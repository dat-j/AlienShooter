extends GutTest

const CRAWLER_PATH := "res://data/enemies/enm_crawler.tres"
const SKITTER_PATH := "res://data/enemies/enm_skitter.tres"
const HUSK_PATH := "res://data/enemies/enm_husk.tres"

func test_three_swarm_types_match_gdd_stats() -> void:
    var crawler: EnemyData = load(CRAWLER_PATH)
    var skitter: EnemyData = load(SKITTER_PATH)
    var husk: EnemyData = load(HUSK_PATH)
    assert_eq([crawler.max_hp, crawler.move_speed, crawler.contact_damage], [18.0, 7.5, 6.0])
    assert_eq([skitter.max_hp, skitter.move_speed, skitter.contact_damage], [10.0, 9.5, 4.0])
    assert_eq([husk.max_hp, husk.move_speed, husk.contact_damage], [30.0, 5.0, 9.0])
    assert_eq([crawler.swarm_type_id, skitter.swarm_type_id, husk.swarm_type_id], [0, 1, 2])

func test_silhouettes_and_speeds_are_distinct() -> void:
    var crawler: EnemyData = load(CRAWLER_PATH)
    var skitter: EnemyData = load(SKITTER_PATH)
    var husk: EnemyData = load(HUSK_PATH)
    assert_ne(crawler.swarm_mesh.get_class(), skitter.swarm_mesh.get_class())
    assert_ne(skitter.swarm_mesh.get_class(), husk.swarm_mesh.get_class())
    assert_true(skitter.move_speed > crawler.move_speed and crawler.move_speed > husk.move_speed)

func test_skitter_jumps_four_metres_at_six_metres() -> void:
    var skitter: EnemyData = load(SKITTER_PATH)
    var manager := SwarmManager.new()
    var movement := SwarmMovement.new()
    var field := FlowField.new()
    field.configure(AABB(Vector3(-8, -1, -8), Vector3(16, 2, 16)), 1.0)
    field.rebuild(Vector3.ZERO)
    movement.configure_type(skitter)
    var id := manager.spawn(Vector3(6, 0, 0), Vector3.ZERO, skitter.max_hp, skitter.swarm_type_id)
    movement.update(manager, field, 0.016, Vector3.ZERO)
    assert_almost_eq(manager._positions[manager._index_by_id[id]].x, 2.0, 0.01)
