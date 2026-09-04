extends Node

## Trung tâm signal toàn cục của IRONHIVE.
## CHỈ khai báo signal — tuyệt đối không logic, không biến trạng thái, không
## hàm. Danh mục đầy đủ và bắt buộc ở docs/02-TDD.md §4.2 — thêm signal mới
## phải được ghi vào đó trước.
## EventBus không được phép biết về bất kỳ autoload nào khác.

# Chiến đấu
signal damage_dealt(target_id: int, info: DamageInfo)
signal enemy_killed(enemy_id: StringName, position: Vector3, was_actor: bool)
signal player_damaged(amount: float, zone: int, source_position: Vector3)
signal player_died()

# Nhiệt & mech
signal heat_changed(current: float, maximum: float)
signal overheat_started()
signal overheat_ended()
signal armor_plate_broken(zone: int)
signal boost_used(charges_left: int)

# Nhiệm vụ
signal mission_started(mission_id: StringName)
signal objective_updated(objective_id: StringName, progress: float)
signal mission_completed(results: Dictionary)
signal mission_failed(reason: StringName)
signal pressure_wave_started(intensity: float)

# Kinh tế
signal resource_gained(type: StringName, amount: int)
signal loot_picked_up(item_id: StringName)

# Hệ thống
signal settings_changed(section: StringName)
signal game_paused(is_paused: bool)
