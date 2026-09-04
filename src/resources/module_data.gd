class_name ModuleData extends Resource

## Định nghĩa một module gắn vào ô module của chassis. Xem docs/01-GDD.md §7.
## `effect_key` là khoá logic hiệu ứng do ModuleComponent (ngoài phạm vi
## file này) đọc và diễn giải cùng effect_value_a/b/c — tương tự cách
## WeaponData tách dữ liệu khỏi hành vi bắn.

@export var id: StringName
@export var display_name_key: String
@export_enum("PASSIVE", "ACTIVE") var module_type: int = 0
@export var tier: int = 1

@export_group("Kích hoạt")
@export var cooldown_seconds: float = 0.0
@export var active_duration_seconds: float = 0.0
@export var uses_per_mission: int = -1    # -1 = không giới hạn, chỉ theo hồi chiêu

@export_group("Hiệu ứng")
@export var effect_key: StringName
@export var effect_value_a: float = 0.0
@export var effect_value_b: float = 0.0
@export var effect_value_c: float = 0.0

@export_group("Trình bày")
@export var icon: Texture2D
@export var activation_vfx: PackedScene
