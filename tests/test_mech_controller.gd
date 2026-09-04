extends GutTest

## T-101 — khung sườn Mech.tscn: cây node đúng docs/02-TDD.md §5, nạp được
## ChassisData, scene chạy độc lập không lỗi.

const MECH_SCENE: PackedScene = preload("res://scenes/player/mech.tscn")


func _make_mech() -> MechController:
    return add_child_autofree(MECH_SCENE.instantiate()) as MechController


func test_scene_instantiates_with_node_tree_from_tdd() -> void:
    var mech := _make_mech()
    assert_not_null(mech, "mech.tscn phải khởi tạo được độc lập")
    assert_not_null(mech.legs_pivot, "phải có LegsPivot")
    assert_not_null(mech.torso_pivot, "phải có TorsoPivot")
    assert_not_null(mech.weapon_mount_left, "phải có WeaponMountLeft")
    assert_not_null(mech.weapon_mount_right, "phải có WeaponMountRight")
    assert_not_null(mech.hurtbox, "phải có Hurtbox")
    assert_not_null(mech.pickup_radius, "phải có PickupRadius")
    assert_not_null(mech.camera_rig, "phải có CameraRig")


func test_loads_default_chassis_when_none_assigned() -> void:
    var mech := _make_mech()
    assert_not_null(mech.chassis_data, "phải có ChassisData sau _ready()")
    assert_eq(mech.chassis_data.id, &"chs_ronin_m", "mặc định là RONIN-M")


func test_set_chassis_emits_signal() -> void:
    var mech := _make_mech()
    watch_signals(mech)
    var data := ChassisData.new()
    data.id = &"chs_test"
    mech.set_chassis(data)
    assert_signal_emitted(mech, "chassis_changed")
    assert_eq(mech.chassis_data.id, &"chs_test")


func test_set_chassis_ignores_null_and_keeps_current() -> void:
    var mech := _make_mech()
    var before: ChassisData = mech.chassis_data
    mech.set_chassis(null)
    assert_same(mech.chassis_data, before, "chassis rỗng không được xoá chỉ số đang dùng")


func test_movement_input_is_relative_to_camera_yaw() -> void:
    var forward: Vector3 = MechController.compute_desired_velocity(Vector2(0.0, -1.0), 0.0, 6.0)
    assert_almost_eq(forward.z, -6.0, 0.001, "W phải đi về −Z khi camera không xoay")
    var rotated: Vector3 = MechController.compute_desired_velocity(
        Vector2(0.0, -1.0), deg_to_rad(90.0), 6.0
    )
    assert_almost_eq(rotated.x, -6.0, 0.001, "camera xoay 90° thì W phải đi về −X")
    assert_almost_eq(rotated.z, 0.0, 0.001)


func test_diagonal_input_does_not_exceed_chassis_speed() -> void:
    var diagonal: Vector3 = MechController.compute_desired_velocity(Vector2(1.0, -1.0), 0.0, 6.0)
    assert_almost_eq(diagonal.length(), 6.0, 0.001, "đi chéo không được nhanh hơn đi thẳng")


func test_acceleration_and_deceleration_times_match_spec() -> void:
    var accel: float = MechController.compute_change_rate(6.0, Vector3(6.0, 0.0, 0.0))
    var decel: float = MechController.compute_change_rate(6.0, Vector3.ZERO)
    assert_almost_eq(accel, 6.0 / 0.18, 0.001, "đạt tốc độ tối đa trong 0.18s")
    assert_almost_eq(decel, 6.0 / 0.25, 0.001, "dừng hẳn trong 0.25s")


func test_apply_movement_builds_speed_over_time_and_stops() -> void:
    var mech := _make_mech()
    for _i: int in range(60):
        mech.apply_movement(Vector2(0.0, -1.0), 1.0 / 60.0)
    assert_almost_eq(mech.velocity.z, -6.0, 0.01, "giữ W một lúc phải đạt tốc độ tối đa")
    for _i: int in range(60):
        mech.apply_movement(Vector2.ZERO, 1.0 / 60.0)
    assert_almost_eq(Vector2(mech.velocity.x, mech.velocity.z).length(), 0.0, 0.01, "nhả phím phải dừng hẳn")
