class_name HeatComponent
extends Node

## Quản lý tích luỹ, tản nhiệt, quá nhiệt và xả nhiệt khẩn cấp của mech.
## Xem docs/01-GDD.md §2 để biết luật đầy đủ.
##
## Component tự giữ trạng thái của mình và chỉ phát signal — nó không gọi
## component khác (docs/02-TDD.md §5). Input do MechController đọc rồi truyền
## vào dưới dạng bool nên component test được mà không cần bàn phím.

signal heat_changed(current: float, maximum: float)
signal threshold_crossed(threshold: float, rising: bool)
signal overheat_started()
signal overheat_ended()
signal vent_started()
signal vent_completed(amount_removed: float)
signal vent_cancelled()

const WARNING_THRESHOLD: float = 80.0
const CRITICAL_THRESHOLD: float = 95.0
## Không bắn trong 1.2s thì tản nhiệt đầy; đang bắn chỉ còn 40%.
const FULL_DISSIPATION_DELAY: float = 1.2
const FIRING_DISSIPATION_SCALE: float = 0.4
const OVERHEAT_DURATION: float = 3.0
const OVERHEAT_SPEED_PENALTY: float = 0.35
const VENT_HOLD_SECONDS: float = 0.8
const HOLD_EPSILON: float = 0.0001
const VENT_HEAT_REMOVED: float = 60.0
const VENT_COOLDOWN_SECONDS: float = 12.0
const VENT_DAMAGE_MULTIPLIER: float = 1.3

@export var chassis_data: ChassisData
## Bội số tản nhiệt của môi trường (GDD §2.3); T-204 sẽ đặt từ EnvironmentZone.
@export var environment_multiplier: float = 1.0

var _current_heat: float = 0.0
var _is_overheated: bool = false
var _time_since_fired: float = FULL_DISSIPATION_DELAY
var _overheat_remaining: float = 0.0
var _vent_hold: float = 0.0
var _vent_cooldown: float = 0.0
var _is_venting: bool = false


func _physics_process(delta: float) -> void:
    tick(delta)


## Tách khỏi _physics_process để test gọi được với delta cố định.
func tick(delta: float) -> void:
    if delta <= 0.0:
        return
    _time_since_fired += delta
    _vent_cooldown = maxf(0.0, _vent_cooldown - delta)
    if _is_overheated:
        _overheat_remaining -= delta
        if _overheat_remaining <= 0.0:
            _end_overheat()
        return
    _dissipate(delta)


func configure(data: ChassisData) -> void:
    chassis_data = data


func add_heat(amount: float) -> void:
    if _is_overheated or amount <= 0.0 or chassis_data == null:
        return
    var previous: float = _current_heat
    _current_heat = minf(_current_heat + amount, chassis_data.heat_capacity)
    _time_since_fired = 0.0
    _emit_thresholds(previous, _current_heat)
    heat_changed.emit(_current_heat, chassis_data.heat_capacity)
    EventBus.heat_changed.emit(_current_heat, chassis_data.heat_capacity)
    if _current_heat >= chassis_data.heat_capacity:
        _start_overheat()


## Đặt thẳng mức nhiệt — dùng cho lệnh debug `heat <0-100>` (TDD §15).
func set_heat(value: float) -> void:
    if chassis_data == null:
        return
    var previous: float = _current_heat
    _current_heat = clampf(value, 0.0, chassis_data.heat_capacity)
    _emit_thresholds(previous, _current_heat)
    heat_changed.emit(_current_heat, chassis_data.heat_capacity)
    EventBus.heat_changed.emit(_current_heat, chassis_data.heat_capacity)
    if _current_heat >= chassis_data.heat_capacity and not _is_overheated:
        _start_overheat()


func get_heat() -> float:
    return _current_heat


func get_heat_ratio() -> float:
    if chassis_data == null or chassis_data.heat_capacity <= 0.0:
        return 0.0
    return _current_heat / chassis_data.heat_capacity


func is_overheated() -> bool:
    return _is_overheated


func is_venting() -> bool:
    return _is_venting


func get_vent_cooldown_remaining() -> float:
    return _vent_cooldown


