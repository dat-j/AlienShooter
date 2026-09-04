class_name DeathState
extends AIState

func enter(_previous_state: StringName = &"") -> void:
    if actor != null:
        actor.velocity = Vector3.ZERO
        actor.hitbox.monitoring = false
        actor.hurtbox.monitoring = false
