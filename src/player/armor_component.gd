class_name ArmorComponent
extends Node

## Bốn vùng giáp độc lập quanh thân mech. Xem docs/01-GDD.md §4.
##
## Component chỉ tính hấp thụ của mảng giáp và trả về phần sát thương đi tiếp
## vào Core. Việc trừ Core HP là của DamageResolver (T-502) — đây không phải
## nơi trừ máu.

signal plate_damaged(zone: Zone, remaining: float)
signal plate_broken(zone: Zone)

enum Zone { FRONT, RIGHT, REAR, LEFT }

## Vùng đã vỡ thì sát thương vào thẳng Core với hệ số ×1.4.
const BROKEN_MULTIPLIER: float = 1.4
## Nửa góc của vùng TRƯỚC/SAU; đúng 45° vẫn tính là TRƯỚC (biên đóng).
const ZONE_HALF_ANGLE: float = 45.0
const ANGLE_EPSILON: float = 0.001

@export var chassis_data: ChassisData

var _plates: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _maximums: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func _ready() -> void:
    if chassis_data != null:
        configure(chassis_data)


func configure(data: ChassisData) -> void:
    chassis_data = data
    if data == null:
        return
    _maximums[Zone.FRONT] = data.armor_front
    _maximums[Zone.RIGHT] = data.armor_side
    _maximums[Zone.REAR] = data.armor_rear
    _maximums[Zone.LEFT] = data.armor_side
    for zone: int in range(_plates.size()):
        _plates[zone] = _maximums[zone]


## Sát thương từ `source_position` bắn vào mech đang đứng ở `mech_transform`.
## Trả về phần sát thương còn lại phải đi vào Core.
func absorb_from(amount: float, source_position: Vector3, mech_transform: Transform3D) -> float:
    return absorb(amount, zone_for_source(mech_transform, source_position))


## Trả về phần sát thương đi tiếp vào Core sau khi mảng giáp hấp thụ.
func absorb(amount: float, zone: Zone) -> float:
    if amount <= 0.0:
        return 0.0
    var remaining: float = _plates[zone]
    if remaining <= 0.0:
        return amount * BROKEN_MULTIPLIER
    var absorbed: float = minf(amount, remaining)
    _plates[zone] = remaining - absorbed
    plate_damaged.emit(zone, _plates[zone])
    if _plates[zone] <= 0.0:
        plate_broken.emit(zone)
        EventBus.armor_plate_broken.emit(int(zone))
    # Phần tràn của chính cú đánh làm vỡ mảng vẫn đi vào Core ở hệ số ×1.0.
    return amount - absorbed


func get_plate(zone: Zone) -> float:
    return _plates[zone]


func get_plate_ratio(zone: Zone) -> float:
    if _maximums[zone] <= 0.0:
        return 0.0
    return _plates[zone] / _maximums[zone]


func is_broken(zone: Zone) -> bool:
    return _plates[zone] <= 0.0


## Nanite Patch / trạm sửa chữa (M9) hồi giáp; giáp không tự hồi trong nhiệm vụ.
func repair(zone: Zone, amount: float) -> void:
    if amount <= 0.0:
        return
    _plates[zone] = minf(_plates[zone] + amount, _maximums[zone])
    plate_damaged.emit(zone, _plates[zone])


## Hàm thuần tuý: nguồn sát thương ở đâu so với hướng thân mech.
## Góc lệch |θ| ≤ 45° là TRƯỚC, ≥ 135° là SAU, còn lại theo dấu là PHẢI/TRÁI.
static func zone_for_source(mech_transform: Transform3D, source_position: Vector3) -> Zone:
    var to_source: Vector3 = source_position - mech_transform.origin
    to_source.y = 0.0
    if to_source.length_squared() <= 0.0001:
        return Zone.FRONT
    var forward: Vector3 = -mech_transform.basis.z
    forward.y = 0.0
    var right: Vector3 = mech_transform.basis.x
    right.y = 0.0
    var angle: float = rad_to_deg(forward.normalized().angle_to(to_source.normalized()))
    # Cộng EPSILON để góc đúng 45.0° không bị sai số dấu phẩy động đẩy sang
    # vùng bên cạnh.
    if angle <= ZONE_HALF_ANGLE + ANGLE_EPSILON:
        return Zone.FRONT
    if angle >= 180.0 - ZONE_HALF_ANGLE - ANGLE_EPSILON:
        return Zone.REAR
    return Zone.RIGHT if right.dot(to_source) > 0.0 else Zone.LEFT
