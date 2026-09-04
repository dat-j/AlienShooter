class_name WaveTable extends Resource

## Bảng trọng số sinh kẻ địch dùng bởi SpawnDirector. Xem docs/01-GDD.md §10.3
## và docs/02-TDD.md §11. Phân phối đầy đủ và tinh chỉnh dung sai thuộc T-801 —
## ở task này chỉ có cấu trúc dữ liệu và một thuật toán roll() cơ bản đúng kiểu.

@export var id: StringName
@export var chapter: int = 1

@export_group("Thành phần")
@export var enemy_ids: Array[StringName] = []
@export var costs: Array[int] = []
@export var weights: Array[float] = []
@export var min_mission_time_seconds: Array[float] = []   # song song với enemy_ids
@export var max_mission_time_seconds: Array[float] = []   # -1 = không giới hạn


## Một mục trong kết quả roll(): một loại kẻ địch và chi phí ngân sách của nó.
class SpawnEntry:
    extends RefCounted

    var enemy_id: StringName
    var cost: int


    func _init(p_enemy_id: StringName, p_cost: int) -> void:
        enemy_id = p_enemy_id
        cost = p_cost


## Quay ra một tổ hợp kẻ địch phù hợp với thời điểm nhiệm vụ và ngân sách hiện
## có. Trả về Array chứa các SpawnEntry. Thuật toán cơ bản: chọn ngẫu nhiên có
## trọng số trong các mục còn hợp lệ, lặp tới khi hết ngân sách hoặc hết ứng viên.
func roll(mission_time: float, budget: float) -> Array:
    var result: Array = []
    var remaining_budget: float = budget
    var guard: int = 0
    while guard < 64:
        guard += 1
        var eligible: Array[int] = _eligible_indices(mission_time, remaining_budget)
        if eligible.is_empty():
            break
        var picked: int = _weighted_pick(eligible)
        if picked < 0:
            break
        result.append(SpawnEntry.new(enemy_ids[picked], costs[picked]))
        remaining_budget -= float(costs[picked])
    return result


func _eligible_indices(mission_time: float, budget: float) -> Array[int]:
    var out: Array[int] = []
    for i: int in range(enemy_ids.size()):
        var min_t: float = min_mission_time_seconds[i] if i < min_mission_time_seconds.size() else 0.0
        var max_t: float = max_mission_time_seconds[i] if i < max_mission_time_seconds.size() else -1.0
        var cost: int = costs[i] if i < costs.size() else 1
        if mission_time < min_t:
            continue
        if max_t >= 0.0 and mission_time > max_t:
            continue
        if float(cost) > budget:
            continue
        out.append(i)
    return out


func _weighted_pick(indices: Array[int]) -> int:
    var total_weight: float = 0.0
    for i: int in indices:
        var w: float = weights[i] if i < weights.size() else 1.0
        total_weight += w
    if total_weight <= 0.0:
        return indices[0] if not indices.is_empty() else -1
    var roll_value: float = randf() * total_weight
    var accum: float = 0.0
    for i: int in indices:
        var w: float = weights[i] if i < weights.size() else 1.0
        accum += w
        if roll_value <= accum:
            return i
    return indices[indices.size() - 1]
