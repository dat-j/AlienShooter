class_name SwarmCombat
extends RefCounted

## Chiến đấu cận chiến data-oriented của swarm. Phát hiện mục tiêu và Boost
## chỉ qua SpatialHashGrid, không dùng physics body/Area3D cho từng đơn vị.

const DEFAULT_ATTACK_RANGE: float = 1.35
const DEFAULT_ATTACK_DAMAGE: float = 5.0
const DEFAULT_ATTACK_COOLDOWN: float = 1.0
const DEFAULT_BOOST_RADIUS: float = 0.9
const DEFAULT_BOOST_KNOCKBACK: float = 9.0

var _query_buffer: PackedInt32Array = PackedInt32Array()
var _attack_ranges: PackedFloat32Array = PackedFloat32Array()
var _attack_damages: PackedFloat32Array = PackedFloat32Array()
var _attack_cooldowns: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
    _query_buffer.resize(SwarmManager.MAX_SWARM_UNITS)
    _attack_ranges.resize(256)
    _attack_ranges.fill(DEFAULT_ATTACK_RANGE)
    _attack_damages.resize(256)
    _attack_damages.fill(DEFAULT_ATTACK_DAMAGE)
    _attack_cooldowns.resize(256)
    _attack_cooldowns.fill(DEFAULT_ATTACK_COOLDOWN)


## Cấu hình thông số cận chiến cho một swarm type mà không cần Dictionary.
func configure_type(swarm_type: int, attack_range: float, damage: float, cooldown: float) -> void:
    var type_index: int = clampi(swarm_type, 0, 255)
    _attack_ranges[type_index] = maxf(0.0, attack_range)
    _attack_damages[type_index] = maxf(0.0, damage)
    _attack_cooldowns[type_index] = maxf(0.001, cooldown)


## Giảm hồi chiêu và gây sát thương cho mục tiêu. `damage_receiver` nhận ba
## tham số: amount, source_position, source_id. Một callback giúp hệ swarm
## độc lập với Health/ArmorComponent sẽ được triển khai ở milestone sau.
func update_melee(
    manager: SwarmManager,
    grid: SpatialHashGrid,
    target_position: Vector3,
    delta: float,
    damage_receiver: Callable
) -> int:
    if manager == null or grid == null or delta < 0.0:
        return 0
    var batched_delta: float = manager.get_batched_delta(delta)
    for index: int in range(manager._alive_count):
        if not manager.is_id_in_current_batch(manager._ids[index]):
            continue
        manager._timers[index] = maxf(0.0, manager._timers[index] - batched_delta)

    var max_range: float = 0.0
    for index: int in range(manager._alive_count):
        max_range = maxf(max_range, _attack_ranges[manager._types[index]])
    var found: int = mini(grid.query_radius(target_position, max_range, _query_buffer), _query_buffer.size())
    var hit_count: int = 0
    for result_index: int in range(found):
        var id: int = _query_buffer[result_index]
        if id < 0 or id >= SwarmManager.MAX_SWARM_UNITS:
            continue
        var index: int = manager._index_by_id[id]
        if index < 0 or not manager.is_id_in_current_batch(id) or manager._timers[index] > 0.0:
            continue
        var swarm_type: int = manager._types[index]
        var offset: Vector3 = manager._positions[index] - target_position
        offset.y = 0.0
        var attack_range: float = _attack_ranges[swarm_type]
        if offset.length_squared() > attack_range * attack_range:
            continue
        manager._timers[index] = _attack_cooldowns[swarm_type]
        if damage_receiver.is_valid():
            damage_receiver.call(_attack_damages[swarm_type], manager._positions[index], id)
        hit_count += 1
    return hit_count


## Đẩy mọi đơn vị trong vùng quét Boost. Trả số đơn vị bị va chạm; caller có
## thể dùng kết quả để nối sát thương Boost ở T-309/T-501.
func apply_boost_collision(
    manager: SwarmManager,
    grid: SpatialHashGrid,
    boost_position: Vector3,
    boost_direction: Vector3,
    radius: float = DEFAULT_BOOST_RADIUS,
    knockback: float = DEFAULT_BOOST_KNOCKBACK
) -> int:
    if manager == null or grid == null or radius < 0.0:
        return 0
    var direction: Vector3 = boost_direction
    direction.y = 0.0
    if direction.length_squared() <= 0.0001:
        return 0
    direction = direction.normalized()
    var found: int = mini(grid.query_radius(boost_position, radius, _query_buffer), _query_buffer.size())
    var affected: int = 0
    for result_index: int in range(found):
        var id: int = _query_buffer[result_index]
        if id < 0 or id >= SwarmManager.MAX_SWARM_UNITS:
            continue
        var index: int = manager._index_by_id[id]
        if index < 0:
            continue
        manager._velocities[index] = direction * knockback
        affected += 1
    return affected
