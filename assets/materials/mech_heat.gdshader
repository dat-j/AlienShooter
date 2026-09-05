shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Thân mech nóng lên thì đỏ lên. Xem docs/03-ART-BIBLE.md §8 ("ánh đỏ trên
// thân mech" khi quá nhiệt) và docs/05-BACKLOG.md T-608.
//
// `heat_glow` do MechVfx đẩy vào mỗi frame, 0 = nguội, 1 = quá nhiệt. Đây là
// tín hiệu GAMEPLAY chứ không phải trang trí: người chơi phải đọc được mức
// nhiệt của mình mà không rời mắt khỏi trận đánh (UX-UI §2.1).

uniform vec3 albedo_color : source_color = vec3(0.227, 0.255, 0.290);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.6;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.45;

// Đỏ nguy hiểm #E03B3B (ART-BIBLE §2).
uniform vec3 heat_color : source_color = vec3(0.878, 0.231, 0.231);
uniform float heat_glow : hint_range(0.0, 1.0) = 0.0;
uniform float heat_energy : hint_range(0.0, 8.0) = 3.0;
// Nhịp đập khi quá nhiệt — ánh sáng tĩnh đọc như hỏng vật liệu, ánh sáng
// đập đọc như "cỗ máy này sắp nổ".
uniform float pulse_hz = 3.0;
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	ALBEDO = albedo_color;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;

	float pulse = 1.0 - pulse_depth + pulse_depth * sin(TIME * pulse_hz * 6.2831853);
	// Bình phương để mức nhiệt thấp gần như không thấy gì: ánh đỏ chỉ được
	// bắt đầu kể chuyện khi nhiệt đã thật sự cao.
	float glow = heat_glow * heat_glow * pulse;
	EMISSION = heat_color * glow * heat_energy;
}
