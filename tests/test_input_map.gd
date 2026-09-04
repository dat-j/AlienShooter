extends GutTest

## T-106 — sơ đồ input: đủ mọi hành động ở docs/01-GDD.md §1, bàn phím và
## gamepad cùng ánh xạ vào một action.

const REQUIRED_ACTIONS: Array[StringName] = [
    &"move_forward", &"move_back", &"move_left", &"move_right",
    &"aim_up", &"aim_down", &"aim_left", &"aim_right",
    &"fire_left", &"fire_right",
    &"boost", &"vent_heat", &"module_1", &"module_2",
    &"interact", &"map", &"pause",
]


func test_every_gdd_action_exists() -> void:
    for action: StringName in REQUIRED_ACTIONS:
        assert_true(InputMap.has_action(action), "thiếu action %s theo GDD §1" % action)


func test_keyboard_and_gamepad_share_the_same_action() -> void:
    for action: StringName in REQUIRED_ACTIONS:
        var has_human_device: bool = false
        var has_pad: bool = false
        for event: InputEvent in InputMap.action_get_events(action):
            if event is InputEventKey or event is InputEventMouseButton:
                has_human_device = true
            if event is InputEventJoypadButton or event is InputEventJoypadMotion:
                has_pad = true
        assert_true(has_pad, "%s phải có ánh xạ gamepad" % action)
        if action.begins_with("aim_"):
            continue    # ngắm bằng chuột đi qua vị trí con trỏ, không qua action
        assert_true(has_human_device, "%s phải có ánh xạ bàn phím hoặc chuột" % action)


func test_movement_uses_wasd_physical_keys() -> void:
    var expected: Dictionary = {
        &"move_forward": KEY_W, &"move_back": KEY_S,
        &"move_left": KEY_A, &"move_right": KEY_D,
    }
    for action: StringName in expected.keys():
        var event := InputEventKey.new()
        event.physical_keycode = expected[action] as Key
        event.pressed = true
        assert_true(InputMap.event_is_action(event, action), "%s phải nhận phím vật lý đúng" % action)


func test_stick_deadzone_matches_gdd() -> void:
    for action: StringName in REQUIRED_ACTIONS:
        assert_almost_eq(InputMap.action_get_deadzone(action), 0.2, 0.001,
            "%s phải dùng bán kính chết 0.2" % action)
