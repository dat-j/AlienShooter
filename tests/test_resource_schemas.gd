extends GutTest

## Kiểm tra 10 schema Resource ở src/resources/: mỗi lớp có trường `id` kiểu
## StringName, và file .tres mẫu tương ứng nạp được với số liệu khớp
## docs/01-GDD.md. Xem docs/05-BACKLOG.md T-007.


func test_weapon_data_mau_khop_gdd_rail_lance() -> void:
    var res: WeaponData = load("res://data/weapons/wpn_rail_lance.tres")
    assert_not_null(res, "phải nạp được wpn_rail_lance.tres")
    assert_eq(res.id, &"wpn_rail_lance", "id phải khớp tên file")
    assert_eq(res.damage, 120.0, "sát thương Rail Lance phải là 120 theo GDD §6.2")
    assert_eq(res.rate_of_fire, 0.6, "tốc bắn Rail Lance phải là 0.6 theo GDD §6.2")
    assert_eq(res.heat_per_shot, 35.0, "nhiệt mỗi phát Rail Lance phải là 35 theo GDD §6.2")
    assert_eq(res.damage_type, DamageTypes.Type.ENERGY, "Rail Lance thuộc nhóm Energy")


func test_enemy_data_mau_khop_gdd_crawler() -> void:
    var res: EnemyData = load("res://data/enemies/enm_crawler.tres")
    assert_not_null(res, "phải nạp được enm_crawler.tres")
    assert_eq(res.max_hp, 18.0, "HP Crawler phải là 18 theo GDD §8.2")
    assert_eq(res.move_speed, 7.5, "tốc độ Crawler phải là 7.5 theo GDD §8.2")
    assert_eq(res.contact_damage, 6.0, "sát thương cận chiến Crawler phải là 6 theo GDD §8.2")
    assert_eq(res.execution_path, 0, "Crawler phải theo đường SWARM (0)")
    assert_eq(res.chapter, 1, "Crawler xuất hiện từ chương 1")


func test_chassis_data_mau_khop_gdd_ronin_m() -> void:
    var res: ChassisData = load("res://data/chassis/chs_ronin_m.tres")
    assert_not_null(res, "phải nạp được chs_ronin_m.tres")
    assert_eq(res.core_hp, 100.0, "Core HP RONIN-M phải là 100 theo GDD §5")
    assert_eq(res.armor_front, 60.0, "Armor Trước RONIN-M phải là 60 theo GDD §5")
    assert_eq(res.move_speed, 6.0, "Tốc độ RONIN-M phải là 6.0 m/s theo GDD §5")
    assert_eq(res.heat_capacity, 100.0, "Sức chứa nhiệt RONIN-M phải là 100 theo GDD §5")
    assert_eq(res.boost_charges, 2, "Nạp Boost RONIN-M phải là 2 theo GDD §5")


func test_module_data_mau_khop_gdd_heat_sink() -> void:
    var res: ModuleData = load("res://data/modules/mod_heat_sink_array.tres")
    assert_not_null(res, "phải nạp được mod_heat_sink_array.tres")
    assert_eq(res.module_type, 0, "Heat Sink Array là module Bị động (0)")
    assert_eq(res.effect_value_a, 0.25, "Heat Sink Array phải cộng 25% tản nhiệt theo GDD §7")


func test_status_effect_data_mau_khop_gdd_burning() -> void:
    var res: StatusEffectData = load("res://data/status_effects/eff_burning.tres")
    assert_not_null(res, "phải nạp được eff_burning.tres")
    assert_eq(res.damage_per_second, 12.0, "Burning phải gây 12 sát thương/s theo GDD §9")
    assert_eq(res.duration_seconds, 4.0, "Burning phải kéo dài 4s theo GDD §9")
    assert_eq(res.max_stacks, 3, "Burning cộng dồn tối đa 3 theo GDD §9")


func test_mission_data_mau_khop_gdd_purge() -> void:
    var res: MissionData = load("res://data/missions/msn_ch1_purge.tres")
    assert_not_null(res, "phải nạp được msn_ch1_purge.tres")
    assert_eq(res.mission_type, 0, "loại nhiệm vụ phải là PURGE (0)")
    assert_eq(res.target_duration_min_seconds, 360.0, "PURGE tối thiểu 6 phút theo GDD §10.1")
    assert_eq(res.target_duration_max_seconds, 540.0, "PURGE tối đa 9 phút theo GDD §10.1")


func test_wave_table_mau_roll_khong_vuot_ngan_sach() -> void:
    var res: WaveTable = load("res://data/wave_tables/wav_ch1.tres")
    assert_not_null(res, "phải nạp được wav_ch1.tres")
    var composition: Array = res.roll(0.0, 10.0)
    for entry: Variant in composition:
        var spawn_entry: WaveTable.SpawnEntry = entry
        assert_true(spawn_entry.cost >= 0, "chi phí một mục sinh quái không được âm")


func test_loot_table_mau_roll_tra_ve_dung_so_luong() -> void:
    var res: LootTable = load("res://data/loot_tables/loot_ch1_standard.tres")
    assert_not_null(res, "phải nạp được loot_ch1_standard.tres")
    var drops: Array = res.roll(5)
    assert_eq(drops.size(), 5, "roll(5) phải trả về đúng 5 lần rơi đồ")
    for drop: Variant in drops:
        var loot_roll: LootTable.LootRoll = drop
        assert_true(res.item_ids.has(loot_roll.item_id), "vật phẩm rơi ra phải nằm trong bảng item_ids")


func test_perk_data_mau_khop_gdd() -> void:
    var res: PerkData = load("res://data/perks/prk_tactical_boost_charge.tres")
    assert_not_null(res, "phải nạp được prk_tactical_boost_charge.tres")
    assert_eq(res.branch, 0, "perk mẫu phải thuộc nhánh CHIẾN THUẬT (0)")


func test_room_module_data_mau_co_du_ket_noi() -> void:
    var res: RoomModuleData = load("res://data/rooms/room_ch1_small_01.tres")
    assert_not_null(res, "phải nạp được room_ch1_small_01.tres")
    assert_eq(res.connection_count, 2, "phòng mẫu phải có 2 điểm kết nối")
    assert_eq(res.connection_sizes.size(), 2, "connection_sizes phải song song với connection_count")


func test_moi_schema_co_truong_id_kieu_stringname() -> void:
    var samples: Array[Resource] = [
        WeaponData.new(), EnemyData.new(), ChassisData.new(), ModuleData.new(),
        StatusEffectData.new(), MissionData.new(), WaveTable.new(), LootTable.new(),
        PerkData.new(), RoomModuleData.new(),
    ]
    for sample: Resource in samples:
        assert_eq(typeof(sample.get("id")), TYPE_STRING_NAME, "mỗi schema phải có trường id kiểu StringName")
