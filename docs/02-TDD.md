# IRONHIVE — Tài liệu Thiết kế Kỹ thuật (TDD)

> Nguồn chân lý cho **kiến trúc, quy ước và ranh giới kỹ thuật**. AI agent phải đọc file này trước khi viết dòng code đầu tiên. Đi lệch kiến trúc ở đây là lý do chính đáng để từ chối một pull request.

---

## 1. Nền tảng

| Mục | Quyết định | Lý do |
|---|---|---|
| Engine | **Godot 4.4 trở lên**, renderer **Forward+** | Cần nhiều đèn động, decal, SDF; Compatibility renderer không đủ |
| Ngôn ngữ | **GDScript**, bật `@static_typed` toàn bộ | Vòng lặp phát triển nhanh; hiệu năng đủ vì phần nóng dùng kiến trúc data-oriented, không dùng node |
| C# / GDExtension | **Không dùng ở v1.0** | Tránh phức tạp build. Chỉ cân nhắc nếu profiler chứng minh GDScript là nút thắt thật sự |
| Vật lý | Godot Physics 3D, **chỉ cho người chơi, actor, projectile lớn** | Swarm không dùng physics engine (mục 6) |
| Đơn vị | 1 đơn vị Godot = **1 mét**. Mech cao ~4m | |
| Hệ trục | Y hướng lên. Mặt phẳng chơi là **XZ** | |
| Điều khiển phiên bản | Git, `main` + nhánh tính năng `feat/<mã-task>` | |

## 2. Cấu trúc thư mục

```
res://
├── addons/                     Plugin bên thứ ba (giữ tối thiểu)
├── assets/
│   ├── models/{mech,enemies,props,environment}/
│   ├── materials/
│   ├── textures/
│   ├── audio/{sfx,music,vo}/
│   └── fonts/
├── data/                       *** DỮ LIỆU .tres — nội dung game sống ở đây ***
│   ├── weapons/                WeaponData
│   ├── chassis/                ChassisData
│   ├── modules/                ModuleData
│   ├── enemies/                EnemyData
│   ├── status_effects/         StatusEffectData
│   ├── missions/               MissionData
│   ├── wave_tables/            WaveTable
│   ├── loot_tables/            LootTable
│   ├── perks/                  PerkData
│   └── rooms/                  RoomModuleData (trỏ tới scene phòng)
├── scenes/
│   ├── main/                   Main.tscn, các màn hình cấp cao nhất
│   ├── player/                 Mech.tscn và các component
│   ├── enemies/actors/         Một scene mỗi ACTOR
│   ├── enemies/bosses/
│   ├── projectiles/
│   ├── rooms/{ch1..ch5}/       Module phòng dựng sẵn
│   ├── ui/{hud,menus,hangar}/
│   └── vfx/
├── src/                        *** CODE GDScript ***
│   ├── autoload/               Singleton (mục 4)
│   ├── core/                   Tiện ích không phụ thuộc game
│   ├── combat/                 Sát thương, hitbox, status, projectile
│   ├── swarm/                  Hệ thống swarm data-oriented (mục 6)
│   ├── ai/                     Máy trạng thái actor, flow field, steering
│   ├── player/                 Component của mech
│   ├── generation/             Sinh màn
│   ├── director/               Spawn director
│   ├── progression/            Save, kinh tế, perk
│   ├── ui/                     Controller cho UI
│   └── resources/              Định nghĩa class Resource (schema)
├── tools/                      Script chỉ chạy trong editor, công cụ cân bằng
├── tests/                      GUT test
└── project.godot
```

**Luật:** `src/` chứa code, `scenes/` chứa scene, `data/` chứa `.tres`. Không nhét script `.gd` vào `scenes/`. Scene tham chiếu script bằng đường dẫn tuyệt đối `res://src/...`.

## 3. Quy ước đặt tên

