extends Node

## Autoload #8 (TDD §4). Rung màn hình, hitstop, rung tay cầm, quang sai màu.
## Xem docs/03-ART-BIBLE.md §9 (bảng tham số) và docs/05-BACKLOG.md
## T-601 · T-602 · T-603.
##
## Ba luật của file này:
##
## 1. **Cộng dồn, không ghi đè.** Bắn liên thanh vào giữa một vụ nổ phải rung
##    mạnh hơn từng thứ riêng lẻ. Mỗi lệnh `shake()` là một mục sống riêng,
##    biên độ tổng là tổng của chúng — không phải cái sau đè cái trước.
##
## 2. **Hitstop lấy MAX chứ không cộng.** Cộng dồn hitstop là con đường
##    thẳng tới đứng hình. Trần cứng `MAX_HITSTOP_SECONDS` chặn nốt.
##
## 3. **Mọi thứ chạy bằng thời gian KHÔNG co giãn.** Hitstop kéo
##    `Engine.time_scale` xuống 0.05; nếu bộ đếm của chính nó cũng bị co theo
##    thì một hitstop 0.05s sẽ kéo dài một giây. Đó cũng là lý do UI đọc
##    `get_unscaled_delta()` để không bị chậm theo thế giới.
##
## Autoload này KHÔNG giữ tham chiếu tới node nào trong màn chơi (luật vàng
## TDD §4). Camera **tự lấy** offset qua `get_shake_offset()`.

## Trần số lệnh rung sống cùng lúc. Vượt quá thì lệnh yếu nhất bị thay —
## trận đánh to phải rung theo những cú mạnh nhất, không phải cú đến sớm nhất.
const MAX_SHAKES: int = 16
const MAX_RUMBLES: int = 8
## Biên độ tổng tối đa (mét). Bảng ART-BIBLE cao nhất là 0.45; trần này cho
## phép vài sự kiện chồng nhau mà vẫn không hất camera ra khỏi trận đánh.
const MAX_TOTAL_AMPLITUDE: float = 0.9
## Tần số lấy mẫu nhiễu. Cao thì rung gắt, thấp thì lắc lư như say sóng.
const SHAKE_HZ: float = 18.0
## Rung theo phương đứng nhẹ hơn: camera chếch 62° nên lệch Y đọc rất mạnh.
const VERTICAL_SHAKE_RATIO: float = 0.4

const HITSTOP_TIME_SCALE: float = 0.05
## Trần cứng: quá ngưỡng này thì người chơi cảm thấy game đơ, không thấy đã.
const MAX_HITSTOP_SECONDS: float = 0.25
const NORMAL_TIME_SCALE: float = 1.0

const CHROMATIC_DECAY_PER_SECOND: float = 2.5
## Chênh lệch nhỏ nhất đáng gửi lại lệnh rung xuống tay cầm.
const RUMBLE_EPSILON: float = 0.02

## Khoá thanh trượt trợ năng trong SettingsManager.
const SCALE_SHAKE: StringName = &"screen_shake"
const SCALE_HITSTOP: StringName = &"hitstop"
const SCALE_RUMBLE: StringName = &"rumble"
const SCALE_CHROMATIC: StringName = &"chromatic_aberration"

## Cường độ rung tay cầm theo cột "Rung tay cầm" của ART-BIBLE §9.
const RUMBLE_LIGHT: float = 0.25
const RUMBLE_MEDIUM: float = 0.5
const RUMBLE_STRONG: float = 1.0
const RUMBLE_AMBIENT: float = 0.15

