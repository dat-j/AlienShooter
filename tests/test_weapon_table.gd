extends GutTest

## T-508 — 16 tài nguyên vũ khí phải khớp bảng GDD §6.2.
## DoD cho phép sai số 5% giữa DPS đo từ `.tres` và DPS trong bảng.

const TOLERANCE: float = 0.05
const ARENA_SCENE: PackedScene = preload("res://scenes/main/test_arena.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/projectile_basic.tscn")

## id → [DPS bảng, DPH bảng]. `-1.0` nghĩa là bảng GDD ghi "—".
const TABLE: Dictionary = {
    "wpn_mk2_autocannon": [64.0, 3.6],
    "wpn_twin_repeater": [65.0, 3.3],
    "wpn_pulse_laser": [42.0, 1.6],
    "wpn_frag_launcher": [90.0, 10.0],
    "wpn_scattergun": [130.0, 10.3],
    "wpn_arc_emitter": [66.0, 5.1],
    "wpn_flamer": [22.0, -1.0],
    "wpn_gauss_repeater": [88.0, 4.4],
    "wpn_mortar_pod": [76.0, 7.9],
    "wpn_rail_lance": [72.0, 3.4],
    "wpn_cryo_projector": [8.0, -1.0],
    "wpn_nail_driver": [119.0, 7.6],
    "wpn_plasma_thrower": [99.0, 2.5],
    # DPH của Swarm Missiles trong GDD (2.4) không khớp với chính DMG/HEAT
    # của nó (96/20 = 4.8). Chỉ kiểm DPS cho tới khi bảng được sửa.
    "wpn_swarm_missiles": [48.0, -1.0],
    "wpn_singularity_core": [-1.0, -1.0],
    "wpn_vulcan_x": [224.0, 4.4],
}


func _weapon(id: String) -> WeaponData:
    return load("res://data/weapons/%s.tres" % id) as WeaponData


## DPS lý thuyết: vũ khí liên tục khai báo thẳng mỗi giây, vũ khí bắn phát
## một nhân sát thương một viên với số viên và tốc bắn.
static func theoretical_dps(data: WeaponData) -> float:
    if data.is_continuous:
        return data.damage
    return data.damage * float(maxi(data.projectiles_per_shot, 1)) * data.rate_of_fire


## DPH — sát thương trên mỗi điểm nhiệt, trục cân bằng chính của GDD §6.3.
static func damage_per_heat(data: WeaponData) -> float:
    if data.heat_per_shot <= 0.0:
        return -1.0
    return data.damage * float(maxi(data.projectiles_per_shot, 1)) / data.heat_per_shot


func test_du_16_vu_khi() -> void:
    var dir: DirAccess = DirAccess.open("res://data/weapons")
    assert_not_null(dir, "phải mở được thư mục vũ khí")
    var count: int = 0
    for file_name: String in dir.get_files():
        if file_name.ends_with(".tres"):
            count += 1
    assert_eq(count, 16, "bảng GDD §6.2 có đúng 16 vũ khí")


func test_id_khop_ten_file_va_co_khoa_dich() -> void:
    for id: String in TABLE:
        var data: WeaponData = _weapon(id)
        assert_not_null(data, "%s phải tải được" % id)
        assert_eq(String(data.id), id, "%s: id phải khớp tên file" % id)
        assert_eq(
            data.display_name_key, "weapon.%s.name" % id,
            "%s: tên hiển thị phải là khoá dịch, không phải chuỗi thô" % id
        )


func test_dps_khop_bang_gdd_trong_sai_so_5_phan_tram() -> void:
    for id: String in TABLE:
        var expected: float = (TABLE[id] as Array)[0]
        if expected < 0.0:
            continue
        var measured: float = theoretical_dps(_weapon(id))
        assert_almost_eq(
            measured, expected, expected * TOLERANCE,
            "%s: DPS đo %.1f, bảng ghi %.1f" % [id, measured, expected]
        )


func test_dph_khop_bang_gdd_trong_sai_so_5_phan_tram() -> void:
    for id: String in TABLE:
        var expected: float = (TABLE[id] as Array)[1]
        if expected < 0.0:
            continue
        var measured: float = damage_per_heat(_weapon(id))
        assert_almost_eq(
            measured, expected, expected * TOLERANCE,
            "%s: DPH đo %.2f, bảng ghi %.2f" % [id, measured, expected]
        )


func test_moi_vu_khi_co_duong_ban_ro_rang() -> void:
    for id: String in TABLE:
        var data: WeaponData = _weapon(id)
        if data.is_continuous:
            assert_gt(data.cone_angle_degrees, 0.0, "%s: vũ khí liên tục phải có nón" % id)
            assert_gt(data.max_range, 0.0, "%s: vũ khí liên tục phải có tầm" % id)
            assert_gt(data.tick_rate, 0.0, "%s: vũ khí liên tục phải có nhịp tick" % id)
            continue
        if data.projectile_scene == null:
            assert_gt(data.max_range, 0.0, "%s: hitscan phải khai báo tầm" % id)
        else:
            assert_gt(data.projectile_speed, 0.0, "%s: đạn bay phải có tốc độ" % id)


