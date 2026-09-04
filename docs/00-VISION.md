# IRONHIVE — Tài liệu Tầm nhìn

> Tài liệu gốc. Mọi tài liệu khác phải nhất quán với file này. Khi có mâu thuẫn, file này thắng.

---

## 1. Pitch một câu

Bạn là phi công lái mech chiến đấu, đơn độc dọn sạch các cơ sở công nghiệp đã bị một dạng sống bán-máy móc chiếm đóng — bắn hàng trăm con một lúc, quản lý nhiệt độ khẩu súng, và độ lại cỗ máy của mình sau mỗi lần trở về.

## 2. Thể loại & định vị

| Mục | Giá trị |
|---|---|
| Thể loại | Top-down shooter / horde shooter, có tiến trình RPG-lite |
| Góc nhìn | 3D, camera từ trên chếch xuống ~62°, khoá xoay |
| Nền tảng | PC (Windows + Linux), bàn phím & chuột là chính, gamepad hỗ trợ đầy đủ |
| Engine | Godot 4.4+ (Forward+ renderer), GDScript |
| Chế độ chơi | Đơn tuyến, chiến dịch 5 chương. **Không** multiplayer ở v1.0 |
| Thời lượng | 10–14 giờ cho lượt chơi đầu, + New Game+ |
| Tham chiếu | Alien Shooter 2 (mật độ & loot), MechWarrior (nhiệt & hardpoint), Helldivers 2 (sức nặng vũ khí), Brotato (đường cong áp lực) |

## 3. Ba trụ cột thiết kế

Mọi tính năng đề xuất phải phục vụ ít nhất một trụ cột. Tính năng không phục vụ trụ cột nào thì cắt.

### Trụ cột 1 — MẬT ĐỘ
Màn hình phải đầy kẻ địch. Mục tiêu kỹ thuật: **300 đơn vị swarm + 30 đơn vị actor cùng lúc ở 60 FPS**. Cảm giác "một mình chống lại cả tổ" là lý do người chơi mở game lên. Không bao giờ đánh đổi mật độ để lấy độ chi tiết mô hình.

### Trụ cột 2 — SỨC NẶNG
Mỗi phát bắn phải cảm thấy như đang điều khiển 12 tấn kim loại. Nguồn cảm giác: độ trễ chuyển hướng chân mech, giật màn hình, hitstop, ánh sáng đầu nòng, vỏ đạn rơi có vật lý, xác quái văng, vết cháy để lại trên sàn. Mech **không** lướt nhẹ như nhân vật twin-stick thường — nó nặng, và Boost là cách duy nhất để nó nhanh.

### Trụ cột 3 — QUYẾT ĐỊNH DƯỚI ÁP LỰC
Hệ thống Nhiệt biến "giữ chuột trái" thành một chuỗi quyết định: bắn tiếp hay để nguội, dùng Boost để thoát hay để dành, đổi sang vũ khí phụ hay chịu quá nhiệt. Người chơi giỏi được thưởng vì biết quản lý tài nguyên, không phải vì bấm nhanh hơn.

## 4. Vòng lặp cốt lõi

```
        ┌──────────────────── VÒNG LẶP LỚN (5–15 phút) ─────────────────────┐
        │                                                                    │
   [KHOANG MECH] ──► [CHỌN TRANG BỊ] ──► [NHIỆM VỤ] ──► [TỔNG KẾT] ──┐      │
        ▲              chassis, 2 vũ khí,   dọn phòng,     salvage,    │      │
        │              module, tiêu hao     hoàn mục tiêu, XP, loot    │      │
        └────────────────────────────────────────────────────────────────────┘
                    sửa chữa · nâng cấp · nghiên cứu · mở perk

        ┌──────────────── VÒNG LẶP NHỎ (5–20 giây) ────────────────┐
        │  Định vị mối đe doạ → chọn vũ khí phù hợp → bắn tới ngưỡng │
        │  nhiệt → Boost đổi vị trí → xả nhiệt → nhặt loot → lặp lại │
        └────────────────────────────────────────────────────────────┘
```

