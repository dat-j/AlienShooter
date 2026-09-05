class_name AmmoCrate
extends Area3D

## Hộp đạn rơi ra trong màn: chạm vào là cộng **25% đạn tối đa cho cả hai
## vũ khí** (GDD §11.2). Xem docs/05-BACKLOG.md T-509.
##
## Pooled — không `instantiate()`, không `queue_free()` trong chiến đấu
## (TDD §12.1). Đây là Area3D chứ không phải node swarm, nên luật cấm Area3D
## ở TDD §12.5 không áp dụng: cả màn chỉ có vài chục hộp, không phải 300 con.

signal collected(mech: MechController, rounds_added: int)

## Tỉ lệ đạn tối đa mà một hộp bù vào, theo bảng rơi đồ GDD §11.2.
const REFILL_FRACTION: float = 0.25
const SPIN_SPEED: float = 1.8
const BOB_HEIGHT: float = 0.12
const BOB_SPEED: float = 2.4

@export var refill_fraction: float = REFILL_FRACTION

var _is_active: bool = false
var _elapsed: float = 0.0

@onready var _model: Node3D = $Model


func _ready() -> void:
    collision_layer = CollisionLayers.Layer.PICKUP
    collision_mask = CollisionLayers.Layer.PLAYER_BODY
    monitoring = true
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
    if not _is_active:
        return
    _elapsed += delta
    _model.rotate_y(SPIN_SPEED * delta)
    _model.position.y = sin(_elapsed * BOB_SPEED) * BOB_HEIGHT


## Đặt hộp xuống sàn và bật nhận va chạm. Gọi sau khi lấy từ PoolManager.
func drop_at(position: Vector3) -> void:
    global_position = position
    _elapsed = 0.0
    _is_active = true
    visible = true
    monitoring = true


func is_active() -> bool:
    return _is_active


## Tách khỏi phần va chạm để test gọi thẳng được mà không cần dựng physics.
func collect(mech: MechController) -> int:
    if not _is_active or mech == null:
        return 0
    var added: int = mech.refill_ammo(refill_fraction)
    _is_active = false
    monitoring = false
    visible = false
    collected.emit(mech, added)
    EventBus.loot_picked_up.emit(&"item_ammo_crate")
    PoolManager.release(self)
    return added


func _on_body_entered(body: Node3D) -> void:
    var mech := body as MechController
    if mech != null:
        collect(mech)


func _on_acquired() -> void:
    _reset()


func _on_released() -> void:
    _reset()


func _reset() -> void:
    _is_active = false
    _elapsed = 0.0
    monitoring = false
    visible = false
