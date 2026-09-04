extends GutTest

const ACTOR_SCENE: PackedScene = preload("res://scenes/enemies/actors/actor_base.tscn")

func _make_actor() -> CharacterBody3D:
    return add_child_autofree(ACTOR_SCENE.instantiate()) as CharacterBody3D

func test_base_states_are_registered_and_idle_is_initial() -> void:
    var actor := _make_actor()
    var machine: Node = actor.get_node("StateMachine")
    assert_true(machine.has_state(&"Idle"))
    assert_true(machine.has_state(&"Chase"))
    assert_true(machine.has_state(&"Attack"))
    assert_true(machine.has_state(&"Stagger"))
    assert_true(machine.has_state(&"Death"))
    assert_eq(machine.current_state_name, &"Idle")

func test_transition_calls_exit_enter_and_emits_signal() -> void:
    var actor := _make_actor()
    var machine: Node = actor.get_node("StateMachine")
    watch_signals(machine)
    assert_true(machine.transition_to(&"Chase"))
    assert_eq(machine.current_state_name, &"Chase")
    assert_signal_emitted_with_parameters(machine, "state_changed", [&"Idle", &"Chase"])

func test_invalid_and_same_transition_are_rejected() -> void:
    var actor := _make_actor()
    var machine: Node = actor.get_node("StateMachine")
    assert_false(machine.transition_to(&"Missing"))
    assert_false(machine.transition_to(&"Idle"))
    assert_eq(machine.current_state_name, &"Idle")

func test_reset_returns_to_initial_state() -> void:
    var actor := _make_actor()
    var machine: Node = actor.get_node("StateMachine")
    machine.transition_to(&"Death")
    machine.reset()
    assert_eq(machine.current_state_name, &"Idle")