| Đối tượng | Quy ước | Ví dụ |
|---|---|---|
| File script | `snake_case.gd` | `heat_component.gd` |
| File scene | `snake_case.tscn` | `ravager.tscn` |
| Tên class | `PascalCase` qua `class_name` | `class_name HeatComponent` |
| Node trong scene | `PascalCase` | `WeaponMountLeft` |
| Biến, hàm | `snake_case` | `current_heat`, `apply_damage()` |
| Private | Tiền tố `_` | `_recalculate_flow_field()` |
| Hằng số | `SCREAMING_SNAKE_CASE` | `MAX_SWARM_UNITS` |
| Signal | `snake_case`, thì quá khứ | `heat_threshold_crossed` |
| Enum | `PascalCase` cho enum, `SCREAMING` cho phần tử | `enum DamageType { KINETIC, ENERGY }` |
| File dữ liệu | `snake_case.tres`, tiền tố theo loại | `wpn_rail_lance.tres`, `enm_ravager.tres` |
| Autoload | `PascalCase` | `EventBus`, `PoolManager` |

**Bắt buộc:** mọi biến, tham số và giá trị trả về đều phải có kiểu tĩnh. `var x = 5` bị từ chối; viết `var x: int = 5`.

## 4. Autoload (Singleton)

Đăng ký theo đúng thứ tự này trong `project.godot` — thứ tự quan trọng vì phụ thuộc khởi tạo.

| # | Tên | Trách nhiệm | Được phép biết về |
|---|---|---|---|
| 1 | `Logger` | Ghi log có cấp độ, ghi ra file khi build debug | Không gì |
| 2 | `EventBus` | Trung tâm signal toàn cục. **Chỉ khai báo signal, không có logic** | Không gì |
| 3 | `SettingsManager` | Đồ hoạ, âm lượng, gán phím; đọc/ghi `user://settings.cfg` | Logger |
| 4 | `ContentDB` | Nạp và index toàn bộ `.tres` trong `res://data/` lúc khởi động. Tra cứu theo id | Logger |
| 5 | `SaveManager` | Serialize/deserialize tiến trình, `user://save_*.json` có phiên bản | ContentDB, Logger |
| 6 | `PoolManager` | Object pool cho projectile, VFX, decal, damage number, actor | Logger |
| 7 | `AudioDirector` | Bus âm thanh, nhạc động, giới hạn số instance mỗi loại SFX | SettingsManager |
| 8 | `JuiceDirector` | Giật màn hình, hitstop, rung gamepad, hiệu ứng hậu kỳ khi trúng đòn | SettingsManager |
| 9 | `GameDirector` | Máy trạng thái cấp cao nhất, chuyển cảnh, tải nhiệm vụ | Tất cả những cái trên |

**Luật vàng:** Autoload không bao giờ giữ tham chiếu trực tiếp tới node trong màn chơi. Giao tiếp một chiều qua `EventBus`. Điều này giúp bất kỳ scene nào cũng chạy độc lập được khi test.

### 4.1 Máy trạng thái GameDirector

```
BOOT → MAIN_MENU → HANGAR ⇄ LOADOUT
                     ↓          ↓
                  MISSION_LOADING → MISSION_ACTIVE → MISSION_DEBRIEF → HANGAR
                                          ↓
                                     MISSION_FAILED → HANGAR
```

Mỗi trạng thái là một scene cấp cao nhất được nạp bất đồng bộ qua `ResourceLoader.load_threaded_request()`. Không bao giờ `change_scene_to_file()` khi đang chơi.

### 4.2 Danh mục EventBus

Giữ danh sách này gọn. Signal thêm vào phải được ghi ở đây.

```gdscript
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
```

## 5. Kiến trúc thực thể người chơi

`Mech.tscn` — `CharacterBody3D` với các node con thuần theo cơ chế. **Không** có script mech khổng lồ.

```
Mech (CharacterBody3D)              → mech_controller.gd  (chỉ điều phối)
├── LegsPivot (Node3D)              → xoay theo hướng di chuyển
│   └── LegsModel
├── TorsoPivot (Node3D)             → xoay theo con trỏ
│   ├── TorsoModel
│   ├── WeaponMountLeft  (Node3D)   → weapon_mount.gd
│   └── WeaponMountRight (Node3D)   → weapon_mount.gd
├── HeatComponent      (Node)       → heat_component.gd
├── ArmorComponent     (Node)       → armor_component.gd  (4 vùng + core)
├── BoostComponent     (Node)       → boost_component.gd
├── ModuleComponent    (Node)       → module_component.gd
├── StatusComponent    (Node)       → status_component.gd
├── Hurtbox            (Area3D)     → hurtbox.gd
├── PickupRadius       (Area3D)
└── CameraRig          (Node3D)     → camera_rig.gd (con của Mech nhưng không xoay theo)
```

