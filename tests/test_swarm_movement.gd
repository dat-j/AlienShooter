extends GutTest

const SwarmMovementScript: GDScript = preload("res://src/swarm/swarm_movement.gd")

var _swarm: SwarmManager
var _flow: FlowField
var _movement: RefCounted


func before_each() -> void:
    _swarm = SwarmManager.new()
    _flow = FlowField.new()
    _movement = SwarmMovementScript.new()
    _flow.configure(AABB(Vector3(-10.0, -1.0, -10.0), Vector3(20.0, 2.0, 20.0)), 1.0)
    _flow.rebuild(Vector3(8.0, 0.0, 0.0))
    add_child_autofree(_swarm)


func test_flow_field_keo_swarm_ve_muc_tieu() -> void:
    _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 10.0, 0)

    for frame: int in range(30):
        _movement.update(_swarm, _flow, 1.0 / 60.0)

    assert_gt(_swarm._positions[0].x, 0.5, "đơn vị phải tiến theo flow field")
    assert_gt(_swarm._velocities[0].x, 0.0)


func test_separation_day_hai_don_vi_ra_xa_nhau() -> void:
    _movement.max_speed = 2.0
    _movement.acceleration = 30.0
    _swarm.spawn(Vector3(-0.1, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    _swarm.spawn(Vector3(0.1, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    var start_distance: float = _swarm._positions[0].distance_to(_swarm._positions[1])

    for frame: int in range(20):
        _movement.update(_swarm, _flow, 1.0 / 60.0)

    assert_gt(_swarm._positions[0].distance_to(_swarm._positions[1]), start_distance)


func test_khong_di_vao_o_tuong() -> void:
    _flow.set_cost(Vector2i(11, 10), FlowField.COST_WALL)
    _flow.rebuild(Vector3(8.0, 0.0, 0.0))
    _swarm.spawn(Vector3(0.4, 0.0, 0.4), Vector3(4.0, 0.0, 0.0), 10.0, 0)

    for frame: int in range(30):
        _movement.update(_swarm, _flow, 1.0 / 60.0)

    assert_true(_flow.is_walkable(_swarm._positions[0]), "đơn vị không được tích phân vào tường")


func test_grid_dong_bo_spawn_kill_va_move() -> void:
    var first: int = _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 10.0, 0)
    var second: int = _swarm.spawn(Vector3.ONE, Vector3.ZERO, 10.0, 0)
    _movement.update(_swarm, _flow, 0.016)
    assert_eq(_movement.get_grid().get_entity_count(), 2)

    _swarm.kill(first)
    _movement.update(_swarm, _flow, 0.016)
    assert_eq(_movement.get_grid().get_entity_count(), 1)
    var results: PackedInt32Array = PackedInt32Array()
    results.resize(4)
    var count: int = _movement.get_grid().query_radius(_swarm._positions[0], 0.5, results)
    assert_eq(count, 1)
    assert_eq(results[0], second)


func test_jitter_on_dinh_theo_id() -> void:
    var first: Vector3 = _movement._stable_jitter(42)
    assert_eq(first, _movement._stable_jitter(42))
    assert_ne(first, _movement._stable_jitter(43))
