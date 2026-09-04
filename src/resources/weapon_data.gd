class_name WeaponData extends Resource

## Định nghĩa dữ liệu một vũ khí. Thêm vũ khí mới = thêm một file .tres,
## không sửa code. Xem docs/01-GDD.md §6 và docs/02-TDD.md §9 (khuôn mẫu gốc).

@export var id: StringName
@export var display_name_key: String          # khoá dịch, không phải chuỗi thô
@export_enum("KINETIC", "ENERGY", "EXPLOSIVE", "SPECIAL") var category: int
@export var tier: int = 1

@export_group("Sát thương")
@export var damage: float = 10.0
@export var damage_type: DamageTypes.Type
@export var projectiles_per_shot: int = 1
@export var spread_degrees: float = 0.0
@export var pierce_count: int = 0
@export var aoe_radius: float = 0.0

@export_group("Tốc độ & Nhiệt")
@export var rate_of_fire: float = 5.0
@export var heat_per_shot: float = 3.0
@export var charge_time: float = 0.0
@export var spin_up_time: float = 0.0

@export_group("Đạn")
@export var uses_ammo: bool = true
@export var max_ammo: int = 200

@export_group("Trình bày")
@export var model: PackedScene
@export var muzzle_vfx: PackedScene
@export var impact_vfx: PackedScene
@export var fire_sound: AudioStream
@export var projectile_scene: PackedScene      # null = hitscan

@export_group("Nâng cấp")
@export var upgrade_costs: Array[Vector2i]     # (salvage, alloy) cho cấp 2..5
@export var overdrive_effect: StringName
