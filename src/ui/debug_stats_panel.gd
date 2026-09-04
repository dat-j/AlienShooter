class_name DebugStatsPanel
extends Label

## Bảng số liệu của sân tập (T-111): tốc độ, vị trí, frame time.
## CHỈ dùng trong build debug — T-1502 loại bỏ hoàn toàn khỏi build phát hành,
## nên phần chữ ở đây không đi qua `tr()` như UI thật.

const UPDATE_INTERVAL: float = 0.1

@export var mech_path: NodePath

var _elapsed: float = 0.0

@onready var _mech: MechController = get_node_or_null(mech_path) as MechController


func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed < UPDATE_INTERVAL:
        return
    _elapsed = 0.0
    text = build_text(_mech, delta)


## Hàm thuần tuý để test được: dựng chuỗi từ trạng thái mech.
static func build_text(mech: MechController, delta: float) -> String:
    if mech == null:
        return "chưa gắn mech"
    var horizontal := Vector2(mech.velocity.x, mech.velocity.z)
    var chassis_name: String = "—"
    if mech.chassis_data != null:
        chassis_name = String(mech.chassis_data.id)
    return "\n".join([
        "chassis   %s" % chassis_name,
        "toc do    %5.2f m/s" % horizontal.length(),
        "vi tri    %6.1f, %5.1f, %6.1f" % [
            mech.global_position.x, mech.global_position.y, mech.global_position.z
        ],
        "than/chan %6.1f / %6.1f do" % [
            rad_to_deg(mech.torso_pivot.rotation.y), rad_to_deg(mech.legs_pivot.rotation.y)
        ],
        "frame     %5.2f ms (%d fps)" % [delta * 1000.0, Engine.get_frames_per_second()],
        "cham dat  %s" % ("co" if mech.is_on_floor() else "khong"),
    ])
