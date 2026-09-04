class_name Projectile
extends Node3D

## Đạn pooled. `Node3D` + `MeshInstance3D`, KHÔNG phải `RigidBody3D` hay
## `Area3D` — nó tự raycast theo đúng đoạn di chuyển của frame để đạn nhanh
## không xuyên qua mục tiêu. Xem docs/02-TDD.md §8.3.

signal hit_target(position: Vector3, target: Node)
signal expired(position: Vector3)

const MAX_LIFETIME: float = 4.0
const DEFAULT_SPEED: float = 60.0
## WORLD + ENEMY_HURTBOX + PLAYER_HURTBOX; đạn tự lọc phe qua nguồn bắn.
const HIT_MASK: int = 1 | 8 | 16
## Bán kính va chạm với swarm — rộng hơn mesh một chút cho đỡ hụt.
const SWARM_HIT_RADIUS: float = 0.7

## SwarmManager của nhiệm vụ; để trống thì đạn chỉ đánh actor và tường.
var swarm_manager: SwarmManager = null

var _velocity: Vector3 = Vector3.ZERO
var _damage: float = 0.0
var _damage_type: DamageTypes.Type = DamageTypes.Type.KINETIC
var _source: Node = null
var _pierce_remaining: int = 0
var _aoe_radius: float = 0.0
var _lifetime: float = 0.0
var _is_flying: bool = false
var _hit_ids: Dictionary = {}

## Tái sử dụng để không cấp phát trong đường nóng (TDD §12.2).
var _ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


func _ready() -> void:
    _ray_query.collide_with_areas = true
    _ray_query.collide_with_bodies = true
    _ray_query.collision_mask = HIT_MASK


func _physics_process(delta: float) -> void:
    if not _is_flying or delta <= 0.0:
        return
    _lifetime += delta
    if _lifetime >= MAX_LIFETIME:
        _finish(false)
        return
    var from: Vector3 = global_position
    var to: Vector3 = from + _velocity * delta
    if _sweep_swarm(from, to):
        return
    if _sweep_bodies(from, to):
        return
    global_position = to


## Hợp đồng dùng chung với RangedAttackState (T-406).
func launch(
    origin: Vector3,
    direction: Vector3,
    speed: float,
    damage: float,
    damage_type: DamageTypes.Type,
    source: Node
) -> void:
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() <= 0.0001:
        flat = Vector3.FORWARD
    flat = flat.normalized()
    global_position = origin
    look_at(origin + flat, Vector3.UP)
    _velocity = flat * (speed if speed > 0.0 else DEFAULT_SPEED)
    _damage = damage
    _damage_type = damage_type
    _source = source
    _lifetime = 0.0
    _hit_ids.clear()
    _is_flying = true
    visible = true


## Số mục tiêu xuyên thêm và bán kính nổ, lấy từ `WeaponData` (T-508).
func configure(pierce_count: int, aoe_radius: float) -> void:
    _pierce_remaining = pierce_count
    _aoe_radius = maxf(aoe_radius, 0.0)


func is_flying() -> bool:
    return _is_flying


func get_damage() -> float:
    return _damage


func _on_acquired() -> void:
    _reset()


func _on_released() -> void:
    _reset()


func _reset() -> void:
    _is_flying = false
    _velocity = Vector3.ZERO
    _damage = 0.0
    _pierce_remaining = 0
    _aoe_radius = 0.0
    _lifetime = 0.0
    _hit_ids.clear()
    _source = null


## Quét swarm bằng spatial data của SwarmManager, không qua physics.
func _sweep_swarm(from: Vector3, to: Vector3) -> bool:
    if swarm_manager == null or _damage <= 0.0:
        return false
    var killed: int = swarm_manager.damage_along_ray(
        from, to, _damage, _pierce_remaining if _pierce_remaining > 0 else 1, SWARM_HIT_RADIUS
    )
    if killed <= 0:
        return false
    global_position = to
    _pierce_remaining -= killed
    if _pierce_remaining < 0:
        _finish(true)
        return true
    return false


func _sweep_bodies(from: Vector3, to: Vector3) -> bool:
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    if space == null:
        return false
    _ray_query.from = from
    _ray_query.to = to
    var hit: Dictionary = space.intersect_ray(_ray_query)
    if hit.is_empty():
        return false
    var collider: Node = hit["collider"] as Node
    global_position = hit["position"] as Vector3
    var hurtbox := collider as Hurtbox
    if hurtbox == null:
        # Tường hoặc vật cản: đạn dừng tại đây.
        _finish(true)
        return true
    var receiver: Node = hurtbox.get_receiver()
    if receiver == null or receiver == _source or _hit_ids.has(receiver.get_instance_id()):
        return false
    _hit_ids[receiver.get_instance_id()] = true
    _deal_damage(receiver)
    hit_target.emit(global_position, receiver)
    _pierce_remaining -= 1
    if _pierce_remaining < 0:
        _finish(true)
        return true
    return false


func _deal_damage(receiver: Node) -> void:
    var info: DamageInfo = PoolManager.get_damage_info()
    info.amount = _damage
    info.type = _damage_type
    info.source_position = global_position
    info.source_id = _source.get_instance_id() if _source != null else -1
    info.pierce_remaining = _pierce_remaining
    DamageResolver.resolve(info, receiver)
    PoolManager.release_damage_info(info)


## Nổ vùng khi có bán kính; suy giảm theo khoảng cách và tự sát thương là
## việc của T-507 (`src/combat/aoe.gd`).
func _explode() -> void:
    if _aoe_radius <= 0.0 or swarm_manager == null:
        return
    swarm_manager.damage_at_point(global_position, _aoe_radius, _damage)


func _finish(did_hit: bool) -> void:
    if not _is_flying:
        return
    _is_flying = false
    _explode()
    if did_hit:
        hit_target.emit(global_position, null)
    else:
        expired.emit(global_position)
    PoolManager.release(self)
