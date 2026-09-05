extends GutTest

## T-601 · T-602 · T-603 — JuiceDirector.
##
## `Engine.time_scale` là trạng thái toàn cục: mọi bài phải trả nó về 1.0,
## nếu không cả bộ test sau đó chạy ở tốc độ 5%.

const EPSILON: float = 0.0001


func before_each() -> void:
    JuiceDirector.reset()
    SettingsManager.reset_all(false)


func after_each() -> void:
    JuiceDirector.reset()


func after_all() -> void:
    Engine.time_scale = 1.0


# --- T-601: API và thanh trượt trợ năng ---------------------------------

func test_du_bon_kenh_cua_api() -> void:
    JuiceDirector.shake(0.2, 0.1)
    JuiceDirector.hitstop(0.05)
    JuiceDirector.rumble(0.5, 1.0, 0.1)
    JuiceDirector.chromatic(0.4)

    assert_gt(JuiceDirector.get_total_amplitude(), 0.0, "shake() có tác dụng")
    assert_true(JuiceDirector.is_hitstopped(), "hitstop() có tác dụng")
    assert_almost_eq(JuiceDirector.get_chromatic_amount(), 0.4, EPSILON, "chromatic() có tác dụng")


func test_thanh_truot_tro_nang_nhan_vao_bien_do_rung() -> void:
    SettingsManager.set_value(&"accessibility", &"screen_shake", 0.5)
    JuiceDirector.shake(0.4, 1.0)
    assert_almost_eq(JuiceDirector.get_total_amplitude(), 0.2, EPSILON, "0.4 × thanh trượt 0.5")


func test_tat_rung_man_hinh_thi_camera_dung_yen() -> void:
    SettingsManager.set_value(&"accessibility", &"screen_shake", 0.0)
    JuiceDirector.shake(0.45, 1.0)
    JuiceDirector._process(0.016)

    assert_eq(JuiceDirector.get_total_amplitude(), 0.0)
    assert_eq(JuiceDirector.get_shake_offset(), Vector3.ZERO, "tắt là tắt hẳn")


func test_tat_hitstop_duoc_qua_tro_nang() -> void:
    SettingsManager.set_value(&"accessibility", &"hitstop", 0.0)
    JuiceDirector.hitstop(0.2)

    assert_false(JuiceDirector.is_hitstopped(), "tắt hitstop thì không đóng băng")
    assert_eq(Engine.time_scale, 1.0)


func test_tat_quang_sai_mau_duoc_qua_tro_nang() -> void:
    SettingsManager.set_value(&"accessibility", &"chromatic_aberration", 0.0)
    JuiceDirector.chromatic(1.0)
    assert_eq(JuiceDirector.get_chromatic_amount(), 0.0)


func test_nhieu_lenh_rung_cong_don_chu_khong_ghi_de() -> void:
    JuiceDirector.shake(0.10, 1.0)
    var one: float = JuiceDirector.get_total_amplitude()
    JuiceDirector.shake(0.10, 1.0)
    var two: float = JuiceDirector.get_total_amplitude()

    assert_eq(JuiceDirector.get_active_shake_count(), 2, "hai cú rung sống song song")
    assert_almost_eq(two, one * 2.0, EPSILON, "cú thứ hai CỘNG vào chứ không đè lên")


func test_bien_do_tong_co_tran_cung() -> void:
    for _i: int in range(JuiceDirector.MAX_SHAKES):
        JuiceDirector.shake(0.45, 1.0)
    assert_eq(
        JuiceDirector.get_total_amplitude(), JuiceDirector.MAX_TOTAL_AMPLITUDE,
        "rung chồng nhau không được hất camera khỏi trận đánh"
    )


func test_het_cho_thi_cu_manh_thay_cu_yeu() -> void:
    for _i: int in range(JuiceDirector.MAX_SHAKES):
        JuiceDirector.shake(0.05, 1.0)
    assert_eq(JuiceDirector.get_active_shake_count(), JuiceDirector.MAX_SHAKES)

    JuiceDirector.shake(0.45, 1.0)

    assert_eq(JuiceDirector.get_active_shake_count(), JuiceDirector.MAX_SHAKES, "không vượt trần slot")
    assert_gt(JuiceDirector.get_total_amplitude(), 0.05 * JuiceDirector.MAX_SHAKES,
        "cú mạnh phải chen được vào")


# --- T-601: bảng ART-BIBLE §9 -------------------------------------------

func test_play_chay_tron_mot_dong_cua_bang() -> void:
    assert_true(JuiceDirector.play(&"rail_lance"))
    assert_almost_eq(JuiceDirector.get_total_amplitude(), 0.30, EPSILON, "Rail Lance rung 0.30")
    assert_true(JuiceDirector.is_hitstopped(), "Rail Lance có hitstop 0.05s")


