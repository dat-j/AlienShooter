extends GutTest

## Kiểm tra EventBus: đủ và đúng mọi signal ở docs/02-TDD.md §4.2, không thêm
## không bớt, và không chứa hàm/biến trạng thái nào ngoài signal.
## Xem docs/05-BACKLOG.md T-006.


func _expected_signatures() -> Array:
    return [
        {"name": "damage_dealt", "args": [
            {"name": "target_id", "type": TYPE_INT},
            {"name": "info", "type": TYPE_OBJECT, "class_name": "DamageInfo"},
        ]},
        {"name": "enemy_killed", "args": [
            {"name": "enemy_id", "type": TYPE_STRING_NAME},
            {"name": "position", "type": TYPE_VECTOR3},
            {"name": "was_actor", "type": TYPE_BOOL},
        ]},
        {"name": "player_damaged", "args": [
            {"name": "amount", "type": TYPE_FLOAT},
            {"name": "zone", "type": TYPE_INT},
            {"name": "source_position", "type": TYPE_VECTOR3},
        ]},
        {"name": "player_died", "args": []},
        {"name": "heat_changed", "args": [
            {"name": "current", "type": TYPE_FLOAT},
            {"name": "maximum", "type": TYPE_FLOAT},
        ]},
        {"name": "overheat_started", "args": []},
        {"name": "overheat_ended", "args": []},
        {"name": "armor_plate_broken", "args": [
            {"name": "zone", "type": TYPE_INT},
        ]},
        {"name": "boost_used", "args": [
            {"name": "charges_left", "type": TYPE_INT},
        ]},
        {"name": "mission_started", "args": [
            {"name": "mission_id", "type": TYPE_STRING_NAME},
        ]},
        {"name": "objective_updated", "args": [
            {"name": "objective_id", "type": TYPE_STRING_NAME},
            {"name": "progress", "type": TYPE_FLOAT},
        ]},
        {"name": "mission_completed", "args": [
            {"name": "results", "type": TYPE_DICTIONARY},
        ]},
        {"name": "mission_failed", "args": [
            {"name": "reason", "type": TYPE_STRING_NAME},
        ]},
        {"name": "pressure_wave_started", "args": [
            {"name": "intensity", "type": TYPE_FLOAT},
        ]},
        {"name": "resource_gained", "args": [
            {"name": "type", "type": TYPE_STRING_NAME},
            {"name": "amount", "type": TYPE_INT},
        ]},
        {"name": "loot_picked_up", "args": [
            {"name": "item_id", "type": TYPE_STRING_NAME},
        ]},
        {"name": "settings_changed", "args": [
            {"name": "section", "type": TYPE_STRING_NAME},
        ]},
        {"name": "game_paused", "args": [
            {"name": "is_paused", "type": TYPE_BOOL},
        ]},
    ]


func _expected_signal_names() -> Array:
    var names: Array = []
    for sig: Dictionary in _expected_signatures():
        names.append(sig["name"])
    return names


func test_co_dung_18_signal_theo_danh_muc_tdd() -> void:
    assert_eq(_expected_signal_names().size(), 18, "danh mục kỳ vọng trong test phải khớp đúng 18 signal ở TDD §4.2")


func test_moi_signal_bat_buoc_ton_tai_dung_chu_ky() -> void:
    var signal_list: Array = EventBus.get_signal_list()
    var by_name: Dictionary = {}
    for s: Dictionary in signal_list:
        by_name[s["name"]] = s

    for expected: Dictionary in _expected_signatures():
        var sig_name: String = expected["name"]
        assert_true(by_name.has(sig_name), "EventBus phải có signal '%s'" % sig_name)
        if not by_name.has(sig_name):
            continue
        var actual: Dictionary = by_name[sig_name]
        var actual_args: Array = actual["args"]
        var expected_args: Array = expected["args"]
        assert_eq(actual_args.size(), expected_args.size(), "signal '%s' phải có đúng %d tham số" % [sig_name, expected_args.size()])
        var arg_count: int = mini(actual_args.size(), expected_args.size())
        for i: int in range(arg_count):
            var actual_arg: Dictionary = actual_args[i]
            var expected_arg: Dictionary = expected_args[i]
            assert_eq(String(actual_arg["name"]), String(expected_arg["name"]), "tham số thứ %d của '%s' phải tên '%s'" % [i, sig_name, expected_arg["name"]])
            assert_eq(int(actual_arg["type"]), int(expected_arg["type"]), "tham số '%s' của '%s' phải đúng kiểu dữ liệu" % [expected_arg["name"], sig_name])
            if expected_arg.has("class_name"):
                assert_eq(String(actual_arg["class_name"]), String(expected_arg["class_name"]), "tham số '%s' của '%s' phải đúng class '%s'" % [expected_arg["name"], sig_name, expected_arg["class_name"]])


func test_khong_co_signal_thua_ngoai_danh_muc() -> void:
    var baseline_node: Node = Node.new()
    var baseline_names: Array = []
    for s: Dictionary in baseline_node.get_signal_list():
        baseline_names.append(s["name"])
    baseline_node.free()

    var custom_names: Array = []
    for s: Dictionary in EventBus.get_signal_list():
        var sig_name: String = s["name"]
        if not baseline_names.has(sig_name):
            custom_names.append(sig_name)

    custom_names.sort()
    var expected_sorted: Array = _expected_signal_names()
    expected_sorted.sort()
    assert_eq(custom_names, expected_sorted, "EventBus phải khai báo đúng và đủ danh mục signal ở TDD §4.2 — không thêm, không bớt")
