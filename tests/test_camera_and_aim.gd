extends GutTest

## T-103 · T-104 · T-105 — tách xoay thân/chân, camera bám và lệch theo con
## trỏ, chiếu con trỏ xuống mặt đất.

const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")


func _make_mech() -> MechController:
    return add_child_autofree(MECH_SCENE.instantiate()) as MechController


# --- T-105: chiếu con trỏ -----------------------------------------------

func test_ray_straight_down_hits_ground_plane_below_camera() -> void:
    var point: Vector3 = AimController.intersect_ground(
        Vector3(3.0, 20.0, -7.0), Vector3.DOWN, 1.5
    )
    assert_almost_eq(point.x, 3.0, 0.001)
    assert_almost_eq(point.y, 1.5, 0.001, "phải cắt đúng mặt phẳng Y của mech")
    assert_almost_eq(point.z, -7.0, 0.001)


func test_slanted_ray_hits_ground_further_away() -> void:
    var direction: Vector3 = Vector3(0.0, -1.0, -1.0).normalized()
    var point: Vector3 = AimController.intersect_ground(Vector3(0.0, 10.0, 0.0), direction, 0.0)
    assert_almost_eq(point.z, -10.0, 0.001, "tia chếch 45° từ độ cao 10m phải chạm đất cách 10m")


func test_ray_parallel_to_ground_falls_back_to_origin_projection() -> void:
    var point: Vector3 = AimController.intersect_ground(
        Vector3(2.0, 5.0, 2.0), Vector3.FORWARD, 0.0
    )
    assert_almost_eq(point.y, 0.0, 0.001, "tia song song mặt đất phải trả về hình chiếu, không lỗi")


func test_stick_below_deadzone_is_ignored() -> void:
    var body := Vector3(1.0, 0.0, 1.0)
    var point: Vector3 = AimController.stick_to_aim_point(body, Vector2(0.1, 0.1), 12.0)
    assert_eq(point, body, "dưới bán kính chết 0.2 thì không đổi hướng ngắm")


func test_stick_is_normalised_to_fixed_radius() -> void:
    var point: Vector3 = AimController.stick_to_aim_point(Vector3.ZERO, Vector2(0.4, 0.0), 12.0)
    assert_almost_eq(point.x, 12.0, 0.001, "cần đẩy nhẹ hay mạnh đều cho cùng bán kính ngắm")
    assert_almost_eq(point.length(), 12.0, 0.001)


func test_mouse_projection_through_real_camera_lands_under_cursor() -> void:
    var mech := _make_mech()
    var camera: Camera3D = mech.camera_rig.get_node("Camera3D") as Camera3D
    var viewport: Viewport = mech.get_viewport()
    var centre: Vector2 = Vector2(viewport.get_visible_rect().size) * 0.5
    var point: Vector3 = AimController.project_screen_to_ground(camera, centre, 0.0)
    assert_almost_eq(point.y, 0.0, 0.001, "điểm ngắm luôn nằm trên mặt phẳng của mech")
    assert_lt(point.distance_to(mech.global_position), 6.0,
        "con trỏ giữa màn hình phải rơi gần chỗ mech đứng")


# --- T-104: camera ------------------------------------------------------

func test_camera_offsets_toward_cursor_by_a_quarter() -> void:
    var focus: Vector3 = CameraRig.compute_focus(Vector3.ZERO, Vector3(8.0, 0.0, 0.0))
    assert_almost_eq(focus.x, 2.0, 0.001, "lệch 25% quãng đường tới con trỏ")


func test_camera_offset_is_capped_at_four_metres() -> void:
    var focus: Vector3 = CameraRig.compute_focus(Vector3.ZERO, Vector3(100.0, 0.0, 0.0))
    assert_almost_eq(focus.x, 4.0, 0.001, "độ lệch tối đa 4m theo ART-BIBLE §3")


func test_camera_pitch_distance_and_fov_match_art_bible() -> void:
    var mech := _make_mech()
    var rig := mech.camera_rig as CameraRig
    var camera: Camera3D = rig.camera
    assert_almost_eq(camera.fov, 38.0, 0.01, "FOV 38°")
    assert_almost_eq(rad_to_deg(camera.rotation.x), -62.0, 0.01, "góc chếch 62°")
    assert_almost_eq(camera.position.length(), 22.0, 0.01, "cách mech 22m")


func test_camera_distance_is_clamped_to_supported_range() -> void:
    var mech := _make_mech()
    var rig := mech.camera_rig as CameraRig
    rig.set_distance(40.0)
    assert_almost_eq(rig.distance, 28.0, 0.001, "xa nhất 28m")
    rig.set_distance(2.0)
    assert_almost_eq(rig.distance, 18.0, 0.001, "gần nhất 18m")


func test_camera_shake_adds_to_follow_position_instead_of_replacing_it() -> void:
    var mech := _make_mech()
    var rig := mech.camera_rig as CameraRig
    rig.shake_offset = Vector3(0.5, 0.0, 0.0)
    rig.update_follow(1.0 / 60.0)
    assert_almost_eq(rig.global_position.x - rig.get_follow_position().x, 0.5, 0.001,
        "rung phải cộng thêm chứ không thay thế vị trí bám")


# --- T-103: tách xoay thân trên / chân ----------------------------------

func test_torso_faces_cursor_immediately() -> void:
    var mech := _make_mech()
    mech.aim_controller._aim_point = mech.global_position + Vector3(10.0, 0.0, 0.0)
    mech.update_orientation(1.0 / 60.0)
    # Quay quanh Y âm 90° là hướng −Z của node chỉ về +X (quy ước "trước" của Godot).
    assert_almost_eq(rad_to_deg(mech.torso_pivot.rotation.y), -90.0, 0.01,
        "thân trên xoay tức thời về phía con trỏ")


func test_legs_turn_at_chassis_speed_not_instantly() -> void:
    var mech := _make_mech()
    mech.velocity = Vector3(6.0, 0.0, 0.0)
    mech.aim_controller._aim_point = mech.global_position + Vector3(10.0, 0.0, 0.0)
    mech.update_orientation(0.1)
    assert_almost_eq(rad_to_deg(mech.legs_pivot.rotation.y), -48.0, 0.01,
        "480°/s trong 0.1s là 48°, không xoay tức thời")


func test_legs_are_dragged_when_offset_exceeds_limit() -> void:
    var legs: float = MechController.clamp_legs_to_torso(deg_to_rad(-180.0), 0.0)
    assert_almost_eq(absf(rad_to_deg(legs)), 110.0, 0.01,
        "lệch quá 110° thì chân bị kéo về đúng giới hạn")


func test_legs_keep_their_angle_inside_the_limit() -> void:
    var legs: float = MechController.clamp_legs_to_torso(deg_to_rad(60.0), 0.0)
    assert_almost_eq(rad_to_deg(legs), 60.0, 0.01, "trong 110° thì chân giữ nguyên hướng đi")


func test_legs_do_not_turn_while_standing_still() -> void:
    var mech := _make_mech()
    mech.velocity = Vector3.ZERO
    mech.legs_pivot.rotation.y = deg_to_rad(30.0)
    mech.aim_controller._aim_point = mech.global_position + Vector3(0.0, 0.0, -10.0)
    mech.update_orientation(1.0 / 60.0)
    assert_almost_eq(rad_to_deg(mech.legs_pivot.rotation.y), 30.0, 0.01,
        "đứng yên thì chân không tự xoay (không rung)")
