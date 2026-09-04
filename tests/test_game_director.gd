extends GutTest

## Kiểm tra máy trạng thái của GameDirector theo docs/02-TDD.md §4.1.
## Dùng instance riêng (không add vào cây scene) để cô lập khỏi autoload
## GameDirector thật và khỏi việc tải scene bất đồng bộ thật sự — chỉ kiểm tra
## logic thuần tuý của máy trạng thái (is_transition_allowed/request_state).
##
## Ghi chú: dùng `:=` (không phải `: GDScript`) cho hằng số preload bên dưới
## là chủ ý — cách này giữ lại kiểu cụ thể của script để các lời gọi
## `_director.get_state()`, `.request_state()`, `.is_transition_allowed()`
## được kiểm tra kiểu tĩnh đầy đủ, thay vì suy biến về `Variant`.
const GameDirectorScript := preload("res://src/autoload/game_director.gd")

var _director: GameDirectorScript


func before_each() -> void:
    _director = GameDirectorScript.new()


func after_each() -> void:
    if _director != null:
        _director.free()
        _director = null


func test_trang_thai_khoi_tao_la_boot() -> void:
    assert_eq(_director.get_state(), GameDirectorScript.State.BOOT,
            "trạng thái khởi tạo phải là BOOT")


func test_is_transition_allowed_dung_voi_moi_canh_hop_le() -> void:
    var canh_hop_le: Array = [
        [GameDirectorScript.State.BOOT, GameDirectorScript.State.MAIN_MENU],
        [GameDirectorScript.State.MAIN_MENU, GameDirectorScript.State.HANGAR],
        [GameDirectorScript.State.HANGAR, GameDirectorScript.State.LOADOUT],
        [GameDirectorScript.State.LOADOUT, GameDirectorScript.State.HANGAR],
        [GameDirectorScript.State.HANGAR, GameDirectorScript.State.MISSION_LOADING],
        [GameDirectorScript.State.LOADOUT, GameDirectorScript.State.MISSION_LOADING],
        [GameDirectorScript.State.MISSION_LOADING, GameDirectorScript.State.MISSION_ACTIVE],
        [GameDirectorScript.State.MISSION_ACTIVE, GameDirectorScript.State.MISSION_DEBRIEF],
        [GameDirectorScript.State.MISSION_ACTIVE, GameDirectorScript.State.MISSION_FAILED],
        [GameDirectorScript.State.MISSION_DEBRIEF, GameDirectorScript.State.HANGAR],
        [GameDirectorScript.State.MISSION_FAILED, GameDirectorScript.State.HANGAR],
    ]
    for canh: Array in canh_hop_le:
        var tu: GameDirectorScript.State = canh[0]
        var den: GameDirectorScript.State = canh[1]
        assert_true(_director.is_transition_allowed(tu, den),
                "phải cho phép chuyển %s → %s" % [tu, den])


func test_is_transition_allowed_chan_moi_canh_khong_hop_le() -> void:
    var canh_khong_hop_le: Array = [
        [GameDirectorScript.State.BOOT, GameDirectorScript.State.HANGAR],
        [GameDirectorScript.State.BOOT, GameDirectorScript.State.LOADOUT],
        [GameDirectorScript.State.MAIN_MENU, GameDirectorScript.State.LOADOUT],
        [GameDirectorScript.State.MAIN_MENU, GameDirectorScript.State.BOOT],
        [GameDirectorScript.State.HANGAR, GameDirectorScript.State.MAIN_MENU],
        [GameDirectorScript.State.HANGAR, GameDirectorScript.State.MISSION_ACTIVE],
        [GameDirectorScript.State.LOADOUT, GameDirectorScript.State.MISSION_ACTIVE],
        [GameDirectorScript.State.MISSION_LOADING, GameDirectorScript.State.MISSION_DEBRIEF],
        [GameDirectorScript.State.MISSION_LOADING, GameDirectorScript.State.HANGAR],
        [GameDirectorScript.State.MISSION_ACTIVE, GameDirectorScript.State.HANGAR],
        [GameDirectorScript.State.MISSION_ACTIVE, GameDirectorScript.State.MISSION_LOADING],
        [GameDirectorScript.State.MISSION_DEBRIEF, GameDirectorScript.State.MISSION_ACTIVE],
        [GameDirectorScript.State.MISSION_FAILED, GameDirectorScript.State.MISSION_ACTIVE],
    ]
    for canh: Array in canh_khong_hop_le:
        var tu: GameDirectorScript.State = canh[0]
        var den: GameDirectorScript.State = canh[1]
        assert_false(_director.is_transition_allowed(tu, den),
                "không được phép chuyển %s → %s" % [tu, den])


