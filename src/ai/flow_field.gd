class_name FlowField
extends RefCounted

## Trường hướng đi (flow field) cho toàn bộ swarm/actor trong một màn chơi.
## Xem docs/02-TDD.md §7. Lưới 2D phẳng trên mặt phẳng XZ (Y bỏ qua), ô
## vuông cạnh `_cell_size`, phủ `_bounds`.
##
## Mỗi ô lưu ba giá trị song song, phẳng, KHÔNG dùng mảng lồng nhau hay
## Dictionary (T-302):
##   - cost: PackedByteArray, 0..254 = chi phí đi qua, 255 = tường
##   - distance: PackedInt32Array, khoảng cách Dijkstra tới mục tiêu (giá
##     trị logic là uint16, đại diện bằng int32 vì GDScript không có
##     PackedUInt16Array; DISTANCE_UNREACHABLE = 65535 = chưa tới được)
##   - dir_index: PackedByteArray, chỉ số 0..7 vào bảng hằng `_DIR_OFFSETS`
##     (8 hướng liên thông), DIRECTION_NONE = 8 nghĩa là không có hướng
##     (ô tường hoặc ô mục tiêu)
##
## Tính bằng Dijkstra (hàng đợi ưu tiên nhị phân, xoá trễ) TỪ Ô MỤC TIÊU
## LAN RA NGOÀI — không phải từ mỗi kẻ địch tính riêng vào mục tiêu. Việc
## tính chạy trong `WorkerThreadPool` qua `request_rebuild()`; kết quả
## hoán đổi vào cặp buffer đang đọc (double buffer) CHỈ trên luồng chính,
## chỉ sau khi task đã hoàn thành — không bao giờ gọi
## `wait_for_task_completion()` trước khi `is_task_completed()` xác nhận
## xong, nên không bao giờ chặn frame chính.
##
## LỚP NÀY KHÔNG tự đọc hình học va chạm màn chơi. `set_cost()` là điểm
## nạp dữ liệu duy nhất — hệ thống sinh màn (T-706, chưa triển khai) chịu
## trách nhiệm quét collision và gọi `set_cost()` cho từng ô. Đây là lựa
## chọn có chủ đích: `Ràng buộc quan trọng` của T-301..303 cấm dùng
## Area3D/PhysicsServer/NavigationAgent3D trong các file này, nên việc
## "đọc từ hình học va chạm" ở TDD §7 được hiểu là trách nhiệm của caller,
## không phải của FlowField. Xem mục "Không chắc chắn" trong báo cáo T-303.
##
## Lớp này thuộc `src/ai/` và không tham chiếu autoload nào, để test được
## độc lập bằng GUT mà không cần dựng scene/autoload.

signal field_updated()

const DEFAULT_CELL_SIZE: float = 1.5
const COST_DEFAULT: int = 1
const COST_WALL: int = 255
const DISTANCE_UNREACHABLE: int = 65535
const DIRECTION_NONE: int = 8

## Tính lại khi mục tiêu đi quá 2 ô HOẶC mỗi 250ms — cái nào đến trước.
const REBUILD_INTERVAL_MSEC: int = 250
const REBUILD_TARGET_CELL_DELTA: int = 2