## Bảng tham số ART-BIBLE §9, một dòng một sự kiện. Người gọi dùng `play()`
## với id thay vì rải số ma thuật khắp codebase — đổi cảm giác game là đổi
## đúng bảng này.
const EVENTS: Dictionary = {
    &"fire_light": {&"amp": 0.04, &"dur": 0.05, &"hitstop": 0.0, &"rumble": RUMBLE_LIGHT},
    &"fire_heavy": {&"amp": 0.15, &"dur": 0.10, &"hitstop": 0.02, &"rumble": RUMBLE_MEDIUM},
    &"rail_lance": {&"amp": 0.30, &"dur": 0.18, &"hitstop": 0.05, &"rumble": RUMBLE_STRONG},
    &"swarm_killed": {&"amp": 0.0, &"dur": 0.0, &"hitstop": 0.0, &"rumble": 0.0},
    &"actor_killed": {&"amp": 0.08, &"dur": 0.08, &"hitstop": 0.04, &"rumble": RUMBLE_LIGHT},
    &"boss_phase": {&"amp": 0.45, &"dur": 0.60, &"hitstop": 0.20, &"rumble": RUMBLE_STRONG},
    &"player_hit": {&"amp": 0.20, &"dur": 0.15, &"hitstop": 0.0, &"rumble": RUMBLE_MEDIUM, &"chromatic": 0.4},
    &"armor_broken": {&"amp": 0.35, &"dur": 0.25, &"hitstop": 0.08, &"rumble": RUMBLE_STRONG},
    &"explosion_near": {&"amp": 0.40, &"dur": 0.30, &"hitstop": 0.06, &"rumble": RUMBLE_STRONG},
}

## "Quá nhiệt: 0.10 liên tục" — không phải một cú giật mà là nền rung kéo dài
## suốt thời gian quá nhiệt, nên nó đi đường riêng.
const OVERHEAT_AMPLITUDE: float = 0.10

var _shake_amplitudes: PackedFloat32Array = PackedFloat32Array()
var _shake_durations: PackedFloat32Array = PackedFloat32Array()
var _shake_elapsed: PackedFloat32Array = PackedFloat32Array()
var _shake_count: int = 0

var _rumble_weak: PackedFloat32Array = PackedFloat32Array()
var _rumble_strong: PackedFloat32Array = PackedFloat32Array()
var _rumble_remaining: PackedFloat32Array = PackedFloat32Array()
var _rumble_count: int = 0
var _last_weak: float = 0.0
var _last_strong: float = 0.0

var _sustained_amplitude: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _shake_time: float = 0.0
var _hitstop_remaining: float = 0.0
var _chromatic: float = 0.0

var _noise: FastNoiseLite = FastNoiseLite.new()


func _ready() -> void:
    _shake_amplitudes.resize(MAX_SHAKES)
    _shake_durations.resize(MAX_SHAKES)
    _shake_elapsed.resize(MAX_SHAKES)
    _rumble_weak.resize(MAX_RUMBLES)
    _rumble_strong.resize(MAX_RUMBLES)
    _rumble_remaining.resize(MAX_RUMBLES)
    # Perlin, KHÔNG phải ngẫu nhiên trắng: nhiễu trắng làm camera giật hạt
    # tiêu, Perlin cho quỹ đạo liên tục nên đọc ra là "bị đấm" chứ không phải
    # "màn hình hỏng" (T-602).
    _noise.noise_type = FastNoiseLite.TYPE_PERLIN
    _noise.frequency = 1.0
    _noise.seed = 20260905
    process_mode = Node.PROCESS_MODE_ALWAYS
    EventBus.player_damaged.connect(_on_player_damaged)
    EventBus.armor_plate_broken.connect(_on_armor_plate_broken)
    EventBus.overheat_started.connect(_on_overheat_started)
    EventBus.overheat_ended.connect(_on_overheat_ended)


func _process(delta: float) -> void:
    var unscaled: float = get_unscaled_delta(delta)
    _update_hitstop(unscaled)
    _update_shakes(unscaled)
    _update_rumbles(unscaled)
    _chromatic = maxf(0.0, _chromatic - CHROMATIC_DECAY_PER_SECOND * unscaled)


# --- API (T-601) --------------------------------------------------------

## Thêm một cú rung. Cộng dồn với những cú đang sống, không ghi đè.
## `amplitude` tính bằng mét theo bảng ART-BIBLE §9.
func shake(amplitude: float, duration: float) -> void:
    var scaled: float = amplitude * accessibility_scale(SCALE_SHAKE)
    if scaled <= 0.0 or duration <= 0.0:
        return
    var slot: int = _shake_slot(scaled)
    if slot < 0:
        return
    _shake_amplitudes[slot] = scaled
    _shake_durations[slot] = duration
    _shake_elapsed[slot] = 0.0


