class_name LootTable extends Resource

## Bảng xác suất rơi đồ. Xem docs/01-GDD.md §11.2. Luật thả đồ thích ứng
## (theo % Armor hoặc nhiệt trung bình của người chơi) KHÔNG nằm trong Resource
## này — đó là logic runtime của loot_spawner.gd (T-902); ở đây chỉ có bảng
## xác suất tĩnh và một hàm roll() cơ bản.

@export var id: StringName

@export_group("Thành phần")
@export var item_ids: Array[StringName] = []
@export var weights: Array[float] = []
@export var min_amount: Array[int] = []
@export var max_amount: Array[int] = []


## Một lần rơi đồ: loại vật phẩm và số lượng.
class LootRoll:
    extends RefCounted

    var item_id: StringName
    var amount: int


    func _init(p_item_id: StringName, p_amount: int) -> void:
        item_id = p_item_id
        amount = p_amount


## Quay ra `count` lần rơi đồ độc lập (có hoàn lại), trọng số theo `weights`.
## Trả về Array chứa các LootRoll.
func roll(count: int = 1) -> Array:
    var result: Array = []
    if item_ids.is_empty():
        return result
    for _n: int in range(count):
        var index: int = _weighted_pick()
        if index < 0:
            continue
        var lo: int = min_amount[index] if index < min_amount.size() else 1
        var hi: int = max_amount[index] if index < max_amount.size() else lo
        var amount: int = lo if hi <= lo else randi_range(lo, hi)
        result.append(LootRoll.new(item_ids[index], amount))
    return result


func _weighted_pick() -> int:
    var total_weight: float = 0.0
    for i: int in range(item_ids.size()):
        var w: float = weights[i] if i < weights.size() else 1.0
        total_weight += w
    if total_weight <= 0.0:
        return -1
    var roll_value: float = randf() * total_weight
    var accum: float = 0.0
    for i: int in range(item_ids.size()):
        var w: float = weights[i] if i < weights.size() else 1.0
        accum += w
        if roll_value <= accum:
            return i
    return item_ids.size() - 1
