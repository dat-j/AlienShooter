extends SceneTree

## Sinh sơ đồ input mặc định vào project.godot theo docs/01-GDD.md §1.
## Chạy lại khi cần khôi phục mặc định:
##   godot --headless --path <dự án> --script res://tools/setup_input_map.gd
## Không phải code chạy trong game — chỉ là công cụ.

const DEADZONE: float = 0.2

## -1 = mọi thiết bị, giống cách editor ghi sự kiện bàn phím/chuột.
const ALL_DEVICES: int = -1

## Mỗi action: phím vật lý, nút chuột, nút gamepad, và trục gamepad.
## Trục ghi dạng [chỉ số trục, giá trị ±1.0].
const ACTIONS: Dictionary = {
    "move_forward": {"keys": [KEY_W], "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
    "move_back": {"keys": [KEY_S], "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
    "move_left": {"keys": [KEY_A], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
    "move_right": {"keys": [KEY_D], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
    "aim_up": {"axes": [[JOY_AXIS_RIGHT_Y, -1.0]]},
    "aim_down": {"axes": [[JOY_AXIS_RIGHT_Y, 1.0]]},
    "aim_left": {"axes": [[JOY_AXIS_RIGHT_X, -1.0]]},
    "aim_right": {"axes": [[JOY_AXIS_RIGHT_X, 1.0]]},
    "fire_left": {"mouse": [MOUSE_BUTTON_LEFT], "axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
    "fire_right": {"mouse": [MOUSE_BUTTON_RIGHT], "axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
    "boost": {"keys": [KEY_SPACE], "buttons": [JOY_BUTTON_A]},
    "vent_heat": {"keys": [KEY_R], "buttons": [JOY_BUTTON_X]},
    "module_1": {"keys": [KEY_Q], "buttons": [JOY_BUTTON_LEFT_SHOULDER]},
    "module_2": {"keys": [KEY_E], "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
    "interact": {"keys": [KEY_F], "buttons": [JOY_BUTTON_Y]},
    "map": {"keys": [KEY_TAB], "buttons": [JOY_BUTTON_BACK]},
    "pause": {"keys": [KEY_ESCAPE], "buttons": [JOY_BUTTON_START]},
}


func _init() -> void:
    for action_name: String in ACTIONS.keys():
        var spec: Dictionary = ACTIONS[action_name]
        var events: Array[InputEvent] = []
        for keycode: int in spec.get("keys", []) as Array:
            var key_event := InputEventKey.new()
            key_event.device = ALL_DEVICES
            key_event.physical_keycode = keycode
            events.append(key_event)
        for button_index: int in spec.get("mouse", []) as Array:
            var mouse_event := InputEventMouseButton.new()
            mouse_event.device = ALL_DEVICES
            mouse_event.button_index = button_index as MouseButton
            events.append(mouse_event)
        for button_index: int in spec.get("buttons", []) as Array:
            var pad_event := InputEventJoypadButton.new()
            pad_event.device = ALL_DEVICES
            pad_event.button_index = button_index as JoyButton
            events.append(pad_event)
        for axis_spec: Array in spec.get("axes", []) as Array:
            var motion_event := InputEventJoypadMotion.new()
            motion_event.device = ALL_DEVICES
            motion_event.axis = (axis_spec[0] as int) as JoyAxis
            motion_event.axis_value = axis_spec[1] as float
            events.append(motion_event)
        ProjectSettings.set_setting("input/%s" % action_name, {
            "deadzone": DEADZONE,
            "events": events,
        })
    var err: Error = ProjectSettings.save()
    if err != OK:
        printerr("Không ghi được project.godot, lỗi %d" % err)
    else:
        print("Đã ghi %d action vào sơ đồ input." % ACTIONS.size())
    quit()
