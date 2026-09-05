class_name ConeWeapon
extends RefCounted

## Vũ khí liên tục hình nón: Flamer, Cryo Projector, Arc Emitter.
## Xem docs/01-GDD.md §6.2 và docs/05-BACKLOG.md T-506.
##
## Ba điểm khác biệt so với vũ khí bắn phát một:
##  * `WeaponData.damage` và `heat_per_shot` là **mỗi giây**, không phải mỗi
##    phát. Chúng được chia cho `tick_rate` để ra lượng của một tick.
##  * Sát thương rơi theo **tick cố định** chứ không theo frame. Cùng một
##    giây kẹp cò phải gây đúng cùng lượng sát thương ở 30 hay 144 FPS.
##  * `heat_per_shot` âm nghĩa là **làm mát** mech — ngoại lệ cố ý của Cryo
##    Projector (GDD §6.3), đi qua `HeatComponent.set_heat()` vì `add_heat()`
##    từ chối giá trị âm.
##
## Swarm không có `StatusComponent` (kiến trúc data-oriented, TDD §6.1) nên
## trạng thái chỉ áp được lên actor; swarm chỉ nhận sát thương.
##
## Instance được WeaponMount giữ và dùng lại giữa các frame.

## Trần mục tiêu actor mỗi tick — chặn chi phí truy vấn hình khối.
const MAX_ACTOR_RESULTS: int = 16
## PLAYER_HURTBOX + ENEMY_HURTBOX. Nón không quan tâm tường (Flamer liếm
## quanh vật cản); chắn tầm nhìn là việc của AoE (T-507).
const ACTOR_MASK: int = 8 | 16
const DEFAULT_TICK_RATE: float = 10.0

var _accumulator: float = 0.0
var _was_firing: bool = false
var _tick_count: int = 0
var _hit_count: int = 0

var _targets: PackedInt32Array = PackedInt32Array()
var _shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _sphere: SphereShape3D = SphereShape3D.new()


func _init() -> void:
    _targets.resize(SwarmManager.MAX_SWARM_UNITS)
    _shape_query.shape = _sphere
    _shape_query.collide_with_areas = true
    _shape_query.collide_with_bodies = false
    _shape_query.collision_mask = ACTOR_MASK


## Gọi mỗi frame vật lý. Trả về số tick đã nổ ra trong frame này (0 khi chưa
## tới nhịp). `space` để trống thì chỉ đánh swarm.
func update(
    delta: float,
    wants_fire: bool,
    data: WeaponData,
    apex: Vector3,
    direction: Vector3,
    space: PhysicsDirectSpaceState3D,
    swarm: SwarmManager,
    heat: HeatComponent,
    source: Node
) -> int:
    _tick_count = 0
    _hit_count = 0
    if data == null or delta <= 0.0:
        return 0
    var period: float = 1.0 / maxf(data.tick_rate, 0.01)
    if not wants_fire:
        _was_firing = false
        _accumulator = 0.0
        return 0
    if not _was_firing:
        # Bóp cò lại thì đếm nhịp từ đầu — không mang nợ tick của lần trước,
        # cũng không tặng một tick miễn phí (làm DPS lệch bảng GDD §6.2).
        _was_firing = true
        _accumulator = 0.0
    _accumulator = minf(_accumulator + delta, period * 2.0)
    while _accumulator >= period:
        _accumulator -= period
        _tick(data, period, apex, direction, space, swarm, heat, source)
        _tick_count += 1
    return _tick_count


## Số mục tiêu bị trừ máu trong lần `update()` gần nhất.
func get_hit_count() -> int:
    return _hit_count


func get_tick_period(data: WeaponData) -> float:
    if data == null:
        return 1.0 / DEFAULT_TICK_RATE
    return 1.0 / maxf(data.tick_rate, 0.01)


func reset() -> void:
    _accumulator = 0.0
    _was_firing = false
    _tick_count = 0
    _hit_count = 0


