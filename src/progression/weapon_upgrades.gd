class_name WeaponUpgrades
extends RefCounted

## Năm cấp nâng cấp vũ khí theo bảng GDD §6.4. Class tĩnh — không khởi tạo.
## Xem docs/05-BACKLOG.md T-510.
##
## | Cấp | Chi phí (Salvage/Alloy) | Hiệu ứng cộng dồn      |
## |-----|-------------------------|------------------------|
## |  1  | —                       | Cơ bản                 |
## |  2  | 400 / 8                 | +12% sát thương        |
## |  3  | 900 / 20                | −10% nhiệt mỗi phát    |
## |  4  | 1800 / 45               | +15% sát thương, +20% đạn tối đa |
## |  5  | 3500 / 90               | Mở Overdrive           |
##
## "Cộng dồn" hiểu theo nghĩa **nhân dồn**: cấp 4 mang cả +12% của cấp 2 lẫn
## +15% của cấp 4, tức 1.12 × 1.15 = 1.288.

const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 5

const DAMAGE_BONUS_LEVEL_2: float = 0.12
const DAMAGE_BONUS_LEVEL_4: float = 0.15
const HEAT_REDUCTION_LEVEL_3: float = 0.10
const AMMO_BONUS_LEVEL_4: float = 0.20
const OVERDRIVE_LEVEL: int = 5


static func clamp_level(level: int) -> int:
    return clampi(level, MIN_LEVEL, MAX_LEVEL)


static func damage_multiplier(level: int) -> float:
    var value: float = 1.0
    var capped: int = clamp_level(level)
    if capped >= 2:
        value *= 1.0 + DAMAGE_BONUS_LEVEL_2
    if capped >= 4:
        value *= 1.0 + DAMAGE_BONUS_LEVEL_4
    return value


static func heat_multiplier(level: int) -> float:
    if clamp_level(level) >= 3:
        return 1.0 - HEAT_REDUCTION_LEVEL_3
    return 1.0


static func ammo_multiplier(level: int) -> float:
    if clamp_level(level) >= 4:
        return 1.0 + AMMO_BONUS_LEVEL_4
    return 1.0


static func has_overdrive(level: int) -> bool:
    return clamp_level(level) >= OVERDRIVE_LEVEL


## Chi phí để đi từ `level` lên `level + 1`, đọc từ `WeaponData.upgrade_costs`
## (mảng 4 phần tử cho cấp 2..5). Trả về `Vector2i.ZERO` khi đã kịch cấp hoặc
## dữ liệu thiếu.
static func cost_to_next(data: WeaponData, level: int) -> Vector2i:
    if data == null or level < MIN_LEVEL or level >= MAX_LEVEL:
        return Vector2i.ZERO
    var index: int = level - 1
    if index >= data.upgrade_costs.size():
        return Vector2i.ZERO
    return data.upgrade_costs[index]


## Tổng chi phí từ cấp 1 lên `level`.
static func total_cost(data: WeaponData, level: int) -> Vector2i:
    var total := Vector2i.ZERO
    for step: int in range(MIN_LEVEL, clamp_level(level)):
        total += cost_to_next(data, step)
    return total


## Bản sao của `data` đã áp mọi hiệu ứng tới `level`. KHÔNG sửa `data` gốc —
## nó là Resource dùng chung do ContentDB giữ, sửa nó là hỏng cả game.
## Nhiệt âm (Cryo) được giữ nguyên dấu: giảm 10% "sinh nhiệt" nghĩa là làm
## mát ít đi 10%, không phải làm mát nhiều hơn.
static func build_upgraded(data: WeaponData, level: int) -> WeaponData:
    if data == null:
        return null
    var upgraded := data.duplicate() as WeaponData
    var capped: int = clamp_level(level)
    upgraded.damage = data.damage * damage_multiplier(capped)
    upgraded.heat_per_shot = data.heat_per_shot * heat_multiplier(capped)
    if data.uses_ammo:
        upgraded.max_ammo = int(round(float(data.max_ammo) * ammo_multiplier(capped)))
    return upgraded


## Gọi hiệu ứng Overdrive riêng của vũ khí. `handler` là node khai báo hàm
## `_overdrive_<id>` tương ứng với `WeaponData.overdrive_effect`. Trả về true
## nếu đã gọi được; false nếu chưa tới cấp 5, vũ khí không khai báo hiệu ứng,
## hoặc handler không có hàm đó.
static func trigger_overdrive(data: WeaponData, level: int, handler: Object) -> bool:
    if data == null or handler == null or not has_overdrive(level):
        return false
    if data.overdrive_effect == &"":
        return false
    var method: StringName = overdrive_method_name(data.overdrive_effect)
    if not handler.has_method(method):
        Log.warn(
            "Vũ khí %s khai báo overdrive %s nhưng %s không có hàm %s" % [
                data.id, data.overdrive_effect, handler.get_class(), method
            ],
            "WeaponUpgrades"
        )
        return false
    handler.call(method, data)
    return true


## Hàm thuần tuý: id hiệu ứng → tên hàm mà handler phải khai báo.
static func overdrive_method_name(effect_id: StringName) -> StringName:
    return StringName("_overdrive_%s" % effect_id)
