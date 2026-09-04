extends GutTest

## T-205 · T-206 · T-208 — Boost, bốn vùng giáp, và ba khung mech.
## Số liệu theo docs/01-GDD.md §3, §4, §5.

const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")
const ARENA_SCENE: PackedScene = preload("res://scenes/main/test_arena.tscn")

var _chassis: ChassisData


func before_each() -> void:
    _chassis = load("res://data/chassis/chs_ronin_m.tres") as ChassisData


func _make_boost() -> BoostComponent:
    var boost := BoostComponent.new()
    boost.chassis_data = _chassis
    add_child_autofree(boost)
    return boost


func _make_heat() -> HeatComponent:
    var heat := HeatComponent.new()
    heat.chassis_data = _chassis
    add_child_autofree(heat)
    return heat


func _make_armor() -> ArmorComponent:
    var armor := ArmorComponent.new()
    armor.chassis_data = _chassis
    add_child_autofree(armor)
    return armor


# --- T-205: Boost -------------------------------------------------------

func test_dash_covers_seven_metres_in_zero_point_one_eight_seconds() -> void:
    var boost := _make_boost()
    assert_true(boost.try_start(Vector3.FORWARD, null, Vector3.ZERO))
    assert_almost_eq(boost.get_dash_velocity().length(), 7.0 / 0.18, 0.01,
        "7.0m trong 0.18s")


func test_iframe_window_is_zero_point_one_two_in_the_middle() -> void:
    var boost := _make_boost()
    boost.try_start(Vector3.FORWARD, null, Vector3.ZERO)
    boost.update(0.02, Vector3.ZERO, true)
    assert_false(boost.is_invulnerable(), "đầu cú lướt chưa bất tử")
    boost.update(0.05, Vector3.ZERO, true)
    assert_true(boost.is_invulnerable(), "giữa cú lướt phải có i-frame")
    boost.update(0.09, Vector3.ZERO, true)
    assert_false(boost.is_invulnerable(), "cuối cú lướt hết bất tử")


func test_boost_costs_fifteen_heat() -> void:
    var boost := _make_boost()
    var heat := _make_heat()
    boost.try_start(Vector3.FORWARD, heat, Vector3.ZERO)
    assert_eq(heat.get_heat(), 15.0, "mỗi lần Boost tốn 15 nhiệt")


func test_charges_come_from_chassis_and_recharge_over_time() -> void:
    var boost := _make_boost()
    assert_eq(boost.get_charges(), 2, "RONIN-M có 2 lần nạp")
    boost.try_start(Vector3.FORWARD, null, Vector3.ZERO)
    boost.try_start(Vector3.FORWARD, null, Vector3.ZERO)
    assert_eq(boost.get_charges(), 1, "đang lướt thì không bắt đầu cú lướt thứ hai")
    boost.update(0.2, Vector3.ZERO, true)
    boost.try_start(Vector3.FORWARD, null, Vector3.ZERO)
    assert_eq(boost.get_charges(), 0)
    assert_false(boost.try_start(Vector3.FORWARD, null, Vector3.ZERO), "hết nạp thì không lướt được")
    boost.update(0.2, Vector3.ZERO, true)
    boost.update(3.5, Vector3.ZERO, true)
    assert_eq(boost.get_charges(), 1, "3.5s nạp lại một lần")


func test_no_recharge_while_overheated() -> void:
    var boost := _make_boost()
    boost.try_start(Vector3.FORWARD, null, Vector3.ZERO)
    boost.update(0.2, Vector3.ZERO, false)
    boost.update(5.0, Vector3.ZERO, false)
    assert_eq(boost.get_charges(), 1, "quá nhiệt thì không nạp lại Boost")


func test_boost_blocked_while_overheated_or_venting() -> void:
    var boost := _make_boost()
    var heat := _make_heat()
    heat.add_heat(100.0)
    assert_false(boost.try_start(Vector3.FORWARD, heat, Vector3.ZERO), "quá nhiệt thì không Boost")
    heat.tick(3.1)
    heat.update_vent(true, 0.2)
    assert_false(boost.try_start(Vector3.FORWARD, heat, Vector3.ZERO), "đang xả nhiệt thì không Boost")


