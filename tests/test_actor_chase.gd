extends GutTest

const ACTOR_SCENE: PackedScene = preload("res://scenes/enemies/actors/actor_base.tscn")

func _field() -> FlowField:
    var field := FlowField.new()
    field.configure(AABB(Vector3(-10, -1, -10), Vector3(20, 2, 20)), 1.0)
    field.rebuild(Vector3(8, 0, 0))
    return field

func _actor(position: Vector3, field: FlowField, target: Node3D) -> ActorEnemy:
    var actor := add_child_autofree(ACTOR_SCENE.instantiate()) as ActorEnemy
    var data := EnemyData.new()
    data.execution_path = 1
    data.move_speed = 6.0
    data.attack_range = 2.0
    actor.configure(data)
    actor.global_position = position
    actor.set_context(field, target)
    actor._on_acquired()
    actor.state_machine.transition_to(&"Chase")
    return actor

func test_chase_samples_flow_field_and_moves_toward_target() -> void:
    var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
    target.global_position = Vector3(8, 0, 0)
    var actor := _actor(Vector3.ZERO, _field(), target)
    actor.state_machine.current_state.physics_update(0.1)
    assert_gt(actor.velocity.x, 0.0)
    assert_gt(actor.global_position.x, 0.0)

func test_chase_decelerates_inside_arrival_range_without_jitter() -> void:
    var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
    target.global_position = Vector3(1, 0, 0)
    var actor := _actor(Vector3.ZERO, _field(), target)
    actor.velocity = Vector3(4, 0, 0)
    actor.state_machine.current_state.physics_update(0.1)
    assert_eq(actor.velocity, Vector3(2, 0, 0))
    actor.state_machine.current_state.physics_update(0.1)
    assert_eq(actor.velocity, Vector3.ZERO)

func test_chase_separates_from_nearby_actor() -> void:
    var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
    target.global_position = Vector3(8, 0, 0)
    var field := _field()
    var actor := _actor(Vector3.ZERO, field, target)
    var neighbour := _actor(Vector3(0, 0, 0.5), field, target)
    var separation: Vector3 = actor.state_machine.current_state._separation()
    assert_lt(separation.z, 0.0)
    neighbour._on_released()
