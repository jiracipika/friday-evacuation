extends SceneTree
const Rig = preload("res://scripts/overhaul/VisualRig.gd")
const Roster = preload("res://scripts/CharacterRoster.gd")
const Skins = preload("res://scripts/ChairSkins.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")

func triangles(mesh: Mesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		count += indices.size() / 3 if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size() / 3
	return count

func run() -> void:
	var largest := 0
	for character in Roster.CHARACTERS:
		for skin in Skins.SKINS:
			var rig := Rig.new()
			root.add_child(rig)
			rig.configure(character.id, {}, skin.id)
			var visible_triangles := 0
			var hair := 0
			var face := 0
			var outfit := 0
			for mesh in rig.body.find_children("*", "MeshInstance3D", true, false):
				if not mesh.is_visible_in_tree(): continue
				visible_triangles += triangles(mesh.mesh)
				if str(mesh.name).begins_with("Hair_"): hair += 1
				if str(mesh.name).begins_with("Face_"): face += 1
				if str(mesh.name).begins_with("Outfit_"): outfit += 1
				for surface in mesh.mesh.get_surface_count():
					if mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR] == null:
						failures.append("Missing palette regions: " + str(mesh.name))
			for mesh in rig.chair.find_children("*", "MeshInstance3D", true, false):
				visible_triangles += triangles(mesh.mesh)
			largest = maxi(largest, visible_triangles)
			if visible_triangles > 20000: failures.append("Avatar exceeds triangle budget: " + character.id + ":" + skin.id)
			if hair != 1 or face != 1 or outfit != 1: failures.append("Modular visibility: " + character.id)
			if not rig.animator or rig.animator.get_animation_list().size() < 6: failures.append("Missing animation states")
			rig.free()
	print("OFFICE_ASSET_CHECK largest_avatar=", largest, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
