extends Node

## Autoload #3 (TDD §4). Đọc/ghi thiết lập của người chơi vào
## `user://settings.cfg`. Xem docs/05-BACKLOG.md T-107.
##
## Nguyên tắc: **file thiết lập không bao giờ được làm hỏng game.** Thiếu
## file, hỏng file, thiếu khoá, sai kiểu — mọi trường hợp đều lặng lẽ rơi về
## giá trị mặc định và ghi log, chứ không bao giờ ném lỗi hay trả về null.
## Người chơi có thể sửa tay file này; nó phải chịu được điều đó.
##
## Chỉ biết về `Log` (TDD §4). Không giữ tham chiếu tới node trong màn chơi.

const FILE_PATH: String = "user://settings.cfg"

const SECTION_GRAPHICS: StringName = &"graphics"
const SECTION_AUDIO: StringName = &"audio"
const SECTION_ACCESSIBILITY: StringName = &"accessibility"
const SECTION_INPUT: StringName = &"input"

## Nguồn duy nhất của mọi khoá thiết lập và kiểu của chúng. Khoá không có ở
## đây thì không tồn tại — `set_value()` từ chối ghi, `get_value()` trả về
## giá trị dự phòng của người gọi.
const DEFAULTS: Dictionary = {
    SECTION_GRAPHICS: {
        &"preset": "high",              # low | medium | high
        &"decal_limit": 150,            # TDD §12.7
        &"leg_ik": true,                # T-108 tắt được qua đây
        &"vsync": true,
    },
    SECTION_AUDIO: {
        &"master": 1.0,
        &"music": 0.7,
        &"sfx": 1.0,
    },
    SECTION_ACCESSIBILITY: {
        &"screen_shake": 1.0,           # thanh trượt 0..1, JuiceDirector nhân vào
        &"hitstop": 1.0,
        &"rumble": 1.0,
        &"chromatic_aberration": 1.0,
        &"damage_numbers": true,        # T-607
    },
}

## Preset đồ hoạ ghi đè một phần mục `graphics` (TDD §12.7 — trần decal điều
## chỉnh được theo preset).
const GRAPHICS_PRESETS: Dictionary = {
    "low": {&"decal_limit": 40, &"leg_ik": false},
    "medium": {&"decal_limit": 90, &"leg_ik": true},
    "high": {&"decal_limit": 150, &"leg_ik": true},
}

var _values: Dictionary = {}
var _bindings: Dictionary = {}


func _ready() -> void:
    load_settings()


## Nạp lại từ đĩa. File thiếu hoặc hỏng → toàn bộ giá trị mặc định.
func load_settings() -> bool:
    reset_all(false)
    var config := ConfigFile.new()
    var error: Error = config.load(FILE_PATH)
    if error != OK:
        if error != ERR_FILE_NOT_FOUND:
            Log.warn("settings.cfg hỏng (mã %d) — dùng mặc định" % error, "SettingsManager")
        return false
    for section: StringName in DEFAULTS:
        _read_section(config, section)
    _read_bindings(config)
    return true


func save() -> bool:
    var config := ConfigFile.new()
    for section: StringName in _values:
        var entries: Dictionary = _values[section]
        for key: StringName in entries:
            config.set_value(String(section), String(key), entries[key])
    for action: StringName in _bindings:
        config.set_value(String(SECTION_INPUT), String(action), _bindings[action])
    var error: Error = config.save(FILE_PATH)
    if error != OK:
        Log.error("không ghi được settings.cfg (mã %d)" % error, "SettingsManager")
        return false
    return true


## Giá trị hiện tại. `fallback` chỉ dùng khi khoá không có trong `DEFAULTS`
## — khoá hợp lệ luôn có giá trị, kể cả khi file hỏng.
func get_value(section: StringName, key: StringName, fallback: Variant = null) -> Variant:
    var entries: Dictionary = _values.get(section, {}) as Dictionary
    if entries.has(key):
        return entries[key]
    return fallback


## Ghi một khoá. Từ chối khoá lạ và giá trị sai kiểu — đây là hàng rào giữ
## cho phần còn lại của game không phải kiểm tra kiểu ở mỗi lần đọc.
## Phát `EventBus.settings_changed` khi giá trị thực sự đổi.
func set_value(section: StringName, key: StringName, value: Variant) -> bool:
    var defaults: Dictionary = DEFAULTS.get(section, {}) as Dictionary
    if not defaults.has(key):
        Log.warn("khoá thiết lập lạ: %s/%s" % [section, key], "SettingsManager")
        return false
    if typeof(value) != typeof(defaults[key]):
        Log.warn("sai kiểu cho %s/%s" % [section, key], "SettingsManager")
        return false
    var entries: Dictionary = _values[section] as Dictionary
    if entries[key] == value:
        return true
    entries[key] = value
    if section == SECTION_GRAPHICS and key == &"preset":
        _apply_graphics_preset(String(value))
    EventBus.settings_changed.emit(section)
    return true


## Thanh trượt trợ năng, kẹp về 0..1. JuiceDirector gọi hàm này mỗi lần rung.
func get_accessibility_scale(key: StringName) -> float:
    var value: Variant = get_value(SECTION_ACCESSIBILITY, key, 1.0)
    if typeof(value) == TYPE_BOOL:
        return 1.0 if value else 0.0
    return clampf(float(value), 0.0, 1.0)


