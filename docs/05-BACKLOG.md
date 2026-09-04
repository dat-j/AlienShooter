# IRONHIVE — Backlog triển khai

> Đây là hàng đợi công việc cho AI agent. Làm **theo đúng thứ tự**. Không nhảy cóc milestone.
>
> **Định dạng mỗi task:**
> `ID` · tên · **Dep:** phụ thuộc · **File:** file chính bị đụng tới · **DoD:** điều kiện hoàn thành có thể kiểm chứng được
>
> **Luật:** Một task = một commit = một nhánh `feat/<ID>`. Task chưa đạt hết DoD thì chưa xong. Không được báo hoàn thành khi test đỏ.

---

## Bản đồ milestone

| M | Tên | Mục tiêu chốt | Task |
|---|---|---|---|
| M0 | Nền móng | Project chạy, cấu trúc đúng, CI test xanh | T-001 → T-010 |
| M1 | Cảm giác di chuyển | Điều khiển mech thấy "nặng" và đã | T-101 → T-112 |
| M2 | Nhiệt · Boost · Giáp | Ba hệ thống ký tên của game hoạt động | T-201 → T-210 |
| M3 | **Công nghệ swarm** | 300 kẻ địch ở 60 FPS. **Cổng rủi ro lớn nhất** | T-301 → T-312 |
| M4 | Actor AI | Kẻ địch node đầy đủ với máy trạng thái | T-401 → T-410 |
| M5 | Vũ khí & sát thương | Đủ 16 vũ khí, hệ thống sát thương hoàn chỉnh | T-501 → T-512 |
| M6 | Juice | Game "sướng tay" | T-601 → T-609 |
| M7 | Sinh màn | Bản đồ ráp từ module, luôn đi được | T-701 → T-710 |
| M8 | Director & nhiệm vụ | 6 loại nhiệm vụ, đường cong áp lực | T-801 → T-810 |
| M9 | Meta & kinh tế | Khoang mech, shop, perk, kinh tế | T-901 → T-912 |
| M10 | Save, menu, thiết lập | Vòng đời game hoàn chỉnh | T-1001 → T-1009 |
| M11 | Sản xuất nội dung | 18 quái, 45 phòng, 26 nhiệm vụ, 5 chương | T-1101 → T-1118 |
| M12 | Trùm | 5 trùm nhiều phase | T-1201 → T-1206 |
| M13 | Âm thanh | Đủ SFX, nhạc động | T-1301 → T-1308 |
| M14 | Cân bằng & tối ưu | Đạt mục tiêu hiệu năng và độ khó | T-1401 → T-1410 |
| M15 | Chuẩn bị phát hành | Export, bản địa hoá, đánh bóng | T-1501 → T-1508 |

---

## M0 — Nền móng

**T-001** · Khởi tạo project Godot
**Dep:** —
**File:** `project.godot`, `.gitignore`, `.gitattributes`
**DoD:** Project mở được trong Godot 4.4+; renderer là Forward+; `.gitignore` loại trừ `.godot/`, `*.import`, `export/`; project chạy được với một scene rỗng.

**T-002** · Dựng cây thư mục
**Dep:** T-001
**File:** toàn bộ cấu trúc trong `02-TDD.md` §2
**DoD:** Mọi thư mục tồn tại, mỗi thư mục có `.gdignore` hoặc file placeholder để git giữ lại; cấu trúc khớp chính xác với TDD.

**T-003** · Bật kiểu tĩnh và cấu hình linter
**Dep:** T-002
**File:** `project.godot`, `.editorconfig`
**DoD:** Bật `debug/gdscript/warnings/untyped_declaration = 2` (lỗi); project không có cảnh báo nào.

**T-004** · Cài GUT và dựng khung test
**Dep:** T-002
**File:** `addons/gut/`, `tests/test_smoke.gd`
**DoD:** `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` chạy và trả về mã 0 với một test smoke.

**T-005** · Autoload `Log`
**Dep:** T-003
**File:** `src/autoload/log.gd`
*(đổi tên từ `Logger` — xem ghi chú sai lệch ở `02-TDD.md` §4)*
**DoD:** Có các cấp `debug/info/warn/error`; ghi ra `user://logs/` trong build debug; có test bao phủ việc lọc theo cấp.

**T-006** · Autoload `EventBus`
**Dep:** T-005
**File:** `src/autoload/event_bus.gd`
**DoD:** Khai báo đủ mọi signal ở `02-TDD.md` §4.2; không chứa logic; có test khẳng định mọi signal đều tồn tại với đúng chữ ký.

**T-007** · Schema Resource
**Dep:** T-006
**File:** `src/resources/*.gd` (10 file)
**DoD:** `WeaponData`, `EnemyData`, `ChassisData`, `ModuleData`, `StatusEffectData`, `MissionData`, `WaveTable`, `LootTable`, `PerkData`, `RoomModuleData` đều có `class_name`, `@export` đủ kiểu, khớp với GDD; tạo được một `.tres` mẫu cho mỗi loại trong editor.

**T-008** · Autoload `ContentDB`
**Dep:** T-007
**File:** `src/autoload/content_db.gd`
**DoD:** Quét đệ quy `res://data/`, index theo `id`; các hàm `get_weapon/get_enemy/get_chassis/...`; báo lỗi rõ ràng khi trùng id; test với 3 tài nguyên giả.

**T-009** · Autoload `PoolManager`
**Dep:** T-006
**File:** `src/autoload/pool_manager.gd`
**DoD:** Pool chung theo `PackedScene`; `acquire()`/`release()`; cấp phát trước theo cấu hình; đếm được số lượng để debug; test khẳng định không có `instantiate()` nào sau lần cấp phát đầu qua 1.000 chu kỳ acquire/release.

**T-010** · Autoload `GameDirector` + máy trạng thái
**Dep:** T-008, T-009
**File:** `src/autoload/game_director.gd`, `scenes/main/main.tscn`
**DoD:** Máy trạng thái ở `02-TDD.md` §4.1 hoạt động; chuyển cảnh dùng `load_threaded_request`; chuyển được BOOT → MAIN_MENU với scene giữ chỗ; test chuyển trạng thái hợp lệ và chặn chuyển không hợp lệ.

---

## M1 — Cảm giác di chuyển

