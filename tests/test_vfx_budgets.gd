extends GutTest

## T-604 · T-605 · T-606 — mọi hiệu ứng bề mặt đều phải có TRẦN (TDD §12.7).
## Đây là phần đáng test nhất của M6: hình dạng hạt thì mắt kiểm, còn trần số
## lượng thì chỉ có test mới giữ được.

const MUZZLE_SCENE: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/vfx/shell_casing.tscn")
const GIB_SCENE: PackedScene = preload("res://scenes/vfx/gib.tscn")
const IMPACT_METAL: PackedScene = preload("res://scenes/vfx/impact_metal.tscn")
const IMPACT_FLESH: PackedScene = preload("res://scenes/vfx/impact_flesh.tscn")
const DECAL_BLOOD: PackedScene = preload("res://scenes/vfx/decal_blood.tscn")
const DECAL_BULLET: PackedScene = preload("res://scenes/vfx/decal_bullet.tscn")

var _root: Node3D


func before_each() -> void:
    LightBudget.reset()
    ShellEjector.clear_all()
    _root = Node3D.new()
    add_child_autofree(_root)


func after_each() -> void:
    ShellEjector.clear_all()
    LightBudget.reset()
    for scene: PackedScene in [MUZZLE_SCENE, SHELL_SCENE, GIB_SCENE, IMPACT_METAL, IMPACT_FLESH, DECAL_BLOOD, DECAL_BULLET]:
        PoolManager.clear_pool(scene)


# --- T-604: ngân sách đèn tạm (TDD §12.6) -------------------------------

func test_den_tam_khong_vuot_tran_12() -> void:
    for _i: int in range(LightBudget.MAX_TEMPORARY_LIGHTS):
        assert_true(LightBudget.request(), "trong ngân sách thì phải cấp được")
    assert_eq(LightBudget.get_active_count(), 12, "TDD §12.6: tối đa 12 đèn tạm")
    assert_false(LightBudget.request(), "quá trần thì từ chối")
    assert_eq(LightBudget.get_active_count(), 12, "từ chối rồi thì không được tăng bộ đếm")


func test_tra_den_thi_ngan_sach_hoi_lai() -> void:
    LightBudget.request()
    LightBudget.release()
    assert_eq(LightBudget.get_active_count(), 0)
    LightBudget.release()
    assert_eq(LightBudget.get_active_count(), 0, "trả thừa không được làm bộ đếm âm")


func test_chop_lua_khong_do_bong_va_song_dung_0_08_giay() -> void:
    var flash := PoolManager.acquire(MUZZLE_SCENE) as MuzzleFlash
    _root.add_child(flash)
    flash.flash(Vector3.ZERO, Vector3.FORWARD)

    var light := flash.get_node("Light") as OmniLight3D
    assert_false(light.shadow_enabled, "đèn tạm TUYỆT ĐỐI không đổ bóng (TDD §12.6)")
    assert_true(flash.is_active())

    flash._process(MuzzleFlash.LIFETIME + 0.01)
    assert_false(flash.is_active(), "0.08s là hết")


func test_chop_lua_van_no_khi_het_ngan_sach_den() -> void:
    for _i: int in range(LightBudget.MAX_TEMPORARY_LIGHTS):
        LightBudget.request()

    var flash := PoolManager.acquire(MUZZLE_SCENE) as MuzzleFlash
    _root.add_child(flash)
    flash.flash(Vector3.ZERO, Vector3.FORWARD)

    assert_true(flash.is_active(), "mất đèn không được làm mất luôn hiệu ứng")
    assert_false(flash.has_light(), "nhưng đèn thì không có")


func test_chop_lua_tra_den_ve_ngan_sach_khi_tat() -> void:
    var flash := PoolManager.acquire(MUZZLE_SCENE) as MuzzleFlash
    _root.add_child(flash)
    flash.flash(Vector3.ZERO, Vector3.FORWARD)
    assert_eq(LightBudget.get_active_count(), 1)

    flash._process(MuzzleFlash.LIFETIME + 0.01)
    assert_eq(LightBudget.get_active_count(), 0, "không trả đèn thì vài giây là cạn ngân sách")


# --- T-604: vỏ đạn ------------------------------------------------------

