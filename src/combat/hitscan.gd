class_name Hitscan
extends RefCounted

## Bắn tức thời cho vũ khí không dùng đạn bay (Pulse Laser, Rail Lance,
## Arc Emitter). Xem docs/02-TDD.md §8.3 và docs/05-BACKLOG.md T-505.
##
## Một tia duy nhất phải xử lý được BA thế giới va chạm khác nhau:
##   1. tường/vật cản  → raycast physics, cắt ngắn tia
##   2. actor          → raycast physics vào Hurtbox, lặp có loại trừ
##   3. swarm          → truy vấn mảng của SwarmManager, KHÔNG qua physics
## Kết quả của cả ba được **trộn theo khoảng cách tăng dần** rồi mới trừ máu,
## nhờ vậy `pierce` tiêu đúng vào những mục tiêu gần nòng nhất, bất kể mục
## tiêu đó là actor hay swarm.
##
## Instance được WeaponMount giữ và dùng lại; mọi buffer cấp phát một lần
## trong `_init()` để `fire()` không cấp phát trong đường nóng (TDD §12.2).

## Số actor tối đa một tia có thể chạm. Vượt quá thì tia dừng — bảo vệ vòng
## lặp raycast khỏi trường hợp bệnh lý, không phải luật gameplay.
const MAX_ACTOR_HITS: int = 8
## Bán kính va chạm với swarm, khớp với `Projectile` để hai đường bắn cùng
## cảm giác trúng đích như nhau.
const SWARM_HIT_RADIUS: float = 0.7
## Tầm mặc định khi vũ khí không khai báo — đủ dài để vượt mọi phòng.
const DEFAULT_MAX_DISTANCE: float = 120.0
## WORLD + PLAYER_HURTBOX + ENEMY_HURTBOX; lọc phe bằng `source`.
const HIT_MASK: int = 1 | 8 | 16
const BEAM_THICKNESS: float = 0.08

var beam_scene: PackedScene
## Node cha để gắn VFX tia. Để trống thì bỏ qua phần trình bày.
var vfx_root: Node = null

var _end_point: Vector3 = Vector3.ZERO
var _hit_count: int = 0

var _actor_nodes: Array[Node] = []
var _actor_distances: PackedFloat32Array = PackedFloat32Array()
var _actor_points: PackedVector3Array = PackedVector3Array()
var _actor_count: int = 0

var _swarm_ids: PackedInt32Array = PackedInt32Array()
var _swarm_ts: PackedFloat32Array = PackedFloat32Array()

var _hit_points: PackedVector3Array = PackedVector3Array()

var _ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _exclude: Array[RID] = []


func _init() -> void:
    _actor_nodes.resize(MAX_ACTOR_HITS)
    _actor_distances.resize(MAX_ACTOR_HITS)
    _actor_points.resize(MAX_ACTOR_HITS)
    _swarm_ids.resize(SwarmManager.MAX_SWARM_UNITS)
    _swarm_ts.resize(SwarmManager.MAX_SWARM_UNITS)
    _hit_points.resize(MAX_ACTOR_HITS + SwarmManager.MAX_SWARM_UNITS)
    _ray_query.collide_with_areas = true
    _ray_query.collide_with_bodies = true
    _ray_query.collision_mask = HIT_MASK


## Bắn một tia. Trả về số mục tiêu thực sự bị trừ máu.
## `pierce_count` theo đúng nghĩa của `WeaponData`: 0 = trúng một mục tiêu,
## n = trúng thêm n mục tiêu nữa, âm = xuyên vô hạn.
## `space` để trống (headless/test không có world) thì chỉ đánh swarm.
func fire(
    space: PhysicsDirectSpaceState3D,
    origin: Vector3,
    direction: Vector3,
    max_distance: float,
    damage: float,
    damage_type: DamageTypes.Type,
    pierce_count: int,
    source: Node,
    swarm: SwarmManager,
    statuses: Array[StringName] = []
) -> int:
    _hit_count = 0
    _actor_count = 0
    var axis := Vector3(direction.x, 0.0, direction.z)
    if axis.length_squared() <= 0.000001:
        axis = Vector3.FORWARD
    axis = axis.normalized()
    var distance: float = max_distance if max_distance > 0.0 else DEFAULT_MAX_DISTANCE
    _end_point = origin + axis * distance

    _gather_actors(space, origin, source)
    var swarm_count: int = 0
    if swarm != null:
        swarm_count = swarm.query_along_ray(origin, _end_point, SWARM_HIT_RADIUS, _swarm_ids, _swarm_ts)

    var beam_length: float = origin.distance_to(_end_point)
    var budget: int = -1 if pierce_count < 0 else pierce_count + 1
    _apply_merged(origin, beam_length, budget, damage, damage_type, source, swarm, swarm_count, statuses)
    _spawn_beam(origin, _end_point)
    return _hit_count