**T-101** · Scene `Mech.tscn` khung sườn
**Dep:** T-010
**File:** `scenes/player/mech.tscn`, `src/player/mech_controller.gd`
**DoD:** Cây node khớp `02-TDD.md` §5; dùng hình hộp giữ chỗ; scene chạy độc lập được.

**T-102** · Di chuyển nền
**Dep:** T-101
**File:** `src/player/mech_controller.gd`
**DoD:** WASD di chuyển tương đối với camera; tăng/giảm tốc có quán tính (thời gian tăng tốc 0.18s, giảm tốc 0.25s); không trượt nổi trên dốc; `move_and_slide` với `up_direction` đúng.

**T-103** · Tách xoay thân trên / chân
**Dep:** T-102
**File:** `src/player/mech_controller.gd`
**DoD:** Thân trên hướng tức thời về con trỏ chiếu xuống mặt phẳng XZ; chân xoay theo hướng di chuyển với 480°/s; góc lệch tối đa 110° buộc chân xoay theo; giá trị đọc từ `ChassisData`.

**T-104** · `CameraRig`
**Dep:** T-102
**File:** `src/player/camera_rig.gd`
**DoD:** Thông số theo `03-ART-BIBLE.md` §3; lệch theo con trỏ tối đa 4m; nhận offset rung từ `JuiceDirector` (giữ chỗ); không giật khi mech Boost.

**T-105** · Chiếu con trỏ xuống mặt đất
**Dep:** T-104
**File:** `src/player/aim_controller.gd`
**DoD:** Raycast từ camera qua chuột xuống mặt phẳng Y của mech; chính xác ở mọi vị trí màn hình; hoạt động cả với cần analog phải của gamepad (bán kính chết 0.2, chuẩn hoá).

**T-106** · Sơ đồ input & gán phím
**Dep:** T-101
**File:** `project.godot` (input map), `src/autoload/settings_manager.gd`
**DoD:** Toàn bộ hành động ở `01-GDD.md` §1 được khai báo; gamepad và bàn phím cùng ánh xạ vào cùng action; gán lại phím lưu vào `user://settings.cfg` và nạp lại đúng.

**T-107** · Autoload `SettingsManager`
**Dep:** T-005
**File:** `src/autoload/settings_manager.gd`
**DoD:** Đọc/ghi đồ hoạ, âm thanh, gán phím, trợ năng; phát `EventBus.settings_changed`; có giá trị mặc định khi file thiếu hoặc hỏng; test khứ hồi.

**T-108** · Chân bám mặt đất bằng IK
**Dep:** T-103
**File:** `src/player/leg_ik.gd`
**DoD:** Dùng `SkeletonIK3D` hoặc raycast + IK thủ công; hai chân bám bậc thang và dốc; không giật khi đứng yên; tắt được qua thiết lập đồ hoạ.

**T-109** · Nghiêng thân theo gia tốc
**Dep:** T-103
**File:** `src/player/mech_controller.gd`
**DoD:** Thân nghiêng tối đa 6° ngược hướng gia tốc; hồi mượt; cảm giác có khối lượng chứ không phải hoạt hình lò xo.

**T-110** · Máy trạng thái animation mech
**Dep:** T-102
**File:** `scenes/player/mech.tscn` (AnimationTree)
**DoD:** `BlendSpace2D` với các clip đi/lùi/tạt ngang; hoà trộn mượt; tốc độ animation đồng bộ với tốc độ di chuyển thực (không trượt chân).

**T-111** · Scene sân tập
**Dep:** T-102
**File:** `scenes/main/test_arena.tscn`
**DoD:** Phòng 60×60m, có dốc, bậc, cột chắn; bảng debug hiện tốc độ, vị trí, frame time; là scene chính để thử mọi thứ về sau.

**T-112** · Autoload `DebugConsole`
**Dep:** T-111
**File:** `src/autoload/debug_console.gd`
**DoD:** Mở bằng `~` trong build debug; các lệnh ở `02-TDD.md` §15 (những lệnh đã có hệ thống tương ứng); có tự động hoàn thành lệnh; hoàn toàn bị loại khỏi build release.

---

## M2 — Nhiệt · Boost · Giáp

**T-201** · `HeatComponent`
**Dep:** T-101
**File:** `src/player/heat_component.gd`
**DoD:** Toàn bộ luật ở `01-GDD.md` §2; tản nhiệt 40% khi đang bắn; phát `heat_changed`/`overheat_started`/`overheat_ended`; unit test đủ mọi ngưỡng và trạng thái biên.

**T-202** · Trạng thái quá nhiệt
**Dep:** T-201
**File:** `src/player/mech_controller.gd`, `src/player/heat_component.gd`
**DoD:** Ở mức 100: khoá vũ khí, −35% tốc độ, khoá Boost trong 3.0s, nhiệt về 0 khi kết thúc; không kích hoạt lặp; kiểm tra được bằng lệnh `heat 100`.

**T-203** · Xả nhiệt khẩn cấp
**Dep:** T-201
**File:** `src/player/heat_component.gd`
**DoD:** Giữ `R` 0.8s → −60 nhiệt; hồi chiêu 12s; mech đứng yên và nhận +30% sát thương trong lúc xả; huỷ được bằng cách nhả phím.

**T-204** · Bội số nhiệt theo môi trường
**Dep:** T-201
**File:** `src/player/heat_component.gd`, `src/generation/environment_zone.gd`
**DoD:** `Area3D` trong phòng đặt bội số tản nhiệt; bảng ở `01-GDD.md` §2.3; HUD hiển thị bội số đang áp dụng.

**T-205** · `BoostComponent`
**Dep:** T-102, T-201
**File:** `src/player/boost_component.gd`
**DoD:** 7.0m trong 0.18s; i-frame 0.12s ở giữa; tốn 15 nhiệt; hệ thống nạp theo `ChassisData`; không boost xuyên tường (sweep test); gây 12 sát thương cho swarm bị đâm phải (nối sau khi có M3).

**T-206** · `ArmorComponent` 4 vùng
**Dep:** T-101
**File:** `src/player/armor_component.gd`
**DoD:** Phân vùng theo góc tương đối giữa nguồn sát thương và hướng thân mech; vỡ mảng ở 0; nhân ×1.4 vào Core khi vùng đã vỡ; phát `armor_plate_broken`; test đủ 4 vùng và trường hợp biên đúng 45°.

