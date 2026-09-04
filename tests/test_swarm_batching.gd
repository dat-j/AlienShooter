extends GutTest

var _swarm: SwarmManager


func before_each() -> void:
    _swarm = SwarmManager.new()
    add_child_autofree(_swarm)


func test_mac_dinh_mot_lo_va_nhan_cau_hinh_hop_le() -> void:
    assert_eq(_swarm.get_batch_count(), 1)
    assert_true(_swarm.set_batch_count(2))
    assert_eq(_swarm.get_batch_count(), 2)
    assert_true(_swarm.set_batch_count(4))
    assert_eq(_swarm.get_batch_count(), 4)


func test_tu_choi_so_lo_khong_hop_le() -> void:
    assert_true(_swarm.set_batch_count(2))
    assert_false(_swarm.set_batch_count(3))
    assert_eq(_swarm.get_batch_count(), 2)


func test_bon_lo_lan_luot_bao_phu_moi_id() -> void:
    assert_true(_swarm.set_batch_count(4))
    for expected: int in range(4):
        assert_eq(_swarm.get_current_batch(), expected)
        for id: int in range(8):
            assert_eq(_swarm.is_id_in_current_batch(id), id % 4 == expected)
        _swarm.advance_batch()
    assert_eq(_swarm.get_current_batch(), 0)


func test_delta_theo_lo_bu_thoi_gian_giua_hai_lan_cap_nhat() -> void:
    _swarm.set_batch_count(4)
    assert_almost_eq(_swarm.get_batched_delta(0.016), 0.064, 0.00001)


func test_movement_chi_cap_nhat_lo_hien_tai() -> void:
    var flow: FlowField = FlowField.new()
    flow.configure(AABB(Vector3(-6.0, -1.0, -6.0), Vector3(12.0, 2.0, 12.0)), 1.5)
    flow.rebuild(Vector3(5.0, 0.0, 0.0))
    var movement: SwarmMovement = SwarmMovement.new()
    for id: int in range(4):
        _swarm.spawn(Vector3(float(id) * 0.1, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    _swarm.set_batch_count(4)

    movement.update(_swarm, flow, 0.1)

    assert_gt(_swarm._velocities[_swarm._index_by_id[0]].length(), 0.0)
    for id: int in range(1, 4):
        assert_eq(_swarm._velocities[_swarm._index_by_id[id]], Vector3.ZERO)


func test_sau_bon_frame_moi_don_vi_duoc_cap_nhat_mot_lan() -> void:
    var flow: FlowField = FlowField.new()
    flow.configure(AABB(Vector3(-6.0, -1.0, -6.0), Vector3(12.0, 2.0, 12.0)), 1.5)
    flow.rebuild(Vector3(5.0, 0.0, 0.0))
    var movement: SwarmMovement = SwarmMovement.new()
    for id: int in range(4):
        _swarm.spawn(Vector3(float(id) * 0.1, 0.0, 0.0), Vector3.ZERO, 10.0, 0)
    _swarm.set_batch_count(4)

    for frame: int in range(4):
        movement.update(_swarm, flow, 0.1)
        _swarm.advance_batch()

    for id: int in range(4):
        assert_gt(_swarm._velocities[_swarm._index_by_id[id]].length(), 0.0)
