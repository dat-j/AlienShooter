# IRONHIVE — Art Bible

> Nguồn chân lý cho **hình ảnh và âm thanh**. Mục tiêu: đẹp mà vẫn giữ được 300 kẻ địch ở 60 FPS. Mỗi quyết định dưới đây đều là sự đánh đổi có chủ ý giữa hai điều đó.

---

## 1. Câu thần chú

> **"Kim loại lạnh, sạch, có chủ đích — bị thứ gì đó ấm, ẩm và vô định ăn mòn."**

Toàn bộ ngôn ngữ hình ảnh là sự đối lập giữa hai phe:

| | **Mech / Vantek** | **The Bloom** |
|---|---|---|
| Hình khối | Thẳng, đối xứng, vát góc, tấm ghép rõ ràng | Cong, bất đối xứng, phân nhánh, phồng |
| Bề mặt | Kim loại sơn, mài mòn ở cạnh, dầu mỡ | Ướt bóng, dưới bề mặt xuyên sáng, sợi |
| Màu | Xám lạnh, cam an toàn, xanh cyan phát sáng | Tím thối, xanh nõn chuối bệnh hoạn |
| Ánh sáng | Nguồn cứng, đèn pha định hướng | Tự phát sáng, khuếch tán, đập theo nhịp |
| Chuyển động | Cơ khí, có trọng lượng, giật khớp | Trườn, co giật, mượt bất thường |

Người chơi phải phân biệt được bạn/thù chỉ bằng **hình bóng (silhouette)** trong 0.1 giây, kể cả khi màn hình đầy hiệu ứng.

## 2. Bảng màu

```
=== PHE MECH / CÔNG NGHIỆP ===
Thép nền        #3A414A    thân mech, kết cấu
Thép sáng       #5C6670    tấm giáp nổi
Cam Vantek      #E8752A    sọc cảnh báo, điểm nhấn thương hiệu
Cyan HUD        #48D6E0    tự phát sáng, giao diện, đèn thân thiện
Vàng cảnh báo   #F2C230    ngưỡng nhiệt, mục tiêu
Đỏ nguy hiểm    #E03B3B    máu thấp, quá nhiệt, đe doạ

=== PHE BLOOM ===
Tím thịt        #6B2F5E    khối cơ thể chính
Tím sẫm         #3D1638    vùng tối, hốc
Xanh bào tử     #9BD64A    tự phát sáng, điểm yếu, acid
Hồng tuỷ        #C4587E    nội tạng lộ ra, vết thương
Vàng trứng      #D9C46B    túi trứng, ổ

=== MÔI TRƯỜNG ===
Bê tông         #6E6A63
Gỉ sét          #7A4B2E
Bóng tối        #12161C    (không bao giờ dùng đen tuyệt đối)
Sương ánh sáng  #1E2A38
```

**Luật:** màu **Xanh bào tử `#9BD64A`** chỉ được dùng cho những gì thuộc về Bloom và **những gì có thể bắn được**. Không bao giờ dùng cho trang trí môi trường trung tính. Nó là tín hiệu đọc-được-tức-thì cho người chơi.

## 3. Camera

| Thông số | Giá trị |
|---|---|
| Loại | `Camera3D`, perspective |
| FOV | 38° (hẹp, để giảm méo, gần cảm giác orthographic mà vẫn có chiều sâu) |
| Góc chếch | 62° so với phương ngang |
| Khoảng cách | 22m so với người chơi (co giãn 18–28m theo bối cảnh) |
| Xoay | **Khoá.** Người chơi không xoay được camera |
| Bám theo | Lerp mượt, hệ số 8.0, **cộng thêm lệch 25% về phía con trỏ chuột** (tối đa 4m) |
| Rung | Do `JuiceDirector` điều khiển, luôn cộng thêm chứ không thay thế vị trí bám |

Việc lệch theo con trỏ là chi tiết nhỏ nhưng quan trọng: nó cho người chơi nhìn xa hơn về hướng đang ngắm.

## 4. Ánh sáng

Godot Forward+.

- **Một `DirectionalLight3D`** làm nguồn chính, có đổ bóng (`shadow_mode = PSSM 2 Split`). Đây là nguồn đổ bóng duy nhất luôn bật.
- **Đèn môi trường:** `OmniLight3D`/`SpotLight3D` đặt tay trong phòng, **tắt đổ bóng** trừ tối đa 2 đèn nhấn mỗi phòng.
- **Đèn pha mech:** một `SpotLight3D` gắn trên thân trên, có đổ bóng. Là nguồn sáng cảm xúc chính ở các chương tối (3, 4).
- **Đèn tạm** (muzzle flash, vụ nổ, đạn plasma): `OmniLight3D` lấy từ pool, **luôn tắt đổ bóng**, thời gian sống < 0.15s, trần **12 đèn cùng lúc**.
- **GI:** dùng `LightmapGI` nướng sẵn cho hình học tĩnh của phòng. **Không dùng SDFGI** (quá nặng và không hợp với hình học sinh ngẫu nhiên). `ReflectionProbe` đặt tay, một cái mỗi phòng lớn.
- **Sương mù thể tích:** bật ở mật độ thấp, đây là công cụ tạo không khí chính. Chương 3 và 5 dùng nhiều.