**Luật component:**
- Mỗi component sở hữu trạng thái của riêng nó và phát signal cục bộ.
- `mech_controller.gd` nối các component lại nhưng không tự tính toán logic của chúng.
- Component không gọi trực tiếp lẫn nhau — chúng đi qua signal của controller hoặc `EventBus`.
- Mỗi component phải chạy được độc lập trong một scene test rỗng.

## 6. Kiến trúc kẻ địch — QUYẾT ĐỊNH QUAN TRỌNG NHẤT

Chúng ta cần 300+ kẻ địch ở 60 FPS. Node Godot đầy đủ không làm được điều đó. Vì vậy có **hai đường thực thi tách biệt**.

### 6.1 Đường SWARM (data-oriented, không có node)

Quản lý bởi `SwarmManager` (node trong màn, không phải autoload).

Trạng thái lưu trong **mảng song song**, không phải object:

```gdscript
# src/swarm/swarm_manager.gd
const MAX_SWARM_UNITS: int = 400

var _positions:  PackedVector3Array
var _velocities: PackedVector3Array
var _healths:    PackedFloat32Array
var _types:      PackedByteArray      # chỉ số vào bảng SwarmTypeTable
var _states:     PackedByteArray      # bit cờ: sống, đang tấn công, bị choáng...
var _timers:     PackedFloat32Array   # dùng chung cho hồi chiêu tấn công / trạng thái
var _alive_count: int = 0
```

- **Vẽ:** một `MultiMeshInstance3D` cho mỗi loại swarm. Cập nhật transform hàng loạt mỗi frame qua `MultiMesh.set_instance_transform()`. Animation qua vertex shader (offset thời gian theo instance), **không** dùng `AnimationPlayer`.
- **Va chạm:** `SpatialHashGrid` tự viết (`src/core/spatial_hash_grid.gd`), ô lưới 2m. Không dùng Area3D, không dùng PhysicsServer.
- **Di chuyển:** lấy vector từ flow field + lực tách đàn (separation) từ các ô lân cận trong spatial hash.
- **Cập nhật:** một vòng lặp trong `_physics_process`. Nếu profiler cho thấy quá tải, chia theo lô (cập nhật 1/2 số đơn vị mỗi frame xen kẽ) — hành vi swarm chấp nhận được độ trễ này.
- **Chết:** đánh dấu bit không-sống, hoán đổi với phần tử cuối, giảm `_alive_count`. Không cấp phát bộ nhớ.

### 6.2 Đường ACTOR (node đầy đủ)

`CharacterBody3D` với máy trạng thái. Giới hạn cứng **40 đơn vị sống**. Lấy từ `PoolManager`, không bao giờ `instantiate()` trong chiến đấu.

```
ActorEnemy (CharacterBody3D)        → actor_enemy.gd
├── Model (Node3D) + AnimationTree
├── StateMachine (Node)             → ai_state_machine.gd
│   ├── IdleState, ChaseState, AttackState, StaggerState, DeathState...
├── HealthComponent (Node)
├── StatusComponent (Node)
├── Hurtbox (Area3D)
├── Hitbox  (Area3D, tắt mặc định)
└── NavAgent — KHÔNG DÙNG. Actor cũng lấy hướng từ flow field.
```

**Không dùng `NavigationAgent3D` cho việc đuổi bám thông thường.** Flow field đã cho hướng đi rồi và rẻ hơn nhiều. `NavigationAgent3D` chỉ được dùng cho các hành vi hiếm gặp cần đường đi tuỳ ý (ví dụ Stalker vòng ra sau lưng người chơi).

### 6.3 Thăng cấp SWARM → ACTOR

Không có. Một loại kẻ địch là swarm hoặc actor, cố định lúc thiết kế, khai báo trong `EnemyData.execution_path`.

## 7. Flow field pathfinding

`src/ai/flow_field.gd` — một instance cho mỗi màn chơi.

