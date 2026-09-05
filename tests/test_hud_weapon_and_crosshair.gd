extends GutTest

## T-511 — ô vũ khí trên HUD. T-512 — con trỏ ngắm tuỳ chỉnh.
## TDD §14 không bắt buộc test cho bố cục UI, nên ở đây chỉ kiểm **hành vi**:
## chuỗi hiển thị, màu, bán kính, hit marker.

const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")
const DISPLAY_SCENE: PackedScene = preload("res://scenes/ui/hud/weapon_display.tscn")
const CROSSHAIR_SCENE: PackedScene = preload("res://scenes/ui/hud/crosshair.tscn")
const ARENA_SCENE: PackedScene = preload("res://scenes/main/test_arena.tscn")

var _mech: MechController


func before_each() -> void:
    _mech = add_child_autofree(MECH_SCENE.instantiate()) as MechController


func _weapon(id: String) -> WeaponData:
    return load("res://data/weapons/%s.tres" % id) as WeaponData


func _make_crosshair() -> Crosshair:
    var crosshair := CROSSHAIR_SCENE.instantiate() as Crosshair
    # Không cướp con trỏ chuột của máy chạy test.
    crosshair.hide_os_cursor = false
    add_child_autofree(crosshair)
    crosshair.bind(_mech, null)
    return crosshair


# --- T-511: ô vũ khí ----------------------------------------------------

func test_vu_khi_co_dan_hien_so_hien_tai_tren_toi_da() -> void:
    assert_eq(WeaponDisplay.ammo_text(true, 248, 360), "248 / 360")


func test_vu_khi_energy_hien_khoa_nang_luong_thay_cho_so() -> void:
    var text: String = WeaponDisplay.ammo_text(false, 0, 0)
    assert_eq(text, WeaponDisplay.translate(WeaponDisplay.KEY_ENERGY), "Energy hiện NĂNG LƯỢNG chứ không hiện 0 / 0")
    assert_ne(text, "0 / 0")


func test_het_dan_hien_khoa_rieng_chu_khong_hien_so_khong() -> void:
    assert_eq(WeaponDisplay.ammo_text(true, 0, 360), WeaponDisplay.translate(WeaponDisplay.KEY_EMPTY))


func test_ten_vu_khi_dung_khoa_dich_va_co_dau_chi_tay() -> void:
    var data: WeaponData = _weapon("wpn_mk2_autocannon")
    var text: String = WeaponDisplay.name_text(data, WeaponDisplay.MARKER_LEFT)
    assert_string_starts_with(text, WeaponDisplay.MARKER_LEFT, "dòng trái có dấu ◀")
    assert_string_contains(text, WeaponDisplay.translate(data.display_name_key), "tên đi qua khoá dịch")


func test_o_vu_khi_trong_khi_chua_lap_gi() -> void:
    assert_string_contains(WeaponDisplay.name_text(null, WeaponDisplay.MARKER_RIGHT), "—")


func test_con_dan_thi_khong_nhay_do() -> void:
    var color: Color = WeaponDisplay.ammo_color(false, 0.0)
    assert_eq(color, WeaponDisplay.COLOR_NORMAL, "còn đạn thì HUD im lặng")


func test_het_dan_thi_nhay_do_theo_thoi_gian() -> void:
    var mid: Color = WeaponDisplay.ammo_color(true, 0.0)
    # Đỉnh chu kỳ nháy nằm ở 1/4 chu kỳ, nơi sin() đạt 1.
    var peak: Color = WeaponDisplay.ammo_color(true, 0.25 / WeaponDisplay.FLASH_HZ)
    assert_ne(mid, peak, "màu phải đổi theo thời gian thì mới gọi là nháy")
    assert_eq(peak, WeaponDisplay.COLOR_EMPTY, "đỉnh chu kỳ là đỏ nguy hiểm")
    assert_gt(peak.r, mid.r, "đỉnh chu kỳ ngả về đỏ")


