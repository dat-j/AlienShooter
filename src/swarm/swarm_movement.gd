class_name SwarmMovement
extends RefCounted

## Điều hướng data-oriented cho SwarmManager theo flow field.
## Mỗi update dùng một buffer hàng xóm cố định và SpatialHashGrid; không tạo
## Node/Area3D/NavigationAgent3D cho từng đơn vị.

const FLOW_WEIGHT: float = 1.0
const SEPARATION_WEIGHT: float = 0.6
const WALL_WEIGHT: float = 0.8
const JITTER_WEIGHT: float = 0.1
const SEPARATION_RADIUS: float = 1.25
const WALL_PROBE_DISTANCE: float = 0.8

const WALL_PROBES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]

var max_speed: float = 4.0
var acceleration: float = 18.0
var _speed_by_type: PackedFloat32Array = PackedFloat32Array()
var _jump_distance_by_type: PackedFloat32Array = PackedFloat32Array()
var _jump_range_by_type: PackedFloat32Array = PackedFloat32Array()
var _jump_cooldown_by_type: PackedFloat32Array = PackedFloat32Array()
var _jump_timers: PackedFloat32Array = PackedFloat32Array()

var _grid: SpatialHashGrid
var _neighbours: PackedInt32Array = PackedInt32Array()
var _tracked: PackedByteArray = PackedByteArray()
var _alive_ids: PackedByteArray = PackedByteArray()


func _init(cell_size: float = SpatialHashGrid.DEFAULT_CELL_SIZE) -> void:
    _grid = SpatialHashGrid.new(cell_size)
    _neighbours.resize(SwarmManager.MAX_SWARM_UNITS)
    _tracked.resize(SwarmManager.MAX_SWARM_UNITS)
    _tracked.fill(0)
    _alive_ids.resize(SwarmManager.MAX_SWARM_UNITS)
    _jump_timers.resize(SwarmManager.MAX_SWARM_UNITS)
    _speed_by_type.resize(256)
    _speed_by_type.fill(max_speed)
    _jump_distance_by_type.resize(256)
    _jump_range_by_type.resize(256)
    _jump_cooldown_by_type.resize(256)


func configure_type(data: EnemyData) -> void:
    if data == null or data.execution_path != 0:
        return
    var type_id: int = clampi(data.swarm_type_id, 0, 255)
    _speed_by_type[type_id] = data.move_speed
    _jump_distance_by_type[type_id] = data.jump_distance
    _jump_range_by_type[type_id] = data.jump_trigger_range
    _jump_cooldown_by_type[type_id] = data.jump_cooldown_seconds


## Cập nhật toàn bộ đơn vị sống. Grid được đồng bộ trước và sau bước tích
## phân để các truy vấn trong frame dùng cùng một snapshot ổn định.
func update(manager: SwarmManager, flow_field: FlowField, delta: float, target_position: Vector3 = Vector3.INF) -> void:
    if manager == null or flow_field == null or delta <= 0.0:
        return
    _sync_grid(manager)
    var alive_count: int = manager._alive_count
    var batched_delta: float = manager.get_batched_delta(delta)
    for index: int in range(alive_count):
        var id: int = manager._ids[index]
        if not manager.is_id_in_current_batch(id):
            continue
        var position: Vector3 = manager._positions[index]
        _jump_timers[id] = maxf(0.0, _jump_timers[id] - batched_delta)
        var swarm_type: int = manager._types[index]
        if target_position != Vector3.INF and _try_jump(manager, flow_field, index, id, swarm_type, target_position):
            continue
        var flow_2d: Vector2 = flow_field.sample_direction(position)
        var flow: Vector3 = Vector3(flow_2d.x, 0.0, flow_2d.y)
        var separation: Vector3 = _separation(manager, position, id)
        var wall_avoid: Vector3 = _wall_avoidance(flow_field, position)
        var jitter: Vector3 = _stable_jitter(id)
        var steering: Vector3 = (
            flow * FLOW_WEIGHT
            + separation * SEPARATION_WEIGHT
            + wall_avoid * WALL_WEIGHT
            + jitter * JITTER_WEIGHT
        )
        var desired_velocity: Vector3 = Vector3.ZERO
        if steering.length_squared() > 0.0001:
            desired_velocity = steering.normalized() * _speed_by_type[swarm_type]
        var velocity: Vector3 = manager._velocities[index].move_toward(
            desired_velocity, acceleration * batched_delta
        )
        var next_position: Vector3 = position + velocity * batched_delta
        if not flow_field.is_walkable(next_position):
            velocity = _slide_from_wall(flow_field, position, velocity)
            next_position = position + velocity * batched_delta
        manager._velocities[index] = velocity
        manager._positions[index] = next_position
        _grid.move(id, next_position)


