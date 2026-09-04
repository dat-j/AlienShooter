extends GutTest

const PerfReportScript: GDScript = preload("res://tools/perf_report.gd")


func test_canh_perf_nap_duoc_va_co_du_pipeline() -> void:
    var scene: PackedScene = load("res://scenes/main/perf_swarm.tscn") as PackedScene
    assert_not_null(scene)
    var instance: Node = scene.instantiate()
    add_child_autofree(instance)
    await get_tree().process_frame

    assert_eq(instance.get_node("SwarmManager").get_alive_count(), 300)
    assert_eq(instance.get_node("SwarmManager").get_batch_count(), 4)
    assert_not_null(instance.get_node("SwarmRenderer").get_type_instance(0))
    assert_not_null(instance.get_node("HUD/Metrics"))


func test_bao_cao_csv_co_header_va_mau_do() -> void:
    var scene: PackedScene = load("res://scenes/main/perf_swarm.tscn") as PackedScene
    var instance: Node3D = scene.instantiate()
    instance.auto_export_after_samples = false
    add_child_autofree(instance)
    await get_tree().physics_frame
    await get_tree().physics_frame

    var path: String = "user://test_perf_swarm.csv"
    assert_eq(instance.export_csv(path), OK)
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    assert_not_null(file)
    var content: String = file.get_as_text()
    file.close()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    assert_true(content.begins_with(PerfReportScript.CSV_HEADER))
    assert_gt(instance.get_sample_count(), 0)
    assert_true(content.contains("300,4,"))


func test_tong_chi_phi_bang_tong_ba_he_thong() -> void:
    var report: Node3D = PerfReportScript.new()
    report._last_flow_usec = 10
    report._last_movement_usec = 20
    report._last_render_usec = 30
    assert_eq(report.get_swarm_update_usec(), 60)
    report.free()
