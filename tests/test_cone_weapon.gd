extends GutTest

## T-506 — Vũ khí hình nón liên tục: Flamer và Cryo Projector.
## Điểm quan trọng nhất: sát thương rơi theo TICK, không theo frame — cùng
## một giây giữ cò phải cho cùng kết quả ở mọi khung hình.

const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")

var _swarm: SwarmManager
var _cone: ConeWeapon


func before_each() -> void:
    _swarm = SwarmManager.new()
    add_child_autofree(_swarm)
    _cone = ConeWeapon.new()


func _weapon(id: String) -> WeaponData:
    return load("res://data/weapons/%s.tres" % id) as WeaponData


## Bắn về hướng +X trong `seconds` giây, chia thành các frame dài `frame`.
func _hold(data: WeaponData, seconds: float, frame: float, heat: HeatComponent = null) -> int:
    var ticks: int = 0
    var elapsed: float = 0.0
    while elapsed < seconds - 0.000001:
        ticks += _cone.update(
            frame, true, data, Vector3.ZERO, Vector3(1.0, 0.0, 0.0),
            null, _swarm, heat, null
        )
        elapsed += frame
    return ticks


func test_sat_thuong_roi_theo_tick_chu_khong_theo_frame() -> void:
    var flamer := _weapon("wpn_flamer")     # 10 tick/giây
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)
    _hold(flamer, 1.0, 0.01)                # 100 frame trong 1 giây
    var after_small_frames: float = _swarm._healths[0]

    _swarm.kill(_swarm._ids[0])
    _cone.reset()
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)
    _hold(flamer, 1.0, 0.05)                # 20 frame trong cùng 1 giây

    assert_almost_eq(
        _swarm._healths[0], after_small_frames, 2.5,
        "một giây kẹp cò phải cho cùng sát thương ở 100 FPS và 20 FPS"
    )


func test_flamer_gay_dung_sat_thuong_moi_giay_cua_gdd() -> void:
    var flamer := _weapon("wpn_flamer")     # 22 sát thương/giây
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)

    _hold(flamer, 2.0, 0.02)

    # DoD T-508 cho phép sai số 5% so với bảng GDD §6.2.
    assert_almost_eq(1000.0 - _swarm._healths[0], 44.0, 2.2, "22 sát thương mỗi giây")


func test_tick_dau_no_dung_sau_mot_chu_ky() -> void:
    var flamer := _weapon("wpn_flamer")     # 10 tick/giây → chu kỳ 0.1s
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)

    assert_eq(_hold(flamer, 0.09, 0.03), 0, "chưa đủ một chu kỳ thì chưa có tick")
    assert_eq(_hold(flamer, 0.03, 0.03), 1, "qua 0.1s thì tick đầu nổ")


func test_nha_co_thi_khong_gay_sat_thuong() -> void:
    var flamer := _weapon("wpn_flamer")
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)

    for _i: int in range(50):
        _cone.update(0.02, false, flamer, Vector3.ZERO, Vector3(1.0, 0.0, 0.0),
            null, _swarm, null, null)

    assert_eq(_swarm._healths[0], 1000.0, "nhả cò là im")


func test_muc_tieu_ngoai_goc_non_khong_dinh() -> void:
    var flamer := _weapon("wpn_flamer")     # nón 45°, tầm 6m
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)      # thẳng trước
    _swarm.spawn(Vector3(-3.0, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)     # sau lưng
    _swarm.spawn(Vector3(0.0, 0.0, 3.0), Vector3.ZERO, 1000.0, 0)      # bên hông 90°

    _hold(flamer, 1.0, 0.02)

    assert_lt(_swarm._healths[0], 1000.0, "con thẳng trước mặt phải cháy")
    assert_eq(_swarm._healths[1], 1000.0, "con sau lưng không dính")
    assert_eq(_swarm._healths[2], 1000.0, "con vuông góc nằm ngoài nón 45°")


func test_muc_tieu_ngoai_tam_non_khong_dinh() -> void:
    var flamer := _weapon("wpn_flamer")     # tầm 6m
    _swarm.spawn(Vector3(10.0, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)

    _hold(flamer, 1.0, 0.02)

    assert_eq(_swarm._healths[0], 1000.0, "10m nằm ngoài tầm 6m")


func test_arc_emitter_gioi_han_3_muc_tieu_moi_tick() -> void:
    var arc := _weapon("wpn_arc_emitter")   # max_targets_per_tick = 3
    for x: float in [1.0, 2.0, 3.0, 4.0, 5.0]:
        _swarm.spawn(Vector3(x, 0.0, 0.0), Vector3.ZERO, 1000.0, 0)

    _cone.update(0.2, true, arc, Vector3.ZERO, Vector3(1.0, 0.0, 0.0),
        null, _swarm, null, null)

    var hurt: int = 0
    for index: int in range(5):
        if _swarm._healths[index] < 1000.0:
            hurt += 1
    assert_eq(hurt, 3, "Arc Emitter nhảy tối đa 3 mục tiêu")


# --- Cryo: ngoại lệ nhiệt âm (GDD §6.3) ---------------------------------

func test_cryo_lam_mat_mech_thay_vi_nung_no() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    var heat: HeatComponent = mech.heat_component
    heat.set_heat(50.0)
    var cryo := _weapon("wpn_cryo_projector")   # −6 nhiệt/giây

    _hold(cryo, 2.0, 0.02, heat)

    assert_almost_eq(heat.get_heat(), 38.0, 0.6, "Cryo hạ 6 nhiệt mỗi giây")


func test_cryo_khong_lam_nhiet_am() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    var heat: HeatComponent = mech.heat_component
    heat.set_heat(2.0)
    var cryo := _weapon("wpn_cryo_projector")

    _hold(cryo, 3.0, 0.02, heat)

    assert_eq(heat.get_heat(), 0.0, "nhiệt chạm đáy thì dừng ở 0")


func test_flamer_van_nung_nong_mech() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    var heat: HeatComponent = mech.heat_component
    var flamer := _weapon("wpn_flamer")         # +14 nhiệt/giây

    _hold(flamer, 2.0, 0.02, heat)

    assert_almost_eq(heat.get_heat(), 28.0, 1.4, "Flamer cộng 14 nhiệt mỗi giây")
