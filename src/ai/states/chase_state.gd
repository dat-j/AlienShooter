class_name ChaseState
extends AIState

## Di chuyển actor bằng cùng FlowField với swarm; CharacterBody3D xử lý va
## chạm vật lý, còn các probe trên trường chi phí giúp bẻ lái trước tường.
@export var acceleration: float = 20.0
@export var separation_radius: float = 1.75
@export var separation_weight: float = 0.65
@export var wall_probe_distance: float = 1.0
@export var wall_weight: float = 0.9
@export var arrival_margin: float = 0.35

const _WALL_PROBES: Array[Vector3] = [
    Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK
]


func enter(_previous_state: StringName = &"") -> void:
    if actor != null:
        actor.add_to_group(&"actor_enemies")


func physics_update(delta: float) -> void:
    if actor == null or actor.enemy_data == null or delta <= 0.0:
        return
    if not is_instance_valid(actor.target):
        actor.velocity = actor.velocity.move_toward(Vector3.ZERO, acceleration * delta)
        actor.move_and_slide()
        return

    var target_offset: Vector3 = actor.target.global_position - actor.global_position
    target_offset.y = 0.0
    var stop_distance: float = actor.enemy_data.attack_range + arrival_margin
    if target_offset.length_squared() <= stop_distance * stop_distance:
        # Giảm tốc trước khi vào Attack để tránh rung lắc quanh mục tiêu.
        actor.velocity = actor.velocity.move_toward(Vector3.ZERO, acceleration * delta)
        actor.move_and_slide()
        if actor.attack_cooldown_remaining <= 0.0:
            machine.transition_to(&"Attack")
        return

    if actor.flow_field == null:
        actor.velocity = actor.velocity.move_toward(Vector3.ZERO, acceleration * delta)
        actor.move_and_slide()
        return

    var sampled: Vector2 = actor.flow_field.sample_direction(actor.global_position)
    var flow_direction := Vector3(sampled.x, 0.0, sampled.y)
    var steering: Vector3 = (
        flow_direction
        + _separation() * separation_weight
        + _wall_avoidance() * wall_weight
    )
    var desired := Vector3.ZERO
    if steering.length_squared() > 0.0001:
        desired = steering.normalized() * actor.enemy_data.move_speed
    actor.velocity = actor.velocity.move_toward(desired, acceleration * delta)
    actor.velocity.y = 0.0
    actor.move_and_slide()


func _separation() -> Vector3:
    var force := Vector3.ZERO
    var radius_sq: float = separation_radius * separation_radius
    for other_node: Node in actor.get_tree().get_nodes_in_group(&"actor_enemies"):
        var other := other_node as ActorEnemy
        if other == null or other == actor or not other.is_active():
            continue
        var offset: Vector3 = actor.global_position - other.global_position
        offset.y = 0.0
        var distance_sq: float = offset.length_squared()
        if distance_sq > 0.0001 and distance_sq < radius_sq:
            force += offset.normalized() * (1.0 - sqrt(distance_sq) / separation_radius)
    return force.normalized() if force.length_squared() > 0.0001 else Vector3.ZERO


func _wall_avoidance() -> Vector3:
    var force := Vector3.ZERO
    for direction: Vector3 in _WALL_PROBES:
        if not actor.flow_field.is_walkable(
            actor.global_position + direction * wall_probe_distance
        ):
            force -= direction
    return force.normalized() if force.length_squared() > 0.0001 else Vector3.ZERO
