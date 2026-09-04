class_name BoostComponent
extends Node

## Lướt nhanh 7.0m trong 0.18s với i-frame 0.12s ở giữa. Xem docs/01-GDD.md §3.
##
## Component không tự di chuyển mech: nó chỉ tính vận tốc lướt, còn
## MechController gọi move_and_slide() nên tường vẫn chặn được cú lướt.

signal boost_started(direction: Vector3)
signal boost_finished(travelled: float)
signal charges_changed(current: int, maximum: int)

const DASH_DISTANCE: float = 7.0
const DASH_DURATION: float = 0.18
const IFRAME_DURATION: float = 0.12
const HEAT_COST: float = 15.0
const SWARM_CONTACT_DAMAGE: float = 12.0
const SWARM_SWEEP_RADIUS: float = 1.2

@export var chassis_data: ChassisData

## SwarmManager của nhiệm vụ; để trống thì cú lướt không gây sát thương swarm.
var swarm_manager: SwarmManager = null

var _charges: int = 0
var _recharge_remaining: float = 0.0
var _dash_elapsed: float = 0.0
var _is_dashing: bool = false
var _dash_direction: Vector3 = Vector3.ZERO
var _dash_start: Vector3 = Vector3.ZERO


func _ready() -> void:
    if chassis_data != null:
        configure(chassis_data)


func configure(data: ChassisData) -> void:
    chassis_data = data
    if data == null:
        return
    _charges = data.boost_charges
    charges_changed.emit(_charges, data.boost_charges)


## Bắt đầu lướt theo `direction` (đã chuẩn hoá trên mặt phẳng XZ). Trả về
## false khi hết nạp, đang lướt, hoặc nhiệt không cho phép.
func try_start(direction: Vector3, heat: HeatComponent, origin: Vector3) -> bool:
    if chassis_data == null or _is_dashing or _charges <= 0:
        return false
    if heat != null and not heat.can_boost():
        return false
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() <= 0.0001:
        return false
    _dash_direction = flat.normalized()
    _dash_start = origin
    _dash_elapsed = 0.0
    _is_dashing = true
    _charges -= 1
    if _recharge_remaining <= 0.0:
        _recharge_remaining = chassis_data.boost_recharge_seconds
    if heat != null:
        heat.add_heat(HEAT_COST)
    boost_started.emit(_dash_direction)
    charges_changed.emit(_charges, chassis_data.boost_charges)
    EventBus.boost_used.emit(_charges)
    return true


## `current_position` dùng để biết cú lướt thực sự đi được bao xa (tường có
## thể chặn giữa chừng). `can_recharge` = false khi mech đang quá nhiệt.
func update(delta: float, current_position: Vector3, can_recharge: bool) -> void:
    if delta <= 0.0 or chassis_data == null:
        return
    if _is_dashing:
        _dash_elapsed += delta
        if _dash_elapsed >= DASH_DURATION:
            _finish_dash(current_position)
    if not can_recharge or _charges >= chassis_data.boost_charges:
        return
    _recharge_remaining -= delta
    if _recharge_remaining > 0.0:
        return
    _charges += 1
    _recharge_remaining = chassis_data.boost_recharge_seconds if _charges < chassis_data.boost_charges else 0.0
    charges_changed.emit(_charges, chassis_data.boost_charges)


func is_dashing() -> bool:
    return _is_dashing


## I-frame nằm giữa cú lướt: 0.12s ở chính giữa 0.18s.
func is_invulnerable() -> bool:
    if not _is_dashing:
        return false
    var margin: float = (DASH_DURATION - IFRAME_DURATION) * 0.5
    return _dash_elapsed >= margin and _dash_elapsed <= DASH_DURATION - margin


func get_dash_velocity() -> Vector3:
    if not _is_dashing:
        return Vector3.ZERO
    return _dash_direction * (DASH_DISTANCE / DASH_DURATION)


func get_charges() -> int:
    return _charges


func get_recharge_remaining() -> float:
    return _recharge_remaining


func _finish_dash(end_position: Vector3) -> void:
    _is_dashing = false
    _dash_elapsed = 0.0
    var travelled: float = _dash_start.distance_to(end_position)
    if swarm_manager != null:
        # Lướt xuyên qua swarm gây 12 sát thương va chạm (GDD §3).
        swarm_manager.damage_along_ray(
            _dash_start, end_position, SWARM_CONTACT_DAMAGE, -1, SWARM_SWEEP_RADIUS
        )
    boost_finished.emit(travelled)
