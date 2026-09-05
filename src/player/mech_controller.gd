class_name MechController
extends CharacterBody3D

## Điều phối các component của mech — KHÔNG chứa logic của component nào.
## Xem docs/02-TDD.md §5 (cây node và luật component).
##
## Di chuyển: WASD tương đối với camera, quán tính đọc từ hằng số dưới đây
## (docs/05-BACKLOG.md T-102), tốc độ tối đa đọc từ `ChassisData`.

signal chassis_changed(data: ChassisData)
signal core_health_changed(current: float, maximum: float)
signal died()

const DEFAULT_CHASSIS_PATH: String = "res://data/chassis/chs_ronin_m.tres"
const ACCELERATION_TIME: float = 0.18
const DECELERATION_TIME: float = 0.25
## Góc lệch tối đa giữa thân trên và chân; vượt quá thì chân bị kéo theo
## (docs/01-GDD.md §1 — nguồn chính của cảm giác "nặng").
const MAX_TORSO_LEG_ANGLE: float = 110.0
const MIN_MOVE_SPEED_FOR_TURN: float = 0.1

@export var chassis_data: ChassisData

## Máu lõi. CHỈ DamageResolver được phép trừ giá trị này (TDD §8.2).
var core_hp: float = 1.0

var _move_input: Vector2 = Vector2.ZERO
var _gravity: float = 24.0

@onready var legs_pivot: Node3D = $LegsPivot
@onready var torso_pivot: Node3D = $TorsoPivot
@onready var weapon_mount_left: WeaponMount = $TorsoPivot/WeaponMountLeft
@onready var weapon_mount_right: WeaponMount = $TorsoPivot/WeaponMountRight
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var pickup_radius: Area3D = $PickupRadius
@onready var camera_rig: Node3D = $CameraRig
@onready var aim_controller: AimController = $AimController
@onready var heat_component: HeatComponent = $HeatComponent
@onready var armor_component: ArmorComponent = $ArmorComponent
@onready var boost_component: BoostComponent = $BoostComponent
@onready var status_component: StatusComponent = $StatusComponent


func _ready() -> void:
    _gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
    if chassis_data == null:
        chassis_data = load(DEFAULT_CHASSIS_PATH) as ChassisData
    set_chassis(chassis_data)


func _physics_process(delta: float) -> void:
    _move_input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
    heat_component.update_vent(Input.is_action_pressed(&"vent_heat"), delta)
    if Input.is_action_just_pressed(&"boost"):
        try_boost()
    apply_movement(_move_input, delta)
    boost_component.update(delta, global_position, not heat_component.is_overheated())
    update_orientation(delta)
    update_weapons(delta, Input.is_action_pressed(&"fire_left"), Input.is_action_pressed(&"fire_right"))


## Đổi khung mech lúc chạy (Khoang mech ở M9 sẽ gọi hàm này).
func set_chassis(data: ChassisData) -> void:
    if data == null:
        Log.warn("chassis_data rỗng — mech giữ nguyên chỉ số cũ", "MechController")
        return
    chassis_data = data
    core_hp = data.core_hp
    core_health_changed.emit(core_hp, data.core_hp)
    heat_component.configure(data)
    armor_component.configure(data)
    boost_component.configure(data)
    chassis_changed.emit(data)


## Hai mount bắn độc lập nhau, cùng ngắm về một điểm.
func update_weapons(delta: float, fire_left: bool, fire_right: bool) -> void:
    var aim_point: Vector3 = global_position - global_transform.basis.z
    if aim_controller != null:
        aim_point = aim_controller.get_aim_point()
    if weapon_mount_left != null:
        weapon_mount_left.update(delta, fire_left, heat_component, aim_point)
    if weapon_mount_right != null:
        weapon_mount_right.update(delta, fire_right, heat_component, aim_point)


## Hộp đạn bù cho **cả hai** vũ khí cùng lúc (GDD §11.2). Trả về tổng số
## viên đã nạp — 0 nghĩa là cả hai tay đều đầy hoặc đều là vũ khí Energy.
func refill_ammo(fraction: float) -> int:
    var added: int = 0
    if weapon_mount_left != null:
        added += weapon_mount_left.refill(fraction)
    if weapon_mount_right != null:
        added += weapon_mount_right.refill(fraction)
    return added


## Gán SwarmManager của nhiệm vụ cho mọi hệ thống cần đụng tới swarm.
func set_swarm_manager(manager: SwarmManager) -> void:
    boost_component.swarm_manager = manager
    weapon_mount_left.swarm_manager = manager
    weapon_mount_right.swarm_manager = manager


## DamageResolver gọi sau khi đã đổi core_hp.
func notify_core_changed() -> void:
    var maximum: float = chassis_data.core_hp if chassis_data != null else core_hp
    core_health_changed.emit(core_hp, maximum)
    if core_hp <= 0.0:
        died.emit()


func get_core_ratio() -> float:
    if chassis_data == null or chassis_data.core_hp <= 0.0:
        return 0.0
    return core_hp / chassis_data.core_hp


