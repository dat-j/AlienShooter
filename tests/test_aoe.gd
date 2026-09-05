extends GutTest

## T-507 — Sát thương vùng: suy giảm theo khoảng cách, tự sát thương, và
## không đánh xuyên tường. Phần chặn tầm nhìn cần world vật lý thật nên chỉ
## kiểm ở sân tập; ở đây `space` để trống, và `Aoe` ghi rõ khi đó coi như
## mọi mục tiêu đều nhìn thấy tâm nổ.

const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")

var _swarm: SwarmManager
var _aoe: Aoe


func before_each() -> void:
    _swarm = SwarmManager.new()
    add_child_autofree(_swarm)
    _aoe = Aoe.new()


func _detonate(radius: float, damage: float) -> int:
    return _aoe.detonate(
        null, Vector3.ZERO, radius, damage, DamageTypes.Type.EXPLOSIVE, null, _swarm
    )


# --- Suy giảm theo khoảng cách ------------------------------------------

func test_falloff_day_du_o_tam_va_yeu_nhat_o_mep() -> void:
    assert_eq(Aoe.falloff_at(0.0, 4.0), 1.0, "tâm nổ ăn trọn")
    assert_almost_eq(Aoe.falloff_at(4.0, 4.0), Aoe.FALLOFF_AT_EDGE, 0.001, "mép yếu nhất")
    assert_almost_eq(Aoe.falloff_at(8.0, 4.0), Aoe.FALLOFF_AT_EDGE, 0.001, "ngoài mép vẫn kẹp ở đáy")


func test_falloff_giam_dan_deu() -> void:
    var half: float = Aoe.falloff_at(2.0, 4.0)
    assert_almost_eq(half, 0.65, 0.001, "nửa bán kính nằm chính giữa 1.0 và 0.3")
    assert_lt(half, Aoe.falloff_at(1.0, 4.0), "càng xa càng yếu")


func test_falloff_ban_kinh_0_khong_chia_cho_0() -> void:
    assert_eq(Aoe.falloff_at(5.0, 0.0), 1.0, "bán kính 0 không được sinh NaN")


func test_no_gay_it_sat_thuong_hon_cho_muc_tieu_o_xa() -> void:
    _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 1000.0, 0)             # ngay tâm
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)   # sát mép

    assert_eq(_detonate(3.0, 100.0), 2, "cả hai đều trong bán kính")
    var at_centre: float = 1000.0 - _swarm._healths[0]
    var at_edge: float = 1000.0 - _swarm._healths[1]
    assert_almost_eq(at_centre, 100.0, 0.01, "tâm ăn đủ 100")
    assert_almost_eq(at_edge, 30.0, 0.01, "mép chỉ còn 30%")
    assert_lt(at_edge, at_centre, "xa hơn thì đau ít hơn")


func test_ngoai_ban_kinh_thi_khong_dinh() -> void:
    _swarm.spawn(Vector3(9.0, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)

    assert_eq(_detonate(3.0, 100.0), 0, "ngoài bán kính là an toàn")
    assert_eq(_swarm._healths[0], 1000.0)


func test_no_giet_ca_cum_swarm_khong_bo_sot() -> void:
    for x: float in [0.0, 0.4, 0.8, 1.2]:
        _swarm.spawn(Vector3(x, 0.0, 0.0), Vector3.ZERO, 20.0, 0)

    assert_eq(_detonate(3.0, 100.0), 4, "cả cụm đều dính")
    assert_eq(_swarm.get_alive_count(), 0, "swap-kill không được bỏ sót con nào")


func test_ban_kinh_hoac_sat_thuong_khong_hop_le_thi_khong_lam_gi() -> void:
    _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 100.0, 0)

    assert_eq(_detonate(0.0, 50.0), 0, "bán kính 0 thì không nổ")
    assert_eq(_detonate(5.0, 0.0), 0, "0 sát thương thì không nổ")
    assert_eq(_swarm._healths[0], 100.0)


# --- Tự sát thương (GDD §6.1, nhóm Explosive) ---------------------------

func test_nguoi_choi_dung_qua_gan_thi_tu_dinh_don() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    mech.global_position = Vector3(1.0, 0.0, 0.0)
    var before: float = mech.core_hp

    _aoe.detonate(
        null, Vector3.ZERO, 3.0, 100.0, DamageTypes.Type.EXPLOSIVE,
        null, _swarm, 1.5, mech
    )

    assert_lt(mech.core_hp, before, "nổ ngay dưới chân thì người bắn cũng ăn")


func test_nguoi_choi_ngoai_ban_kinh_tu_sat_thuong_thi_an_toan() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    mech.global_position = Vector3(2.5, 0.0, 0.0)
    var before: float = mech.core_hp

    # Vẫn nằm trong bán kính nổ 3.0 nhưng ngoài bán kính tự sát thương 1.5.
    _aoe.detonate(
        null, Vector3.ZERO, 3.0, 100.0, DamageTypes.Type.EXPLOSIVE,
        null, _swarm, 1.5, mech
    )

    assert_eq(mech.core_hp, before, "ngoài 1.5m thì không tự dính")


func test_khong_khai_bao_tu_sat_thuong_thi_nguoi_ban_mien_nhiem() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    mech.global_position = Vector3(0.2, 0.0, 0.0)
    var before: float = mech.core_hp

    _aoe.detonate(
        null, Vector3.ZERO, 3.0, 100.0, DamageTypes.Type.EXPLOSIVE,
        null, _swarm, 0.0, mech
    )

    assert_eq(mech.core_hp, before, "vũ khí không có self_damage_radius thì không tự thương")
