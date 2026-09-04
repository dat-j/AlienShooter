# IRONHIVE — Tài liệu UX & Giao diện

> Nguồn chân lý cho **các màn hình, luồng điều hướng và bố cục HUD**.

---

## 1. Sơ đồ luồng màn hình

```
[BOOT / Logo]
      │
      ▼
[MENU CHÍNH] ──► Tiếp tục ──┐
      ├──► Chơi mới ────────┤
      ├──► Tải slot ────────┤
      ├──► Thiết lập        │
      ├──► Ghi công         │
      └──► Thoát            │
                            ▼
                    [KHOANG MECH] ◄──────────────────────┐
                     ├─► Bảng nhiệm vụ ─► [CHỌN TRANG BỊ]│
                     ├─► Xưởng vũ khí                    │
                     ├─► Nâng cấp chassis                │
                     ├─► Cây perk phi công               │
                     ├─► Nghiên cứu (Bio-Sample)         │
                     └─► Nhật ký / Sưu tầm               │
                                     │                   │
                                     ▼                   │
                              [ĐANG TẢI]                 │
                                     ▼                   │
                            [NHIỆM VỤ ĐANG CHƠI] ────────┤
                              ├─ Tạm dừng                │
                              ├─ Bản đồ (Tab)            │
                              ▼                          │
                            [TỔNG KẾT] ──────────────────┘
```

## 2. Bố cục HUD trong nhiệm vụ

```
┌───────────────────────────────────────────────────────────────────────┐
│ ◆ PURGE: Tiêu diệt ổ Bloom          [██████░░░░] 6/10      ⏱ 04:12   │ ← Mục tiêu (trên giữa)
│                                                                       │
│                                                                       │
│                                                                       │
│                                                                       │
│                              ╱▔▔▔╲                                    │
│                             │ MECH│         ← con trỏ ngắm tuỳ chỉnh  │
│                              ╲▁▁▁╱             (không phải chuột HĐH) │
│                                                                       │
│                                                                       │
│                                                                       │
│  ┌─────────────┐                                    ┌───────────────┐ │
│  │   ▲ 60/60   │      NHIỆT                          │ ◀ MK2 AUTOCAN│ │
│  │ ◀52   52▶   │  ▓▓▓▓▓▓▓▓░░░░░░░░  62/100          │   248 / 360  │ │
│  │   ▼ 42/42   │  ═══════════════════               │ ▶ PULSE LASER│ │
│  │  LÕI 100    │  ● ● ○  Boost                      │   NĂNG LƯỢNG │ │
│  └─────────────┘                                    └───────────────┘ │
│   Giáp 4 vùng      Thanh nhiệt (trung tâm chú ý)      Vũ khí (phải)   │
│                                                                       │
│  [Q] Coolant ×3   [E] Overshield 12s        SALVAGE 1.240  ALLOY 34  │
└───────────────────────────────────────────────────────────────────────┘
```

### 2.1 Thứ tự ưu tiên chú ý

Khi mọi thứ hỗn loạn, người chơi nhìn theo thứ tự này. Thiết kế phải phục vụ nó:

1. **Mech của mình** (giữa màn hình) — vị trí, hướng, có bị vây không
2. **Thanh nhiệt** (ngay dưới mech, sát tâm nhìn) — quyết định tức thời quan trọng nhất
3. **Mối đe doạ** (khắp màn) — hình bóng và màu sắc phải phân biệt được
4. **Giáp** (dưới trái) — kiểm tra khi có nhịp nghỉ
5. **Đạn / vũ khí** (dưới phải) — kiểm tra khi có nhịp nghỉ
6. Tài nguyên, thời gian (mép màn) — thông tin nền

**Quyết định thiết kế:** thanh nhiệt **không** nằm ở góc màn hình. Nó là một vòng cung mảnh ngay dưới chân mech, di chuyển cùng mech. Người chơi không bao giờ phải rời mắt khỏi hành động để đọc nó.

### 2.2 Chỉ báo giáp 4 vùng

Một hình thoi nhỏ dưới trái, mỗi cạnh là một vùng. Khi một vùng bị đánh, cạnh đó nháy trắng. Khi vỡ, cạnh đó chuyển thành đường đứt nét đỏ. Thanh Lõi nằm ở giữa hình thoi.

Ngoài ra, khi bị đánh, một **chỉ báo hướng** (hình cung đỏ) hiện ra ở mép màn hình phía nguồn tấn công, tồn tại 1.2 giây.

### 2.3 Con trỏ ngắm

Con trỏ hệ điều hành bị ẩn. Con trỏ tuỳ chỉnh có:
- Vòng ngoài co giãn theo độ tản đạn hiện tại của vũ khí
- Vạch trúng đích (hit marker) khi gây sát thương, đổi màu khi chí mạng
- Chuyển đỏ khi rê qua kẻ địch
- Vòng cung mờ khi vũ khí đang sạc/quay nòng

### 2.4 Damage number

Bật/tắt được (mặc định bật). Pooled, trần 40 cái. Font nhỏ, trôi lên và mờ dần trong 0.7s. Chí mạng thì to hơn 1.4× và có màu vàng. Sát thương lên swarm **được gộp lại** — không hiển thị 300 con số riêng lẻ.

