extends GutTest

## T-607 — damage number. T-608 — VFX nhiệt và giáp.

const NUMBER_SCENE: PackedScene = preload("res://scenes/ui/damage_number.tscn")
const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")

var _root: Node3D


func before_each() -> void:
    SettingsManager.reset_all(false)
    _root = Node3D.new()
    add_child_autofree(_root)


func after_each() -> void:
    PoolManager.clear_pool(NUMBER_SCENE)
    SettingsManager.reset_all(false)


func _make_pool() -> DamageNumberPool:
    var pool := DamageNumberPool.new()
    pool.number_scene = NUMBER_SCENE
    _root.add_child(pool)
    return pool


# --- T-607: damage number -----------------------------------------------

func test_so_sat_thuong_troi_len_va_mo_dan_roi_tat() -> void:
    var pool := _make_pool()
    var number: DamageNumber = pool.show_damage(Vector3.ZERO, 42.0, false)

    assert_not_null(number)
    assert_eq(number.text, "42")
    assert_true(number.is_active())

    number._process(DamageNumber.LIFETIME + 0.01)
    assert_false(number.is_active(), "UX-UI §2.4: sống 0.7 giây")


func test_so_troi_len_cham_dan_chu_khong_bay_vut() -> void:
    assert_eq(DamageNumber.rise_at(0.0), 0.0)
    assert_almost_eq(DamageNumber.rise_at(1.0), DamageNumber.RISE_METRES, 0.0001)
    assert_gt(
        DamageNumber.rise_at(0.5), DamageNumber.RISE_METRES * 0.5,
        "nửa thời gian phải đi được hơn nửa quãng đường thì mới là chậm dần"
    )


func test_so_giu_ro_nua_dau_roi_moi_tan() -> void:
    assert_eq(DamageNumber.alpha_at(0.0), 1.0)
    assert_eq(DamageNumber.alpha_at(0.5), 1.0, "phải đọc được trước khi biến mất")
    assert_eq(DamageNumber.alpha_at(1.0), 0.0)


func test_chi_mang_to_hon_va_doi_mau() -> void:
    var pool := _make_pool()
    var normal: DamageNumber = pool.show_damage(Vector3.ZERO, 10.0, false)
    var critical: DamageNumber = pool.show_damage(Vector3.ZERO, 10.0, true)

    assert_gt(critical.font_size, normal.font_size, "chí mạng to hơn 1.4×")
    assert_eq(critical.modulate, DamageNumber.COLOR_CRITICAL, "và vàng")
    assert_ne(critical.modulate, normal.modulate)


func test_lam_tron_ve_so_nguyen_va_khong_bao_gio_hien_so_khong() -> void:
    assert_eq(DamageNumber.format_amount(12.4), "12")
    assert_eq(DamageNumber.format_amount(12.6), "13")
    assert_eq(DamageNumber.format_amount(0.6), "1", "trúng nhẹ vẫn phải hiện là có trúng")


func test_khong_vuot_tran_40() -> void:
    var pool := _make_pool()
    for _i: int in range(DamageNumberPool.MAX_NUMBERS + 20):
        pool.show_damage(Vector3.ZERO, 10.0, false)
    assert_eq(pool.get_active_count(), DamageNumberPool.MAX_NUMBERS, "TDD §12.7: trần 40")


func test_tat_duoc_trong_thiet_lap() -> void:
    var pool := _make_pool()
    SettingsManager.set_value(&"accessibility", &"damage_numbers", false)

    assert_false(pool.is_enabled())
    assert_null(pool.show_damage(Vector3.ZERO, 50.0, false), "tắt là không hiện gì")
    assert_eq(pool.get_active_count(), 0)


func test_sat_thuong_qua_nho_thi_khong_lam_ban_man_hinh() -> void:
    var pool := _make_pool()
    assert_null(pool.show_damage(Vector3.ZERO, 0.1, false))


