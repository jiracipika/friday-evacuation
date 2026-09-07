extends SceneTree
var checks: int = 0
var failures: int = 0
func _init() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
func _run() -> void:
	var props: GDScript = load("res://scripts/BlenderProps.gd")
	var vending: PackedScene = props.get_model(props.vending_machine())
	check(vending != null, "vending machine glb loads")
	var cooler: PackedScene = props.get_model(props.water_cooler())
	check(cooler != null, "water cooler glb loads")
	check(props.get_model(props.potted_plant()) != null, "potted plant glb loads")
	check(props.get_model(props.desk_printer()) != null, "desk printer glb loads")
	check(props.get_model(props.wall_clock()) != null, "wall clock glb loads")
	check(props.get_model(props.crate()) != null, "crate glb loads")
	var root_node := Node3D.new()
	root.add_child(root_node)
	for packed: PackedScene in [vending, cooler]:
		if packed == null:
			continue
		var instance := packed.instantiate()
		root_node.add_child(instance)
		await process_frame
		var meshes: Array = instance.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() >= 5, "prop has chunky part count (%d)" % meshes.size())
		var tri_total: int = 0
		var max_extent: float = 0.0
		var emissive_parts: int = 0
		for mi: MeshInstance3D in meshes:
			if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_arrays(0).size() > 0:
				var arrays: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				tri_total += indices.size() / 3
				for v: Vector3 in verts:
					max_extent = maxf(max_extent, absf(v.x))
					max_extent = maxf(max_extent, absf(v.y))
					max_extent = maxf(max_extent, absf(v.z))
			var surface_mat := mi.get_active_material(0)
			if surface_mat and surface_mat is StandardMaterial3D and (surface_mat as StandardMaterial3D).emission_enabled:
				emissive_parts += 1
		check(tri_total > 40 and tri_total < 2500, "low-poly budget (%d tris)" % tri_total)
		check(max_extent < 1.6, "fits office scale (max extent %.2f m)" % max_extent)
		check(emissive_parts > 0, "has emissive dusk-glow part (%d)" % emissive_parts)
		instance.queue_free()
	await process_frame
	check(props.spawn(root_node, props.vending_machine(), Vector3.ZERO, 0.5) != null, "spawn() mounts instance")
	check(props.spawn(root_node, "res://models/missing.glb", Vector3.ZERO) == null, "missing model falls back to null, no crash")
	var spawned: Array = root_node.find_children("*", "MeshInstance3D", true, false)
	var all_shadowless := true
	for mi: MeshInstance3D in spawned:
		all_shadowless = all_shadowless and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	check(all_shadowless, "spawned props cast no key-light shadows (repo law)")
	print("ArtBlenderPropsTest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
