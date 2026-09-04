extends GutTest

## Kiểm tra ContentDB: index theo id, phát hiện trùng id, các getter, và quét
## đệ quy thư mục. Xem docs/05-BACKLOG.md T-008.
##
## Vì reload_all() quét res://data/ thật (theo hợp đồng CONTRACTS), phần lớn
## bài test dưới đây dùng một instance riêng của lớp ContentDBImpl (không phải
## autoload đang chạy) cùng ba tài nguyên giả, để kiểm tra logic index mà
## không phụ thuộc vào nội dung thật sẽ còn thay đổi theo thời gian.
## `ContentDBImpl` là class_name của script content_db.gd — khác với tên
## autoload `ContentDB` đăng ký trong project.godot, không xung đột.

var _db: ContentDBImpl


func before_each() -> void:
    _db = autofree(ContentDBImpl.new())


func test_index_hai_id_khac_nhau_tra_ve_dung_tai_nguyen() -> void:
    var a: WeaponData = WeaponData.new()
    a.id = &"wpn_fake_a"
    var b: WeaponData = WeaponData.new()
    b.id = &"wpn_fake_b"
    _db._index_resource(a, "res://fake/a.tres")
    _db._index_resource(b, "res://fake/b.tres")

    assert_eq(_db.get_weapon(&"wpn_fake_a"), a, "phải trả về đúng tài nguyên a theo id")
    assert_eq(_db.get_weapon(&"wpn_fake_b"), b, "phải trả về đúng tài nguyên b theo id")
    assert_eq(_db.get_count(&"weapon"), 2, "phải đếm đúng 2 vũ khí đã index")


func test_trung_id_giu_ban_dau_va_khong_ghi_de() -> void:
    var first: WeaponData = WeaponData.new()
    first.id = &"wpn_fake_dup"
    first.tier = 1
    var second: WeaponData = WeaponData.new()
    second.id = &"wpn_fake_dup"
    second.tier = 99

    _db._index_resource(first, "res://fake/first.tres")
    _db._index_resource(second, "res://fake/second.tres")

    assert_eq(_db.get_count(&"weapon"), 1, "trùng id không được thêm bản ghi thứ hai")
    assert_eq(_db.get_weapon(&"wpn_fake_dup").tier, 1, "bản ghi đầu tiên phải được giữ lại khi trùng id")


func test_id_khong_ton_tai_tra_ve_null() -> void:
    assert_null(_db.get_weapon(&"wpn_khong_ton_tai"), "id không tồn tại phải trả về null")


func test_get_all_enemies_for_chapter_loc_dung_chuong() -> void:
    var e1: EnemyData = EnemyData.new()
    e1.id = &"enm_fake_ch1"
    e1.chapter = 1
    var e2: EnemyData = EnemyData.new()
    e2.id = &"enm_fake_ch2"
    e2.chapter = 2
    _db._index_resource(e1, "res://fake/e1.tres")
    _db._index_resource(e2, "res://fake/e2.tres")

    var ch1_list: Array[EnemyData] = _db.get_all_enemies_for_chapter(1)
    assert_eq(ch1_list.size(), 1, "chỉ được 1 kẻ địch ở chương 1")
    assert_eq(ch1_list[0], e1, "phải là đúng kẻ địch chương 1 vừa thêm")


func test_get_count_category_khong_ro_tra_ve_0() -> void:
    assert_eq(_db.get_count(&"khong_ton_tai"), 0, "category không rõ phải trả về 0")


func test_is_loaded_mac_dinh_false_khi_chua_reload() -> void:
    assert_false(_db.is_loaded(), "is_loaded phải false trước khi reload_all chạy")


func test_scan_de_quy_tim_thay_file_tres_that_duoi_data() -> void:
    var files: Array[String] = []
    _db._collect_resource_files("res://data", files)
    assert_true(files.size() >= 10, "phải tìm thấy tối thiểu 10 file .tres mẫu đã tạo dưới res://data")
    var has_weapon_sample: bool = false
    for f: String in files:
        if f.ends_with("wpn_rail_lance.tres"):
            has_weapon_sample = true
    assert_true(has_weapon_sample, "phải tìm thấy wpn_rail_lance.tres qua quét đệ quy")


func test_autoload_that_nap_duoc_du_lieu_mau() -> void:
    assert_true(ContentDB.is_loaded(), "ContentDB autoload phải đã nạp xong sau khi project khởi động")
    assert_not_null(ContentDB.get_weapon(&"wpn_rail_lance"), "phải nạp được tài nguyên mẫu wpn_rail_lance.tres")
    assert_not_null(ContentDB.get_enemy(&"enm_crawler"), "phải nạp được tài nguyên mẫu enm_crawler.tres")
    assert_not_null(ContentDB.get_chassis(&"chs_ronin_m"), "phải nạp được tài nguyên mẫu chs_ronin_m.tres")
    assert_not_null(ContentDB.get_module(&"mod_heat_sink_array"), "phải nạp được tài nguyên mẫu mod_heat_sink_array.tres")
    assert_not_null(ContentDB.get_status_effect(&"eff_burning"), "phải nạp được tài nguyên mẫu eff_burning.tres")
    assert_not_null(ContentDB.get_mission(&"msn_ch1_purge"), "phải nạp được tài nguyên mẫu msn_ch1_purge.tres")
    assert_not_null(ContentDB.get_wave_table(&"wav_ch1"), "phải nạp được tài nguyên mẫu wav_ch1.tres")
    assert_not_null(ContentDB.get_loot_table(&"loot_ch1_standard"), "phải nạp được tài nguyên mẫu loot_ch1_standard.tres")
    assert_not_null(ContentDB.get_perk(&"prk_tactical_boost_charge"), "phải nạp được tài nguyên mẫu prk_tactical_boost_charge.tres")
    assert_not_null(ContentDB.get_room_module(&"room_ch1_small_01"), "phải nạp được tài nguyên mẫu room_ch1_small_01.tres")
