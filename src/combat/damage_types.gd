class_name DamageTypes
extends RefCounted

## Bảng liệt kê loại sát thương và tiện ích tra cứu thuần tuý.
## Xem docs/01-GDD.md §4 và docs/02-TDD.md §8.1.
## Không bao giờ khởi tạo class này — chỉ dùng như không gian tên.

enum Type {
    KINETIC,
    ENERGY,
    EXPLOSIVE,
    FIRE,
    ACID,
    TRUE,
}

const TYPE_COUNT: int = 6


static func to_key(type: Type) -> StringName:
    match type:
        Type.KINETIC: return &"kinetic"
        Type.ENERGY: return &"energy"
        Type.EXPLOSIVE: return &"explosive"
        Type.FIRE: return &"fire"
        Type.ACID: return &"acid"
        Type.TRUE: return &"true"
    return &"kinetic"


static func from_key(key: StringName) -> Type:
    match key:
        &"kinetic": return Type.KINETIC
        &"energy": return Type.ENERGY
        &"explosive": return Type.EXPLOSIVE
        &"fire": return Type.FIRE
        &"acid": return Type.ACID
        &"true": return Type.TRUE
    return Type.KINETIC
