class_name Gib
extends RigidBody3D

## Một mảnh xác quái. Xem docs/03-ART-BIBLE.md §8 ("Mảnh vụn pooled, 6s rồi
## tan") và docs/02-TDD.md §12.7 (trần 60 xác quái vật lý).
##
## Pooled. Vòng đời do `GibManager` cấp phát và thu hồi.

const LIFETIME: float = 6.0
## Một giây cuối dành cho việc tan đi — biến mất đột ngột rất lộ.
const FADE_SECONDS: float = 1.0
const SPIN: float = 9.0

var _elapsed: float = 0.0
var _is_active: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _mesh: MeshInstance3D = $Mesh


func _process(delta: float) -> void:
    if not _is_active:
        return
    _elapsed += delta
    _mesh.transparency = fade_at(_elapsed)
    if _elapsed >= LIFETIME:
        PoolManager.release(self)


## Bắn mảnh vụn ra từ `origin` theo `impulse`.
func burst(origin: Vector3, impulse: Vector3) -> void:
    global_position = origin
    freeze = false
    linear_velocity = impulse
    angular_velocity = Vector3(
        _rng.randf_range(-SPIN, SPIN),
        _rng.randf_range(-SPIN, SPIN),
        _rng.randf_range(-SPIN, SPIN)
    )
    _elapsed = 0.0
    _is_active = true
    visible = true
    _mesh.transparency = 0.0


func is_active() -> bool:
    return _is_active


## Hàm thuần tuý: độ trong suốt theo tuổi mảnh vụn. 0 = đục, 1 = biến mất.
static func fade_at(elapsed: float) -> float:
    var fade_start: float = LIFETIME - FADE_SECONDS
    if elapsed <= fade_start:
        return 0.0
    return clampf((elapsed - fade_start) / FADE_SECONDS, 0.0, 1.0)


func _on_acquired() -> void:
    _reset()


func _on_released() -> void:
    _reset()


func _reset() -> void:
    _is_active = false
    _elapsed = 0.0
    visible = false
    freeze = true
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
