class_name SwarmManager
extends Node3D

## Quản lý trạng thái data-oriented của toàn bộ swarm trong một màn chơi.
## Xem docs/02-TDD.md §6.1 và docs/05-BACKLOG.md T-304.
##
## Swarm không có Node riêng. Mỗi thuộc tính được lưu trong một mảng song
## song và cùng một index biểu diễn một đơn vị. Khi một đơn vị chết, phần tử
## cuối được hoán đổi vào vị trí của nó để giữ dữ liệu liên tục và không cần
## dịch chuyển cả mảng.

const MAX_SWARM_UNITS: int = 400
const STATE_ALIVE: int = 1

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

## Scene VFX chết được cấp phát qua PoolManager. Để trống trong test/headless
## hoặc trước khi content thật được gán.
var death_vfx_scene: PackedScene
var _ray_hit_ids: PackedInt32Array = PackedInt32Array()
var _ray_hit_distances: PackedFloat32Array = PackedFloat32Array()


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
        _healths[index] -= damage
        if _healths[index] <= 0.0:
            var dead_position: Vector3 = _positions[index]
            var dead_id: int = _ids[index]
            kill(dead_id)
            _spawn_death_vfx(dead_position)
        else:
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
    var length_sq: float = segment.length_squared()
    if length_sq <= 0.000001:
        return damage_at_point(from, hit_radius, damage)
    var candidate_count: int = 0
    var radius_sq: float = hit_radius * hit_radius
    for index: int in range(_alive_count):
        var offset: Vector3 = _positions[index] - from
        offset.y = 0.0
        var t: float = clampf(offset.dot(segment) / length_sq, 0.0, 1.0)
        var closest: Vector3 = from + segment * t
        var distance: Vector3 = _positions[index] - closest
        distance.y = 0.0
        if distance.length_squared() <= radius_sq:
            var insert_at: int = candidate_count
            while insert_at > 0 and _ray_hit_distances[insert_at - 1] > t:
                _ray_hit_distances[insert_at] = _ray_hit_distances[insert_at - 1]
                _ray_hit_ids[insert_at] = _ray_hit_ids[insert_at - 1]
                insert_at -= 1
            _ray_hit_distances[insert_at] = t
            _ray_hit_ids[insert_at] = _ids[index]
            candidate_count += 1
    var limit: int = candidate_count if pierce < 0 else mini(candidate_count, pierce)
    var hit_count: int = 0
    for result_index: int in range(limit):
        var id: int = _ray_hit_ids[result_index]
        var index: int = _index_by_id[id]
        if index < 0:
            continue
        _healths[index] -= damage
        hit_count += 1
        if _healths[index] <= 0.0:
            var dead_position: Vector3 = _positions[index]
            kill(id)
            _spawn_death_vfx(dead_position)
    return hit_count


func _spawn_death_vfx(position: Vector3) -> void:
    if death_vfx_scene == null or not is_inside_tree():
        return
    var vfx: Node = PoolManager.acquire(death_vfx_scene)
    if vfx is Node3D:
        (vfx as Node3D).global_position = position
    add_child(vfx)


## Số đơn vị swarm đang sống. Không duyệt mảng.
func get_alive_count() -> int:
    return _alive_count
