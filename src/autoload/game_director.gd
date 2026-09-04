extends Node

## Máy trạng thái cấp cao nhất của game + điều phối chuyển cảnh bất đồng bộ.
## Xem docs/02-TDD.md §4 (luật vàng autoload) và §4.1 (sơ đồ chuyển trạng thái).
##
## Luật vàng: autoload không bao giờ giữ tham chiếu tới node bên trong một
## màn chơi. GameDirector chỉ biết về `res://scenes/main/main.tscn` (chính nó
## quản lý vòng đời của scene đó) và các scene cấp cao nhất nó tự nạp/gắn vào
## `Main/SceneContainer` — không bao giờ với tới node bên trong các scene đó.

enum State {
    BOOT,
    MAIN_MENU,
    HANGAR,
    LOADOUT,
    MISSION_LOADING,
    MISSION_ACTIVE,
    MISSION_DEBRIEF,
    MISSION_FAILED,
}

signal state_changed(from: State, to: State)

## Bảng tra cứu tường minh cho sơ đồ ở TDD §4.1:
##   BOOT → MAIN_MENU → HANGAR ⇄ LOADOUT
##                        ↓          ↓
##                     MISSION_LOADING → MISSION_ACTIVE → MISSION_DEBRIEF → HANGAR
##                                             ↓
##                                        MISSION_FAILED → HANGAR
const _TRANSITIONS: Dictionary = {
    State.BOOT: [State.MAIN_MENU],
    State.MAIN_MENU: [State.HANGAR],
    State.HANGAR: [State.LOADOUT, State.MISSION_LOADING],
    State.LOADOUT: [State.HANGAR, State.MISSION_LOADING],
    State.MISSION_LOADING: [State.MISSION_ACTIVE],
    State.MISSION_ACTIVE: [State.MISSION_DEBRIEF, State.MISSION_FAILED],
    State.MISSION_DEBRIEF: [State.HANGAR],
    State.MISSION_FAILED: [State.HANGAR],
}

## Scene cấp cao nhất gắn với mỗi trạng thái. Trạng thái chưa có scene thật
## (LOADOUT, MISSION_LOADING, MISSION_ACTIVE, MISSION_DEBRIEF, MISSION_FAILED)
## sẽ được các task sau bổ sung vào bảng này khi scene tương ứng ra đời.
const _STATE_SCENES: Dictionary = {
    State.MAIN_MENU: "res://scenes/ui/menus/main_menu.tscn",
    State.HANGAR: "res://scenes/ui/hangar/hangar.tscn",
}

## Đường dẫn tới node chứa scene đang hoạt động bên trong `main.tscn`.
const _SCENE_CONTAINER_PATH: NodePath = ^"Main/SceneContainer"

var _current_state: State = State.BOOT
var _pending_scene_path: String = ""
var _is_loading: bool = false
var _active_scene: Node = null


func _ready() -> void:
    # Kích hoạt chuyển cảnh đầu tiên của game. Lúc này `main.tscn` (run/main_scene)
    # có thể chưa vào cây scene (autoload _ready chạy trước main scene), nhưng
    # ResourceLoader không cần cây scene để bắt đầu nạp — việc gắn scene vào
    # `Main/SceneContainer` chỉ diễn ra sau, trong _process(), khi main.tscn
    # chắc chắn đã vào cây (trước khung hình đầu tiên).
    request_state(State.MAIN_MENU)


func _process(_delta: float) -> void:
    if not _is_loading:
        return
    var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_pending_scene_path)
    if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        return
    _is_loading = false
    if status != ResourceLoader.THREAD_LOAD_LOADED:
        Log.error("Tải scene thất bại (trạng thái tải %d): %s" % [status, _pending_scene_path], "GameDirector")
        return
    var packed: PackedScene = ResourceLoader.load_threaded_get(_pending_scene_path) as PackedScene
    _attach_scene(packed)


## Yêu cầu chuyển sang `next`. Trả về `false` và ghi `Log.warn` nếu chuyển
## không hợp lệ theo sơ đồ TDD §4.1; trạng thái giữ nguyên trong trường hợp đó.
## Khi hợp lệ: trạng thái đổi ngay (đồng bộ), `state_changed` phát ngay, và
## việc nạp scene tương ứng (nếu có) chạy nền qua `ResourceLoader.load_threaded_request`.
func request_state(next: State) -> bool:
    var current: State = _current_state
    if not is_transition_allowed(current, next):
        Log.warn("Chuyển trạng thái không hợp lệ: %s → %s" % [
                State.keys()[current], State.keys()[next]], "GameDirector")
        return false
    _current_state = next
    state_changed.emit(current, next)
    Log.info("GameDirector: %s → %s" % [State.keys()[current], State.keys()[next]], "GameDirector")
    _start_scene_load(next)
    return true


func get_state() -> State:
    return _current_state


## Hàm thuần tuý — không phụ thuộc engine/scene tree — tra bảng `_TRANSITIONS`.
func is_transition_allowed(from: State, to: State) -> bool:
    if not _TRANSITIONS.has(from):
        return false
    var allowed: Array = _TRANSITIONS[from]
    return allowed.has(to)


## Bắt đầu nạp bất đồng bộ scene gắn với `state` (nếu có khai báo trong
## `_STATE_SCENES`). Không bao giờ dùng `change_scene_to_file()`.
func _start_scene_load(state: State) -> void:
    var scene_path: String = String(_STATE_SCENES.get(state, ""))
    if scene_path.is_empty():
        return
    var err: Error = ResourceLoader.load_threaded_request(scene_path)
    if err != OK:
        Log.error("Không thể bắt đầu tải scene cho trạng thái %s (lỗi %d): %s" % [
                State.keys()[state], err, scene_path], "GameDirector")
        return
    _pending_scene_path = scene_path
    _is_loading = true


## Gắn scene vừa nạp xong vào `Main/SceneContainer`, giải phóng scene cũ.
## Tra `get_node_or_null` chỉ diễn ra một lần khi một lượt tải vừa hoàn tất —
## không phải mỗi khung hình — nên không rơi vào luật cấm ở TDD §12.3 (luật đó
## nhắm tới việc duyệt cây mỗi frame trong đường nóng chiến đấu).
func _attach_scene(packed: PackedScene) -> void:
    if packed == null:
        return
    var container: Node = _find_scene_container()
    if container == null:
        Log.warn("Không tìm thấy %s để gắn scene; bỏ qua hiển thị" % String(_SCENE_CONTAINER_PATH), "GameDirector")
        return
    if _active_scene != null and is_instance_valid(_active_scene):
        _active_scene.queue_free()
    _active_scene = packed.instantiate()
    container.add_child(_active_scene)


func _find_scene_container() -> Node:
    var tree: SceneTree = get_tree()
    if tree == null:
        return null
    return tree.root.get_node_or_null(_SCENE_CONTAINER_PATH)