## Góc yaw của camera; input di chuyển được xoay theo góc này nên WASD luôn
## đúng với những gì người chơi thấy trên màn hình.
func get_camera_yaw() -> float:
    if camera_rig == null:
        return 0.0
    return camera_rig.global_rotation.y


## Lướt theo hướng đang đi; đứng yên thì lướt theo hướng thân trên (GDD §3).
func try_boost() -> bool:
    var direction := Vector3(velocity.x, 0.0, velocity.z)
    if direction.length_squared() < 0.01:
        direction = -torso_pivot.global_transform.basis.z
    return try_boost_in_direction(direction)


func try_boost_in_direction(direction: Vector3) -> bool:
    if boost_component == null:
        return false
    return boost_component.try_start(direction, heat_component, global_position)


func apply_movement(input: Vector2, delta: float) -> void:
    if chassis_data == null or delta <= 0.0:
        return
    if boost_component != null and boost_component.is_dashing():
        # Cú lướt do move_and_slide thực hiện nên tường vẫn chặn được.
        var dash: Vector3 = boost_component.get_dash_velocity()
        velocity.x = dash.x
        velocity.z = dash.z
        velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
        move_and_slide()
        return
    var speed: float = chassis_data.move_speed
    if heat_component != null:
        speed *= heat_component.get_move_speed_multiplier()
    if status_component != null:
        speed *= status_component.get_move_speed_multiplier()
    var desired: Vector3 = compute_desired_velocity(input, get_camera_yaw(), speed)
    var horizontal := Vector3(velocity.x, 0.0, velocity.z)
    horizontal = horizontal.move_toward(desired, compute_change_rate(chassis_data.move_speed, desired) * delta)
    velocity.x = horizontal.x
    velocity.z = horizontal.z
    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y -= _gravity * delta
    move_and_slide()


## Thân trên bám con trỏ tức thời, chân xoay theo hướng đi với tốc độ của
## chassis, và chân bị kéo theo khi lệch quá MAX_TORSO_LEG_ANGLE.
func update_orientation(delta: float) -> void:
    if chassis_data == null or delta <= 0.0:
        return
    var aim_point: Vector3 = global_position - global_transform.basis.z
    if aim_controller != null:
        aim_point = aim_controller.get_aim_point()
    var to_aim: Vector3 = aim_point - global_position
    to_aim.y = 0.0
    var torso_yaw: float = torso_pivot.rotation.y
    if to_aim.length_squared() > 0.0001:
        torso_yaw = yaw_from_direction(to_aim)
    torso_pivot.rotation.y = torso_yaw

    var legs_yaw: float = legs_pivot.rotation.y
    var move_direction := Vector3(velocity.x, 0.0, velocity.z)
    if move_direction.length() > MIN_MOVE_SPEED_FOR_TURN:
        legs_yaw = step_angle(
            legs_yaw,
            yaw_from_direction(move_direction),
            deg_to_rad(chassis_data.leg_turn_speed_degrees) * delta
        )
    legs_pivot.rotation.y = clamp_legs_to_torso(legs_yaw, torso_yaw)


## Hàm thuần tuý: hướng trên mặt phẳng XZ → góc yaw sao cho −Z của node quay
## về hướng đó (quy ước "trước" của Godot).
static func yaw_from_direction(direction: Vector3) -> float:
    return atan2(-direction.x, -direction.z)


## Hàm thuần tuý: xoay `from` về phía `to` nhiều nhất `max_step` radian.
static func step_angle(from: float, to: float, max_step: float) -> float:
    var difference: float = angle_difference(from, to)
    return wrapf(from + clampf(difference, -max_step, max_step), -PI, PI)


## Hàm thuần tuý: kéo chân theo khi lệch quá 110° so với thân trên.
static func clamp_legs_to_torso(legs_yaw: float, torso_yaw: float) -> float:
    var limit: float = deg_to_rad(MAX_TORSO_LEG_ANGLE)
    var difference: float = angle_difference(legs_yaw, torso_yaw)
    if absf(difference) <= limit:
        return wrapf(legs_yaw, -PI, PI)
    return wrapf(torso_yaw - signf(difference) * limit, -PI, PI)


## Hàm thuần tuý: input màn hình → vận tốc mong muốn trong không gian thế giới.
static func compute_desired_velocity(input: Vector2, yaw: float, speed: float) -> Vector3:
    var clamped: Vector2 = input if input.length_squared() <= 1.0 else input.normalized()
    var direction := Vector3(clamped.x, 0.0, clamped.y).rotated(Vector3.UP, yaw)
    return direction * speed


## Tăng tốc trong 0.18s, giảm tốc trong 0.25s — mech nặng nên dừng chậm hơn
## khởi động (docs/05-BACKLOG.md T-102).
static func compute_change_rate(speed: float, desired: Vector3) -> float:
    var duration: float = ACCELERATION_TIME if desired.length_squared() > 0.0 else DECELERATION_TIME
    return speed / duration
