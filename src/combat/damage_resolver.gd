class_name DamageResolver
extends RefCounted

## NƠI DUY NHẤT trừ máu trong toàn bộ codebase. Xem docs/02-TDD.md §8.2.
## Không có bất kỳ chỗ nào khác được viết `health -= x`.
## Class tĩnh — không bao giờ khởi tạo.
##
## Thứ tự xử lý: kháng theo loại → chí mạng → trạng thái (+sát thương nhận
## vào) → vùng giáp → trừ Core/HP → phát EventBus.

## GIÁ TRỊ TẠM — GDD chưa quy định con số, cần chốt ở T-1402 (pass cân bằng).
const CRITICAL_MULTIPLIER: float = 2.0
## ENERGY "xuyên giáp tốt" (GDD §6.1): phần này đi thẳng vào Core.
const ENERGY_ARMOR_BYPASS: float = 0.5


## Áp sát thương lên `target`. Trả về lượng máu thực sự bị trừ.
## `info` do người gọi lấy từ PoolManager và tự trả lại sau khi xong.
static func resolve(info: DamageInfo, target: Node) -> float:
    if info == null or target == null or info.amount <= 0.0:
        return 0.0
    var mech := target as MechController
    if mech != null:
        return _resolve_mech(info, mech)
    var actor := target as ActorEnemy
    if actor != null:
        return _resolve_actor(info, actor)
    Log.warn("Không biết cách gây sát thương cho %s" % target.get_class(), "DamageResolver")
    return 0.0


## Hàm thuần tuý: nhân chí mạng và kháng theo loại lên sát thương gốc.
static func compute_base_amount(info: DamageInfo, resistance: float) -> float:
    var amount: float = info.amount
    if info.type != DamageTypes.Type.TRUE:
        amount *= maxf(resistance, 0.0)
    if info.is_critical:
        amount *= CRITICAL_MULTIPLIER
    return maxf(amount, 0.0)


## Phần sát thương bỏ qua giáp: TRUE bỏ qua hoàn toàn, ENERGY bỏ qua một nửa.
static func compute_armor_bypass(type: DamageTypes.Type) -> float:
    match type:
        DamageTypes.Type.TRUE:
            return 1.0
        DamageTypes.Type.ENERGY:
            return ENERGY_ARMOR_BYPASS
        _:
            return 0.0


static func _resolve_mech(info: DamageInfo, mech: MechController) -> float:
    var amount: float = compute_base_amount(info, _mech_resistance(info.type, mech))
    if mech.status_component != null:
        amount *= mech.status_component.get_damage_taken_multiplier()
    if mech.heat_component != null:
        amount *= mech.heat_component.get_damage_taken_multiplier()
    if mech.boost_component != null and mech.boost_component.is_invulnerable():
        return 0.0

    var zone: ArmorComponent.Zone = ArmorComponent.Zone.FRONT
    var to_core: float = amount
    if mech.armor_component != null:
        zone = ArmorComponent.zone_for_source(mech.global_transform, info.source_position)
        var bypass: float = compute_armor_bypass(info.type)
        var direct: float = amount * bypass
        var through_armor: float = amount - direct
        # Corroded làm giảm hiệu quả giáp: phần giáp hấp thụ được ít đi.
        var effectiveness: float = 1.0
        if mech.status_component != null:
            effectiveness = mech.status_component.get_armor_effectiveness_multiplier()
        var absorbed_input: float = through_armor * effectiveness
        var leaked: float = mech.armor_component.absorb(absorbed_input, zone)
        to_core = direct + leaked + (through_armor - absorbed_input)

    var applied: float = _apply_to_mech_core(mech, to_core)
    _apply_statuses(info, mech.status_component)
    if mech.status_component != null:
        mech.status_component.on_single_hit(amount)
    EventBus.player_damaged.emit(applied, int(zone), info.source_position)
    EventBus.damage_dealt.emit(mech.get_instance_id(), info)
    if mech.core_hp <= 0.0:
        EventBus.player_died.emit()
    return applied


static func _resolve_actor(info: DamageInfo, actor: ActorEnemy) -> float:
    if not actor.is_active() or actor.enemy_data == null:
        return 0.0
    var amount: float = compute_base_amount(info, 1.0)
    var status := actor.get_node_or_null(^"StatusComponent") as StatusComponent
    if status != null:
        amount *= status.get_damage_taken_multiplier()
    var applied: float = _apply_to_actor_health(actor, amount)
    _apply_statuses(info, status)
    if status != null:
        status.on_single_hit(amount)
    EventBus.damage_dealt.emit(actor.get_instance_id(), info)
    return applied


## Kháng riêng của chassis: ATLAS-H nhận ít sát thương nổ hơn (GDD §5).
static func _mech_resistance(type: DamageTypes.Type, mech: MechController) -> float:
    if mech.chassis_data == null:
        return 1.0
    if type == DamageTypes.Type.EXPLOSIVE:
        return mech.chassis_data.explosive_damage_taken_multiplier
    return 1.0


static func _apply_statuses(info: DamageInfo, status: StatusComponent) -> void:
    if status == null or info.status_to_apply.is_empty():
        return
    for id: StringName in info.status_to_apply:
        var data: StatusEffectData = ContentDB.get_status_effect(id)
        if data != null:
            status.apply(data)


## Hai hàm dưới đây là HAI DÒNG DUY NHẤT trong codebase được phép trừ máu.
static func _apply_to_mech_core(mech: MechController, amount: float) -> float:
    if amount <= 0.0:
        return 0.0
    var before: float = mech.core_hp
    mech.core_hp = maxf(0.0, mech.core_hp - amount)
    var applied: float = before - mech.core_hp
    mech.notify_core_changed()
    return applied


static func _apply_to_actor_health(actor: ActorEnemy, amount: float) -> float:
    if amount <= 0.0:
        return 0.0
    var before: float = actor.current_health
    actor.current_health = maxf(0.0, actor.current_health - amount)
    var applied: float = before - actor.current_health
    actor.notify_health_changed()
    return applied