func _tick(
    data: WeaponData,
    period: float,
    apex: Vector3,
    direction: Vector3,
    space: PhysicsDirectSpaceState3D,
    swarm: SwarmManager,
    heat: HeatComponent,
    source: Node
) -> void:
    var damage: float = data.damage * period
    var cone_range: float = data.max_range if data.max_range > 0.0 else 6.0
    var limit: int = data.max_targets_per_tick
    _apply_heat(data.heat_per_shot * period, heat)
    _damage_swarm(swarm, apex, direction, cone_range, data.cone_angle_degrees, damage, limit)
    _damage_actors(space, apex, direction, cone_range, data.cone_angle_degrees, damage, data, source, limit)


## Dương thì nung, âm thì làm mát. `add_heat()` chặn giá trị âm nên nhánh
## làm mát phải đi qua `set_heat()` — xem GDD §6.3, Cryo Projector.
func _apply_heat(amount: float, heat: HeatComponent) -> void:
    if heat == null or is_zero_approx(amount):
        return
    if amount > 0.0:
        heat.add_heat(amount)
        return
    heat.set_heat(heat.get_heat() + amount)


func _damage_swarm(
    swarm: SwarmManager,
    apex: Vector3,
    direction: Vector3,
    cone_range: float,
    angle_degrees: float,
    damage: float,
    limit: int
) -> void:
    if swarm == null or damage <= 0.0:
        return
    var found: int = swarm.query_in_cone(apex, direction, cone_range, angle_degrees, _targets)
    var budget: int = found if limit <= 0 else mini(found, limit)
    for slot: int in range(budget):
        if swarm.damage_unit(_targets[slot], damage) >= 0:
            _hit_count += 1


## Truy vấn hình cầu rồi lọc góc. `intersect_shape` cấp phát một Array, chấp
## nhận được vì nó chạy MỖI TICK (tối đa 14 lần/giây) chứ không mỗi frame.
func _damage_actors(
    space: PhysicsDirectSpaceState3D,
    apex: Vector3,
    direction: Vector3,
    cone_range: float,
    angle_degrees: float,
    damage: float,
    data: WeaponData,
    source: Node,
    limit: int
) -> void:
    if space == null or damage <= 0.0:
        return
    var axis := Vector3(direction.x, 0.0, direction.z)
    if axis.length_squared() <= 0.000001:
        return
    axis = axis.normalized()
    _sphere.radius = cone_range
    _shape_query.transform = Transform3D(Basis.IDENTITY, apex)
    var cos_limit: float = cos(deg_to_rad(clampf(angle_degrees, 0.0, 360.0)) * 0.5)
    var results: Array[Dictionary] = space.intersect_shape(_shape_query, MAX_ACTOR_RESULTS)
    var applied: int = 0
    for result: Dictionary in results:
        if limit > 0 and applied >= limit:
            return
        var hurtbox := result.get("collider") as Hurtbox
        if hurtbox == null:
            continue
        var receiver: Node = hurtbox.get_receiver()
        if receiver == null or receiver == source:
            continue
        var offset: Vector3 = hurtbox.global_position - apex
        offset.y = 0.0
        var distance: float = offset.length()
        if distance > 0.0001 and offset.dot(axis) / distance < cos_limit:
            continue
        _resolve(receiver, hurtbox.global_position, damage, data, source)
        applied += 1
        _hit_count += 1


func _resolve(
    receiver: Node,
    point: Vector3,
    damage: float,
    data: WeaponData,
    source: Node
) -> void:
    var info: DamageInfo = PoolManager.get_damage_info()
    info.amount = damage
    info.type = data.damage_type
    info.source_position = point
    info.source_id = source.get_instance_id() if source != null else -1
    for status_id: StringName in data.status_to_apply:
        info.status_to_apply.append(status_id)
    DamageResolver.resolve(info, receiver)
    PoolManager.release_damage_info(info)