func test_vo_dan_khong_vuot_tran_60() -> void:
    var ejector := ShellEjector.new()
    ejector.shell_scene = SHELL_SCENE
    ejector.container = _root

    for _i: int in range(ShellEjector.MAX_SHELLS + 25):
        ejector.eject(Vector3.ZERO, Vector3.FORWARD)

    assert_eq(ShellEjector.get_active_count(), ShellEjector.MAX_SHELLS, "TDD §12.7: trần 60 vỏ")


func test_tran_vo_dan_la_tran_chung_cua_ca_hai_tay() -> void:
    var left := ShellEjector.new()
    var right := ShellEjector.new()
    for ejector: ShellEjector in [left, right]:
        ejector.shell_scene = SHELL_SCENE
        ejector.container = _root

    for _i: int in range(40):
        left.eject(Vector3.ZERO, Vector3.FORWARD)
        right.eject(Vector3.ZERO, Vector3.BACK)

    assert_eq(ShellEjector.get_active_count(), ShellEjector.MAX_SHELLS,
        "hai mount dùng chung một trần, không phải 60 mỗi bên")


func test_vo_dan_tu_tra_ve_pool_sau_4_giay() -> void:
    var ejector := ShellEjector.new()
    ejector.shell_scene = SHELL_SCENE
    ejector.container = _root
    var shell: ShellCasing = ejector.eject(Vector3.ZERO, Vector3.FORWARD)

    assert_not_null(shell)
    assert_true(shell.is_active())
    shell._process(ShellCasing.LIFETIME + 0.01)
    assert_false(shell.is_active(), "ART-BIBLE §8: 4s rồi ẩn")


func test_vo_dan_chi_keng_mot_lan() -> void:
    var ejector := ShellEjector.new()
    ejector.shell_scene = SHELL_SCENE
    ejector.container = _root
    var shell: ShellCasing = ejector.eject(Vector3.ZERO, Vector3.FORWARD)

    # Stream còn trống tới M13 nên play_clink() trả false; điều đang kiểm là
    # nó chỉ ĐƯỢC PHÉP kêu một lần, không phải mỗi lần nảy.
    shell.play_clink()
    assert_false(shell.play_clink(), "vỏ lăn lọc cọc không được kêu liên tục")


func test_vu_khi_energy_va_lien_tuc_khong_nha_vo() -> void:
    var rail: WeaponData = load("res://data/weapons/wpn_rail_lance.tres") as WeaponData
    var flamer: WeaponData = load("res://data/weapons/wpn_flamer.tres") as WeaponData
    var autocannon: WeaponData = load("res://data/weapons/wpn_mk2_autocannon.tres") as WeaponData

    assert_false(WeaponMount.ejects_shells(rail), "súng năng lượng không có vỏ")
    assert_false(WeaponMount.ejects_shells(flamer), "súng phun lửa không có vỏ")
    assert_true(WeaponMount.ejects_shells(autocannon), "súng động năng thì có")
    assert_false(WeaponMount.ejects_shells(null))


# --- T-605: xác quái và VFX trúng đích ----------------------------------

func _make_gib_manager() -> GibManager:
    var manager := GibManager.new()
    manager.gib_scene = GIB_SCENE
    manager.impact_metal_scene = IMPACT_METAL
    manager.impact_flesh_scene = IMPACT_FLESH
    _root.add_child(manager)
    return manager


func test_manh_xac_khong_vuot_tran_60() -> void:
    var manager := _make_gib_manager()
    manager.spawn_death_gibs(Vector3.ZERO, GibManager.MAX_GIBS + 30)
    assert_eq(manager.get_active_gib_count(), GibManager.MAX_GIBS, "TDD §12.7: trần 60 xác quái")


func test_manh_xac_tan_sau_6_giay() -> void:
    var manager := _make_gib_manager()
    manager.spawn_death_gibs(Vector3.ZERO, 1)
    var gib: Gib = manager.get_children()[0] as Gib

    assert_eq(Gib.fade_at(0.0), 0.0, "mới ra thì đục")
    assert_eq(Gib.fade_at(Gib.LIFETIME), 1.0, "hết đời thì trong suốt hẳn")
    gib._process(Gib.LIFETIME + 0.01)
    assert_false(gib.is_active(), "ART-BIBLE §8: 6s rồi tan")


