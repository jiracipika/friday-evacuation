extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + description)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var scene = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var assemblies := get_nodes_in_group("office_architecture")
	check(assemblies.size() == 4, "four real level architecture assemblies")
	for floor_index in range(4):
		var assembly: Node3D = scene.get_node("OfficeArchitecture%d" % floor_index)
		check(is_equal_approx(assembly.position.y, floor_index * 6.0), "correct story elevation %d" % floor_index)
		check(assembly.find_children("*", "CollisionObject3D", true, false).is_empty(), "no added colliders %d" % floor_index)
		check(assembly.find_children("*", "Light3D", true, false).is_empty(), "no additional lights %d" % floor_index)
		check(assembly.has_node("FivePMClock"), "clock mounted %d" % floor_index)
		check(scene._floor_groups[floor_index].has(assembly), "culling registered %d" % floor_index)
		var meshes: Array = assembly.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() <= 42, "bounded meshes %d: %d" % [floor_index, meshes.size()])
		for mesh in meshes:
			check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no extra shadow draw")
	scene.local_player.position.y = 0.8
	scene._update_floor_culling()
	check(not scene.get_node("OfficeArchitecture3").visible, "far story culled")
	scene.local_player.position.y = 18.8
	scene._update_floor_culling()
	check(scene.get_node("OfficeArchitecture3").visible, "destination story restored")
	scene.queue_free()
	await process_frame
	print("OfficeArchitectureSmokeTest: %d/%d checks PASS" % [checks - failures, checks])
	quit(1 if failures else 0)