func test_request_state_hop_le_cap_nhat_trang_thai_va_phat_signal() -> void:
    watch_signals(_director)
    var ok: bool = _director.request_state(GameDirectorScript.State.MAIN_MENU)
    assert_true(ok, "chuyển BOOT → MAIN_MENU phải hợp lệ")
    assert_eq(_director.get_state(), GameDirectorScript.State.MAIN_MENU,
            "trạng thái phải cập nhật thành MAIN_MENU")
    # assert_signal_emitted_with_parameters(p1, p2, p3=params, p4=index) — KHÔNG có
    # tham số thông điệp; truyền chuỗi vào đây sẽ bị hiểu là index và làm GUT lỗi.
    assert_signal_emitted_with_parameters(_director, "state_changed",
            [GameDirectorScript.State.BOOT, GameDirectorScript.State.MAIN_MENU])


func test_request_state_khong_hop_le_bi_chan_va_giu_nguyen_trang_thai() -> void:
    watch_signals(_director)
    var ok: bool = _director.request_state(GameDirectorScript.State.HANGAR)
    assert_false(ok, "chuyển BOOT → HANGAR phải bị chặn (bỏ qua MAIN_MENU)")
    assert_eq(_director.get_state(), GameDirectorScript.State.BOOT,
            "trạng thái phải giữ nguyên BOOT khi chuyển không hợp lệ")
    assert_signal_not_emitted(_director, "state_changed",
            "không được phát state_changed khi chuyển bị chặn")


func test_chuoi_chuyen_trang_thai_qua_hangar_loadout_hai_chieu() -> void:
    assert_true(_director.request_state(GameDirectorScript.State.MAIN_MENU),
            "BOOT → MAIN_MENU phải hợp lệ")
    assert_true(_director.request_state(GameDirectorScript.State.HANGAR),
            "MAIN_MENU → HANGAR phải hợp lệ")
    assert_eq(_director.get_state(), GameDirectorScript.State.HANGAR,
            "phải tới được HANGAR qua MAIN_MENU")
    assert_true(_director.request_state(GameDirectorScript.State.LOADOUT),
            "HANGAR → LOADOUT phải hợp lệ")
    assert_true(_director.request_state(GameDirectorScript.State.HANGAR),
            "LOADOUT → HANGAR phải hợp lệ (chuyển hai chiều HANGAR ⇄ LOADOUT)")


func test_chuoi_nhiem_vu_that_bai_van_ve_duoc_hangar() -> void:
    _director.request_state(GameDirectorScript.State.MAIN_MENU)
    _director.request_state(GameDirectorScript.State.HANGAR)
    _director.request_state(GameDirectorScript.State.MISSION_LOADING)
    assert_true(_director.request_state(GameDirectorScript.State.MISSION_ACTIVE),
            "MISSION_LOADING → MISSION_ACTIVE phải hợp lệ")
    assert_true(_director.request_state(GameDirectorScript.State.MISSION_FAILED),
            "MISSION_ACTIVE → MISSION_FAILED phải hợp lệ")
    assert_true(_director.request_state(GameDirectorScript.State.HANGAR),
            "MISSION_FAILED → HANGAR phải hợp lệ")
    assert_eq(_director.get_state(), GameDirectorScript.State.HANGAR,
            "phải quay lại HANGAR sau khi nhiệm vụ thất bại")


func test_get_state_tra_ve_dung_gia_tri_hien_tai() -> void:
    _director.request_state(GameDirectorScript.State.MAIN_MENU)
    assert_eq(_director.get_state(), GameDirectorScript.State.MAIN_MENU,
            "get_state() phải phản ánh trạng thái vừa chuyển tới")
