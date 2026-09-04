class_name IdleState
extends AIState

func enter(_previous_state: StringName = &"") -> void:
    if actor != null:
        actor.velocity = Vector3.ZERO
