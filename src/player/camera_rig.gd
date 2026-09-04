class_name CameraRig
extends Node3D

## Camera khoá góc theo docs/03-ART-BIBLE.md §3: FOV 38°, chếch 62°, cách 22m
## (co giãn 18–28m), người chơi không xoay được. Bám mục tiêu bằng lerp hệ số
## 8.0 và lệch 25% về phía con trỏ, tối đa 4m. Rung của JuiceDirector (M6)
## luôn được CỘNG THÊM vào vị trí bám chứ không thay thế nó.

const FOLLOW_LERP: float = 8.0
const PITCH_DEGREES: float = -62.0
const DEFAULT_DISTANCE: float = 22.0
const MIN_DISTANCE: float = 18.0
const MAX_DISTANCE: float = 28.0
const FIELD_OF_VIEW: float = 38.0
const AIM_OFFSET_RATIO: float = 0.25
const MAX_AIM_OFFSET: float = 4.0

@export var target_path: NodePath = NodePath("..")
@export var distance: float = DEFAULT_DISTANCE

## JuiceDirector (M6) ghi vào đây mỗi frame; giữ chỗ cho tới khi có T-601.
var shake_offset: Vector3 = Vector3.ZERO

var _target: Node3D
var _aim_point: Vector3 = Vector3.ZERO
var _follow_position: Vector3 = Vector3.ZERO

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
    # Rig là con của Mech nhưng không đi theo phép biến đổi của Mech: nó tự
    # bám bằng lerp, nếu không sẽ không thể làm mượt được.
    top_level = true
    _target = get_node_or_null(target_path) as Node3D
    set_distance(distance)
    camera.fov = FIELD_OF_VIEW
    if _target != null:
        _follow_position = _target.global_position
        _aim_point = _target.global_position
        global_position = _follow_position


func _process(delta: float) -> void:
    update_follow(delta)


## Điểm ngắm hiện tại, do AimController (T-105) đẩy vào mỗi frame.
func set_aim_point(point: Vector3) -> void:
    _aim_point = point


func set_distance(value: float) -> void:
    distance = clampf(value, MIN_DISTANCE, MAX_DISTANCE)
    var pitch: float = deg_to_rad(PITCH_DEGREES)
    camera.position = Vector3(0.0, sin(-pitch) * distance, cos(-pitch) * distance)
    camera.rotation = Vector3(pitch, 0.0, 0.0)


func update_follow(delta: float) -> void:
    if _target == null or delta <= 0.0:
        return
    var focus: Vector3 = compute_focus(_target.global_position, _aim_point)
    _follow_position = _follow_position.lerp(focus, clampf(FOLLOW_LERP * delta, 0.0, 1.0))
    global_position = _follow_position + shake_offset


func get_follow_position() -> Vector3:
    return _follow_position


## Hàm thuần tuý: tâm camera = vị trí mech cộng 25% quãng đường tới con trỏ,
## giới hạn 4m, chỉ trên mặt phẳng XZ.
static func compute_focus(target_position: Vector3, aim_point: Vector3) -> Vector3:
    var offset: Vector3 = aim_point - target_position
    offset.y = 0.0
    offset *= AIM_OFFSET_RATIO
    if offset.length() > MAX_AIM_OFFSET:
        offset = offset.normalized() * MAX_AIM_OFFSET
    return target_position + offset