## Đóng băng thế giới trong `duration` giây thời gian thực. Nhiều lệnh
## chồng nhau lấy giá trị LỚN NHẤT, không cộng — xem luật 2 ở đầu file.
func hitstop(duration: float) -> void:
    var scaled: float = duration * accessibility_scale(SCALE_HITSTOP)
    if scaled <= 0.0:
        return
    _hitstop_remaining = minf(maxf(_hitstop_remaining, scaled), MAX_HITSTOP_SECONDS)
    Engine.time_scale = HITSTOP_TIME_SCALE


## Rung tay cầm. `weak`/`strong` trong 0..1; cộng dồn giữa các lệnh.
func rumble(weak: float, strong: float, duration: float) -> void:
    var scale: float = accessibility_scale(SCALE_RUMBLE)
    var weak_scaled: float = clampf(weak, 0.0, 1.0) * scale
    var strong_scaled: float = clampf(strong, 0.0, 1.0) * scale
    if duration <= 0.0 or (weak_scaled <= 0.0 and strong_scaled <= 0.0):
        return
    var slot: int = _rumble_slot()
    if slot < 0:
        return
    _rumble_weak[slot] = weak_scaled
    _rumble_strong[slot] = strong_scaled
    _rumble_remaining[slot] = duration


## Quang sai màu tức thời, tự tắt dần. Lấy giá trị lớn nhất đang có.
func chromatic(amount: float) -> void:
    var scaled: float = clampf(amount, 0.0, 1.0) * accessibility_scale(SCALE_CHROMATIC)
    _chromatic = maxf(_chromatic, scaled)


## Chạy trọn một dòng của bảng ART-BIBLE §9. Đây là cách gọi được ưu tiên —
## `shake()`/`hitstop()` trần chỉ dành cho trường hợp không có trong bảng.
func play(event_id: StringName) -> bool:
    var entry: Dictionary = EVENTS.get(event_id, {}) as Dictionary
    if entry.is_empty():
        Log.warn("không có sự kiện juice tên %s" % event_id, "JuiceDirector")
        return false
    shake(float(entry.get(&"amp", 0.0)), float(entry.get(&"dur", 0.0)))
    hitstop(float(entry.get(&"hitstop", 0.0)))
    var strength: float = float(entry.get(&"rumble", 0.0))
    if strength > 0.0:
        rumble(strength * 0.6, strength, maxf(float(entry.get(&"dur", 0.0)), 0.08))
    var aberration: float = float(entry.get(&"chromatic", 0.0))
    if aberration > 0.0:
        chromatic(aberration)
    return true


## Nền rung kéo dài (quá nhiệt). Đặt 0 để tắt.
func set_sustained_shake(amplitude: float) -> void:
    _sustained_amplitude = maxf(amplitude, 0.0) * accessibility_scale(SCALE_SHAKE)


## Camera gọi mỗi frame và CỘNG kết quả vào vị trí bám của nó.
func get_shake_offset() -> Vector3:
    return _shake_offset


func get_chromatic_amount() -> float:
    return _chromatic


func is_hitstopped() -> bool:
    return _hitstop_remaining > 0.0


func get_active_shake_count() -> int:
    return _shake_count


func get_total_amplitude() -> float:
    var total: float = _sustained_amplitude
    for index: int in range(_shake_count):
        total += _shake_amplitudes[index] * decay_curve(_shake_elapsed[index] / _shake_durations[index])
    return minf(total, MAX_TOTAL_AMPLITUDE)


## Dừng mọi thứ ngay lập tức: đổi cảnh, tạm dừng, hồi sinh.
func reset() -> void:
    _shake_count = 0
    _rumble_count = 0
    _sustained_amplitude = 0.0
    _shake_offset = Vector3.ZERO
    _chromatic = 0.0
    _hitstop_remaining = 0.0
    Engine.time_scale = NORMAL_TIME_SCALE
    _stop_rumble()


## Thời gian thật, không bị hitstop bóp. UI dùng hàm này để hit marker và
## nhịp nháy không chậm lại theo thế giới (T-603).
static func get_unscaled_delta(delta: float) -> float:
    return delta / maxf(Engine.time_scale, 0.0001)


## Hàm thuần tuý: đường tắt dần của một cú rung, 1.0 lúc bắt đầu → 0.0 lúc
## hết. Bậc hai nên đoạn cuối êm, không "cụp" một phát.
static func decay_curve(ratio: float) -> float:
    var remaining: float = clampf(1.0 - ratio, 0.0, 1.0)
    return remaining * remaining


