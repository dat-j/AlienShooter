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
