# PanicCamSmokeTest.gd — verifies the panic-cam PiP mounts and tracks.
extends SceneTree

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("[PASS] " + label)
	else:
		fails += 1
		printerr("[FAIL] " + label)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var PanicCamScript = load("res://scripts/PanicCam.gd")
	check(PanicCamScript != null, "PanicCam.gd loads")

	var root_node := Node3D.new()
	get_root().add_child(root_node)

	# Null-safety: mount with nulls returns null, no crash
	check(PanicCamScript.mount(null, null) == null, "mount(null,null) is null-safe")

	# Fake rider (Node3D with the fields _process reads)
	var rider := Node3D.new()
	rider.set("is_boosting", true)
	rider.set("is_stunned", 0.0)
	root_node.add_child(rider)

	var pip = PanicCamScript.mount(root_node, rider)
	check(pip != null, "mount returns a control")
	if pip == null:
		quit(1)
		return

	# Simulate a couple frames
	for i in range(3):
		await process_frame
	check(is_instance_valid(pip), "panic cam survives frames")
	var children: Array = pip.get_children()
	var has_vp_container := false
	for c in children:
		if c is SubViewportContainer:
			has_vp_container = true
	check(has_vp_container, "hosts a SubViewportContainer")
	var vp: SubViewport = null
	for c in children:
		if c is SubViewportContainer:
			for gc in c.get_children():
				if gc is SubViewport:
					vp = gc
	check(vp != null, "SubViewport exists")
	if vp:
		var has_cam := false
		var has_light := false
		for gc in vp.get_children():
			if gc is Camera3D:
				has_cam = true
			if gc is Light3D:
				has_light = true
		check(has_cam, "dedicated face Camera3D present")
		check(has_light, "dedicated lamp present")
		# Camera should be tracking near the rider head position
		var cam: Camera3D = null
		for gc in vp.get_children():
			if gc is Camera3D:
				cam = gc
		if cam:
			var expected_head: Vector3 = rider.global_position + Vector3.UP * 1.5
			var dist: float = cam.global_position.distance_to(expected_head)
			check(dist < 1.6, "face camera tracks rider head (dist %.2f)" % dist)

	# Dedupe: second mount returns the same node and rebinds target
	var again = PanicCamScript.mount(root_node, rider)
	check(again == pip, "mount dedupes")

	if fails == 0:
		print("=== PANICCAM SMOKE TEST PASSED ===")
		quit(0)
	else:
		printerr("=== PANICCAM SMOKE TEST FAILED (%d) ===" % fails)
		quit(1)
