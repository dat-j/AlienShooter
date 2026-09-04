shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// T-306: Animation hoàn toàn trên GPU; không dùng AnimationPlayer cho swarm.
uniform vec4 base_color : source_color = vec4(0.72, 0.78, 0.60, 1.0);
uniform float crawl_speed : hint_range(0.0, 30.0, 0.1) = 12.0;
uniform float body_wave : hint_range(0.0, 0.2, 0.001) = 0.06;
uniform float side_wave : hint_range(0.0, 0.1, 0.001) = 0.03;
uniform float body_frequency : hint_range(0.0, 10.0, 0.1) = 3.0;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.08;

varying vec4 instance_tint;

void vertex() {
    // Golden angle tạo phân bố pha đều; các instance không chuyển động đồng pha.
    float phase = float(INSTANCE_ID) * 2.399;
    VERTEX.y += sin(TIME * crawl_speed + phase + VERTEX.z * body_frequency) * body_wave;
    VERTEX.x += cos(TIME * 9.0 + phase) * side_wave;
    instance_tint = COLOR;
}

void fragment() {
    ALBEDO = base_color.rgb * instance_tint.rgb;
    ALPHA = base_color.a * instance_tint.a;
    ROUGHNESS = roughness;
    METALLIC = metallic;
}
