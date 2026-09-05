extends GutTest

## T-509 — đạn và tiếp đạn. T-510 — năm cấp nâng cấp vũ khí (GDD §6.4).

const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/pickups/ammo_crate.tscn")

var _mech: MechController


func before_each() -> void:
    _mech = add_child_autofree(MECH_SCENE.instantiate()) as MechController


func after_each() -> void:
    PoolManager.clear_pool(CRATE_SCENE)


func _weapon(id: String) -> WeaponData:
    return load("res://data/weapons/%s.tres" % id) as WeaponData


# --- T-509: đạn ---------------------------------------------------------

func test_dan_toi_da_lay_tu_weapon_data() -> void:
    var mount: WeaponMount = _mech.weapon_mount_left
    mount.equip(_weapon("wpn_vulcan_x"))         # 900 đạn
    assert_eq(mount.get_ammo(), 900, "trang bị xong là đầy đạn theo WeaponData")
    assert_eq(mount.get_max_ammo(), 900)
    assert_true(mount.uses_ammo())


func test_vu_khi_energy_bo_qua_hoan_toan_he_thong_dan() -> void:
    var mount: WeaponMount = _mech.weapon_mount_left
    mount.equip(_weapon("wpn_rail_lance"))
    assert_false(mount.uses_ammo(), "Rail Lance là Energy, không có đạn")
    assert_eq(mount.get_max_ammo(), 0)
    assert_false(mount.is_out_of_ammo(), "không có đạn thì không bao giờ 'hết đạn'")
    assert_eq(mount.refill(0.25), 0, "hộp đạn không cộng gì cho vũ khí Energy")


func test_refill_cong_dung_ti_le_dan_toi_da() -> void:
    var mount: WeaponMount = _mech.weapon_mount_left
    mount.equip(_weapon("wpn_mk2_autocannon"))   # 360 đạn
    mount.add_ammo(-360)
    assert_eq(mount.get_ammo(), 0)

    assert_eq(mount.refill(0.25), 90, "25% của 360 là 90 viên")
    assert_eq(mount.get_ammo(), 90)


func test_refill_khong_vuot_qua_dan_toi_da() -> void:
    var mount: WeaponMount = _mech.weapon_mount_left
    mount.equip(_weapon("wpn_mk2_autocannon"))
    assert_eq(mount.refill(0.25), 0, "đang đầy thì không nạp thêm được viên nào")
    assert_eq(mount.get_ammo(), 360)


func test_hop_dan_bu_cho_ca_hai_vu_khi() -> void:
    var left: WeaponMount = _mech.weapon_mount_left
    var right: WeaponMount = _mech.weapon_mount_right
    left.equip(_weapon("wpn_mk2_autocannon"))    # 360
    right.equip(_weapon("wpn_twin_repeater"))    # 500
    left.add_ammo(-360)
    right.add_ammo(-500)

    # GDD §11.2: hộp đạn = +25% đạn tối đa cho CẢ HAI vũ khí.
    var added: int = _mech.refill_ammo(AmmoCrate.REFILL_FRACTION)

    assert_eq(added, 90 + 125, "tổng đạn nạp của cả hai tay")
    assert_eq(left.get_ammo(), 90)
    assert_eq(right.get_ammo(), 125)


func test_hop_dan_nhat_len_thi_tra_ve_pool_va_bao_event() -> void:
    var crate := PoolManager.acquire(CRATE_SCENE) as AmmoCrate
    add_child_autofree(crate)
    crate.drop_at(Vector3.ZERO)
    _mech.weapon_mount_left.add_ammo(-360)
    watch_signals(EventBus)

    var added: int = crate.collect(_mech)

    assert_gt(added, 0, "nhặt hộp phải cộng đạn")
    assert_false(crate.is_active(), "hộp đã nhặt thì tắt")
    assert_signal_emitted(EventBus, "loot_picked_up")


func test_hop_dan_da_nhat_khong_nhat_lai_duoc() -> void:
    var crate := PoolManager.acquire(CRATE_SCENE) as AmmoCrate
    add_child_autofree(crate)
    crate.drop_at(Vector3.ZERO)
    _mech.weapon_mount_left.add_ammo(-360)
    crate.collect(_mech)

    assert_eq(crate.collect(_mech), 0, "hộp rỗng không cộng thêm lần hai")


# --- T-510: nâng cấp (GDD §6.4) -----------------------------------------

func test_cap_1_khong_doi_gi() -> void:
    assert_eq(WeaponUpgrades.damage_multiplier(1), 1.0)
    assert_eq(WeaponUpgrades.heat_multiplier(1), 1.0)
    assert_eq(WeaponUpgrades.ammo_multiplier(1), 1.0)
    assert_false(WeaponUpgrades.has_overdrive(1))


func test_cap_2_cong_12_phan_tram_sat_thuong() -> void:
    assert_almost_eq(WeaponUpgrades.damage_multiplier(2), 1.12, 0.0001)
    assert_eq(WeaponUpgrades.heat_multiplier(2), 1.0, "cấp 2 chưa đụng tới nhiệt")


func test_cap_3_giam_10_phan_tram_nhiet_va_giu_sat_thuong_cap_2() -> void:
    assert_almost_eq(WeaponUpgrades.damage_multiplier(3), 1.12, 0.0001)
    assert_almost_eq(WeaponUpgrades.heat_multiplier(3), 0.9, 0.0001)