func get_vent_progress() -> float:
    return clampf(_vent_hold / VENT_HOLD_SECONDS, 0.0, 1.0)


## Quá nhiệt khoá cả hai vũ khí (GDD §2.1).
func can_fire() -> bool:
    return not _is_overheated


## Quá nhiệt hoặc đang xả thì không Boost được.
func can_boost() -> bool:
    return not _is_overheated and not _is_venting


## −35% tốc độ khi quá nhiệt, đứng yên hoàn toàn khi đang xả nhiệt.
func get_move_speed_multiplier() -> float:
    if _is_venting:
        return 0.0
    if _is_overheated:
        return 1.0 - OVERHEAT_SPEED_PENALTY
    return 1.0


## +30% sát thương nhận vào trong lúc xả nhiệt — đánh đổi cố ý (GDD §2.2).
func get_damage_taken_multiplier() -> float:
    return VENT_DAMAGE_MULTIPLIER if _is_venting else 1.0


## Giữ phím xả nhiệt: đủ 0.8s thì trừ 60 nhiệt, nhả sớm thì huỷ, không mất
## hồi chiêu.
func update_vent(is_holding: bool, delta: float) -> void:
    if delta <= 0.0:
        return
    if not is_holding:
        if _is_venting:
            _is_venting = false
            _vent_hold = 0.0
            vent_cancelled.emit()
        return
    if _vent_cooldown > 0.0 or _is_overheated:
        return
    if not _is_venting:
        _is_venting = true
        _vent_hold = 0.0
        vent_started.emit()
    _vent_hold += delta
    # Trừ epsilon vì cộng dồn delta theo frame không bao giờ chạm đúng 0.8.
    if _vent_hold < VENT_HOLD_SECONDS - HOLD_EPSILON:
        return
    var previous: float = _current_heat
    _current_heat = maxf(0.0, _current_heat - VENT_HEAT_REMOVED)
    _is_venting = false
    _vent_hold = 0.0
    _vent_cooldown = VENT_COOLDOWN_SECONDS
    _emit_thresholds(previous, _current_heat)
    heat_changed.emit(_current_heat, chassis_data.heat_capacity if chassis_data != null else 0.0)
    vent_completed.emit(previous - _current_heat)


func _dissipate(delta: float) -> void:
    if chassis_data == null or _current_heat <= 0.0:
        return
    var rate: float = chassis_data.heat_dissipation * environment_multiplier
    if _time_since_fired < FULL_DISSIPATION_DELAY:
        rate *= FIRING_DISSIPATION_SCALE
    var previous: float = _current_heat
    _current_heat = maxf(_current_heat - rate * delta, 0.0)
    if is_equal_approx(previous, _current_heat):
        return
    _emit_thresholds(previous, _current_heat)
    heat_changed.emit(_current_heat, chassis_data.heat_capacity)
    EventBus.heat_changed.emit(_current_heat, chassis_data.heat_capacity)


func _start_overheat() -> void:
    if _is_overheated:
        return
    _is_overheated = true
    _is_venting = false
    _vent_hold = 0.0
    _overheat_remaining = OVERHEAT_DURATION
    overheat_started.emit()
    EventBus.overheat_started.emit()


func _end_overheat() -> void:
    _is_overheated = false
    _overheat_remaining = 0.0
    var previous: float = _current_heat
    _current_heat = 0.0
    _time_since_fired = FULL_DISSIPATION_DELAY
    _emit_thresholds(previous, _current_heat)
    overheat_ended.emit()
    EventBus.overheat_ended.emit()
    if chassis_data != null:
        heat_changed.emit(_current_heat, chassis_data.heat_capacity)
        EventBus.heat_changed.emit(_current_heat, chassis_data.heat_capacity)


func _emit_thresholds(previous: float, current: float) -> void:
    for threshold: float in [WARNING_THRESHOLD, CRITICAL_THRESHOLD]:
        if previous < threshold and current >= threshold:
            threshold_crossed.emit(threshold, true)
        elif previous >= threshold and current < threshold:
            threshold_crossed.emit(threshold, false)
