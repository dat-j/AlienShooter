extends Node3D

## Đạn giả lập cho test T-406. Chỉ ghi lại tham số của launch(); đường đạn và
## va chạm thật là việc của T-504 (`src/combat/projectile.gd`).

var launch_count: int = 0
var last_origin: Vector3 = Vector3.ZERO
var last_direction: Vector3 = Vector3.ZERO
var last_speed: float = 0.0
var last_damage: float = 0.0
var last_damage_type: int = 0
var last_source: Node


func launch(
    origin: Vector3,
    direction: Vector3,
    speed: float,
    damage: float,
    damage_type: int,
    source: Node
) -> void:
    launch_count += 1
    last_origin = origin
    last_direction = direction
    last_speed = speed
    last_damage = damage
    last_damage_type = damage_type
    last_source = source
