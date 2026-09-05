class_name Crosshair
extends Control

## Con trỏ ngắm tuỳ chỉnh. Xem docs/04-UX-UI.md §2.3 và docs/05-BACKLOG.md
## T-512.
##
## Vẽ bằng `_draw()` thay vì texture: mọi hình dạng ở đây đều là hình học
## đơn giản và phải **co giãn theo độ tản đạn** theo từng frame, nên vẽ trực
## tiếp rẻ hơn và không cần asset.
##
## Con trỏ hệ điều hành bị ẩn ngay khi node vào cây. Toàn bộ phép tính hình
## dạng nằm trong hàm static thuần tuý để test được mà không cần dựng
## viewport (xem `tests/test_crosshair.gd`).

## Bán kính vòng ngoài khi vũ khí không tản đạn.
const BASE_RADIUS: float = 14.0
## Mỗi độ tản đạn đẩy vòng ngoài ra bấy nhiêu pixel.
const PIXELS_PER_SPREAD_DEGREE: float = 2.2
const MAX_RADIUS: float = 90.0
const TICK_LENGTH: float = 6.0
const LINE_WIDTH: float = 2.0
const CENTRE_DOT_RADIUS: float = 1.6

## Thời gian hit marker tồn tại, theo docs/04-UX-UI.md §2.4 (cùng nhịp với
## damage number cho hai phản hồi trùng khớp nhau).
const HIT_MARKER_SECONDS: float = 0.25
const HIT_MARKER_OFFSET: float = 5.0
const HIT_MARKER_LENGTH: float = 7.0

## Bán kính quanh điểm ngắm được tính là "đang rê qua kẻ địch".
const HOVER_RADIUS: float = 1.2
const HOVER_MASK: int = 16          # ENEMY_HURTBOX

## Bảng màu docs/03-ART-BIBLE.md §2.
const COLOR_IDLE := Color(0.282, 0.839, 0.878)      # Cyan HUD
const COLOR_OVER_ENEMY := Color(0.878, 0.231, 0.231) # Đỏ nguy hiểm
const COLOR_HIT := Color(1.0, 1.0, 1.0)
const COLOR_CRIT := Color(0.949, 0.761, 0.188)      # Vàng cảnh báo
const COLOR_CHARGE := Color(0.949, 0.761, 0.188)

@export var mech_path: NodePath
@export var swarm_path: NodePath
## Ẩn con trỏ hệ điều hành. Tắt được để test/editor không cướp chuột.
@export var hide_os_cursor: bool = true

var _mech: MechController = null
var _swarm: SwarmManager = null
var _position: Vector2 = Vector2.ZERO
var _radius: float = BASE_RADIUS
var _build_up: float = 1.0
var _over_enemy: bool = false
var _hit_timer: float = 0.0
var _hit_is_critical: bool = false

## Buffer dùng lại cho truy vấn swarm — không cấp phát mỗi frame.
var _hover_ids: PackedInt32Array = PackedInt32Array()
var _hover_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


func _ready() -> void:
    _hover_ids.resize(SwarmManager.MAX_SWARM_UNITS)
    _hover_query.collide_with_areas = true
    _hover_query.collide_with_bodies = false
    _hover_query.collision_mask = HOVER_MASK
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    bind(get_node_or_null(mech_path) as MechController, get_node_or_null(swarm_path) as SwarmManager)
    if hide_os_cursor and not Engine.is_editor_hint():
        Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
    if not EventBus.damage_dealt.is_connected(_on_damage_dealt):
        EventBus.damage_dealt.connect(_on_damage_dealt)


func _exit_tree() -> void:
    if hide_os_cursor and not Engine.is_editor_hint():
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    if EventBus.damage_dealt.is_connected(_on_damage_dealt):
        EventBus.damage_dealt.disconnect(_on_damage_dealt)


func _process(delta: float) -> void:
    _hit_timer = maxf(0.0, _hit_timer - delta)
    _position = get_viewport().get_mouse_position()
    var mount: WeaponMount = _leading_mount()
    _radius = ring_radius(_spread_of(mount))
    _build_up = build_up_ratio(mount)
    _over_enemy = _check_over_enemy()
    queue_redraw()


func _draw() -> void:
    var ring: Color = ring_color(_over_enemy)
    # Bốn vạch chữ thập, không vẽ vòng tròn kín: tâm màn hình phải thoáng để
    # nhìn thấy mech và đám đông ngay dưới con trỏ (UX-UI §2.1).
    for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
        draw_line(
            _position + direction * _radius,
            _position + direction * (_radius + TICK_LENGTH),
            ring,
            LINE_WIDTH
        )
    draw_circle(_position, CENTRE_DOT_RADIUS, ring)
    if _build_up < 1.0:
        # Vòng cung mờ chạy hết vòng khi sạc/quay nòng xong.
        draw_arc(_position, _radius - 4.0, -PI * 0.5, -PI * 0.5 + TAU * _build_up, 24, COLOR_CHARGE, LINE_WIDTH)
    if _hit_timer > 0.0:
        _draw_hit_marker()