func accessibility_scale(key: StringName) -> float:
    return SettingsManager.get_accessibility_scale(key)


# --- Nội bộ -------------------------------------------------------------

func _update_hitstop(unscaled: float) -> void:
    if _hitstop_remaining <= 0.0:
        return
    _hitstop_remaining -= unscaled
    if _hitstop_remaining > 0.0:
        return
    _hitstop_remaining = 0.0
    Engine.time_scale = NORMAL_TIME_SCALE


func _update_shakes(unscaled: float) -> void:
    var index: int = 0
    while index < _shake_count:
        _shake_elapsed[index] += unscaled
        if _shake_elapsed[index] < _shake_durations[index]:
            index += 1
            continue
        _remove_shake(index)
    var total: float = get_total_amplitude()
    if total <= 0.0:
        _shake_offset = Vector3.ZERO
        return
    _shake_time += unscaled
    var sample: float = _shake_time * SHAKE_HZ
    _shake_offset = Vector3(
        _noise.get_noise_2d(sample, 0.0),
        _noise.get_noise_2d(0.0, sample) * VERTICAL_SHAKE_RATIO,
        _noise.get_noise_2d(sample, 512.0)
    ) * total


func _update_rumbles(unscaled: float) -> void:
    var index: int = 0
    while index < _rumble_count:
        _rumble_remaining[index] -= unscaled
        if _rumble_remaining[index] > 0.0:
            index += 1
            continue
        _remove_rumble(index)
    var weak: float = 0.0
    var strong: float = 0.0
    for slot: int in range(_rumble_count):
        weak += _rumble_weak[slot]
        strong += _rumble_strong[slot]
    weak = clampf(weak, 0.0, 1.0)
    strong = clampf(strong, 0.0, 1.0)
    if absf(weak - _last_weak) < RUMBLE_EPSILON and absf(strong - _last_strong) < RUMBLE_EPSILON:
        return
    _last_weak = weak
    _last_strong = strong
    if weak <= 0.0 and strong <= 0.0:
        _stop_rumble()
        return
    for device: int in Input.get_connected_joypads():
        Input.start_joy_vibration(device, weak, strong, 0.0)


func _stop_rumble() -> void:
    _last_weak = 0.0
    _last_strong = 0.0
    for device: int in Input.get_connected_joypads():
        Input.stop_joy_vibration(device)


## Còn chỗ thì lấy chỗ trống; hết chỗ thì thay cú yếu nhất, và chỉ khi cú
## mới mạnh hơn nó.
func _shake_slot(amplitude: float) -> int:
    if _shake_count < MAX_SHAKES:
        _shake_count += 1
        return _shake_count - 1
    var weakest: int = 0
    for index: int in range(1, _shake_count):
        if _shake_amplitudes[index] < _shake_amplitudes[weakest]:
            weakest = index
    return weakest if amplitude > _shake_amplitudes[weakest] else -1


func _rumble_slot() -> int:
    if _rumble_count < MAX_RUMBLES:
        _rumble_count += 1
        return _rumble_count - 1
    var weakest: int = 0
    for index: int in range(1, _rumble_count):
        if _rumble_strong[index] < _rumble_strong[weakest]:
            weakest = index
    return weakest


func _remove_shake(index: int) -> void:
    var last: int = _shake_count - 1
    _shake_amplitudes[index] = _shake_amplitudes[last]
    _shake_durations[index] = _shake_durations[last]
    _shake_elapsed[index] = _shake_elapsed[last]
    _shake_count -= 1


func _remove_rumble(index: int) -> void:
    var last: int = _rumble_count - 1
    _rumble_weak[index] = _rumble_weak[last]
    _rumble_strong[index] = _rumble_strong[last]
    _rumble_remaining[index] = _rumble_remaining[last]
    _rumble_count -= 1


func _on_player_damaged(_amount: float, _zone: int, _source_position: Vector3) -> void:
    play(&"player_hit")


func _on_armor_plate_broken(_zone: int) -> void:
    play(&"armor_broken")


func _on_overheat_started() -> void:
    set_sustained_shake(OVERHEAT_AMPLITUDE)


func _on_overheat_ended() -> void:
    set_sustained_shake(0.0)
