extends GutTest

## T-503 · T-504 — WeaponMount bắn theo WeaponData, và đạn pooled tự raycast.

const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/projectile_basic.tscn")

var _mech: MechController


func before_each() -> void:
    _mech = add_child_autofree(MECH_SCENE.instantiate()) as MechController


func after_each() -> void:
    # Trả mọi viên còn bay về pool để bài sau không nhặt nhầm đạn của bài trước.
    for root: Node in [get_tree().current_scene, get_tree().root]:
        if root == null:
            continue
        for child: Node in root.get_children():
            if child is Projectile:
                PoolManager.release(child)
    PoolManager.clear_pool(PROJECTILE_SCENE)


func _weapon(id: String) -> WeaponData:
    return load("res://data/weapons/%s.tres" % id) as WeaponData


func _aim_point() -> Vector3:
    return _mech.global_position + Vector3(0.0, 0.0, -20.0)


# --- T-503: WeaponMount -------------------------------------------------

func test_both_mounts_are_equipped_and_fire_independently() -> void:
    assert_not_null(_mech.weapon_mount_left.weapon_data, "mount trái phải có vũ khí")
    assert_not_null(_mech.weapon_mount_right.weapon_data, "mount phải phải có vũ khí")
    var left_before: int = _mech.weapon_mount_left.get_ammo()
    var right_before: int = _mech.weapon_mount_right.get_ammo()
    _mech.update_weapons(0.02, true, false)
    assert_eq(_mech.weapon_mount_left.get_ammo(), left_before - 1, "chỉ mount trái bắn")
    assert_eq(_mech.weapon_mount_right.get_ammo(), right_before, "mount phải không bắn theo")
    _mech.update_weapons(0.02, false, true)
    assert_eq(_mech.weapon_mount_right.get_ammo(), right_before - 1, "mount phải bắn độc lập")


func test_rate_of_fire_comes_from_weapon_data() -> void:
    var mount := _mech.weapon_mount_left
    mount.equip(_weapon("wpn_mk2_autocannon"))     # 8 phát/giây → 0.125s mỗi phát
    assert_eq(mount.update(0.02, true, null, _aim_point()), 1, "phát đầu bắn ngay")
    assert_eq(mount.update(0.02, true, null, _aim_point()), 0, "chưa tới nhịp thì chưa bắn")
    assert_eq(mount.update(0.13, true, null, _aim_point()), 1, "qua 0.125s thì bắn phát tiếp")


func test_firing_adds_heat_from_weapon_data() -> void:
    var mount := _mech.weapon_mount_left
    mount.equip(_weapon("wpn_mk2_autocannon"))
    mount.update(0.02, true, _mech.heat_component, _aim_point())
    assert_almost_eq(_mech.heat_component.get_heat(), 2.2, 0.001, "MK2 Autocannon cộng 2.2 nhiệt")


func test_overheat_locks_the_mount() -> void:
    var mount := _mech.weapon_mount_left
    _mech.heat_component.add_heat(100.0)
    assert_eq(mount.update(0.02, true, _mech.heat_component, _aim_point()), 0, "quá nhiệt thì khoá vũ khí")
    _mech.heat_component.tick(3.1)
    assert_eq(mount.update(0.02, true, _mech.heat_component, _aim_point()), 1, "hết quá nhiệt thì bắn lại được")


func test_ammo_runs_out_and_can_be_refilled() -> void:
    var mount := _mech.weapon_mount_left
    var data := WeaponData.new()
    data.rate_of_fire = 100.0
    data.uses_ammo = true
    data.max_ammo = 2
    mount.equip(data)
    watch_signals(mount)
    mount.update(0.02, true, null, _aim_point())
    mount.update(0.02, true, null, _aim_point())
    assert_eq(mount.get_ammo(), 0)
    assert_eq(mount.update(0.02, true, null, _aim_point()), 0, "hết đạn thì không bắn")
    assert_signal_emitted(mount, "out_of_ammo")
    mount.add_ammo(5)
    assert_eq(mount.get_ammo(), 2, "không nạp quá đạn tối đa")


func test_energy_weapon_ignores_ammo() -> void:
    var mount := _mech.weapon_mount_left
    mount.equip(_weapon("wpn_rail_lance"))         # Energy, uses_ammo = false
    mount.update(2.0, true, null, _aim_point())    # đủ thời gian sạc 0.5s
    assert_eq(mount.update(0.02, true, null, _aim_point()), 0, "còn hồi chiêu")
    assert_eq(mount.get_ammo(), 0, "vũ khí Energy không đếm đạn")


func test_charge_weapon_waits_before_the_first_shot() -> void:
    var mount := _mech.weapon_mount_left
    mount.equip(_weapon("wpn_rail_lance"))         # charge_time 0.5s
    assert_eq(mount.update(0.2, true, null, _aim_point()), 0, "chưa sạc xong thì chưa bắn")
    assert_almost_eq(mount.get_charge_ratio(), 0.4, 0.001)
    assert_eq(mount.update(0.4, true, null, _aim_point()), 1, "sạc đủ 0.5s thì bắn")
    assert_almost_eq(mount.get_charge_ratio(), 0.0, 0.001, "bắn xong thì sạc lại từ đầu")


