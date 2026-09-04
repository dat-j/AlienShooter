class_name StatusEffectData extends Resource

## Định nghĩa một trạng thái bất lợi (hoặc có lợi) áp lên mech/kẻ địch.
## Xem docs/01-GDD.md §9.

@export var id: StringName
@export var display_name_key: String

@export_group("Thời gian")
@export var duration_seconds: float = 1.0
@export var max_stacks: int = 1

@export_group("Sát thương theo thời gian")
@export var damage_per_second: float = 0.0
@export var damage_type: DamageTypes.Type

@export_group("Ảnh hưởng thuộc tính")
@export var move_speed_multiplier: float = 1.0
@export var armor_effectiveness_multiplier: float = 1.0
@export var damage_taken_multiplier: float = 1.0
@export var prevents_attack: bool = false

@export_group("Điều kiện đặc biệt")
@export var breaks_on_single_hit_damage: float = 0.0  # 0 = không vỡ được
@export var grants_stealth: bool = false

@export_group("Trình bày")
@export var vfx: PackedScene
@export var tint_color: Color = Color.WHITE
