class_name SwarmManager
extends Node3D

## Quản lý trạng thái data-oriented của toàn bộ swarm trong một màn chơi.
## Xem docs/02-TDD.md §6.1 và docs/05-BACKLOG.md T-304.
##
## Swarm không có Node riêng. Mỗi thuộc tính được lưu trong một mảng song
## song và cùng một index biểu diễn một đơn vị. Khi một đơn vị chết, phần tử
## cuối được hoán đổi vào vị trí của nó để giữ dữ liệu liên tục và không cần
## dịch chuyển cả mảng.

## Tổng kết sát thương của cả frame, phát đúng MỘT lần. Damage number và
## VFX xác quái đọc tín hiệu này thay vì bám từng con — 300 con trúng đòn
## cùng lúc mà bắn ra 300 sự kiện thì cả hai hệ thống đó đều sập (TDD §12.7,
## docs/04-UX-UI.md §2.4 "gộp sát thương swarm").
signal damage_reported(centre: Vector3, total_damage: float, hits: int, kills: int)

const MAX_SWARM_UNITS: int = 400
const STATE_ALIVE: int = 1
## Số VFX chết được phép sinh riêng lẻ trong một frame. Vượt qua thì phần
## còn lại gộp vào `damage_reported` để GibManager xử lý một cục — đây là
## hàng rào chống "bão hạt" khi quét sạch một đàn (T-605).
const MAX_DEATH_VFX_PER_FRAME: int = 10

var _positions: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _healths: PackedFloat32Array = PackedFloat32Array()
var _types: PackedByteArray = PackedByteArray()
var _states: PackedByteArray = PackedByteArray()
var _timers: PackedFloat32Array = PackedFloat32Array()
var _ids: PackedInt32Array = PackedInt32Array()

## Map id logic -> index hiện tại trong các mảng song song. Kích thước cố định
## ngay từ _init() để spawn/kill không phải tạo entry mới.
var _index_by_id: PackedInt32Array = PackedInt32Array()

## Stack id rảnh, cấp phát một lần trong _init().
var _free_ids: PackedInt32Array = PackedInt32Array()

var _alive_count: int = 0
var _free_count: int = MAX_SWARM_UNITS

## Bộ lập lịch cập nhật theo lô. Chỉ chấp nhận 1/2/4 để giữ nhịp đều và
## cho phép dùng phép modulo rẻ, deterministic theo id logic.
var _batch_count: int = 1
var _batch_cursor: int = 0

## Scene VFX chết được cấp phát qua PoolManager. Để trống trong test/headless
## hoặc trước khi content thật được gán.
var death_vfx_scene: PackedScene
var _ray_hit_ids: PackedInt32Array = PackedInt32Array()
var _ray_hit_distances: PackedFloat32Array = PackedFloat32Array()

## Buffer dùng lại cho truy vấn — không bao giờ cấp phát trong đường nóng.
var _query_ids: PackedInt32Array = PackedInt32Array()
var _cone_candidates: PackedInt32Array = PackedInt32Array()

## Lưới băm không gian của SwarmMovement. Không bắt buộc: khi để trống, mọi
## truy vấn rơi về quét tuyến tính trên mảng liên tục (đúng nhưng O(n)).
var _grid: SpatialHashGrid = null

var _report_damage: float = 0.0
var _report_position_sum: Vector3 = Vector3.ZERO
var _report_hits: int = 0
var _report_kills: int = 0
var _death_vfx_this_frame: int = 0

## Lưới do SwarmMovement đồng bộ mỗi frame, nên nó KHÔNG biết những đơn vị
## vừa spawn/kill sau lần đồng bộ gần nhất. Truy vấn chiến đấu chỉ được tin
## lưới khi hai số hiệu này bằng nhau; lệch thì quét tuyến tính cho chắc —
## thà chậm còn hơn để một con vừa spawn miễn nhiễm với vụ nổ.
var _state_revision: int = 0
var _grid_synced_revision: int = -1