func reset_section(section: StringName, notify: bool = true) -> void:
    var defaults: Dictionary = DEFAULTS.get(section, {}) as Dictionary
    _values[section] = defaults.duplicate(true)
    if notify:
        EventBus.settings_changed.emit(section)


func reset_all(notify: bool = true) -> void:
    _values.clear()
    for section: StringName in DEFAULTS:
        reset_section(section, false)
    _bindings.clear()
    if notify:
        for section: StringName in DEFAULTS:
            EventBus.settings_changed.emit(section)


# --- Gán phím -----------------------------------------------------------

## Gán lại một action. `events` là các `InputEvent` thật; chúng được chuyển
## thành chuỗi để ghi vào file cấu hình.
func set_binding(action: StringName, events: Array[InputEvent]) -> bool:
    if not InputMap.has_action(action):
        Log.warn("gán phím cho action không tồn tại: %s" % action, "SettingsManager")
        return false
    var encoded: Array[String] = []
    for event: InputEvent in events:
        var text: String = serialize_event(event)
        if not text.is_empty():
            encoded.append(text)
    _bindings[action] = encoded
    _apply_binding(action, encoded)
    EventBus.settings_changed.emit(SECTION_INPUT)
    return true


func get_binding(action: StringName) -> Array:
    return _bindings.get(action, []) as Array


## Đẩy toàn bộ gán phím đã lưu vào `InputMap`. Gọi sau `load_settings()`.
func apply_all_bindings() -> void:
    for action: StringName in _bindings:
        _apply_binding(action, _bindings[action] as Array)


## Hàm thuần tuý: `InputEvent` → chuỗi. Trả về chuỗi rỗng cho loại chưa hỗ
## trợ, để người gọi bỏ qua thay vì ghi rác vào file.
static func serialize_event(event: InputEvent) -> String:
    var key := event as InputEventKey
    if key != null:
        return "key:%d" % key.physical_keycode
    var mouse := event as InputEventMouseButton
    if mouse != null:
        return "mouse:%d" % mouse.button_index
    var button := event as InputEventJoypadButton
    if button != null:
        return "joy:%d" % button.button_index
    var motion := event as InputEventJoypadMotion
    if motion != null:
        return "joyaxis:%d:%d" % [motion.axis, int(signf(motion.axis_value))]
    return ""


## Hàm thuần tuý: chuỗi → `InputEvent`. Chuỗi rác trả về null.
static func parse_event(text: String) -> InputEvent:
    var parts: PackedStringArray = text.split(":")
    if parts.size() < 2 or not parts[1].is_valid_int():
        return null
    match parts[0]:
        "key":
            var key := InputEventKey.new()
            key.physical_keycode = int(parts[1])
            return key
        "mouse":
            var mouse := InputEventMouseButton.new()
            mouse.button_index = int(parts[1])
            return mouse
        "joy":
            var button := InputEventJoypadButton.new()
            button.button_index = int(parts[1])
            return button
        "joyaxis":
            if parts.size() < 3 or not parts[2].is_valid_int():
                return null
            var motion := InputEventJoypadMotion.new()
            motion.axis = int(parts[1])
            motion.axis_value = float(int(parts[2]))
            return motion
    return null


# --- Nội bộ -------------------------------------------------------------

## Đọc từng khoá một chứ không nuốt cả mục: một khoá hỏng chỉ làm hỏng đúng
## khoá đó, phần còn lại của mục vẫn dùng được.
func _read_section(config: ConfigFile, section: StringName) -> void:
    var defaults: Dictionary = DEFAULTS[section] as Dictionary
    var entries: Dictionary = _values[section] as Dictionary
    for key: StringName in defaults:
        if not config.has_section_key(String(section), String(key)):
            continue
        var value: Variant = config.get_value(String(section), String(key))
        if typeof(value) != typeof(defaults[key]):
            Log.warn("bỏ qua %s/%s vì sai kiểu trong file" % [section, key], "SettingsManager")
            continue
        entries[key] = value


func _read_bindings(config: ConfigFile) -> void:
    if not config.has_section(String(SECTION_INPUT)):
        return
    for action_name: String in config.get_section_keys(String(SECTION_INPUT)):
        var value: Variant = config.get_value(String(SECTION_INPUT), action_name)
        if typeof(value) != TYPE_ARRAY:
            continue
        var encoded: Array[String] = []
        for entry: Variant in value as Array:
            if typeof(entry) == TYPE_STRING:
                encoded.append(entry as String)
        _bindings[StringName(action_name)] = encoded


func _apply_binding(action: StringName, encoded: Array) -> void:
    if not InputMap.has_action(action):
        return
    InputMap.action_erase_events(action)
    for text: Variant in encoded:
        var event: InputEvent = parse_event(String(text))
        if event != null:
            InputMap.action_add_event(action, event)


func _apply_graphics_preset(preset: String) -> void:
    var overrides: Dictionary = GRAPHICS_PRESETS.get(preset, {}) as Dictionary
    var entries: Dictionary = _values[SECTION_GRAPHICS] as Dictionary
    for key: StringName in overrides:
        entries[key] = overrides[key]