## Bật hit marker. Hệ thống nào gây sát thương cũng gọi được — vũ khí bắn
## tức thời gọi qua `WeaponMount.hit_landed`, sát thương lên actor đi qua
## `EventBus.damage_dealt`.
func show_hit_marker(is_critical: bool = false) -> void:
    # Chí mạng thắng: trong một loạt đạn, cú chí mạng là thứ đáng báo nhất.
    # Phải đọc _hit_timer TRƯỚC khi nạp lại nó, nếu không điều kiện luôn đúng.
    _hit_is_critical = is_critical or (_hit_timer > 0.0 and _hit_is_critical)
    _hit_timer = HIT_MARKER_SECONDS


## Nối vào mech và swarm của màn chơi. Gọi được nhiều lần (đổi màn, hồi sinh).
func bind(mech: MechController, swarm: SwarmManager) -> void:
    _disconnect_mounts()
    _mech = mech
    _swarm = swarm
    _connect_mounts()


func get_radius() -> float:
    return _radius


func is_over_enemy() -> bool:
    return _over_enemy


func is_hit_marker_visible() -> bool:
    return _hit_timer > 0.0


func is_hit_marker_critical() -> bool:
    return _hit_is_critical


## Hàm thuần tuý: độ tản đạn (độ) → bán kính vòng ngoài (pixel).
static func ring_radius(spread_degrees: float) -> float:
    return clampf(BASE_RADIUS + maxf(spread_degrees, 0.0) * PIXELS_PER_SPREAD_DEGREE, BASE_RADIUS, MAX_RADIUS)


## Hàm thuần tuý: màu vòng ngoài.
static func ring_color(over_enemy: bool) -> Color:
    return COLOR_OVER_ENEMY if over_enemy else COLOR_IDLE


## Hàm thuần tuý: màu hit marker. Chí mạng khác màu để phân biệt không cần đọc số.
static func marker_color(is_critical: bool) -> Color:
    return COLOR_CRIT if is_critical else COLOR_HIT


## Hàm thuần tuý: tiến độ sạc/quay nòng của một mount, 1.0 = sẵn sàng bắn.
static func build_up_ratio(mount: WeaponMount) -> float:
    if mount == null:
        return 1.0
    return minf(mount.get_charge_ratio(), mount.get_spin_ratio())


func _draw_hit_marker() -> void:
    var color: Color = marker_color(_hit_is_critical)
    color.a = _hit_timer / HIT_MARKER_SECONDS
    for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
        var start: Vector2 = _position + corner * HIT_MARKER_OFFSET
        draw_line(start, start + corner * HIT_MARKER_LENGTH, color, LINE_WIDTH)


## Mount đang sạc/quay nòng được ưu tiên; nếu cả hai đều rảnh thì lấy mount
## trái làm chuẩn cho độ tản đạn.
func _leading_mount() -> WeaponMount:
    if _mech == null:
        return null
    var left: WeaponMount = _mech.weapon_mount_left
    var right: WeaponMount = _mech.weapon_mount_right
    if left == null:
        return right
    if right == null:
        return left
    return right if build_up_ratio(right) < build_up_ratio(left) else left


func _spread_of(mount: WeaponMount) -> float:
    if mount == null or mount.weapon_data == null:
        return 0.0
    return mount.weapon_data.spread_degrees


func _check_over_enemy() -> bool:
    if _mech == null or _mech.aim_controller == null:
        return false
    var aim_point: Vector3 = _mech.aim_controller.get_aim_point()
    if _swarm != null and _swarm.query_radius(aim_point, HOVER_RADIUS, _hover_ids) > 0:
        return true
    return _actor_under_aim(aim_point)


## Bắn một tia ngắn thẳng đứng xuống điểm ngắm: actor đứng trên sàn nên
## Hurtbox của nó luôn cắt đoạn này, mà không cần biết camera ở đâu.
func _actor_under_aim(aim_point: Vector3) -> bool:
    var world: World3D = get_viewport().world_3d
    if world == null:
        return false
    var space: PhysicsDirectSpaceState3D = world.direct_space_state
    if space == null:
        return false
    _hover_query.from = aim_point + Vector3(0.0, 4.0, 0.0)
    _hover_query.to = aim_point - Vector3(0.0, 1.0, 0.0)
    return not space.intersect_ray(_hover_query).is_empty()


func _connect_mounts() -> void:
    if _mech == null:
        return
    for mount: WeaponMount in [_mech.weapon_mount_left, _mech.weapon_mount_right]:
        if mount != null and not mount.hit_landed.is_connected(_on_mount_hit):
            mount.hit_landed.connect(_on_mount_hit)


func _disconnect_mounts() -> void:
    if _mech == null:
        return
    for mount: WeaponMount in [_mech.weapon_mount_left, _mech.weapon_mount_right]:
        if mount != null and mount.hit_landed.is_connected(_on_mount_hit):
            mount.hit_landed.disconnect(_on_mount_hit)


func _on_mount_hit(count: int, is_critical: bool) -> void:
    if count > 0:
        show_hit_marker(is_critical)


## Chỉ báo cho đòn do CHÍNH người chơi gây ra; đạn của kẻ địch không được
## làm nháy con trỏ.
func _on_damage_dealt(_target_id: int, info: DamageInfo) -> void:
    if _mech == null or info == null or info.source_id != _mech.get_instance_id():
        return
    show_hit_marker(info.is_critical)
