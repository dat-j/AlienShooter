extends GutTest

class DamageReceiver:
    extends Node3D
    var damage_taken: float = 0.0
    func take_damage(amount: float) -> void:
        damage_taken += amount


func _make_hurtbox(receiver: DamageReceiver) -> Hurtbox:
    var hurtbox := Hurtbox.new()
    receiver.add_child(hurtbox)
    hurtbox.monitoring = true
    return hurtbox


func _make_hitbox(owner_node: Node3D) -> Hitbox:
    var hitbox := Hitbox.new()
    owner_node.add_child(hitbox)
    hitbox.damage = 12.0
    return hitbox


func test_hitbox_is_disabled_until_window_opens() -> void:
    var owner_node := add_child_autofree(Node3D.new()) as Node3D
    var hitbox := _make_hitbox(owner_node)
    assert_false(hitbox.monitoring)
    assert_false(hitbox.is_window_active())
    hitbox.open_window()
    assert_true(hitbox.monitoring)
    hitbox.close_window()
    assert_false(hitbox.monitoring)


func test_target_is_hit_only_once_per_attack_window() -> void:
    var attacker := add_child_autofree(Node3D.new()) as Node3D
    var receiver := add_child_autofree(DamageReceiver.new()) as DamageReceiver
    var hitbox := _make_hitbox(attacker)
    var hurtbox := _make_hurtbox(receiver)
    hitbox.open_window()
    assert_true(hitbox.try_hit(hurtbox))
    assert_false(hitbox.try_hit(hurtbox))
    assert_eq(receiver.damage_taken, 12.0)


func test_new_window_can_hit_same_target_again() -> void:
    var attacker := add_child_autofree(Node3D.new()) as Node3D
    var receiver := add_child_autofree(DamageReceiver.new()) as DamageReceiver
    var hitbox := _make_hitbox(attacker)
    var hurtbox := _make_hurtbox(receiver)
    hitbox.open_window()
    hitbox.try_hit(hurtbox)
    hitbox.close_window()
    hitbox.open_window()
    assert_true(hitbox.try_hit(hurtbox))
    assert_eq(receiver.damage_taken, 24.0)


func test_self_hit_is_rejected() -> void:
    var actor := add_child_autofree(DamageReceiver.new()) as DamageReceiver
    var hitbox := _make_hitbox(actor)
    var hurtbox := _make_hurtbox(actor)
    hitbox.open_window()
    assert_false(hitbox.try_hit(hurtbox))
    assert_eq(actor.damage_taken, 0.0)


func test_actor_scene_uses_central_collision_layers() -> void:
    var scene := load("res://scenes/enemies/actors/actor_base.tscn") as PackedScene
    var actor := add_child_autofree(scene.instantiate()) as ActorEnemy
    assert_eq(actor.collision_layer, CollisionLayers.Layer.ENEMY_BODY)
    assert_eq(actor.hurtbox.collision_layer, CollisionLayers.Layer.ENEMY_HURTBOX)
    assert_eq(actor.hitbox.collision_mask, CollisionLayers.Layer.PLAYER_HURTBOX)
    assert_false(actor.hitbox.monitoring)
