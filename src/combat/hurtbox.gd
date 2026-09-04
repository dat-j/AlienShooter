class_name Hurtbox
extends Area3D

## Điểm nhận đòn. Việc trừ máu tạm thời chuyển cho entity sở hữu; T-502 sẽ
## thay bằng DamageResolver mà không cần đổi hợp đồng Hitbox/Hurtbox.
signal hit_received(info: DamageInfo, source: Hitbox)

@export var receiver_path: NodePath = NodePath("..")


func receive_hit(info: DamageInfo, source: Hitbox) -> bool:
    if info == null or source == null or not monitoring:
        return false
    var receiver: Node = get_node_or_null(receiver_path)
    if receiver == null or receiver == source.get_damage_owner():
        return false
    hit_received.emit(info, source)
    if receiver.has_method(&"take_damage"):
        receiver.call(&"take_damage", info.amount)
        return true
    return false


func get_receiver() -> Node:
    return get_node_or_null(receiver_path)
