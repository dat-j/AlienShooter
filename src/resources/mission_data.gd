class_name MissionData extends Resource

## Định nghĩa một nhiệm vụ: loại, bố cục, đường cong áp lực, phần thưởng.
## Xem docs/01-GDD.md §10. Tham chiếu tới LayoutTemplate/WaveTable/LootTable
## dùng khoá StringName mềm (layout_template_id, wave_table_id, loot_table_id)
## thay vì kiểu Resource cứng, vì LayoutTemplate (T-702) chưa tồn tại lúc
## viết file này — ContentDB/LevelGenerator tự tra cứu theo id khi cần.

@export var id: StringName
@export var display_name_key: String
@export_enum("PURGE", "HOLD", "RETRIEVE", "ESCORT", "HUNT", "EXTRACT") var mission_type: int = 0
@export var chapter: int = 1

@export_group("Bố cục")
@export var layout_template_id: StringName
@export var enemy_pool: Array[StringName] = []
@export var wave_table_id: StringName
@export var loot_table_id: StringName

@export_group("Thời lượng")
@export var target_duration_min_seconds: float = 300.0
@export var target_duration_max_seconds: float = 480.0

@export_group("Áp lực")
@export var pressure_curve: Curve
@export var difficulty_budget_multiplier: float = 1.0

@export_group("Mục tiêu")
@export var objective_summary_key: String

@export_group("Phần thưởng")
@export var salvage_reward_min: int = 0
@export var salvage_reward_max: int = 0
@export var alloy_reward_min: int = 0
@export var alloy_reward_max: int = 0
