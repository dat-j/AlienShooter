extends GutTest

## Kiểm tra FlowField — tính Dijkstra từ mục tiêu ra ngoài, tường chặn
## đúng cost 255, không ô mồ côi, và nội suy song tuyến của
## sample_direction(). Xem docs/05-BACKLOG.md T-302, T-303.

const CELL_SIZE: float = 1.5
const GRID_CELLS: int = 6  # lưới 6x6 ô = 9m x 9m

var _field: FlowField


func before_each() -> void:
    _field = FlowField.new()
    var bounds: AABB = AABB(
        Vector3.ZERO, Vector3(float(GRID_CELLS) * CELL_SIZE, 1.0, float(GRID_CELLS) * CELL_SIZE)
    )
    _field.configure(bounds, CELL_SIZE)


func _cell_center_world(cx: int, cz: int) -> Vector3:
    return Vector3((float(cx) + 0.5) * CELL_SIZE, 0.0, (float(cz) + 0.5) * CELL_SIZE)


func test_get_cell_chuyen_doi_dung_toa_do() -> void:
    var cell: Vector2i = _field.get_cell(Vector3(2.2, 0.0, 4.6))
    assert_eq(cell, Vector2i(1, 3), "ô 1.5m tại (2.2, 4.6) phải là (1, 3)")


func test_rebuild_dat_khoang_cach_0_tai_o_muc_tieu() -> void:
    _field.rebuild(_cell_center_world(3, 3))
    var cells: Array = _field.get_debug_cells()
    var found: bool = false
    for entry: Dictionary in cells:
        if entry["cell"] == Vector2i(3, 3):
            assert_eq(entry["distance"], 0, "ô mục tiêu phải có distance = 0")
            found = true
    assert_true(found, "phải tìm thấy ô mục tiêu trong get_debug_cells()")


func test_moi_o_di_duoc_deu_co_huong_ve_dich_khi_luoi_mo() -> void:
    _field.rebuild(_cell_center_world(3, 3))
    var cells: Array = _field.get_debug_cells()
    for entry: Dictionary in cells:
        var cell: Vector2i = entry["cell"]
        if cell == Vector2i(3, 3):
            continue
        var direction: Vector2 = entry["direction"]
        assert_ne(
            direction,
            Vector2.ZERO,
            "ô (%d,%d) đi được trên lưới mở phải có hướng về đích" % [cell.x, cell.y]
        )
        assert_lt(entry["distance"], FlowField.DISTANCE_UNREACHABLE, "ô đi được không được là UNREACHABLE")


func test_o_tuong_co_cost_255_va_khong_co_huong() -> void:
    _field.set_cost(Vector2i(2, 2), 255)
    _field.rebuild(_cell_center_world(5, 5))
    var cells: Array = _field.get_debug_cells()
    for entry: Dictionary in cells:
        if entry["cell"] == Vector2i(2, 2):
            assert_eq(entry["cost"], 255, "ô đã set_cost 255 phải giữ nguyên cost tường")
            assert_eq(
                entry["direction"], Vector2.ZERO, "ô tường không được có hướng dẫn đường"
            )
            assert_eq(
                entry["distance"],
                FlowField.DISTANCE_UNREACHABLE,
                "ô tường không được có khoảng cách hợp lệ"
            )


func test_tuong_khong_chan_duong_di_vong_qua() -> void:
    # Dựng một bức tường có khe hở — ô ở phía xa mục tiêu vẫn phải có
    # hướng đi hợp lệ (đi vòng qua khe), không bị mồ côi.
    for cx: int in range(GRID_CELLS):
        if cx != 4:
            _field.set_cost(Vector2i(cx, 3), 255)
    _field.rebuild(_cell_center_world(0, 0))
    var cells: Array = _field.get_debug_cells()
    for entry: Dictionary in cells:
        var cell: Vector2i = entry["cell"]
        if cell == Vector2i(0, 0):
            continue
        if cell.y == 3 and cell.x != 4:
            continue  # chính ô tường, bỏ qua
        assert_ne(
            entry["direction"],
            Vector2.ZERO,
            "ô (%d,%d) phải đi vòng qua khe hở để tới mục tiêu" % [cell.x, cell.y]
        )


func test_is_walkable_dung_voi_o_tuong_va_o_thuong() -> void:
    _field.set_cost(Vector2i(1, 1), 255)
    assert_false(_field.is_walkable(_cell_center_world(1, 1)), "ô tường phải không đi được")
    assert_true(_field.is_walkable(_cell_center_world(0, 0)), "ô thường phải đi được")


func test_sample_direction_tra_ve_vector_chuan_hoa() -> void:
    _field.rebuild(_cell_center_world(5, 0))
    var sample: Vector2 = _field.sample_direction(_cell_center_world(0, 0))
    assert_almost_eq(sample.length(), 1.0, 0.01, "hướng nội suy phải là vector chuẩn hoá")
    assert_gt(sample.x, 0.0, "mục tiêu ở bên phải, hướng phải nghiêng theo +X")


func test_configure_reset_lai_toan_bo_du_lieu() -> void:
    _field.set_cost(Vector2i(0, 0), 255)
    _field.rebuild(_cell_center_world(3, 3))
    _field.configure(
        AABB(Vector3.ZERO, Vector3(float(GRID_CELLS) * CELL_SIZE, 1.0, float(GRID_CELLS) * CELL_SIZE)),
        CELL_SIZE
    )
    assert_true(_field.is_walkable(_cell_center_world(0, 0)), "configure lại phải đặt cost về mặc định")


func test_request_rebuild_hoan_thanh_qua_worker_thread() -> void:
    _field.request_rebuild(_cell_center_world(3, 3))
    var waited_msec: int = 0
    while waited_msec < 2000:
        await get_tree().create_timer(0.05).timeout
        waited_msec += 50
        _field.request_rebuild(_cell_center_world(3, 3))
        if _field.is_walkable(_cell_center_world(0, 0)) and _field.sample_direction(_cell_center_world(0, 0)) != Vector2.ZERO:
            break
    var sample: Vector2 = _field.sample_direction(_cell_center_world(0, 0))
    assert_ne(
        sample, Vector2.ZERO, "sau khi task nền hoàn thành, hướng đi phải được tính và hoán đổi vào"
    )