func test_diet_swarm_khong_rung_gi_ca() -> void:
    assert_true(JuiceDirector.play(&"swarm_killed"))
    assert_eq(JuiceDirector.get_total_amplitude(), 0.0, "diệt swarm lẻ không được rung")
    assert_false(JuiceDirector.is_hitstopped())


func test_nguoi_choi_bi_danh_keo_theo_quang_sai_mau() -> void:
    JuiceDirector.play(&"player_hit")
    assert_almost_eq(JuiceDirector.get_chromatic_amount(), 0.4, EPSILON, "bảng ghi CA 0.4")


func test_su_kien_la_thi_khong_lam_gi() -> void:
    assert_false(JuiceDirector.play(&"khong_co_trong_bang"))
    assert_eq(JuiceDirector.get_total_amplitude(), 0.0)


func test_bang_juice_phu_du_moi_dong_art_bible() -> void:
    var expected: Array[StringName] = [
        &"fire_light", &"fire_heavy", &"rail_lance", &"swarm_killed", &"actor_killed",
        &"boss_phase", &"player_hit", &"armor_broken", &"explosion_near",
    ]
    for id: StringName in expected:
        assert_true(JuiceDirector.EVENTS.has(id), "thiếu dòng %s của ART-BIBLE §9" % id)


# --- T-602: rung màn hình -----------------------------------------------

func test_rung_dung_nhieu_perlin_chu_khong_phai_ngau_nhien_trang() -> void:
    JuiceDirector.shake(0.5, 10.0)
    var samples: Array[Vector3] = []
    for _i: int in range(24):
        JuiceDirector._process(1.0 / 240.0)
        samples.append(JuiceDirector.get_shake_offset())

    # Nhiễu trắng nhảy loạn giữa hai frame liền kề; Perlin thì liên tục, nên
    # bước nhảy phải nhỏ hơn nhiều so với biên độ tổng.
    var max_step: float = 0.0
    for index: int in range(1, samples.size()):
        max_step = maxf(max_step, samples[index].distance_to(samples[index - 1]))
    assert_lt(max_step, 0.5, "quỹ đạo phải liên tục — đây là dấu hiệu của Perlin")


func test_rung_tat_dan_muot_roi_het_han() -> void:
    JuiceDirector.shake(0.4, 0.2)
    var start: float = JuiceDirector.get_total_amplitude()

    JuiceDirector._process(0.1)
    var middle: float = JuiceDirector.get_total_amplitude()
    assert_lt(middle, start, "đang tắt dần")
    assert_gt(middle, 0.0, "chưa tắt hẳn ở giữa chừng")

    JuiceDirector._process(0.15)
    assert_eq(JuiceDirector.get_active_shake_count(), 0, "hết thời gian thì mục bị thu hồi")
    assert_eq(JuiceDirector.get_shake_offset(), Vector3.ZERO)


func test_duong_tat_dan_di_tu_1_ve_0() -> void:
    assert_eq(JuiceDirector.decay_curve(0.0), 1.0, "đầu cú rung là mạnh nhất")
    assert_eq(JuiceDirector.decay_curve(1.0), 0.0, "hết giờ là im")
    assert_lt(JuiceDirector.decay_curve(0.5), 0.5, "bậc hai nên nửa sau êm hơn tuyến tính")


func test_qua_nhiet_rung_nen_lien_tuc_va_dung_khi_het() -> void:
    EventBus.overheat_started.emit()
    assert_almost_eq(
        JuiceDirector.get_total_amplitude(), JuiceDirector.OVERHEAT_AMPLITUDE, EPSILON,
        "ART-BIBLE §9: quá nhiệt rung 0.10 liên tục"
    )
    for _i: int in range(60):
        JuiceDirector._process(1.0 / 60.0)
    assert_gt(JuiceDirector.get_total_amplitude(), 0.0, "rung nền không tự tắt sau một giây")

    EventBus.overheat_ended.emit()
    assert_eq(JuiceDirector.get_total_amplitude(), 0.0, "hết quá nhiệt là hết rung")


