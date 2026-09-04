class_name StatusComponent
extends Node

## Áp, cộng dồn, hết hạn và gỡ trạng thái bất lợi. Dùng chung cho cả người
## chơi lẫn actor. Xem docs/01-GDD.md §9.
##
## Component KHÔNG tự trừ máu: sát thương theo thời gian được phát ra qua
## `damage_over_time` để DamageResolver (T-502) xử lý — đây không phải nơi
## trừ máu.

signal status_applied(id: StringName, stacks: int)
signal status_refreshed(id: StringName, stacks: int)
signal status_removed(id: StringName)
signal damage_over_time(amount: float, type: DamageTypes.Type)

## Danh sách id trạng thái mà thực thể này miễn nhiễm (EnemyData.immune_status).
@export var immune_status: Array[StringName] = []

var _active: Dictionary = {}


func _physics_process(delta: float) -> void:
    tick(delta)


## Tách khỏi _physics_process để test gọi được với delta cố định.
func tick(delta: float) -> void:
    if delta <= 0.0 or _active.is_empty():
        return
    var expired: Array[StringName] = []
    for id: StringName in _active.keys():
        var entry: Dictionary = _active[id]
        var data: StatusEffectData = entry["data"]
        if data.damage_per_second > 0.0:
            damage_over_time.emit(data.damage_per_second * float(entry["stacks"]) * delta, data.damage_type)
        entry["remaining"] = float(entry["remaining"]) - delta
        if entry["remaining"] <= 0.0:
            expired.append(id)
    for id: StringName in expired:
        _remove_entry(id)


## Áp trạng thái. Trả về số tầng sau khi áp; 0 nghĩa là bị miễn nhiễm.
func apply(data: StatusEffectData) -> int:
    if data == null or immune_status.has(data.id):
        return 0
    if not _active.has(data.id):
        _active[data.id] = {"data": data, "remaining": data.duration_seconds, "stacks": 1}
        status_applied.emit(data.id, 1)
        return 1
    var entry: Dictionary = _active[data.id]
    var stacks: int = mini(int(entry["stacks"]) + 1, maxi(data.max_stacks, 1))
    entry["stacks"] = stacks
    entry["remaining"] = data.duration_seconds     # áp lại làm mới thời gian
    status_refreshed.emit(data.id, stacks)
    return stacks


func remove(id: StringName) -> bool:
    if not _active.has(id):
        return false
    _remove_entry(id)
    return true


func clear_all() -> void:
    for id: StringName in _active.keys().duplicate():
        _remove_entry(id)


func has_status(id: StringName) -> bool:
    return _active.has(id)


func get_stacks(id: StringName) -> int:
    if not _active.has(id):
        return 0
    return int((_active[id] as Dictionary)["stacks"])


func get_remaining(id: StringName) -> float:
    if not _active.has(id):
        return 0.0
    return float((_active[id] as Dictionary)["remaining"])


func get_active_ids() -> Array:
    return _active.keys()


## Các bội số nhân dồn với nhau khi dính nhiều trạng thái cùng lúc.
func get_move_speed_multiplier() -> float:
    return _product("move_speed_multiplier")


func get_damage_taken_multiplier() -> float:
    return _product("damage_taken_multiplier")


func get_armor_effectiveness_multiplier() -> float:
    return _product("armor_effectiveness_multiplier")


func can_attack() -> bool:
    for id: StringName in _active.keys():
        var data: StatusEffectData = (_active[id] as Dictionary)["data"]
        if data.prevents_attack:
            return false
    return true


func is_stealthed() -> bool:
    for id: StringName in _active.keys():
        var data: StatusEffectData = (_active[id] as Dictionary)["data"]
        if data.grants_stealth:
            return true
    return false


## Cú đánh đơn đủ mạnh làm vỡ trạng thái (Frozen vỡ tan khi chịu >50 sát
## thương một lần — GDD §9). Trả về danh sách trạng thái vừa bị vỡ.
func on_single_hit(amount: float) -> Array[StringName]:
    var broken: Array[StringName] = []
    for id: StringName in _active.keys():
        var data: StatusEffectData = (_active[id] as Dictionary)["data"]
        if data.breaks_on_single_hit_damage > 0.0 and amount > data.breaks_on_single_hit_damage:
            broken.append(id)
    for id: StringName in broken:
        _remove_entry(id)
    return broken


func _product(property: StringName) -> float:
    var result: float = 1.0
    for id: StringName in _active.keys():
        var data: StatusEffectData = (_active[id] as Dictionary)["data"]
        result *= float(data.get(property))
    return result


func _remove_entry(id: StringName) -> void:
    _active.erase(id)
    status_removed.emit(id)