func test_o_vu_khi_doc_duoc_trang_thai_that_cua_mount() -> void:
    var display := DISPLAY_SCENE.instantiate() as WeaponDisplay
    add_child_autofree(display)
    _mech.weapon_mount_left.equip(_weapon("wpn_rail_lance"))
    _mech.weapon_mount_right.equip(_weapon("wpn_mk2_autocannon"))
    display.bind(_mech)

    var left: Label = display.get_node("Panel/Rows/Left/Ammo")
    var right: Label = display.get_node("Panel/Rows/Right/Ammo")
    assert_eq(left.text, WeaponDisplay.translate(WeaponDisplay.KEY_ENERGY), "Rail Lance là Energy")
    assert_eq(right.text, "360 / 360", "MK2 Autocannon đầy đạn")


# --- T-512: con trỏ ngắm ------------------------------------------------

func test_vong_ngoai_co_gian_theo_do_tan_dan() -> void:
    var tight: float = Crosshair.ring_radius(0.0)
    var loose: float = Crosshair.ring_radius(14.0)     # Scattergun
    assert_eq(tight, Crosshair.BASE_RADIUS, "không tản đạn thì bằng bán kính gốc")
    assert_gt(loose, tight, "tản đạn rộng thì vòng ngoài phải nở ra")


func test_vong_ngoai_co_tran_tren_va_khong_am() -> void:
    assert_eq(Crosshair.ring_radius(9999.0), Crosshair.MAX_RADIUS, "không được nở kín màn hình")
    assert_eq(Crosshair.ring_radius(-5.0), Crosshair.BASE_RADIUS, "tản đạn âm là vô nghĩa")


func test_hit_marker_phan_biet_thuong_va_chi_mang() -> void:
    assert_ne(
        Crosshair.marker_color(true), Crosshair.marker_color(false),
        "chí mạng phải khác màu để đọc được mà không cần nhìn số"
    )
    assert_eq(Crosshair.marker_color(true), Crosshair.COLOR_CRIT)


func test_hit_marker_bat_len_roi_tat_sau_thoi_gian_song() -> void:
    var crosshair := _make_crosshair()
    assert_false(crosshair.is_hit_marker_visible(), "chưa bắn trúng thì chưa có marker")

    crosshair.show_hit_marker(false)
    assert_true(crosshair.is_hit_marker_visible())

    crosshair._process(Crosshair.HIT_MARKER_SECONDS + 0.01)
    assert_false(crosshair.is_hit_marker_visible(), "marker phải tự tắt")


func test_chi_mang_thang_trong_cung_mot_loat_dan() -> void:
    var crosshair := _make_crosshair()
    crosshair.show_hit_marker(true)
    crosshair.show_hit_marker(false)
    assert_true(crosshair.is_hit_marker_critical(), "đòn thường ngay sau không được xoá dấu chí mạng")


func test_loat_dan_sau_bat_dau_lai_tu_don_thuong() -> void:
    var crosshair := _make_crosshair()
    crosshair.show_hit_marker(true)
    crosshair._process(Crosshair.HIT_MARKER_SECONDS + 0.01)
    crosshair.show_hit_marker(false)
    assert_false(crosshair.is_hit_marker_critical(), "marker đã tắt thì không giữ dấu chí mạng cũ")


func test_don_trung_cua_vu_khi_ban_tuc_thoi_bat_hit_marker() -> void:
    var crosshair := _make_crosshair()
    _mech.weapon_mount_left.hit_landed.emit(3, false)
    assert_true(crosshair.is_hit_marker_visible(), "hit_landed của mount phải nháy marker")


func test_don_cua_ke_dich_khong_bat_hit_marker_cua_nguoi_choi() -> void:
    var crosshair := _make_crosshair()
    var info: DamageInfo = PoolManager.get_damage_info()
    info.amount = 10.0
    info.source_id = -999                       # không phải mech người chơi
    EventBus.damage_dealt.emit(1, info)
    PoolManager.release_damage_info(info)

    assert_false(crosshair.is_hit_marker_visible(), "bị đánh không phải là đánh trúng")


