extends GutTest

## T-107 — SettingsManager. TDD §14 bắt buộc test khứ hồi cho lớp lưu trữ.
## Mọi bài đều reset về mặc định trước và sau để không rò trạng thái sang
## bài khác (autoload sống suốt cả lần chạy test).

## ConfigFile khá dễ tính — rác thuần tuý vẫn nạp OK (đã đo). Chuỗi này có
## giá trị không phải biểu thức hợp lệ nên nó trả về ERR_PARSE_ERROR thật.
const CORRUPT_LINE: String = "[audio]\nmaster = @@@\n"


func before_each() -> void:
    SettingsManager.reset_all(false)


func after_all() -> void:
    SettingsManager.reset_all(false)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsManager.FILE_PATH))


func _write_raw(text: String) -> void:
    var file := FileAccess.open(SettingsManager.FILE_PATH, FileAccess.WRITE)
    file.store_string(text)
    file.close()


## ConfigFile in thẳng lỗi parse ra luồng lỗi của engine, và GUT mặc định coi
## mọi lỗi engine là test đỏ. Ở bài dưới, lỗi đó CHÍNH LÀ thứ đang được kiểm,
## nên đánh dấu đã xử lý. Chỉ gọi ngay sau đoạn code cố tình gây lỗi — gọi
## bừa sẽ nuốt mất lỗi thật.
func _mark_expected_errors_handled() -> int:
    var errors: Array = GutUtils.get_error_tracker().get_current_test_errors()
    for error: Object in errors:
        error.handled = true
    return errors.size()


# --- Mặc định -----------------------------------------------------------

func test_gia_tri_mac_dinh_co_du_moi_muc() -> void:
    for section: StringName in SettingsManager.DEFAULTS:
        var defaults: Dictionary = SettingsManager.DEFAULTS[section]
        for key: StringName in defaults:
            assert_eq(
                SettingsManager.get_value(section, key), defaults[key],
                "%s/%s phải có giá trị mặc định" % [section, key]
            )


func test_thieu_file_thi_dung_mac_dinh_chu_khong_no() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsManager.FILE_PATH))
    assert_false(SettingsManager.load_settings(), "không có file thì báo false")
    assert_eq(SettingsManager.get_value(&"accessibility", &"screen_shake"), 1.0)


func test_file_hong_thi_roi_ve_mac_dinh() -> void:
    SettingsManager.set_value(&"audio", &"master", 0.1)
    _write_raw(CORRUPT_LINE)

    var loaded: bool = SettingsManager.load_settings()
    assert_gt(_mark_expected_errors_handled(), 0, "engine phải kêu vì file hỏng thật")

    assert_false(loaded, "file hỏng thì báo false")
    assert_eq(SettingsManager.get_value(&"audio", &"master"), 1.0, "rơi về mặc định")


func test_khoa_sai_kieu_trong_file_bi_bo_qua_nhung_khoa_khac_van_song() -> void:
    var config := ConfigFile.new()
    config.set_value("audio", "master", "khong phai so")
    config.set_value("audio", "music", 0.25)
    config.save(SettingsManager.FILE_PATH)

    SettingsManager.load_settings()

    assert_eq(SettingsManager.get_value(&"audio", &"master"), 1.0, "khoá hỏng rơi về mặc định")
    assert_eq(SettingsManager.get_value(&"audio", &"music"), 0.25, "khoá lành vẫn được nạp")


# --- Khứ hồi ------------------------------------------------------------

func test_khu_hoi_qua_dia() -> void:
    SettingsManager.set_value(&"graphics", &"vsync", false)
    SettingsManager.set_value(&"audio", &"music", 0.33)
    SettingsManager.set_value(&"accessibility", &"screen_shake", 0.5)
    SettingsManager.set_value(&"accessibility", &"damage_numbers", false)
    assert_true(SettingsManager.save(), "ghi được xuống đĩa")

    SettingsManager.reset_all(false)
    assert_eq(SettingsManager.get_value(&"audio", &"music"), 0.7, "đã reset thật")

    assert_true(SettingsManager.load_settings())
    assert_false(SettingsManager.get_value(&"graphics", &"vsync"))
    assert_eq(SettingsManager.get_value(&"audio", &"music"), 0.33)
    assert_eq(SettingsManager.get_value(&"accessibility", &"screen_shake"), 0.5)
    assert_false(SettingsManager.get_value(&"accessibility", &"damage_numbers"))


# --- Hàng rào kiểu ------------------------------------------------------

func test_tu_choi_khoa_la() -> void:
    assert_false(SettingsManager.set_value(&"audio", &"khong_ton_tai", 1.0))


