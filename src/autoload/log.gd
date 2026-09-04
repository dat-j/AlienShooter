extends Node

## Ghi log có cấp độ cho toàn bộ game; trong build debug còn ghi ra
## `user://logs/`. Xem docs/02-TDD.md §4 (autoload) và §15 (debug).
## Log không được phép biết về bất kỳ autoload nào khác.

enum Level { DEBUG, INFO, WARN, ERROR, NONE }

const LOG_DIR: String = "user://logs/"
const MAX_HISTORY: int = 200

var _current_level: Level = Level.DEBUG
var _is_debug_build: bool = false
var _log_file: FileAccess = null
var _history: Array[String] = []


func _ready() -> void:
    _is_debug_build = OS.is_debug_build()


func _exit_tree() -> void:
    if _log_file != null:
        _log_file.close()
        _log_file = null


func set_level(level: Level) -> void:
    _current_level = level


func get_level() -> Level:
    return _current_level


func debug(message: String, context: String = "") -> void:
    _log(Level.DEBUG, message, context)


func info(message: String, context: String = "") -> void:
    _log(Level.INFO, message, context)


func warn(message: String, context: String = "") -> void:
    _log(Level.WARN, message, context)


func error(message: String, context: String = "") -> void:
    _log(Level.ERROR, message, context)


## Trả về các dòng log gần nhất (tối đa MAX_HISTORY). Chỉ dùng cho test/gỡ lỗi.
func get_history() -> Array[String]:
    return _history.duplicate()


## Xoá sạch lịch sử log đã ghi nhớ. Chỉ dùng cho test.
func clear_history() -> void:
    _history.clear()


func _log(level: Level, message: String, context: String) -> void:
    if level < _current_level:
        return
    var line: String = _format_line(level, message, context)
    print(line)
    _history.append(line)
    if _history.size() > MAX_HISTORY:
        _history.pop_front()
    if _is_debug_build:
        _write_to_file(line)


func _format_line(level: Level, message: String, context: String) -> String:
    var level_name: String = _level_name(level)
    var timestamp: String = Time.get_datetime_string_from_system(false, true)
    if context.is_empty():
        return "[%s][%s] %s" % [timestamp, level_name, message]
    return "[%s][%s][%s] %s" % [timestamp, level_name, context, message]


func _level_name(level: Level) -> String:
    match level:
        Level.DEBUG:
            return "DEBUG"
        Level.INFO:
            return "INFO"
        Level.WARN:
            return "WARN"
        Level.ERROR:
            return "ERROR"
        _:
            return "NONE"


func _write_to_file(line: String) -> void:
    if _log_file == null:
        _open_log_file()
    if _log_file != null:
        _log_file.store_line(line)


func _open_log_file() -> void:
    var dir_err: Error = DirAccess.make_dir_recursive_absolute(LOG_DIR)
    if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
        return
    var stamp: String = Time.get_datetime_string_from_system(true, true).replace(":", "-")
    var file_name: String = "log_%s.txt" % stamp
    _log_file = FileAccess.open(LOG_DIR + file_name, FileAccess.WRITE)
