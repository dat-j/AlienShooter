# IRONHIVE — Tài liệu Thiết kế Game (GDD)

> Nguồn chân lý cho **luật chơi và số liệu**. Mọi giá trị số ở đây phải được phản ánh trong file `.tres` tương ứng dưới `res://data/`. Nếu code và tài liệu lệch nhau, sửa cho khớp và ghi chú tại mục 14 (Nhật ký cân bằng).

---

## 1. Điều khiển

| Hành động | Bàn phím & chuột | Gamepad |
|---|---|---|
| Di chuyển | `W A S D` | Cần trái |
| Ngắm | Vị trí chuột | Cần phải |
| Bắn vũ khí trái | Chuột trái (giữ) | LT |
| Bắn vũ khí phải | Chuột phải (giữ) | RT |
| Boost / Lướt | `Space` (theo hướng di chuyển) | A / Cross |
| Xả nhiệt khẩn cấp | `R` (giữ 0.8s) | X / Square (giữ) |
| Module 1 / 2 | `Q` / `E` | LB / RB |
| Nhặt đồ | `F` (hoặc tự động trong bán kính) | Y / Triangle |
| Bản đồ | `Tab` | Nút chọn |
| Tạm dừng | `Esc` | Nút start |

**Quy tắc ngắm:** Thân trên (torso) xoay tức thời theo con trỏ. Phần chân xoay theo hướng di chuyển với tốc độ **480°/giây**. Góc lệch tối đa giữa thân và chân là **110°**; vượt quá thì chân bị kéo theo. Đây là nguồn chính của cảm giác "nặng" — không được bỏ.

---

## 2. Hệ thống Nhiệt (Heat)

Cơ chế đặc trưng của game. Thay thế hoàn toàn cho việc nạp đạn truyền thống ở phần lớn vũ khí.

### 2.1 Luật

- Thanh nhiệt: **0 → 100**. Hiển thị lớn, ngay dưới mech.
- Mỗi phát bắn cộng `heat_per_shot`. Boost cộng nhiệt. Một số module cộng nhiệt.
- Nhiệt tự giảm theo `dissipation_rate`:
  - Không bắn trong **1.2 giây** → tản nhiệt **đầy** (100%)
  - Đang bắn → tản nhiệt **giảm còn 40%**
- Ngưỡng cảnh báo: **80** (HUD chuyển vàng, âm thanh cảnh báo, hơi nước phụt ra)
- Ngưỡng nguy hiểm: **95** (HUD đỏ, rung màn hình nhẹ liên tục)
- **Quá nhiệt tại 100:** cả hai vũ khí bị khoá, mech phụt hơi trong **3.0 giây**, tốc độ di chuyển **-35%**, không dùng được Boost. Nhiệt tụt về 0 khi kết thúc.

### 2.2 Xả nhiệt khẩn cấp (Vent)

Giữ `R` trong 0.8 giây. Mech đứng yên, mở tấm tản nhiệt, giảm **60 nhiệt tức thì**. Hồi chiêu **12 giây**. Trong lúc xả, mech nhận thêm **+30% sát thương**. Đây là quyết định rủi ro/phần thưởng cố ý.

### 2.3 Bảng ảnh hưởng môi trường

| Môi trường | Bội số tản nhiệt |
|---|---|
| Chuẩn (trong nhà) | ×1.00 |
| Khu vực đóng băng (Chương 4) | ×1.45 |
| Gần lò luyện / lửa (Chương 2) | ×0.65 |
| Ngập nước nông | ×1.25 |
| Chân không (Chương 5) | ×0.55 |

---

## 3. Boost

- Lướt nhanh theo hướng đang di chuyển (nếu đứng yên thì theo hướng thân trên).
- Quãng đường **7.0 m**, thời gian **0.18 giây**, có **i-frame 0.12 giây** ở giữa.
- Tốn **15 nhiệt** mỗi lần.
- **2 lần nạp** (Light chassis: 3). Mỗi lần nạp lại mất **3.5 giây**, chỉ nạp khi không quá nhiệt.
- Boost xuyên qua kẻ địch swarm và gây **12 sát thương va chạm** cho chúng.
- Không boost xuyên tường.

