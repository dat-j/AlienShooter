extends GutTest

## Kiểm tra SpatialHashGrid — chèn, xoá, di chuyển, truy vấn bán kính và
## truy vấn ô lân cận. Xem docs/05-BACKLOG.md T-301.

var _grid: SpatialHashGrid


func before_each() -> void:
    _grid = SpatialHashGrid.new(2.0)


func test_insert_roi_query_radius_tim_thay_id() -> void:
    _grid.insert(1, Vector3(0.0, 0.0, 0.0))
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(8)
    var count: int = _grid.query_radius(Vector3(0.0, 0.0, 0.0), 1.0, out)
    assert_eq(count, 1, "phải tìm thấy đúng 1 id trong bán kính 1m")
    assert_eq(out[0], 1, "id tìm thấy phải là id vừa chèn")


func test_query_radius_bo_qua_id_ngoai_ban_kinh() -> void:
    _grid.insert(1, Vector3(0.0, 0.0, 0.0))
    _grid.insert(2, Vector3(50.0, 0.0, 50.0))
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(8)
    var count: int = _grid.query_radius(Vector3(0.0, 0.0, 0.0), 5.0, out)
    assert_eq(count, 1, "id ở xa 70m không được nằm trong bán kính 5m")


func test_query_radius_qua_nhieu_o() -> void:
    # Ô 2m: đặt các id rải rác qua nhiều ô để đảm bảo vòng lặp ô hoạt động.
    _grid.insert(1, Vector3(-3.0, 0.0, -3.0))
    _grid.insert(2, Vector3(3.0, 0.0, 3.0))
    _grid.insert(3, Vector3(0.0, 0.0, 0.0))
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(8)
    var count: int = _grid.query_radius(Vector3(0.0, 0.0, 0.0), 10.0, out)
    assert_eq(count, 3, "bán kính 10m phải phủ cả 3 ô khác nhau")


func test_move_cap_nhat_vi_tri_va_chuyen_o() -> void:
    _grid.insert(1, Vector3(0.0, 0.0, 0.0))
    _grid.move(1, Vector3(20.0, 0.0, 20.0))
    var out_old: PackedInt32Array = PackedInt32Array()
    out_old.resize(8)
    var count_old: int = _grid.query_radius(Vector3(0.0, 0.0, 0.0), 1.0, out_old)
    assert_eq(count_old, 0, "sau khi move, vị trí cũ không còn id nào")
    var out_new: PackedInt32Array = PackedInt32Array()
    out_new.resize(8)
    var count_new: int = _grid.query_radius(Vector3(20.0, 0.0, 20.0), 1.0, out_new)
    assert_eq(count_new, 1, "sau khi move, vị trí mới phải tìm thấy id")


func test_move_trong_cung_mot_o_khong_lam_mat_id() -> void:
    _grid.insert(1, Vector3(0.1, 0.0, 0.1))
    _grid.move(1, Vector3(0.2, 0.0, 0.2))
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(8)
    var count: int = _grid.query_radius(Vector3(0.2, 0.0, 0.2), 1.0, out)
    assert_eq(count, 1, "di chuyển nhỏ trong cùng ô vẫn phải giữ được id")


func test_remove_xoa_hoan_toan_id() -> void:
    _grid.insert(1, Vector3(0.0, 0.0, 0.0))
    _grid.remove(1)
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(8)
    var count: int = _grid.query_radius(Vector3(0.0, 0.0, 0.0), 5.0, out)
    assert_eq(count, 0, "id đã remove không được xuất hiện trong query")
    assert_eq(_grid.get_entity_count(), 0, "số thực thể phải về 0 sau remove")


func test_remove_id_khong_ton_tai_khong_gay_loi() -> void:
    _grid.remove(999)
    assert_eq(_grid.get_entity_count(), 0, "remove id chưa từng chèn phải là no-op an toàn")


func test_query_cell_neighbours_lay_dung_khoi_3x3() -> void:
    _grid.insert(1, Vector3(0.0, 0.0, 0.0))       # ô (0,0)
    _grid.insert(2, Vector3(2.5, 0.0, 0.0))       # ô (1,0) — lân cận
    _grid.insert(3, Vector3(100.0, 0.0, 100.0))   # ô rất xa — không phải lân cận
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(16)
    var count: int = _grid.query_cell_neighbours(Vector3(0.0, 0.0, 0.0), out)
    assert_eq(count, 2, "khối 3x3 quanh gốc phải chứa đúng 2 id gần")


func test_clear_xoa_sach_du_lieu() -> void:
    _grid.insert(1, Vector3(0.0, 0.0, 0.0))
    _grid.insert(2, Vector3(2.5, 0.0, 0.0))
    _grid.clear()
    assert_eq(_grid.get_entity_count(), 0, "clear phải đưa số thực thể về 0")
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(8)
    var count: int = _grid.query_radius(Vector3(0.0, 0.0, 0.0), 100.0, out)
    assert_eq(count, 0, "clear phải làm mọi truy vấn trả về rỗng")


func test_query_radius_khong_ghi_vuot_suc_chua_out() -> void:
    for i: int in range(5):
        _grid.insert(i, Vector3(float(i) * 0.1, 0.0, 0.0))
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(2)
    var count: int = _grid.query_radius(Vector3(0.0, 0.0, 0.0), 5.0, out)
    assert_eq(count, 5, "tổng số tìm thấy phải đúng dù out nhỏ hơn")
    assert_eq(out.size(), 2, "hàm không được resize out của người gọi")


func test_insert_lap_lai_cung_id_duoc_xu_ly_nhu_move() -> void:
    _grid.insert(1, Vector3(0.0, 0.0, 0.0))
    _grid.insert(1, Vector3(30.0, 0.0, 30.0))
    assert_eq(_grid.get_entity_count(), 1, "insert lại cùng id không được tạo bản ghi trùng")
    var out: PackedInt32Array = PackedInt32Array()
    out.resize(4)
    var count: int = _grid.query_radius(Vector3(30.0, 0.0, 30.0), 1.0, out)
    assert_eq(count, 1, "insert lại cùng id phải cập nhật vị trí mới")