**T-207** · `StatusComponent`
**Dep:** T-007
**File:** `src/combat/status_component.gd`
**DoD:** Áp/gỡ/cộng dồn trạng thái từ `StatusEffectData`; đủ 6 trạng thái ở GDD §9; dùng chung cho cả người chơi và actor; test cộng dồn và hết hạn.

**T-208** · `ChassisData` và 3 khung mech
**Dep:** T-007
**File:** `data/chassis/*.tres`
**DoD:** VESPA-L, RONIN-M, ATLAS-H với đúng số liệu GDD §5; đổi chassis trong sân tập thấy khác biệt rõ ràng về cảm giác.

**T-209** · Thanh nhiệt HUD
**Dep:** T-201
**File:** `scenes/ui/hud/heat_bar.tscn`, `src/ui/heat_bar.gd`
**DoD:** Vòng cung dưới chân mech, di chuyển cùng mech; đổi màu ở ngưỡng 80/95; nhấp nháy khi quá nhiệt; đọc được rõ khi màn hình đầy kẻ địch.

**T-210** · HUD giáp + chỉ báo hướng bị đánh
**Dep:** T-206
**File:** `scenes/ui/hud/armor_display.tscn`
**DoD:** Hình thoi 4 vùng theo `04-UX-UI.md` §2.2; nháy khi trúng; đường đứt khi vỡ; cung đỏ ở mép màn chỉ hướng nguồn tấn công trong 1.2s.

---

## M3 — Công nghệ swarm ★ CỔNG RỦI RO

> Milestone này quyết định game có làm được hay không. **Không sang M4 cho tới khi đo được 300 đơn vị chạy trong ngân sách 3.0ms.**

**T-301** · `SpatialHashGrid`
**Dep:** T-002
**File:** `src/core/spatial_hash_grid.gd`
**DoD:** Ô 2m; `insert/move/remove/query_radius/query_cell_neighbors`; không cấp phát trong truy vấn (dùng buffer kết quả tái sử dụng); unit test đủ; benchmark: 400 đơn vị, 400 truy vấn bán kính, dưới 0.5ms.

**T-302** · `FlowField` — tính toán
**Dep:** T-301
**File:** `src/ai/flow_field.gd`
**DoD:** Lưới ô 1.5m; Dijkstra từ mục tiêu; trường chi phí đọc từ hình học va chạm màn chơi; test: mọi ô đi được đều có hướng dẫn về đích, ô tường có cost 255.

**T-303** · `FlowField` — luồng nền và double buffer
**Dep:** T-302
**File:** `src/ai/flow_field.gd`
**DoD:** Tính trong `WorkerThreadPool`; hoán đổi buffer nguyên tử; tính lại khi người chơi đi quá 2 ô hoặc mỗi 250ms; không tăng frame time nào đo được ở luồng chính; bật hiển thị debug bằng lệnh `ff`.

**T-304** · Bộ khung `SwarmManager`
**Dep:** T-301
**File:** `src/swarm/swarm_manager.gd`
**DoD:** Mảng song song theo `02-TDD.md` §6.1; `spawn/kill/get_alive_count`; hoán đổi-với-cuối khi chết; không cấp phát sau khi khởi tạo; test 10.000 chu kỳ sinh/diệt không tăng bộ nhớ.

**T-305** · Vẽ swarm bằng MultiMesh
**Dep:** T-304
**File:** `src/swarm/swarm_renderer.gd`
**DoD:** Một `MultiMeshInstance3D` cho mỗi loại; cập nhật transform hàng loạt; cull đúng; 300 đơn vị chỉ tốn 1 draw call cho mỗi loại.

**T-306** · Shader animation swarm
**Dep:** T-305
**File:** `assets/materials/swarm_crawl.gdshader`
**DoD:** Dao động theo `INSTANCE_ID` như `03-ART-BIBLE.md` §7; không có hai con trùng pha; chi phí GPU không đáng kể; hoạt động với instance color để đổi biến thể.

**T-307** · Điều hướng swarm
**Dep:** T-303, T-304
**File:** `src/swarm/swarm_movement.gd`
**DoD:** Công thức lực ở `02-TDD.md` §7; các con không chồng lên nhau; không kẹt ở góc tường; tạo được thành dòng chảy tự nhiên khi qua cửa hẹp.

**T-308** · Tấn công và va chạm của swarm
**Dep:** T-307
**File:** `src/swarm/swarm_combat.gd`
**DoD:** Đơn vị trong tầm cận chiến gây sát thương theo hồi chiêu; truy vấn qua spatial hash chứ không qua physics; đẩy lùi khi người chơi Boost xuyên qua.

**T-309** · Nhận sát thương cho swarm
**Dep:** T-304
**File:** `src/swarm/swarm_manager.gd`
**DoD:** Hàm `damage_at_point(pos, radius, dmg)` và `damage_along_ray(from, to, dmg, pierce)`; xử lý xuyên và sát thương vùng; chết sinh VFX từ pool.

**T-310** · Cập nhật swarm theo lô
**Dep:** T-307
**File:** `src/swarm/swarm_manager.gd`
**DoD:** Cấu hình được số lô (1/2/4); ở 4 lô, hành vi vẫn chấp nhận được; giảm chi phí mỗi frame tỉ lệ thuận.

**T-311** · Cảnh kiểm chuẩn hiệu năng
**Dep:** T-310
**File:** `scenes/main/perf_swarm.tscn`, `tools/perf_report.gd`
**DoD:** Sinh 300 đơn vị đuổi người chơi; HUD hiện thời gian mỗi hệ thống; xuất báo cáo CSV; **cổng nghiệm thu: cập nhật swarm ≤ 3.0ms, tổng frame ≤ 16.6ms trên máy tham chiếu.**

**T-312** · Ba loại swarm đầu tiên
**Dep:** T-311
**File:** `data/enemies/enm_crawler.tres`, `enm_skitter.tres`, `enm_husk.tres`
**DoD:** Số liệu theo GDD §8.2; hành vi nhảy của Skitter hoạt động; ba loại phân biệt được bằng hình bóng và tốc độ; chạy chung mà vẫn đạt ngân sách hiệu năng.

---

## M4 — Actor AI

