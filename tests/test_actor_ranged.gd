extends GutTest

## T-406 — đòn tầm xa của actor: ngắm có thời gian kèm tia laser báo trước,
## đạn lấy từ PoolManager, giữ khoảng cách ưa thích và tách khỏi actor khác.

const ACTOR_SCENE: PackedScene = preload("res://scenes/enemies/actors/actor_base.tscn")
const STUB_PROJECTILE: GDScript = preload("res://tests/stub_projectile.gd")

var _projectile_scene: PackedScene


func before_each() -> void:
    var root := Node3D.new()
    root.set_script(STUB_PROJECTILE)
    _projectile_scene = PackedScene.new()
    _projectile_scene.pack(root)
    root.free()


func after_each() -> void:
    PoolManager.clear_pool(_projectile_scene)


func _make_data() -> EnemyData:
    var data := EnemyData.new()
    data.id = &"enm_test_spitter"
    data.execution_path = 1
    data.max_hp = 60.0
    data.move_speed = 3.5
    data.attack_range = 2.0
    data.ranged_attack_range = 14.0
    data.ranged_damage = 14.0
    data.ranged_damage_type = DamageTypes.Type.ACID
    data.ranged_aim_seconds = 0.9
    data.ranged_recovery_seconds = 0.4
    data.ranged_cooldown_seconds = 2.0
    data.preferred_distance = 10.0
    data.projectile_scene = _projectile_scene
    data.projectile_speed = 25.0
    return data


func _make_actor(target_distance: float) -> ActorEnemy:
    var actor := add_child_autofree(ACTOR_SCENE.instantiate()) as ActorEnemy
    actor.configure(_make_data())
    actor._on_acquired()
    actor.global_position = Vector3.ZERO
    var target := add_child_autofree(Node3D.new()) as Node3D
    target.global_position = Vector3(0.0, 0.0, -target_distance)
    actor.target = target
    return actor


func _ranged_state(actor: ActorEnemy) -> RangedAttackState:
    return actor.state_machine.get_node("RangedAttack") as RangedAttackState


func test_aim_phase_reads_enemy_data_and_shows_telegraph_laser() -> void:
    var actor := _make_actor(10.0)
    var ranged := _ranged_state(actor)
    watch_signals(ranged)
    actor.state_machine.transition_to(&"RangedAttack")
    assert_eq(ranged.phase, RangedAttackState.Phase.AIM, "phải bắt đầu ở pha ngắm")
    assert_eq(ranged.phase_remaining, 0.9, "thời gian ngắm phải đọc từ EnemyData")
    assert_signal_emitted_with_parameters(ranged, "telegraph_started", [0.9])
    assert_true(ranged.is_telegraph_visible(), "tia laser báo trước phải hiện khi đang ngắm")


func test_telegraph_laser_hidden_after_shot() -> void:
    var actor := _make_actor(10.0)
    var ranged := _ranged_state(actor)
    actor.state_machine.transition_to(&"RangedAttack")
    watch_signals(ranged)
    ranged.physics_update(0.9)
    assert_signal_emitted(ranged, "telegraph_finished")
    assert_false(ranged.is_telegraph_visible(), "tia laser phải tắt ngay khi bắn")
    PoolManager.release((get_signal_parameters(ranged, "projectile_fired")[0]) as Node)


func test_shot_uses_projectile_from_pool_with_enemy_data_values() -> void:
    var actor := _make_actor(10.0)
    var ranged := _ranged_state(actor)
    watch_signals(ranged)
    actor.state_machine.transition_to(&"RangedAttack")
    ranged.physics_update(0.9)
    assert_true(ranged.has_fired(), "hết thời gian ngắm phải bắn ra một viên")
    var params: Array = get_signal_parameters(ranged, "projectile_fired")
    var projectile: Node = params[0] as Node
    assert_not_null(projectile, "phải phát projectile_fired kèm viên đạn")
    assert_eq(projectile.launch_count, 1, "viên đạn phải được launch() đúng một lần")
    assert_eq(projectile.last_damage, 14.0, "sát thương lấy từ EnemyData")
    assert_eq(projectile.last_speed, 25.0, "tốc độ đạn lấy từ EnemyData")
    assert_eq(projectile.last_damage_type, DamageTypes.Type.ACID, "loại sát thương lấy từ EnemyData")
    assert_almost_eq(projectile.last_direction.z, -1.0, 0.01, "đạn phải bay về phía mục tiêu")
    assert_same(projectile.last_source, actor, "nguồn sát thương là actor bắn")
    PoolManager.release(projectile)


