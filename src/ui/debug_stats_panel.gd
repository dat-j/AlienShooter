class_name DebugStatsPanel
extends Label

## Bảng số liệu của sân tập (T-111): tốc độ, vị trí, frame time.
## CHỈ dùng trong build debug — T-1502 loại bỏ hoàn toàn khỏi build phát hành,
## nên phần chữ ở đây không đi qua `tr()` như UI thật.

const UPDATE_INTERVAL: float = 0.1

@export var mech_path: NodePath
@export var swarm_path: NodePath = NodePath("../../SwarmRuntime")

var _elapsed: float = 0.0

@onready var _mech: MechController = get_node_or_null(mech_path) as MechController
@onready var _swarm: SwarmRuntime = get_node_or_null(swarm_path) as SwarmRuntime


func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed < UPDATE_INTERVAL:
        return
    _elapsed = 0.0
    text = build_text(_mech, delta)
    if _swarm != null:
        text += "
swarm     %d con" % _swarm.get_alive_count()


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
        "core hp   %5.1f / %5.1f" % [
            mech.core_hp, mech.chassis_data.core_hp if mech.chassis_data != null else 0.0
        ],
        "dan       T %d  P %d" % [
            mech.weapon_mount_left.get_ammo(), mech.weapon_mount_right.get_ammo()
        ],
        "nhiet     %5.1f %s" % [mech.heat_component.get_heat(), _heat_flag(mech.heat_component)],
        "boost     %d nap%s" % [
            mech.boost_component.get_charges(),
            "  (dang luot)" if mech.boost_component.is_dashing() else ""
        ],
        "giap      T %3.0f  P %3.0f  S %3.0f  Tr %3.0f" % [
            mech.armor_component.get_plate(ArmorComponent.Zone.FRONT),
            mech.armor_component.get_plate(ArmorComponent.Zone.RIGHT),
            mech.armor_component.get_plate(ArmorComponent.Zone.REAR),
            mech.armor_component.get_plate(ArmorComponent.Zone.LEFT),
        ],
        "frame     %5.2f ms (%d fps)" % [delta * 1000.0, Engine.get_frames_per_second()],
        "cham dat  %s" % ("co" if mech.is_on_floor() else "khong"),
    ])


static func _heat_flag(heat: HeatComponent) -> String:
    if heat.is_overheated():
        return "QUA NHIET"
    if heat.is_venting():
        return "dang xa %.0f%%" % (heat.get_vent_progress() * 100.0)
    if heat.get_vent_cooldown_remaining() > 0.0:
        return "xa hoi %.1fs" % heat.get_vent_cooldown_remaining()
    return ""
