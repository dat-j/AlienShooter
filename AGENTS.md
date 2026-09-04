# AGENTS.md — Luật làm việc trên dự án IRONHIVE

> File này áp dụng cho **mọi AI agent** làm việc trong repo này. Đọc hết trước khi sửa bất cứ thứ gì.
> Claude Code cũng đọc file này qua `CLAUDE.md` (symlink).

---

## 0. Đọc gì trước khi bắt đầu

Theo thứ tự, luôn luôn:

1. `docs/00-VISION.md` — dự án này là gì và **không** là gì
2. `docs/02-TDD.md` — kiến trúc bắt buộc. **Đây là file quan trọng nhất với bạn.**
3. `docs/05-BACKLOG.md` — tìm task của bạn, đọc dep và DoD
4. Chỉ đọc `01-GDD.md`, `03-ART-BIBLE.md`, `04-UX-UI.md`, `06-ASSET-LIST.md` khi task liên quan

Không cần đọc toàn bộ codebase. Đọc những file mà task của bạn đụng tới, cộng với hàng xóm trực tiếp của chúng.

## 1. Quy trình làm một task

```
1. Xác định ID task (ví dụ T-305)
2. Kiểm tra mọi dep đã xong chưa. Chưa xong thì DỪNG và báo.
3. Đọc DoD. Nếu có chỗ mơ hồ, HỎI — đừng đoán.
4. Tạo nhánh: git checkout -b feat/T-305
5. Viết code theo đúng kiến trúc TDD.
6. Viết test nếu task nằm trong danh mục bắt buộc test (TDD §14).
7. Chạy: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
8. Mở project trong Godot, xác nhận không cảnh báo, không lỗi.
9. Tự kiểm tra bằng checklist ở mục 5 dưới đây.
10. Commit: "T-305: vẽ swarm bằng MultiMesh"
11. Báo cáo: đã làm gì, DoD nào đạt, cái gì chưa chắc chắn.
```

## 2. Được phép làm mà không cần hỏi

- Viết code triển khai task được giao
- Tạo file mới trong đúng thư mục theo TDD §2
- Viết và chạy test
- Tạo `.tres` từ số liệu đã có trong GDD
- Tạo scene giữ chỗ với hình hộp cơ bản
- Refactor code do chính bạn vừa viết trong task này
- Thêm log qua `Log`

## 3. PHẢI hỏi trước khi làm

- Thêm autoload mới
- Thêm plugin/addon bên thứ ba
- Đi lệch kiến trúc quy định trong TDD
- Thay đổi số liệu cân bằng trong GDD
- Thêm signal mới vào `EventBus`
- Sửa file trong `docs/`
- Xoá hoặc đổi tên file hiện có
- Refactor code của task khác
- Thêm cơ chế gameplay không có trong GDD
- Bất cứ thứ gì có vẻ nằm ngoài phạm vi task

## 4. Tuyệt đối CẤM

- `instantiate()` hoặc `queue_free()` trong đường chạy chiến đấu — dùng `PoolManager`
- `Area3D` hay bất kỳ node physics nào cho kẻ địch swarm
- `get_node()` / `find_child()` trong `_process` / `_physics_process`
- Khai báo không có kiểu tĩnh
- Chuỗi hiển thị viết thẳng trong code — dùng `tr()` với khoá dịch
- Trừ máu ở bất kỳ đâu ngoài `DamageResolver`
- File `utils.gd` chung chung
- `call_deferred()` để né lỗi thứ tự — sửa cho đúng kiến trúc
- Commit code mà test đang đỏ
- Báo cáo hoàn thành khi chưa đạt hết DoD
- Sửa hoặc vô hiệu hoá test hiện có để nó xanh
- `await` trong đường nóng của chiến đấu

## 5. Checklist tự kiểm trước khi báo xong

```
[ ] Đạt toàn bộ DoD của task
[ ] Project mở trong Godot không cảnh báo, không lỗi
[ ] Mọi khai báo có kiểu tĩnh
[ ] Toàn bộ test xanh
[ ] Có test mới nếu thuộc danh mục bắt buộc (TDD §14)
[ ] Không vi phạm luật hiệu năng (TDD §12)
[ ] Không vi phạm mục CẤM (TDD §16 và mục 4 ở trên)
[ ] Scene liên quan chạy độc lập được
[ ] Số liệu khớp GDD
[ ] File nằm đúng thư mục, đặt tên đúng quy ước
[ ] Commit có tiền tố ID task
```

## 6. Phong cách code

