class_name Hitbox
extends Area3D

## Chỉ gây sát thương trong cửa sổ đòn đánh. Mỗi Hurtbox chỉ được nhận một
## lần trong một cửa sổ, kể cả khi tín hiệu area_entered phát lại.
signal hit_confirmed(hurtbox: Hurtbox)

@export var damage: float = 1.0
@export var damage_type: DamageTypes.Type = DamageTypes.Type.KINETIC
@export var damage_owner_path: NodePath = NodePath("..")

var _hit_targets: Dictionary = {}
var _window_active: bool = false


func _ready() -> void:
    monitoring = false
    area_entered.connect(_on_area_entered)


func open_window() -> void:
    _hit_targets.clear()
    _window_active = true
    monitoring = true
    # Area đã chồng trước khi mở cửa sổ không phát area_entered lần nữa.
    call_deferred(&"_scan_overlaps")


func close_window() -> void:
    _window_active = false
    monitoring = false


func is_window_active() -> bool:
    return _window_active


func try_hit(hurtbox: Hurtbox) -> bool:
    if not _window_active or hurtbox == null:
        return false
    var target: Node = hurtbox.get_receiver()
    if target == null or target == get_damage_owner():
        return false
    var target_id: int = target.get_instance_id()
    if _hit_targets.has(target_id):
        return false
    _hit_targets[target_id] = true
    var info := DamageInfo.new()
    info.amount = damage
    info.type = damage_type
    info.source_position = global_position
    var owner_node: Node = get_damage_owner()
    info.source_id = owner_node.get_instance_id() if owner_node != null else -1
    if not hurtbox.receive_hit(info, self):
        _hit_targets.erase(target_id)
        return false
    hit_confirmed.emit(hurtbox)
    return true


func get_damage_owner() -> Node:
    return get_node_or_null(damage_owner_path)


func _on_area_entered(area: Area3D) -> void:
    var hurtbox := area as Hurtbox
    if hurtbox != null:
        try_hit(hurtbox)


func _scan_overlaps() -> void:
    if not _window_active:
        return
    for area: Area3D in get_overlapping_areas():
        _on_area_entered(area)
