extends GutTest

## Sân tập chơi được: swarm đuổi và đánh được người chơi, người chơi bắn chết
## được swarm, chết thì hồi sinh. Giàn giáo tạm cho tới khi có SpawnDirector
## thật (T-802).

const ARENA_SCENE: PackedScene = preload("res://scenes/main/test_arena.tscn")

var _arena: ArenaDemo
var _mech: MechController
var _swarm: SwarmRuntime


func before_each() -> void:
    _arena = add_child_autofree(ARENA_SCENE.instantiate()) as ArenaDemo
    _mech = _arena.get_node("Mech") as MechController
    _swarm = _arena.get_node("SwarmRuntime") as SwarmRuntime


func test_arena_wires_mech_to_the_swarm_systems() -> void:
    assert_not_null(_swarm, "sân tập phải có SwarmRuntime")
    assert_same(_mech.boost_component.swarm_manager, _swarm.manager, "Boost phải biết swarm")
    assert_same(_mech.weapon_mount_left.swarm_manager, _swarm.manager, "vũ khí trái phải biết swarm")
    assert_same(_mech.weapon_mount_right.swarm_manager, _swarm.manager, "vũ khí phải phải biết swarm")


func test_three_swarm_types_are_configured_for_rendering() -> void:
    assert_eq(_swarm.get_enemy_types().size(), 3, "phải nạp đủ Crawler, Skitter, Husk")
    assert_eq(_swarm.renderer.get_configured_type_count(), 3, "mỗi loại một MultiMeshInstance3D")


func test_wave_spawns_units_around_the_player() -> void:
    var spawned: int = _arena.spawn_wave()
    assert_gt(spawned, 0, "một đợt phải đổ ra ít nhất một con")
    assert_eq(_swarm.get_alive_count(), spawned)
    for index: int in range(spawned):
        var distance: float = _swarm.manager._positions[index].distance_to(_mech.global_position)
        assert_between(distance, _arena.spawn_radius_min - 1.0, _arena.spawn_radius_max + 1.0,
            "quái phải sinh trong vành đai quanh người chơi")


func test_wave_respects_the_alive_cap() -> void:
    _arena.max_alive = 5
    _arena.units_per_wave = 20
    assert_eq(_arena.spawn_wave(), 5, "không vượt trần số quái sống")
    assert_eq(_arena.spawn_wave(), 0, "đã đầy thì không đổ thêm")


func test_flow_field_marks_pillars_as_walls() -> void:
    var field: FlowField = _swarm.get_flow_field()
    assert_false(field.is_walkable(Vector3(-9.0, 0.0, 9.0)), "ô có cột phải là tường")
    assert_false(field.is_walkable(Vector3(0.0, 0.0, 29.5)), "ô sát tường phải là tường")
    assert_true(field.is_walkable(Vector3(2.0, 0.0, 2.0)), "giữa sân phải đi được")


func test_swarm_melee_damages_the_player_through_the_resolver() -> void:
    var crawler: EnemyData = ContentDB.get_enemy(&"enm_crawler")
    _swarm.spawn_unit(crawler, _mech.global_position + Vector3(0.0, 0.0, -1.0))
    var armor_before: float = _mech.armor_component.get_plate(ArmorComponent.Zone.FRONT)
    _swarm._physics_process(0.1)
    assert_lt(_mech.armor_component.get_plate(ArmorComponent.Zone.FRONT), armor_before,
        "con swarm đứng sát phải cắn trúng giáp trước")


func test_swarm_moves_toward_the_player() -> void:
    var crawler: EnemyData = ContentDB.get_enemy(&"enm_crawler")
    var id: int = _swarm.spawn_unit(crawler, _mech.global_position + Vector3(0.0, 0.0, -12.0))
    var index: int = _swarm.manager._index_by_id[id]
    var before: float = _swarm.manager._positions[index].distance_to(_mech.global_position)
    for _i: int in range(10):
        _swarm._physics_process(1.0 / 60.0)
    var after: float = _swarm.manager._positions[_swarm.manager._index_by_id[id]].distance_to(_mech.global_position)
    assert_lt(after, before, "swarm phải đuổi theo người chơi")


func test_player_shots_kill_swarm_units() -> void:
    var crawler: EnemyData = ContentDB.get_enemy(&"enm_crawler")
    var victim_position: Vector3 = _mech.global_position + Vector3(0.0, 0.25, -8.0)
    _swarm.spawn_unit(crawler, victim_position)
    var aim: Vector3 = victim_position
    var before: float = _swarm.manager._healths[0]
    _mech.weapon_mount_left.update(0.02, true, null, aim)
    for root: Node in [get_tree().current_scene, get_tree().root]:
        if root == null:
            continue
        for child: Node in root.get_children():
            var projectile := child as Projectile
            if projectile != null and projectile.is_flying():
                projectile._physics_process(0.2)
                PoolManager.release(projectile)
    assert_lt(_swarm.manager._healths[0], before, "đạn của người chơi phải trừ máu swarm")


func test_player_death_triggers_a_respawn() -> void:
    watch_signals(_arena)
    _arena.spawn_wave()
    _mech.core_hp = 0.0
    _mech.notify_core_changed()
    _arena._physics_process(_arena.respawn_delay_seconds + 0.1)
    assert_signal_emitted(_arena, "player_respawned")
    assert_eq(_mech.core_hp, _mech.chassis_data.core_hp, "hồi sinh phải đầy Core HP")
    assert_eq(_mech.armor_component.get_plate(ArmorComponent.Zone.FRONT), 60.0, "giáp cũng hồi lại")
    assert_eq(_swarm.get_alive_count(), 0, "hồi sinh thì dọn sạch swarm")
