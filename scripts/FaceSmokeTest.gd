extends SceneTree
# Mesh faces stay visible and react to acceleration with shared materials.
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/PlayerChair.tscn")
	for expression in ["focused", "sleepy", "derpy", "panic"]:
		var chair = scene.instantiate()
		chair.use_global_character = false
		chair.use_global_skin = false
		chair.character_design = {"expression": expression}
		root.add_child(chair)
		chair.set_physics_process(false)
		var rider: Node3D = chair.rider_root
		var pupil := rider.get_node_or_null("Head/PupilL") as MeshInstance3D
		var other := rider.get_node_or_null("Head/PupilR") as MeshInstance3D
		if not rider.visible or not pupil or not other:
			printerr("[FAIL] missing visible mesh eyes: " + expression)
			quit(1)
			return
		var rest := pupil.position
		var material_before := pupil.material_override
		chair.velocity = Vector3(6, 0, 0)
		chair._update_googly_eyes(1.0 / 60.0)
		if pupil.position.is_equal_approx(rest) or pupil.material_override != material_before:
			printerr("[FAIL] mesh pupils must wobble using transforms: " + expression)
			quit(1)
			return
		chair.free()
	print("=== FACE SMOKE TEST PASSED ===")
	quit(0)