## 5. Hiệu ứng hậu kỳ

`WorldEnvironment` một cái cho mỗi chương, khác nhau ở tông màu.

| Hiệu ứng | Thiết lập | Ghi chú |
|---|---|---|
| Bloom | Ngưỡng 0.9, cường độ 0.35 | Làm vật liệu tự phát sáng nổi bật |
| SSAO | Bán kính 1.2, cường độ 1.4 | Gắn mech xuống mặt sàn |
| SSR | Tắt | Quá đắt, lợi ích thấp ở góc nhìn này |
| Tonemap | ACES, phơi sáng 1.0 | |
| Color grading | LUT riêng mỗi chương | Công cụ chính tạo bản sắc từng chương |
| Vignette | Nhẹ, tăng lên khi máu thấp | Qua shader trên `ColorRect` toàn màn |
| Chromatic aberration | 0 mặc định, nhảy lên khi bị đánh | `JuiceDirector` điều khiển |
| Motion blur | Tắt | Gây nhiễu khi có nhiều đối tượng chuyển động |

## 6. Ngân sách mô hình

| Đối tượng | Tam giác | Texture | Ghi chú |
|---|---|---|---|
| Mech người chơi | 25.000 | 2048² (albedo/normal/ORM) | Vật thể ngắm nhìn kỹ nhất |
| Vũ khí | 3.000 mỗi cái | Dùng chung atlas 1024² | |
| Kẻ địch SWARM | **600** | Dùng chung atlas 512² | Cực kỳ nghiêm ngặt — vẽ 300 con |
| Kẻ địch ACTOR | 4.000–8.000 | 1024² | |
| Trùm | 30.000 | 2048² | |
| Vật thể môi trường | 200–2.500 | Atlas dùng chung theo chương | |
| Mảnh kiến trúc | 500–3.000 | Vật liệu trilinear/triplanar dùng chung | |

**LOD:** bắt buộc cho mọi thứ trên 2.000 tam giác. LOD0 → LOD1 ở 15m, LOD1 → LOD2 ở 30m. Dùng tính năng tự sinh LOD của Godot 4 làm mặc định, chỉ làm tay khi cần.

**Vật liệu:** tối đa **6 vật liệu duy nhất** hiển thị trên màn tại một thời điểm cho phe kẻ địch. Gộp atlas quyết liệt. Mỗi vật liệu thêm vào là một draw call phá vỡ instancing.

## 7. Animation

### Mech người chơi
- Chân: `idle`, `walk_fwd`, `walk_back`, `strafe_L`, `strafe_R`, `boost_start`, `boost_loop`, `boost_end`, `overheat_stagger`
- Trộn bằng `AnimationTree` với `BlendSpace2D` (trục: tốc độ tiến/lùi × trái/phải)
- Thân trên: bù nghiêng theo gia tốc, giật lùi khi bắn (do code, không phải animation clip)
- **Bám mặt đất theo IK:** dùng `SkeletonIK3D` cho hai chân bám địa hình gồ ghề. Tính năng bán được cả game — ưu tiên cao.

### ACTOR
- Tối thiểu: `idle`, `move`, `attack`, `hit_react`, `death` (2 biến thể)
- `AnimationTree` với `StateMachine` đồng bộ với AI state machine trong code
- Root motion: **không dùng**. Di chuyển do code điều khiển.

### SWARM
- **Không có `AnimationPlayer`.** Chuyển động do vertex shader tạo ra:
  ```glsl
  // Trườn: dao động sin dọc trục cơ thể, offset pha theo INSTANCE_ID
  float phase = float(INSTANCE_ID) * 2.399;
  VERTEX.y += sin(TIME * 12.0 + phase + VERTEX.z * 3.0) * 0.06;
  VERTEX.x += cos(TIME * 9.0  + phase) * 0.03;
  ```
- Đây là lý do bắt buộc mà swarm phải có ngân sách tam giác thấp và một vật liệu dùng chung.

## 8. VFX

Ưu tiên `GPUParticles3D` với `ParticleProcessMaterial`. Tất cả đều pooled.

| Hiệu ứng | Hạt | Thời gian sống | Ghi chú |
|---|---|---|---|
| Muzzle flash | 8 + 1 đèn + 1 quad billboard | 0.08s | Phải rất ngắn, rất sáng |
| Vỏ đạn văng | 1 mỗi phát, RigidBody3D pooled | 4s rồi ẩn | Trần 60 vỏ. Có tiếng leng keng |
| Tia đạn | Đường trải dài | 0.05s | Chỉ cho đạn > 60 m/s |
| Trúng kim loại | 12 tia lửa | 0.4s | |
| Trúng thịt | 20 giọt + phun sương | 0.6s | Sinh decal |
| Xác quái | Mảnh vụn pooled | 6s rồi tan | Trần 60 |
| Vụ nổ | 40 hạt + sóng xung kích + đèn | 0.9s | |
| Xả nhiệt | Cột hơi từ tấm tản nhiệt | 1.2s | Đọc rõ ràng, đây là tín hiệu gameplay |
| Quá nhiệt | Hơi phụt liên tục + ánh đỏ trên thân mech | Cho tới khi hết | |
| Vỡ giáp | Mảnh giáp + tia lửa + rung màn | 0.5s | |
| Vũng acid | Decal + hạt bay lên | 8s | |