func test_sat_thuong_swarm_duoc_gop_thanh_mot_con_so() -> void:
    var swarm := SwarmManager.new()
    _root.add_child(swarm)
    var pool := _make_pool()
    pool.bind(swarm)

    for index: int in range(25):
        swarm.spawn(Vector3(float(index), 0.0, 0.0), Vector3.ZERO, 1000.0, 0)
    swarm.damage_at_point(Vector3(12.0, 0.0, 0.0), 100.0, 4.0)
    swarm.flush_damage_report()

    assert_eq(pool.get_active_count(), 1, "25 con trúng đòn chỉ được hiện MỘT con số")
    var number: DamageNumber = pool.get_children()[0] as DamageNumber
    assert_eq(number.text, "100", "và con số đó là TỔNG: 25 con × 4 sát thương")


func test_khong_co_gi_trung_thi_khong_hien_so() -> void:
    var swarm := SwarmManager.new()
    _root.add_child(swarm)
    var pool := _make_pool()
    pool.bind(swarm)

    swarm.flush_damage_report()
    assert_eq(pool.get_active_count(), 0, "frame không ai trúng thì im lặng")


func test_sat_thuong_len_actor_hien_tung_don() -> void:
    var pool := _make_pool()
    var info: DamageInfo = PoolManager.get_damage_info()
    info.amount = 33.0
    info.source_position = Vector3(1.0, 0.0, 2.0)
    EventBus.damage_dealt.emit(1, info)
    PoolManager.release_damage_info(info)

    assert_eq(pool.get_active_count(), 1, "actor ít nên không cần gộp")


# --- T-608: VFX nhiệt và giáp -------------------------------------------

func test_nhiet_thap_thi_than_mech_khong_ung_do() -> void:
    assert_eq(MechVfx.glow_for_ratio(0.0, false), 0.0)
    assert_eq(MechVfx.glow_for_ratio(MechVfx.GLOW_START_RATIO, false), 0.0,
        "dải nhiệt thấp phải sạch thì dải nhiệt cao mới đáng sợ")


func test_nhiet_cao_thi_anh_do_manh_dan() -> void:
    var mid: float = MechVfx.glow_for_ratio(0.7, false)
    var high: float = MechVfx.glow_for_ratio(0.95, false)
    assert_gt(mid, 0.0)
    assert_gt(high, mid, "càng nóng càng đỏ")
    assert_almost_eq(MechVfx.glow_for_ratio(1.0, false), 1.0, 0.0001)


func test_qua_nhiet_luon_do_het_co() -> void:
    assert_eq(MechVfx.glow_for_ratio(0.0, true), 1.0,
        "quá nhiệt là trạng thái phải hét lên, bất kể nhiệt còn lại bao nhiêu")


func test_mech_co_san_node_vfx_va_shader_nhiet() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    var vfx := mech.get_node_or_null("MechVfx") as MechVfx
    assert_not_null(vfx, "mech phải có sẵn MechVfx")

    var torso := mech.get_node("TorsoPivot/TorsoModel") as MeshInstance3D
    var material := torso.get_active_material(0) as ShaderMaterial
    assert_not_null(material, "thân mech phải dùng ShaderMaterial thì mới đẩy được heat_glow")
    assert_true(
        material.get_shader_parameter(MechVfx.HEAT_GLOW_PARAM) != null,
        "shader phải có tham số heat_glow"
    )


func test_day_duoc_anh_do_vao_shader() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    var vfx := mech.get_node("MechVfx") as MechVfx
    var torso := mech.get_node("TorsoPivot/TorsoModel") as MeshInstance3D
    var material := torso.get_active_material(0) as ShaderMaterial

    vfx.apply_glow(0.75)
    assert_almost_eq(
        float(material.get_shader_parameter(MechVfx.HEAT_GLOW_PARAM)), 0.75, 0.0001,
        "T-608 yêu cầu ánh đỏ đi qua THAM SỐ SHADER"
    )
    vfx.apply_glow(0.0)


func test_xa_nhiet_phun_hoi_va_vo_giap_van_manh() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    var vfx := mech.get_node("MechVfx") as MechVfx

    assert_not_null(vfx.play_vent_steam(), "xả nhiệt phải phụt hơi — đây là tín hiệu gameplay")
    assert_not_null(vfx.play_plate_break(), "vỡ giáp phải văng mảnh")
