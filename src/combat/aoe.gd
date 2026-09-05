class_name Aoe
extends RefCounted

## Sát thương vùng: Frag Launcher, Mortar Pod, Plasma Thrower, Swarm Missiles.
## Xem docs/01-GDD.md §6.1–§6.2 và docs/05-BACKLOG.md T-507.
##
## Ba luật của một vụ nổ:
##  * **Suy giảm theo khoảng cách** — tâm ăn trọn, mép chỉ còn
##    `FALLOFF_AT_EDGE`. Tuyến tính, dễ đọc bằng mắt khi chơi.
##  * **Không xuyên tường** — mỗi mục tiêu phải nhìn thấy tâm nổ. Không có
##    luật này thì Mortar Pod bắn thủng cả bản đồ.
##  * **Tự gây sát thương** — nổ ngay dưới chân người chơi thì người chơi
##    cũng ăn. Đây là điều kiện kìm hãm của nhóm Explosive (GDD §6.1).
##
## Instance được người gọi (Projectile, WeaponMount) giữ và dùng lại.

## Hệ số sát thương ở đúng mép bán kính. GIÁ TRỊ TẠM — GDD chưa chốt đường
## cong suy giảm; cần xác nhận ở T-1402 (pass cân bằng).
const FALLOFF_AT_EDGE: float = 0.3
## Chiều cao lấy mẫu khi kiểm tra tầm nhìn: ngang thân mục tiêu, không phải
## sát sàn (sát sàn sẽ bị chính gờ nền chắn).
const LOS_PROBE_HEIGHT: float = 0.8
## Chỉ WORLD. Hurtbox không được chắn tầm nhìn của nhau.
const LOS_MASK: int = 1
const ACTOR_MASK: int = 8 | 16
const MAX_ACTOR_RESULTS: int = 16


var _targets: PackedInt32Array = PackedInt32Array()
var _los_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _sphere: SphereShape3D = SphereShape3D.new()
var _hit_count: int = 0


func _init() -> void:
    _targets.resize(SwarmManager.MAX_SWARM_UNITS)
    _los_query.collide_with_areas = false
    _los_query.collide_with_bodies = true
    _los_query.collision_mask = LOS_MASK
    _shape_query.shape = _sphere
    _shape_query.collide_with_areas = true
    _shape_query.collide_with_bodies = false
    _shape_query.collision_mask = ACTOR_MASK


## Hệ số sát thương còn lại ở khoảng cách `distance` so với tâm nổ.
## Hàm thuần tuý — test cân bằng gọi thẳng, không cần dựng world.
static func falloff_at(distance: float, radius: float) -> float:
    if radius <= 0.0:
        return 1.0
    var ratio: float = clampf(distance / radius, 0.0, 1.0)
    return lerpf(1.0, FALLOFF_AT_EDGE, ratio)


## Nổ tại `centre`. Trả về số mục tiêu bị trừ máu (kể cả người chơi tự dính).
## `self_target` là chủ vũ khí: nó MIỄN nhiễm ở vòng ngoài và chỉ ăn đòn khi
## đứng trong `self_damage_radius`. `space` để trống thì bỏ qua actor và bỏ
## qua kiểm tra tầm nhìn (dùng cho test headless).
func detonate(
    space: PhysicsDirectSpaceState3D,
    centre: Vector3,
    radius: float,
    damage: float,
    damage_type: DamageTypes.Type,
    source: Node,
    swarm: SwarmManager,
    self_damage_radius: float = 0.0,
    self_target: Node = null,
    statuses: Array[StringName] = []
) -> int:
    _hit_count = 0
    if radius <= 0.0 or damage <= 0.0:
        return 0
    _damage_swarm(space, centre, radius, damage, swarm)
    _damage_actors(space, centre, radius, damage, damage_type, source, statuses)
    _damage_self(space, centre, damage, damage_type, source, self_damage_radius, self_target, statuses)
    return _hit_count