**Decal:** dùng node `Decal` của Godot. Trần **150 cái**, hàng đợi FIFO. Máu, vết cháy, vết đạn. Chúng là thứ khiến căn phòng kể lại được trận đánh vừa diễn ra — đừng bỏ.

## 9. Juice — bảng tham số

Do `JuiceDirector` quản lý, tất cả phải bật/tắt được trong phần Trợ năng.

| Sự kiện | Rung màn (biên độ/thời gian) | Hitstop | Rung tay cầm |
|---|---|---|---|
| Bắn súng nhẹ | 0.04 / 0.05s | — | Nhẹ |
| Bắn súng nặng | 0.15 / 0.10s | 0.02s | Trung bình |
| Rail Lance | 0.30 / 0.18s | 0.05s | Mạnh |
| Diệt swarm | — | — | — |
| Diệt actor | 0.08 / 0.08s | 0.04s | Nhẹ |
| Diệt trùm (mỗi phase) | 0.45 / 0.60s | 0.20s | Mạnh |
| Người chơi bị đánh | 0.20 / 0.15s | — | Trung bình + CA 0.4 |
| Vỡ giáp | 0.35 / 0.25s | 0.08s | Mạnh |
| Quá nhiệt | 0.10 liên tục | — | Rung nền |
| Vụ nổ gần | 0.40 / 0.30s | 0.06s | Mạnh |

**Hitstop** = tạm dừng `Engine.time_scale` cực ngắn. Là gia vị mạnh nhất trong bếp — dùng ít nhưng đúng chỗ.

## 10. Âm thanh

### Bus
```
Master
├── SFX
│   ├── Weapons      (giới hạn 8 instance đồng thời, ưu tiên theo khoảng cách)
│   ├── Enemies      (giới hạn 12, gộp âm swarm)
│   ├── Player
│   ├── Impacts      (giới hạn 10)
│   └── Ambience
├── Music
└── UI
```

**Gộp âm swarm:** không phát riêng cho từng con trong 300 con. `SwarmManager` phát **một** âm "đám đông" duy nhất, âm lượng và cao độ điều chế theo số lượng gần người chơi. Đây vừa là quyết định hiệu năng vừa là quyết định thẩm mỹ — kết quả nghe hay hơn nhiều.

### Nguyên tắc thiết kế âm thanh
- Vũ khí cần **lớp trầm rõ ràng** (dưới 120 Hz). Không có bass thì không cảm thấy nặng.
- Mỗi phát bắn có 3 lớp: đầu tiếng (transient) + thân + đuôi vang theo không gian phòng.
- Biến thiên cao độ ±4% mỗi lần phát để tránh tiếng "súng máy đồ chơi".
- Ưu tiên tần số: khi quá nhiệt sắp xảy ra, ducking mọi thứ khác để tiếng cảnh báo lọt lên trên.

### Nhạc
- Nhạc động 3 tầng: `ambient` → `combat` → `intense`, chuyển tiếp theo mức áp lực của Spawn Director.
- Chuyển tầng ở ranh giới ô nhịp, crossfade 2 giây.
- Phong cách: nền công nghiệp tối, percussion kim loại, synth trầm. Không dùng dàn nhạc orchestral anh hùng.

## 11. Giao diện — phong cách

- **Diegetic ở mức vừa phải:** HUD trông như màn hình buồng lái, có nhiễu quét nhẹ và cong nhẹ ở mép, nhưng không đánh đổi tính đọc-được.
- Font: sans-serif kỹ thuật, chữ hoa cho nhãn, có bảng chữ Việt đầy đủ dấu. Đề xuất: **Rajdhani** hoặc **Chakra Petch** (Google Fonts, có dấu tiếng Việt, giấy phép OFL).
- Không hoạt hình mềm mại. Chuyển tiếp giao diện là bật/tắt cứng, trượt cơ khí, kèm âm thanh relay.
- Mọi ký hiệu quan trọng phải đọc được ở 1080p khi nhân vật chiếm khoảng 8% chiều cao màn hình.

## 12. Trợ năng (bắt buộc, không phải tuỳ chọn)

- Thanh trượt cường độ rung màn hình (0–100%, mặc định 70%)
- Bật/tắt hitstop
- Bật/tắt nhấp nháy màn hình
- Chế độ mù màu: bổ sung ký hiệu hình dạng cho kẻ địch tinh nhuệ, không chỉ dựa vào màu
- Cỡ chữ giao diện: 100% / 125% / 150%
- Bật/tắt tự động bắn (giữ chuột thành bật/tắt)
- Hỗ trợ gán phím đầy đủ
- Thanh trượt tốc độ game 50–100% (chỉ chế độ đơn, không có bảng xếp hạng nên không cần lo)
