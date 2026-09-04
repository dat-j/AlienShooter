extends GutTest

## T-207 · T-204 — trạng thái bất lợi (GDD §9) và vùng môi trường (GDD §2.3).

const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")

var _status: StatusComponent


func before_each() -> void:
    _status = StatusComponent.new()
    add_child_autofree(_status)


func _effect(id: String) -> StatusEffectData:
    return load("res://data/status_effects/%s.tres" % id) as StatusEffectData


func test_all_six_gdd_statuses_exist_with_correct_numbers() -> void:
    var burning := _effect("eff_burning")
    assert_eq(burning.duration_seconds, 4.0, "Burning kéo dài 4s")
    assert_eq(burning.damage_per_second, 12.0, "Burning 12 sát thương/s")
    assert_eq(burning.max_stacks, 3, "Burning cộng dồn tối đa 3")
    var shocked := _effect("eff_shocked")
    assert_eq(shocked.duration_seconds, 2.5)
    assert_almost_eq(shocked.move_speed_multiplier, 0.6, 0.001, "Shocked −40% tốc độ")
    assert_true(shocked.prevents_attack, "Shocked không tấn công được")
    var frozen := _effect("eff_frozen")
    assert_almost_eq(frozen.move_speed_multiplier, 0.3, 0.001, "Frozen −70% tốc độ")
    assert_eq(frozen.breaks_on_single_hit_damage, 50.0, "Frozen vỡ khi chịu >50 một lần")
    var corroded := _effect("eff_corroded")
    assert_almost_eq(corroded.armor_effectiveness_multiplier, 0.75, 0.001, "Corroded −25% giáp")
    assert_eq(corroded.duration_seconds, 6.0)
    var marked := _effect("eff_marked")
    assert_almost_eq(marked.damage_taken_multiplier, 1.2, 0.001, "Marked +20% sát thương nhận vào")
    var slowed := _effect("eff_slowed")
    assert_almost_eq(slowed.move_speed_multiplier, 0.5, 0.001, "Slowed −50% tốc độ")


func test_apply_and_expire() -> void:
    watch_signals(_status)
    _status.apply(_effect("eff_shocked"))
    assert_true(_status.has_status(&"eff_shocked"))
    assert_signal_emitted_with_parameters(_status, "status_applied", [&"eff_shocked", 1])
    _status.tick(2.4)
    assert_true(_status.has_status(&"eff_shocked"), "chưa hết 2.5s thì vẫn còn")
    _status.tick(0.2)
    assert_false(_status.has_status(&"eff_shocked"), "hết hạn phải tự gỡ")
    assert_signal_emitted_with_parameters(_status, "status_removed", [&"eff_shocked"])


func test_stacking_is_capped_and_refreshes_duration() -> void:
    var burning := _effect("eff_burning")
    for _i: int in range(5):
        _status.apply(burning)
    assert_eq(_status.get_stacks(&"eff_burning"), 3, "Burning cộng dồn tối đa 3 tầng")
    _status.tick(3.0)
    _status.apply(burning)
    assert_almost_eq(_status.get_remaining(&"eff_burning"), 4.0, 0.001, "áp lại làm mới thời gian")


func test_damage_over_time_scales_with_stacks_and_is_only_reported() -> void:
    watch_signals(_status)
    var burning := _effect("eff_burning")
    _status.apply(burning)
    _status.apply(burning)
    _status.tick(0.5)
    var params: Array = get_signal_parameters(_status, "damage_over_time")
    assert_almost_eq(params[0] as float, 12.0 * 2.0 * 0.5, 0.001, "2 tầng × 12 dps × 0.5s")
    assert_eq(params[1], DamageTypes.Type.FIRE, "Burning là sát thương lửa")


func test_multipliers_stack_multiplicatively() -> void:
    _status.apply(_effect("eff_shocked"))     # ×0.6
    _status.apply(_effect("eff_slowed"))      # ×0.5
    assert_almost_eq(_status.get_move_speed_multiplier(), 0.3, 0.001, "hai trạng thái chậm nhân dồn")
    assert_false(_status.can_attack(), "Shocked chặn tấn công")
    _status.apply(_effect("eff_marked"))
    assert_almost_eq(_status.get_damage_taken_multiplier(), 1.2, 0.001)
    _status.apply(_effect("eff_corroded"))
    assert_almost_eq(_status.get_armor_effectiveness_multiplier(), 0.75, 0.001)


func test_frozen_breaks_on_a_big_single_hit() -> void:
    _status.apply(_effect("eff_frozen"))
    var broken: Array[StringName] = _status.on_single_hit(40.0)
    assert_eq(broken.size(), 0, "40 sát thương chưa đủ làm vỡ băng")
    assert_true(_status.has_status(&"eff_frozen"))
    broken = _status.on_single_hit(51.0)
    assert_eq(broken, [&"eff_frozen"] as Array[StringName], "hơn 50 một lần thì vỡ tan")
    assert_false(_status.has_status(&"eff_frozen"))


func test_immunity_blocks_application() -> void:
    _status.immune_status = [&"eff_burning"] as Array[StringName]
    assert_eq(_status.apply(_effect("eff_burning")), 0, "miễn nhiễm thì không áp được")
    assert_false(_status.has_status(&"eff_burning"))


func test_status_slows_the_mech_in_the_arena() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    mech.status_component.apply(_effect("eff_slowed"))
    for _i: int in range(60):
        mech.apply_movement(Vector2(0.0, -1.0), 1.0 / 60.0)
    assert_almost_eq(mech.velocity.z, -3.0, 0.05, "Slowed −50% thì tốc độ tối đa còn 3.0 m/s")


# --- T-204: vùng môi trường ---------------------------------------------

func test_environment_zone_sets_and_restores_dissipation_multiplier() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    var zone := EnvironmentZone.new()
    zone.dissipation_multiplier = 1.45          # khu vực đóng băng
    add_child_autofree(zone)
    zone._on_body_entered(mech)
    assert_almost_eq(mech.heat_component.environment_multiplier, 1.45, 0.001,
        "vào vùng lạnh thì tản nhiệt nhanh hơn")
    zone._on_body_exited(mech)
    assert_almost_eq(mech.heat_component.environment_multiplier, 1.0, 0.001,
        "ra khỏi vùng thì về mức chuẩn")


func test_environment_zone_ignores_non_mech_bodies() -> void:
    var zone := EnvironmentZone.new()
    zone.dissipation_multiplier = 0.65
    add_child_autofree(zone)
    var other: Node3D = add_child_autofree(Node3D.new()) as Node3D
    zone._on_body_entered(other)
    pass_test("vật thể không phải mech không làm vùng môi trường lỗi")
