extends GutTest

## T-502 — DamageResolver là nơi duy nhất trừ máu. Bao phủ mọi loại sát
## thương, vùng giáp, chí mạng, xuyên, trạng thái và các trường hợp biên.
## TDD §14 bắt buộc test cho DamageResolver.

const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")
const ACTOR_SCENE: PackedScene = preload("res://scenes/enemies/actors/actor_base.tscn")


func _make_mech() -> MechController:
    return add_child_autofree(MECH_SCENE.instantiate()) as MechController


func _make_actor(max_hp: float) -> ActorEnemy:
    var actor := add_child_autofree(ACTOR_SCENE.instantiate()) as ActorEnemy
    var data := EnemyData.new()
    data.execution_path = 1
    data.max_hp = max_hp
    actor.configure(data)
    actor._on_acquired()
    return actor


func _info(amount: float, from: Vector3, type: DamageTypes.Type = DamageTypes.Type.KINETIC) -> DamageInfo:
    var info: DamageInfo = PoolManager.get_damage_info()
    info.amount = amount
    info.type = type
    info.source_position = from
    return info


# --- Trường hợp biên ----------------------------------------------------

func test_null_and_zero_damage_do_nothing() -> void:
    var mech := _make_mech()
    assert_eq(DamageResolver.resolve(null, mech), 0.0, "info rỗng không gây gì")
    var info := _info(0.0, Vector3.ZERO)
    assert_eq(DamageResolver.resolve(info, mech), 0.0, "0 sát thương không gây gì")
    assert_eq(DamageResolver.resolve(info, null), 0.0, "mục tiêu rỗng không gây gì")
    PoolManager.release_damage_info(info)


func test_health_never_goes_below_zero() -> void:
    var actor := _make_actor(20.0)
    var info := _info(999.0, Vector3.ZERO)
    var applied: float = DamageResolver.resolve(info, actor)
    assert_eq(actor.current_health, 0.0, "máu không xuống dưới 0")
    assert_eq(applied, 20.0, "chỉ tính phần máu thực sự bị trừ")
    PoolManager.release_damage_info(info)


# --- Loại sát thương và chí mạng ----------------------------------------

func test_critical_doubles_the_hit() -> void:
    var actor := _make_actor(100.0)
    var info := _info(10.0, Vector3.ZERO)
    info.is_critical = true
    DamageResolver.resolve(info, actor)
    assert_eq(actor.current_health, 80.0, "chí mạng nhân đôi")
    PoolManager.release_damage_info(info)


func test_explosive_resistance_comes_from_chassis() -> void:
    var mech := _make_mech()
    mech.set_chassis(load("res://data/chassis/chs_atlas_h.tres") as ChassisData)
    var info := _info(100.0, mech.global_position + Vector3(0.0, 0.0, -5.0), DamageTypes.Type.EXPLOSIVE)
    DamageResolver.resolve(info, mech)
    # 100 × 0.8 = 80 → giáp trước ATLAS-H 95 nuốt hết, Core không mất máu.
    assert_eq(mech.armor_component.get_plate(ArmorComponent.Zone.FRONT), 15.0,
        "ATLAS-H nhận 80% sát thương nổ")
    assert_eq(mech.core_hp, 145.0)
    PoolManager.release_damage_info(info)


func test_true_damage_ignores_armor_completely() -> void:
    var mech := _make_mech()
    var info := _info(10.0, mech.global_position + Vector3(0.0, 0.0, -5.0), DamageTypes.Type.TRUE)
    DamageResolver.resolve(info, mech)
    assert_eq(mech.armor_component.get_plate(ArmorComponent.Zone.FRONT), 60.0, "TRUE không chạm giáp")
    assert_eq(mech.core_hp, 90.0, "TRUE đi thẳng vào Core")
    PoolManager.release_damage_info(info)


func test_energy_bypasses_half_of_the_armour() -> void:
    var mech := _make_mech()
    var info := _info(20.0, mech.global_position + Vector3(0.0, 0.0, -5.0), DamageTypes.Type.ENERGY)
    DamageResolver.resolve(info, mech)
    assert_eq(mech.armor_component.get_plate(ArmorComponent.Zone.FRONT), 50.0, "một nửa vào giáp")
    assert_eq(mech.core_hp, 90.0, "một nửa xuyên thẳng vào Core")
    PoolManager.release_damage_info(info)


# --- Vùng giáp ----------------------------------------------------------