## Điểm kết thúc của tia vừa bắn: chỗ chạm tường, hoặc hết tầm.
func get_end_point() -> Vector3:
    return _end_point


func get_hit_count() -> int:
    return _hit_count


## Vị trí trúng thứ `index`, theo thứ tự gần nòng trước. Dùng cho VFX va chạm.
func get_hit_position(index: int) -> Vector3:
    if index < 0 or index >= _hit_count:
        return Vector3.INF
    return _hit_points[index]


## Lặp raycast, mỗi lần loại trừ vật vừa chạm, cho tới khi gặp tường hoặc
## hết tầm. Tường cắt ngắn `_end_point` nên swarm phía sau tường không dính.
func _gather_actors(space: PhysicsDirectSpaceState3D, origin: Vector3, source: Node) -> void:
    if space == null:
        return
    _exclude.clear()
    _ray_query.from = origin
    _ray_query.to = _end_point
    for _step: int in range(MAX_ACTOR_HITS):
        _ray_query.exclude = _exclude
        var hit: Dictionary = space.intersect_ray(_ray_query)
        if hit.is_empty():
            return
        var collider: Node = hit["collider"] as Node
        var point: Vector3 = hit["position"] as Vector3
        var hurtbox := collider as Hurtbox
        if hurtbox == null:
            # Tường hoặc vật cản: tia dừng ở đây.
            _end_point = point
            return
        _exclude.append(hit["rid"] as RID)
        var receiver: Node = hurtbox.get_receiver()
        if receiver == null or receiver == source:
            continue
        _actor_nodes[_actor_count] = receiver
        _actor_distances[_actor_count] = origin.distance_to(point)
        _actor_points[_actor_count] = point
        _actor_count += 1


## Trộn hai danh sách đã sắp xếp (actor theo mét, swarm theo tham số 0..1)
## và tiêu `budget` theo đúng thứ tự khoảng cách thật.
func _apply_merged(
    origin: Vector3,
    beam_length: float,
    budget: int,
    damage: float,
    damage_type: DamageTypes.Type,
    source: Node,
    swarm: SwarmManager,
    swarm_count: int,
    statuses: Array[StringName]
) -> void:
    var actor_index: int = 0
    var swarm_index: int = 0
    while budget != 0:
        var has_actor: bool = actor_index < _actor_count
        var has_swarm: bool = swarm_index < swarm_count
        if not has_actor and not has_swarm:
            return
        var actor_distance: float = _actor_distances[actor_index] if has_actor else INF
        var swarm_distance: float = _swarm_ts[swarm_index] * beam_length if has_swarm else INF
        if has_actor and actor_distance <= swarm_distance:
            _damage_actor(_actor_nodes[actor_index], _actor_points[actor_index], damage, damage_type, source, statuses)
            actor_index += 1
        else:
            var id: int = _swarm_ids[swarm_index]
            swarm_index += 1
            var point: Vector3 = swarm.get_unit_position(id)
            if swarm.damage_unit(id, damage) < 0:
                continue
            _record_hit(point)
        if budget > 0:
            budget -= 1


func _damage_actor(
    receiver: Node,
    point: Vector3,
    damage: float,
    damage_type: DamageTypes.Type,
    source: Node,
    statuses: Array[StringName]
) -> void:
    var info: DamageInfo = PoolManager.get_damage_info()
    info.amount = damage
    info.type = damage_type
    info.source_position = point
    info.source_id = source.get_instance_id() if source != null else -1
    for status_id: StringName in statuses:
        info.status_to_apply.append(status_id)
    DamageResolver.resolve(info, receiver)
    PoolManager.release_damage_info(info)
    _record_hit(point)


func _record_hit(point: Vector3) -> void:
    if _hit_count < _hit_points.size():
        _hit_points[_hit_count] = point
    _hit_count += 1


func _spawn_beam(origin: Vector3, end_point: Vector3) -> void:
    if beam_scene == null or vfx_root == null or not vfx_root.is_inside_tree():
        return
    var node: Node = PoolManager.acquire(beam_scene)
    var beam := node as BeamVfx
    if beam == null:
        PoolManager.release(node)
        return
    vfx_root.add_child(beam)
    beam.show_beam(origin, end_point, BEAM_THICKNESS)
