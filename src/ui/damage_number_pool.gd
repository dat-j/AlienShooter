class_name DamageNumberPool
extends Node3D

## Cấp phát và giới hạn số sát thương bay lên. Xem docs/04-UX-UI.md §2.4 và
## docs/05-BACKLOG.md T-607.
##
## Ba ràng buộc, theo thứ tự quan trọng:
##  1. **Gộp sát thương swarm.** Bắn một loạt vào 40 con thì hiện MỘT con số
##     tổng ở trọng tâm, không phải 40 con số chồng lên nhau. Đây là lý do
##     `SwarmManager` chốt sổ mỗi frame thay vì báo từng con.
##  2. **Trần 40 cái** cùng lúc, FIFO (TDD §12.7).
##  3. **Tắt được** qua thiết lập — có người thấy số nhảy là rối mắt.

const MAX_NUMBERS: int = 40
## Dưới ngưỡng này thì không đáng hiện: nhiễu thị giác nhiều hơn thông tin.
const MIN_AMOUNT: float = 0.5
## Nhấc số lên khỏi tâm mục tiêu cho khỏi lọt vào trong mesh.
const SPAWN_HEIGHT: float = 1.0

@export var number_scene: PackedScene
## SwarmManager của màn chơi; để trống thì chỉ hiện số cho actor và mech.
@export var swarm_path: NodePath

var _active: Array[DamageNumber] = []
var _swarm: SwarmManager = null


func _ready() -> void:
    bind(get_node_or_null(swarm_path) as SwarmManager)
    EventBus.damage_dealt.connect(_on_damage_dealt)


func _exit_tree() -> void:
    bind(null)
    if EventBus.damage_dealt.is_connected(_on_damage_dealt):
        EventBus.damage_dealt.disconnect(_on_damage_dealt)


func bind(swarm: SwarmManager) -> void:
    if _swarm != null and _swarm.damage_reported.is_connected(_on_swarm_damage_reported):
        _swarm.damage_reported.disconnect(_on_swarm_damage_reported)
    _swarm = swarm
    if _swarm != null and not _swarm.damage_reported.is_connected(_on_swarm_damage_reported):
        _swarm.damage_reported.connect(_on_swarm_damage_reported)


## Hiện một con số. Trả về null khi thiết lập đang tắt damage number, sát
## thương quá nhỏ, hoặc chưa có scene.
func show_damage(position: Vector3, amount: float, is_critical: bool = false) -> DamageNumber:
    if not is_enabled() or amount < MIN_AMOUNT or number_scene == null or not is_inside_tree():
        return null
    _recycle_if_full()
    var node: Node = PoolManager.acquire(number_scene)
    var number := node as DamageNumber
    if number == null:
        PoolManager.release(node)
        return null
    add_child(number)
    number.show_damage(position + Vector3.UP * SPAWN_HEIGHT, amount, is_critical)
    _active.append(number)
    return number


func is_enabled() -> bool:
    return SettingsManager.get_value(&"accessibility", &"damage_numbers", true)


func get_active_count() -> int:
    _prune()
    return _active.size()


func clear_all() -> void:
    for number: DamageNumber in _active:
        if is_instance_valid(number) and number.is_active():
            PoolManager.release(number)
    _active.clear()


## Cả frame gộp thành đúng một con số ở trọng tâm những chỗ vừa trúng đòn.
func _on_swarm_damage_reported(centre: Vector3, total: float, _hits: int, _kills: int) -> void:
    show_damage(centre, total, false)


## Sát thương lên actor và mech đi qua DamageResolver nên báo từng đòn —
## số lượng ở đây nhỏ (tối đa 30 actor), không cần gộp.
func _on_damage_dealt(_target_id: int, info: DamageInfo) -> void:
    if info == null:
        return
    show_damage(info.source_position, info.amount, info.is_critical)


func _prune() -> void:
    var kept: Array[DamageNumber] = []
    for number: DamageNumber in _active:
        if is_instance_valid(number) and number.is_active():
            kept.append(number)
    _active = kept


func _recycle_if_full() -> void:
    _prune()
    while _active.size() >= MAX_NUMBERS:
        var oldest: DamageNumber = _active.pop_front()
        if is_instance_valid(oldest) and oldest.is_active():
            PoolManager.release(oldest)
