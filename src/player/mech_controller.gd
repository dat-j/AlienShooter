class_name MechController
extends CharacterBody3D

## Điều phối các component của mech — KHÔNG chứa logic của component nào.
## Xem docs/02-TDD.md §5 (cây node và luật component).

signal chassis_changed(data: ChassisData)

const DEFAULT_CHASSIS_PATH: String = "res://data/chassis/chs_ronin_m.tres"

@export var chassis_data: ChassisData

@onready var legs_pivot: Node3D = $LegsPivot
@onready var torso_pivot: Node3D = $TorsoPivot
@onready var weapon_mount_left: Node3D = $TorsoPivot/WeaponMountLeft
@onready var weapon_mount_right: Node3D = $TorsoPivot/WeaponMountRight
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var pickup_radius: Area3D = $PickupRadius
@onready var camera_rig: Node3D = $CameraRig


func _ready() -> void:
    if chassis_data == null:
        chassis_data = load(DEFAULT_CHASSIS_PATH) as ChassisData
    set_chassis(chassis_data)


## Đổi khung mech lúc chạy (Khoang mech ở M9 sẽ gọi hàm này).
func set_chassis(data: ChassisData) -> void:
    if data == null:
        Log.warn("chassis_data rỗng — mech giữ nguyên chỉ số cũ", "MechController")
        return
    chassis_data = data
    chassis_changed.emit(data)
