@tool
extends SceneTree
## Offline only: run with --editor --rendering-method mobile and a Vulkan driver.
## Runtime remains GL Compatibility. These scenes carry their unwraps/lightmaps.
const Course = preload("res://scripts/overhaul/RaceCourse.gd")
const Builder = preload("res://scripts/overhaul/CourseBuilder.gd")
func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var args := OS.get_cmdline_user_args()
	var layout := args[0] if not args.is_empty() else "open_plan"
	var stage := Node3D.new()
	stage.name = "BakedOffice"
	root.add_child(stage)
	Builder.new().build(stage, Course.new(layout), false, false)
	var processed: Dictionary = {}
	for instance in stage.find_children("*", "MeshInstance3D", true, false):
		var node: Node = instance
		var dynamic := false
		while node != stage:
			dynamic = dynamic or node.has_meta("pickup") or node.has_meta("hazard")
			node = node.get_parent()
		if dynamic:
			continue
		var original: Mesh = instance.mesh
		if not processed.has(original):
			var mesh := ArrayMesh.new()
			for surface in original.get_surface_count():
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, original.surface_get_arrays(surface))
				mesh.surface_set_material(surface, original.surface_get_material(surface))
			var error := mesh.lightmap_unwrap(Transform3D.IDENTITY, 0.65)
			if error != OK:
				push_error("UV unwrap failed: %s" % instance.name)
				quit(1)
				return
			processed[original] = mesh
		instance.mesh = processed[original]
		instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	var lightmap := LightmapGI.new()
	lightmap.name = "BakedIndirect"
	lightmap.quality = LightmapGI.BAKE_QUALITY_LOW
	lightmap.max_texture_size = 2048
	lightmap.bounces = 2
	lightmap.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_4
	stage.add_child(lightmap)
	DirAccess.make_dir_recursive_absolute("res://scenes/overhaul/baked")
	for i in 3: await process_frame
	for node in stage.find_children("*", "", true, false):
		node.scene_file_path = ""
		node.owner = stage
		if str(node.name).begins_with("@"):
			node.name = "Part_%d" % node.get_instance_id()
	var packed := PackedScene.new()
	packed.pack(stage)
	var error := ResourceSaver.save(packed, "res://scenes/overhaul/baked/%s.scn" % layout, ResourceSaver.FLAG_COMPRESS)
	print("PREPARED_BAKE_SCENE ", layout, " error=", error)
	quit(0 if error == OK else 1)
