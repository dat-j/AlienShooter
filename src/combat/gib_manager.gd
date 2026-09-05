class_name GibManager
extends Node3D

## VFX trúng đích và xác quái. Xem docs/03-ART-BIBLE.md §8 và
## docs/05-BACKLOG.md T-605.
##
## Vấn đề trung tâm của task này KHÔNG phải là vẽ được mảnh vụn — mà là **đừng
## vẽ 300 cái cùng lúc**. Một quả Mortar Pod rơi vào giữa đàn có thể giết 60
## con trong đúng một frame; nếu mỗi con nhả một cụm hạt thì frame đó chết.
##
## Hai hàng rào:
##  * `SwarmManager` chỉ sinh VFX chết riêng lẻ cho `MAX_DEATH_VFX_PER_FRAME`
##    con đầu tiên mỗi frame.
##  * Node này nghe `damage_reported` — một bản tổng kết mỗi frame — và với
##    đợt chết hàng loạt thì nổ **một** cụm gộp ở trọng tâm thay vì n cụm.
##
## Trần 60 mảnh vụn là trần toàn cục, FIFO (TDD §12.7).

## Số con chết trong cùng một frame để được coi là "chết hàng loạt".
const MASS_DEATH_THRESHOLD: int = 10
const MAX_GIBS: int = 60
## Số mảnh vụn của một cái chết lẻ, và của một cụm gộp.
const GIBS_PER_DEATH: int = 3
const GIBS_PER_MASS_BURST: int = 8
const BURST_SPEED: float = 4.5
const BURST_UP: float = 3.0

enum Surface {
    METAL,
    FLESH,
}

@export var gib_scene: PackedScene
@export var impact_metal_scene: PackedScene
@export var impact_flesh_scene: PackedScene
## SwarmManager của màn chơi; để trống thì chỉ phục vụ actor và tường.
@export var swarm_path: NodePath

var _gibs: Array[Gib] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _swarm: SwarmManager = null


func _ready() -> void:
    bind(get_node_or_null(swarm_path) as SwarmManager)


func _exit_tree() -> void:
    bind(null)


## Nối vào SwarmManager của màn chơi. Gọi lại được (đổi màn, hồi sinh).
func bind(swarm: SwarmManager) -> void:
    if _swarm != null and _swarm.damage_reported.is_connected(_on_swarm_damage_reported):
        _swarm.damage_reported.disconnect(_on_swarm_damage_reported)
    _swarm = swarm
    if _swarm != null and not _swarm.damage_reported.is_connected(_on_swarm_damage_reported):
        _swarm.damage_reported.connect(_on_swarm_damage_reported)


## VFX trúng đích. Kim loại toé tia lửa, thịt bắn giọt — hai thứ phải nhìn
## khác nhau tức thì, đó là cách người chơi biết mình có đang bắn trúng
## hay chỉ đang bắn vào tường (ART-BIBLE §8).
func spawn_impact(position: Vector3, normal: Vector3, surface: Surface) -> Node3D:
    var scene: PackedScene = impact_flesh_scene if surface == Surface.FLESH else impact_metal_scene
    if scene == null or not is_inside_tree():
        return null
    var node: Node = PoolManager.acquire(scene)
    var effect := node as ImpactVfx
    if effect == null:
        PoolManager.release(node)
        return null
    add_child(effect)
    effect.play(position, normal)
    return effect


## Một cái chết lẻ: vài mảnh vụn bắn ra từ chỗ chết.
func spawn_death_gibs(position: Vector3, count: int = GIBS_PER_DEATH) -> int:
    var spawned: int = 0
    for _i: int in range(maxi(count, 0)):
        if _spawn_gib(position) != null:
            spawned += 1
    return spawned


## Hàm thuần tuý: một frame chết `kills` con thì nổ bao nhiêu cụm mảnh vụn.
## Dưới ngưỡng thì mỗi con một cụm; trên ngưỡng thì gộp thành đúng một cụm
## to ở trọng tâm — đây là điều kiện nghiệm thu của T-605.
static func gib_count_for_kills(kills: int) -> int:
    if kills <= 0:
        return 0
    if kills < MASS_DEATH_THRESHOLD:
        return kills * GIBS_PER_DEATH
    return GIBS_PER_MASS_BURST


func get_active_gib_count() -> int:
    _prune()
    return _gibs.size()


func clear_all() -> void:
    for gib: Gib in _gibs:
        if is_instance_valid(gib) and gib.is_active():
            PoolManager.release(gib)
    _gibs.clear()


func _on_swarm_damage_reported(centre: Vector3, _total: float, _hits: int, kills: int) -> void:
    var count: int = gib_count_for_kills(kills)
    for _i: int in range(count):
        _spawn_gib(centre)


func _spawn_gib(position: Vector3) -> Gib:
    if gib_scene == null or not is_inside_tree():
        return null
    _recycle_if_full()
    var node: Node = PoolManager.acquire(gib_scene)
    var gib := node as Gib
    if gib == null:
        PoolManager.release(node)
        return null
    add_child(gib)
    var impulse := Vector3(
        _rng.randf_range(-BURST_SPEED, BURST_SPEED),
        _rng.randf_range(BURST_UP * 0.4, BURST_UP),
        _rng.randf_range(-BURST_SPEED, BURST_SPEED)
    )
    gib.burst(position, impulse)
    _gibs.append(gib)
    return gib


func _prune() -> void:
    var kept: Array[Gib] = []
    for gib: Gib in _gibs:
        if is_instance_valid(gib) and gib.is_active():
            kept.append(gib)
    _gibs = kept


func _recycle_if_full() -> void:
    _prune()
    while _gibs.size() >= MAX_GIBS:
        var oldest: Gib = _gibs.pop_front()
        if is_instance_valid(oldest) and oldest.is_active():
            PoolManager.release(oldest)