## 3. Màn hình Khoang mech (Hangar)

```
┌───────────────────────────────────────────────────────────────────────┐
│  KHOANG MECH · VANTEK-7            SALVAGE 4.820  ALLOY 96  BIO 12   │
├──────────────┬────────────────────────────────────┬───────────────────┤
│              │                                    │                   │
│  BẢNG        │                                    │  RONIN-M          │
│  NHIỆM VỤ    │        [ MECH 3D XOAY ĐƯỢC ]       │  ─────────────    │
│              │                                    │  Lõi      100     │
│  XƯỞNG       │         ánh sáng studio,           │  Giáp   60/52/52/42│
│  VŨ KHÍ      │         xoay chậm tự động,         │  Tốc độ   6.0 m/s │
│              │         chuột kéo để xoay tay      │  Nhiệt    100     │
│  NÂNG CẤP    │                                    │  Tản      12/s    │
│  CHASSIS     │                                    │                   │
│              │                                    │  ◀ MK2 AUTOCANNON │
│  PERK        │                                    │  ▶ PULSE LASER    │
│  PHI CÔNG    │                                    │  ⬢ Heat Sink Array│
│              │                                    │  ⬢ Servo Boosters │
│  NGHIÊN CỨU  │                                    │                   │
│              │                                    │  [ SỬA CHỮA 340 ] │
│  NHẬT KÝ     │                                    │  [ XUẤT KÍCH  ▶ ] │
└──────────────┴────────────────────────────────────┴───────────────────┘
```

**Nguyên tắc:** mech 3D luôn hiển thị ở giữa và **cập nhật ngay lập tức** khi thay vũ khí hoặc lắp module. Nhìn thấy cỗ máy của mình thay đổi chính là phần thưởng.

## 4. Màn hình Chọn trang bị (Loadout)

Hiện trước mỗi nhiệm vụ. Cho phép đổi vũ khí, module, và vật phẩm tiêu hao.

Bắt buộc hiển thị:
- Tóm tắt nhiệm vụ: loại, chương, độ khó, thời lượng ước tính
- **Cảnh báo tình báo:** kẻ địch chủ yếu sẽ gặp (giúp người chơi chọn build có chủ đích — đây là điểm ra quyết định chính của meta game)
- Điều kiện môi trường (ví dụ "Nhiệt độ cao: tản nhiệt −35%")
- Phần thưởng dự kiến
- Ba ô tiêu hao mua bằng Salvage

## 5. Màn hình Tổng kết (Debrief)

Xuất hiện theo từng dòng, có âm thanh riêng cho mỗi dòng — nhịp điệu ăn mừng quan trọng ngang nội dung.

```
NHIỆM VỤ HOÀN THÀNH

Kẻ địch tiêu diệt        1.847      +924 Salvage
Mục tiêu hoàn thành        3/3      +500 Salvage
Không quá nhiệt lần nào     ✓        +150 Salvage  ← thưởng phong cách
Thời gian              06:42
Chính xác                58%

Alloy thu được              28
Bio-Sample                   4

XP PHI CÔNG    ████████████░░░░  CẤP 12 → 13    [+1 ĐIỂM PERK]

                              [ TIẾP TỤC ]
```

## 6. Bản đồ (Tab)

Lớp phủ bán trong suốt, **game không dừng** (giữ áp lực). Hiện: phòng đã khám phá, vị trí người chơi, mục tiêu, điểm rút, két đồ chưa mở. Không hiện vị trí kẻ địch trừ khi có module Targeting Uplink.

## 7. Menu Thiết lập

Bốn tab: **Đồ hoạ · Âm thanh · Điều khiển · Trợ năng**

Preset đồ hoạ: Thấp / Trung bình / Cao / Siêu cao + Tuỳ chỉnh. Preset điều chỉnh: độ phân giải bóng, chất lượng SSAO, mật độ hạt, trần decal, sương thể tích, mật độ swarm (Thấp giới hạn 180 thay vì 300 — đây là van an toàn hiệu năng cho máy yếu).

Tab Trợ năng có toàn bộ mục ở `03-ART-BIBLE.md` §12.

## 8. Bản địa hoá

- Toàn bộ chuỗi hiển thị qua `tr()` với khoá dạng `ui.hangar.launch`, `weapon.rail_lance.name`.
- File `.csv` trong `res://assets/locale/`, cột `key,vi,en`.
- Tiếng Việt là ngôn ngữ chính khi phát triển; tiếng Anh phải hoàn chỉnh trước khi phát hành.
- Bố cục phải chịu được chuỗi dài hơn 40% — không thiết kế nút vừa khít chữ.

## 9. Luật phản hồi giao diện

Mọi hành động của người chơi phải có phản hồi trong **50ms**:
- Rê chuột: đổi màu + tiếng click nhẹ
- Nhấn: hiệu ứng ấn xuống + âm thanh
- Không đủ tài nguyên: nút rung + âm thanh từ chối + tài nguyên thiếu nháy đỏ
- Mua thành công: hiệu ứng nở + âm thanh xác nhận + số tài nguyên đếm giảm dần (không nhảy tức thì)
