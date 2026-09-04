extends GutTest

const SWARM_SHADER_PATH: String = "res://assets/materials/swarm_crawl.gdshader"

## Kiểm tra contract của shader T-306 mà không phụ thuộc ảnh chụp GPU.


func test_shader_import_va_bien_dich_duoc() -> void:
    assert_true(ResourceLoader.exists(SWARM_SHADER_PATH), "shader swarm phải tồn tại")
    var shader: Shader = load(SWARM_SHADER_PATH) as Shader
    assert_not_null(shader, "Godot phải nạp được shader")
    assert_eq(shader.get_mode(), Shader.MODE_SPATIAL, "shader swarm phải là spatial")


func test_shader_co_uniform_dieu_chinh_animation() -> void:
    var shader: Shader = load(SWARM_SHADER_PATH) as Shader
    var names: Array[StringName] = []
    for uniform: Dictionary in shader.get_shader_uniform_list():
        names.append(uniform["name"] as StringName)

    assert_has(names, &"base_color")
    assert_has(names, &"crawl_speed")
    assert_has(names, &"body_wave")
    assert_has(names, &"side_wave")
    assert_has(names, &"body_frequency")


func test_shader_dung_instance_id_va_instance_color() -> void:
    var source: String = FileAccess.get_file_as_string(SWARM_SHADER_PATH)

    assert_true(source.contains("INSTANCE_ID"), "pha animation phải dựa trên INSTANCE_ID")
    assert_true(source.contains("COLOR"), "shader phải nhận instance color từ MultiMesh")
    assert_true(source.contains("2.399"), "golden angle phải tách pha giữa các instance")