- Lưới 2D trên mặt phẳng XZ, ô **1.5m**, phủ hộp bao của màn đã sinh.
- Mỗi ô lưu: `cost: uint8` (255 = tường), `distance: uint16`, `direction: Vector2i`.
- Tính bằng **Dijkstra/BFS từ vị trí người chơi ra ngoài**, không phải từ mỗi kẻ địch vào.
- Tính lại khi: người chơi di chuyển quá **2 ô**, hoặc mỗi **250ms** — cái nào đến trước.
- Việc tính chạy trong `WorkerThreadPool`, kết quả hoán đổi vào (double buffer). Không bao giờ chặn frame chính.
- Kẻ địch lấy mẫu bằng nội suy song tuyến giữa 4 ô lân cận để hướng đi mượt.
- Bổ sung **flow field thứ hai** cho mục tiêu nhiệm vụ (ví dụ ESCORT: xe khoan) khi cần.

**Lực điều hướng của mỗi đơn vị:**
```
hướng_cuối = normalize(
      flow_field_dir * 1.0
    + separation     * 0.6      # đẩy ra khỏi hàng xóm gần trong spatial hash
    + wall_avoid     * 0.8      # raycast ngắn hoặc gradient trường chi phí
    + tách_ngẫu_nhiên * 0.1     # phá vỡ tính đối xứng, seed theo id đơn vị
)
```

## 8. Sát thương & Chiến đấu

### 8.1 DamageInfo

Không phải Resource (tránh cấp phát). Dùng struct-như-Dictionary có kiểu, tạo từ pool:

```gdscript
# src/combat/damage_info.gd
class_name DamageInfo extends RefCounted

var amount: float
var type: DamageTypes.Type       # KINETIC, ENERGY, EXPLOSIVE, FIRE, ACID, TRUE
var source_position: Vector3
var source_id: int               # id thực thể, không phải tham chiếu node
var knockback: float
var status_to_apply: Array[StringName]
var is_critical: bool
var pierce_remaining: int
```

Instance lấy từ `PoolManager.get_damage_info()` và trả về sau khi xử lý.

### 8.2 Luồng sát thương

```
Vũ khí bắn
   └─► Projectile (pool) hoặc Hitscan raycast
          └─► trúng Hurtbox / spatial hash swarm
                 └─► DamageResolver.resolve(info, target)
                        ├── áp dụng hệ số kháng theo loại
                        ├── áp dụng vùng giáp (chỉ người chơi)
                        ├── áp dụng chí mạng, xuyên
                        ├── EventBus.damage_dealt
                        └── JuiceDirector.on_hit(...)
```

`DamageResolver` là class tĩnh trong `src/combat/damage_resolver.gd`. Là **nơi duy nhất** trong toàn bộ codebase trừ máu. Không có bất kỳ chỗ nào khác được viết `health -= x`.

### 8.3 Projectile

- Tất cả đều **pooled**. `PoolManager` cấp phát trước 600 projectile lúc tải màn.
- Đạn nhanh (> 40 m/s) dùng **raycast theo đoạn di chuyển của frame** để tránh xuyên qua mục tiêu (tunneling), không dựa vào phát hiện va chạm liên tục của engine.
- Projectile là `Node3D` cộng với `MeshInstance3D`, **không phải** `RigidBody3D` hay `Area3D`. Việc phát hiện trúng đích do chính projectile chủ động thực hiện: raycast với actor/thế giới, truy vấn spatial hash với swarm.
- Vũ khí hitscan (Pulse Laser, Rail Lance) bỏ qua hoàn toàn projectile, chỉ dùng raycast + VFX tia.

## 9. Data-driven qua Resource

Mọi nội dung game là `.tres`. Thêm vũ khí mới **không được** đòi hỏi sửa code.

```gdscript
# src/resources/weapon_data.gd
class_name WeaponData extends Resource

@export var id: StringName
@export var display_name_key: String          # khoá dịch, không phải chuỗi thô
@export_enum("KINETIC","ENERGY","EXPLOSIVE","SPECIAL") var category: int
@export var tier: int = 1

@export_group("Sát thương")
@export var damage: float = 10.0
@export var damage_type: DamageTypes.Type
@export var projectiles_per_shot: int = 1
@export var spread_degrees: float = 0.0
@export var pierce_count: int = 0
@export var aoe_radius: float = 0.0

@export_group("Tốc độ & Nhiệt")
@export var rate_of_fire: float = 5.0
@export var heat_per_shot: float = 3.0
@export var charge_time: float = 0.0
@export var spin_up_time: float = 0.0

@export_group("Đạn")
@export var uses_ammo: bool = true
@export var max_ammo: int = 200

@export_group("Trình bày")
@export var model: PackedScene
@export var muzzle_vfx: PackedScene
@export var impact_vfx: PackedScene
@export var fire_sound: AudioStream
@export var projectile_scene: PackedScene      # null = hitscan

@export_group("Nâng cấp")
@export var upgrade_costs: Array[Vector2i]     # (salvage, alloy) cho cấp 2..5
@export var overdrive_effect: StringName
```