func test_tu_choi_sai_kieu() -> void:
    assert_false(SettingsManager.set_value(&"audio", &"master", "to len"))
    assert_eq(SettingsManager.get_value(&"audio", &"master"), 1.0, "giá trị cũ không bị phá")


func test_doi_gia_tri_thi_phat_settings_changed() -> void:
    watch_signals(EventBus)
    SettingsManager.set_value(&"audio", &"master", 0.4)
    assert_signal_emitted_with_parameters(EventBus, "settings_changed", [&"audio"])


func test_ghi_dung_gia_tri_cu_thi_khong_phat_tin_hieu() -> void:
    SettingsManager.set_value(&"audio", &"master", 0.4)
    watch_signals(EventBus)
    SettingsManager.set_value(&"audio", &"master", 0.4)
    assert_signal_not_emitted(EventBus, "settings_changed", "không đổi thì không báo")


# --- Trợ năng -----------------------------------------------------------

func test_thanh_truot_tro_nang_luon_nam_trong_0_1() -> void:
    SettingsManager.set_value(&"accessibility", &"screen_shake", 0.35)
    assert_almost_eq(SettingsManager.get_accessibility_scale(&"screen_shake"), 0.35, 0.0001)


func test_cong_tac_bat_tat_doc_ra_0_hoac_1() -> void:
    SettingsManager.set_value(&"accessibility", &"damage_numbers", false)
    assert_eq(SettingsManager.get_accessibility_scale(&"damage_numbers"), 0.0)
    SettingsManager.set_value(&"accessibility", &"damage_numbers", true)
    assert_eq(SettingsManager.get_accessibility_scale(&"damage_numbers"), 1.0)


# --- Preset đồ hoạ ------------------------------------------------------

func test_preset_thap_ha_tran_decal_va_tat_ik() -> void:
    SettingsManager.set_value(&"graphics", &"preset", "low")
    assert_eq(SettingsManager.get_value(&"graphics", &"decal_limit"), 40)
    assert_false(SettingsManager.get_value(&"graphics", &"leg_ik"))


func test_preset_cao_tra_lai_tran_decal_cua_tdd() -> void:
    SettingsManager.set_value(&"graphics", &"preset", "low")
    SettingsManager.set_value(&"graphics", &"preset", "high")
    assert_eq(SettingsManager.get_value(&"graphics", &"decal_limit"), 150, "TDD §12.7")


# --- Gán phím -----------------------------------------------------------

func test_khu_hoi_su_kien_ban_phim() -> void:
    var key := InputEventKey.new()
    key.physical_keycode = KEY_R
    var text: String = SettingsManager.serialize_event(key)
    var parsed := SettingsManager.parse_event(text) as InputEventKey

    assert_not_null(parsed, "chuỗi phím phải dựng lại được")
    assert_eq(parsed.physical_keycode, KEY_R)


func test_khu_hoi_su_kien_chuot_va_tay_cam() -> void:
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_RIGHT
    var parsed_mouse := SettingsManager.parse_event(SettingsManager.serialize_event(mouse)) as InputEventMouseButton
    assert_eq(parsed_mouse.button_index, MOUSE_BUTTON_RIGHT)

    var pad := InputEventJoypadButton.new()
    pad.button_index = JOY_BUTTON_X
    var parsed_pad := SettingsManager.parse_event(SettingsManager.serialize_event(pad)) as InputEventJoypadButton
    assert_eq(parsed_pad.button_index, JOY_BUTTON_X)


func test_chuoi_rac_khong_dung_thanh_su_kien() -> void:
    assert_null(SettingsManager.parse_event("rac"))
    assert_null(SettingsManager.parse_event("key:khongphaiso"))
    assert_null(SettingsManager.parse_event(""))


func test_gan_phim_di_thang_vao_input_map() -> void:
    var action: StringName = &"fire_left"
    var original: Array[InputEvent] = []
    for event: InputEvent in InputMap.action_get_events(action):
        original.append(event)

    var key := InputEventKey.new()
    key.physical_keycode = KEY_F
    assert_true(SettingsManager.set_binding(action, [key]))
    assert_eq(InputMap.action_get_events(action).size(), 1, "gán mới thay hết gán cũ")

    # Trả lại sơ đồ input gốc cho các bài khác (T-106).
    InputMap.action_erase_events(action)
    for event: InputEvent in original:
        InputMap.action_add_event(action, event)


func test_tu_choi_gan_phim_cho_action_khong_ton_tai() -> void:
    assert_false(SettingsManager.set_binding(&"action_khong_co_that", []))
