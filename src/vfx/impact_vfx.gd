class_name ImpactVfx
extends Node3D

## Cụm hạt trúng đích, dùng chung cho cả trúng kim loại lẫn trúng thịt —
## khác nhau nằm ở scene (`impact_metal.tscn` / `impact_flesh.tscn`) chứ
## không nằm ở code. Xem docs/03-ART-BIBLE.md §8 và T-605.
##
## Pooled. Tự trả về pool khi hạt cuối tắt.

## Đủ dài cho cả hai dòng của bảng ART-BIBLE §8 (kim loại 0.4s, thịt 0.6s);
## scene tự đặt thời gian sống của hạt trong khoảng này.
@export var lifetime: float = 0.6
## Trúng thịt sinh decal máu; trúng kim loại thì không (ART-BIBLE §8).
@export var leaves_decal: bool = false
@export var decal_kind: StringName = &"blood"

var _elapsed: float = 0.0
var _is_active: bool = false

@onready var _particles: GPUParticles3D = $Particles


func _process(delta: float) -> void:
    if not _is_active:
        return
    _elapsed += delta
    if _elapsed >= lifetime:
        _is_active = false
        PoolManager.release(self)


## Nổ hạt tại `position`, quay theo pháp tuyến bề mặt để tia lửa bắn ngược
## ra chứ không cắm vào tường.
func play(position: Vector3, normal: Vector3) -> void:
    global_position = position
    var direction := normal
    if direction.length_squared() <= 0.000001:
        direction = Vector3.UP
    direction = direction.normalized()
    # look_at gục khi pháp tuyến song song với trục UP (trúng sàn hoặc trần).
    var up: Vector3 = Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
    look_at(position + direction, up)
    _elapsed = 0.0
    _is_active = true
    visible = true
    if _particles != null:
        _particles.restart()


func is_active() -> bool:
    return _is_active


func _on_acquired() -> void:
    _reset()


func _on_released() -> void:
    _reset()


func _reset() -> void:
    _is_active = false
    _elapsed = 0.0
    visible = false