**T-401** · Scene cơ sở `ActorEnemy`
**Dep:** T-009, T-303
**File:** `scenes/enemies/actors/actor_base.tscn`, `src/ai/actor_enemy.gd`
**DoD:** Cây node theo `02-TDD.md` §6.2; nạp chỉ số từ `EnemyData`; lấy từ pool; không dùng `NavigationAgent3D`.

**T-402** · `AIStateMachine`
**Dep:** T-401
**File:** `src/ai/ai_state_machine.gd`, `src/ai/states/*.gd`
**DoD:** Trạng thái làm node con; `enter/exit/physics_update`; các trạng thái cơ sở Idle/Chase/Attack/Stagger/Death; chuyển trạng thái ghi log được; test chuyển trạng thái.

**T-403** · Actor di chuyển theo flow field
**Dep:** T-402, T-303
**File:** `src/ai/states/chase_state.gd`
**DoD:** Lấy mẫu flow field nội suy; tách khỏi actor khác; tránh tường; không rung lắc khi tới gần mục tiêu.

**T-404** · Hệ thống Hitbox/Hurtbox
**Dep:** T-007
**File:** `src/combat/hitbox.gd`, `src/combat/hurtbox.gd`
**DoD:** Hitbox chỉ bật trong cửa sổ animation; lớp va chạm khai báo trong một enum duy nhất; không đánh trúng cùng mục tiêu hai lần một đòn.

**T-405** · Cận chiến của actor
**Dep:** T-404
**File:** `src/ai/states/attack_state.gd`
**DoD:** Chuỗi ngắm → vung → hồi có thời lượng đọc từ `EnemyData`; có tín hiệu báo trước (telegraph) rõ ràng; huỷ đòn được khi bị choáng.

**T-406** · Tấn công tầm xa của actor
**Dep:** T-404
**File:** `src/ai/states/ranged_attack_state.gd`
**DoD:** Ngắm có thời gian, có tia laser báo trước; dùng projectile từ pool; giữ khoảng cách ưa thích và tránh đứng chồng nhau.

**T-407** · Phản ứng trúng đòn và choáng
**Dep:** T-402
**File:** `src/ai/states/stagger_state.gd`
**DoD:** Ngưỡng choáng theo `EnemyData`; animation phản ứng; miễn nhiễm choáng có thời gian hồi để tránh khoá cứng vĩnh viễn.

**T-408** · Sáu actor đầu tiên
**Dep:** T-405, T-406
**File:** `data/enemies/*.tres`, `scenes/enemies/actors/*.tscn`
**DoD:** Ravager, Bulwark, Spitter, Detonator, Pulsar, Hive Node theo GDD §8.2; giáp trước của Bulwark hoạt động; Detonator nổ đúng; Pulsar hồi máu cho đồng minh; Hive Node sinh Crawler.

**T-409** · Nhận biết và chọn mục tiêu
**Dep:** T-403
**File:** `src/ai/perception.gd`
**DoD:** Tầm nhận biết, kiểm tra tầm nhìn (chỉ khi cần); actor bên ngoài tầm nhận biết đi vào chế độ ngủ rẻ tiền; ngân sách CPU cho AI ≤ 1.5ms với 30 actor.

**T-410** · Giới hạn số actor và ưu tiên
**Dep:** T-409
**File:** `src/director/actor_budget.gd`
**DoD:** Trần cứng 40; khi đầy, thu hồi actor xa nhất ngoài tầm nhìn thay vì từ chối sinh; không bao giờ thu hồi actor người chơi đang nhìn thấy.

---

## M5 — Vũ khí & Sát thương

**T-501** · `DamageInfo` và pool
**Dep:** T-009
**File:** `src/combat/damage_info.gd`
**DoD:** Trường theo `02-TDD.md` §8.1; lấy/trả về pool; không cấp phát trong chiến đấu; test 10.000 lần lấy/trả không tăng bộ nhớ.

**T-502** · `DamageResolver`
**Dep:** T-501, T-206, T-207
**File:** `src/combat/damage_resolver.gd`
**DoD:** Là **nơi duy nhất** trừ máu trong toàn codebase (kiểm chứng bằng `grep`); xử lý loại sát thương, kháng, vùng giáp, chí mạng, xuyên; unit test bao phủ mọi loại và trường hợp biên.

**T-503** · `WeaponMount` và bắn
**Dep:** T-201, T-502
**File:** `src/player/weapon_mount.gd`
**DoD:** Bắn trái/phải độc lập; tốc bắn, sạc, quay nòng theo `WeaponData`; cộng nhiệt; trừ đạn; khoá khi quá nhiệt; hai mount hoạt động đồng thời không xung đột.

**T-504** · Projectile pooled
**Dep:** T-009, T-502
**File:** `src/combat/projectile.gd`
**DoD:** `Node3D` + `MeshInstance3D`, **không** RigidBody/Area; raycast theo đoạn di chuyển mỗi frame; xuyên; sát thương vùng; trả về pool khi hết đời; test bắn 5.000 viên không rò rỉ.

**T-505** · Vũ khí hitscan
**Dep:** T-503
**File:** `src/combat/hitscan.gd`
**DoD:** Raycast tức thời cả với actor và spatial hash swarm; VFX tia; xuyên nhiều mục tiêu theo thứ tự khoảng cách.

**T-506** · Vũ khí hình nón/liên tục
**Dep:** T-503
**File:** `src/combat/cone_weapon.gd`
**DoD:** Flamer và Cryo; truy vấn hình nón vào spatial hash; sát thương theo tick chứ không mỗi frame; áp trạng thái; Cryo **giảm** nhiệt của mech (giá trị âm).

**T-507** · Sát thương vùng và tự sát thương
**Dep:** T-502
**File:** `src/combat/aoe.gd`
**DoD:** Suy giảm theo khoảng cách; tự gây sát thương cho người chơi khi trong bán kính tối thiểu; không đánh xuyên tường (kiểm tra tầm nhìn); tối ưu bằng truy vấn spatial hash.

**T-508** · 16 tài nguyên vũ khí
**Dep:** T-504, T-505, T-506
**File:** `data/weapons/*.tres` (16 file)
**DoD:** Toàn bộ bảng GDD §6.2 với đúng số liệu; mỗi vũ khí bắn được trong sân tập; DPS đo được khớp bảng trong sai số 5%.

