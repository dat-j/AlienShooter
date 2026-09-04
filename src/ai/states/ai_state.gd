class_name AIState
extends Node

## Lớp cơ sở nhẹ cho mọi trạng thái actor.
var actor: ActorEnemy
var machine: AIStateMachine


func setup(owner_actor: ActorEnemy, owner_machine: AIStateMachine) -> void:
    actor = owner_actor
    machine = owner_machine


func enter(_previous_state: StringName = &"") -> void:
    pass


func exit(_next_state: StringName = &"") -> void:
    pass


func physics_update(_delta: float) -> void:
    pass
