class_name AIStateMachine
extends Node

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: StringName = &"Idle"

var actor: ActorEnemy
var current_state: AIState
var current_state_name: StringName = &""
var _states: Dictionary = {}


func _ready() -> void:
    actor = get_parent() as ActorEnemy
    rebuild_states()
    if not initial_state.is_empty():
        transition_to(initial_state)


func _physics_process(delta: float) -> void:
    if current_state != null:
        current_state.physics_update(delta)


func rebuild_states() -> void:
    _states.clear()
    for child: Node in get_children():
        if child is AIState:
            var state := child as AIState
            state.setup(actor, self)
            _states[child.name] = state


func transition_to(next_name: StringName) -> bool:
    if not _states.has(next_name) or next_name == current_state_name:
        return false
    var previous := current_state_name
    if current_state != null:
        current_state.exit(next_name)
    current_state = _states[next_name] as AIState
    current_state_name = next_name
    current_state.enter(previous)
    if Log != null:
        Log.debug("AI %s: %s → %s" % [actor.name if actor != null else "Actor", previous, next_name], "AIStateMachine")
    state_changed.emit(previous, next_name)
    return true


func has_state(state_name: StringName) -> bool:
    return _states.has(state_name)


func reset() -> void:
    if current_state != null:
        current_state.exit(initial_state)
    current_state = null
    current_state_name = &""
    if not initial_state.is_empty():
        transition_to(initial_state)
