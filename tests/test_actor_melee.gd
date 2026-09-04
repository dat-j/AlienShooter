extends GutTest

const ACTOR_SCENE: PackedScene = preload("res://scenes/enemies/actors/actor_base.tscn")

func _make_actor() -> ActorEnemy:
    var actor := add_child_autofree(ACTOR_SCENE.instantiate()) as ActorEnemy
    var data := EnemyData.new()
    data.execution_path = 1
    data.contact_damage = 13.0
    data.attack_range = 2.0
    data.attack_windup_seconds = 0.3
    data.attack_active_seconds = 0.2
    data.attack_recovery_seconds = 0.4
    data.attack_cooldown_seconds = 0.8
    actor.configure(data)
    actor._on_acquired()
    actor.target = add_child_autofree(Node3D.new()) as Node3D
    actor.target.global_position = Vector3(0.0, 0.0, -1.0)
    return actor


func test_attack_uses_enemy_data_for_three_phases() -> void:
    var actor := _make_actor()
    var machine := actor.state_machine as AIStateMachine
    machine.transition_to(&"Attack")
    var attack := machine.current_state as AttackState
    assert_eq(attack.phase, AttackState.Phase.WINDUP)
    assert_eq(attack.phase_remaining, 0.3)
    attack.physics_update(0.3)
    assert_eq(attack.phase, AttackState.Phase.ACTIVE)
    assert_true(actor.hitbox.is_window_active())
    attack.physics_update(0.2)
    assert_eq(attack.phase, AttackState.Phase.RECOVERY)
    assert_false(actor.hitbox.is_window_active())
    attack.physics_update(0.4)
    assert_eq(machine.current_state_name, &"Chase")
    assert_eq(actor.attack_cooldown_remaining, 0.8)


func test_windup_emits_clear_telegraph_signal() -> void:
    var actor := _make_actor()
    var attack := actor.state_machine.get_node("Attack") as AttackState
    watch_signals(attack)
    actor.state_machine.transition_to(&"Attack")
    assert_signal_emitted_with_parameters(attack, "telegraph_started", [0.3])
    attack.physics_update(0.3)
    assert_signal_emitted(attack, "telegraph_finished")


func test_stagger_cancels_attack_and_disables_hitbox() -> void:
    var actor := _make_actor()
    var machine := actor.state_machine as AIStateMachine
    machine.transition_to(&"Attack")
    var attack := machine.current_state as AttackState
    attack.physics_update(0.3)
    assert_true(actor.hitbox.is_window_active())
    assert_true(attack.cancel_for_stagger())
    assert_eq(machine.current_state_name, &"Stagger")
    assert_false(actor.hitbox.is_window_active())


func test_chase_enters_attack_only_when_cooldown_ready() -> void:
    var actor := _make_actor()
    var machine := actor.state_machine as AIStateMachine
    actor.attack_cooldown_remaining = 0.5
    machine.transition_to(&"Chase")
    machine.current_state.physics_update(0.1)
    assert_eq(machine.current_state_name, &"Chase")
    actor.attack_cooldown_remaining = 0.0
    machine.current_state.physics_update(0.1)
    assert_eq(machine.current_state_name, &"Attack")