func _init() -> void:
    _positions.resize(MAX_SWARM_UNITS)
    _velocities.resize(MAX_SWARM_UNITS)
    _healths.resize(MAX_SWARM_UNITS)
    _types.resize(MAX_SWARM_UNITS)
    _states.resize(MAX_SWARM_UNITS)
    _timers.resize(MAX_SWARM_UNITS)
    _ids.resize(MAX_SWARM_UNITS)

    _index_by_id.resize(MAX_SWARM_UNITS)
    _index_by_id.fill(-1)

    _free_ids.resize(MAX_SWARM_UNITS)
    _ray_hit_ids.resize(MAX_SWARM_UNITS)
    _ray_hit_distances.resize(MAX_SWARM_UNITS)
    _query_ids.resize(MAX_SWARM_UNITS)
    _cone_candidates.resize(MAX_SWARM_UNITS)
    for id: int in range(MAX_SWARM_UNITS):
        _free_ids[id] = MAX_SWARM_UNITS - 1 - id


## Sinh một đơn vị swarm vào slot rảnh. Không tạo Node và không cấp phát
## container runtime. Trả về id logic >= 0, hoặc -1 nếu swarm đã đầy.
func spawn(
    position: Vector3,
    velocity: Vector3,
    health: float,
    swarm_type: int,
    state: int = STATE_ALIVE,
    timer: float = 0.0
) -> int:
    if _alive_count >= MAX_SWARM_UNITS:
        return -1

    if _free_count <= 0:
        return -1

    _free_count -= 1
    var id: int = _free_ids[_free_count]
    var index: int = _alive_count

    _positions[index] = position
    _velocities[index] = velocity
    _healths[index] = health
    _types[index] = clampi(swarm_type, 0, 255)
    _states[index] = state
    _timers[index] = timer
    _ids[index] = id
    _index_by_id[id] = index
    _alive_count += 1
    _state_revision += 1
    return id


## Đánh dấu đơn vị `id` đã chết và hoán đổi phần tử cuối vào slot của nó.
## Chỉ giảm _alive_count và trả id về stack rảnh; không tạo/xoá object.
## Trả false nếu id không tồn tại hoặc đã chết.
func kill(id: int) -> bool:
    if id < 0 or id >= MAX_SWARM_UNITS:
        return false

    var index: int = _index_by_id[id]
    if index < 0 or index >= _alive_count:
        return false

    var last_index: int = _alive_count - 1
    if index != last_index:
        var moved_id: int = _ids[last_index]
        _positions[index] = _positions[last_index]
        _velocities[index] = _velocities[last_index]
        _healths[index] = _healths[last_index]
        _types[index] = _types[last_index]
        _states[index] = _states[last_index]
        _timers[index] = _timers[last_index]
        _ids[index] = moved_id
        _index_by_id[moved_id] = index

    _index_by_id[id] = -1
    _free_ids[_free_count] = id
    _free_count += 1
    _alive_count -= 1
    _state_revision += 1
    return true


## Gây sát thương vùng trên mặt phẳng XZ. Duyệt mảng liên tục để không phụ
## thuộc trạng thái đồng bộ của grid; swap-kill ngay tại index hiện tại.
func damage_at_point(position: Vector3, radius: float, damage: float) -> int:
    if radius < 0.0 or damage <= 0.0:
        return 0
    var radius_sq: float = radius * radius
    var hit_count: int = 0
    var index: int = 0
    while index < _alive_count:
        var offset: Vector3 = _positions[index] - position
        var in_range: bool = offset.x * offset.x + offset.z * offset.z <= radius_sq
        if not in_range:
            index += 1
            continue
        hit_count += 1
        var position_hit: Vector3 = _positions[index]
        _healths[index] -= damage
        if _healths[index] <= 0.0:
            var dead_id: int = _ids[index]
            kill(dead_id)
            _record_damage(position_hit, damage, true)
            _spawn_death_vfx(position_hit)
        else:
            _record_damage(position_hit, damage, false)
            index += 1
    return hit_count


