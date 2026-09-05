class_name ShellEjector
extends RefCounted

## Quản lý vòng đời vỏ đạn cho một hardpoint. Xem docs/05-BACKLOG.md T-604
## và docs/02-TDD.md §12.7 (trần số lượng cho mọi hiệu ứng bề mặt).
##
## Trần 60 vỏ là trần **toàn cục**, không phải mỗi mount 60 cái: hai tay bắn
## Vulcan-X ở 16 phát/giây sẽ đạt trần trong chưa tới hai giây, và người chơi
## không phân biệt nổi 60 với 120 vỏ trên sàn — chỉ có frame time là phân
## biệt được. Đầy trần thì vỏ CŨ NHẤT bị thu hồi (FIFO).
##
## Vũ khí Energy và vũ khí liên tục không nhả vỏ.

const MAX_SHELLS: int = 60
## Vỏ văng sang phải và hơi ra sau, như súng thật.
const EJECT_SIDE_RATIO: float = 1.0
const EJECT_BACK_RATIO: float = 0.35

## Vòng FIFO dùng chung cho mọi ShellEjector — trần là của cả game.
static var _ring: Array[ShellCasing] = []
static var _next_slot: int = 0

var shell_scene: PackedScene
## Node cha để gắn vỏ. Để trống thì không nhả vỏ (test headless, editor).
var container: Node = null


## Nhả một vỏ. `origin` là miệng nòng, `forward` là hướng bắn — vỏ văng
## vuông góc với nó. Trả về vỏ vừa nhả, hoặc null nếu không nhả được.
func eject(origin: Vector3, forward: Vector3) -> ShellCasing:
    if shell_scene == null or container == null or not container.is_inside_tree():
        return null
    var flat := Vector3(forward.x, 0.0, forward.z)
    if flat.length_squared() <= 0.000001:
        flat = Vector3.FORWARD
    flat = flat.normalized()
    var side: Vector3 = flat.cross(Vector3.UP).normalized()
    var direction: Vector3 = side * EJECT_SIDE_RATIO - flat * EJECT_BACK_RATIO

    _recycle_if_full()
    var node: Node = PoolManager.acquire(shell_scene)
    var shell := node as ShellCasing
    if shell == null:
        PoolManager.release(node)
        return null
    container.add_child(shell)
    shell.eject(origin, direction)
    _track(shell)
    return shell


## Vỏ nào đã tự trả về pool (hết 4 giây) thì bỏ khỏi sổ theo dõi.
static func prune() -> void:
    var kept: Array[ShellCasing] = []
    for shell: ShellCasing in _ring:
        if is_instance_valid(shell) and shell.is_active():
            kept.append(shell)
    _ring = kept
    _next_slot = 0


static func get_active_count() -> int:
    prune()
    return _ring.size()


## Dọn sạch khi đổi màn hoặc trong teardown của test.
static func clear_all() -> void:
    for shell: ShellCasing in _ring:
        if is_instance_valid(shell) and shell.is_active():
            PoolManager.release(shell)
    _ring.clear()
    _next_slot = 0


func _track(shell: ShellCasing) -> void:
    _ring.append(shell)


## Đầy trần thì thu hồi vỏ cũ nhất còn sống. Duyệt từ đầu mảng nên đúng là
## FIFO, không phải "cái nào tiện thì lấy".
func _recycle_if_full() -> void:
    prune()
    while _ring.size() >= MAX_SHELLS:
        var oldest: ShellCasing = _ring.pop_front()
        if is_instance_valid(oldest) and oldest.is_active():
            PoolManager.release(oldest)
