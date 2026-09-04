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


## Số đơn vị swarm đang sống. Không duyệt mảng.
func get_alive_count() -> int:
    return _alive_count