## Gây sát thương dọc đoạn thẳng trên XZ. Mỗi đơn vị chỉ trúng một lần;
## `pierce` là số mục tiêu tối đa theo thứ tự gần `from` nhất. Giá trị âm
## xuyên toàn bộ mục tiêu. Bán kính va chạm mặc định đủ cho mesh swarm nhỏ.
func damage_along_ray(
    from: Vector3,
    to: Vector3,
    damage: float,
    pierce: int,
    hit_radius: float = 0.5
) -> int:
    if damage <= 0.0 or pierce == 0 or hit_radius < 0.0:
        return 0
    var segment: Vector3 = to - from
    segment.y = 0.0
    if segment.length_squared() <= 0.000001:
        return damage_at_point(from, hit_radius, damage)
    var candidate_count: int = query_along_ray(from, to, hit_radius, _ray_hit_ids, _ray_hit_distances)
    var limit: int = candidate_count if pierce < 0 else mini(candidate_count, pierce)
    var hit_count: int = 0
    for result_index: int in range(limit):
        if damage_unit(_ray_hit_ids[result_index], damage) >= 0:
            hit_count += 1
    return hit_count


## Trừ máu đúng MỘT đơn vị theo id logic, kill và phát VFX nếu nó chết.
## Trả về 1 nếu chết, 0 nếu còn sống, -1 nếu id không tồn tại.
func damage_unit(id: int, damage: float) -> int:
    if id < 0 or id >= MAX_SWARM_UNITS or damage <= 0.0:
        return -1
    var index: int = _index_by_id[id]
    if index < 0 or index >= _alive_count:
        return -1
    var position_hit: Vector3 = _positions[index]
    _healths[index] -= damage
    if _healths[index] > 0.0:
        _record_damage(position_hit, damage, false)
        return 0
    kill(id)
    _record_damage(position_hit, damage, true)
    _spawn_death_vfx(position_hit)
    return 1


## KHÔNG cấp phát và KHÔNG gây sát thương: ghi id của mọi đơn vị nằm trong
## `hit_radius` quanh đoạn `from`→`to` vào `out_ids`, kèm tham số vị trí dọc
## đoạn (0..1) vào `out_ts`, đã **sắp xếp tăng dần theo khoảng cách tới
## `from`**. Người gọi cấp phát trước hai buffer; hàm không bao giờ resize.
## Trả về số phần tử đã ghi. Đoạn suy biến (dài 0) trả về 0.
func query_along_ray(
    from: Vector3,
    to: Vector3,
    hit_radius: float,
    out_ids: PackedInt32Array,
    out_ts: PackedFloat32Array
) -> int:
    if hit_radius < 0.0:
        return 0
    var segment: Vector3 = to - from
    segment.y = 0.0
    var length_sq: float = segment.length_squared()
    if length_sq <= 0.000001:
        return 0
    var capacity: int = mini(out_ids.size(), out_ts.size())
    var radius_sq: float = hit_radius * hit_radius
    var count: int = 0
    for index: int in range(_alive_count):
        var offset: Vector3 = _positions[index] - from
        offset.y = 0.0
        var t: float = clampf(offset.dot(segment) / length_sq, 0.0, 1.0)
        var to_axis: Vector3 = offset - segment * t
        to_axis.y = 0.0
        if to_axis.length_squared() > radius_sq or count >= capacity:
            continue
        var insert_at: int = count
        while insert_at > 0 and out_ts[insert_at - 1] > t:
            out_ts[insert_at] = out_ts[insert_at - 1]
            out_ids[insert_at] = out_ids[insert_at - 1]
            insert_at -= 1
        out_ts[insert_at] = t
        out_ids[insert_at] = _ids[index]
        count += 1
    return count