func test_don_cua_nguoi_choi_len_actor_bat_hit_marker() -> void:
    var crosshair := _make_crosshair()
    var info: DamageInfo = PoolManager.get_damage_info()
    info.amount = 10.0
    info.is_critical = true
    info.source_id = _mech.get_instance_id()
    EventBus.damage_dealt.emit(1, info)
    PoolManager.release_damage_info(info)

    assert_true(crosshair.is_hit_marker_visible())
    assert_true(crosshair.is_hit_marker_critical(), "chí mạng lên actor hiện marker chí mạng")


func test_mau_vong_ngoai_doi_khi_re_qua_ke_dich() -> void:
    assert_ne(Crosshair.ring_color(true), Crosshair.ring_color(false))
    assert_eq(Crosshair.ring_color(true), Crosshair.COLOR_OVER_ENEMY)


func test_re_qua_swarm_thi_bao_co_ke_dich() -> void:
    var swarm := SwarmManager.new()
    add_child_autofree(swarm)
    var crosshair := _make_crosshair()
    crosshair.bind(_mech, swarm)
    var aim_point: Vector3 = _mech.aim_controller.get_aim_point()

    crosshair._process(0.016)
    assert_false(crosshair.is_over_enemy(), "sân trống thì con trỏ trung tính")

    swarm.spawn(aim_point, Vector3.ZERO, 10.0, 0)
    crosshair._process(0.016)
    assert_true(crosshair.is_over_enemy(), "có con swarm ngay dưới con trỏ thì phải báo")


func test_vong_cung_sac_day_khi_vu_khi_san_sang() -> void:
    _mech.weapon_mount_left.equip(_weapon("wpn_mk2_autocannon"))
    assert_eq(Crosshair.build_up_ratio(_mech.weapon_mount_left), 1.0, "vũ khí không sạc thì luôn sẵn sàng")


func test_vong_cung_chay_theo_tien_do_sac() -> void:
    var mount: WeaponMount = _mech.weapon_mount_left
    mount.equip(_weapon("wpn_rail_lance"))       # sạc 0.5s
    mount.update(0.25, true, null, _mech.global_position + Vector3(0.0, 0.0, -10.0))
    assert_almost_eq(Crosshair.build_up_ratio(mount), 0.5, 0.05, "sạc nửa đường thì cung đi nửa vòng")


func test_vong_cung_theo_quay_nong() -> void:
    var mount: WeaponMount = _mech.weapon_mount_left
    mount.equip(_weapon("wpn_vulcan_x"))         # quay nòng 0.7s
    mount.update(0.35, true, null, _mech.global_position + Vector3(0.0, 0.0, -10.0))
    assert_almost_eq(Crosshair.build_up_ratio(mount), 0.5, 0.05, "quay nòng nửa đường")


func test_khong_co_mount_thi_khong_no() -> void:
    assert_eq(Crosshair.build_up_ratio(null), 1.0, "thiếu vũ khí thì con trỏ vẫn vẽ được")


# --- HUD phải thực sự có mặt trong sân tập ------------------------------

func test_san_tap_co_san_o_vu_khi_va_con_tro_da_noi_dung_mech() -> void:
    var arena := add_child_autofree(ARENA_SCENE.instantiate()) as Node3D
    var mech := arena.get_node("Mech") as MechController
    var display := arena.get_node_or_null("HudLayer/WeaponDisplay") as WeaponDisplay
    var crosshair := arena.get_node_or_null("HudLayer/Crosshair") as Crosshair

    assert_not_null(display, "sân tập phải có ô vũ khí")
    assert_not_null(crosshair, "sân tập phải có con trỏ ngắm")

    var ammo: Label = display.get_node("Panel/Rows/Left/Ammo")
    assert_eq(ammo.text, "360 / 360", "ô vũ khí đọc đúng mount trái của mech trong sân")

    mech.weapon_mount_left.hit_landed.emit(1, false)
    assert_true(crosshair.is_hit_marker_visible(), "con trỏ đã nối vào mount của mech trong sân")
