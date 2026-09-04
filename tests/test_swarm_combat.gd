extends GutTest

var _swarm: SwarmManager
var _movement: SwarmMovement
var _combat: SwarmCombat
var _received_damage: float
var _received_sources: PackedInt32Array


func before_each() -> void:
    _swarm = SwarmManager.new()
    _movement = SwarmMovement.new()
    _combat = SwarmCombat.new()
    _received_damage = 0.0
    _received_sources = PackedInt32Array()
    add_child_autofree(_swarm)


func test_don_vi_trong_tam_gay_sat_thuong() -> void:
    var id: int = _swarm.spawn(Vector3(0.5, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    _sync_grid()

    var hits: int = _combat.update_melee(_swarm, _movement.get_grid(), Vector3.ZERO, 0.016, _receive_damage)

    assert_eq(hits, 1)
    assert_eq(_received_damage, SwarmCombat.DEFAULT_ATTACK_DAMAGE)
    assert_eq(_received_sources[0], id)


func test_don_vi_ngoai_tam_khong_gay_sat_thuong() -> void:
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    _sync_grid()
    assert_eq(_combat.update_melee(_swarm, _movement.get_grid(), Vector3.ZERO, 0.016, _receive_damage), 0)
    assert_eq(_received_damage, 0.0)


func test_hoi_chieu_chan_tan_cong_lap_lai() -> void:
    _combat.configure_type(2, 2.0, 7.0, 0.5)
    _swarm.spawn(Vector3(0.5, 0.0, 0.0), Vector3.ZERO, 10.0, 2)
    _sync_grid()

    assert_eq(_combat.update_melee(_swarm, _movement.get_grid(), Vector3.ZERO, 0.0, _receive_damage), 1)
    assert_eq(_combat.update_melee(_swarm, _movement.get_grid(), Vector3.ZERO, 0.49, _receive_damage), 0)
    assert_eq(_combat.update_melee(_swarm, _movement.get_grid(), Vector3.ZERO, 0.01, _receive_damage), 1)
    assert_eq(_received_damage, 14.0)


func test_moi_don_vi_co_hoi_chieu_rieng() -> void:
    _swarm.spawn(Vector3(0.4, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    _swarm.spawn(Vector3(-0.4, 0.0, 0.0), Vector3.ZERO, 10.0, 0, SwarmManager.STATE_ALIVE, 0.5)
    _sync_grid()

    assert_eq(_combat.update_melee(_swarm, _movement.get_grid(), Vector3.ZERO, 0.1, _receive_damage), 1)


func test_boost_day_lui_don_vi_trong_ban_kinh() -> void:
    _swarm.spawn(Vector3(0.2, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    _sync_grid()

    var count: int = _combat.apply_boost_collision(
        _swarm, _movement.get_grid(), Vector3.ZERO, Vector3.RIGHT, 1.0, 12.0
    )

    assert_eq(count, 1)
    assert_eq(_swarm._velocities[0], Vector3(12.0, 0.0, 0.0))
    assert_eq(_swarm._velocities[1], Vector3.ZERO)


func test_boost_huong_zero_la_no_op() -> void:
    _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 10.0, 0)
    _sync_grid()
    assert_eq(_combat.apply_boost_collision(_swarm, _movement.get_grid(), Vector3.ZERO, Vector3.ZERO), 0)


func _sync_grid() -> void:
    _movement._sync_grid(_swarm)


func _receive_damage(amount: float, _source_position: Vector3, source_id: int) -> void:
    _received_damage += amount
    _received_sources.append(source_id)