func test_damage_is_routed_to_the_zone_facing_the_source() -> void:
    var mech := _make_mech()
    var info := _info(20.0, mech.global_position + Vector3(5.0, 0.0, 0.0))
    DamageResolver.resolve(info, mech)
    assert_eq(mech.armor_component.get_plate(ArmorComponent.Zone.RIGHT), 32.0, "nguồn bên phải trừ giáp phải")
    assert_eq(mech.armor_component.get_plate(ArmorComponent.Zone.FRONT), 60.0)
    assert_eq(mech.core_hp, 100.0, "giáp còn thì Core nguyên vẹn")
    PoolManager.release_damage_info(info)


func test_broken_zone_sends_amplified_damage_to_core() -> void:
    var mech := _make_mech()
    var behind: Vector3 = mech.global_position + Vector3(0.0, 0.0, 5.0)
    var first := _info(42.0, behind)
    DamageResolver.resolve(first, mech)          # vỡ đúng mảng giáp sau
    PoolManager.release_damage_info(first)
    assert_true(mech.armor_component.is_broken(ArmorComponent.Zone.REAR))
    assert_eq(mech.core_hp, 100.0)
    var second := _info(10.0, behind)
    DamageResolver.resolve(second, mech)
    assert_almost_eq(mech.core_hp, 86.0, 0.001, "vùng đã vỡ nhân ×1.4 vào Core")
    PoolManager.release_damage_info(second)


func test_emits_player_damaged_and_player_died() -> void:
    var mech := _make_mech()
    watch_signals(EventBus)
    var info := _info(500.0, mech.global_position + Vector3(0.0, 0.0, -5.0), DamageTypes.Type.TRUE)
    DamageResolver.resolve(info, mech)
    assert_eq(mech.core_hp, 0.0)
    assert_signal_emitted(EventBus, "player_damaged")
    assert_signal_emitted(EventBus, "player_died")
    PoolManager.release_damage_info(info)


# --- Tương tác với các hệ thống khác -------------------------------------

func test_iframe_during_boost_blocks_everything() -> void:
    var mech := _make_mech()
    mech.try_boost_in_direction(Vector3.FORWARD)
    mech.boost_component.update(0.05, mech.global_position, true)
    assert_true(mech.boost_component.is_invulnerable(), "đang ở giữa cú lướt")
    var info := _info(50.0, mech.global_position + Vector3(0.0, 0.0, -5.0), DamageTypes.Type.TRUE)
    assert_eq(DamageResolver.resolve(info, mech), 0.0, "i-frame chặn toàn bộ sát thương")
    assert_eq(mech.core_hp, 100.0)
    PoolManager.release_damage_info(info)


func test_venting_raises_damage_taken_by_thirty_percent() -> void:
    var mech := _make_mech()
    mech.heat_component.update_vent(true, 0.2)
    var info := _info(10.0, mech.global_position + Vector3(0.0, 0.0, -5.0), DamageTypes.Type.TRUE)
    DamageResolver.resolve(info, mech)
    assert_almost_eq(mech.core_hp, 87.0, 0.001, "đang xả nhiệt nhận +30% sát thương")
    PoolManager.release_damage_info(info)


func test_marked_status_amplifies_incoming_damage() -> void:
    var mech := _make_mech()
    mech.status_component.apply(load("res://data/status_effects/eff_marked.tres") as StatusEffectData)
    var info := _info(10.0, mech.global_position + Vector3(0.0, 0.0, -5.0), DamageTypes.Type.TRUE)
    DamageResolver.resolve(info, mech)
    assert_almost_eq(mech.core_hp, 88.0, 0.001, "Marked +20% sát thương nhận vào")
    PoolManager.release_damage_info(info)


func test_status_in_damage_info_is_applied_to_target() -> void:
    var actor := _make_actor(100.0)
    var info := _info(5.0, Vector3.ZERO)
    info.status_to_apply.append(&"eff_burning")
    DamageResolver.resolve(info, actor)
    var status := actor.get_node_or_null("StatusComponent") as StatusComponent
    assert_not_null(status, "actor phải có StatusComponent dùng chung")
    assert_true(status.has_status(&"eff_burning"), "trạng thái kèm theo phải được áp")
    PoolManager.release_damage_info(info)


func test_actor_take_damage_goes_through_the_resolver() -> void:
    var actor := _make_actor(50.0)
    watch_signals(actor)
    actor.take_damage(20.0)
    assert_eq(actor.current_health, 30.0)
    assert_signal_emitted(actor, "health_changed")
    actor.take_damage(30.0)
    assert_eq(actor.current_health, 0.0)
    assert_signal_emitted(actor, "died")