---

## 4. Giáp & Lõi

Mech có **4 vùng giáp** độc lập: Trước, Sau, Trái, Phải. Sát thương được phân bổ theo hướng nguồn gây ra tương đối với thân mech.

```
              TRƯỚC
          ┌───────────┐
   TRÁI   │   [LÕI]   │   PHẢI
          └───────────┘
               SAU
```

- Mỗi vùng có chỉ số **Armor** riêng. Sát thương trừ vào Armor của vùng đó trước.
- Armor về 0 → **mảng giáp vỡ** (hiệu ứng hình ảnh: tấm giáp rơi ra, để lộ khung). Từ đó sát thương vào vùng này đi thẳng vào **Core HP** với hệ số **×1.4**.
- Core HP về 0 → thua nhiệm vụ.
- Giáp **không tự hồi** trong nhiệm vụ. Chỉ hồi qua vật phẩm `Nanite Patch` hoặc trạm sửa chữa trong màn.
- Vùng SAU luôn có Armor thấp hơn 30% so với TRƯỚC — khuyến khích người chơi không để bị vây.

---

## 5. Khung mech (Chassis)

| | **VESPA-L** (Nhẹ) | **RONIN-M** (Trung) | **ATLAS-H** (Nặng) |
|---|---|---|---|
| Mở khoá | Mặc định | Chương 2 | Chương 4 |
| Core HP | 80 | 100 | 145 |
| Armor Trước | 45 | 60 | 95 |
| Armor Trái/Phải | 38 | 52 | 80 |
| Armor Sau | 30 | 42 | 66 |
| Tốc độ | 7.6 m/s | 6.0 m/s | 4.4 m/s |
| Xoay chân | 620°/s | 480°/s | 330°/s |
| Sức chứa nhiệt | 85 | 100 | 125 |
| Tản nhiệt | 15/s | 12/s | 9/s |
| Nạp Boost | 3 | 2 | 2 |
| Hồi chiêu Boost | 2.8s | 3.5s | 4.6s |
| Ô module | 2 | 2 | 3 |
| Đặc tính riêng | Boost không tốn i-frame cooldown | Cân bằng, +10% tầm nhặt loot | Miễn nhiễm knockback, -20% sát thương nổ nhận vào |

Cả ba chassis đều có **2 hardpoint vũ khí** (trái/phải). Không có ngoại lệ — đây là ngôn ngữ điều khiển cố định của game.

---

## 6. Vũ khí

### 6.1 Nhóm

| Nhóm | Đặc điểm | Nhiệt | Đạn |
|---|---|---|---|
| **Kinetic** | Sát thương ổn định, có đạn hữu hạn, nhiệt thấp | Thấp | Có |
| **Energy** | Không cần đạn, nhiệt cao, xuyên giáp tốt | Cao | Không |
| **Explosive** | Sát thương vùng, đạn ít, tự gây sát thương nếu quá gần | Trung | Có |
| **Special** | Cơ chế riêng biệt | Thay đổi | Thay đổi |

### 6.2 Bảng vũ khí đầy đủ

Ký hiệu: `DMG` sát thương mỗi phát · `RoF` phát/giây · `HEAT` nhiệt mỗi phát · `DPS` lý thuyết · `DPH` sát thương trên mỗi điểm nhiệt (chỉ số hiệu quả nhiệt)

