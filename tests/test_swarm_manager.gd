extends GutTest

## Kiểm tra vòng đời data-oriented của SwarmManager.
## Xem docs/05-BACKLOG.md T-304 và docs/02-TDD.md §6.1.

var _swarm: SwarmManager


func before_each() -> void:
    _swarm = SwarmManager.new()
    add_child_autofree(_swarm)


func test_spawn_tang_alive_count_va_luu_du_lieu_song_song() -> void:
    var id: int = _swarm.spawn(
        Vector3(1.0, 0.0, 2.0),
        Vector3(3.0, 0.0, 4.0),
        18.0,
        0
    )

    assert_true(id >= 0, "spawn phải trả về id hợp lệ")
    assert_eq(_swarm.get_alive_count(), 1, "spawn một đơn vị phải tăng alive_count lên 1")
    assert_eq(_swarm._ids[0], id, "slot đầu phải giữ đúng id logic")
    assert_eq(_swarm._positions[0], Vector3(1.0, 0.0, 2.0), "position phải được lưu trong mảng song song")
    assert_eq(_swarm._velocities[0], Vector3(3.0, 0.0, 4.0), "velocity phải được lưu trong mảng song song")
    assert_eq(_swarm._healths[0], 18.0, "health phải được lưu trong mảng song song")
    assert_eq(_swarm._types[0], 0, "type phải được lưu trong mảng song song")
    assert_eq(_swarm._states[0], SwarmManager.STATE_ALIVE, "state mặc định phải là ALIVE")


func test_spawn_day_slot_khi_swarm_day() -> void:
    for i: int in range(SwarmManager.MAX_SWARM_UNITS):
        var id: int = _swarm.spawn(Vector3(float(i), 0.0, 0.0), Vector3.ZERO, 10.0, 0)
        assert_true(id >= 0, "400 slot đầu tiên đều phải spawn được")

    var overflow_id: int = _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 10.0, 0)
    assert_eq(overflow_id, -1, "spawn thứ 401 phải bị từ chối")
    assert_eq(_swarm.get_alive_count(), SwarmManager.MAX_SWARM_UNITS, "alive_count phải dừng ở 400")


func test_kill_hoan_doi_phan_tu_cuoi_vao_slot_bi_xoa() -> void:
    var first_id: int = _swarm.spawn(Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 10.0, 1)
    var second_id: int = _swarm.spawn(Vector3(2.0, 0.0, 0.0), Vector3.ZERO, 20.0, 2)
    var third_id: int = _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 30.0, 3)

    assert_true(_swarm.kill(second_id), "kill id đang sống phải thành công")
    assert_eq(_swarm.get_alive_count(), 2, "kill phải giảm alive_count")
    assert_eq(_swarm._ids[0], first_id, "phần tử đầu phải giữ nguyên")
    assert_eq(_swarm._ids[1], third_id, "phần tử cuối phải được hoán đổi vào slot bị xoá")
    assert_eq(_swarm._positions[1], Vector3(3.0, 0.0, 0.0), "position của phần tử được hoán đổi phải được giữ")
    assert_eq(_swarm._healths[1], 30.0, "health của phần tử được hoán đổi phải được giữ")
    assert_eq(_swarm._types[1], 3, "type của phần tử được hoán đổi phải được giữ")
    assert_eq(_swarm._index_by_id[third_id], 1, "index của id được hoán đổi phải được cập nhật")


func test_kill_id_khong_ton_tai_la_no_op() -> void:
    assert_false(_swarm.kill(999), "kill id ngoài phạm vi phải là no-op")
    assert_eq(_swarm.get_alive_count(), 0, "kill id không tồn tại không được thay đổi alive_count")


func test_spawn_lai_sau_khi_kill_o_giua_khong_tao_id_trung() -> void:
    var first_id: int = _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 10.0, 0)
    var second_id: int = _swarm.spawn(Vector3.ONE, Vector3.ZERO, 10.0, 0)
    var third_id: int = _swarm.spawn(Vector3(2.0, 0.0, 0.0), Vector3.ZERO, 10.0, 0)

    assert_true(_swarm.kill(second_id), "kill id ở giữa phải thành công")
    var reused_id: int = _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 10.0, 0)

    assert_eq(reused_id, second_id, "spawn sau kill phải tái sử dụng đúng id rảnh")
    assert_ne(reused_id, first_id, "id mới không được trùng id còn sống thứ nhất")
    assert_ne(reused_id, third_id, "id mới không được trùng id còn sống thứ ba")
    assert_eq(_swarm.get_alive_count(), 3, "kill rồi spawn lại phải giữ đúng số đơn vị sống")


func test_spawn_kill_lap_lai_10000_chu_ky_khong_tang_so_slot() -> void:
    for i: int in range(10000):
        var id: int = _swarm.spawn(Vector3(float(i), 0.0, 0.0), Vector3.ZERO, 10.0, i & 3)
        assert_true(id >= 0, "mỗi chu kỳ phải lấy được slot rảnh")
        assert_true(_swarm.kill(id), "id vừa spawn phải kill được ngay")

    assert_eq(_swarm.get_alive_count(), 0, "10000 chu kỳ phải trả swarm về 0 đơn vị")
    assert_eq(_swarm._free_ids.size(), SwarmManager.MAX_SWARM_UNITS, "stack id rảnh phải giữ nguyên kích thước cố định")