func get_hit_count() -> int:
    return _hit_count


func _damage_swarm(
    space: PhysicsDirectSpaceState3D,
    centre: Vector3,
    radius: float,
    damage: float,
    swarm: SwarmManager
) -> void:
    if swarm == null:
        return
    var found: int = swarm.query_radius(centre, radius, _targets)
    for slot: int in range(found):
        var id: int = _targets[slot]
        var position: Vector3 = swarm.get_unit_position(id)
        if position == Vector3.INF:
            continue
        if not _has_line_of_sight(space, centre, position):
            continue
        var amount: float = damage * falloff_at(centre.distance_to(position), radius)
        if swarm.damage_unit(id, amount) >= 0:
            _hit_count += 1


func _damage_actors(
    space: PhysicsDirectSpaceState3D,
    centre: Vector3,
    radius: float,
    damage: float,
    damage_type: DamageTypes.Type,
    source: Node,
    statuses: Array[StringName]
) -> void:
    if space == null:
        return
    _sphere.radius = radius
    _shape_query.transform = Transform3D(Basis.IDENTITY, centre)
    var results: Array[Dictionary] = space.intersect_shape(_shape_query, MAX_ACTOR_RESULTS)
    for result: Dictionary in results:
        var hurtbox := result.get("collider") as Hurtbox
        if hurtbox == null:
            continue
        var receiver: Node = hurtbox.get_receiver()
        # Chủ vũ khí đi qua nhánh tự sát thương riêng, không phải vòng này.
        if receiver == null or receiver == source:
            continue
        var point: Vector3 = hurtbox.global_position
        if not _has_line_of_sight(space, centre, point):
            continue
        var amount: float = damage * falloff_at(centre.distance_to(point), radius)
        _resolve(receiver, centre, amount, damage_type, source, statuses)


## Người chơi chỉ tự dính khi đứng RẤT gần tâm nổ; suy giảm tính theo bán
## kính tự sát thương chứ không theo bán kính nổ, nên mép vùng này vẫn đau.
func _damage_self(
    space: PhysicsDirectSpaceState3D,
    centre: Vector3,
    damage: float,
    damage_type: DamageTypes.Type,
    source: Node,
    self_damage_radius: float,
    self_target: Node,
    statuses: Array[StringName]
) -> void:
    if self_damage_radius <= 0.0 or self_target == null:
        return
    var body := self_target as Node3D
    if body == null:
        return
    var distance: float = centre.distance_to(body.global_position)
    if distance > self_damage_radius:
        return
    if not _has_line_of_sight(space, centre, body.global_position):
        return
    _resolve(self_target, centre, damage * falloff_at(distance, self_damage_radius), damage_type, source, statuses)


## Không có `space` (test headless) thì coi như thấy nhau — hành vi này được
## nêu rõ ở `detonate()` để test không phải dựng cả world vật lý.
func _has_line_of_sight(space: PhysicsDirectSpaceState3D, centre: Vector3, target: Vector3) -> bool:
    if space == null:
        return true
    _los_query.from = centre + Vector3(0.0, LOS_PROBE_HEIGHT, 0.0)
    _los_query.to = target + Vector3(0.0, LOS_PROBE_HEIGHT, 0.0)
    return space.intersect_ray(_los_query).is_empty()


func _resolve(
    receiver: Node,
    centre: Vector3,
    amount: float,
    damage_type: DamageTypes.Type,
    source: Node,
    statuses: Array[StringName]
) -> void:
    if amount <= 0.0:
        return
    var info: DamageInfo = PoolManager.get_damage_info()
    info.amount = amount
    info.type = damage_type
    info.source_position = centre
    info.source_id = source.get_instance_id() if source != null else -1
    for status_id: StringName in statuses:
        info.status_to_apply.append(status_id)
    DamageResolver.resolve(info, receiver)
    PoolManager.release_damage_info(info)
    _hit_count += 1
