class_name SpatialHashGrid
extends RefCounted

## Lưới băm không gian đều, dùng để truy vấn hàng xóm gần cho swarm.
## Xem docs/02-TDD.md §6.1. Ô vuông cạnh `_cell_size` trên mặt phẳng XZ
## (Y bị bỏ qua hoàn toàn — mọi truy vấn đều là hình chiếu 2D xuống XZ).
##
## KHÔNG dùng Area3D / PhysicsServer. Không cấp phát trong `query_radius`
## hay `query_cell_neighbours` — hai hàm này chỉ ĐỌC cấu trúc đã có và GHI
## vào buffer `out` do người gọi cấp phát trước (T-301). `insert/move/remove`
## không nằm trong ràng buộc không-cấp-phát vì chúng không chạy mỗi frame
## cho mọi đơn vị theo cùng một cách truy vấn chạy.
##
## Lớp này thuộc `src/core/` — tiện ích không phụ thuộc game, do đó KHÔNG
## tham chiếu tới bất kỳ autoload nào (Log, EventBus, ...). Lỗi sử dụng
## sai (move/remove một id chưa tồn tại) được xử lý im lặng và có tài liệu
## ở từng hàm, thay vì log.

const DEFAULT_CELL_SIZE: float = 2.0

## Số bit dành cho mỗi trục khi ghép toạ độ ô thành một khoá 64-bit duy
## nhất. 21 bit mỗi trục (sau khi lệch dương bằng `_CELL_KEY_BIAS`) cho
## phép toạ độ ô nằm trong [-1048576, 1048575] — dư sức cho bất kỳ màn
## chơi nào (ở ô 2m, tương đương ±2000km mỗi trục) mà không tràn số
## nguyên 64-bit có dấu của GDScript.
const _CELL_KEY_BITS: int = 21
const _CELL_KEY_BIAS: int = 1 << 20

var _cell_size: float = DEFAULT_CELL_SIZE
var _inv_cell_size: float = 1.0 / DEFAULT_CELL_SIZE

## Khoá ô (int64 ghép từ toạ độ ô) -> PackedInt32Array id thực thể trong ô.
var _cells: Dictionary = {}

## id thực thể -> Vector3 vị trí hiện tại (dùng để lọc bán kính chính xác
## trong query_radius mà không cần đọc lại toàn bộ transform của swarm).
var _positions: Dictionary = {}

## id thực thể -> khoá ô hiện tại (để move/remove tìm đúng ô cũ, O(1)).
var _cell_of: Dictionary = {}

## Bucket rỗng dùng làm giá trị mặc định cho `Dictionary.get()` trong
## query_radius/query_cell_neighbours — gộp "kiểm tra tồn tại" và "lấy
## giá trị" thành MỘT lần băm/tra cứu thay vì hai (has() rồi lại []),
## đây là chi phí chiếm phần lớn thời gian truy vấn theo benchmark thực
## đo trên Godot 4.7.2 (xem tools/bench_spatial_hash.gd). Hằng số, không
## bao giờ bị ghi, nên không có rủi ro alias giữa các lần gọi.
var _empty_bucket: PackedInt32Array = PackedInt32Array()


func _init(cell_size: float = DEFAULT_CELL_SIZE) -> void:
    _cell_size = cell_size
    _inv_cell_size = 1.0 / cell_size


## Thêm thực thể `id` vào lưới tại `position`. Gọi lại với id đã tồn tại
## sẽ được xử lý như `move()` (cập nhật vị trí) thay vì tạo bản ghi trùng.
func insert(id: int, position: Vector3) -> void:
    if _cell_of.has(id):
        move(id, position)
        return
    var key: int = _key_from_world(position)
    _add_to_cell(key, id)
    _cell_of[id] = key
    _positions[id] = position


## Cập nhật vị trí của `id`. Chỉ chuyển ô (xoá khỏi ô cũ, thêm vào ô mới)
## khi vị trí mới rơi sang ô khác — di chuyển trong cùng một ô chỉ cập
## nhật `_positions`, không đụng tới `_cells`. Gọi với id chưa tồn tại sẽ
## tự động chèn mới (tiện cho vòng đời spawn/move dùng chung một lệnh gọi).
func move(id: int, new_position: Vector3) -> void:
    if not _cell_of.has(id):
        insert(id, new_position)
        return
    var old_key: int = _cell_of[id]
    var new_key: int = _key_from_world(new_position)
    if old_key != new_key:
        _remove_from_cell(old_key, id)
        _add_to_cell(new_key, id)
        _cell_of[id] = new_key
    _positions[id] = new_position


## Xoá `id` khỏi lưới. Gọi với id không tồn tại là no-op an toàn.
func remove(id: int) -> void:
    if not _cell_of.has(id):
        return
    var key: int = _cell_of[id]
    _remove_from_cell(key, id)
    _cell_of.erase(id)
    _positions.erase(id)


