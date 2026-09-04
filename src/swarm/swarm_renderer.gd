class_name SwarmRenderer
extends Node3D

## Vẽ trạng thái của SwarmManager bằng một MultiMeshInstance3D cho mỗi loại.
## Xem docs/05-BACKLOG.md T-305 và docs/02-TDD.md §6.1.
##
## Loại swarm được cấu hình trước khi chiến đấu. sync_from_manager() chỉ cập
## nhật các buffer MultiMesh đã cấp phát sẵn và không tạo node theo đơn vị.

const DEFAULT_BOUNDS_PADDING: float = 1.0

@export_range(0.0, 10.0, 0.1) var bounds_padding: float = DEFAULT_BOUNDS_PADDING

var _instances_by_type: Dictionary[int, MultiMeshInstance3D] = {}


## Tạo renderer cho một loại swarm. Gọi lại với cùng type chỉ cập nhật mesh
## và material, không tạo draw call thứ hai.
func configure_type(swarm_type: int, mesh: Mesh, material: Material = null) -> MultiMeshInstance3D:
    assert(swarm_type >= 0 and swarm_type <= 255, "swarm_type phải nằm trong khoảng byte")
    assert(mesh != null, "Mỗi loại swarm phải có mesh")

    var instance: MultiMeshInstance3D = _instances_by_type.get(swarm_type) as MultiMeshInstance3D
    if instance == null:
        instance = MultiMeshInstance3D.new()
        instance.name = "SwarmType%d" % swarm_type
        instance.multimesh = MultiMesh.new()
        instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
        instance.multimesh.use_colors = true
        instance.multimesh.instance_count = SwarmManager.MAX_SWARM_UNITS
        instance.multimesh.visible_instance_count = 0
        add_child(instance)
        _instances_by_type[swarm_type] = instance

    instance.multimesh.mesh = mesh
    instance.material_override = material
    return instance


## Sao chép vị trí các đơn vị sống sang MultiMesh tương ứng với loại của nó.
## Transform được ghi liên tục từ index 0 cho từng loại để tận dụng
## visible_instance_count và giữ đúng một draw call cho mỗi loại.
func sync_from_manager(manager: SwarmManager) -> void:
    for type_value: Variant in _instances_by_type:
        var swarm_type: int = int(type_value)
        var instance: MultiMeshInstance3D = _instances_by_type[swarm_type] as MultiMeshInstance3D
        var write_index: int = 0
        var has_bounds: bool = false
        var bounds: AABB = AABB()
        # Godot bỏ qua ghi transform vào slot nằm ngoài visible_instance_count.
        # Mở toàn bộ buffer trong lúc ghi rồi thu lại đúng số lượng ở cuối.
        instance.multimesh.visible_instance_count = -1

        for unit_index: int in range(manager._alive_count):
            if int(manager._types[unit_index]) != swarm_type:
                continue

            var position: Vector3 = manager._positions[unit_index]
            instance.multimesh.set_instance_transform(write_index, Transform3D(Basis.IDENTITY, position))
            write_index += 1

            if has_bounds:
                bounds = bounds.expand(position)
            else:
                bounds = AABB(position, Vector3.ZERO)
                has_bounds = true

        instance.multimesh.visible_instance_count = write_index
        if has_bounds:
            var padding: Vector3 = Vector3.ONE * bounds_padding
            instance.custom_aabb = AABB(bounds.position - padding, bounds.size + padding * 2.0)
        else:
            instance.custom_aabb = AABB()


## Trả renderer của type để nối debug/profiling mà không cần tìm node theo tên.
func get_type_instance(swarm_type: int) -> MultiMeshInstance3D:
    return _instances_by_type.get(swarm_type) as MultiMeshInstance3D


func get_configured_type_count() -> int:
    return _instances_by_type.size()


## Gán màu biến thể theo id logic. Shader swarm nhân màu này với base_color.
## Màu được lưu trên MultiMesh nên không tạo material riêng hay draw call mới.
func set_instance_color(swarm_type: int, instance_index: int, color: Color) -> bool:
    var instance: MultiMeshInstance3D = get_type_instance(swarm_type)
    if instance == null or instance_index < 0 or instance_index >= instance.multimesh.instance_count:
        return false
    var previous_visible_count: int = instance.multimesh.visible_instance_count
    instance.multimesh.visible_instance_count = maxi(instance_index + 1, previous_visible_count)
    instance.multimesh.set_instance_color(instance_index, color)
    instance.multimesh.visible_instance_count = previous_visible_count
    return true