```gdscript
class_name HeatComponent
extends Node

## Quản lý tích luỹ và tản nhiệt của mech.
## Xem docs/01-GDD.md §2 để biết luật đầy đủ.

signal threshold_crossed(threshold: float, rising: bool)

const WARNING_THRESHOLD: float = 80.0
const CRITICAL_THRESHOLD: float = 95.0

@export var chassis_data: ChassisData

var _current_heat: float = 0.0
var _is_overheated: bool = false
var _time_since_fired: float = 0.0

@onready var _vent_timer: Timer = $VentTimer


func _physics_process(delta: float) -> void:
    _time_since_fired += delta
    _dissipate(delta)


func add_heat(amount: float) -> void:
    if _is_overheated:
        return
    _current_heat = minf(_current_heat + amount, chassis_data.heat_capacity)
    _time_since_fired = 0.0
    _check_thresholds()


func _dissipate(delta: float) -> void:
    var rate: float = chassis_data.heat_dissipation
    if _time_since_fired < 1.2:
        rate *= 0.4
    _current_heat = maxf(_current_heat - rate * delta, 0.0)
```

Điểm cần chú ý:
- `class_name` ở đầu, `extends` ngay sau
- Docstring `##` giải thích mục đích và trỏ về tài liệu
- Thứ tự: signal → const → @export → biến private → @onready → hàm vòng đời → hàm public → hàm private
- Thụt lề 4 khoảng trắng, hai dòng trống giữa các hàm
- Dùng `minf`/`maxf`/`clampf` cho float, không dùng bản int
- Số ma thuật (`1.2`, `0.4`) đến từ GDD — nếu dùng nhiều nơi thì đưa thành hằng số

## 7. Cách viết test

```gdscript
extends GutTest

var _heat: HeatComponent


func before_each() -> void:
    _heat = HeatComponent.new()
    _heat.chassis_data = load("res://data/chassis/ronin_m.tres")
    add_child_autofree(_heat)


func test_overheat_locks_weapons_at_capacity() -> void:
    _heat.add_heat(100.0)
    assert_true(_heat.is_overheated(), "phải quá nhiệt ở mức 100")
    assert_eq(_heat.get_heat(), 100.0)


func test_dissipation_slows_while_firing() -> void:
    _heat.add_heat(50.0)
    _heat._physics_process(1.0)   # vừa bắn xong → tản 40%
    assert_almost_eq(_heat.get_heat(), 50.0 - 12.0 * 0.4, 0.01)
```

Test một hành vi mỗi hàm. Tên hàm mô tả hành vi, không mô tả tên hàm được test. Thông điệp assert viết tiếng Việt.

## 8. Cách báo cáo

Sau mỗi task, báo đúng cấu trúc này:

```
## T-305 · Vẽ swarm bằng MultiMesh

**Đã làm:** một MultiMeshInstance3D cho mỗi loại swarm, cập nhật transform
hàng loạt trong SwarmRenderer, nối vào mảng dữ liệu của SwarmManager.

**File:** src/swarm/swarm_renderer.gd (mới), src/swarm/swarm_manager.gd (sửa)

**DoD:**
- [x] Một MultiMeshInstance3D mỗi loại
- [x] Cập nhật hàng loạt
- [x] Cull đúng — đã xác nhận bằng debug draw
- [x] 1 draw call mỗi loại — đo bằng bảng monitor của Godot

**Test:** 14/14 xanh

**Không chắc chắn:** custom AABB đang đặt cứng là 100m. Nếu bản đồ sau này
lớn hơn thì cull sẽ sai. Đã ghi TODO, cần xử lý ở T-706.
```

Nếu có gì không đạt, nói thẳng. Báo cáo sai là vấn đề nghiêm trọng hơn code chưa xong.

## 9. Khi bế tắc

Đừng loanh quanh. Sau 2 lần thử một hướng mà không được:

1. Nói rõ đang kẹt ở đâu, đã thử gì, kết quả ra sao
2. Nêu 2–3 hướng đi kèm đánh đổi
3. Đề xuất hướng bạn nghiêng về và lý do
4. Hỏi

Đặc biệt: nếu một quyết định kiến trúc trong TDD tỏ ra sai khi triển khai thực tế — **hãy nói ra**. Tài liệu được viết trước khi có code, nó có thể sai. Nhưng phải sửa tài liệu trước, rồi mới sửa code, chứ không âm thầm đi đường khác.

## 10. Lệnh hay dùng

```bash
# Chạy test
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Chạy một scene cụ thể
godot res://scenes/main/test_arena.tscn

# Kiểm tra lỗi import/script mà không mở editor
godot --headless --check-only --script src/swarm/swarm_manager.gd

# Kiểm toán pool: không được có kết quả nào trong code chiến đấu
grep -rn "instantiate()\|queue_free()" src/combat src/swarm src/ai src/player

# Kiểm toán trừ máu: chỉ được xuất hiện trong damage_resolver.gd
grep -rn "health -=\|hp -=\|_health -" src/

# Kiểm toán kiểu tĩnh: tìm khai báo không có kiểu
grep -rnE "^\s*(var|const)\s+[a-z_]+\s*=" src/
```
