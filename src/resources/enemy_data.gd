class_name EnemyData extends Resource

## Định nghĩa dữ liệu một loại kẻ địch, dùng cho cả đường SWARM và ACTOR.
## Xem docs/01-GDD.md §8 và docs/02-TDD.md §6 (kiến trúc kẻ địch), §6.3
## (không có thăng cấp SWARM → ACTOR — cố định lúc thiết kế qua execution_path).

@export var id: StringName
@export var display_name_key: String
@export var chapter: int = 1
@export_enum("SWARM", "ACTOR") var execution_path: int = 0

@export_group("Chỉ số")
@export var max_hp: float = 10.0
@export var move_speed: float = 5.0
@export var contact_damage: float = 5.0
@export var contact_damage_type: DamageTypes.Type

@export_group("Ngân sách & nhận biết")
@export var spawn_budget_cost: int = 1          # xem docs/01-GDD.md §10.3
@export var perception_radius: float = 15.0
@export var stagger_threshold: float = 999999.0 # không dùng cho SWARM
@export var stagger_immunity_seconds: float = 1.5

@export_group("Tấn công")
@export var attack_range: float = 2.0
@export var attack_windup_seconds: float = 0.3
@export var attack_active_seconds: float = 0.2
@export var attack_recovery_seconds: float = 0.4
@export var attack_cooldown_seconds: float = 1.0

@export_group("Trạng thái")
@export var inflicts_status: Array[StringName] = []
@export var immune_status: Array[StringName] = []

@export_group("Chiến lợi phẩm")
@export var loot_table: LootTable

@export_group("Trình bày")
@export var actor_scene: PackedScene    # dùng khi execution_path == ACTOR
@export var swarm_mesh: Mesh             # dùng khi execution_path == SWARM
@export var swarm_material: Material

@export_group("Swarm")
@export_range(0, 255, 1) var swarm_type_id: int = 0
@export var swarm_scale: Vector3 = Vector3.ONE
@export var swarm_tint: Color = Color.WHITE
@export var jump_distance: float = 0.0
@export var jump_trigger_range: float = 0.0
@export var jump_cooldown_seconds: float = 0.0
