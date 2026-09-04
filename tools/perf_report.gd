class_name PerfReport
extends Node3D

## Cảnh kiểm chuẩn T-311: chạy 300 swarm qua đúng pipeline movement +
## MultiMesh, hiển thị thời gian từng hệ thống và ghi mẫu ra CSV.

const UNIT_COUNT: int = 300
const ARENA_SIZE: float = 60.0
const SAMPLE_LIMIT: int = 600
const CSV_HEADER: String = "frame,alive,batches,flow_us,movement_us,render_us,swarm_ms,frame_ms"

@export_file("*.csv") var report_path: String = "user://perf_swarm.csv"
@export_range(1, 4, 1) var batch_count: int = 4
@export var auto_export_after_samples: bool = true

@onready var _target: Node3D = $Target
@onready var _hud: Label = $HUD/Metrics
@onready var _manager: SwarmManager = $SwarmManager
@onready var _renderer: SwarmRenderer = $SwarmRenderer

var _flow: FlowField = FlowField.new()
var _movement: SwarmMovement = SwarmMovement.new()
var _samples: PackedStringArray = PackedStringArray()
var _frame_index: int = 0
var _last_flow_usec: int = 0
var _last_movement_usec: int = 0
var _last_render_usec: int = 0
var _exported: bool = false


func _ready() -> void:
    _flow.configure(
        AABB(Vector3(-ARENA_SIZE * 0.5, -1.0, -ARENA_SIZE * 0.5), Vector3(ARENA_SIZE, 2.0, ARENA_SIZE)),
        FlowField.DEFAULT_CELL_SIZE
    )
    _flow.rebuild(_target.global_position)
    _manager.set_batch_count(batch_count)
    _configure_renderer()
    _spawn_units()
    _samples.append(CSV_HEADER)


func _physics_process(delta: float) -> void:
    _move_target(delta)

    var started_usec: int = Time.get_ticks_usec()
    _flow.request_rebuild(_target.global_position)
    _last_flow_usec = Time.get_ticks_usec() - started_usec

    started_usec = Time.get_ticks_usec()
    _movement.update(_manager, _flow, delta)
    _last_movement_usec = Time.get_ticks_usec() - started_usec

    started_usec = Time.get_ticks_usec()
    _renderer.sync_from_manager(_manager)
    _last_render_usec = Time.get_ticks_usec() - started_usec

    _record_sample()
    _manager.advance_batch()
    _frame_index += 1
    if auto_export_after_samples and not _exported and _frame_index >= SAMPLE_LIMIT:
        export_csv()


func export_csv(path: String = report_path) -> Error:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    for line: String in _samples:
        file.store_line(line)
    file.close()
    _exported = true
    return OK


func get_sample_count() -> int:
    return maxi(0, _samples.size() - 1)


func get_swarm_update_usec() -> int:
    return _last_flow_usec + _last_movement_usec + _last_render_usec


func _configure_renderer() -> void:
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(0.55, 0.35, 0.8)
    var shader: Shader = load("res://assets/materials/swarm_crawl.gdshader") as Shader
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = shader
    _renderer.configure_type(0, mesh, material)


func _spawn_units() -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 311
    for index: int in range(UNIT_COUNT):
        var angle: float = TAU * float(index) / float(UNIT_COUNT)
        var radius: float = rng.randf_range(14.0, 27.0)
        var position: Vector3 = Vector3(cos(angle) * radius, 0.25, sin(angle) * radius)
        _manager.spawn(position, Vector3.ZERO, 20.0, 0)
        _renderer.set_instance_color(0, index, Color(0.75 + rng.randf() * 0.2, 0.85, 0.65, 1.0))


func _move_target(delta: float) -> void:
    var input_vector: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if input_vector.length_squared() <= 0.001:
        return
    var movement: Vector3 = Vector3(input_vector.x, 0.0, input_vector.y) * 8.0 * delta
    _target.position.x = clampf(_target.position.x + movement.x, -28.0, 28.0)
    _target.position.z = clampf(_target.position.z + movement.z, -28.0, 28.0)


func _record_sample() -> void:
    var swarm_usec: int = get_swarm_update_usec()
    var frame_msec: float = 1000.0 / maxf(1.0, Engine.get_frames_per_second())
    _samples.append("%d,%d,%d,%d,%d,%d,%.3f,%.3f" % [
        _frame_index,
        _manager.get_alive_count(),
        _manager.get_batch_count(),
        _last_flow_usec,
        _last_movement_usec,
        _last_render_usec,
        float(swarm_usec) / 1000.0,
        frame_msec,
    ])
    if _hud != null:
        _hud.text = (
            "SWARM PERF\nAlive: %d / %d  |  Batches: %d\nFlow: %.3f ms\nMovement: %.3f ms\nRender sync: %.3f ms\nSwarm total: %.3f / 3.000 ms\nFrame: %.3f / 16.600 ms\nCSV: %s"
            % [
                _manager.get_alive_count(), UNIT_COUNT, _manager.get_batch_count(),
                float(_last_flow_usec) / 1000.0, float(_last_movement_usec) / 1000.0,
                float(_last_render_usec) / 1000.0, float(swarm_usec) / 1000.0,
                frame_msec, report_path,
            ]
        )
