class_name ArenaDemo
extends Node3D

## Bộ điều khiển của sân tập (T-111): nối mech với hệ swarm, đổ quái theo đợt
## và hồi sinh khi người chơi chết.
##
## GIÀN GIÁO TẠM: đây KHÔNG phải SpawnDirector. Đợt quái ở đây theo nhịp cố
## định, không có ngân sách, không có đường cong áp lực, không có luật chống
## ức chế. T-802 sẽ thay bằng `src/director/spawn_director.gd` thật và file
## này chỉ còn giữ phần nối dây của sân tập.

signal wave_spawned(index: int, count: int)
signal player_respawned()

@export var mech_path: NodePath = NodePath("Mech")
@export var swarm_path: NodePath = NodePath("SwarmRuntime")
@export var wave_interval_seconds: float = 5.0
@export var units_per_wave: int = 10
@export var max_alive: int = 140
@export var spawn_radius_min: float = 16.0
@export var spawn_radius_max: float = 26.0
@export var respawn_delay_seconds: float = 2.0

var _time_to_next_wave: float = 2.0
var _wave_index: int = 0
var _respawn_countdown: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _mech: MechController = get_node_or_null(mech_path) as MechController
@onready var _swarm: SwarmRuntime = get_node_or_null(swarm_path) as SwarmRuntime


func _ready() -> void:
    _rng.randomize()
    if _mech == null or _swarm == null:
        Log.warn("Sân tập thiếu Mech hoặc SwarmRuntime — bỏ qua phần đổ quái", "ArenaDemo")
        return
    _mech.set_swarm_manager(_swarm.manager)
    _mech.died.connect(_on_player_died)


func _physics_process(delta: float) -> void:
    if _mech == null or _swarm == null or delta <= 0.0:
        return
    if _respawn_countdown > 0.0:
        _respawn_countdown -= delta
        if _respawn_countdown <= 0.0:
            respawn_player()
        return
    _time_to_next_wave -= delta
    if _time_to_next_wave > 0.0:
        return
    _time_to_next_wave = wave_interval_seconds
    spawn_wave()


## Đổ một đợt quanh người chơi theo vòng tròn, luân phiên các loại swarm.
func spawn_wave() -> int:
    var types: Array[EnemyData] = _swarm.get_enemy_types()
    if types.is_empty():
        return 0
    var room: int = max_alive - _swarm.get_alive_count()
    var count: int = mini(units_per_wave, maxi(room, 0))
    for index: int in range(count):
        var angle: float = _rng.randf() * TAU
        var radius: float = _rng.randf_range(spawn_radius_min, spawn_radius_max)
        var position: Vector3 = _mech.global_position + Vector3(cos(angle) * radius, 0.25, sin(angle) * radius)
        var data: EnemyData = types[(_wave_index + index) % types.size()]
        _swarm.spawn_unit(data, position)
    if count > 0:
        _wave_index += 1
        wave_spawned.emit(_wave_index, count)
    return count


func get_wave_index() -> int:
    return _wave_index


func respawn_player() -> void:
    _swarm.clear_all()
    _mech.set_chassis(_mech.chassis_data)     # nạp lại Core HP và cả bốn mảng giáp
    _mech.velocity = Vector3.ZERO
    _mech.global_position = Vector3(0.0, 0.5, 6.0)
    _time_to_next_wave = wave_interval_seconds
    player_respawned.emit()
    Log.info("Sân tập: hồi sinh người chơi", "ArenaDemo")


func _on_player_died() -> void:
    _respawn_countdown = respawn_delay_seconds
