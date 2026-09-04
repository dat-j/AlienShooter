class_name RoomModuleData extends Resource

## Metadata mô tả một scene phòng, dùng để LevelGenerator (T-703) chọn phòng
## tương thích theo hạng cỡ và số cửa nối. Bản thân scene phòng và hợp đồng
## ConnectionPoint/SpawnZones/LootAnchors/bounds thuộc docs/02-TDD.md §10.2 —
## được định nghĩa trong room_module.gd (T-701), không phải file này.

@export var id: StringName
@export var display_name_key: String
@export var chapter: int = 1
@export_enum("SPAWN", "STANDARD", "OBJECTIVE", "EXTRACTION") var room_role: int = 1
@export_enum("SMALL", "MEDIUM", "LARGE") var size_class: int = 1

@export_group("Kết nối")
@export var connection_count: int = 1
@export var connection_sizes: Array[int] = []   # song song, mỗi phần tử là size_class của một ConnectionPoint

@export_group("Nội dung")
@export var enemy_density: float = 1.0
@export var loot_density: float = 1.0
@export var supports_environment_hazard: bool = false

@export_group("Scene")
@export var scene: PackedScene
