# IRONHIVE

Top-down mech shooter cho PC, làm bằng Godot 4. Bạn lái một cỗ mech chiến đấu, dọn sạch các cơ sở công nghiệp bị một dạng sống bán-máy móc chiếm đóng — hàng trăm kẻ địch cùng lúc, quản lý nhiệt thay vì nạp đạn, và độ lại cỗ máy sau mỗi lần trở về.

> Trạng thái: **giai đoạn tài liệu.** Chưa có code. Bắt đầu từ `docs/05-BACKLOG.md` task T-001.

## Tài liệu

| File | Nội dung |
|---|---|
| [docs/00-VISION.md](docs/00-VISION.md) | Tầm nhìn, trụ cột thiết kế, phạm vi, rủi ro |
| [docs/01-GDD.md](docs/01-GDD.md) | Luật chơi và toàn bộ số liệu cân bằng |
| [docs/02-TDD.md](docs/02-TDD.md) | Kiến trúc kỹ thuật — **đọc trước khi viết code** |
| [docs/03-ART-BIBLE.md](docs/03-ART-BIBLE.md) | Hình ảnh, ánh sáng, VFX, âm thanh |
| [docs/04-UX-UI.md](docs/04-UX-UI.md) | Màn hình, HUD, luồng điều hướng |
| [docs/05-BACKLOG.md](docs/05-BACKLOG.md) | ~120 task theo thứ tự, có DoD |
| [docs/06-ASSET-LIST.md](docs/06-ASSET-LIST.md) | Asset cần làm/kiếm, ngân sách kỹ thuật |
| [AGENTS.md](AGENTS.md) | Luật cho AI agent làm việc trên repo |

## Ba trụ cột

1. **MẬT ĐỘ** — 300 kẻ địch swarm + 30 actor ở 60 FPS
2. **SỨC NẶNG** — mỗi phát bắn phải cảm thấy như đang điều khiển 12 tấn kim loại
3. **QUYẾT ĐỊNH DƯỚI ÁP LỰC** — hệ thống Nhiệt biến "giữ chuột trái" thành chuỗi lựa chọn

## Bắt đầu

```bash
# Cần Godot 4.4 trở lên
godot --version

# Chạy test
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Sân tập (sau khi hoàn thành T-111)
godot res://scenes/main/test_arena.tscn
```

## Cột mốc rủi ro

**M3 (T-301 → T-312)** là cổng quyết định dự án. Nếu không đạt 300 đơn vị swarm trong ngân sách 3.0ms, phải xem lại phạm vi trước khi sản xuất nội dung. Không sang M4 khi chưa qua T-311.