Các schema khác (`EnemyData`, `ChassisData`, `ModuleData`, `MissionData`, `WaveTable`, `LootTable`, `PerkData`, `RoomModuleData`, `StatusEffectData`) tuân theo cùng khuôn mẫu: `@export` có kiểu, nhóm rõ ràng, không có logic bên trong Resource ngoài các hàm helper thuần tuý.

**`ContentDB` nạp tất cả lúc khởi động** và cung cấp:
```gdscript
ContentDB.get_weapon(&"wpn_rail_lance") -> WeaponData
ContentDB.get_all_enemies_for_chapter(3) -> Array[EnemyData]
```

## 10. Sinh màn

`src/generation/level_generator.gd`, chạy theo **seed cố định**.

### 10.1 Thuật toán

```
1. Chọn LayoutTemplate theo loại nhiệm vụ (PURGE dùng đồ thị phân nhánh,
   ESCORT dùng hành lang tuyến tính, HOLD dùng trung tâm + vành đai)
2. Đặt phòng SPAWN (điểm đổ bộ)
3. Duyệt đồ thị template: mỗi nút chọn một RoomModule tương thích từ
   res://data/rooms/ch<N>/ khớp về hạng cỡ và số cửa nối
4. Nối bằng scene hành lang, khớp các ConnectionPoint
5. Đặt phòng OBJECTIVE và EXTRACTION
6. Rải điểm sinh quái, két đồ, vật phá được theo mật độ của template
7. Nướng navmesh / trường chi phí flow field
8. KIỂM TRA TÍNH LIÊN THÔNG — BFS từ spawn phải chạm được mọi objective và
   extraction. Thất bại → tăng seed, làm lại (tối đa 20 lần rồi báo lỗi)
9. Phát mission_ready
```

### 10.2 Hợp đồng RoomModule

Mỗi scene phòng phải có:
- Node gốc `RoomModule` (`Node3D`) với script `room_module.gd`
- Một hoặc nhiều node con `ConnectionPoint` (`Marker3D`) có `@export var size: Size` (SMALL/MEDIUM/LARGE) và trục hướng ra ngoài là **−Z cục bộ**
- Một node `SpawnZones` chứa các `Area3D` được gắn nhãn
- Một node `LootAnchors` chứa các `Marker3D`
- `@export var bounds: AABB` đúng, dùng để phát hiện chồng lấn
- Không có script cụ thể-cho-phòng. Phòng là dữ liệu, không phải hành vi.

## 11. Spawn Director

`src/director/spawn_director.gd` — node trong màn.

```gdscript
func _physics_process(delta: float) -> void:
    _budget += _pressure_curve.sample(_mission_time) * _difficulty_mult * delta
    if _budget < _cheapest_cost: return
    if _is_in_anti_frustration_window(): return
    var composition := _wave_table.roll(_mission_time, _budget)
    for entry in composition:
        var point := _pick_spawn_point_out_of_view(entry)
        if point == null: continue
        _spawn(entry.enemy_id, point)
        _budget -= entry.cost
```

- `_pressure_curve` là `Curve` được `@export` trong `MissionData` — người thiết kế chỉnh bằng đồ thị trong editor.
- Điểm sinh phải nằm ngoài **frustum camera** và cách người chơi ít nhất **12m**.
- Bộ đếm sinh quái theo từng loại để tránh dồn quá nhiều một kiểu.

## 12. Hiệu năng — luật bắt buộc

Đây là ràng buộc cứng. Vi phạm là lỗi, không phải chuyện phong cách.

