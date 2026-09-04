extends GutTest

## Kiểm tra PoolManager: acquire/release, prewarm, thống kê, hook
## _on_acquired()/_on_released(), và luật hiệu năng — không instantiate()
## thêm sau lần cấp phát đầu qua nhiều chu kỳ acquire/release.
## Xem docs/05-BACKLOG.md T-009.


func _make_dummy_scene() -> PackedScene:
    var root: Node3D = Node3D.new()
    root.name = "DummyPoolNode"
    var packed: PackedScene = PackedScene.new()
    packed.pack(root)
    root.free()
    return packed


func _make_hook_scene() -> PackedScene:
    var script: GDScript = GDScript.new()
    script.source_code = "extends Node3D\n\nvar acquired_calls: int = 0\nvar released_calls: int = 0\n\n\nfunc _on_acquired() -> void:\n    acquired_calls += 1\n\n\nfunc _on_released() -> void:\n    released_calls += 1\n"
    script.reload()
    var root: Node3D = Node3D.new()
    root.set_script(script)
    var packed: PackedScene = PackedScene.new()
    packed.pack(root)
    root.free()
    return packed


func test_acquire_lan_dau_tra_ve_node_khong_cha() -> void:
    var scene: PackedScene = _make_dummy_scene()
    var node: Node = PoolManager.acquire(scene)
    assert_not_null(node, "acquire() phải trả về một node hợp lệ")
    assert_null(node.get_parent(), "acquire() phải trả về node không còn cha (đã gỡ khỏi container nội bộ)")
    PoolManager.release(node)
    PoolManager.clear_pool(scene)


func test_release_dua_node_ve_container_va_an_di() -> void:
    var scene: PackedScene = _make_dummy_scene()
    var node: Node3D = PoolManager.acquire(scene) as Node3D
    PoolManager.release(node)
    assert_not_null(node.get_parent(), "node rảnh sau release() phải được gắn vào container nội bộ của pool")
    assert_false(node.visible, "node rảnh sau release() phải bị ẩn đi")
    PoolManager.clear_pool(scene)


func test_prewarm_cap_phat_truoc_dung_so_luong() -> void:
    var scene: PackedScene = _make_dummy_scene()
    PoolManager.prewarm(scene, 5)
    var stats: Dictionary = PoolManager.get_stats()
    var key: String = PoolManager._display_key(scene)
    assert_true(stats.has(key), "get_stats() phải có mục cho scene vừa prewarm")
    assert_eq(int(stats[key]["total"]), 5, "prewarm(scene, 5) phải tạo đúng 5 instance")
    assert_eq(int(stats[key]["in_use"]), 0, "ngay sau prewarm chưa có instance nào đang được dùng")
    PoolManager.clear_pool(scene)


func test_get_stats_dem_dung_so_luong_dang_dung() -> void:
    var scene: PackedScene = _make_dummy_scene()
    var a: Node = PoolManager.acquire(scene)
    var b: Node = PoolManager.acquire(scene)
    var key: String = PoolManager._display_key(scene)
    var stats: Dictionary = PoolManager.get_stats()
    assert_eq(int(stats[key]["in_use"]), 2, "phải đếm đúng 2 instance đang dùng sau 2 lần acquire")
    PoolManager.release(a)
    stats = PoolManager.get_stats()
    assert_eq(int(stats[key]["in_use"]), 1, "sau khi release 1 trong 2, in_use phải giảm còn 1")
    PoolManager.release(b)
    PoolManager.clear_pool(scene)


func test_hook_on_acquired_va_on_released_duoc_goi() -> void:
    var scene: PackedScene = _make_hook_scene()
    var node: Node = PoolManager.acquire(scene)
    assert_eq(int(node.get("acquired_calls")), 1, "_on_acquired() phải được pool gọi khi acquire()")
    PoolManager.release(node)
    assert_eq(int(node.get("released_calls")), 1, "_on_released() phải được pool gọi khi release()")
    PoolManager.clear_pool(scene)


func test_clear_all_xoa_sach_moi_pool_khoi_thong_ke() -> void:
    var scene: PackedScene = _make_dummy_scene()
    PoolManager.prewarm(scene, 3)
    var key: String = PoolManager._display_key(scene)
    PoolManager.clear_all()
    var stats: Dictionary = PoolManager.get_stats()
    assert_false(stats.has(key), "clear_all() phải xoá sạch mọi pool khỏi get_stats()")


func test_khong_instantiate_them_sau_lan_cap_phat_dau_qua_1000_chu_ky() -> void:
    var scene: PackedScene = _make_dummy_scene()
    var warm_up: Node = PoolManager.acquire(scene)
    PoolManager.release(warm_up)
    var count_after_warm_up: int = PoolManager._instantiate_count

    for _i: int in range(1000):
        var node: Node = PoolManager.acquire(scene)
        PoolManager.release(node)

    assert_eq(PoolManager._instantiate_count, count_after_warm_up, "không được có instantiate() nào thêm sau lần cấp phát đầu, qua 1000 chu kỳ acquire/release")
    PoolManager.clear_pool(scene)


## --- T-501: pool cho DamageInfo -----------------------------------------

func test_damage_info_lay_ra_luon_o_trang_thai_sach() -> void:
    var info: DamageInfo = PoolManager.get_damage_info()
    info.amount = 42.0
    info.is_critical = true
    info.status_to_apply.append(&"eff_burning")
    PoolManager.release_damage_info(info)
    var reused: DamageInfo = PoolManager.get_damage_info()
    assert_eq(reused.amount, 0.0, "DamageInfo lấy ra phải được reset")
    assert_false(reused.is_critical)
    assert_eq(reused.status_to_apply.size(), 0)
    PoolManager.release_damage_info(reused)


func test_damage_info_khong_cap_phat_them_qua_10000_chu_ky() -> void:
    PoolManager.prewarm_damage_info(4)
    var created_after_warm_up: int = (PoolManager.get_damage_info_stats() as Dictionary)["total"]
    for _i: int in range(10000):
        var info: DamageInfo = PoolManager.get_damage_info()
        info.amount = 1.0
        PoolManager.release_damage_info(info)
    var stats: Dictionary = PoolManager.get_damage_info_stats()
    assert_eq(stats["total"], created_after_warm_up, "không được tạo DamageInfo mới khi pool còn hàng")
    assert_eq(stats["in_use"], 0, "trả hết thì không còn cái nào đang dùng")


func test_damage_info_dem_dung_so_dang_dung() -> void:
    var a: DamageInfo = PoolManager.get_damage_info()
    var b: DamageInfo = PoolManager.get_damage_info()
    assert_eq((PoolManager.get_damage_info_stats() as Dictionary)["in_use"], 2)
    PoolManager.release_damage_info(a)
    PoolManager.release_damage_info(b)
    assert_eq((PoolManager.get_damage_info_stats() as Dictionary)["in_use"], 0)
