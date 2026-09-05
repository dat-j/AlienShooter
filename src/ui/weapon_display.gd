class_name WeaponDisplay
extends Control

## Ô vũ khí góc dưới phải HUD. Xem docs/04-UX-UI.md §2 và
## docs/05-BACKLOG.md T-511.
##
## Hai dòng, trái trên phải dưới, đúng thứ tự trong sơ đồ HUD:
##     ◀ MK2 AUTOCANNON        248 / 360
##     ▶ PULSE LASER           NĂNG LƯỢNG
##
## Đây là mục ưu tiên chú ý thứ 5 (UX-UI §2.1) — người chơi chỉ liếc khi có
## nhịp nghỉ. Vì vậy nó ở mép màn, chữ nhỏ, và chỉ **nháy đỏ khi hết đạn**,
## thứ duy nhất đáng cắt ngang sự chú ý.

## Chuỗi hiển thị đi qua khoá dịch, không viết thẳng (TDD §16).
const KEY_ENERGY: String = "hud.weapon.energy"
const KEY_EMPTY: String = "hud.weapon.empty"
const MARKER_LEFT: String = "◀"
const MARKER_RIGHT: String = "▶"

const FLASH_HZ: float = 4.0
## Bảng màu docs/03-ART-BIBLE.md §2.
const COLOR_NORMAL := Color(0.282, 0.839, 0.878)    # Cyan HUD
const COLOR_EMPTY := Color(0.878, 0.231, 0.231)     # Đỏ nguy hiểm
const COLOR_BUILD_UP := Color(0.949, 0.761, 0.188)  # Vàng cảnh báo

@export var mech_path: NodePath

var _mech: MechController = null
var _flash_phase: float = 0.0

@onready var _left_name: Label = $Panel/Rows/Left/Name
@onready var _left_ammo: Label = $Panel/Rows/Left/Ammo
@onready var _left_build_up: ProgressBar = $Panel/Rows/Left/BuildUp
@onready var _right_name: Label = $Panel/Rows/Right/Name
@onready var _right_ammo: Label = $Panel/Rows/Right/Ammo
@onready var _right_build_up: ProgressBar = $Panel/Rows/Right/BuildUp


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    bind(get_node_or_null(mech_path) as MechController)


func _process(delta: float) -> void:
    _flash_phase += delta
    if _mech == null:
        return
    _refresh(_mech.weapon_mount_left, MARKER_LEFT, _left_name, _left_ammo, _left_build_up)
    _refresh(_mech.weapon_mount_right, MARKER_RIGHT, _right_name, _right_ammo, _right_build_up)


## Nối vào mech của màn chơi. Gọi được nhiều lần (đổi màn, hồi sinh).
func bind(mech: MechController) -> void:
    _mech = mech
    _flash_phase = 0.0
    if mech == null:
        return
    _refresh(mech.weapon_mount_left, MARKER_LEFT, _left_name, _left_ammo, _left_build_up)
    _refresh(mech.weapon_mount_right, MARKER_RIGHT, _right_name, _right_ammo, _right_build_up)


## Hàm thuần tuý: dòng đạn của một mount.
## Vũ khí Energy không có đạn nên hiện khoá "NĂNG LƯỢNG" thay cho con số.
##
## Dịch qua TranslationServer chứ không qua Object.tr(): hàm static không có
## instance nên không gọi được tr(). Khi chưa có file dịch (T-1503) thì cả
## hai đều trả về chính khoá.
static func ammo_text(uses_ammo: bool, current: int, maximum: int) -> String:
    if not uses_ammo:
        return translate(KEY_ENERGY)
    if current <= 0:
        return translate(KEY_EMPTY)
    return "%d / %d" % [current, maximum]


## Hàm thuần tuý: tên vũ khí trên HUD, kèm dấu chỉ tay trái/phải.
static func name_text(data: WeaponData, marker: String) -> String:
    if data == null:
        return "%s —" % marker
    return "%s %s" % [marker, translate(data.display_name_key)]


## Hàm thuần tuý: màu dòng đạn. Hết đạn thì nháy đỏ theo `phase` (giây).
static func ammo_color(is_out_of_ammo: bool, phase: float) -> Color:
    if not is_out_of_ammo:
        return COLOR_NORMAL
    var blink: float = 0.5 + 0.5 * sin(phase * TAU * FLASH_HZ)
    return COLOR_NORMAL.lerp(COLOR_EMPTY, blink)


## Hàm thuần tuý: tra khoá dịch từ ngữ cảnh static.
static func translate(key: String) -> String:
    return String(TranslationServer.translate(key))


func _refresh(
    mount: WeaponMount,
    marker: String,
    name_label: Label,
    ammo_label: Label,
    build_up: ProgressBar
) -> void:
    if mount == null:
        return
    name_label.text = name_text(mount.weapon_data, marker)
    ammo_label.text = ammo_text(mount.uses_ammo(), mount.get_ammo(), mount.get_max_ammo())
    ammo_label.add_theme_color_override(&"font_color", ammo_color(mount.is_out_of_ammo(), _flash_phase))
    var ratio: float = Crosshair.build_up_ratio(mount)
    build_up.value = ratio * 100.0
    # Thanh sạc/quay nòng chỉ hiện khi đang thực sự nạp — HUD phải im lặng
    # khi không có gì để nói.
    build_up.visible = ratio < 1.0
    build_up.modulate = COLOR_BUILD_UP
