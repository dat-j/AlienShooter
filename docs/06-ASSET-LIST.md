# IRONHIVE — Danh mục Asset

> Nguồn chân lý cho **mọi thứ cần được tạo ra hoặc kiếm về**. Cột "Nguồn" quyết định ai làm: `CC0` = tải về, `KITBASH` = ghép từ mảnh có sẵn, `TỰ LÀM` = phải dựng mới.

---

## 1. Chiến lược asset

Đây là dự án lớn với nguồn lực nghệ thuật hạn chế. Thứ tự ưu tiên:

1. **Kitbash từ thư viện CC0** — nhanh nhất, chất lượng ổn, hợp với chủ đề công nghiệp
2. **Modular** — dựng 20 mảnh kiến trúc rồi ghép ra 45 phòng, không mô hình hoá từng phòng riêng
3. **Tự làm chỉ cho những thứ mang bản sắc** — mech người chơi, các loại kẻ địch, trùm
4. **Vật liệu quan trọng hơn hình học** — một hình đơn giản với vật liệu PBR tốt trông đẹp hơn một hình phức tạp với vật liệu tệ

### Nguồn CC0 đã kiểm chứng

| Nguồn | Dùng cho | Giấy phép |
|---|---|---|
| Kenney.nl | Prop, mảnh kiến trúc, UI, âm thanh giữ chỗ | CC0 |
| Quaternius | Mảnh sci-fi modular, mech cơ bản | CC0 |
| Poly Haven | HDRI, texture PBR | CC0 |
| ambientCG | Texture PBR (kim loại, bê tông, hữu cơ) | CC0 |
| Freesound (lọc CC0) | Âm thanh nền, va chạm | Kiểm từng file |
| Google Fonts | Rajdhani, Chakra Petch | OFL |
| Sonniss GDC Bundle | SFX chất lượng cao | Royalty-free |

**Bắt buộc:** mọi asset bên thứ ba phải ghi vào `assets/CREDITS.md` ngay khi thêm vào, kèm URL và giấy phép. Task T-1504 sẽ kiểm tra file này.

---

## 2. Mô hình 3D

### 2.1 Mech người chơi — TỰ LÀM (ưu tiên cao nhất)

| Phần | Ngân sách tam giác | Ghi chú |
|---|---|---|
| Thân trên RONIN-M | 9.000 | Có khoang tản nhiệt mở ra được (animation xả nhiệt) |
| Chân RONIN-M | 8.000 | Rig 2 chân, hỗ trợ IK |
| Thân trên VESPA-L | 7.000 | Mảnh mai hơn, khoang tản nhiệt lớn hơn tỉ lệ |
| Chân VESPA-L | 6.000 | |
| Thân trên ATLAS-H | 11.000 | Vai rộng, giáp nhiều lớp |
| Chân ATLAS-H | 9.000 | Chân trụ dày |
| Bộ mảng giáp (rời ra được) | 2.000 mỗi bộ | Mỗi vùng 4–6 mảnh riêng để vỡ ra |

**Rig:** một skeleton dùng chung cho cả 3 chassis nếu có thể — tiết kiệm rất nhiều công animation. Nếu tỉ lệ khác nhau quá, ít nhất giữ chung tên xương.

### 2.2 Vũ khí — TỰ LÀM / KITBASH

16 mô hình, mỗi cái ~3.000 tam giác, dùng chung một texture atlas 1024². Mỗi vũ khí cần:
- Một `Marker3D` tên `MuzzlePoint` ở đầu nòng
- Một `Marker3D` tên `EjectPoint` cho vũ khí Kinetic
- Điểm gắn khớp với ổ hardpoint chuẩn của mech

### 2.3 Kẻ địch

| Loại | Số mẫu | Tam giác | Nguồn |
|---|---|---|---|
| SWARM (Crawler, Skitter, Husk, Drone) | 4 | **600 mỗi con** | TỰ LÀM — ràng buộc rất chặt |
| ACTOR (14 loại) | 14 | 4.000–8.000 | TỰ LÀM, dùng chung bộ phận giữa các loại |
| Trùm | 5 | 30.000 | TỰ LÀM, đây là điểm nhấn hình ảnh |

**Chiến lược tái sử dụng:** thiết kế 3 "bộ khung sinh học" (bốn chân / hai chân / bám tường) rồi biến tấu bằng phần đầu, phần phụ và tỉ lệ. 14 actor không có nghĩa là 14 mô hình từ đầu.

### 2.4 Kiến trúc modular — KITBASH

Bộ mảnh dùng để dựng toàn bộ 45 phòng:

```
Sàn:      1×1, 2×2, 4×4 · phẳng, có rãnh, có lưới, hư hại
Tường:    1×3, 2×3, 4×3 · trơn, có ống, có cửa sổ, hư hại
Cửa:      nhỏ (3m), vừa (6m), lớn (10m)
Trần:     tấm, dầm, khung đèn
Cột:      tròn, vuông, có giằng
Ống:      thẳng, cong, chữ T, van
Lan can, cầu thang, bậc thềm, sàn nâng
Prop:     thùng, két, thùng phuy, bảng điều khiển, giá kệ, máy móc,
          xe nâng, băng chuyền, đèn, quạt thông gió
```

Mỗi chương thêm một lớp phủ chủ đề:
- Ch1: sạch, công nghiệp, đèn vàng
- Ch2: nóng, gỉ, dung nham, băng chuyền
- Ch3: mô sống mọc trùm lên (bộ mảnh hữu cơ phủ lên tường/sàn có sẵn)
- Ch4: lạnh, băng, tấm chắn chân không, khung dàn kim loại
- Ch5: hoàn toàn hữu cơ (bộ mảnh riêng, không tái dùng)

