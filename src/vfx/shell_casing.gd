class_name ShellCasing
extends RigidBody3D

## Vỏ đạn văng ra. Xem docs/03-ART-BIBLE.md §8 và docs/05-BACKLOG.md T-604.
##
## Đây là chỗ DUY NHẤT trong đường chiến đấu được dùng `RigidBody3D`: vỏ đạn
## nảy trên sàn là thứ physics làm tốt hơn code, và trần 60 cái giữ chi phí
## trong tầm kiểm soát. Luật cấm ở TDD §12.5 nhắm vào swarm, không phải
## mảnh vụn trang trí.
##
## Vòng đời do `ShellEjector` quản lý; vỏ tự trả về pool khi hết hạn.

## "4s rồi ẩn" — bảng VFX ART-BIBLE §8.
const LIFETIME: float = 4.0
## Dưới ngưỡng va chạm này thì không kêu: vỏ đạn lăn lọc cọc trên sàn không
## được biến thành tiếng ồn liên tục.
const MIN_CLINK_SPEED: float = 1.2
const EJECT_SPEED: float = 3.2
const EJECT_SPIN: float = 12.0

var _elapsed: float = 0.0
var _is_active: bool = false
var _has_clinked: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _audio: AudioStreamPlayer3D = $Clink


func _ready() -> void:
    contact_monitor = true
    max_contacts_reported = 1
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)
    _reset()


func _process(delta: float) -> void:
    if not _is_active:
        return
    _elapsed += delta
    if _elapsed >= LIFETIME:
        PoolManager.release(self)


## Bắn vỏ ra khỏi nòng. `direction` là hướng văng (thường là bên hông mech).
func eject(origin: Vector3, direction: Vector3) -> void:
    global_position = origin
    freeze = false
    var flat: Vector3 = direction.normalized() if direction.length_squared() > 0.000001 else Vector3.RIGHT
    linear_velocity = (flat + Vector3.UP * 0.6).normalized() * EJECT_SPEED
    angular_velocity = Vector3(
        _rng.randf_range(-EJECT_SPIN, EJECT_SPIN),
        _rng.randf_range(-EJECT_SPIN, EJECT_SPIN),
        _rng.randf_range(-EJECT_SPIN, EJECT_SPIN)
    )
    _elapsed = 0.0
    _has_clinked = false
    _is_active = true
    visible = true


func is_active() -> bool:
    return _is_active


func get_lifetime_elapsed() -> float:
    return _elapsed


## Tiếng chạm sàn. Chỉ kêu MỘT lần cho mỗi vỏ, ở lần chạm đầu đủ mạnh.
## Stream còn trống cho tới M13 (T-1302) — cơ chế đã sẵn, âm thanh chưa có.
func play_clink() -> bool:
    if _has_clinked or _audio == null:
        return false
    _has_clinked = true
    if _audio.stream == null:
        return false
    _audio.play()
    return true


func _on_body_entered(_body: Node) -> void:
    if _is_active and linear_velocity.length() >= MIN_CLINK_SPEED:
        play_clink()


func _on_acquired() -> void:
    _reset()


func _on_released() -> void:
    _reset()


func _reset() -> void:
    _is_active = false
    _elapsed = 0.0
    _has_clinked = false
    visible = false
    # Đóng băng khi nằm trong pool: vỏ chưa dùng không được rơi tự do.
    freeze = true
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
