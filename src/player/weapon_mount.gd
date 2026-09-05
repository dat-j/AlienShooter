class_name WeaponMount
extends Node3D

## Một hardpoint vũ khí (trái hoặc phải). Bắn độc lập với mount kia; tốc bắn,
## sạc, quay nòng, nhiệt và đạn đều đọc từ `WeaponData`.
## Xem docs/01-GDD.md §6 và docs/05-BACKLOG.md T-503.

signal fired(weapon: WeaponData, origin: Vector3)
signal ammo_changed(current: int, maximum: int)
signal charge_changed(ratio: float)
signal spin_changed(ratio: float)
signal out_of_ammo()
## Đòn trúng đích ngay trong frame bắn (hitscan, hình nón, nổ). Đạn bay có
## độ trễ nên KHÔNG đi qua đây — con trỏ ngắm lấy phản hồi của chúng qua
## `EventBus.damage_dealt`.
signal hit_landed(count: int, is_critical: bool)

## VFX tia của vũ khí hitscan (T-505). Pooled qua PoolManager.
const BEAM_SCENE: PackedScene = preload("res://scenes/vfx/hitscan_beam.tscn")

## Ngưỡng nhiệt mỗi phát để một khẩu được coi là "súng nặng" trong bảng juice
## ART-BIBLE §9. Nhiệt là thước đo sức nặng sẵn có trong dữ liệu, không cần
## thêm cờ vào WeaponData.
const HEAVY_HEAT_THRESHOLD: float = 10.0
const JUICE_RAIL_LANCE: StringName = &"wpn_rail_lance"

## Chớp lửa và vỏ đạn (T-604). Vũ khí liên tục và vũ khí Energy không nhả vỏ.
const MUZZLE_FLASH_SCENE: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
const SHELL_SCENE: PackedScene = preload("res://scenes/vfx/shell_casing.tscn")

@export var weapon_data: WeaponData
## Đầu nòng; để trống thì đạn xuất phát từ chính mount.
@export var muzzle_path: NodePath = NodePath("MuzzleModel")
## Thực thể sở hữu vũ khí — nguồn sát thương của mọi viên đạn bắn ra.
@export var shooter_path: NodePath = NodePath("../..")

## SwarmManager của nhiệm vụ, truyền tiếp cho từng viên đạn.
var swarm_manager: SwarmManager = null

var _cooldown: float = 0.0
var _charge: float = 0.0
var _spin: float = 0.0
var _ammo: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Ba đường bắn, mỗi đường một đối tượng dùng lại — không cấp phát khi bắn.
var _hitscan: Hitscan = Hitscan.new()
var _cone: ConeWeapon = ConeWeapon.new()
var _aoe: Aoe = Aoe.new()
var _ejector: ShellEjector = ShellEjector.new()

## VFX của màn chơi, do MechController tiêm vào. Để trống thì bắn vẫn chạy,
## chỉ là không có hạt — scene test không cần dựng cả dàn VFX.
var gib_manager: GibManager = null
var decal_manager: DecalManager = null

@onready var _muzzle: Node3D = get_node_or_null(muzzle_path) as Node3D
@onready var _shooter: Node = get_node_or_null(shooter_path)


func _ready() -> void:
    _hitscan.beam_scene = BEAM_SCENE
    _ejector.shell_scene = SHELL_SCENE
    if weapon_data != null:
        equip(weapon_data)


func equip(data: WeaponData) -> void:
    weapon_data = data
    _cooldown = 0.0
    _charge = 0.0
    _spin = 0.0
    _cone.reset()
    if data == null:
        return
    _ammo = data.max_ammo if data.uses_ammo else 0
    ammo_changed.emit(_ammo, data.max_ammo)


