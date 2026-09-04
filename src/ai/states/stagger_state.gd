class_name StaggerState
extends AIState

func enter(_previous_state: StringName = &"") -> void:
    if actor != null:
        actor.velocity = Vector3.ZERO
