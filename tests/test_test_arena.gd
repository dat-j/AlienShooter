extends GutTest

## T-111 — sân tập: phòng 60×60 có dốc/bậc/cột, mech chơi được, bảng debug.

const ARENA_SCENE: PackedScene = preload("res://scenes/main/test_arena.tscn")


func _make_arena() -> Node3D:
    return add_child_autofree(ARENA_SCENE.instantiate()) as Node3D


func test_arena_runs_standalone_with_a_playable_mech() -> void:
    var arena := _make_arena()
    var mech := arena.get_node_or_null("Mech") as MechController
    assert_not_null(mech, "sân tập phải có sẵn mech chơi được")
    assert_not_null(mech.camera_rig, "mech trong sân tập phải có camera")
    assert_true(mech.global_position.y >= 0.0, "mech phải đứng trên sàn")


func test_arena_has_slope_steps_and_pillars_to_test_movement() -> void:
    var arena := _make_arena()
    assert_not_null(arena.get_node_or_null("Ramp"), "phải có dốc")
    assert_not_null(arena.get_node_or_null("Step0"), "phải có bậc")
    assert_not_null(arena.get_node_or_null("Pillar0"), "phải có cột chắn")
    var walls: Array[String] = ["WallNorth", "WallSouth", "WallEast", "WallWest"]
    for wall: String in walls:
        assert_not_null(arena.get_node_or_null(wall), "phải kín bốn phía: thiếu %s" % wall)


func test_floor_is_sixty_by_sixty_metres() -> void:
    var arena := _make_arena()
    var floor_body := arena.get_node_or_null("Floor") as StaticBody3D
    var shape := floor_body.get_node("CollisionShape3D") as CollisionShape3D
    var box := shape.shape as BoxShape3D
    assert_almost_eq(box.size.x, 60.0, 0.001, "sàn rộng 60m")
    assert_almost_eq(box.size.z, 60.0, 0.001, "sàn dài 60m")


func test_debug_panel_reports_speed_position_and_frame_time() -> void:
    var arena := _make_arena()
    var mech := arena.get_node_or_null("Mech") as MechController
    mech.velocity = Vector3(3.0, 0.0, 4.0)
    var text: String = DebugStatsPanel.build_text(mech, 1.0 / 60.0)
    assert_string_contains(text, "5.00", "phải hiện tốc độ thực (3,4 → 5 m/s)")
    assert_string_contains(text, "vi tri", "phải hiện vị trí")
    assert_string_contains(text, "frame", "phải hiện frame time")


func test_debug_panel_survives_missing_mech() -> void:
    var text: String = DebugStatsPanel.build_text(null, 0.016)
    assert_string_contains(text, "chua gan mech".replace("chua gan", "chưa gắn"),
        "không có mech thì báo rõ chứ không crash")
