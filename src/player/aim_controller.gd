class_name AimController
extends Node

## Chiếu con trỏ xuống mặt phẳng ngang của mech (docs/05-BACKLOG.md T-105).
## Chuột: raycast từ camera qua vị trí con trỏ. Gamepad: cần phải, bán kính
## chết 0.2 rồi chuẩn hoá. Điểm ngắm là nguồn duy nhất cho hướng thân trên
## (T-103) và độ lệch camera (T-104).

signal aim_source_changed(using_gamepad: bool)

const GAMEPAD_DEADZONE: float = 0.2
const GAMEPAD_AIM_DISTANCE: float = 12.0

@export var body_path: NodePath = NodePath("..")
@export var camera_path: NodePath = NodePath("../CameraRig/Camera3D")
@export var camera_rig_path: NodePath = NodePath("../CameraRig")

var _aim_point: Vector3 = Vector3.ZERO
var _using_gamepad: bool = false

@onready var _body: Node3D = get_node_or_null(body_path) as Node3D
@onready var _camera: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var _camera_rig: CameraRig = get_node_or_null(camera_rig_path) as CameraRig
@onready var _viewport: Viewport = get_viewport()


func _ready() -> void:
    if _body != null:
        _aim_point = _body.global_position - _body.global_transform.basis.z


func _process(_delta: float) -> void:
    if _body == null:
        return
    var stick: Vector2 = Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
    var plane_y: float = _body.global_position.y
    if stick.length() >= GAMEPAD_DEADZONE:
        _set_source(true)
        _aim_point = stick_to_aim_point(_body.global_position, stick, GAMEPAD_AIM_DISTANCE)
    elif _camera != null and _viewport != null:
        _set_source(false)
        _aim_point = project_screen_to_ground(_camera, _viewport.get_mouse_position(), plane_y)
    if _camera_rig != null:
        _camera_rig.set_aim_point(_aim_point)


func get_aim_point() -> Vector3:
    return _aim_point


func is_using_gamepad() -> bool:
    return _using_gamepad


## Raycast từ camera qua một điểm trên màn hình xuống mặt phẳng y = `plane_y`.
static func project_screen_to_ground(camera: Camera3D, screen_position: Vector2, plane_y: float) -> Vector3:
    var origin: Vector3 = camera.project_ray_origin(screen_position)
    var direction: Vector3 = camera.project_ray_normal(screen_position)
    return intersect_ground(origin, direction, plane_y)


## Hàm thuần tuý: giao điểm của tia với mặt phẳng ngang. Tia song song mặt
## phẳng (hoặc chỉ ra xa) thì trả về hình chiếu của điểm xuất phát.
static func intersect_ground(origin: Vector3, direction: Vector3, plane_y: float) -> Vector3:
    var ground := Plane(Vector3.UP, plane_y)
    var hit: Variant = ground.intersects_ray(origin, direction)
    if hit == null:
        return Vector3(origin.x, plane_y, origin.z)
    return hit as Vector3


## Hàm thuần tuý: cần analog phải → điểm ngắm quanh mech. Dưới bán kính chết
## thì giữ nguyên hướng hiện tại của thân (trả về chính vị trí mech).
static func stick_to_aim_point(body_position: Vector3, stick: Vector2, radius: float) -> Vector3:
    if stick.length() < GAMEPAD_DEADZONE:
        return body_position
    var normalized: Vector2 = stick.normalized()
    return body_position + Vector3(normalized.x, 0.0, normalized.y) * radius


func _set_source(using_gamepad: bool) -> void:
    if using_gamepad == _using_gamepad:
        return
    _using_gamepad = using_gamepad
    aim_source_changed.emit(using_gamepad)
