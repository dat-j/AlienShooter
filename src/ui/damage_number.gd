class_name DamageNumber
extends Label3D

## Một con số sát thương bay lên. Xem docs/04-UX-UI.md §2.4 và
## docs/05-BACKLOG.md T-607. Pooled — vòng đời do `DamageNumberPool` quản lý.
##
## Là `Label3D` chứ không phải Control: con số phải bám vào chỗ vừa trúng
## đòn trong không gian 3D, không phải một điểm cố định trên màn hình.

## "trôi lên và mờ dần trong 0.7s" — UX-UI §2.4.
const LIFETIME: float = 0.7
const RISE_METRES: float = 1.1
## Chí mạng to hơn 1.4× và đổi màu (UX-UI §2.4).
const CRITICAL_SCALE: float = 1.4
const BASE_FONT_SIZE: int = 48

## Bảng màu ART-BIBLE §2.
const COLOR_NORMAL := Color(0.95, 0.96, 0.98)
const COLOR_CRITICAL := Color(0.949, 0.761, 0.188)   # Vàng cảnh báo

var _elapsed: float = 0.0
var _is_active: bool = false
var _origin: Vector3 = Vector3.ZERO


func _process(delta: float) -> void:
    if not _is_active:
        return
    # Thời gian thật: hitstop đóng băng thế giới chứ không đóng băng phản hồi.
    _elapsed += JuiceDirector.get_unscaled_delta(delta)
    var ratio: float = clampf(_elapsed / LIFETIME, 0.0, 1.0)
    global_position = _origin + Vector3.UP * rise_at(ratio)
    modulate.a = alpha_at(ratio)
    if ratio >= 1.0:
        _is_active = false
        PoolManager.release(self)


## Hiện một con số tại `position`.
func show_damage(position: Vector3, amount: float, is_critical: bool) -> void:
    _origin = position
    global_position = position
    text = format_amount(amount)
    modulate = COLOR_CRITICAL if is_critical else COLOR_NORMAL
    font_size = int(round(float(BASE_FONT_SIZE) * (CRITICAL_SCALE if is_critical else 1.0)))
    billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _elapsed = 0.0
    _is_active = true
    visible = true


func is_active() -> bool:
    return _is_active


## Hàm thuần tuý: sát thương → chuỗi hiển thị. Làm tròn về số nguyên — HUD
## giữa trận không phải bảng tính, `12` đọc nhanh hơn `12.4`.
static func format_amount(amount: float) -> String:
    return str(maxi(int(round(amount)), 1))


## Hàm thuần tuý: quãng đường đã trôi lên. Chậm dần để số dừng lại ở cuối
## thay vì bay vụt khỏi tầm mắt.
static func rise_at(ratio: float) -> float:
    var eased: float = 1.0 - (1.0 - ratio) * (1.0 - ratio)
    return RISE_METRES * eased


## Hàm thuần tuý: độ mờ. Giữ đục nửa đầu rồi mới tan — con số phải đọc được
## trước khi nó biến mất.
static func alpha_at(ratio: float) -> float:
    if ratio <= 0.5:
        return 1.0
    return clampf(1.0 - (ratio - 0.5) * 2.0, 0.0, 1.0)


func _on_acquired() -> void:
    _reset()


func _on_released() -> void:
    _reset()


func _reset() -> void:
    _is_active = false
    _elapsed = 0.0
    visible = false