func _try_jump(manager: SwarmManager, flow_field: FlowField, index: int, id: int, swarm_type: int, target: Vector3) -> bool:
    var jump_distance: float = _jump_distance_by_type[swarm_type]
    var trigger_range: float = _jump_range_by_type[swarm_type]
    if jump_distance <= 0.0 or trigger_range <= 0.0 or _jump_timers[id] > 0.0:
        return false
    var offset: Vector3 = target - manager._positions[index]
    offset.y = 0.0
    var distance: float = offset.length()
    if distance > trigger_range or distance <= jump_distance * 0.5:
        return false
    var landing: Vector3 = manager._positions[index] + offset.normalized() * minf(jump_distance, distance)
    if not flow_field.is_walkable(landing):
        return false
    manager._positions[index] = landing
    manager._velocities[index] = offset.normalized() * _speed_by_type[swarm_type]
    _jump_timers[id] = _jump_cooldown_by_type[swarm_type]
    _grid.move(id, landing)
    return true


func get_grid() -> SpatialHashGrid:
    return _grid


func _sync_grid(manager: SwarmManager) -> void:
    _alive_ids.fill(0)
    for index: int in range(manager._alive_count):
        var id: int = manager._ids[index]
        _alive_ids[id] = 1
        if _tracked[id] == 0:
            _grid.insert(id, manager._positions[index])
            _tracked[id] = 1
        else:
            _grid.move(id, manager._positions[index])
    for id: int in range(SwarmManager.MAX_SWARM_UNITS):
        if _tracked[id] != 0 and _alive_ids[id] == 0:
            _grid.remove(id)
            _tracked[id] = 0


func _separation(manager: SwarmManager, position: Vector3, self_id: int) -> Vector3:
    var count: int = mini(_grid.query_radius(position, SEPARATION_RADIUS, _neighbours), _neighbours.size())
    var force: Vector3 = Vector3.ZERO
    for i: int in range(count):
        var other_id: int = _neighbours[i]
        if other_id == self_id:
            continue
        var other_index: int = manager._index_by_id[other_id]
        if other_index < 0:
            continue
        var offset: Vector3 = position - manager._positions[other_index]
        offset.y = 0.0
        var distance_sq: float = offset.length_squared()
        if distance_sq > 0.0001:
            force += offset.normalized() * (1.0 - sqrt(distance_sq) / SEPARATION_RADIUS)
        else:
            force += _stable_jitter(self_id ^ other_id)
    return force.normalized() if force.length_squared() > 0.0001 else Vector3.ZERO


func _wall_avoidance(flow_field: FlowField, position: Vector3) -> Vector3:
    var force: Vector3 = Vector3.ZERO
    for direction: Vector3 in WALL_PROBES:
        if not flow_field.is_walkable(position + direction * WALL_PROBE_DISTANCE):
            force -= direction
    return force.normalized() if force.length_squared() > 0.0001 else Vector3.ZERO


func _slide_from_wall(flow_field: FlowField, position: Vector3, velocity: Vector3) -> Vector3:
    var slide_x: Vector3 = Vector3(velocity.x, 0.0, 0.0)
    var slide_z: Vector3 = Vector3(0.0, 0.0, velocity.z)
    if slide_x.length_squared() > 0.0001 and flow_field.is_walkable(position + slide_x * 0.05):
        return slide_x
    if slide_z.length_squared() > 0.0001 and flow_field.is_walkable(position + slide_z * 0.05):
        return slide_z
    return Vector3.ZERO


## Vector giả-ngẫu-nhiên bất biến theo id: phá đối xứng nhưng vẫn deterministic.
func _stable_jitter(id: int) -> Vector3:
    var angle: float = fmod(float(id * 1103515245 + 12345), 6283.0) * 0.001
    return Vector3(cos(angle), 0.0, sin(angle))