**T-509** · Hệ thống đạn và tiếp đạn
**Dep:** T-503
**File:** `src/player/weapon_mount.gd`
**DoD:** Đạn tối đa từ `WeaponData`; hộp đạn rơi ra cộng đạn; vũ khí Energy bỏ qua hoàn toàn; HUD hiện đúng, hiện "NĂNG LƯỢNG" cho vũ khí không đạn.

**T-510** · Nâng cấp vũ khí
**Dep:** T-508
**File:** `src/progression/weapon_upgrades.gd`
**DoD:** 5 cấp theo GDD §6.4; cộng dồn đúng; Overdrive ở cấp 5 gọi đúng hàm hiệu ứng riêng của từng vũ khí.

**T-511** · HUD vũ khí
**Dep:** T-509
**File:** `scenes/ui/hud/weapon_display.tscn`
**DoD:** Hai ô trái/phải theo `04-UX-UI.md` §2; hiện tên, đạn, trạng thái sạc/quay nòng; nháy đỏ khi hết đạn.

**T-512** · Con trỏ ngắm tuỳ chỉnh
**Dep:** T-105, T-503
**File:** `scenes/ui/hud/crosshair.tscn`
**DoD:** Đủ hành vi ở `04-UX-UI.md` §2.3; co giãn theo độ tản đạn; hit marker phân biệt thường/chí mạng; ẩn con trỏ hệ điều hành.

---

## M6 — Juice

**T-601** · Autoload `JuiceDirector`
**Dep:** T-107
**File:** `src/autoload/juice_director.gd`
**DoD:** API `shake(amp, dur)`, `hitstop(dur)`, `rumble(l, r, dur)`, `chromatic(amount)`; nhân với thanh trượt trợ năng; nhiều lệnh rung cộng dồn chứ không ghi đè.

**T-602** · Rung màn hình
**Dep:** T-601, T-104
**File:** `src/autoload/juice_director.gd`, `src/player/camera_rig.gd`
**DoD:** Rung dựa trên nhiễu Perlin (không phải ngẫu nhiên trắng); tắt dần mượt; cộng vào vị trí bám chứ không thay thế; bảng tham số ở `03-ART-BIBLE.md` §9.

**T-603** · Hitstop
**Dep:** T-601
**File:** `src/autoload/juice_director.gd`
**DoD:** `Engine.time_scale` giảm rồi hồi; không ảnh hưởng UI và âm nhạc; nhiều hitstop không cộng dồn thành đứng hình; tắt được.

**T-604** · Muzzle flash và vỏ đạn
**Dep:** T-503, T-009
**File:** `scenes/vfx/muzzle_flash.tscn`, `src/combat/shell_ejector.gd`
**DoD:** Chớp sáng 0.08s có đèn không đổ bóng; vỏ đạn `RigidBody3D` pooled, trần 60, có âm thanh chạm sàn; đèn tạm không vượt trần 12.

**T-605** · VFX trúng đích và xác quái
**Dep:** T-502, T-009
**File:** `scenes/vfx/impact_*.tscn`, `src/combat/gib_manager.gd`
**DoD:** Trúng kim loại/thịt khác nhau; mảnh xác pooled trần 60, tan sau 6s; diệt swarm hàng loạt không tạo bão hạt (gộp lại khi trên 10 con chết cùng frame).

**T-606** · Hệ thống decal
**Dep:** T-605
**File:** `src/vfx/decal_manager.gd`
**DoD:** Node `Decal` pooled; trần 150 FIFO; máu, cháy, vết đạn; chiếu đúng lên sàn và tường; trần điều chỉnh được theo preset đồ hoạ.

**T-607** · Damage number
**Dep:** T-502
**File:** `scenes/ui/damage_number.tscn`, `src/ui/damage_number_pool.gd`
**DoD:** Pooled trần 40; trôi lên và mờ; chí mạng to hơn màu vàng; **gộp sát thương swarm**; tắt được trong thiết lập.

**T-608** · VFX nhiệt và giáp
**Dep:** T-201, T-206
**File:** `scenes/vfx/vent_steam.tscn`, `scenes/vfx/plate_break.tscn`
**DoD:** Hơi phụt khi xả nhiệt đọc rõ ràng; ánh đỏ trên thân khi quá nhiệt (qua tham số shader); mảng giáp rơi ra khi vỡ.

**T-609** · Kiểm định cảm giác bắn
**Dep:** T-601 → T-608
**File:** `docs/playtest/feel_pass_01.md`
**DoD:** Ghi video 60s bắn mỗi vũ khí trong sân tập; ghi lại đánh giá chủ quan; điều chỉnh bảng juice; **cổng nghiệm thu: bắn MK2 Autocannon vào 50 Crawler phải thấy đã tay mà không cần nhìn số.**

---

## M7 — Sinh màn

**T-701** · Hợp đồng `RoomModule`
**Dep:** T-007
**File:** `src/generation/room_module.gd`, `scenes/rooms/_template.tscn`
**DoD:** Đúng theo `02-TDD.md` §10.2; template có mọi node bắt buộc; script kiểm tra trong editor (`@tool`) cảnh báo khi thiếu ConnectionPoint hoặc sai AABB.

**T-702** · `LayoutTemplate`
**Dep:** T-701
**File:** `src/resources/layout_template.gd`, `data/layouts/*.tres`
**DoD:** Mô tả đồ thị (nút, cạnh, ràng buộc kích cỡ); một template cho mỗi loại nhiệm vụ; sửa được trong editor.

**T-703** · `LevelGenerator` — đặt phòng
**Dep:** T-702
**File:** `src/generation/level_generator.gd`
**DoD:** Thuật toán bước 1–5 ở `02-TDD.md` §10.1; phát hiện chồng lấn bằng AABB; seed cố định cho kết quả tái lập được.

**T-704** · Nối hành lang
**Dep:** T-703
**File:** `src/generation/corridor_builder.gd`
**DoD:** Khớp ConnectionPoint đúng hướng và kích cỡ; hành lang co giãn được; không có khe hở hoặc mặt đâm xuyên nhau.

**T-705** · Kiểm tra tính liên thông
**Dep:** T-704
**File:** `src/generation/connectivity_validator.gd`
**DoD:** BFS từ spawn; mọi mục tiêu và điểm rút phải chạm được; thất bại thì tăng seed thử lại (tối đa 20); **test: 100 seed cố định × 6 layout, 100% sinh ra bản đồ hợp lệ.**