## Gọi mỗi frame vật lý. Trả về số phát vừa rời nòng: 0 hoặc 1 với vũ khí
## bắn phát một, và số tick đã nổ với vũ khí liên tục (Flamer, Cryo, Arc).
func update(delta: float, wants_fire: bool, heat: HeatComponent, aim_point: Vector3) -> int:
    if weapon_data == null or delta <= 0.0:
        return 0
    if weapon_data.is_continuous:
        return _update_continuous(delta, wants_fire, heat, aim_point)
    _cooldown = maxf(0.0, _cooldown - delta)
    var blocked: bool = heat != null and not heat.can_fire()
    if not wants_fire or blocked:
        _release_triggers(delta)
        return 0
    if weapon_data.uses_ammo and _ammo <= 0:
        out_of_ammo.emit()
        return 0
    if not _build_up(delta):
        return 0
    if _cooldown > 0.0:
        return 0
    _fire(heat, aim_point)
    return 1


func get_ammo() -> int:
    return _ammo


func get_charge_ratio() -> float:
    if weapon_data == null or weapon_data.charge_time <= 0.0:
        return 1.0
    return clampf(_charge / weapon_data.charge_time, 0.0, 1.0)


func get_spin_ratio() -> float:
    if weapon_data == null or weapon_data.spin_up_time <= 0.0:
        return 1.0
    return clampf(_spin / weapon_data.spin_up_time, 0.0, 1.0)


func is_ready_to_fire() -> bool:
    return _cooldown <= 0.0


func add_ammo(amount: int) -> void:
    if weapon_data == null or not weapon_data.uses_ammo:
        return
    _ammo = clampi(_ammo + amount, 0, weapon_data.max_ammo)
    ammo_changed.emit(_ammo, weapon_data.max_ammo)


## Bù đạn theo tỉ lệ của đạn tối đa — dạng mà hộp đạn trong màn dùng
## (GDD §11.2: +25% đạn tối đa). Trả về số viên thực sự nạp được; vũ khí
## Energy luôn trả 0 vì nó không có khái niệm đạn.
func refill(fraction: float) -> int:
    if weapon_data == null or not weapon_data.uses_ammo or fraction <= 0.0:
        return 0
    var before: int = _ammo
    add_ammo(int(round(float(weapon_data.max_ammo) * fraction)))
    return _ammo - before


## Vũ khí này có hiện số đạn trên HUD không. Energy hiện "NĂNG LƯỢNG".
func uses_ammo() -> bool:
    return weapon_data != null and weapon_data.uses_ammo


func get_max_ammo() -> int:
    if weapon_data == null or not weapon_data.uses_ammo:
        return 0
    return weapon_data.max_ammo


func is_out_of_ammo() -> bool:
    return uses_ammo() and _ammo <= 0


## Quay nòng và sạc phải hoàn tất trước khi viên đầu tiên rời nòng.
func _build_up(delta: float) -> bool:
    if weapon_data.spin_up_time > 0.0 and _spin < weapon_data.spin_up_time:
        _spin = minf(_spin + delta, weapon_data.spin_up_time)
        spin_changed.emit(get_spin_ratio())
        if _spin < weapon_data.spin_up_time:
            return false
    if weapon_data.charge_time > 0.0 and _charge < weapon_data.charge_time:
        _charge = minf(_charge + delta, weapon_data.charge_time)
        charge_changed.emit(get_charge_ratio())
        if _charge < weapon_data.charge_time:
            return false
    return true


func _release_triggers(delta: float) -> void:
    if weapon_data.charge_time > 0.0 and _charge > 0.0:
        _charge = 0.0
        charge_changed.emit(0.0)
    if weapon_data.spin_up_time > 0.0 and _spin > 0.0:
        _spin = maxf(0.0, _spin - delta)
        spin_changed.emit(get_spin_ratio())