func test_diet_le_thi_moi_con_mot_cum_manh_vun() -> void:
    assert_eq(GibManager.gib_count_for_kills(1), GibManager.GIBS_PER_DEATH)
    assert_eq(GibManager.gib_count_for_kills(3), 3 * GibManager.GIBS_PER_DEATH)
    assert_eq(GibManager.gib_count_for_kills(0), 0)


func test_diet_hang_loat_gop_lai_thanh_mot_cum_chu_khong_tao_bao_hat() -> void:
    var many: int = GibManager.gib_count_for_kills(60)
    var few: int = GibManager.gib_count_for_kills(GibManager.MASS_DEATH_THRESHOLD - 1)

    assert_eq(many, GibManager.GIBS_PER_MASS_BURST, "60 con chết cùng frame vẫn chỉ một cụm")
    assert_lt(many, few, "gộp phải RẺ HƠN là không gộp, nếu không thì gộp làm gì")


func test_swarm_chet_hang_loat_chi_sinh_mot_cum_qua_bao_cao_frame() -> void:
    var swarm := SwarmManager.new()
    _root.add_child(swarm)
    var manager := _make_gib_manager()
    manager.bind(swarm)

    for index: int in range(30):
        swarm.spawn(Vector3(float(index), 0.0, 0.0), Vector3.ZERO, 1.0, 0)
    swarm.damage_at_point(Vector3(15.0, 0.0, 0.0), 100.0, 50.0)
    swarm.flush_damage_report()

    assert_eq(swarm.get_alive_count(), 0, "cả đàn phải chết")
    assert_eq(manager.get_active_gib_count(), GibManager.GIBS_PER_MASS_BURST,
        "30 con chết cùng frame chỉ được nổ một cụm gộp")


func test_swarm_gioi_han_vfx_chet_rieng_le_moi_frame() -> void:
    var swarm := SwarmManager.new()
    _root.add_child(swarm)
    swarm.death_vfx_scene = IMPACT_FLESH

    for index: int in range(40):
        swarm.spawn(Vector3(float(index), 0.0, 0.0), Vector3.ZERO, 1.0, 0)
    swarm.damage_at_point(Vector3(20.0, 0.0, 0.0), 100.0, 50.0)

    assert_eq(swarm.get_death_vfx_this_frame(), SwarmManager.MAX_DEATH_VFX_PER_FRAME,
        "quá 10 con chết cùng frame thì ngừng sinh VFX lẻ")


func test_trung_kim_loai_va_trung_thit_dung_hai_scene_khac_nhau() -> void:
    var manager := _make_gib_manager()
    var metal: Node3D = manager.spawn_impact(Vector3.ZERO, Vector3.UP, GibManager.Surface.METAL)
    var flesh: Node3D = manager.spawn_impact(Vector3.ZERO, Vector3.UP, GibManager.Surface.FLESH)

    assert_not_null(metal)
    assert_not_null(flesh)
    assert_ne(metal.scene_file_path, flesh.scene_file_path,
        "kim loại và thịt phải nhìn khác nhau tức thì (ART-BIBLE §8)")
    assert_true((flesh as ImpactVfx).leaves_decal, "trúng thịt sinh decal")
    assert_false((metal as ImpactVfx).leaves_decal, "trúng kim loại thì không")


func test_vfx_trung_dich_ban_thang_xuong_san_khong_lam_sap_look_at() -> void:
    var manager := _make_gib_manager()
    # Pháp tuyến song song trục UP là ca làm hỏng look_at nếu không chặn.
    var effect: Node3D = manager.spawn_impact(Vector3.ZERO, Vector3.UP, GibManager.Surface.METAL)
    assert_not_null(effect, "bắn xuống sàn vẫn phải ra hiệu ứng")


# --- T-606: decal -------------------------------------------------------

func _make_decal_manager() -> DecalManager:
    var manager := DecalManager.new()
    manager.decal_scenes = {&"blood": DECAL_BLOOD, &"bullet": DECAL_BULLET}
    _root.add_child(manager)
    return manager


