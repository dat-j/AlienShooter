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
## Bán kính người chơi tự ăn đòn nổ của chính mình (GDD §6.1, nhóm Explosive).
@export var self_damage_radius: float = 0.0
## Trạng thái áp lên mục tiêu mỗi lần trúng, tra trong ContentDB theo id.
@export var status_to_apply: Array[StringName] = []

@export_group("Tốc độ & Nhiệt")
@export var rate_of_fire: float = 5.0
@export var heat_per_shot: float = 3.0
@export var charge_time: float = 0.0
@export var spin_up_time: float = 0.0

@export_group("Tầm & nhịp liên tục")
## Tầm tối đa của hitscan/hình nón, tính bằng mét. 0 = mặc định của loại.
@export var max_range: float = 0.0
## Vũ khí kẹp cò liên tục (Flamer, Cryo, Arc). Khi bật, `damage` và
## `heat_per_shot` được hiểu là **mỗi giây** chứ không phải mỗi phát, và
## `rate_of_fire` bị bỏ qua — xem `src/combat/cone_weapon.gd`.
@export var is_continuous: bool = false
## Số lần gây sát thương mỗi giây của vũ khí liên tục.
@export var tick_rate: float = 10.0
## Góc mở tổng của hình nón. 0 = tia thẳng.
@export var cone_angle_degrees: float = 0.0
## Trần mục tiêu mỗi tick của vũ khí liên tục. 0 = không giới hạn.
@export var max_targets_per_tick: int = 0

@export_group("Đạn")
@export var uses_ammo: bool = true
@export var max_ammo: int = 200

@export_group("Trình bày")
@export var model: PackedScene
@export var muzzle_vfx: PackedScene
@export var impact_vfx: PackedScene
@export var fire_sound: AudioStream
@export var projectile_scene: PackedScene      # null = hitscan
## Tốc độ đạn (m/s). 0 = dùng `Projectile.DEFAULT_SPEED`.
@export var projectile_speed: float = 0.0

@export_group("Nâng cấp")
@export var upgrade_costs: Array[Vector2i]     # (salvage, alloy) cho cấp 2..5
@export var overdrive_effect: StringName