## Vũ khí liên tục không có nhịp bắn: nó rót sát thương theo tick cố định
## suốt thời gian giữ cò. Nhiệt do `ConeWeapon` tự cộng (Cryo cộng số âm).
func _update_continuous(
    delta: float,
    wants_fire: bool,
    heat: HeatComponent,
    aim_point: Vector3
) -> int:
    var blocked: bool = heat != null and not heat.can_fire()
    var firing: bool = wants_fire and not blocked
    if firing and weapon_data.uses_ammo and _ammo <= 0:
        out_of_ammo.emit()
        firing = false
    var origin: Vector3 = _origin()
    var ticks: int = _cone.update(
        delta,
        firing,
        weapon_data,
        origin,
        _aim_direction(origin, aim_point),
        _space(),
        swarm_manager,
        heat,
        _shooter
    )
    if ticks <= 0:
        return 0
    _report_hits(_cone.get_hit_count())
    JuiceDirector.play(juice_event_for(weapon_data))
    if weapon_data.uses_ammo:
        _ammo = maxi(0, _ammo - ticks)
        ammo_changed.emit(_ammo, weapon_data.max_ammo)
    fired.emit(weapon_data, origin)
    return ticks


func _fire(heat: HeatComponent, aim_point: Vector3) -> void:
    var origin: Vector3 = _origin()
    var direction: Vector3 = _aim_direction(origin, aim_point)
    for _i: int in range(maxi(weapon_data.projectiles_per_shot, 1)):
        var shot: Vector3 = _apply_spread(direction)
        if weapon_data.projectile_scene != null:
            _spawn_projectile(origin, shot)
        else:
            _fire_hitscan(origin, shot)
    if heat != null:
        heat.add_heat(weapon_data.heat_per_shot)
    if weapon_data.uses_ammo:
        _ammo = maxi(0, _ammo - 1)
        ammo_changed.emit(_ammo, weapon_data.max_ammo)
    _cooldown = 1.0 / maxf(weapon_data.rate_of_fire, 0.01)
    _charge = 0.0
    _play_muzzle_effects(origin, direction)
    JuiceDirector.play(juice_event_for(weapon_data))
    fired.emit(weapon_data, origin)


## Chớp lửa cho mọi phát bắn; vỏ đạn chỉ cho vũ khí thật sự có đạn — súng
## laser không nhả vỏ, và vũ khí liên tục nhả 10 vỏ/giây thì đạt trần 60
## trong sáu giây mà chẳng ai kịp nhìn.
func _play_muzzle_effects(origin: Vector3, direction: Vector3) -> void:
    var container: Node = get_tree().current_scene
    if container == null:
        container = get_tree().root
    var node: Node = PoolManager.acquire(MUZZLE_FLASH_SCENE)
    var flash := node as MuzzleFlash
    if flash != null:
        container.add_child(flash)
        flash.flash(origin, direction)
    else:
        PoolManager.release(node)
    if not ejects_shells(weapon_data):
        return
    _ejector.container = container
    _ejector.eject(origin, direction)


## Hàm thuần tuý: khẩu này có nhả vỏ đạn không.
static func ejects_shells(data: WeaponData) -> bool:
    return data != null and data.uses_ammo and not data.is_continuous


## Hàm thuần tuý: vũ khí → dòng nào trong bảng juice ART-BIBLE §9.
## Vũ khí liên tục (Flamer, Cryo, Arc) luôn là "súng nhẹ": rót sát thương
## liên tục mà rung nặng mỗi tick thì camera không đứng yên nổi.
static func juice_event_for(data: WeaponData) -> StringName:
    if data == null:
        return &"fire_light"
    if data.id == JUICE_RAIL_LANCE:
        return &"rail_lance"
    if not data.is_continuous and data.heat_per_shot >= HEAVY_HEAT_THRESHOLD:
        return &"fire_heavy"
    return &"fire_light"


func _apply_spread(direction: Vector3) -> Vector3:
    if weapon_data.spread_degrees <= 0.0:
        return direction
    var half: float = deg_to_rad(weapon_data.spread_degrees) * 0.5
    return direction.rotated(Vector3.UP, _rng.randf_range(-half, half))


