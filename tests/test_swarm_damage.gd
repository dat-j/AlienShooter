extends GutTest

var _swarm: SwarmManager


func before_each() -> void:
    _swarm = SwarmManager.new()
    add_child_autofree(_swarm)


func test_damage_at_point_gay_sat_thuong_moi_don_vi_trong_vung() -> void:
    _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 10.0, 0)
    _swarm.spawn(Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 10.0, 0)

    assert_eq(_swarm.damage_at_point(Vector3.ZERO, 1.1, 4.0), 2)
    assert_eq(_swarm._healths[0], 6.0)
    assert_eq(_swarm._healths[1], 6.0)
    assert_eq(_swarm._healths[2], 10.0)


func test_damage_at_point_kill_nhieu_don_vi_khong_bo_sot_do_swap() -> void:
    for x: float in [0.0, 0.25, 0.5]:
        _swarm.spawn(Vector3(x, 0.0, 0.0), Vector3.ZERO, 2.0, 0)

    assert_eq(_swarm.damage_at_point(Vector3.ZERO, 1.0, 2.0), 3)
    assert_eq(_swarm.get_alive_count(), 0)


func test_damage_along_ray_chi_danh_don_vi_sat_doan_thang() -> void:
    _swarm.spawn(Vector3(1.0, 0.0, 0.2), Vector3.ZERO, 10.0, 0)
    _swarm.spawn(Vector3(2.0, 0.0, 2.0), Vector3.ZERO, 10.0, 0)

    assert_eq(_swarm.damage_along_ray(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 3.0, -1), 1)
    assert_eq(_swarm._healths[0], 7.0)
    assert_eq(_swarm._healths[1], 10.0)


func test_damage_along_ray_ton_trong_pierce_theo_thu_tu_gan_nhat() -> void:
    var near_id: int = _swarm.spawn(Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    var far_id: int = _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 10.0, 0)

    assert_eq(_swarm.damage_along_ray(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 4.0, 1), 1)
    assert_eq(_swarm._healths[_swarm._index_by_id[near_id]], 6.0)
    assert_eq(_swarm._healths[_swarm._index_by_id[far_id]], 10.0)


func test_damage_along_ray_xuyen_va_kill_nhieu_muc_tieu() -> void:
    _swarm.spawn(Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 2.0, 0)
    _swarm.spawn(Vector3(2.0, 0.0, 0.0), Vector3.ZERO, 2.0, 0)
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 2.0, 0)

    assert_eq(_swarm.damage_along_ray(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 2.0, 2), 2)
    assert_eq(_swarm.get_alive_count(), 1)
    assert_eq(_swarm._positions[0], Vector3(3.0, 0.0, 0.0))


func test_sat_thuong_khong_hop_le_la_no_op() -> void:
    _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 10.0, 0)
    assert_eq(_swarm.damage_at_point(Vector3.ZERO, 1.0, 0.0), 0)
    assert_eq(_swarm.damage_along_ray(Vector3.ZERO, Vector3.RIGHT, 5.0, 0), 0)
    assert_eq(_swarm._healths[0], 10.0)
