class_name MuzzleFlash
extends Node3D

## Chớp lửa đầu nòng. Xem docs/03-ART-BIBLE.md §8 và docs/05-BACKLOG.md
## T-604. Pooled — không `instantiate()`/`queue_free()` trong chiến đấu.
##
## "Phải rất ngắn, rất sáng": 0.08 giây. Dài hơn thì nó thành ánh sáng nền
## và mất hẳn cảm giác đấm.
##
## Đèn đi qua `LightBudget`: hết ngân sách thì chớp vẫn nổ, chỉ là không có
## đèn — mất một chút ánh sáng còn hơn tụt frame (TDD §12.6).

const LIFETIME: float = 0.08
const LIGHT_ENERGY: float = 4.0
const LIGHT_RANGE: float = 4.5

var _elapsed: float = 0.0
var _is_active: bool = false
var _has_light: bool = false

@onready var _light: OmniLight3D = $Light
@onready var _quad: MeshInstance3D = $Quad
@onready var _sparks: GPUParticles3D = $Sparks


func _ready() -> void:
    # Luật cứng TDD §12.6: đèn tạm KHÔNG BAO GIỜ đổ bóng.
    _light.shadow_enabled = false
    _light.omni_range = LIGHT_RANGE
    _reset()


func _process(delta: float) -> void:
    if not _is_active:
        return
    _elapsed += delta
    var ratio: float = clampf(_elapsed / LIFETIME, 0.0, 1.0)
    # Tắt theo bậc hai: sáng loé rồi tắt gọn, không "mờ dần" lê thê.
    var falloff: float = (1.0 - ratio) * (1.0 - ratio)
    if _has_light:
        _light.light_energy = LIGHT_ENERGY * falloff
    _quad.transparency = ratio
    if ratio >= 1.0:
        _finish()


## Nổ chớp tại `origin`, hướng theo `direction`. Gọi sau khi lấy từ pool.
func flash(origin: Vector3, direction: Vector3) -> void:
    global_position = origin
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() > 0.000001:
        look_at(origin + flat, Vector3.UP)
    _elapsed = 0.0
    _is_active = true
    visible = true
    _has_light = LightBudget.request()
    _light.visible = _has_light
    _light.light_energy = LIGHT_ENERGY if _has_light else 0.0
    _quad.transparency = 0.0
    _sparks.restart()


func is_active() -> bool:
    return _is_active


func has_light() -> bool:
    return _has_light


func _finish() -> void:
    _is_active = false
    PoolManager.release(self)


func _on_acquired() -> void:
    _reset()


func _on_released() -> void:
    _reset()


func _reset() -> void:
    if _has_light:
        LightBudget.release()
        _has_light = false
    _is_active = false
    _elapsed = 0.0
    visible = false
    if _light != null:
        _light.visible = false