**T-706** · Nướng flow field và navmesh
**Dep:** T-705, T-302
**File:** `src/generation/level_generator.gd`
**DoD:** Trường chi phí sinh từ hình học màn đã ráp; xong trong 400ms cho bản đồ lớn nhất; hiển thị debug khớp với hình học thực.

**T-707** · Rải điểm sinh quái và loot
**Dep:** T-705
**File:** `src/generation/spawn_placer.gd`
**DoD:** Dùng `SpawnZones` và `LootAnchors` của từng phòng; mật độ theo template; điểm sinh không nằm sát điểm rút; két đồ không sinh trong tường.

**T-708** · Vùng môi trường
**Dep:** T-204, T-707
**File:** `src/generation/environment_zone.gd`
**DoD:** Phòng khai báo được bội số nhiệt, trọng lực, tầm nhìn; áp dụng khi người chơi vào; HUD hiện chỉ báo.

**T-709** · 9 phòng mẫu cho chương 1
**Dep:** T-701
**File:** `scenes/rooms/ch1/*.tscn` (9 file)
**DoD:** 3 nhỏ, 4 vừa, 2 lớn; đủ ConnectionPoint mọi hướng; ánh sáng nướng sẵn; ghép được với nhau ở mọi tổ hợp mà generator sinh ra.

**T-710** · Bản đồ Tab
**Dep:** T-705
**File:** `scenes/ui/hud/tactical_map.tscn`
**DoD:** Theo `04-UX-UI.md` §6; sinh từ dữ liệu phòng; game **không dừng** khi mở; hiện mục tiêu và két chưa mở.

---

## M8 — Director & Nhiệm vụ

**T-801** · `WaveTable`
**Dep:** T-007
**File:** `src/resources/wave_table.gd`, `data/wave_tables/*.tres`
**DoD:** Trọng số theo thời gian nhiệm vụ và ngân sách; hàm `roll()` trả về thành phần đợt; test phân phối nằm trong dung sai ±10% qua 10.000 lần quay.

**T-802** · `SpawnDirector`
**Dep:** T-801, T-410, T-707
**File:** `src/director/spawn_director.gd`
**DoD:** Vòng lặp ngân sách theo `02-TDD.md` §11; đường cong áp lực từ `MissionData`; chi phí theo loại quái đúng GDD §10.3.

**T-803** · Chọn điểm sinh ngoài tầm nhìn
**Dep:** T-802
**File:** `src/director/spawn_point_selector.gd`
**DoD:** Ngoài frustum camera và cách ≥12m; dự phòng khi không có điểm hợp lệ (chờ chứ không sinh trước mặt); test không bao giờ sinh trong tầm nhìn.

**T-804** · Luật chống ức chế
**Dep:** T-802
**File:** `src/director/spawn_director.gd`
**DoD:** Đủ luật ở GDD §10.3; nghỉ tối thiểu 8s sau cao trào; giảm 25% ngân sách khi người chơi dưới 30% máu; ghi log quyết định để tinh chỉnh.

**T-805** · Hệ thống mục tiêu nhiệm vụ
**Dep:** T-006
**File:** `src/director/objective_system.gd`, `src/resources/objective_data.gd`
**DoD:** Mục tiêu dạng dữ liệu (giết N, giữ T giây, tới điểm, bảo vệ thực thể, mang vật phẩm); phát `objective_updated`; hỗ trợ mục tiêu chuỗi và song song.

**T-806** · Sáu loại nhiệm vụ
**Dep:** T-805, T-802
**File:** `src/director/mission_types/*.gd`
**DoD:** PURGE, HOLD, RETRIEVE, ESCORT, HUNT, EXTRACT theo GDD §10.1; mỗi loại có đường cong áp lực riêng; chơi được từ đầu đến cuối.

**T-807** · AI xe khoan cho ESCORT
**Dep:** T-806, T-303
**File:** `src/director/escort_vehicle.gd`
**DoD:** Đi theo đường định sẵn; dừng khi bị tấn công hoặc người chơi ở quá xa; có máu riêng; thua nhiệm vụ khi xe bị phá.

**T-808** · Điều kiện thắng/thua
**Dep:** T-805
**File:** `src/director/mission_controller.gd`
**DoD:** Phát `mission_completed`/`mission_failed`; thu thập thống kê (số diệt, độ chính xác, thời gian, số lần quá nhiệt); chuyển sang trạng thái DEBRIEF.

**T-809** · HUD mục tiêu
**Dep:** T-805
**File:** `scenes/ui/hud/objective_display.tscn`
**DoD:** Trên giữa màn theo `04-UX-UI.md` §2; cập nhật tiến độ có hoạt hình; đồng hồ đếm ngược khi liên quan.

**T-810** · Bốn nhiệm vụ chương 1
**Dep:** T-806, T-709
**File:** `data/missions/ch1_*.tres`
**DoD:** Mở đầu + 3 nhiệm vụ dùng các loại khác nhau; chơi được liên tục; thời lượng khớp GDD §10.1 trong sai số ±20%.

---

## M9 — Meta & Kinh tế

**T-901** · Hệ thống tài nguyên
**Dep:** T-006
**File:** `src/progression/resource_wallet.gd`
**DoD:** 4 loại tài nguyên GDD §11.1; cộng/trừ có kiểm tra; phát `resource_gained`; không bao giờ âm.

**T-902** · `LootTable` và rơi đồ
**Dep:** T-007, T-901
**File:** `src/resources/loot_table.gd`, `src/progression/loot_spawner.gd`
**DoD:** Xác suất theo GDD §11.2; **luật thả đồ thích ứng** hoạt động; đồ rơi ra được pooled; test phân phối.

**T-903** · Nhặt đồ
**Dep:** T-902
**File:** `src/progression/pickup.gd`
**DoD:** Tự hút trong bán kính (chỉnh bởi module Salvage Magnet); hoạt ảnh bay về mech; âm thanh riêng theo loại; không rớt đồ khi quá nhiều cùng lúc.

**T-904** · Màn hình Khoang mech
**Dep:** T-901
**File:** `scenes/ui/hangar/hangar.tscn`, `src/ui/hangar_controller.gd`
**DoD:** Bố cục theo `04-UX-UI.md` §3; mech 3D xoay được và **cập nhật tức thì** khi đổi trang bị; điều hướng bằng cả chuột và gamepad.

