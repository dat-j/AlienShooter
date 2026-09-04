class_name ContentDBImpl extends Node

## Nạp và index toàn bộ tài nguyên .tres/.res dưới res://data/ lúc khởi động.
## Tra cứu theo id qua get_weapon/get_enemy/.../get_room_module.
## Xem docs/02-TDD.md §4, §9 và docs/05-BACKLOG.md T-008.
##
## Phân loại tài nguyên dựa trên kiểu class_name thực tế của nó (`res is
## WeaponData`, v.v.) chứ không dựa vào thư mục chứa nó — nhờ vậy việc quét là
## đệ quy và không phụ thuộc vào cấu trúc thư mục con.
##
## Lớp mang tên `ContentDBImpl` (khác với tên autoload `ContentDB` khai báo
## trong project.godot) chỉ để có kiểu tĩnh khi test tự tạo một instance cách
## ly — bản thân singleton vẫn được truy cập toàn cục qua tên `ContentDB`.

const DATA_ROOT: String = "res://data"
const RESOURCE_EXTENSIONS: PackedStringArray = ["tres", "res"]

const CATEGORY_WEAPON: StringName = &"weapon"
const CATEGORY_ENEMY: StringName = &"enemy"
const CATEGORY_CHASSIS: StringName = &"chassis"
const CATEGORY_MODULE: StringName = &"module"
const CATEGORY_STATUS_EFFECT: StringName = &"status_effect"
const CATEGORY_MISSION: StringName = &"mission"
const CATEGORY_WAVE_TABLE: StringName = &"wave_table"
const CATEGORY_LOOT_TABLE: StringName = &"loot_table"
const CATEGORY_PERK: StringName = &"perk"
const CATEGORY_ROOM_MODULE: StringName = &"room_module"

var _weapons: Dictionary = {}
var _enemies: Dictionary = {}
var _chassis: Dictionary = {}
var _modules: Dictionary = {}
var _status_effects: Dictionary = {}
var _missions: Dictionary = {}
var _wave_tables: Dictionary = {}
var _loot_tables: Dictionary = {}
var _perks: Dictionary = {}
var _room_modules: Dictionary = {}
var _is_loaded: bool = false


func _ready() -> void:
    reload_all()


## Quét lại toàn bộ res://data/ từ đầu và xây lại mọi bảng index.
func reload_all() -> void:
    _weapons.clear()
    _enemies.clear()
    _chassis.clear()
    _modules.clear()
    _status_effects.clear()
    _missions.clear()
    _wave_tables.clear()
    _loot_tables.clear()
    _perks.clear()
    _room_modules.clear()
    _is_loaded = false

    var files: Array[String] = []
    _collect_resource_files(DATA_ROOT, files)
    for file_path: String in files:
        var res: Resource = ResourceLoader.load(file_path)
        if res == null:
            Log.error("Không nạp được tài nguyên tại %s" % file_path, "ContentDB")
            continue
        _index_resource(res, file_path)

    _is_loaded = true
    Log.info(
        "Nạp xong: %d vũ khí, %d kẻ địch, %d chassis, %d module, %d trạng thái, %d nhiệm vụ, %d wave table, %d loot table, %d perk, %d phòng" % [
            _weapons.size(), _enemies.size(), _chassis.size(), _modules.size(),
            _status_effects.size(), _missions.size(), _wave_tables.size(),
            _loot_tables.size(), _perks.size(), _room_modules.size(),
        ],
        "ContentDB"
    )


func is_loaded() -> bool:
    return _is_loaded


func get_weapon(id: StringName) -> WeaponData:
    if not _weapons.has(id):
        Log.error("Không tìm thấy weapon với id '%s'" % id, "ContentDB")
        return null
    var result: WeaponData = _weapons[id]
    return result


func get_enemy(id: StringName) -> EnemyData:
    if not _enemies.has(id):
        Log.error("Không tìm thấy enemy với id '%s'" % id, "ContentDB")
        return null
    var result: EnemyData = _enemies[id]
    return result


func get_chassis(id: StringName) -> ChassisData:
    if not _chassis.has(id):
        Log.error("Không tìm thấy chassis với id '%s'" % id, "ContentDB")
        return null
    var result: ChassisData = _chassis[id]
    return result


func get_module(id: StringName) -> ModuleData:
    if not _modules.has(id):
        Log.error("Không tìm thấy module với id '%s'" % id, "ContentDB")
        return null
    var result: ModuleData = _modules[id]
    return result


func get_status_effect(id: StringName) -> StatusEffectData:
    if not _status_effects.has(id):
        Log.error("Không tìm thấy status_effect với id '%s'" % id, "ContentDB")
        return null
    var result: StatusEffectData = _status_effects[id]
    return result