func test_second_shot_reuses_pooled_projectile_without_new_instantiate() -> void:
    var actor := _make_actor(10.0)
    var ranged := _ranged_state(actor)
    watch_signals(ranged)
    actor.state_machine.transition_to(&"RangedAttack")
    ranged.physics_update(0.9)
    var first: Node = (get_signal_parameters(ranged, "projectile_fired")[0]) as Node
    PoolManager.release(first)
    var count_after_first: int = PoolManager._instantiate_count

    ranged.physics_update(0.4)
    actor.attack_cooldown_remaining = 0.0
    actor.state_machine.transition_to(&"RangedAttack")
    ranged.physics_update(0.9)
    var second: Node = (get_signal_parameters(ranged, "projectile_fired")[0]) as Node

    assert_same(second, first, "phát thứ hai phải tái dùng viên đạn đã trả về pool")
    assert_eq(PoolManager._instantiate_count, count_after_first, "không được instantiate() thêm khi pool còn đạn rảnh")
    PoolManager.release(second)


func test_backs_off_when_target_closer_than_preferred_distance() -> void:
    var actor := _make_actor(4.0)
    var ranged := _ranged_state(actor)
    actor.state_machine.transition_to(&"RangedAttack")
    ranged.physics_update(0.1)
    assert_gt(actor.velocity.z, 0.0, "mục tiêu ở −Z quá gần thì actor phải lùi về +Z")


func test_closes_in_when_target_beyond_preferred_distance() -> void:
    var actor := _make_actor(13.0)
    var ranged := _ranged_state(actor)
    actor.state_machine.transition_to(&"RangedAttack")
    ranged.physics_update(0.1)
    assert_lt(actor.velocity.z, 0.0, "xa hơn khoảng cách ưa thích thì actor phải tiến lại gần")


func test_holds_position_at_preferred_distance() -> void:
    var actor := _make_actor(10.0)
    var ranged := _ranged_state(actor)
    actor.state_machine.transition_to(&"RangedAttack")
    ranged.physics_update(0.1)
    assert_almost_eq(actor.velocity.length(), 0.0, 0.001, "đúng khoảng cách ưa thích thì đứng yên ngắm")


func test_separates_from_nearby_ranged_actor() -> void:
    var actor := _make_actor(10.0)
    var neighbour := _make_actor(10.0)
    neighbour.global_position = Vector3(0.0, 0.0, 1.2)
    actor.state_machine.transition_to(&"RangedAttack")
    neighbour.state_machine.transition_to(&"RangedAttack")
    var separation: Vector3 = _ranged_state(actor)._separation()
    assert_lt(separation.z, 0.0, "actor phải bị đẩy ra xa đồng loại đứng sát sau lưng")
    neighbour._on_released()


func test_stagger_cancels_aim_without_firing() -> void:
    var actor := _make_actor(10.0)
    var ranged := _ranged_state(actor)
    actor.state_machine.transition_to(&"RangedAttack")
    ranged.physics_update(0.5)
    assert_true(ranged.cancel_for_stagger(), "đang ngắm phải huỷ được sang Stagger")
    assert_eq(actor.state_machine.current_state_name, &"Stagger")
    assert_false(ranged.has_fired(), "huỷ giữa lúc ngắm thì không được bắn")
    assert_false(ranged.is_telegraph_visible(), "huỷ đòn phải tắt tia laser")


func test_recovery_sets_cooldown_and_returns_to_chase() -> void:
    var actor := _make_actor(10.0)
    var ranged := _ranged_state(actor)
    watch_signals(ranged)
    actor.state_machine.transition_to(&"RangedAttack")
    ranged.physics_update(0.9)
    assert_eq(ranged.phase, RangedAttackState.Phase.RECOVERY, "bắn xong phải vào pha hồi")
    ranged.physics_update(0.4)
    assert_eq(actor.state_machine.current_state_name, &"Chase", "hồi xong phải quay lại Chase")
    assert_eq(actor.attack_cooldown_remaining, 2.0, "hồi chiêu tầm xa lấy từ EnemyData")
    PoolManager.release((get_signal_parameters(ranged, "projectile_fired")[0]) as Node)


func test_aim_aborts_when_target_leaves_ranged_range() -> void:
    var actor := _make_actor(10.0)
    var ranged := _ranged_state(actor)
    actor.state_machine.transition_to(&"RangedAttack")
    actor.target.global_position = Vector3(0.0, 0.0, -20.0)
    ranged.physics_update(0.1)
    assert_eq(actor.state_machine.current_state_name, &"Chase", "mục tiêu ra ngoài tầm thì bỏ ngắm")
    assert_false(ranged.has_fired(), "bỏ ngắm thì không bắn")


func test_chase_hands_off_to_ranged_attack_only_when_cooldown_ready() -> void:
    var actor := _make_actor(12.0)
    var machine := actor.state_machine as AIStateMachine
    actor.attack_cooldown_remaining = 1.0
    machine.transition_to(&"Chase")
    machine.current_state.physics_update(0.1)
    assert_eq(machine.current_state_name, &"Chase", "còn hồi chiêu thì chưa vào ngắm")
    actor.attack_cooldown_remaining = 0.0
    machine.current_state.physics_update(0.1)
    assert_eq(machine.current_state_name, &"RangedAttack", "trong tầm và hết hồi chiêu thì vào ngắm")