| # | Tên | Nhóm | Tier | DMG | RoF | HEAT | Đạn | DPS | DPH | Ghi chú |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | MK2 Autocannon | Kinetic | 1 | 8 | 8.0 | 2.2 | 360 | 64 | 3.6 | Vũ khí khởi đầu, độ giật nhỏ |
| 2 | Twin Repeater | Kinetic | 1 | 5 | 13.0 | 1.5 | 500 | 65 | 3.3 | Tản đạn rộng, tốt cho swarm |
| 3 | Pulse Laser | Energy | 1 | 14 | 3.0 | 9.0 | — | 42 | 1.6 | Hitscan, xuyên 1 mục tiêu |
| 4 | Frag Launcher | Explosive | 1 | 60 (AoE 3.0m) | 1.5 | 6.0 | 40 | 90 | 10.0 | Tự sát thương trong 1.5m |
| 5 | Scattergun | Kinetic | 2 | 9×8 viên | 1.8 | 7.0 | 120 | 130 | 10.3 | Suy giảm theo tầm, cực mạnh cận |
| 6 | Arc Emitter | Energy | 2 | 11/tick, 6 tick/s | — | 13/s | — | 66 | 5.1 | Nhảy 3 mục tiêu, gây `Shocked` |
| 7 | Flamer | Special | 2 | 22/s hình nón 6m | — | 14/s | 400 nhiên liệu | 22+DoT | — | Gây `Burning`, xuyên swarm |
| 8 | Gauss Repeater | Kinetic | 2 | 22 | 4.0 | 5.0 | 200 | 88 | 4.4 | Xuyên 2 mục tiêu |
| 9 | Mortar Pod | Explosive | 3 | 95 (AoE 4.5m) | 0.8 | 12.0 | 24 | 76 | 7.9 | Bắn cầu vồng, qua tường thấp |
| 10 | Rail Lance | Energy | 3 | 120 | 0.6 | 35.0 | — | 72 | 3.4 | Xuyên vô hạn, cần sạc 0.5s |
| 11 | Cryo Projector | Special | 3 | 8/s hình nón | — | −6/s | 300 | 8 | — | **Làm mát mech**, gây `Frozen` |
| 12 | Nail Driver | Kinetic | 3 | 34 | 3.5 | 4.5 | 150 | 119 | 7.6 | Ghim xác vào tường (thị giác) |
| 13 | Plasma Thrower | Energy | 4 | 45 (AoE 2.0m) | 2.2 | 18.0 | — | 99 | 2.5 | Đạn bay chậm, để lại vũng lửa |
| 14 | Swarm Missiles | Explosive | 4 | 8×12 tên lửa (AoE 1.5m) | 0.5 | 20.0 | 30 | 48 | 2.4 | Tự tìm mục tiêu, tốt chống nhóm actor |
| 15 | Singularity Core | Special | 4 | 0 trực tiếp | 0.25 | 45.0 | 8 | — | — | Hút mọi kẻ địch bán kính 8m trong 2.5s |
| 16 | Vulcan-X | Kinetic | 4 | 14 | 16.0 | 3.2 | 900 | 224 | 4.4 | Cần quay nòng 0.7s trước khi bắn |

### 6.3 Nguyên tắc thiết kế vũ khí

