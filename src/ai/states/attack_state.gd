class_name AttackState
extends AIState

## Cận chiến theo ba pha dữ liệu: ngắm/báo trước -> hitbox hoạt động -> hồi.
enum Phase { WINDUP, ACTIVE, RECOVERY }

signal phase_changed(phase: Phase)
signal telegraph_started(duration: float)
signal telegraph_finished

var phase: Phase = Phase.WINDUP
var phase_remaining: float = 0.0


func enter(_previous_state: StringName = &"") -> void:
    if actor == null or actor.enemy_data == null:
        return
    actor.velocity = Vector3.ZERO
    actor.hitbox.damage = actor.enemy_data.contact_damage
    actor.hitbox.damage_type = actor.enemy_data.contact_damage_type
    _set_phase(Phase.WINDUP, actor.enemy_data.attack_windup_seconds)
    telegraph_started.emit(phase_remaining)


func exit(_next_state: StringName = &"") -> void:
    # Bất kỳ chuyển trạng thái nào (đặc biệt Stagger) đều huỷ đòn an toàn.
    if actor != null:
        actor.hitbox.close_window()
    if phase == Phase.WINDUP:
        telegraph_finished.emit()
    phase_remaining = 0.0


func physics_update(delta: float) -> void:
    if actor == null or actor.enemy_data == null or delta <= 0.0:
        return
    actor.velocity = Vector3.ZERO
    if not is_instance_valid(actor.target):
        machine.transition_to(&"Chase")
        return
    if phase == Phase.WINDUP:
        _aim_at_target()
        if not _is_target_in_range():
            machine.transition_to(&"Chase")
            return
    phase_remaining -= delta
    while phase_remaining <= 0.0 and machine.current_state == self:
        var overflow: float = -phase_remaining
        match phase:
            Phase.WINDUP:
                telegraph_finished.emit()
                actor.hitbox.open_window()
                _set_phase(Phase.ACTIVE, actor.enemy_data.attack_active_seconds)
            Phase.ACTIVE:
                actor.hitbox.close_window()
                _set_phase(Phase.RECOVERY, actor.enemy_data.attack_recovery_seconds)
            Phase.RECOVERY:
                actor.attack_cooldown_remaining = actor.enemy_data.attack_cooldown_seconds
                machine.transition_to(&"Chase")
                return
        phase_remaining -= overflow


func cancel_for_stagger() -> bool:
    if machine == null or not machine.has_state(&"Stagger"):
        return false
    return machine.transition_to(&"Stagger")


func _set_phase(next_phase: Phase, duration: float) -> void:
    phase = next_phase
    phase_remaining = maxf(0.0, duration)
    phase_changed.emit(phase)


func _is_target_in_range() -> bool:
    var offset: Vector3 = actor.target.global_position - actor.global_position
    offset.y = 0.0
    return offset.length_squared() <= actor.enemy_data.attack_range * actor.enemy_data.attack_range


func _aim_at_target() -> void:
    var target_position: Vector3 = actor.target.global_position
    target_position.y = actor.global_position.y
    if actor.global_position.distance_squared_to(target_position) > 0.0001:
        actor.look_at(target_position, Vector3.UP)