func test_dash_damages_swarm_units_it_passes_through() -> void:
    var boost := _make_boost()
    var swarm: SwarmManager = add_child_autofree(SwarmManager.new()) as SwarmManager
    var victim: int = swarm.spawn(Vector3(0.0, 0.0, -3.0), Vector3.ZERO, 18.0, 0)
    var bystander: int = swarm.spawn(Vector3(9.0, 0.0, 0.0), Vector3.ZERO, 18.0, 0)
    boost.swarm_manager = swarm
    boost.try_start(Vector3.FORWARD, null, Vector3.ZERO)
    boost.update(0.2, Vector3(0.0, 0.0, -7.0), true)
    assert_almost_eq(swarm._healths[swarm._index_by_id[victim]], 6.0, 0.01,
        "lướt xuyên qua swarm gây 12 sát thương va chạm")
    assert_almost_eq(swarm._healths[swarm._index_by_id[bystander]], 18.0, 0.01,
        "con đứng ngoài đường lướt không bị gì")


func test_dash_cannot_pass_through_a_wall() -> void:
    var arena := add_child_autofree(ARENA_SCENE.instantiate()) as Node3D
    var mech := arena.get_node("Mech") as MechController
    mech.global_position = Vector3(0.0, 0.1, 26.0)   # sát tường Nam (z = 30)
    assert_true(mech.try_boost_in_direction(Vector3.BACK))
    for _i: int in range(12):
        mech.apply_movement(Vector2.ZERO, 0.02)
        mech.boost_component.update(0.02, mech.global_position, true)
    assert_lt(mech.global_position.z, 30.0, "cú lướt không được xuyên tường")


# --- T-206: bốn vùng giáp -----------------------------------------------

func _transform_facing_forward() -> Transform3D:
    return Transform3D.IDENTITY   # −Z là hướng trước


func test_zone_is_chosen_by_angle_to_source() -> void:
    var origin := _transform_facing_forward()
    assert_eq(ArmorComponent.zone_for_source(origin, Vector3(0.0, 0.0, -5.0)), ArmorComponent.Zone.FRONT)
    assert_eq(ArmorComponent.zone_for_source(origin, Vector3(0.0, 0.0, 5.0)), ArmorComponent.Zone.REAR)
    assert_eq(ArmorComponent.zone_for_source(origin, Vector3(5.0, 0.0, 0.0)), ArmorComponent.Zone.RIGHT)
    assert_eq(ArmorComponent.zone_for_source(origin, Vector3(-5.0, 0.0, 0.0)), ArmorComponent.Zone.LEFT)


func test_exact_forty_five_degrees_counts_as_front() -> void:
    var origin := _transform_facing_forward()
    var right_edge := Vector3(5.0, 0.0, -5.0)     # đúng 45° về bên phải
    var left_edge := Vector3(-5.0, 0.0, -5.0)
    assert_eq(ArmorComponent.zone_for_source(origin, right_edge), ArmorComponent.Zone.FRONT,
        "biên đúng 45° tính là TRƯỚC")
    assert_eq(ArmorComponent.zone_for_source(origin, left_edge), ArmorComponent.Zone.FRONT)


func test_zone_follows_mech_rotation() -> void:
    var turned := Transform3D(Basis(Vector3.UP, deg_to_rad(180.0)), Vector3.ZERO)
    assert_eq(ArmorComponent.zone_for_source(turned, Vector3(0.0, 0.0, -5.0)), ArmorComponent.Zone.REAR,
        "xoay 180° thì nguồn ở −Z thành phía sau")


func test_plate_absorbs_until_it_breaks() -> void:
    var armor := _make_armor()
    watch_signals(armor)
    assert_eq(armor.get_plate(ArmorComponent.Zone.FRONT), 60.0, "giáp trước RONIN-M là 60")
    var to_core: float = armor.absorb(20.0, ArmorComponent.Zone.FRONT)
    assert_eq(to_core, 0.0, "giáp còn thì Core không nhận gì")
    assert_eq(armor.get_plate(ArmorComponent.Zone.FRONT), 40.0)
    to_core = armor.absorb(50.0, ArmorComponent.Zone.FRONT)
    assert_almost_eq(to_core, 10.0, 0.001, "phần tràn của cú đánh làm vỡ mảng đi vào Core ×1.0")
    assert_true(armor.is_broken(ArmorComponent.Zone.FRONT))
    assert_signal_emitted_with_parameters(armor, "plate_broken", [ArmorComponent.Zone.FRONT])


func test_broken_zone_multiplies_core_damage_by_one_point_four() -> void:
    var armor := _make_armor()
    armor.absorb(60.0, ArmorComponent.Zone.REAR)      # giáp sau 42 → vỡ
    var to_core: float = armor.absorb(10.0, ArmorComponent.Zone.REAR)
    assert_almost_eq(to_core, 14.0, 0.001, "vùng đã vỡ nhân ×1.4 vào Core")