## 5. Bối cảnh

Thế kỷ 24. Tập đoàn khai khoáng **Vantek Industrial** đào trúng một tầng địa chất chứa bào tử ngủ đông của một sinh vật có khả năng đồng hoá kim loại. Bào tử lan qua hệ thống thông gió, ăn vào máy móc, rồi dùng chính máy móc để dựng nên tổ. Người ta gọi nó là **The Bloom**.

Vantek không báo cáo. Họ thuê phi công hợp đồng — rẻ hơn nhiều so với việc mất giấy phép khai thác. Bạn là một trong số đó. Bạn được trả bằng phế liệu thu hồi được, và Vantek giữ quyền chấm dứt hợp đồng bất cứ lúc nào.

Giọng điệu: công nghiệp, lạnh, hài đen nhẹ qua các bản tin nội bộ của Vantek. Không melodrama. Cốt truyện kể qua ghi âm nhặt được và giao diện nhiệm vụ, không qua cutscene dài.

## 6. Phạm vi v1.0

| Hạng mục | Số lượng |
|---|---|
| Chương chiến dịch | 5 |
| Nhiệm vụ | 26 (5 chương × 5 nhiệm vụ + 1 mở đầu) |
| Loại nhiệm vụ | 6 |
| Module phòng dựng sẵn | 45 (9 mỗi chương) |
| Khung mech (chassis) | 3 |
| Vũ khí | 16 |
| Module lắp thêm | 14 |
| Loại kẻ địch | 18 |
| Trùm | 5 |
| Perk phi công | 24 |
| Ngôn ngữ | Tiếng Việt + Tiếng Anh |

## 7. Ngoài phạm vi v1.0

Ghi rõ để tránh phình dự án. Những thứ sau **không** làm, kể cả khi nghe hay:

- Multiplayer / co-op dưới mọi hình thức
- Mech tuỳ biến ngoại hình (skin, sơn màu)
- Cây hội thoại, NPC có thể nói chuyện
- Chế độ Endless/Horde tách rời (cân nhắc cho bản cập nhật sau)
- Mod support chính thức
- Console port
- Vật lý phá huỷ môi trường toàn diện (chỉ có vật thể phá được đặt sẵn)

## 8. Tiêu chí thành công kỹ thuật

Đây là các con số nghiệm thu, không phải mong muốn:

- 60 FPS ổn định ở 1920×1080, thiết lập Medium, trên GPU tương đương GTX 1060
- Thời gian tải một nhiệm vụ < 4 giây từ ổ SSD
- Không rò rỉ bộ nhớ: chơi liên tục 60 phút, mức RAM không tăng quá 15% so với sau nhiệm vụ đầu
- Không có `instantiate()` hay `queue_free()` cho đạn/quái/hiệu ứng trong lúc chiến đấu — tất cả đi qua object pool
- Build export sạch, không lỗi/cảnh báo từ Godot

## 9. Rủi ro đã nhận diện

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| Hiệu năng sập khi quái đông | Cao | Kiến trúc swarm data-oriented + MultiMesh, chốt ngay ở Milestone 3 trước khi làm nội dung |
| Khối lượng asset 3D quá lớn | Cao | Ưu tiên asset CC0 có sẵn (Kenney, Quaternius, Poly Haven), modular kitbash, xem `06-ASSET-LIST.md` |
| Cân bằng 16 vũ khí × 18 quái | Trung bình | Bảng số liệu tập trung trong `01-GDD.md`, công cụ tuning tại `res://tools/balance_sim/` |
| Sinh màn tạo ra bản đồ không đi được | Trung bình | Bước kiểm tra tính liên thông bắt buộc sau khi sinh, seed cố định cho test |
| Phình phạm vi | Trung bình | Mục 7 ở trên; mọi bổ sung phải sửa file này trước |