## 8 hướng liên thông quanh một ô, thứ tự cố định. `_DIR_OFFSETS[i]` và
## `_DIR_OFFSETS[7 - i]` luôn đối nhau (dùng trong Dijkstra để gán hướng
## "đi ngược từ ô lân cận về ô hiện tại" mà không cần bảng tra riêng).
const _DIR_OFFSETS: Array[Vector2i] = [
    Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
    Vector2i(-1, 0), Vector2i(1, 0),
    Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _bounds: AABB = AABB()
var _cell_size: float = DEFAULT_CELL_SIZE
var _width: int = 0
var _depth: int = 0

## Buffer "phía trước" — đang được sample_direction()/is_walkable() đọc.
var _cost: PackedByteArray = PackedByteArray()
var _distance: PackedInt32Array = PackedInt32Array()
var _dir_index: PackedByteArray = PackedByteArray()

## Buffer "phía sau" — nơi task nền ghi kết quả Dijkstra mới vào. Chỉ
## hoán đổi với buffer phía trước trên luồng chính, sau khi task xong.
var _distance_back: PackedInt32Array = PackedInt32Array()
var _dir_index_back: PackedByteArray = PackedByteArray()

var _last_target_world: Vector3 = Vector3.ZERO
var _last_target_cell: Vector2i = Vector2i(999999, 999999)
var _last_rebuild_msec: int = 0

var _rebuild_in_progress: bool = false
var _pending_task_id: int = -1
var _pending_target_world: Vector3 = Vector3.ZERO
var _pending_result_target_world: Vector3 = Vector3.ZERO
var _pending_result_target_cell: Vector2i = Vector2i.ZERO


## Cấp lại lưới theo hộp bao `bounds` (mặt phẳng XZ) và kích thước ô.
## Đặt lại toàn bộ cost về mặc định (đi được) và distance/direction về
## "chưa tính". KHÔNG gọi hàm này khi đang có `request_rebuild()` chưa
## xong — hành vi khi đó không xác định (không có khoá đồng bộ, vì mọi
## rebuild nền chỉ nên diễn ra sau khi màn đã cấu hình xong lúc tải màn).
func configure(bounds: AABB, cell_size: float = DEFAULT_CELL_SIZE) -> void:
    _bounds = bounds
    _cell_size = cell_size
    _width = maxi(1, ceili(bounds.size.x / cell_size))
    _depth = maxi(1, ceili(bounds.size.z / cell_size))
    var cell_count: int = _width * _depth
    _cost.resize(cell_count)
    _cost.fill(COST_DEFAULT)
    _distance.resize(cell_count)
    _distance.fill(DISTANCE_UNREACHABLE)
    _dir_index.resize(cell_count)
    _dir_index.fill(DIRECTION_NONE)
    _distance_back.resize(cell_count)
    _distance_back.fill(DISTANCE_UNREACHABLE)
    _dir_index_back.resize(cell_count)
    _dir_index_back.fill(DIRECTION_NONE)
    _last_target_cell = Vector2i(999999, 999999)
    _last_rebuild_msec = 0
    _rebuild_in_progress = false
    _pending_task_id = -1


## Đặt chi phí đi qua ô lưới `cell` (toạ độ ô, không phải mét). `cost` bị
## kẹp về [0, 255]; 255 nghĩa là tường (không thể đi qua). Ô ngoài phạm
## vi lưới bị bỏ qua im lặng. Đây là điểm nạp dữ liệu duy nhất cho trường
## chi phí — xem docstring đầu file.
func set_cost(cell: Vector2i, cost: int) -> void:
    var idx: int = _index_of(cell.x, cell.y)
    if idx < 0:
        return
    _cost[idx] = clampi(cost, 0, 255)


## Tính đồng bộ (chặn luồng gọi) trường distance/direction từ `target_world`
## lan ra toàn lưới bằng Dijkstra, ghi thẳng vào buffer đang đọc. Dùng cho
## test và lần nướng đầu tiên lúc tải màn (trước khi combat bắt đầu) —
## KHÔNG gọi hàm này mỗi frame trong MISSION_ACTIVE, dùng `request_rebuild()`.
func rebuild(target_world: Vector3) -> void:
    var target_cell: Vector2i = get_cell(target_world)
    _compute_flow_field(target_cell, _distance, _dir_index)
    _last_target_world = target_world
    _last_target_cell = target_cell
    _last_rebuild_msec = Time.get_ticks_msec()
    field_updated.emit()


## Xin tính lại trường trong nền qua `WorkerThreadPool`, không chặn luồng
## chính. Gọi hàm này MỖI physics frame từ hệ thống sở hữu FlowField (ví
## dụ SwarmManager) với vị trí mục tiêu hiện tại — bản thân hàm tự quyết
## định có cần tính lại hay không (đi quá 2 ô HOẶC quá 250ms) và cũng là
## nơi duy nhất kiểm tra + hoán đổi buffer khi task nền trước đó đã xong
## (không có hàm `poll()` riêng trong hợp đồng API, nên việc này gộp vào
## đây; xem "Không chắc chắn" trong báo cáo T-303).
func request_rebuild(target_world: Vector3) -> void:
    _try_finish_pending_rebuild()
    if _rebuild_in_progress:
        return
    var target_cell: Vector2i = get_cell(target_world)
    var now_msec: int = Time.get_ticks_msec()
    var cell_delta: int = maxi(
        absi(target_cell.x - _last_target_cell.x),
        absi(target_cell.y - _last_target_cell.y)
    )
    var due_by_time: bool = (now_msec - _last_rebuild_msec) >= REBUILD_INTERVAL_MSEC
    var due_by_distance: bool = cell_delta >= REBUILD_TARGET_CELL_DELTA
    if not due_by_time and not due_by_distance:
        return
    _pending_target_world = target_world
    _rebuild_in_progress = true
    _pending_task_id = WorkerThreadPool.add_task(_threaded_rebuild_task, false, "flow_field_rebuild")


## Nội suy song tuyến hướng đi giữa 4 ô lân cận quanh `world_position`,
## trả về Vector2 chuẩn hoá trên mặt phẳng XZ (x -> X, y -> Z). Trả về
## Vector2.ZERO nếu cả 4 ô lân cận đều không có hướng (ví dụ đứng giữa
## một khối tường lớn).
func sample_direction(world_position: Vector3) -> Vector2:
    if _width <= 0 or _depth <= 0:
        return Vector2.ZERO
    var local_x: float = world_position.x - _bounds.position.x
    var local_z: float = world_position.z - _bounds.position.z
    var fx: float = local_x / _cell_size - 0.5
    var fz: float = local_z / _cell_size - 0.5
    var cx0: int = floori(fx)
    var cz0: int = floori(fz)
    var tx: float = fx - float(cx0)
    var tz: float = fz - float(cz0)
    var d00: Vector2 = _direction_at(cx0, cz0)
    var d10: Vector2 = _direction_at(cx0 + 1, cz0)
    var d01: Vector2 = _direction_at(cx0, cz0 + 1)
    var d11: Vector2 = _direction_at(cx0 + 1, cz0 + 1)
    var top: Vector2 = d00.lerp(d10, tx)
    var bottom: Vector2 = d01.lerp(d11, tx)
    var blended: Vector2 = top.lerp(bottom, tz)
    if blended.length_squared() < 0.0001:
        return Vector2.ZERO
    return blended.normalized()


## Ô chứa `world_position` có đi được không (cost < 255)? Ô ngoài lưới
## luôn được coi là không đi được.
func is_walkable(world_position: Vector3) -> bool:
    var cell: Vector2i = get_cell(world_position)
    var idx: int = _index_of(cell.x, cell.y)
    if idx < 0:
        return false
    return _cost[idx] < COST_WALL


## Chuyển vị trí thế giới sang toạ độ ô (có thể nằm ngoài lưới, âm hoặc
## vượt width/depth — người gọi tự kiểm tra nếu cần).
func get_cell(world_position: Vector3) -> Vector2i:
    var local_x: float = world_position.x - _bounds.position.x
    var local_z: float = world_position.z - _bounds.position.z
    return Vector2i(floori(local_x / _cell_size), floori(local_z / _cell_size))


## Xuất dữ liệu từng ô (cell, cost, distance, direction) để DebugConsole
## vẽ lệnh `ff` sau này (T-112, CHƯA triển khai ở wave này). CHỈ dùng cho
## overlay debug — hàm này cấp phát một Array kết quả, KHÔNG gọi trong
## đường nóng mỗi frame của combat.
func get_debug_cells() -> Array:
    var result: Array = []
    for cz: int in range(_depth):
        for cx: int in range(_width):
            var idx: int = _index_of(cx, cz)
            result.append({
                "cell": Vector2i(cx, cz),
                "cost": _cost[idx],
                "distance": _distance[idx],
                "direction": _direction_at(cx, cz),
            })
    return result


func _threaded_rebuild_task() -> void:
    var target_cell: Vector2i = get_cell(_pending_target_world)
    _compute_flow_field(target_cell, _distance_back, _dir_index_back)
    _pending_result_target_world = _pending_target_world
    _pending_result_target_cell = target_cell


func _try_finish_pending_rebuild() -> void:
    if not _rebuild_in_progress:
        return
    if not WorkerThreadPool.is_task_completed(_pending_task_id):
        return
    ## Task đã xong nên wait ở đây không chặn — chỉ để giải phóng task
    ## đúng cách theo API của WorkerThreadPool.
    WorkerThreadPool.wait_for_task_completion(_pending_task_id)
    _swap_buffers()
    _last_target_world = _pending_result_target_world
    _last_target_cell = _pending_result_target_cell
    _last_rebuild_msec = Time.get_ticks_msec()
    _rebuild_in_progress = false
    _pending_task_id = -1
    field_updated.emit()


func _swap_buffers() -> void:
    var tmp_distance: PackedInt32Array = _distance
    _distance = _distance_back
    _distance_back = tmp_distance
    var tmp_dir: PackedByteArray = _dir_index
    _dir_index = _dir_index_back
    _dir_index_back = tmp_dir


## Dijkstra từ `target_cell` lan ra toàn lưới, đọc `_cost` (dùng chung,
## không double-buffer vì hiếm khi đổi giữa mission), ghi kết quả vào
## `out_distance`/`out_dir`. An toàn chạy trên luồng nền vì chỉ đọc
## `_cost`/`_width`/`_depth` (bất biến trong lúc rebuild) và chỉ ghi vào
## các buffer được truyền vào (không đụng `_distance`/`_dir_index` phía
## trước). Không hiệu chỉnh khoảng cách chéo (sqrt(2)) — chấp nhận sai số
## nhỏ vì mục tiêu là hướng đi đúng, không phải khoảng cách mét chính xác.
func _compute_flow_field(
    target_cell: Vector2i, out_distance: PackedInt32Array, out_dir: PackedByteArray
) -> void:
    out_distance.fill(DISTANCE_UNREACHABLE)
    out_dir.fill(DIRECTION_NONE)
    if _width <= 0 or _depth <= 0:
        return
    var tcx: int = clampi(target_cell.x, 0, _width - 1)
    var tcz: int = clampi(target_cell.y, 0, _depth - 1)
    var target_idx: int = _index_of(tcx, tcz)
    if target_idx < 0:
        return
    out_distance[target_idx] = 0
    var heap_idx: PackedInt32Array = PackedInt32Array()
    var heap_dist: PackedInt32Array = PackedInt32Array()
    _heap_push(heap_idx, heap_dist, target_idx, 0)
    while heap_idx.size() > 0:
        var current_idx: int = heap_idx[0]
        var current_dist: int = heap_dist[0]
        _heap_pop(heap_idx, heap_dist)
        if current_dist > out_distance[current_idx]:
            continue
        var ccx: int = current_idx % _width
        var ccz: int = current_idx / _width
        for i: int in range(_DIR_OFFSETS.size()):
            var offset: Vector2i = _DIR_OFFSETS[i]
            var nidx: int = _index_of(ccx + offset.x, ccz + offset.y)
            if nidx < 0:
                continue
            var ncost: int = _cost[nidx]
            if ncost >= COST_WALL:
                continue
            var new_dist: int = current_dist + ncost
            if new_dist < out_distance[nidx]:
                out_distance[nidx] = new_dist
                out_dir[nidx] = 7 - i
                _heap_push(heap_idx, heap_dist, nidx, new_dist)


func _direction_at(cx: int, cz: int) -> Vector2:
    var idx: int = _index_of(cx, cz)
    if idx < 0:
        return Vector2.ZERO
    var dir_idx: int = _dir_index[idx]
    if dir_idx >= DIRECTION_NONE:
        return Vector2.ZERO
    var offset: Vector2i = _DIR_OFFSETS[dir_idx]
    return Vector2(float(offset.x), float(offset.y))


func _index_of(cx: int, cz: int) -> int:
    if cx < 0 or cz < 0 or cx >= _width or cz >= _depth:
        return -1
    return cz * _width + cx


## Heap nhị phân nhỏ nhất, "xoá trễ" (không cần decrease-key: khi một ô
## được relax nhiều lần, mọi bản ghi cũ trong heap bị bỏ qua ở
## `_compute_flow_field` bằng so sánh `current_dist > out_distance[...]`).
## Chỉ dùng nội bộ lúc bake (không phải mỗi frame) nên cấp phát khi heap
## lớn dần là chấp nhận được.
func _heap_push(
    heap_idx: PackedInt32Array, heap_dist: PackedInt32Array, idx: int, dist: int
) -> void:
    heap_idx.append(idx)
    heap_dist.append(dist)
    var i: int = heap_idx.size() - 1
    while i > 0:
        var parent: int = (i - 1) / 2
        if heap_dist[parent] <= heap_dist[i]:
            break
        _heap_swap(heap_idx, heap_dist, i, parent)
        i = parent


func _heap_pop(heap_idx: PackedInt32Array, heap_dist: PackedInt32Array) -> void:
    var last: int = heap_idx.size() - 1
    heap_idx[0] = heap_idx[last]
    heap_dist[0] = heap_dist[last]
    heap_idx.resize(last)
    heap_dist.resize(last)
    var i: int = 0
    var n: int = last
    while true:
        var left: int = i * 2 + 1
        var right: int = i * 2 + 2
        var smallest: int = i
        if left < n and heap_dist[left] < heap_dist[smallest]:
            smallest = left
        if right < n and heap_dist[right] < heap_dist[smallest]:
            smallest = right
        if smallest == i:
            break
        _heap_swap(heap_idx, heap_dist, i, smallest)
        i = smallest


func _heap_swap(
    heap_idx: PackedInt32Array, heap_dist: PackedInt32Array, a: int, b: int
) -> void:
    var ti: int = heap_idx[a]
    heap_idx[a] = heap_idx[b]
    heap_idx[b] = ti
    var td: int = heap_dist[a]
    heap_dist[a] = heap_dist[b]
    heap_dist[b] = td