- **DPH là trục cân bằng chính.** Vũ khí DPS cao phải có DPH thấp (đốt nhiệt nhanh) hoặc đạn hạn chế.
- Mỗi tier phải có ít nhất một lựa chọn cho từng vai trò: dọn swarm, hạ actor đơn lẻ, kiểm soát khu vực.
- `Cryo Projector` (#11) làm **giảm** nhiệt — đây là ngoại lệ cố ý, tạo ra build "một tay đốt, một tay làm mát".

### 6.4 Nâng cấp vũ khí

Mỗi vũ khí có **5 cấp**. Mỗi cấp tốn Salvage + Alloy tăng dần.

| Cấp | Chi phí (Salvage / Alloy) | Hiệu ứng cộng dồn |
|---|---|---|
| 1 | — | Cơ bản |
| 2 | 400 / 8 | +12% sát thương |
| 3 | 900 / 20 | −10% nhiệt mỗi phát |
| 4 | 1800 / 45 | +15% sát thương, +20% đạn tối đa |
| 5 | 3500 / 90 | Mở **Overdrive**: hiệu ứng đặc thù của từng vũ khí |

---

## 7. Module

Lắp vào ô module của chassis. Bị động trừ khi ghi rõ là kích hoạt.

| Tên | Loại | Hiệu ứng |
|---|---|---|
| Heat Sink Array | Bị động | +25% tản nhiệt |
| Ablative Plating | Bị động | +30 Armor mọi vùng, −8% tốc độ |
| Servo Boosters | Bị động | +1 nạp Boost, −15% hồi chiêu Boost |
| Auto-Loader | Bị động | +35% đạn tối đa mọi vũ khí Kinetic |
| Targeting Uplink | Bị động | +18% sát thương lên actor, hiện thanh máu kẻ địch |
| Salvage Magnet | Bị động | +80% bán kính tự nhặt, +10% Salvage nhận được |
| Reactive Armor | Bị động | Khi một mảng giáp vỡ, gây nổ 90 sát thương bán kính 5m |
| Coolant Injector | Kích hoạt | Giảm 45 nhiệt tức thì. 3 lần dùng/nhiệm vụ |
| Overshield | Kích hoạt | Khiên 120 điểm trong 5s. Hồi chiêu 40s |
| Deployable Turret | Kích hoạt | Đặt tháp pháo 25 DPS, tồn tại 20s. Hồi chiêu 45s |
| EMP Burst | Kích hoạt | Choáng mọi kẻ địch bán kính 10m trong 3s. Hồi chiêu 35s |
| Repair Drone | Kích hoạt | Hồi 40 Armor cho vùng yếu nhất. 2 lần dùng/nhiệm vụ |
| Phase Dash | Bị động | Boost xuyên tường mỏng, +2.0m quãng đường |
| Overclock Core | Bị động | +25% sát thương khi nhiệt trên 70, +15% tốc sinh nhiệt |

---

## 8. Kẻ địch

### 8.1 Phân loại kỹ thuật

Cực kỳ quan trọng cho kiến trúc (xem `02-TDD.md` mục 6):

- **SWARM** — không có node Godot riêng. Quản lý theo mảng dữ liệu, vẽ bằng `MultiMeshInstance3D`, va chạm bằng spatial hash. Giới hạn 400 đơn vị sống cùng lúc.
- **ACTOR** — node đầy đủ, `CharacterBody3D`, có máy trạng thái AI riêng. Giới hạn 40 đơn vị.
- **BOSS** — node đầy đủ, có nhiều phase, kịch bản riêng.

### 8.2 Bảng kẻ địch

| # | Tên | Loại KT | HP | Tốc độ | Sát thương | Hành vi | Chương |
|---|---|---|---|---|---|---|---|
| 1 | Crawler | SWARM | 18 | 7.5 | 6 (cận) | Lao thẳng theo flow field | 1+ |
| 2 | Skitter | SWARM | 10 | 9.5 | 4 (cận) | Nhanh, nhảy 4m khi cách 6m | 1+ |
| 3 | Husk | SWARM | 30 | 5.0 | 9 (cận) | Chậm hơn, trâu hơn, cản đường | 2+ |
| 4 | Ravager | ACTOR | 220 | 4.2 | 32 (cận, vung 3 nhịp) | Đuổi bám, knockback | 1+ |
| 5 | Bulwark | ACTOR | 450 | 2.6 | 45 (cận) | Giảm 70% sát thương từ phía trước | 2+ |
| 6 | Spitter | ACTOR | 60 | 3.5 | 14 (acid, tầm 14m) | Giữ khoảng cách, để lại vũng acid | 1+ |
| 7 | Lancer | ACTOR | 130 | 3.0 | 30 (xuyên, tầm 22m) | Ngắm 0.9s rồi bắn tia | 3+ |
| 8 | Detonator | ACTOR | 45 | 6.0 | 70 (nổ 4m) | Lao vào rồi tự nổ | 2+ |
| 9 | Burrower | ACTOR | 90 | — | 40 (trồi lên) | Chui đất, trồi lên dưới chân người chơi | 3+ |
| 10 | Pulsar | ACTOR | 110 | 3.2 | — | Hồi 8 HP/s cho mọi kẻ địch bán kính 9m | 2+ |
| 11 | Stalker | ACTOR | 160 | 5.5 | 60 (đánh lén) | Tàng hình, hiện ra khi tấn công | 4+ |
| 12 | Hive Node | ACTOR (tĩnh) | 300 | 0 | — | Sinh 3 Crawler mỗi 4s. Ưu tiên phá | 1+ |
| 13 | Weaver | ACTOR | 140 | 2.8 | 12 | Nhả mạng làm chậm 50% trong vùng | 3+ |
| 14 | Sentinel | ACTOR | 260 | 3.4 | 25 (đạn ×3) | Xác máy móc bị chiếm, bắn loạt | 4+ |
| 15 | Bloated | ACTOR | 200 | 2.2 | 55 (nổ acid 6m) | Chậm, nổ để lại vùng acid lớn | 3+ |
| 16 | Screamer | ACTOR | 95 | 4.0 | — | Hét: triệu thêm swarm, buff tốc độ +30% | 4+ |
| 17 | Warden | ACTOR | 520 | 3.0 | 50 | Có khiên năng lượng, phải phá khiên trước | 5 |
| 18 | Drone Swarm | SWARM (bay) | 14 | 8.5 | 5 | Bay, bỏ qua địa hình | 4+ |

### 8.3 Trùm

| Chương | Tên | HP | Phase | Cơ chế chính |
|---|---|---|---|---|
| 1 | **THE MAW** | 4.500 | 2 | Nằm cố định, quật xúc tu, nhả Crawler liên tục. Phase 2: sàn sập từng mảng |
| 2 | **FOUNDRY KING** | 7.200 | 3 | Mech công nghiệp bị chiếm. Bắn kim loại nóng chảy. Phase 3: quá nhiệt cả phòng, buộc người chơi phải giữ nhiệt thấp |
| 3 | **THE CHOIR** | 3× 3.000 | 1 | Ba Screamer khổng lồ, buff lẫn nhau. Phải giết gần như đồng thời |
| 4 | **NULL-9** | 9.800 | 3 | Stalker khổng lồ. Tắt đèn cả phòng, chỉ thấy qua đèn pha mech |
| 5 | **THE BLOOM CORE** | 15.000 | 4 | Trùm cuối. Mỗi phase mở một cơ chế của các trùm trước |

### 8.4 Nguyên tắc thiết kế kẻ địch

- Kẻ địch SWARM tồn tại để **bị giết hàng loạt**. Chúng không cần AI thông minh — chúng cần đến đúng chỗ và chết đẹp.
- Mỗi ACTOR phải trả lời được câu hỏi: **"Nó buộc người chơi thay đổi hành vi gì?"** Nếu không có câu trả lời, cắt.
- Không có kẻ địch nào một-phát-chết người chơi từ máu đầy. Sát thương cao nhất trong game (Detonator + Bloated cùng lúc) không được vượt 60% Core HP của chassis Trung.

---

## 9. Trạng thái bất lợi (Status Effect)

| Trạng thái | Nguồn | Hiệu ứng | Thời gian |
|---|---|---|---|
| `Burning` | Flamer, Plasma | 12 sát thương/s | 4s, cộng dồn tối đa 3 |
| `Shocked` | Arc Emitter, EMP | −40% tốc độ, không tấn công | 2.5s |
| `Frozen` | Cryo | −70% tốc độ; vỡ tan nếu chịu >50 sát thương một lần | 3s |
| `Corroded` | Acid của Spitter/Bloated | −25% Armor hiệu dụng | 6s |
| `Marked` | Targeting Uplink | +20% sát thương nhận vào | 5s |
| `Slowed` | Weaver | −50% tốc độ | Khi ở trong vùng mạng |

---

## 10. Nhiệm vụ

### 10.1 Sáu loại nhiệm vụ

| Loại | Mục tiêu | Thời lượng | Nhịp áp lực |
|---|---|---|---|
| **PURGE** | Tiêu diệt hết kẻ địch trong khu vực | 6–9 phút | Sóng đều, tăng dần |
| **HOLD** | Giữ vị trí trong N giây | 4–6 phút | Ba đợt cao trào rõ rệt |
| **RETRIEVE** | Lấy vật phẩm rồi rút về điểm đổ bộ | 7–10 phút | Yên tĩnh khi đi, cực căng khi về |
| **ESCORT** | Hộ tống xe khoan di chuyển chậm | 8–11 phút | Liên tục trung bình, không có lúc nghỉ |
| **HUNT** | Truy lùng và diệt mục tiêu ưu tiên | 6–8 phút | Thấp → dốc đứng khi tìm thấy |
| **EXTRACT** | Sống sót và tới điểm rút trước giờ G | 5–7 phút | Áp lực tăng không ngừng |

### 10.2 Cấu trúc chương

Mỗi chương gồm 5 nhiệm vụ:
1. Nhiệm vụ giới thiệu (chủ đề mới, kẻ địch mới)
2. Nhiệm vụ khai thác (loại nhiệm vụ khác)
3. Nhiệm vụ tuỳ chọn (có thể bỏ qua, thưởng hậu hĩnh)
4. Nhiệm vụ dốc căng
5. Nhiệm vụ trùm

Chủ đề các chương:
1. **VANTEK-7 · Trạm khai khoáng bề mặt** — hành lang hẹp, ánh sáng vàng công nghiệp, giới thiệu cơ chế
2. **HỆ THỐNG LUYỆN KIM** — nóng, tản nhiệt kém, dung nham, băng chuyền chuyển động
3. **KHU SINH HỌC** — cơ sở bị mô sống mọc trùm, sàn hữu cơ, tầm nhìn kém
4. **TRỤC THANG QUỸ ĐẠO** — lạnh, chân không từng đoạn, kẻ địch bay, trọng lực thấp trong vài phòng
5. **LÕI BLOOM** — hoàn toàn hữu cơ, quy luật vật lý bất thường, mật độ kẻ địch cao nhất game

### 10.3 Điều tiết áp lực (Spawn Director)

Mỗi nhiệm vụ có một **đường cong áp lực** — hàm số theo thời gian trả về "ngân sách sinh quái" mỗi giây.

```
Áp lực
  ▲
  │           ╱╲              ╱╲╱╲
  │      ╱╲  ╱  ╲       ╱╲  ╱      ╲
  │  ╱╲ ╱  ╲╱    ╲╱╲  ╱  ╲╱         ╲
  │ ╱  ╲            ╲╱                ╲
  └──────────────────────────────────────► Thời gian
    khởi động   sóng    nghỉ    cao trào   kết
```

- Mỗi loại kẻ địch có **chi phí ngân sách** (Crawler 1, Ravager 12, Bulwark 25, Hive Node 30).
- Director chỉ sinh khi có đủ ngân sách, chọn thành phần từ `WaveTable` của chương.
- **Luật chống ức chế:** không sinh trong tầm nhìn trực tiếp của người chơi; không sinh 2 Detonator trong vòng 3 giây; sau một đợt cao trào bắt buộc có tối thiểu **8 giây** áp lực thấp.
- Nếu người chơi dưới 30% Core HP, Director giảm 25% ngân sách trong 15 giây (rubber-band ẩn, không thông báo).

---

## 11. Kinh tế & Loot

### 11.1 Tài nguyên

| Tài nguyên | Nguồn | Dùng để |
|---|---|---|
| **Salvage** | Mọi kẻ địch rơi ra | Mua vũ khí/module, chi phí sửa chữa |
| **Alloy** | Két đồ trong màn, actor | Nâng cấp vũ khí và chassis |
| **Bio-Sample** | Chỉ từ actor và trùm | Nghiên cứu mở khoá công nghệ mới |
| **Ascendant Core** | Chỉ từ trùm và két hiếm | Nâng cấp tier 5, mở chassis |

### 11.2 Rơi đồ trong màn

| Vật phẩm | Tần suất | Hiệu ứng |
|---|---|---|
| Salvage nhỏ | Rất cao | +5–15 Salvage |
| Nanite Patch | Trung bình | Hồi 35 Armor cho vùng yếu nhất |
| Coolant Cell | Trung bình | Giảm 40 nhiệt tức thì |
| Hộp đạn | Trung bình | +25% đạn tối đa cho cả hai vũ khí |
| Két Alloy | Thấp (đặt tay trong màn) | 10–30 Alloy |
| Overdrive Chip | Rất thấp | +40% sát thương, −50% sinh nhiệt trong 15 giây |

**Luật thả đồ thích ứng:** nếu người chơi dưới 40% Armor tổng, xác suất rơi `Nanite Patch` tăng gấp đôi. Nếu nhiệt trung bình 30 giây qua trên 75, xác suất rơi `Coolant Cell` tăng gấp đôi.

### 11.3 Đường cong thu nhập mục tiêu

| Chương | Salvage/nhiệm vụ | Alloy/nhiệm vụ | Chi phí nâng cấp điển hình |
|---|---|---|---|
| 1 | 350–600 | 6–12 | 400 Salvage |
| 2 | 700–1.100 | 15–28 | 900 Salvage |
| 3 | 1.300–2.000 | 30–50 | 1.800 Salvage |
| 4 | 2.200–3.400 | 55–85 | 3.500 Salvage |
| 5 | 3.500–5.200 | 90–140 | 3.500 Salvage |

Nguyên tắc: người chơi luôn nâng cấp được **đúng một** thứ đáng kể sau mỗi 1–2 nhiệm vụ. Không bao giờ để họ mua được mọi thứ.

---

## 12. Tiến trình phi công

- XP nhận từ diệt kẻ địch và hoàn thành mục tiêu. **30 cấp.**
- Mỗi cấp: +1 điểm perk. Cấp 10/20/30 thêm 1 điểm bonus.
- **24 perk**, chia 3 nhánh, mỗi nhánh 8:

**Nhánh CHIẾN THUẬT** (sống sót & cơ động)
Tăng nạp Boost · Giảm sát thương từ phía sau · Hồi Armor khi diệt actor · Miễn `Corroded` · i-frame Boost dài hơn · Sống sót một đòn chí mạng mỗi nhiệm vụ · Tốc độ khi nhiệt thấp · Nhặt đồ từ xa

**Nhánh HOẢ LỰC** (sát thương)
Sát thương chí mạng · +sát thương lên swarm · +sát thương lên actor · Đạn xuyên thêm 1 mục tiêu · Nổ lan · Overdrive lâu hơn · Sát thương tăng theo nhiệt · Vũ khí trái và phải cùng loại thì +20%

**Nhánh KỸ THUẬT** (nhiệt & module)
Tản nhiệt nền · Xả nhiệt hồi chiêu ngắn · Module hồi chiêu nhanh · Không quá nhiệt lần đầu mỗi nhiệm vụ · Bắt đầu nhiệm vụ với 1 Coolant Cell · Trạng thái bất lợi lên địch kéo dài hơn · Tháp pháo/drone mạnh hơn · Giảm nhiệt của Boost xuống 0

---

## 13. Độ khó

| Mức | HP kẻ địch | Sát thương lên người chơi | Ngân sách Director | Ghi chú |
|---|---|---|---|---|
| Recruit | ×0.75 | ×0.60 | ×0.80 | |
| Contractor | ×1.00 | ×1.00 | ×1.00 | Mặc định |
| Veteran | ×1.30 | ×1.35 | ×1.25 | |
| Ironclad | ×1.60 | ×1.75 | ×1.50 | Mở sau khi phá đảo |
| Bloomtouched | ×2.10 | ×2.30 | ×1.85 | New Game+, kẻ địch có biến thể tinh nhuệ |

---

## 14. Nhật ký cân bằng

> Mọi thay đổi số liệu sau khi tài liệu này được chốt phải ghi vào đây, theo định dạng: `[YYYY-MM-DD] Đối tượng · giá trị cũ → mới · lý do`

- `[2026-09-04]` Tài liệu khởi tạo. Toàn bộ số liệu là ước lượng ban đầu, chưa qua playtest.