func test_vu_khi_energy_khong_dung_dan() -> void:
    for id: String in TABLE:
        var data: WeaponData = _weapon(id)
        if data.category != 1:
            continue
        assert_false(data.uses_ammo, "%s: nhóm Energy không dùng đạn (GDD §6.1)" % id)


func test_chi_cryo_lam_mat_mech() -> void:
    for id: String in TABLE:
        var data: WeaponData = _weapon(id)
        if id == "wpn_cryo_projector":
            assert_lt(data.heat_per_shot, 0.0, "Cryo Projector phải có nhiệt âm (GDD §6.3)")
        else:
            assert_gte(data.heat_per_shot, 0.0, "%s: chỉ Cryo được có nhiệt âm" % id)


func test_trang_thai_khai_bao_deu_ton_tai_trong_content_db() -> void:
    for id: String in TABLE:
        var data: WeaponData = _weapon(id)
        for status_id: StringName in data.status_to_apply:
            assert_not_null(
                ContentDB.get_status_effect(status_id),
                "%s: trạng thái %s phải có file .tres" % [id, status_id]
            )


func test_chi_nhom_explosive_moi_tu_gay_sat_thuong() -> void:
    for id: String in TABLE:
        var data: WeaponData = _weapon(id)
        if data.self_damage_radius <= 0.0:
            continue
        assert_eq(data.category, 2, "%s: chỉ nhóm Explosive mới tự thương (GDD §6.1)" % id)
        assert_gt(data.aoe_radius, data.self_damage_radius,
            "%s: bán kính tự thương phải nhỏ hơn bán kính nổ" % id)


# --- Bắn thật trong sân tập ---------------------------------------------

func after_each() -> void:
    # Trả đạn còn bay về pool để bài sau không nhặt nhầm đạn của bài trước.
    for root: Node in [get_tree().current_scene, get_tree().root]:
        if root == null:
            continue
        for child: Node in root.get_children():
            if child is Projectile:
                PoolManager.release(child)
    PoolManager.clear_pool(PROJECTILE_SCENE)


## Giữ cò `seconds` giây trên mount trái. Trả về tổng số phát/tick rời nòng.
func _hold_trigger(mount: WeaponMount, aim_point: Vector3, seconds: float) -> int:
    var shots: int = 0
    var frame: float = 1.0 / 60.0
    var elapsed: float = 0.0
    while elapsed < seconds:
        shots += mount.update(frame, true, null, aim_point)
        elapsed += frame
    return shots


func test_moi_vu_khi_deu_ban_duoc_trong_san_tap() -> void:
    var arena := add_child_autofree(ARENA_SCENE.instantiate()) as Node3D
    var mech := arena.get_node("Mech") as MechController
    var swarm := arena.get_node("SwarmRuntime/SwarmManager") as SwarmManager
    var mount: WeaponMount = mech.weapon_mount_left
    mount.swarm_manager = swarm
    var aim_point: Vector3 = mech.global_position + Vector3(0.0, 0.0, -10.0)

    for id: String in TABLE:
        mount.equip(_weapon(id))
        var shots: int = _hold_trigger(mount, aim_point, 2.0)
        assert_gt(shots, 0, "%s: giữ cò 2 giây phải bắn được ít nhất một phát" % id)


func test_hitscan_va_non_trung_swarm_ngay_trong_frame_ban() -> void:
    var arena := add_child_autofree(ARENA_SCENE.instantiate()) as Node3D
    var mech := arena.get_node("Mech") as MechController
    var swarm := arena.get_node("SwarmRuntime/SwarmManager") as SwarmManager
    var mount: WeaponMount = mech.weapon_mount_left
    mount.swarm_manager = swarm
    # Pulse Laser (hitscan) và Flamer (nón 6m) đều trúng ngay, không cần đợi
    # đạn bay — nên kiểm được trong một lần gọi update().
    for id: String in ["wpn_pulse_laser", "wpn_flamer"]:
        var target := mech.global_position + Vector3(0.0, 0.0, -4.0)
        var unit_id: int = swarm.spawn(target, Vector3.ZERO, 1000.0, 0)
        mount.equip(_weapon(id))
        # Ngắm thẳng vào mục tiêu: nòng lệch sang trái so với tâm mech nên
        # ngắm vào một điểm "phía trước mech" sẽ cho tia đi chệch.
        _hold_trigger(mount, target, 1.0)
        assert_true(swarm.is_alive(unit_id), "%s: mục tiêu 1000 máu chưa chết" % id)
        assert_lt(swarm._healths[swarm._index_by_id[unit_id]], 1000.0,
            "%s: phải trừ máu con swarm đứng trước mặt" % id)
        swarm.kill(unit_id)
