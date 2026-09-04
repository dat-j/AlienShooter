class_name RangedAttackState
extends AIState

## Đòn tầm xa hai pha đọc từ `EnemyData`: NGẮM (có tia laser báo trước, actor
## vừa ngắm vừa chỉnh khoảng cách) rồi HỒI. Viên đạn lấy từ `PoolManager`,
## không bao giờ `instantiate()`. Xem docs/02-TDD.md §8.3 và §12.
enum Phase { AIM, RECOVERY }

signal phase_changed(phase: Phase)
signal telegraph_started(duration: float)
signal telegraph_finished
signal projectile_fired(projectile: Node)

@export var laser_path: NodePath = NodePath("../../Model/AimLaser")
@export var acceleration: float = 14.0
@export var reposition_speed_scale: float = 0.85
@export var distance_tolerance: float = 1.0
@export var separation_radius: float = 2.5
@export var separation_weight: float = 1.0
@export var muzzle_height: float = 1.0

var phase: Phase = Phase.AIM
var phase_remaining: float = 0.0

var _laser: Node3D
var _did_fire: bool = false


func setup(owner_actor: ActorEnemy, owner_machine: AIStateMachine) -> void:
    super(owner_actor, owner_machine)
    _laser = get_node_or_null(laser_path) as Node3D
    _hide_laser()


func enter(_previous_state: StringName = &"") -> void:
    if actor == null or actor.enemy_data == null:
        return
    actor.add_to_group(&"actor_enemies")
    _did_fire = false
    _set_phase(Phase.AIM, actor.enemy_data.ranged_aim_seconds)
    if is_instance_valid(actor.target):
        _aim_at_target()
        _show_laser()
    telegraph_started.emit(phase_remaining)


func exit(_next_state: StringName = &"") -> void:
    # Bị choáng hay mất mục tiêu giữa lúc ngắm thì huỷ đòn, không bắn.
    _hide_laser()
    if phase == Phase.AIM:
        telegraph_finished.emit()
    phase_remaining = 0.0


func physics_update(delta: float) -> void:
    if actor == null or actor.enemy_data == null or delta <= 0.0:
        return
    if not is_instance_valid(actor.target):
        machine.transition_to(&"Chase")
        return
    if phase == Phase.AIM:
        _aim_at_target()
        if not _is_target_in_range():
            machine.transition_to(&"Chase")
            return
        _reposition(delta)
        _show_laser()
    else:
        actor.velocity = actor.velocity.move_toward(Vector3.ZERO, acceleration * delta)
        actor.move_and_slide()
    phase_remaining -= delta
    while phase_remaining <= 0.0 and machine.current_state == self:
        var overflow: float = -phase_remaining
        match phase:
            Phase.AIM:
                telegraph_finished.emit()
                _hide_laser()
                _fire()
                _set_phase(Phase.RECOVERY, actor.enemy_data.ranged_recovery_seconds)
            Phase.RECOVERY:
                actor.attack_cooldown_remaining = actor.enemy_data.ranged_cooldown_seconds
                machine.transition_to(&"Chase")
                return
        phase_remaining -= overflow


func cancel_for_stagger() -> bool:
    if machine == null or not machine.has_state(&"Stagger"):
        return false
    return machine.transition_to(&"Stagger")


func has_fired() -> bool:
    return _did_fire


func _set_phase(next_phase: Phase, duration: float) -> void:
    phase = next_phase
    phase_remaining = maxf(0.0, duration)
    phase_changed.emit(phase)


func _fire() -> void:
    var scene: PackedScene = actor.enemy_data.projectile_scene
    if scene == null:
        Log.warn("%s không có projectile_scene, bỏ qua phát bắn" % actor.enemy_data.id, "RangedAttackState")
        return
    var projectile: Node = PoolManager.acquire(scene)
    if projectile == null:
        return
    var origin: Vector3 = actor.global_position + Vector3.UP * muzzle_height
    var direction: Vector3 = _aim_direction()
    var container: Node = actor.get_parent()
    if container != null:
        container.add_child(projectile)
    var body := projectile as Node3D
    if body != null:
        body.global_position = origin
        body.visible = true
    if projectile.has_method(&"launch"):
        projectile.call(
            &"launch",
            origin,
            direction,
            actor.enemy_data.projectile_speed,
            actor.enemy_data.ranged_damage,
            actor.enemy_data.ranged_damage_type,
            actor
        )
    _did_fire = true
    projectile_fired.emit(projectile)


func _aim_direction() -> Vector3:
    var offset: Vector3 = actor.target.global_position - actor.global_position
    offset.y = 0.0
    if offset.length_squared() <= 0.0001:
        return -actor.global_transform.basis.z
    return offset.normalized()


func _aim_at_target() -> void:
    var target_position: Vector3 = actor.target.global_position
    target_position.y = actor.global_position.y
    if actor.global_position.distance_squared_to(target_position) > 0.0001:
        actor.look_at(target_position, Vector3.UP)


func _is_target_in_range() -> bool:
    var offset: Vector3 = actor.target.global_position - actor.global_position
    offset.y = 0.0
    var range_limit: float = actor.enemy_data.ranged_attack_range
    return offset.length_squared() <= range_limit * range_limit


## Lùi ra khi mục tiêu tới quá gần, tiến vào khi trôi ra quá xa, cộng lực tách
## để hai actor tầm xa không đứng chồng lên nhau.
func _reposition(delta: float) -> void:
    var offset: Vector3 = actor.global_position - actor.target.global_position
    offset.y = 0.0
    var distance: float = offset.length()
    var preferred: float = actor.enemy_data.preferred_distance
    var steering := Vector3.ZERO
    if distance > 0.0001:
        if distance < preferred - distance_tolerance:
            steering = offset.normalized()
        elif distance > preferred + distance_tolerance:
            steering = -offset.normalized()
    steering += _separation() * separation_weight
    var desired := Vector3.ZERO
    if steering.length_squared() > 0.0001:
        desired = steering.normalized() * actor.enemy_data.move_speed * reposition_speed_scale
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


func _show_laser() -> void:
    if _laser == null or not is_instance_valid(actor.target):
        return
    var offset: Vector3 = actor.target.global_position - actor.global_position
    offset.y = 0.0
    var distance: float = maxf(offset.length(), 0.01)
    # Actor đã look_at mục tiêu nên tia chỉ cần kéo dài theo −Z cục bộ.
    _laser.position = Vector3(0.0, muzzle_height, -distance * 0.5)
    _laser.scale = Vector3(1.0, 1.0, distance)
    _laser.visible = true


func _hide_laser() -> void:
    if _laser != null:
        _laser.visible = false


func is_telegraph_visible() -> bool:
    return _laser != null and _laser.visible
