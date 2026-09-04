extends GutTest

## T-201 · T-202 · T-203 — nhiệt, quá nhiệt và xả nhiệt khẩn cấp.
## Số liệu theo docs/01-GDD.md §2. TDD §14 bắt buộc test cho HeatComponent.

var _heat: HeatComponent


func before_each() -> void:
    _heat = HeatComponent.new()
    _heat.chassis_data = load("res://data/chassis/chs_ronin_m.tres") as ChassisData
    add_child_autofree(_heat)


func test_overheat_locks_weapons_at_capacity() -> void:
    _heat.add_heat(100.0)
    assert_true(_heat.is_overheated(), "phải quá nhiệt ở mức 100")
    assert_eq(_heat.get_heat(), 100.0)
    assert_false(_heat.can_fire(), "quá nhiệt phải khoá cả hai vũ khí")
    assert_false(_heat.can_boost(), "quá nhiệt không được Boost")


func test_dissipation_slows_while_firing() -> void:
    _heat.add_heat(50.0)
    _heat.tick(1.0)   # vừa bắn xong → tản 40% của 12/s
    assert_almost_eq(_heat.get_heat(), 50.0 - 12.0 * 0.4, 0.01)


func test_dissipation_is_full_after_one_point_two_seconds() -> void:
    _heat.add_heat(50.0)
    for _i: int in range(13):
        _heat.tick(0.1)
    # 11 nhịp đầu còn trong cửa sổ 1.2s nên tản 40%; từ nhịp thứ 12 (mốc 1.2s)
    # trở đi tản đầy.
    var slow_phase: float = 12.0 * 0.4 * 1.1
    var full_phase: float = 12.0 * 0.2
    assert_almost_eq(_heat.get_heat(), 50.0 - slow_phase - full_phase, 0.05,
        "quá 1.2s không bắn thì tản nhiệt đầy 100%")


func test_environment_multiplier_scales_dissipation() -> void:
    _heat.environment_multiplier = 1.45      # khu vực đóng băng, GDD §2.3
    _heat.add_heat(50.0)
    _heat.tick(1.0)
    assert_almost_eq(_heat.get_heat(), 50.0 - 12.0 * 0.4 * 1.45, 0.01)


func test_warning_and_critical_thresholds_emit_both_ways() -> void:
    watch_signals(_heat)
    _heat.set_heat(85.0)
    assert_signal_emitted_with_parameters(_heat, "threshold_crossed", [80.0, true])
    _heat.set_heat(96.0)
    assert_signal_emitted_with_parameters(_heat, "threshold_crossed", [95.0, true])
    _heat.set_heat(85.0)
    assert_signal_emitted_with_parameters(_heat, "threshold_crossed", [95.0, false])
    _heat.set_heat(50.0)
    assert_signal_emitted_with_parameters(_heat, "threshold_crossed", [80.0, false])


func test_overheat_lasts_three_seconds_then_resets_heat_to_zero() -> void:
    watch_signals(_heat)
    _heat.add_heat(100.0)
    assert_signal_emitted(_heat, "overheat_started")
    _heat.tick(2.9)
    assert_true(_heat.is_overheated(), "chưa đủ 3.0s thì vẫn quá nhiệt")
    assert_eq(_heat.get_heat(), 100.0, "trong lúc quá nhiệt nhiệt không tự tụt")
    _heat.tick(0.2)
    assert_false(_heat.is_overheated())
    assert_eq(_heat.get_heat(), 0.0, "kết thúc quá nhiệt thì nhiệt về 0")
    assert_signal_emitted(_heat, "overheat_ended")


func test_overheat_applies_thirty_five_percent_speed_penalty() -> void:
    _heat.add_heat(100.0)
    assert_almost_eq(_heat.get_move_speed_multiplier(), 0.65, 0.001, "−35% tốc độ khi quá nhiệt")
    _heat.tick(3.1)
    assert_almost_eq(_heat.get_move_speed_multiplier(), 1.0, 0.001)


func test_overheat_does_not_retrigger_while_active() -> void:
    watch_signals(_heat)
    _heat.add_heat(100.0)
    _heat.add_heat(50.0)
    _heat.tick(1.0)
    assert_signal_emit_count(_heat, "overheat_started", 1, "không được kích hoạt quá nhiệt lặp")


func test_vent_removes_sixty_heat_after_holding_zero_point_eight_seconds() -> void:
    watch_signals(_heat)
    _heat.set_heat(90.0)
    for _i: int in range(7):
        _heat.update_vent(true, 0.1)
    assert_true(_heat.is_venting(), "giữ 0.7s thì vẫn đang xả, chưa xong")
    assert_eq(_heat.get_heat(), 90.0)
    _heat.update_vent(true, 0.1)
    assert_eq(_heat.get_heat(), 30.0, "đủ 0.8s thì trừ 60 nhiệt")
    assert_signal_emitted(_heat, "vent_completed")
    assert_almost_eq(_heat.get_vent_cooldown_remaining(), 12.0, 0.001, "hồi chiêu 12s")


func test_vent_cancelled_by_releasing_key_keeps_heat_and_cooldown() -> void:
    watch_signals(_heat)
    _heat.set_heat(90.0)
    _heat.update_vent(true, 0.5)
    _heat.update_vent(false, 0.1)
    assert_false(_heat.is_venting(), "nhả phím phải huỷ xả nhiệt")
    assert_eq(_heat.get_heat(), 90.0, "huỷ giữa chừng thì không trừ nhiệt")
    assert_eq(_heat.get_vent_cooldown_remaining(), 0.0, "huỷ thì không mất hồi chiêu")
    assert_signal_emitted(_heat, "vent_cancelled")


func test_vent_locks_movement_and_raises_damage_taken() -> void:
    _heat.set_heat(90.0)
    _heat.update_vent(true, 0.2)
    assert_eq(_heat.get_move_speed_multiplier(), 0.0, "đang xả thì mech đứng yên")
    assert_almost_eq(_heat.get_damage_taken_multiplier(), 1.3, 0.001, "+30% sát thương khi xả")
    _heat.update_vent(false, 0.1)
    assert_almost_eq(_heat.get_damage_taken_multiplier(), 1.0, 0.001)


func test_vent_blocked_while_on_cooldown() -> void:
    _heat.set_heat(90.0)
    _heat.update_vent(true, 0.8)
    assert_eq(_heat.get_heat(), 30.0)
    _heat.update_vent(false, 0.1)
    _heat.set_heat(90.0)
    _heat.update_vent(true, 0.8)
    assert_eq(_heat.get_heat(), 90.0, "còn hồi chiêu thì không xả được")
    _heat.tick(12.0)              # 12s này cũng tản hết nhiệt, nên nạp lại
    _heat.set_heat(90.0)
    _heat.update_vent(true, 0.8)
    assert_eq(_heat.get_heat(), 30.0, "hết hồi chiêu thì xả lại được")
