class_name PerkData extends Resource

## Định nghĩa một perk trong cây kỹ năng phi công. Xem docs/01-GDD.md §12.

@export var id: StringName
@export var display_name_key: String
@export var description_key: String
@export_enum("TACTICAL", "FIREPOWER", "TECHNICAL") var branch: int = 0
@export var tier_index: int = 0
@export var point_cost: int = 1

@export_group("Yêu cầu")
@export var required_pilot_level: int = 1
@export var prerequisite_perk_id: StringName    # rỗng nếu không cần

@export_group("Hiệu ứng")
@export var effect_key: StringName
@export var effect_value: float = 0.0

@export_group("Trình bày")
@export var icon: Texture2D
