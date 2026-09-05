class_name BeamVfx
extends Node3D

## Tia sáng của vũ khí hitscan (T-505). Pooled — không `instantiate()` cũng
## không `queue_free()` trong chiến đấu (TDD §12.1).
##
## Mờ dần bằng `GeometryInstance3D.transparency`, KHÔNG bằng alpha của vật
## liệu: material là SubResource dùng chung cho mọi bản sao trong pool, sửa
## nó sẽ làm mọi tia đang bay cùng mờ theo.

const DEFAULT_LIFETIME: float = 0.09
## Mesh gốc là hộp cạnh 1m, quay theo trục -Z của node.
const BASE_LENGTH: float = 1.0

@export var lifetime: float = DEFAULT_LIFETIME

var _elapsed: float = 0.0
var _is_active: bool = false

@onready var _mesh: MeshInstance3D = $BeamMesh


func _process(delta: float) -> void:
    if not _is_active:
        return
    _elapsed += delta
    var ratio: float = clampf(_elapsed / maxf(lifetime, 0.001), 0.0, 1.0)
    _mesh.transparency = ratio
    if ratio >= 1.0:
        _is_active = false
        PoolManager.release(self)


## Kéo dài tia từ `from` tới `to`. `thickness` là cạnh vuông của tiết diện.
func show_beam(from: Vector3, to: Vector3, thickness: float) -> void:
    var segment: Vector3 = to - from
    var length: float = segment.length()
    global_position = from
    # look_at hướng -Z về mục tiêu; bỏ qua khi đoạn gần như thẳng đứng vì
    # trục nhìn khi đó song song với Vector3.UP.
    var flat := Vector3(segment.x, 0.0, segment.z)
    if length > 0.001 and flat.length_squared() > 0.000001:
        look_at(to, Vector3.UP)
    _mesh.position = Vector3(0.0, 0.0, -length * 0.5)
    _mesh.scale = Vector3(thickness, thickness, maxf(length, 0.001) / BASE_LENGTH)
    _mesh.transparency = 0.0
    _elapsed = 0.0
    _is_active = true
    visible = true


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