1. **Không `instantiate()` hoặc `queue_free()` trong `MISSION_ACTIVE`.** Mọi thứ đi qua `PoolManager`.
2. **Không cấp phát trong `_process`/`_physics_process`** ở đường nóng. Không tạo `Array`/`Dictionary`/`Vector` mới trong vòng lặp mỗi frame — dùng biến thành viên tái sử dụng.
3. **Không `get_node()` trong `_process`.** Cache tham chiếu node trong `_ready()`, dùng `@onready`.
4. **Không `find_child()` hay duyệt cây khi runtime.** Bao giờ cũng dùng `@export` node path hoặc signal.
5. **Không dùng `Area3D` cho swarm.** Không có ngoại lệ.
6. **Không đổ bóng** cho đèn tạm (muzzle flash, vụ nổ). Chỉ đèn định hướng chính và tối đa 2 đèn điểm chính mới đổ bóng.
7. **Đặt trần số lượng** cho mọi hiệu ứng bề mặt: tối đa 150 decal, 60 xác quái vật lý, 40 damage number cùng lúc. Cái cũ nhất bị thu hồi.
8. **Chạy profiler ở mỗi milestone.** Nếu một milestone làm tụt frame time quá 15%, phải xử lý trước khi sang milestone kế.

**Ngân sách hiệu năng ở 60 FPS (16.6ms):**

| Hệ thống | Ngân sách |
|---|---|
| Cập nhật swarm (300 đơn vị) | 3.0 ms |
| Actor AI (30 đơn vị) | 1.5 ms |
| Projectile + phát hiện va chạm | 1.5 ms |
| Vật lý người chơi + input | 0.5 ms |
| Vẽ hình + cull | 6.0 ms |
| Hiệu ứng hậu kỳ | 2.0 ms |
| UI | 0.8 ms |
| Dự phòng | 1.3 ms |

## 13. Save/Load

- `user://save_slot_<n>.json`, 3 slot, kèm `save_version: int`.
- Lưu: tiến trình chiến dịch, tài nguyên, kho vũ khí và cấp nâng cấp, perk đã mở, thống kê, thiết lập độ khó.
- **Không lưu giữa nhiệm vụ.** Điểm lưu là khi trở về Khoang mech. Thoát giữa nhiệm vụ = mất tiến độ nhiệm vụ đó (chủ ý: giữ áp lực).
- `SaveManager` có hàm `_migrate(data: Dictionary, from_version: int)` — mọi thay đổi schema phải bổ sung một bước migrate.
- Ghi qua file tạm rồi đổi tên nguyên tử, tránh hỏng save.

## 14. Kiểm thử

Framework: **GUT** (`addons/gut`).

Bắt buộc có unit test cho:
- `DamageResolver` — mọi loại sát thương, vùng giáp, xuyên, chí mạng
- `HeatComponent` — tích luỹ, tản, quá nhiệt, xả nhiệt, ảnh hưởng môi trường
- `FlowField` — tính đúng, tường chặn, không có ô mồ côi
- `SpatialHashGrid` — chèn, xoá, truy vấn bán kính
- `LevelGenerator` — với 100 seed cố định, mọi bản đồ đều liên thông
- `SaveManager` — khứ hồi, migrate qua từng phiên bản
- `WaveTable` / `LootTable` — phân phối xác suất nằm trong dung sai

Không bắt buộc test cho: VFX, UI layout, animation.

Chạy: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

## 15. Debug

`DebugConsole` (bật bằng `~`, chỉ trong build debug):

```
god                 bất tử
heat <0-100>        đặt nhiệt
spawn <id> <n>      sinh kẻ địch
give <res> <n>      cộng tài nguyên
weapon <id> <L|R>   gắn vũ khí
noclip
timescale <f>
ff                  hiện flow field dạng lưới mũi tên
hash                hiện ô spatial hash
perf                hiện HUD chi tiết thời gian mỗi hệ thống
seed <n>            sinh lại màn với seed cho trước
mission <id>        nhảy thẳng vào nhiệm vụ
```

## 16. Những thứ CẤM

- Không dùng `Node.call_deferred()` để né lỗi thứ tự thực thi — sửa cho đúng kiến trúc.
- Không dùng biến toàn cục ngoài autoload.
- Không dùng `preload` cho các asset lớn trong script chạy thường xuyên; dùng `ContentDB` hoặc `PoolManager`.
- Không viết chuỗi hiển thị trực tiếp trong code — dùng khoá dịch qua `tr()`.
- Không tạo file `utils.gd` chung chung. Đặt helper vào module đúng phạm vi.
- Không dùng `yield`/`await` trong đường nóng của chiến đấu.
- Không thêm plugin bên thứ ba nếu chưa được chấp thuận rõ ràng (ngoại lệ: GUT).