func _origin() -> Vector3:
    return _muzzle.global_position if _muzzle != null else global_position


func _aim_direction(origin: Vector3, aim_point: Vector3) -> Vector3:
    var direction: Vector3 = aim_point - origin
    direction.y = 0.0
    if direction.length_squared() <= 0.0001:
        direction = -global_transform.basis.z
        direction.y = 0.0
    return direction.normalized()


func _space() -> PhysicsDirectSpaceState3D:
    var world: World3D = get_world_3d()
    return world.direct_space_state if world != null else null


## Hitscan trúng ngay trong frame bắn. Vũ khí hitscan có bán kính nổ (không
## có trong bảng GDD hiện tại, nhưng dữ liệu cho phép) kích nổ ở cuối tia.
func _fire_hitscan(origin: Vector3, direction: Vector3) -> void:
    # Tia treo ở gốc màn chơi chứ không ở mount: mount xoay theo thân mech,
    # tia đã bắn ra thì phải đứng yên trong không gian.
    var container: Node = get_tree().current_scene
    _hitscan.vfx_root = container if container != null else get_tree().root
    var hits: int = _hitscan.fire(
        _space(),
        origin,
        direction,
        weapon_data.max_range,
        weapon_data.damage,
        weapon_data.damage_type,
        weapon_data.pierce_count,
        _shooter,
        swarm_manager,
        weapon_data.status_to_apply
    )
    _spawn_impact_vfx(direction)
    if weapon_data.aoe_radius <= 0.0:
        _report_hits(hits)
        return
    hits += _aoe.detonate(
        _space(),
        _hitscan.get_end_point(),
        weapon_data.aoe_radius,
        weapon_data.damage,
        weapon_data.damage_type,
        _shooter,
        swarm_manager,
        weapon_data.self_damage_radius,
        _shooter,
        weapon_data.status_to_apply
    )
    _report_hits(hits)


## Tia hitscan chạm nhiều chỗ trong cùng một frame; mỗi chỗ một cụm hạt.
## Cuối tia luôn để lại vết đạn — đó là chỗ tia cắm vào tường.
func _spawn_impact_vfx(direction: Vector3) -> void:
    if gib_manager == null:
        return
    var normal: Vector3 = -direction
    for index: int in range(_hitscan.get_hit_count()):
        var point: Vector3 = _hitscan.get_hit_position(index)
        if point == Vector3.INF:
            continue
        gib_manager.spawn_impact(point, normal, GibManager.Surface.FLESH)
    if decal_manager != null:
        decal_manager.spawn(_hitscan.get_end_point(), normal, &"bullet")


## Chí mạng chưa có nguồn phát nào trong game (perk M9 mới sinh ra nó), nên
## hiện tại mọi đòn báo về đều là đòn thường.
func _report_hits(count: int) -> void:
    if count > 0:
        hit_landed.emit(count, false)


func _spawn_projectile(origin: Vector3, direction: Vector3) -> void:
    var node: Node = PoolManager.acquire(weapon_data.projectile_scene)
    var projectile := node as Projectile
    if projectile == null:
        PoolManager.release(node)
        return
    var container: Node = get_tree().current_scene
    if container == null:
        container = get_tree().root
    container.add_child(projectile)
    projectile.swarm_manager = swarm_manager
    projectile.gib_manager = gib_manager
    projectile.decal_manager = decal_manager
    projectile.configure(
        weapon_data.pierce_count,
        weapon_data.aoe_radius,
        weapon_data.self_damage_radius,
        _shooter
    )
    projectile.launch(
        origin,
        direction,
        _projectile_speed(),
        weapon_data.damage,
        weapon_data.damage_type,
        _shooter
    )


func _projectile_speed() -> float:
    if weapon_data.projectile_speed > 0.0:
        return weapon_data.projectile_speed
    return Projectile.DEFAULT_SPEED
