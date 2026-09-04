extends Node

## Object pool chung theo PackedScene cho projectile, VFX, decal, damage
## number, actor. Xem docs/02-TDD.md §4, §12 (luật hiệu năng — cấm
## instantiate()/queue_free() trong đường chiến đấu).
## PoolManager chỉ được phép biết Log.
##
## Node lấy ra qua acquire() được gỡ khỏi cha cũ và giao cho người gọi tự
## add_child(). Khi release() node được ẩn đi và add_child() vào một
## container nội bộ (giữ chỗ), KHÔNG BAO GIỜ bị queue_free() trong đường
## chiến đấu. Nếu node có _on_acquired()/_on_released() thì pool tự gọi.

## Sổ theo dõi nội bộ cho một PackedScene cụ thể.
class _PoolEntry:
    var scene: PackedScene
    var container: Node
    var free_list: Array[Node] = []
    var in_use_count: int = 0
    var total_count: int = 0


var _pools: Dictionary = {}
var _node_to_entry: Dictionary = {}

## Số lần instantiate() đã gọi trong suốt vòng đời PoolManager. Chỉ dùng để
## kiểm toán hiệu năng (test T-009): số này không được tăng sau khi pool đã
## đủ node rảnh để tái sử dụng.
var _instantiate_count: int = 0


func prewarm(scene: PackedScene, count: int) -> void:
    var entry: _PoolEntry = _get_or_create_entry(scene)
    for _i: int in range(count):
        var node: Node = _instantiate(scene, entry)
        _store_free(entry, node)


func acquire(scene: PackedScene) -> Node:
    var entry: _PoolEntry = _get_or_create_entry(scene)
    var node: Node
    if entry.free_list.is_empty():
        node = _instantiate(scene, entry)
    else:
        node = entry.free_list.pop_back()
    if node.get_parent() != null:
        node.get_parent().remove_child(node)
    entry.in_use_count += 1
    if node.has_method("_on_acquired"):
        node.call("_on_acquired")
    return node


func release(node: Node) -> void:
    var entry: _PoolEntry = _node_to_entry.get(node) as _PoolEntry
    if entry == null:
        Log.warn("release() gọi với node không thuộc pool nào", "PoolManager")
        return
    if not is_instance_valid(entry.container):
        node.queue_free()
        _node_to_entry.erase(node)
        return
    entry.in_use_count = maxi(entry.in_use_count - 1, 0)
    if node.has_method("_on_released"):
        node.call("_on_released")
    _store_free(entry, node)


func clear_pool(scene: PackedScene) -> void:
    if not _pools.has(scene):
        return
    var entry: _PoolEntry = _pools[scene] as _PoolEntry
    for node: Node in entry.free_list:
        _node_to_entry.erase(node)
        node.queue_free()
    entry.free_list.clear()
    if is_instance_valid(entry.container):
        entry.container.queue_free()
    _pools.erase(scene)


func clear_all() -> void:
    var keys: Array = _pools.keys().duplicate()
    for scene: PackedScene in keys:
        clear_pool(scene)


func get_stats() -> Dictionary:
    var stats: Dictionary = {}
    for scene: PackedScene in _pools.keys():
        var entry: _PoolEntry = _pools[scene] as _PoolEntry
        stats[_display_key(scene)] = {"total": entry.total_count, "in_use": entry.in_use_count}
    return stats


func _get_or_create_entry(scene: PackedScene) -> _PoolEntry:
    if _pools.has(scene):
        return _pools[scene] as _PoolEntry
    var entry: _PoolEntry = _PoolEntry.new()
    entry.scene = scene
    entry.container = Node.new()
    entry.container.name = "Pool_%d" % entry.container.get_instance_id()
    add_child(entry.container)
    _pools[scene] = entry
    return entry


func _instantiate(scene: PackedScene, entry: _PoolEntry) -> Node:
    var node: Node = scene.instantiate()
    _instantiate_count += 1
    entry.total_count += 1
    _node_to_entry[node] = entry
    return node


func _store_free(entry: _PoolEntry, node: Node) -> void:
    if node.get_parent() != null:
        node.get_parent().remove_child(node)
    if node.has_method("hide"):
        node.call("hide")
    entry.container.add_child(node)
    entry.free_list.append(node)


func _display_key(scene: PackedScene) -> String:
    if not scene.resource_path.is_empty():
        return scene.resource_path
    return "PackedScene#%d" % scene.get_instance_id()