**T-905** · Xưởng vũ khí
**Dep:** T-510, T-904
**File:** `scenes/ui/hangar/weapon_shop.tscn`
**DoD:** Mua vũ khí, nâng cấp 5 cấp; so sánh chỉ số với vũ khí đang lắp; chặn khi không đủ tài nguyên với phản hồi rõ ràng.

**T-906** · Nâng cấp chassis
**Dep:** T-208, T-904
**File:** `scenes/ui/hangar/chassis_upgrade.tscn`
**DoD:** Mở khoá chassis mới; nâng cấp Armor/nhiệt/tốc độ theo bậc; chi phí Alloy và Ascendant Core đúng.

**T-907** · Cây perk phi công
**Dep:** T-904
**File:** `src/progression/perk_system.gd`, `scenes/ui/hangar/perk_tree.tscn`
**DoD:** 24 perk 3 nhánh GDD §12; điểm perk từ lên cấp; hiệu ứng perk áp dụng vào mọi hệ thống liên quan; tẩy điểm được (có phí).

**T-908** · XP và lên cấp
**Dep:** T-907
**File:** `src/progression/pilot_progression.gd`
**DoD:** 30 cấp, đường cong XP có công thức rõ ràng; điểm thưởng ở cấp 10/20/30; thông báo lên cấp trong nhiệm vụ không che tầm nhìn.

**T-909** · Nghiên cứu bằng Bio-Sample
**Dep:** T-904
**File:** `scenes/ui/hangar/research.tscn`
**DoD:** Mở khoá tier vũ khí và module; điều kiện tiên quyết theo cây; hiện rõ mở ra cái gì tiếp theo.

**T-910** · Màn hình Chọn trang bị
**Dep:** T-905, T-906
**File:** `scenes/ui/hangar/loadout.tscn`
**DoD:** Đủ nội dung `04-UX-UI.md` §4; **cảnh báo tình báo** liệt kê kẻ địch sẽ gặp; ô tiêu hao mua được.

**T-911** · Màn hình Tổng kết
**Dep:** T-808, T-901
**File:** `scenes/ui/debrief.tscn`
**DoD:** Bố cục và nhịp điệu theo `04-UX-UI.md` §5; từng dòng xuất hiện có âm thanh riêng; thưởng phong cách được tính đúng.

**T-912** · Sửa chữa và chi phí
**Dep:** T-901, T-904
**File:** `src/progression/repair_system.gd`
**DoD:** Giáp hư hại giữ nguyên giữa các nhiệm vụ; chi phí sửa tỉ lệ với mức hư hại; xuất kích với giáp chưa sửa được phép (có cảnh báo).

---

## M10 — Save, Menu, Thiết lập

**T-1001** · Autoload `SaveManager`
**Dep:** T-901, T-907
**File:** `src/autoload/save_manager.gd`
**DoD:** JSON có phiên bản trong `user://`; 3 slot; ghi qua file tạm rồi đổi tên nguyên tử; test khứ hồi đầy đủ mọi trường tiến trình.

**T-1002** · Migrate save
**Dep:** T-1001
**File:** `src/autoload/save_manager.gd`
**DoD:** Hàm `_migrate()`; test nạp save phiên bản cũ giả lập lên phiên bản hiện tại; save hỏng không làm crash mà báo lỗi thân thiện.

**T-1003** · Menu chính
**Dep:** T-010, T-1001
**File:** `scenes/ui/menus/main_menu.tscn`
**DoD:** Luồng theo `04-UX-UI.md` §1; nút Tiếp tục ẩn khi chưa có save; điều hướng gamepad đầy đủ.

**T-1004** · Menu tạm dừng
**Dep:** T-1003
**File:** `scenes/ui/menus/pause_menu.tscn`
**DoD:** Dừng đúng cách (`get_tree().paused`) mà autoload thiết yếu vẫn chạy; có Tiếp tục / Thiết lập / Bỏ nhiệm vụ; xác nhận trước khi bỏ.

**T-1005** · Menu thiết lập
**Dep:** T-107
**File:** `scenes/ui/menus/settings_menu.tscn`
**DoD:** 4 tab theo `04-UX-UI.md` §7; mọi thay đổi áp dụng ngay; preset đồ hoạ đổi đúng các thông số kèm theo, gồm cả trần mật độ swarm.

**T-1006** · Menu gán phím
**Dep:** T-106, T-1005
**File:** `scenes/ui/menus/keybind_menu.tscn`
**DoD:** Gán lại mọi action; phát hiện xung đột; khôi phục mặc định; gán được cả nút gamepad.

**T-1007** · Tuỳ chọn trợ năng
**Dep:** T-601, T-1005
**File:** `scenes/ui/menus/settings_menu.tscn`
**DoD:** Đủ mục ở `03-ART-BIBLE.md` §12; mỗi tuỳ chọn thực sự có tác dụng (kiểm chứng bằng tay từng cái).

**T-1008** · Màn hình tải
**Dep:** T-010
**File:** `scenes/ui/loading_screen.tscn`
**DoD:** Hiện tiến độ thật từ `load_threaded_get_status`; mẹo chơi xoay vòng; không đứng hình trên 100ms.

**T-1009** · Nhật ký và sưu tầm
**Dep:** T-904
**File:** `scenes/ui/hangar/codex.tscn`
**DoD:** Mục kẻ địch mở khoá khi giết đủ 10 con; ghi âm cốt truyện nhặt được trong màn; đọc lại được.

---

## M11 — Sản xuất nội dung

> Từ đây trở đi phần lớn là công việc lặp lại có khuôn mẫu. Mỗi task đều đã có hệ thống sẵn — chỉ tạo dữ liệu và scene.

**T-1101 → T-1104** · Chương 2: 9 phòng · 5 nhiệm vụ · 3 quái mới (Bulwark, Detonator, Pulsar hoàn thiện) · môi trường nhiệt cao
**T-1105 → T-1108** · Chương 3: 9 phòng · 5 nhiệm vụ · 4 quái mới (Lancer, Burrower, Weaver, Bloated) · môi trường tầm nhìn kém
**T-1109 → T-1112** · Chương 4: 9 phòng · 5 nhiệm vụ · 4 quái mới (Stalker, Sentinel, Screamer, Drone Swarm) · chân không + trọng lực thấp
**T-1113 → T-1116** · Chương 5: 9 phòng · 5 nhiệm vụ · 1 quái mới (Warden) · môi trường hữu cơ
**T-1117** · 14 module (data + hiệu ứng) — GDD §7
**T-1118** · Kiểm định nội dung: chơi hết 26 nhiệm vụ, ghi lỗi và điểm nhàm chán

