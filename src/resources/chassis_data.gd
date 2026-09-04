class_name ChassisData extends Resource

## Định nghĩa chỉ số một khung mech (chassis). Xem docs/01-GDD.md §5.

@export var id: StringName
@export var display_name_key: String
@export var unlock_chapter: int = 1
@export var module_slots: int = 2

@export_group("Giáp & lõi")
@export var core_hp: float = 100.0
@export var armor_front: float = 50.0
@export var armor_side: float = 40.0      # dùng chung cho Trái và Phải
@export var armor_rear: float = 30.0

@export_group("Di chuyển")
@export var move_speed: float = 6.0
@export var leg_turn_speed_degrees: float = 480.0

@export_group("Nhiệt")
@export var heat_capacity: float = 100.0
@export var heat_dissipation: float = 12.0

@export_group("Boost")
@export var boost_charges: int = 2
@export var boost_recharge_seconds: float = 3.5

@export_group("Đặc tính riêng")
@export var boost_skips_iframe_cooldown: bool = false
@export var loot_radius_bonus_percent: float = 0.0
@export var knockback_immune: bool = false
@export var explosive_damage_taken_multiplier: float = 1.0

@export_group("Trình bày")
@export var model: PackedScene
