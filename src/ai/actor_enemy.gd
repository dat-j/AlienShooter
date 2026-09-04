class_name ActorEnemy
extends CharacterBody3D

## Nền tảng cho kẻ địch đường ACTOR. Instance được tạo trước bởi PoolManager;
## các callback acquire/release chỉ đặt lại trạng thái, không cấp phát node.

signal health_changed(current: float, maximum: float)
signal died(actor: ActorEnemy)

@export var enemy_data: EnemyData

@onready var model: Node3D = $Model
@onready var state_machine: Node = $StateMachine
@onready var health_component: Node = $HealthComponent
@onready var status_component: Node = $StatusComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox

var current_health: float = 1.0
var flow_field: FlowField
var target: Node3D
var attack_cooldown_remaining: float = 0.0
var _active: bool = false


func _physics_process(delta: float) -> void:
    attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - delta)


func _ready() -> void:
    if enemy_data != null:
        configure(enemy_data)
    else:
        _set_active(false)


func configure(data: EnemyData) -> bool:
    if data == null or data.execution_path != 1:
        return false
    enemy_data = data
    current_health = data.max_hp
    health_changed.emit(current_health, data.max_hp)
    return true


func set_context(new_flow_field: FlowField, new_target: Node3D) -> void:
    flow_field = new_flow_field
    target = new_target


func take_damage(amount: float) -> void:
    if not _active or amount <= 0.0 or enemy_data == null:
        return
    current_health = maxf(0.0, current_health - amount)
    health_changed.emit(current_health, enemy_data.max_hp)
    if current_health <= 0.0:
        died.emit(self)


func _on_acquired() -> void:
    if enemy_data != null:
        current_health = enemy_data.max_hp
    velocity = Vector3.ZERO
    attack_cooldown_remaining = 0.0
    _set_active(true)


func _on_released() -> void:
    velocity = Vector3.ZERO
    attack_cooldown_remaining = 0.0
    hitbox.close_window()
    target = null
    flow_field = null
    _set_active(false)


func _set_active(value: bool) -> void:
    _active = value
    visible = value
    process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
    hurtbox.monitoring = value
    hitbox.monitoring = false


func is_active() -> bool:
    return _active