**DoD chung cho mỗi task chương:** phòng ghép được mọi tổ hợp; nhiệm vụ chơi trọn vẹn; quái mới có tín hiệu báo trước rõ ràng và trả lời được câu hỏi "nó buộc người chơi đổi hành vi gì"; đạt ngân sách hiệu năng với mật độ cao nhất của chương đó.

---

## M12 — Trùm

**T-1201** · Khung trùm (`BossBase`)
**Dep:** T-402
**File:** `src/ai/boss_base.gd`, `scenes/enemies/bosses/boss_base.tscn`
**DoD:** Máy trạng thái nhiều phase; thanh máu trùm có phân đoạn phase; miễn nhiễm choáng có kiểm soát; nhạc riêng khởi động và kết thúc.

**T-1202 → T-1206** · Năm trùm theo GDD §8.3
**DoD mỗi trùm:** đủ số phase; mỗi phase có cơ chế riêng biệt; mọi đòn đều có telegraph; đánh bại được bằng mọi chassis; thời lượng 2–5 phút; không có phase nào chỉ là "bắn cho hết máu".

---

## M13 — Âm thanh

**T-1301** · Bus và `AudioDirector`
**Dep:** T-107
**File:** `src/autoload/audio_director.gd`
**DoD:** Cấu trúc bus `03-ART-BIBLE.md` §10; giới hạn instance theo bus; ưu tiên theo khoảng cách; ducking khi cảnh báo nhiệt.

**T-1302** · SFX vũ khí (16 bộ)
**Dep:** T-1301, T-508
**File:** `assets/audio/sfx/weapons/`
**DoD:** Mỗi vũ khí có 3 lớp (transient/thân/đuôi); biến thiên cao độ ±4%; có nội dung dưới 120 Hz rõ ràng.

**T-1303** · SFX kẻ địch + gộp âm swarm
**Dep:** T-1301, T-304
**File:** `src/swarm/swarm_audio.gd`
**DoD:** **Một** âm đám đông cho toàn bộ swarm, điều chế theo số lượng và khoảng cách; actor có âm riêng; không bao giờ vượt giới hạn instance.

**T-1304** · SFX mech (nhiệt, boost, giáp, bước chân)
**T-1305** · SFX giao diện và phản hồi
**T-1306** · Âm thanh môi trường theo chương
**T-1307** · Nhạc động 3 tầng
**Dep:** T-802
**DoD:** Tầng chuyển theo áp lực Director; crossfade ở ranh giới ô nhịp; không có chuyển tiếp nào nghe gượng.
**T-1308** · Trộn âm tổng thể
**DoD:** Không clip ở mức lớn nhất; thoại/cảnh báo luôn nghe rõ; kiểm tra trên loa laptop, tai nghe, và hệ 2.1.

---

## M14 — Cân bằng & Tối ưu

**T-1401** · Công cụ mô phỏng cân bằng
**File:** `tools/balance_sim/`
**DoD:** Chạy headless, mô phỏng DPS/TTK cho mọi cặp vũ khí × kẻ địch; xuất bảng CSV; đánh dấu ngoại lệ vượt 25% so với trung vị cùng tier.

**T-1402** · Pass cân bằng vũ khí — không vũ khí nào trội hoặc vô dụng ở mọi tình huống
**T-1403** · Pass cân bằng kẻ địch — TTK trong khoảng mục tiêu ở mọi tier
**T-1404** · Pass cân bằng kinh tế — khớp đường cong thu nhập GDD §11.3
**T-1405** · Pass đường cong độ khó — 5 mức GDD §13, playtest mỗi mức ít nhất một chương
**T-1406** · Profiler pass: CPU — mọi hệ thống trong ngân sách `02-TDD.md` §12
**T-1407** · Profiler pass: GPU — 60 FPS ở 1080p Medium trên GPU tham chiếu
**T-1408** · Kiểm tra rò rỉ bộ nhớ — chơi 60 phút, RAM tăng dưới 15%
**T-1409** · Kiểm toán pool — `grep` khẳng định không có `instantiate()`/`queue_free()` nào trong code đường chiến đấu
**T-1410** · Tối ưu thời gian tải — mỗi nhiệm vụ dưới 4 giây từ SSD

---

## M15 — Chuẩn bị phát hành

**T-1501** · Preset export Windows và Linux, có icon và metadata
**T-1502** · Loại bỏ hoàn toàn công cụ debug khỏi build release
**T-1503** · Hoàn thiện bản địa hoá tiếng Việt và tiếng Anh, rà soát toàn bộ chuỗi
**T-1504** · Ghi công đầy đủ, gồm giấy phép mọi asset bên thứ ba
**T-1505** · Màn hình bắt đầu, cảnh báo động kinh, cảnh báo nội dung
**T-1506** · Kiểm thử trên máy sạch, cả hai nền tảng
**T-1507** · Playtest cuối, tối thiểu 5 người chơi ngoài, ghi lại quan sát
**T-1508** · Sửa lỗi từ playtest, đóng băng tính năng

---

## Định nghĩa Hoàn thành (chung cho mọi task)

Một task chỉ được coi là xong khi **tất cả** các điều sau đúng:

1. Đạt toàn bộ DoD riêng của task
2. Không có cảnh báo hay lỗi nào trong Godot
3. Mọi biến, tham số, giá trị trả về đều có kiểu tĩnh
4. Bộ test hiện có vẫn xanh (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`)
5. Có test mới nếu task tạo ra logic thuộc danh sách bắt buộc test ở `02-TDD.md` §14
6. Không vi phạm luật hiệu năng ở `02-TDD.md` §12
7. Không vi phạm mục CẤM ở `02-TDD.md` §16
8. Scene liên quan mở và chạy độc lập được, không lỗi
9. Số liệu khớp `01-GDD.md`; nếu cố ý lệch, đã ghi vào Nhật ký cân bằng
10. Commit một dòng tiêu đề dạng `<ID>: mô tả ngắn`
