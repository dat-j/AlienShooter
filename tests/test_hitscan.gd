extends GutTest

## T-505 — Hitscan bắn tức thời. Ở đây chỉ dựng phần swarm (`space` để trống)
## vì đó là phần có logic thật: trộn kết quả theo khoảng cách và tiêu pierce.
## Phần raycast actor/tường do engine đảm nhiệm và được sân tập kiểm chứng.

var _swarm: SwarmManager
var _hitscan: Hitscan


func before_each() -> void:
    _swarm = SwarmManager.new()
    add_child_autofree(_swarm)
    _hitscan = Hitscan.new()


func _fire(pierce: int, damage: float = 5.0) -> int:
    return _hitscan.fire(
        null,
        Vector3.ZERO,
        Vector3(1.0, 0.0, 0.0),
        30.0,
        damage,
        DamageTypes.Type.ENERGY,
        pierce,
        null,
        _swarm
    )


func test_pierce_0_chi_trung_mot_muc_tieu() -> void:
    _swarm.spawn(Vector3(2.0, 0.0, 0.0), Vector3.ZERO, 100.0, 0)
    _swarm.spawn(Vector3(4.0, 0.0, 0.0), Vector3.ZERO, 100.0, 0)

    assert_eq(_fire(0), 1, "pierce 0 nghĩa là đúng một mục tiêu")
    assert_eq(_swarm._healths[0], 95.0, "con gần nòng nhất ăn đòn")
    assert_eq(_swarm._healths[1], 100.0, "con phía sau không dính")


func test_pierce_tieu_theo_thu_tu_gan_nong_truoc() -> void:
    # Sinh ngược thứ tự để chứng minh kết quả được sắp lại, không phải may mắn.
    _swarm.spawn(Vector3(6.0, 0.0, 0.0), Vector3.ZERO, 100.0, 0)
    _swarm.spawn(Vector3(2.0, 0.0, 0.0), Vector3.ZERO, 100.0, 0)
    _swarm.spawn(Vector3(4.0, 0.0, 0.0), Vector3.ZERO, 100.0, 0)

    assert_eq(_fire(1), 2, "pierce 1 = hai mục tiêu")
    assert_eq(_swarm._healths[1], 95.0, "con ở 2m dính")
    assert_eq(_swarm._healths[2], 95.0, "con ở 4m dính")
    assert_eq(_swarm._healths[0], 100.0, "con ở 6m còn nguyên")


func test_pierce_am_xuyen_toan_bo() -> void:
    for x: float in [1.0, 2.0, 3.0, 4.0]:
        _swarm.spawn(Vector3(x, 0.0, 0.0), Vector3.ZERO, 100.0, 0)

    assert_eq(_fire(-1), 4, "pierce âm xuyên hết")


func test_muc_tieu_lech_khoi_tia_khong_dinh() -> void:
    _swarm.spawn(Vector3(2.0, 0.0, 5.0), Vector3.ZERO, 100.0, 0)

    assert_eq(_fire(-1), 0, "cách tia 5m thì không trúng")
    assert_eq(_swarm._healths[0], 100.0)


func test_muc_tieu_ngoai_tam_khong_dinh() -> void:
    _swarm.spawn(Vector3(50.0, 0.0, 0.0), Vector3.ZERO, 100.0, 0)

    assert_eq(_fire(-1), 0, "tia dài 30m không với tới 50m")


func test_diem_cuoi_tia_bang_dung_tam_khi_khong_co_tuong() -> void:
    _fire(0)
    assert_almost_eq(_hitscan.get_end_point().x, 30.0, 0.001, "tia đi hết tầm")


func test_giet_muc_tieu_va_van_tieu_dung_pierce() -> void:
    _swarm.spawn(Vector3(1.0, 0.0, 0.0), Vector3.ZERO, 3.0, 0)
    _swarm.spawn(Vector3(2.0, 0.0, 0.0), Vector3.ZERO, 3.0, 0)
    _swarm.spawn(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 100.0, 0)

    assert_eq(_fire(1, 5.0), 2, "hai mục tiêu đầu bị tính là trúng")
    assert_eq(_swarm.get_alive_count(), 1, "hai con máu mỏng chết")


func test_ban_vao_khoang_khong_khong_loi() -> void:
    assert_eq(_fire(-1), 0, "không có mục tiêu thì không trúng gì")
    assert_eq(_hitscan.get_hit_count(), 0)


func test_khong_co_swarm_manager_van_an_toan() -> void:
    var count: int = _hitscan.fire(
        null, Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 30.0, 5.0,
        DamageTypes.Type.ENERGY, 0, null, null
    )
    assert_eq(count, 0, "thiếu SwarmManager thì tia vẫn bắn được, chỉ là không trúng ai")