## KHÔNG cấp phát và KHÔNG gây sát thương: ghi id của mọi đơn vị trong bán
## kính `radius` quanh `centre` (chiếu xuống XZ) vào `out_ids`. Dùng lưới băm
## khi có, ngược lại quét tuyến tính. Trả về số phần tử đã ghi.
func query_radius(centre: Vector3, radius: float, out_ids: PackedInt32Array) -> int:
    if radius < 0.0:
        return 0
    var radius_sq: float = radius * radius
    var capacity: int = out_ids.size()
    var count: int = 0
    if is_grid_fresh():
        var found: int = mini(_grid.query_radius(centre, radius, _query_ids), _query_ids.size())
        for slot: int in range(found):
            if count >= capacity:
                break
            var id: int = _query_ids[slot]
            if id < 0 or id >= MAX_SWARM_UNITS:
                continue
            var index: int = _index_by_id[id]
            if index < 0 or index >= _alive_count:
                continue
            # Lưới có thể trễ một frame so với mảng vị trí — lọc lại cho chắc.
            var grid_offset: Vector3 = _positions[index] - centre
            grid_offset.y = 0.0
            if grid_offset.length_squared() > radius_sq:
                continue
            out_ids[count] = id
            count += 1
        return count
    for index: int in range(_alive_count):
        if count >= capacity:
            break
        var offset: Vector3 = _positions[index] - centre
        offset.y = 0.0
        if offset.length_squared() > radius_sq:
            continue
        out_ids[count] = _ids[index]
        count += 1
    return count


## KHÔNG cấp phát và KHÔNG gây sát thương: ghi id của mọi đơn vị nằm trong
## hình nón đỉnh `apex`, trục `direction`, dài `cone_range`, góc mở tổng
## `angle_degrees`. Sắp theo thứ tự tăng dần khoảng cách tới đỉnh nón.
func query_in_cone(
    apex: Vector3,
    direction: Vector3,
    cone_range: float,
    angle_degrees: float,
    out_ids: PackedInt32Array
) -> int:
    var axis := Vector3(direction.x, 0.0, direction.z)
    if cone_range <= 0.0 or axis.length_squared() <= 0.000001:
        return 0
    axis = axis.normalized()
    var cos_limit: float = cos(deg_to_rad(clampf(angle_degrees, 0.0, 360.0)) * 0.5)
    var candidate_count: int = query_radius(apex, cone_range, _cone_candidates)
    var capacity: int = out_ids.size()
    var count: int = 0
    for slot: int in range(candidate_count):
        if count >= capacity:
            break
        var id: int = _cone_candidates[slot]
        var index: int = _index_by_id[id]
        if index < 0:
            continue
        var offset: Vector3 = _positions[index] - apex
        offset.y = 0.0
        var distance: float = offset.length()
        if distance > 0.0001 and offset.dot(axis) / distance < cos_limit:
            continue
        var insert_at: int = count
        while insert_at > 0 and _distance_to(out_ids[insert_at - 1], apex) > distance:
            out_ids[insert_at] = out_ids[insert_at - 1]
            insert_at -= 1
        out_ids[insert_at] = id
        count += 1
    return count


## Vị trí hiện tại của đơn vị `id`, hoặc `Vector3.INF` nếu nó không còn sống.
func get_unit_position(id: int) -> Vector3:
    if id < 0 or id >= MAX_SWARM_UNITS:
        return Vector3.INF
    var index: int = _index_by_id[id]
    if index < 0 or index >= _alive_count:
        return Vector3.INF
    return _positions[index]


func is_alive(id: int) -> bool:
    return id >= 0 and id < MAX_SWARM_UNITS and _index_by_id[id] >= 0


## Lưới băm dùng chung với SwarmMovement. SwarmRuntime nối vào sau khi tạo
## movement; để trống thì mọi truy vấn rơi về quét tuyến tính.
func set_spatial_grid(grid: SpatialHashGrid) -> void:
    _grid = grid


func get_spatial_grid() -> SpatialHashGrid:
    return _grid


## SwarmMovement gọi sau khi đã đối chiếu xong lưới với mảng vị trí.
func notify_grid_synced() -> void:
    _grid_synced_revision = _state_revision


