extends GutTest

const ACTOR_SCENE: PackedScene = preload("res://scenes/enemies/actors/actor_base.tscn")
const ActorEnemyScript: GDScript = preload("res://src/ai/actor_enemy.gd")

func _actor_data() -> EnemyData:
    var data := EnemyData.new()
    data.id = &"test_actor"
    data.execution_path = 1
    data.max_hp = 80.0
    data.move_speed = 4.5
    return data

func _contains_navigation_agent(node: Node) -> bool:
    if node is NavigationAgent3D:
        return true
    for child: Node in node.get_children():
        if _contains_navigation_agent(child):
            return true
    return false

func test_actor_scene_has_required_tree_and_no_nav_agent() -> void:
    var actor: CharacterBody3D = add_child_autofree(ACTOR_SCENE.instantiate())
    assert_not_null(actor.get_node_or_null("Model/AnimationTree"))
    assert_not_null(actor.get_node_or_null("StateMachine"))
    assert_not_null(actor.get_node_or_null("HealthComponent"))
    assert_not_null(actor.get_node_or_null("StatusComponent"))
    assert_not_null(actor.get_node_or_null("Hurtbox"))
    assert_not_null(actor.get_node_or_null("Hitbox"))
    assert_false(_contains_navigation_agent(actor))

func test_configure_loads_actor_stats_and_rejects_swarm() -> void:
    var actor: CharacterBody3D = add_child_autofree(ACTOR_SCENE.instantiate())
    var data := _actor_data()
    assert_true(actor.configure(data))
    assert_eq(actor.current_health, 80.0)
    data.execution_path = 0
    assert_false(actor.configure(data))

func test_pool_callbacks_reset_actor_without_rebuilding_scene() -> void:
    var actor: CharacterBody3D = add_child_autofree(ACTOR_SCENE.instantiate())
    actor.configure(_actor_data())
    actor._on_acquired()
    actor.take_damage(25.0)
    assert_eq(actor.current_health, 55.0)
    actor._on_released()
    assert_false(actor.is_active())
    assert_false(actor.hitbox.monitoring)
    actor._on_acquired()
    assert_true(actor.is_active())
    assert_eq(actor.current_health, 80.0)

func test_pool_manager_reuses_actor_instance() -> void:
    PoolManager.prewarm(ACTOR_SCENE, 1)
    var first: Node = PoolManager.acquire(ACTOR_SCENE)
    PoolManager.release(first)
    var second: Node = PoolManager.acquire(ACTOR_SCENE)
    assert_same(second, first)
    PoolManager.release(second)
    PoolManager.clear_pool(ACTOR_SCENE)
