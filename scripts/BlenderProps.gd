# BlenderProps.gd — loads and mounts Blender-authored glTF hero props.
#
# Dusk + toybox art pass: chunky low-poly props built in Blender
# (models/vending_machine.glb, models/water_cooler.glb), exported with
# principled materials + emissive fronts that read under the dusk grade
# without extra lights. Non-colliding dressing — collision stays with the
# existing fixture/prop bodies. Falls back silently (returns null) when a
# model is missing so the game boots on any checkout.
class_name BlenderProps
extends RefCounted

static var _cache: Dictionary = {}

static func get_model(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path] as PackedScene
	if not FileAccess.file_exists(path):
		push_warning("BlenderProps: missing model %s" % path)
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		push_warning("BlenderProps: failed to load %s" % path)
		return null
	_cache[path] = packed
	return packed

## Instance a prop at world position with yaw. Returns the root Node3D or null.
static func spawn(parent: Node3D, path: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	if parent == null:
		return null
	var packed := get_model(path)
	if packed == null:
		return null
	var instance := packed.instantiate()
	instance.position = pos
	instance.rotation.y = yaw
	# Decorative dressing: no shadows smeared by the key light (repo law).
	for mi in instance.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

static func vending_machine() -> String:
	return "res://models/vending_machine.glb"

static func water_cooler() -> String:
	return "res://models/water_cooler.glb"

static func clear_cache() -> void:
	_cache.clear()