## Lưới có phản ánh đúng tập đơn vị đang sống hay không. Vị trí có thể lệch
## trong phạm vi một frame — `query_radius` lọc lại bằng `_positions` nên
## sai lệch đó không lọt ra ngoài.
func is_grid_fresh() -> bool:
    return _grid != null and _grid_synced_revision == _state_revision


func _distance_to(id: int, origin: Vector3) -> float:
    var index: int = _index_by_id[id]
    if index < 0:
        return INF
    var offset: Vector3 = _positions[index] - origin
    offset.y = 0.0
    return offset.length()


## Chốt sổ frame: phát `damage_reported` nếu có gì để báo, rồi dọn bộ đếm.
## SwarmRuntime gọi đúng một lần mỗi frame vật lý, sau khi mọi hệ thống swarm
## đã chạy xong. Trả về số đơn vị trúng đòn trong frame vừa rồi.
func flush_damage_report() -> int:
    var hits: int = _report_hits
    _death_vfx_this_frame = 0
    if hits <= 0:
        return 0
    var centre: Vector3 = _report_position_sum / float(hits)
    var total: float = _report_damage
    var kills: int = _report_kills
    _report_damage = 0.0
    _report_position_sum = Vector3.ZERO
    _report_hits = 0
    _report_kills = 0
    damage_reported.emit(centre, total, hits, kills)
    return hits


## Số VFX chết đã sinh riêng lẻ trong frame hiện tại. Trên
## `MAX_DEATH_VFX_PER_FRAME` thì phần dư không được sinh nữa.
func get_death_vfx_this_frame() -> int:
    return _death_vfx_this_frame


func _record_damage(position: Vector3, amount: float, killed: bool) -> void:
    _report_damage += amount
    _report_position_sum += position
    _report_hits += 1
    if killed:
        _report_kills += 1


func _spawn_death_vfx(position: Vector3) -> void:
    if death_vfx_scene == null or not is_inside_tree():
        return
    if _death_vfx_this_frame >= MAX_DEATH_VFX_PER_FRAME:
        return
    _death_vfx_this_frame += 1
    var vfx: Node = PoolManager.acquire(death_vfx_scene)
    # Vào cây TRƯỚC rồi mới đặt vị trí: global_position của node ngoài cây
    # không có nghĩa gì và Godot trả về Transform3D() kèm lỗi.
    add_child(vfx)
    if vfx is Node3D:
        (vfx as Node3D).global_position = position


## Cấu hình số lô hợp lệ. Cursor reset để thay đổi cấu hình có kết quả dự
## đoán được. Trả false và giữ nguyên cấu hình nếu giá trị không hợp lệ.
func set_batch_count(count: int) -> bool:
    if count != 1 and count != 2 and count != 4:
        return false
    _batch_count = count
    _batch_cursor = 0
    return true


func get_batch_count() -> int:
    return _batch_count


## Lô cần chạy ở frame hiện tại. Caller phải gọi advance_batch() đúng một
## lần sau khi hoàn tất mọi hệ thống swarm của frame.
func get_current_batch() -> int:
    return _batch_cursor


func advance_batch() -> void:
    _batch_cursor = (_batch_cursor + 1) % _batch_count


## Kiểm tra id thuộc lô hiện tại. Phân lô theo id thay vì index để swap-kill
## không làm một đơn vị đổi lịch cập nhật bất ngờ.
func is_id_in_current_batch(id: int) -> bool:
    return id >= 0 and id < MAX_SWARM_UNITS and id % _batch_count == _batch_cursor


## Delta tích luỹ tương ứng chu kỳ của một đơn vị. Nhờ vậy vận tốc/gia tốc và
## timer vẫn tiến theo thời gian thực khi chỉ xử lý mỗi 2 hoặc 4 frame.
func get_batched_delta(frame_delta: float) -> float:
    return frame_delta * float(_batch_count)


## Số đơn vị swarm đang sống. Không duyệt mảng.
func get_alive_count() -> int:
    return _alive_count
