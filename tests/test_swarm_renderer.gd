extends GutTest

const SwarmRendererScript: GDScript = preload("res://src/swarm/swarm_renderer.gd")

## Kiểm tra SwarmRenderer gom đơn vị theo type vào đúng MultiMesh.
## Xem docs/05-BACKLOG.md T-305.

var _swarm: SwarmManager
var _renderer: Node3D


func before_each() -> void:
    _swarm = SwarmManager.new()
    _renderer = SwarmRendererScript.new()
    add_child_autofree(_swarm)
    add_child_autofree(_renderer)


func test_moi_type_chi_tao_mot_multimesh_instance() -> void:
    var mesh: BoxMesh = BoxMesh.new()
    var first: MultiMeshInstance3D = _renderer.configure_type(0, mesh)
    var second: MultiMeshInstance3D = _renderer.configure_type(0, mesh)
    _renderer.configure_type(1, mesh)

    assert_same(first, second, "cấu hình lại cùng type phải tái sử dụng renderer")
    assert_eq(_renderer.get_configured_type_count(), 2, "mỗi type chỉ có một renderer")
    assert_eq(_renderer.get_child_count(), 2, "mỗi type chỉ tạo một MultiMeshInstance3D")
    assert_eq(first.multimesh.instance_count, SwarmManager.MAX_SWARM_UNITS, "buffer phải cấp phát đủ trần swarm")


func test_sync_gom_transform_theo_type() -> void:
    var mesh: BoxMesh = BoxMesh.new()
    var type_zero: MultiMeshInstance3D = _renderer.configure_type(0, mesh)
    var type_one: MultiMeshInstance3D = _renderer.configure_type(1, mesh)
    _swarm.spawn(Vector3(1.0, 0.0, 2.0), Vector3.ZERO, 10.0, 0)
    _swarm.spawn(Vector3(3.0, 0.0, 4.0), Vector3.ZERO, 10.0, 1)
    _swarm.spawn(Vector3(5.0, 0.0, 6.0), Vector3.ZERO, 10.0, 0)

    _renderer.sync_from_manager(_swarm)
    await get_tree().process_frame

    assert_eq(type_zero.multimesh.visible_instance_count, 2, "type 0 phải hiện đúng hai đơn vị")
    assert_eq(type_one.multimesh.visible_instance_count, 1, "type 1 phải hiện đúng một đơn vị")
    assert_true(type_zero.custom_aabb.has_point(Vector3(1.0, 0.0, 2.0)), "AABB type 0 phải bao transform đầu")
    assert_true(type_zero.custom_aabb.has_point(Vector3(5.0, 0.0, 6.0)), "AABB type 0 phải bao transform thứ hai")
    assert_true(type_one.custom_aabb.has_point(Vector3(3.0, 0.0, 4.0)), "AABB type 1 phải bao transform của nó")


func test_sync_an_slot_thua_sau_khi_kill() -> void:
    var instance: MultiMeshInstance3D = _renderer.configure_type(0, BoxMesh.new())
    var first_id: int = _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 10.0, 0)
    _swarm.spawn(Vector3.ONE, Vector3.ZERO, 10.0, 0)
    _renderer.sync_from_manager(_swarm)
    assert_eq(instance.multimesh.visible_instance_count, 2)

    _swarm.kill(first_id)
    _renderer.sync_from_manager(_swarm)
    await get_tree().process_frame

    assert_eq(instance.multimesh.visible_instance_count, 1, "kill phải ẩn instance thừa")
    assert_true(instance.custom_aabb.has_point(Vector3.ONE), "AABB phải theo đơn vị được swap")


func test_custom_aabb_bao_phu_toan_bo_instance() -> void:
    var instance: MultiMeshInstance3D = _renderer.configure_type(0, BoxMesh.new())
    _swarm.spawn(Vector3(-4.0, 0.0, -2.0), Vector3.ZERO, 10.0, 0)
    _swarm.spawn(Vector3(6.0, 1.0, 8.0), Vector3.ZERO, 10.0, 0)

    _renderer.sync_from_manager(_swarm)

    assert_true(instance.custom_aabb.has_point(Vector3(-4.0, 0.0, -2.0)), "AABB phải chứa instance nhỏ nhất")
    assert_true(instance.custom_aabb.has_point(Vector3(6.0, 1.0, 8.0)), "AABB phải chứa instance lớn nhất")


func test_type_khong_co_don_vi_co_visible_count_bang_khong() -> void:
    var instance: MultiMeshInstance3D = _renderer.configure_type(7, BoxMesh.new())

    _renderer.sync_from_manager(_swarm)

    assert_eq(instance.multimesh.visible_instance_count, 0, "type rỗng không được tạo draw instance")


func test_multimesh_ho_tro_instance_color_cho_shader_variant() -> void:
    var instance: MultiMeshInstance3D = _renderer.configure_type(0, BoxMesh.new())
    var tint: Color = Color(0.7, 0.9, 0.5, 1.0)

    _swarm.spawn(Vector3.ZERO, Vector3.ZERO, 10.0, 0)
    _renderer.sync_from_manager(_swarm)
    assert_true(instance.multimesh.use_colors, "buffer màu phải được bật trước khi cấp instance")
    assert_true(_renderer.set_instance_color(0, 0, tint), "phải gán được màu biến thể")
    assert_false(_renderer.set_instance_color(9, 0, tint), "type chưa cấu hình phải bị từ chối")