func test_camera_cong_them_offset_chu_khong_thay_the_vi_tri_bam() -> void:
    var rig := CameraRig.new()
    rig.name = "CameraRig"
    var camera := Camera3D.new()
    camera.name = "Camera3D"
    rig.add_child(camera)
    var target := Node3D.new()
    add_child_autofree(target)
    target.add_child(rig)
    rig.target_path = NodePath("..")

    JuiceDirector.shake(0.4, 1.0)
    JuiceDirector._process(0.05)
    rig.update_follow(0.016)

    assert_ne(JuiceDirector.get_shake_offset(), Vector3.ZERO, "phải đang rung")
    assert_eq(
        rig.global_position, rig.get_follow_position() + JuiceDirector.get_shake_offset(),
        "camera = vị trí bám + offset rung của JuiceDirector"
    )


# --- T-603: hitstop -----------------------------------------------------

func test_hitstop_ha_time_scale_roi_tra_lai() -> void:
    JuiceDirector.hitstop(0.05)
    assert_eq(Engine.time_scale, JuiceDirector.HITSTOP_TIME_SCALE, "thế giới chậm lại")

    # Đếm bằng thời gian THẬT: _process nhận delta đã bị co, hàm tự chia lại.
    JuiceDirector._process(0.06 * JuiceDirector.HITSTOP_TIME_SCALE)

    assert_false(JuiceDirector.is_hitstopped())
    assert_eq(Engine.time_scale, 1.0, "phải trả time_scale về 1.0")


func test_nhieu_hitstop_lay_max_chu_khong_cong_don() -> void:
    JuiceDirector.hitstop(0.05)
    JuiceDirector.hitstop(0.05)
    JuiceDirector.hitstop(0.05)

    # Cộng dồn thì phải mất 0.15s; lấy max thì 0.06s là đủ.
    JuiceDirector._process(0.06 * JuiceDirector.HITSTOP_TIME_SCALE)
    assert_false(JuiceDirector.is_hitstopped(), "ba lệnh 0.05s không được thành 0.15s")


func test_hitstop_dai_bi_kep_ve_tran() -> void:
    JuiceDirector.hitstop(10.0)
    JuiceDirector._process((JuiceDirector.MAX_HITSTOP_SECONDS + 0.01) * JuiceDirector.HITSTOP_TIME_SCALE)
    assert_false(JuiceDirector.is_hitstopped(), "không lệnh nào được đóng băng game quá trần")


func test_hitstop_moi_gia_han_chu_khong_cat_ngan_cai_dang_chay() -> void:
    JuiceDirector.hitstop(0.20)
    JuiceDirector.hitstop(0.02)
    JuiceDirector._process(0.05 * JuiceDirector.HITSTOP_TIME_SCALE)
    assert_true(JuiceDirector.is_hitstopped(), "cú ngắn không được cắt ngang cú dài")


func test_thoi_gian_khong_co_gian_dung_bang_thoi_gian_that() -> void:
    Engine.time_scale = JuiceDirector.HITSTOP_TIME_SCALE
    assert_almost_eq(JuiceDirector.get_unscaled_delta(0.001), 0.02, EPSILON,
        "delta bị co 20 lần thì phải giãn lại đúng 20 lần")
    Engine.time_scale = 1.0
    assert_almost_eq(JuiceDirector.get_unscaled_delta(0.016), 0.016, EPSILON)


func test_rung_van_chay_khi_the_gioi_dang_dong_bang() -> void:
    JuiceDirector.shake(0.4, 0.5)
    JuiceDirector.hitstop(0.2)
    var before: float = JuiceDirector.get_total_amplitude()

    # Một frame thật 16ms trong lúc time_scale = 0.05.
    JuiceDirector._process(0.016 * JuiceDirector.HITSTOP_TIME_SCALE)

    assert_lt(JuiceDirector.get_total_amplitude(), before,
        "hitstop đóng băng thế giới, không đóng băng cú rung")


func test_reset_don_sach_moi_thu() -> void:
    JuiceDirector.shake(0.4, 5.0)
    JuiceDirector.hitstop(0.2)
    JuiceDirector.chromatic(1.0)
    EventBus.overheat_started.emit()

    JuiceDirector.reset()

    assert_eq(JuiceDirector.get_active_shake_count(), 0)
    assert_eq(JuiceDirector.get_total_amplitude(), 0.0)
    assert_eq(JuiceDirector.get_chromatic_amount(), 0.0)
    assert_false(JuiceDirector.is_hitstopped())
    assert_eq(Engine.time_scale, 1.0)


func test_quang_sai_mau_tu_tat_dan() -> void:
    JuiceDirector.chromatic(1.0)
    JuiceDirector._process(0.2)
    var middle: float = JuiceDirector.get_chromatic_amount()
    assert_lt(middle, 1.0)
    assert_gt(middle, 0.0)

    JuiceDirector._process(1.0)
    assert_eq(JuiceDirector.get_chromatic_amount(), 0.0, "không được kẹt lại trên màn hình")
