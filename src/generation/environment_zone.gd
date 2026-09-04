class_name EnvironmentZone
extends Area3D

## Vùng môi trường đổi bội số tản nhiệt của mech đi vào. Bảng bội số ở
## docs/01-GDD.md §2.3.
##
## Giới hạn đã biết: hai vùng chồng lên nhau sẽ không cộng dồn — vùng ra sau
## đưa mech về mức chuẩn. Phòng trong màn sinh ra không chồng nhau nên chấp
## nhận được; nếu về sau cần chồng thì phải chuyển sang đếm tham chiếu.

signal mech_entered(multiplier: float)
signal mech_exited()

const DEFAULT_MULTIPLIER: float = 1.0

## ×1.45 đóng băng, ×0.65 gần lò luyện, ×1.25 ngập nước, ×0.55 chân không.
@export var dissipation_multiplier: float = 1.0


func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
    var mech := body as MechController
    if mech == null or mech.heat_component == null:
        return
    mech.heat_component.environment_multiplier = dissipation_multiplier
    mech_entered.emit(dissipation_multiplier)


func _on_body_exited(body: Node3D) -> void:
    var mech := body as MechController
    if mech == null or mech.heat_component == null:
        return
    mech.heat_component.environment_multiplier = DEFAULT_MULTIPLIER
    mech_exited.emit()