func test_zones_are_independent() -> void:
    var armor := _make_armor()
    armor.absorb(100.0, ArmorComponent.Zone.LEFT)
    assert_true(armor.is_broken(ArmorComponent.Zone.LEFT))
    assert_false(armor.is_broken(ArmorComponent.Zone.RIGHT), "vỡ trái không ảnh hưởng phải")
    assert_eq(armor.get_plate(ArmorComponent.Zone.RIGHT), 52.0)


func test_repair_restores_up_to_maximum() -> void:
    var armor := _make_armor()
    armor.absorb(30.0, ArmorComponent.Zone.FRONT)
    armor.repair(ArmorComponent.Zone.FRONT, 100.0)
    assert_eq(armor.get_plate(ArmorComponent.Zone.FRONT), 60.0, "không hồi quá mức tối đa")


# --- T-208: ba khung mech -----------------------------------------------

func test_three_chassis_match_gdd_table() -> void:
    var expected: Dictionary = {
        "chs_vespa_l": [80.0, 45.0, 38.0, 30.0, 7.6, 620.0, 85.0, 15.0, 3, 2.8, 2],
        "chs_ronin_m": [100.0, 60.0, 52.0, 42.0, 6.0, 480.0, 100.0, 12.0, 2, 3.5, 2],
        "chs_atlas_h": [145.0, 95.0, 80.0, 66.0, 4.4, 330.0, 125.0, 9.0, 2, 4.6, 3],
    }
    for id: String in expected.keys():
        var data: ChassisData = load("res://data/chassis/%s.tres" % id) as ChassisData
        assert_not_null(data, "phải có %s.tres" % id)
        var row: Array = expected[id]
        assert_eq(data.core_hp, row[0], "%s: Core HP" % id)
        assert_eq(data.armor_front, row[1], "%s: giáp trước" % id)
        assert_eq(data.armor_side, row[2], "%s: giáp hông" % id)
        assert_eq(data.armor_rear, row[3], "%s: giáp sau" % id)
        assert_eq(data.move_speed, row[4], "%s: tốc độ" % id)
        assert_eq(data.leg_turn_speed_degrees, row[5], "%s: xoay chân" % id)
        assert_eq(data.heat_capacity, row[6], "%s: sức chứa nhiệt" % id)
        assert_eq(data.heat_dissipation, row[7], "%s: tản nhiệt" % id)
        assert_eq(data.boost_charges, row[8], "%s: số lần nạp Boost" % id)
        assert_eq(data.boost_recharge_seconds, row[9], "%s: hồi chiêu Boost" % id)
        assert_eq(data.module_slots, row[10], "%s: ô module" % id)


func test_rear_armor_is_at_least_thirty_percent_below_front() -> void:
    for id: String in ["chs_vespa_l", "chs_ronin_m", "chs_atlas_h"]:
        var data: ChassisData = load("res://data/chassis/%s.tres" % id) as ChassisData
        assert_lte(data.armor_rear, data.armor_front * 0.7 + 0.001,
            "%s: giáp sau phải thấp hơn giáp trước ít nhất 30%%" % id)


func test_chassis_traits_are_distinct() -> void:
    var vespa: ChassisData = load("res://data/chassis/chs_vespa_l.tres") as ChassisData
    var atlas: ChassisData = load("res://data/chassis/chs_atlas_h.tres") as ChassisData
    assert_true(vespa.boost_skips_iframe_cooldown, "VESPA-L: Boost không tốn i-frame cooldown")
    assert_true(atlas.knockback_immune, "ATLAS-H: miễn nhiễm knockback")
    assert_almost_eq(atlas.explosive_damage_taken_multiplier, 0.8, 0.001, "ATLAS-H: −20% sát thương nổ")


func test_switching_chassis_reconfigures_every_component() -> void:
    var mech := add_child_autofree(MECH_SCENE.instantiate()) as MechController
    mech.set_chassis(load("res://data/chassis/chs_atlas_h.tres") as ChassisData)
    assert_eq(mech.armor_component.get_plate(ArmorComponent.Zone.FRONT), 95.0, "giáp đổi theo chassis")
    assert_eq(mech.boost_component.get_charges(), 2)
    mech.set_chassis(load("res://data/chassis/chs_vespa_l.tres") as ChassisData)
    assert_eq(mech.boost_component.get_charges(), 3, "VESPA-L có 3 lần nạp Boost")
    assert_eq(mech.heat_component.chassis_data.heat_capacity, 85.0)
