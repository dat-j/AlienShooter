class_name SwarmRuntime
extends Node3D

## Nối toàn bộ hệ thống swarm lại thành một node dùng được trong màn chơi:
## FlowField → SwarmMovement → SwarmCombat → SwarmRenderer, tất cả chạy trên
## SwarmManager duy nhất. Xem docs/02-TDD.md §6.1 và §7.
##
## SpawnDirector (T-802) sau này chỉ cần gọi `spawn_unit()` trên node này —
## nó không cần biết gì về mảng dữ liệu bên trong.

signal player_hit(amount: float, source_position: Vector3)

const DEFAULT_ARENA_SIZE: float = 60.0
## Chiều cao lấy mẫu khi nướng chi phí: đủ cao để không đụng sàn, đủ thấp để
## bắt được tường, cột và bậc.
const COST_PROBE_HEIGHT: float = 1.2
const COST_PROBE_THICKNESS: float = 2.0

@export var arena_size: float = DEFAULT_ARENA_SIZE
@export var cell_size: float = FlowField.DEFAULT_CELL_SIZE
@export var target_path: NodePath
@export var enemy_ids: Array[StringName] = [&"enm_crawler", &"enm_skitter", &"enm_husk"]
@export_range(1, 4, 1) var batch_count: int = 2

var _flow: FlowField = FlowField.new()
var _movement: SwarmMovement = SwarmMovement.new()
var _combat: SwarmCombat = SwarmCombat.new()
var _types: Array[EnemyData] = []
var _target: Node3D

@onready var manager: SwarmManager = $SwarmManager
@onready var renderer: SwarmRenderer = $SwarmRenderer


func _ready() -> void:
    _target = get_node_or_null(target_path) as Node3D
    manager.set_batch_count(batch_count)
    # Hitscan/AoE truy vấn swarm qua manager; cho nó mượn lưới của movement
    # để không phải quét tuyến tính 400 phần tử mỗi lần nổ (T-505, T-507).
    manager.set_spatial_grid(_movement.get_grid())
    var half: float = arena_size * 0.5
    _flow.configure(AABB(Vector3(-half, -1.0, -half), Vector3(arena_size, 2.0, arena_size)), cell_size)
    bake_costs_from_world()
    _configure_types()
    if _target != null:
        _flow.rebuild(_target.global_position)


func _physics_process(delta: float) -> void:
    if _target == null or delta <= 0.0:
        return
    var target_position: Vector3 = _target.global_position
    _flow.request_rebuild(target_position)
    _movement.update(manager, _flow, delta, target_position)
    _combat.update_melee(manager, _movement.get_grid(), target_position, delta, _on_swarm_melee_hit)
    renderer.sync_from_manager(manager)
    # Chốt sổ sát thương của frame TRƯỚC khi sang lô kế: damage number và VFX
    # xác quái phải thấy đúng một bản tổng kết cho mỗi frame (T-605, T-607).
    manager.flush_damage_report()
    manager.advance_batch()


## Sinh một đơn vị swarm theo `EnemyData`. Trả về id, hoặc -1 nếu đã đầy.
func spawn_unit(data: EnemyData, position: Vector3) -> int:
    if data == null or data.execution_path != 0:
        return -1
    return manager.spawn(position, Vector3.ZERO, data.max_hp, data.swarm_type_id)


func get_enemy_types() -> Array[EnemyData]:
    return _types


func get_flow_field() -> FlowField:
    return _flow


func get_alive_count() -> int:
    return manager.get_alive_count()


func clear_all() -> void:
    while manager.get_alive_count() > 0:
        manager.kill(manager._ids[0])


## Đánh dấu ô có vật cản tĩnh là tường để flow field vòng qua chúng. Chạy một
## lần lúc vào màn — không phải đường nóng.
func bake_costs_from_world() -> int:
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    if space == null:
        return 0
    var shape := BoxShape3D.new()
    shape.size = Vector3(cell_size * 0.9, COST_PROBE_THICKNESS, cell_size * 0.9)
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.collision_mask = CollisionLayers.Layer.WORLD
    query.collide_with_areas = false
    var half: float = arena_size * 0.5
    var blocked: int = 0
    var steps: int = int(ceili(arena_size / cell_size))
    for x_index: int in range(steps):
        for z_index: int in range(steps):
            var world := Vector3(
                -half + (float(x_index) + 0.5) * cell_size,
                COST_PROBE_HEIGHT,
                -half + (float(z_index) + 0.5) * cell_size
            )
            query.transform = Transform3D(Basis.IDENTITY, world)
            if space.intersect_shape(query, 1).is_empty():
                continue
            _flow.set_cost(_flow.get_cell(world), FlowField.COST_WALL)
            blocked += 1
    return blocked


func _configure_types() -> void:
    _types.clear()
    for id: StringName in enemy_ids:
        var data: EnemyData = ContentDB.get_enemy(id)
        if data == null or data.execution_path != 0:
            continue
        _types.append(data)
        _movement.configure_type(data)
        _combat.configure_type(
            data.swarm_type_id,
            data.attack_range,
            data.contact_damage,
            data.attack_cooldown_seconds
        )
        if data.swarm_mesh != null:
            renderer.configure_type(data.swarm_type_id, data.swarm_mesh, data.swarm_material)


## SwarmCombat gọi khi một đơn vị đánh trúng mục tiêu. Sát thương đi qua
## DamageResolver như mọi nguồn khác (TDD §8.2).
func _on_swarm_melee_hit(amount: float, source_position: Vector3, source_id: int) -> void:
    if _target == null:
        return
    var info: DamageInfo = PoolManager.get_damage_info()
    info.amount = amount
    info.type = DamageTypes.Type.KINETIC
    info.source_position = source_position
    info.source_id = source_id
    DamageResolver.resolve(info, _target)
    PoolManager.release_damage_info(info)
    player_hit.emit(amount, source_position)