## Xoá sạch toàn bộ dữ liệu lưới (dùng khi rời màn chơi / reset swarm).
func clear() -> void:
    _cells.clear()
    _positions.clear()
    _cell_of.clear()


## KHÔNG cấp phát. Ghi vào `out` id của mọi thực thể có khoảng cách tới
## `centre` (chiếu xuống XZ) nhỏ hơn hoặc bằng `radius`, trả về SỐ phần tử
## hợp lệ đã ghi. `out` phải do người gọi cấp phát trước với sức chứa đủ
## lớn (ví dụ `resize(MAX_SWARM_UNITS)` một lần lúc khởi tạo) và tái sử
## dụng qua từng frame — hàm này không bao giờ resize `out`. Nếu số kết
## quả thực tế vượt quá `out.size()`, hàm vẫn trả về tổng số tìm thấy
## nhưng chỉ ghi được tới hết sức chứa của `out`; người gọi nên cấp phát
## buffer đủ lớn (>= MAX_SWARM_UNITS) để tránh trường hợp này.
func query_radius(centre: Vector3, radius: float, out: PackedInt32Array) -> int:
    var count: int = 0
    var out_capacity: int = out.size()
    var radius_sq: float = radius * radius
    var min_cx: int = floori((centre.x - radius) * _inv_cell_size)
    var max_cx: int = floori((centre.x + radius) * _inv_cell_size)
    var min_cz: int = floori((centre.z - radius) * _inv_cell_size)
    var max_cz: int = floori((centre.z + radius) * _inv_cell_size)
    for cz: int in range(min_cz, max_cz + 1):
        for cx: int in range(min_cx, max_cx + 1):
            var key: int = _key_from_cell(cx, cz)
            if not _cells.has(key):
                continue
            var bucket: PackedInt32Array = _cells[key]
            for i: int in range(bucket.size()):
                var id: int = bucket[i]
                var pos: Vector3 = _positions[id]
                var dx: float = pos.x - centre.x
                var dz: float = pos.z - centre.z
                if dx * dx + dz * dz <= radius_sq:
                    if count < out_capacity:
                        out[count] = id
                    count += 1
    return count


## KHÔNG cấp phát. Ghi vào `out` id của mọi thực thể nằm trong ô chứa
## `position` và 8 ô lân cận (khối 3x3), KHÔNG lọc theo khoảng cách thực
## (dùng cho lực tách đàn thô — TDD §7 — người gọi tự lọc/tính trọng số
## bằng khoảng cách chính xác nếu cần). Trả về số phần tử hợp lệ đã ghi.
## Cùng ràng buộc về `out` như `query_radius`.
func query_cell_neighbours(position: Vector3, out: PackedInt32Array) -> int:
    var count: int = 0
    var out_capacity: int = out.size()
    var cx: int = floori(position.x * _inv_cell_size)
    var cz: int = floori(position.z * _inv_cell_size)
    for dz: int in range(-1, 2):
        for dx: int in range(-1, 2):
            var key: int = _key_from_cell(cx + dx, cz + dz)
            if not _cells.has(key):
                continue
            var bucket: PackedInt32Array = _cells[key]
            for i: int in range(bucket.size()):
                if count < out_capacity:
                    out[count] = bucket[i]
                count += 1
    return count


## Kích thước ô hiện tại (mét). Tiện cho test/benchmark, không thuộc hợp
## đồng bắt buộc nhưng không phá vỡ nó.
func get_cell_size() -> float:
    return _cell_size


## Số thực thể đang được theo dõi. Tiện cho test/benchmark.
func get_entity_count() -> int:
    return _cell_of.size()


func _add_to_cell(key: int, id: int) -> void:
    if _cells.has(key):
        var bucket: PackedInt32Array = _cells[key]
        bucket.append(id)
        _cells[key] = bucket
    else:
        var new_bucket: PackedInt32Array = PackedInt32Array()
        new_bucket.append(id)
        _cells[key] = new_bucket


func _remove_from_cell(key: int, id: int) -> void:
    if not _cells.has(key):
        return
    var bucket: PackedInt32Array = _cells[key]
    var idx: int = bucket.find(id)
    if idx < 0:
        return
    var last: int = bucket.size() - 1
    bucket[idx] = bucket[last]
    bucket.resize(last)
    if bucket.is_empty():
        _cells.erase(key)
    else:
        _cells[key] = bucket


func _key_from_world(position: Vector3) -> int:
    var cx: int = floori(position.x * _inv_cell_size)
    var cz: int = floori(position.z * _inv_cell_size)
    return _key_from_cell(cx, cz)


func _key_from_cell(cx: int, cz: int) -> int:
    var ux: int = cx + _CELL_KEY_BIAS
    var uz: int = cz + _CELL_KEY_BIAS
    return (ux << _CELL_KEY_BITS) | uz