func get_mission(id: StringName) -> MissionData:
    if not _missions.has(id):
        Log.error("Không tìm thấy mission với id '%s'" % id, "ContentDB")
        return null
    var result: MissionData = _missions[id]
    return result


func get_wave_table(id: StringName) -> WaveTable:
    if not _wave_tables.has(id):
        Log.error("Không tìm thấy wave_table với id '%s'" % id, "ContentDB")
        return null
    var result: WaveTable = _wave_tables[id]
    return result


func get_loot_table(id: StringName) -> LootTable:
    if not _loot_tables.has(id):
        Log.error("Không tìm thấy loot_table với id '%s'" % id, "ContentDB")
        return null
    var result: LootTable = _loot_tables[id]
    return result


func get_perk(id: StringName) -> PerkData:
    if not _perks.has(id):
        Log.error("Không tìm thấy perk với id '%s'" % id, "ContentDB")
        return null
    var result: PerkData = _perks[id]
    return result


func get_room_module(id: StringName) -> RoomModuleData:
    if not _room_modules.has(id):
        Log.error("Không tìm thấy room_module với id '%s'" % id, "ContentDB")
        return null
    var result: RoomModuleData = _room_modules[id]
    return result


func get_all_enemies_for_chapter(chapter: int) -> Array[EnemyData]:
    var result: Array[EnemyData] = []
    for enemy: EnemyData in _enemies.values():
        if enemy.chapter == chapter:
            result.append(enemy)
    return result


func get_count(category: StringName) -> int:
    match category:
        CATEGORY_WEAPON:
            return _weapons.size()
        CATEGORY_ENEMY:
            return _enemies.size()
        CATEGORY_CHASSIS:
            return _chassis.size()
        CATEGORY_MODULE:
            return _modules.size()
        CATEGORY_STATUS_EFFECT:
            return _status_effects.size()
        CATEGORY_MISSION:
            return _missions.size()
        CATEGORY_WAVE_TABLE:
            return _wave_tables.size()
        CATEGORY_LOOT_TABLE:
            return _loot_tables.size()
        CATEGORY_PERK:
            return _perks.size()
        CATEGORY_ROOM_MODULE:
            return _room_modules.size()
    Log.error("Không rõ category '%s'" % category, "ContentDB")
    return 0


func _collect_resource_files(dir_path: String, out_files: Array[String]) -> void:
    var dir: DirAccess = DirAccess.open(dir_path)
    if dir == null:
        return
    dir.list_dir_begin()
    var entry: String = dir.get_next()
    while entry != "":
        if entry == "." or entry == "..":
            entry = dir.get_next()
            continue
        var full_path: String = dir_path + "/" + entry
        if dir.current_is_dir():
            _collect_resource_files(full_path, out_files)
        elif RESOURCE_EXTENSIONS.has(entry.get_extension().to_lower()):
            out_files.append(full_path)
        entry = dir.get_next()
    dir.list_dir_end()


func _index_resource(res: Resource, path: String) -> void:
    if res is WeaponData:
        _insert(_weapons, (res as WeaponData).id, res, path, CATEGORY_WEAPON)
    elif res is EnemyData:
        _insert(_enemies, (res as EnemyData).id, res, path, CATEGORY_ENEMY)
    elif res is ChassisData:
        _insert(_chassis, (res as ChassisData).id, res, path, CATEGORY_CHASSIS)
    elif res is ModuleData:
        _insert(_modules, (res as ModuleData).id, res, path, CATEGORY_MODULE)
    elif res is StatusEffectData:
        _insert(_status_effects, (res as StatusEffectData).id, res, path, CATEGORY_STATUS_EFFECT)
    elif res is MissionData:
        _insert(_missions, (res as MissionData).id, res, path, CATEGORY_MISSION)
    elif res is WaveTable:
        _insert(_wave_tables, (res as WaveTable).id, res, path, CATEGORY_WAVE_TABLE)
    elif res is LootTable:
        _insert(_loot_tables, (res as LootTable).id, res, path, CATEGORY_LOOT_TABLE)
    elif res is PerkData:
        _insert(_perks, (res as PerkData).id, res, path, CATEGORY_PERK)
    elif res is RoomModuleData:
        _insert(_room_modules, (res as RoomModuleData).id, res, path, CATEGORY_ROOM_MODULE)
    else:
        Log.warn("Tài nguyên không thuộc schema nào của ContentDB tại %s" % path, "ContentDB")


func _insert(table: Dictionary, id: StringName, res: Resource, path: String, category: StringName) -> void:
    if String(id).is_empty():
        Log.error("Tài nguyên tại %s thiếu id — bỏ qua" % path, "ContentDB")
        return
    if table.has(id):
        Log.error("Trùng id '%s' (loại %s) — bỏ qua %s" % [id, category, path], "ContentDB")
        return
    table[id] = res
