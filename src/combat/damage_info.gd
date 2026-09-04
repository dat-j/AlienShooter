class_name DamageInfo
extends RefCounted

## Gói dữ liệu một lần gây sát thương. KHÔNG phải Resource — tránh cấp phát.
## Xem docs/02-TDD.md §8.1.
##
## GIỚI HẠN HIỆN TẠI: đây mới là phần khai báo trường, đủ để EventBus và
## DamageResolver tham chiếu kiểu. Việc lấy/trả instance qua PoolManager
## thuộc task T-501 và CHƯA được triển khai.

var amount: float = 0.0
var type: DamageTypes.Type = DamageTypes.Type.KINETIC
var source_position: Vector3 = Vector3.ZERO
var source_id: int = -1
var knockback: float = 0.0
var status_to_apply: Array[StringName] = []
var is_critical: bool = false
var pierce_remaining: int = 0


## Đưa mọi trường về mặc định. Gọi khi lấy instance ra khỏi pool.
func reset() -> void:
    amount = 0.0
    type = DamageTypes.Type.KINETIC
    source_position = Vector3.ZERO
    source_id = -1
    knockback = 0.0
    status_to_apply.clear()
    is_critical = false
    pierce_remaining = 0
