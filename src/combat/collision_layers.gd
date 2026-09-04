class_name CollisionLayers
extends RefCounted

## Nguồn duy nhất khai báo bit va chạm của gameplay.
enum Layer {
    WORLD = 1 << 0,
    PLAYER_BODY = 1 << 1,
    ENEMY_BODY = 1 << 2,
    PLAYER_HURTBOX = 1 << 3,
    ENEMY_HURTBOX = 1 << 4,
    PLAYER_HITBOX = 1 << 5,
    ENEMY_HITBOX = 1 << 6,
}