func test_releasing_the_trigger_cancels_the_charge() -> void:
    var mount := _mech.weapon_mount_left
    mount.equip(_weapon("wpn_rail_lance"))
    mount.update(0.3, true, null, _aim_point())
    mount.update(0.1, false, null, _aim_point())
    assert_almost_eq(mount.get_charge_ratio(), 0.0, 0.001, "nhả cò thì mất sạc")


func test_spin_up_weapon_needs_the_barrel_running() -> void:
    var mount := _mech.weapon_mount_left
    var data := WeaponData.new()
    data.rate_of_fire = 16.0
    data.spin_up_time = 0.7
    data.uses_ammo = false
    mount.equip(data)
    assert_eq(mount.update(0.5, true, null, _aim_point()), 0, "chưa quay đủ nòng thì chưa bắn")
    assert_almost_eq(mount.get_spin_ratio(), 0.5 / 0.7, 0.001)
    assert_eq(mount.update(0.3, true, null, _aim_point()), 1, "quay đủ 0.7s thì bắn")


# --- T-504: đạn ---------------------------------------------------------

func test_shot_spawns_a_pooled_projectile_aimed_at_the_cursor() -> void:
    var mount := _mech.weapon_mount_left
    mount.update(0.02, true, null, _aim_point())
    var projectile: Projectile = _find_projectile()
    assert_not_null(projectile, "bắn phải sinh ra một viên đạn")
    assert_true(projectile.is_flying())
    assert_almost_eq(projectile.get_damage(), 8.0, 0.001, "sát thương lấy từ WeaponData")


func test_projectiles_are_reused_not_reinstantiated() -> void:
    var mount := _mech.weapon_mount_left
    mount.update(0.02, true, null, _aim_point())
    var first: Projectile = _find_projectile()
    PoolManager.release(first)
    var created: int = (PoolManager.get_stats() as Dictionary)[PROJECTILE_SCENE.resource_path]["total"]
    mount.update(1.0, true, null, _aim_point())
    var second: Projectile = _find_projectile()
    assert_same(second, first, "viên thứ hai phải là viên đã trả về pool")
    assert_eq((PoolManager.get_stats() as Dictionary)[PROJECTILE_SCENE.resource_path]["total"], created,
        "không instantiate() thêm khi pool còn đạn rảnh")


func test_projectile_returns_to_pool_after_its_lifetime() -> void:
    var projectile := add_child_autofree(PROJECTILE_SCENE.instantiate()) as Projectile
    projectile.launch(Vector3.ZERO, Vector3.FORWARD, 10.0, 5.0, DamageTypes.Type.KINETIC, null)
    watch_signals(projectile)
    projectile._physics_process(Projectile.MAX_LIFETIME + 0.1)
    assert_false(projectile.is_flying(), "hết đời thì ngừng bay")
    assert_signal_emitted(projectile, "expired")


func test_projectile_moves_along_its_direction() -> void:
    var projectile := add_child_autofree(PROJECTILE_SCENE.instantiate()) as Projectile
    projectile.launch(Vector3.ZERO, Vector3.FORWARD, 60.0, 5.0, DamageTypes.Type.KINETIC, null)
    projectile._physics_process(0.1)
    assert_almost_eq(projectile.global_position.z, -6.0, 0.001, "60 m/s trong 0.1s là 6m")


func test_projectile_damages_swarm_along_its_path() -> void:
    var projectile := add_child_autofree(PROJECTILE_SCENE.instantiate()) as Projectile
    var swarm: SwarmManager = add_child_autofree(SwarmManager.new()) as SwarmManager
    var victim: int = swarm.spawn(Vector3(0.0, 0.0, -3.0), Vector3.ZERO, 18.0, 0)
    projectile.swarm_manager = swarm
    projectile.configure(0, 0.0)
    projectile.launch(Vector3.ZERO, Vector3.FORWARD, 60.0, 8.0, DamageTypes.Type.KINETIC, null)
    projectile._physics_process(0.1)
    assert_almost_eq(swarm._healths[swarm._index_by_id[victim]], 10.0, 0.01,
        "đạn phải trừ máu con swarm nằm trên đường bay")
    assert_false(projectile.is_flying(), "hết lượt xuyên thì đạn kết thúc")


func test_pierce_lets_the_shot_continue_through_more_targets() -> void:
    var projectile := add_child_autofree(PROJECTILE_SCENE.instantiate()) as Projectile
    var swarm: SwarmManager = add_child_autofree(SwarmManager.new()) as SwarmManager
    swarm.spawn(Vector3(0.0, 0.0, -2.0), Vector3.ZERO, 4.0, 0)
    swarm.spawn(Vector3(0.0, 0.0, -4.0), Vector3.ZERO, 4.0, 0)
    projectile.swarm_manager = swarm
    projectile.configure(2, 0.0)
    projectile.launch(Vector3.ZERO, Vector3.FORWARD, 60.0, 8.0, DamageTypes.Type.KINETIC, null)
    projectile._physics_process(0.1)
    assert_eq(swarm.get_alive_count(), 0, "xuyên 2 mục tiêu thì hạ cả hai")


func _find_projectile() -> Projectile:
    for child: Node in get_tree().current_scene.get_children() if get_tree().current_scene != null else []:
        var projectile := child as Projectile
        if projectile != null and projectile.is_flying():
            return projectile
    for child: Node in get_tree().root.get_children():
        var projectile := child as Projectile
        if projectile != null and projectile.is_flying():
            return projectile
    return null