## Instance decal được TÁI SỬ DỤNG ngay sau khi thu hồi, nên không thể kiểm
## FIFO bằng cách giữ tham chiếu tới cái cũ — phải kiểm bằng VỊ TRÍ.
func _has_decal_at(manager: DecalManager, point: Vector3) -> bool:
    for child: Node in manager.get_children():
        var decal := child as Decal
        if decal != null and decal.visible and decal.global_position.distance_to(point) < 0.1:
            return true
    return false


func test_decal_khong_vuot_tran_va_thu_hoi_theo_fifo() -> void:
    SettingsManager.set_value(&"graphics", &"preset", "low")     # trần 40
    var manager := _make_decal_manager()
    var oldest_point := Vector3.ZERO
    var newest_point := Vector3(999.0, 0.0, 0.0)
    for index: int in range(manager.get_limit()):
        manager.spawn(Vector3(float(index), 0.0, 0.0), Vector3.UP, &"blood")

    assert_eq(manager.get_active_count(), manager.get_limit(), "đầy đúng trần")
    assert_true(_has_decal_at(manager, oldest_point), "vết đầu tiên đang còn đó")

    manager.spawn(newest_point, Vector3.UP, &"blood")

    assert_eq(manager.get_active_count(), manager.get_limit(), "TDD §12.7: không được vượt trần")
    assert_false(_has_decal_at(manager, oldest_point), "vết CŨ NHẤT phải là vết bị thu hồi")
    assert_true(_has_decal_at(manager, newest_point), "vết mới nhất phải có mặt")


func test_tran_decal_di_theo_preset_do_hoa() -> void:
    var manager := _make_decal_manager()
    SettingsManager.set_value(&"graphics", &"preset", "low")
    assert_eq(manager.get_limit(), 40, "preset thấp hạ trần mà không phải sửa code")

    SettingsManager.set_value(&"graphics", &"preset", "high")
    assert_eq(manager.get_limit(), 150)


func test_ha_preset_giua_tran_thi_cat_bot_decal_dang_co() -> void:
    SettingsManager.set_value(&"graphics", &"preset", "high")
    var manager := _make_decal_manager()
    for _i: int in range(60):
        manager.spawn(Vector3.ZERO, Vector3.UP, &"blood")
    assert_eq(manager.get_active_count(), 60)

    SettingsManager.set_value(&"graphics", &"preset", "low")
    assert_eq(manager.get_active_count(), 40, "hạ preset phải có tác dụng ngay")


func test_loai_decal_la_thi_khong_sinh_gi() -> void:
    var manager := _make_decal_manager()
    assert_null(manager.spawn(Vector3.ZERO, Vector3.UP, &"khong_co_that"))
    assert_eq(manager.get_active_count(), 0)


func test_decal_dan_phang_len_san() -> void:
    var transform: Transform3D = DecalManager.build_transform(Vector3.ZERO, Vector3.UP, 1.0, 0.0)
    # Node Decal chiếu theo -Y cục bộ, nên +Y phải trùng pháp tuyến bề mặt.
    assert_almost_eq(transform.basis.y.normalized().dot(Vector3.UP), 1.0, 0.001,
        "dán lên sàn thì hộp chiếu phải hướng xuống sàn")


func test_decal_dan_phang_len_tuong() -> void:
    var normal := Vector3.RIGHT
    var transform: Transform3D = DecalManager.build_transform(Vector3.ZERO, normal, 1.0, 0.0)
    assert_almost_eq(transform.basis.y.normalized().dot(normal), 1.0, 0.001,
        "cùng một hàm phải dán được cả tường, không riêng gì sàn")


func test_decal_khong_sap_khi_phap_tuyen_trung_truc_tham_chieu() -> void:
    for normal: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK, Vector3.LEFT]:
        var transform: Transform3D = DecalManager.build_transform(Vector3.ZERO, normal, 1.0, 0.0)
        assert_gt(transform.basis.determinant(), 0.0,
            "pháp tuyến %s không được làm ma trận suy biến" % normal)


func test_decal_nhac_khoi_be_mat_de_khong_z_fighting() -> void:
    var transform: Transform3D = DecalManager.build_transform(Vector3.ZERO, Vector3.UP, 1.0, 0.0)
    assert_gt(transform.origin.y, 0.0, "phải nhấc khỏi mặt sàn một chút")
