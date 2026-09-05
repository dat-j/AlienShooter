class_name DecalManager
extends Node3D

## Vết bẩn để lại trên sàn và tường. Xem docs/03-ART-BIBLE.md §8 và
## docs/05-BACKLOG.md T-606.
##
## ART-BIBLE nói thẳng vì sao thứ này đáng làm: *"chúng là thứ khiến căn
## phòng kể lại được trận đánh vừa diễn ra"*. Nhưng chúng cũng là thứ ăn
## fill-rate nhanh nhất, nên trần là bắt buộc chứ không phải tuỳ chọn.
##
## Trần đọc từ `SettingsManager` (`graphics/decal_limit`) nên preset đồ hoạ
## thấp tự động hạ trần xuống 40 mà không phải sửa code. Hàng đợi FIFO: đầy
## trần thì vết CŨ NHẤT biến mất, vì vết mới luôn là vết đáng nhìn hơn.

const DEFAULT_LIMIT: int = 150
## Chiều dày hộp chiếu của Decal. Đủ mỏng để không dính lên vật thể phía sau
## tường, đủ dày để bám được sàn gồ ghề.
const PROJECTION_DEPTH: float = 0.4
## Nhấc khỏi bề mặt một chút để không bị z-fighting với chính bề mặt đó.
const SURFACE_OFFSET: float = 0.02

## Mỗi loại vết một scene: máu, cháy, vết đạn (ART-BIBLE §8).
@export var decal_scenes: Dictionary = {}

var _active: Array[Decal] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _limit: int = DEFAULT_LIMIT


func _ready() -> void:
    refresh_limit()
    EventBus.settings_changed.connect(_on_settings_changed)


func _exit_tree() -> void:
    if EventBus.settings_changed.is_connected(_on_settings_changed):
        EventBus.settings_changed.disconnect(_on_settings_changed)


## Đặt một vết tại `position`, dán phẳng theo `normal` của bề mặt.
## `kind` tra trong `decal_scenes`; loại lạ thì không làm gì.
func spawn(position: Vector3, normal: Vector3, kind: StringName, size: float = 1.0) -> Decal:
    if not is_inside_tree() or _limit <= 0:
        return null
    var scene: PackedScene = decal_scenes.get(kind, null) as PackedScene
    if scene == null:
        return null
    _recycle_if_full()
    var node: Node = PoolManager.acquire(scene)
    var decal := node as Decal
    if decal == null:
        PoolManager.release(node)
        return null
    add_child(decal)
    decal.global_transform = build_transform(position, normal, size, _rng.randf_range(0.0, TAU))
    decal.visible = true
    _active.append(decal)
    return decal


## Hàm thuần tuý: đặt hộp chiếu của Decal sao cho nó chiếu DỌC THEO pháp
## tuyến bề mặt. Node `Decal` của Godot chiếu theo trục -Y cục bộ, nên +Y
## cục bộ phải trùng với pháp tuyến — nhờ vậy cùng một hàm dán được cả sàn
## (pháp tuyến hướng lên) lẫn tường (pháp tuyến nằm ngang).
static func build_transform(
    position: Vector3,
    normal: Vector3,
    size: float,
    spin: float
) -> Transform3D:
    var up := normal
    if up.length_squared() <= 0.000001:
        up = Vector3.UP
    up = up.normalized()
    # Trục tham chiếu phải không song song với pháp tuyến, nếu không tích có
    # hướng ra vector 0 và cả ma trận sụp.
    var reference: Vector3 = Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
    var right: Vector3 = reference.cross(up).normalized()
    # right × up (chứ không phải up × right): thứ tự kia cho hệ trục THUẬN
    # TAY TRÁI, định thức âm, và Godot lật ngược mặt chiếu của decal.
    var forward: Vector3 = right.cross(up).normalized()
    var basis := Basis(right, up, forward).rotated(up, spin)
    basis = basis.scaled(Vector3(size, PROJECTION_DEPTH, size))
    return Transform3D(basis, position + up * SURFACE_OFFSET)


## Đọc lại trần từ SettingsManager và cắt bớt nếu preset vừa hạ xuống.
func refresh_limit() -> void:
    _limit = int(SettingsManager.get_value(&"graphics", &"decal_limit", DEFAULT_LIMIT))
    _trim_to(_limit)


func get_limit() -> int:
    return _limit


func get_active_count() -> int:
    _prune()
    return _active.size()


func clear_all() -> void:
    for decal: Decal in _active:
        _retire(decal)
    _active.clear()


func _on_settings_changed(section: StringName) -> void:
    if section == &"graphics":
        refresh_limit()


func _prune() -> void:
    var kept: Array[Decal] = []
    for decal: Decal in _active:
        if is_instance_valid(decal):
            kept.append(decal)
    _active = kept


## Chừa đúng một chỗ cho vết sắp đặt.
func _recycle_if_full() -> void:
    _trim_to(_limit - 1)


## Cắt hàng đợi xuống còn nhiều nhất `keep` vết, bỏ vết CŨ NHẤT trước.
func _trim_to(keep: int) -> void:
    _prune()
    while _active.size() > maxi(keep, 0) and not _active.is_empty():
        _retire(_active.pop_front())


## `Decal` là node thuần của Godot, không có script nên không có hook
## `_on_released` để tự ẩn. Phải ẩn tay, nếu không vết đã thu hồi vẫn hiện
## ở gốc toạ độ của container pool.
func _retire(decal: Decal) -> void:
    if not is_instance_valid(decal):
        return
    decal.visible = false
    PoolManager.release(decal)
