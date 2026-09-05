class_name MechVfx
extends Node

## VFX nhiệt và giáp của mech. Xem docs/03-ART-BIBLE.md §8 và
## docs/05-BACKLOG.md T-608.
##
## Ba tín hiệu, cả ba đều là **tín hiệu gameplay chứ không phải trang trí**:
##  * Cột hơi khi xả nhiệt — người chơi phải thấy rõ mình vừa xả thành công,
##    vì trong 0.8 giây đó mech đứng yên và ăn thêm 30% sát thương.
##  * Ánh đỏ trên thân khi nhiệt cao — đọc được mức nhiệt mà không rời mắt
##    khỏi trận đánh (UX-UI §2.1).
##  * Mảnh giáp bay ra khi một vùng vỡ — biết vùng nào vừa mất giáp.
##
## Node này chỉ ĐỌC `HeatComponent`; nó không bao giờ sửa nhiệt.

const HEAT_GLOW_PARAM: StringName = &"heat_glow"
## Dưới ngưỡng này thì thân mech không ửng đỏ chút nào — dải nhiệt thấp phải
## sạch để dải nhiệt cao mới đáng sợ.
const GLOW_START_RATIO: float = 0.45
## Nhiệt tụt nhanh hơn mắt kịp theo; làm mượt cho ánh sáng không nhấp nháy.
const GLOW_LERP: float = 6.0

@export var mech_path: NodePath = NodePath("..")
## Các mesh mang vật liệu `mech_heat.gdshader`.
@export var glow_mesh_paths: Array[NodePath] = []
@export var vent_steam_scene: PackedScene
@export var plate_break_scene: PackedScene

var _mech: MechController = null
var _heat: HeatComponent = null
var _glow: float = 0.0
var _meshes: Array[MeshInstance3D] = []


func _ready() -> void:
    _mech = get_node_or_null(mech_path) as MechController
    if _mech != null:
        _heat = _mech.heat_component
    for path: NodePath in glow_mesh_paths:
        var mesh := get_node_or_null(path) as MeshInstance3D
        if mesh != null:
            _meshes.append(mesh)
    if _heat != null:
        _heat.vent_completed.connect(_on_vent_completed)
    EventBus.armor_plate_broken.connect(_on_armor_plate_broken)


func _exit_tree() -> void:
    if EventBus.armor_plate_broken.is_connected(_on_armor_plate_broken):
        EventBus.armor_plate_broken.disconnect(_on_armor_plate_broken)


func _process(delta: float) -> void:
    if _heat == null:
        return
    var target: float = glow_for_ratio(_heat.get_heat_ratio(), _heat.is_overheated())
    _glow = lerpf(_glow, target, clampf(GLOW_LERP * delta, 0.0, 1.0))
    apply_glow(_glow)


## Hàm thuần tuý: tỉ lệ nhiệt → cường độ ánh đỏ. Quá nhiệt luôn là 1.0 bất
## kể nhiệt còn lại bao nhiêu — trạng thái đó phải hét lên.
static func glow_for_ratio(heat_ratio: float, is_overheated: bool) -> float:
    if is_overheated:
        return 1.0
    if heat_ratio <= GLOW_START_RATIO:
        return 0.0
    return clampf((heat_ratio - GLOW_START_RATIO) / (1.0 - GLOW_START_RATIO), 0.0, 1.0)


## Đẩy tham số vào shader của mọi mesh đã đăng ký.
func apply_glow(amount: float) -> void:
    for mesh: MeshInstance3D in _meshes:
        var material := mesh.get_active_material(0) as ShaderMaterial
        if material != null:
            material.set_shader_parameter(HEAT_GLOW_PARAM, amount)


func get_glow() -> float:
    return _glow


## Cột hơi xả nhiệt. Gọi được trực tiếp để test không phải chạy đủ 0.8 giây
## giữ nút xả.
func play_vent_steam() -> Node3D:
    return _spawn(vent_steam_scene, _mech_position())


## Mảnh giáp bay ra khi một vùng vỡ.
func play_plate_break() -> Node3D:
    return _spawn(plate_break_scene, _mech_position())


func _spawn(scene: PackedScene, position: Vector3) -> Node3D:
    if scene == null or _mech == null or not _mech.is_inside_tree():
        return null
    var node: Node = PoolManager.acquire(scene)
    var effect := node as ImpactVfx
    if effect == null:
        PoolManager.release(node)
        return null
    _mech.get_parent().add_child(effect)
    effect.play(position, Vector3.UP)
    return effect


func _mech_position() -> Vector3:
    return _mech.global_position if _mech != null else Vector3.ZERO


func _on_vent_completed(_amount_removed: float) -> void:
    play_vent_steam()


func _on_armor_plate_broken(_zone: int) -> void:
    play_plate_break()