func test_cap_4_cong_don_ca_hai_muc_sat_thuong() -> void:
    # "Cộng dồn" = nhân dồn: 1.12 × 1.15.
    assert_almost_eq(WeaponUpgrades.damage_multiplier(4), 1.288, 0.0001)
    assert_almost_eq(WeaponUpgrades.ammo_multiplier(4), 1.2, 0.0001)
    assert_almost_eq(WeaponUpgrades.heat_multiplier(4), 0.9, 0.0001, "vẫn giữ ưu đãi nhiệt cấp 3")


func test_cap_5_mo_overdrive_va_giu_toan_bo_cap_truoc() -> void:
    assert_true(WeaponUpgrades.has_overdrive(5))
    assert_almost_eq(WeaponUpgrades.damage_multiplier(5), 1.288, 0.0001)
    assert_almost_eq(WeaponUpgrades.heat_multiplier(5), 0.9, 0.0001)
    assert_almost_eq(WeaponUpgrades.ammo_multiplier(5), 1.2, 0.0001)


func test_cap_ngoai_khoang_bi_kep_lai() -> void:
    assert_eq(WeaponUpgrades.damage_multiplier(0), WeaponUpgrades.damage_multiplier(1))
    assert_eq(WeaponUpgrades.damage_multiplier(99), WeaponUpgrades.damage_multiplier(5))


func test_ban_nang_cap_khong_sua_resource_goc() -> void:
    var base: WeaponData = _weapon("wpn_mk2_autocannon")
    var damage_before: float = base.damage
    var heat_before: float = base.heat_per_shot
    var ammo_before: int = base.max_ammo

    var upgraded: WeaponData = WeaponUpgrades.build_upgraded(base, 4)

    assert_eq(base.damage, damage_before, "resource gốc của ContentDB phải bất biến")
    assert_eq(base.heat_per_shot, heat_before)
    assert_eq(base.max_ammo, ammo_before)
    assert_almost_eq(upgraded.damage, 8.0 * 1.288, 0.0001)
    assert_almost_eq(upgraded.heat_per_shot, 2.2 * 0.9, 0.0001)
    assert_eq(upgraded.max_ammo, 432, "360 + 20%")


func test_vu_khi_energy_khong_bi_cong_dan_khi_nang_cap() -> void:
    var upgraded: WeaponData = WeaponUpgrades.build_upgraded(_weapon("wpn_rail_lance"), 5)
    assert_eq(upgraded.max_ammo, 0, "Energy không có đạn để mà cộng thêm 20%")


func test_cryo_nang_cap_van_lam_mat_chu_khong_dao_dau() -> void:
    var upgraded: WeaponData = WeaponUpgrades.build_upgraded(_weapon("wpn_cryo_projector"), 3)
    assert_lt(upgraded.heat_per_shot, 0.0, "giảm 10% sinh nhiệt không được biến Cryo thành lò nung")
    assert_almost_eq(upgraded.heat_per_shot, -5.4, 0.0001)


func test_chi_phi_nang_cap_khop_bang_gdd() -> void:
    var data: WeaponData = _weapon("wpn_mk2_autocannon")
    assert_eq(WeaponUpgrades.cost_to_next(data, 1), Vector2i(400, 8))
    assert_eq(WeaponUpgrades.cost_to_next(data, 2), Vector2i(900, 20))
    assert_eq(WeaponUpgrades.cost_to_next(data, 3), Vector2i(1800, 45))
    assert_eq(WeaponUpgrades.cost_to_next(data, 4), Vector2i(3500, 90))
    assert_eq(WeaponUpgrades.cost_to_next(data, 5), Vector2i.ZERO, "kịch cấp thì hết chi phí")
    assert_eq(WeaponUpgrades.total_cost(data, 5), Vector2i(6600, 163))


# --- T-510: dispatch Overdrive ------------------------------------------

class OverdriveSpy:
    extends RefCounted

    var called_with: WeaponData = null


    func _overdrive_test_effect(data: WeaponData) -> void:
        called_with = data


func test_overdrive_goi_dung_ham_rieng_cua_vu_khi() -> void:
    var data := WeaponData.new()
    data.id = &"wpn_spy"
    data.overdrive_effect = &"test_effect"
    var spy := OverdriveSpy.new()

    assert_true(WeaponUpgrades.trigger_overdrive(data, 5, spy), "cấp 5 phải gọi được")
    assert_eq(spy.called_with, data, "handler nhận đúng WeaponData đã gọi nó")


func test_overdrive_khong_chay_truoc_cap_5() -> void:
    var data := WeaponData.new()
    data.overdrive_effect = &"test_effect"
    var spy := OverdriveSpy.new()

    assert_false(WeaponUpgrades.trigger_overdrive(data, 4, spy), "cấp 4 chưa mở Overdrive")
    assert_null(spy.called_with)


func test_overdrive_khong_khai_bao_thi_khong_goi_gi() -> void:
    var data := WeaponData.new()
    data.overdrive_effect = &""
    assert_false(WeaponUpgrades.trigger_overdrive(data, 5, OverdriveSpy.new()))


func test_ten_ham_overdrive_suy_ra_tu_id_hieu_ung() -> void:
    assert_eq(WeaponUpgrades.overdrive_method_name(&"burst_fire"), &"_overdrive_burst_fire")