**Bộ mảnh hữu cơ:** ~15 mảnh phủ (mảng thịt trên tường, rễ, túi trứng, dây gân) dùng chung cho Ch3 và Ch5.

---

## 3. Texture & Vật liệu

| Loại | Độ phân giải | Kênh |
|---|---|---|
| Mech | 2048² | Albedo, Normal, ORM (Occlusion/Roughness/Metallic), Emission |
| Vũ khí (atlas chung) | 1024² | Albedo, Normal, ORM |
| Kẻ địch ACTOR | 1024² | Albedo, Normal, ORM, Emission (điểm phát sáng) |
| Kẻ địch SWARM (atlas chung) | 512² | Albedo, Normal — **không** ORM riêng, dùng giá trị hằng |
| Trùm | 2048² | Đủ bộ + Emission |
| Kiến trúc | Trilinear/triplanar 1024² | Albedo, Normal, ORM — dùng chung tối đa |
| Decal | 512² | Albedo + Normal + Alpha |

**Số vật liệu tối đa hiển thị cùng lúc:** 6 cho phe kẻ địch, 8 cho môi trường. Vượt quá là phá vỡ instancing — đây là ràng buộc hiệu năng, không phải sở thích.

---

## 4. VFX

| Hiệu ứng | Số lượng | Ghi chú |
|---|---|---|
| Muzzle flash | 4 biến thể (nhẹ/nặng/năng lượng/nổ) | Dùng chung giữa các vũ khí |
| Trúng đích | 5 (kim loại, thịt, bê tông, năng lượng, acid) | |
| Vụ nổ | 3 cỡ | |
| Xác quái | 3 bộ mảnh vụn | Dùng chung giữa các loại quái |
| Hơi/khói nhiệt | 3 | Xả, quá nhiệt, cảnh báo |
| Trạng thái | 6 | Một cho mỗi status effect |
| Vũng chất lỏng | 2 | Acid, lửa |
| Vỏ đạn | 3 cỡ | |
| Decal | 12 | Máu ×4, cháy ×3, vết đạn ×3, acid ×2 |
| Hiệu ứng trùm | 5 | Riêng cho mỗi trùm |

---

## 5. Âm thanh

| Nhóm | Số file | Nguồn |
|---|---|---|
| Vũ khí | 16 × 3 lớp = 48 | Sonniss / TỰ LÀM |
| Trúng đích | 15 | Freesound CC0 |
| Kẻ địch (actor) | 14 × 4 = 56 | TỰ LÀM (xử lý giọng động vật) |
| Đám đông swarm | 6 lớp | TỰ LÀM |
| Mech | 20 (bước chân, servo, nhiệt, boost, giáp) | Sonniss |
| Giao diện | 15 | Kenney UI Audio |
| Môi trường (5 chương) | 5 nền + 20 điểm nhấn | Freesound |
| Nhạc | 5 chương × 3 tầng = 15 track | Thuê ngoài hoặc thư viện |
| Trùm | 5 track | Thuê ngoài |

---

## 6. Giao diện

| Hạng mục | Số lượng | Nguồn |
|---|---|---|
| Font | 2 (tiêu đề + nội dung) | Google Fonts OFL, phải đủ dấu tiếng Việt |
| Icon | ~80 (vũ khí, module, tài nguyên, trạng thái, mục tiêu) | TỰ LÀM SVG, đồng nhất phong cách |
| Khung/panel 9-slice | 6 | TỰ LÀM |
| Chân dung kẻ địch (Nhật ký) | 18 | Render từ mô hình 3D |
| Nền menu | 3 | Render từ scene trong game |

---

## 7. Danh sách kiểm tra trước khi nhập asset

Mọi asset trước khi vào `res://assets/` phải:

- [ ] Đúng thang tỉ lệ (1 đơn vị = 1 mét), gốc toạ độ ở chân/tâm hợp lý
- [ ] Trục −Z hướng ra trước (quy ước Godot)
- [ ] Trong ngân sách tam giác đã ghi ở tài liệu này
- [ ] Đã sinh LOD nếu trên 2.000 tam giác
- [ ] Texture là kích thước luỹ thừa 2, đã bật nén phù hợp
- [ ] Đặt tên theo `snake_case` khớp quy ước `02-TDD.md` §3
- [ ] Nếu là asset bên thứ ba: đã ghi vào `assets/CREDITS.md` kèm URL và giấy phép
- [ ] Không có vật liệu trùng lặp (kiểm tra xem đã có vật liệu dùng được chưa trước khi tạo mới)

---

## 8. Thứ tự sản xuất đề xuất

Bám theo milestone của backlog để không làm asset cho hệ thống chưa tồn tại:

1. **Hình hộp giữ chỗ cho tất cả** (M0–M2) — không làm asset đẹp trước khi cảm giác chơi đã đúng
2. Mech RONIN-M + 3 vũ khí đầu (M1–M5)
3. 3 loại swarm (M3) — quan trọng vì ràng buộc tam giác chặt, cần làm sớm để kiểm chứng
4. Bộ kiến trúc modular Ch1 (M7)
5. 6 actor đầu (M4)
6. Còn lại theo từng chương (M11)
7. Trùm (M12) — làm cuối vì tốn công nhất và cần hệ thống đã ổn định
