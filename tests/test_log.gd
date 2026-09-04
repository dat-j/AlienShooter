extends GutTest

## Kiểm tra Log: các cấp debug/info/warn/error và việc lọc theo cấp.
## Xem docs/05-BACKLOG.md T-005.


func before_each() -> void:
    Log.set_level(Log.Level.DEBUG)
    Log.clear_history()


func after_each() -> void:
    Log.set_level(Log.Level.DEBUG)
    Log.clear_history()


func test_cap_mac_dinh_la_debug() -> void:
    assert_eq(Log.get_level(), Log.Level.DEBUG, "cấp log mặc định phải là DEBUG")


func test_dat_va_doc_cap_thanh_cong() -> void:
    Log.set_level(Log.Level.WARN)
    assert_eq(Log.get_level(), Log.Level.WARN, "get_level phải trả về đúng cấp vừa đặt bằng set_level")


func test_loc_chan_thong_diep_duoi_cap_hien_tai() -> void:
    Log.set_level(Log.Level.WARN)
    Log.debug("thong diep debug phai bi chan")
    Log.info("thong diep info phai bi chan")
    assert_eq(Log.get_history().size(), 0, "debug/info phải bị lọc bỏ khi cấp hiện tại là WARN")


func test_loc_cho_qua_thong_diep_du_cap() -> void:
    Log.set_level(Log.Level.WARN)
    Log.warn("canh bao duoc ghi")
    Log.error("loi nghiem trong duoc ghi")
    assert_eq(Log.get_history().size(), 2, "warn/error phải được ghi khi cấp hiện tại là WARN")


func test_cap_none_chan_tat_ca_thong_diep() -> void:
    Log.set_level(Log.Level.NONE)
    Log.debug("a")
    Log.info("b")
    Log.warn("c")
    Log.error("d")
    assert_eq(Log.get_history().size(), 0, "cấp NONE phải chặn toàn bộ thông điệp ở mọi cấp")


func test_ca_bon_cap_deu_duoc_ghi_khi_cap_la_debug() -> void:
    Log.set_level(Log.Level.DEBUG)
    Log.debug("a")
    Log.info("b")
    Log.warn("c")
    Log.error("d")
    assert_eq(Log.get_history().size(), 4, "cả 4 cấp debug/info/warn/error phải được ghi khi cấp hiện tại là DEBUG")


func test_thong_diep_giu_dung_noi_dung_va_ngu_canh() -> void:
    Log.set_level(Log.Level.DEBUG)
    Log.info("xin chao he thong", "TestContext")
    var history: Array[String] = Log.get_history()
    assert_eq(history.size(), 1, "phải có đúng 1 dòng log sau một lời gọi info()")
    assert_true(history[0].find("xin chao he thong") != -1, "nội dung thông điệp phải xuất hiện trong dòng log")
    assert_true(history[0].find("TestContext") != -1, "ngữ cảnh truyền vào phải xuất hiện trong dòng log")


func test_clear_history_xoa_sach_lich_su() -> void:
    Log.info("thong diep truoc khi xoa")
    Log.clear_history()
    assert_eq(Log.get_history().size(), 0, "clear_history() phải xoá sạch lịch sử log")
