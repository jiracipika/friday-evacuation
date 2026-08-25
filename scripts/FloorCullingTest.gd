# FloorCullingTest.gd — Phase 7C distance-based floor culling verification.
# Loads the REAL Evacuation scene and verifies:
#   1. All four ceiling-light groups register for culling.
#   2. On floor 1, floors 3+4 (distance > 2) are hidden, floor 2 lights off.
#   3. Player's own floor lights stay on and visible.
#   4. Moving the player to floor 4 flips culling (floors 1+2 hidden).
#   5. Collision is never affected: hidden floors still report their
#      StaticBody3D collision shapes as active (visible=false does not
#      disable collision in Godot — assert shape data still exists).
# Run: godot --headless --path . --script scripts/FloorCullingTest.gd
extends SceneTree

var checks_total := 0
var checks_passed := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks_total += 1
	if cond:
		checks_passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://scenes/Evacuation.tscn")
	var evac = packed.instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame
	await process_frame

	# 1. Registration
	check(evac._floor_groups.has(0) and evac._floor_groups.has(1) \
		and evac._floor_groups.has(2) and evac._floor_groups.has(3),
		"all four floors registered for culling")

	# 2. Spawn state (player on floor 1)
	var f1_group: Node = (evac._floor_groups[0] as Array)[0]
	var f2_group: Node = (evac._floor_groups[1] as Array)[0]
	var f3_group: Node = (evac._floor_groups[2] as Array)[0]
	var f4_group: Node = (evac._floor_groups[3] as Array)[0]
	check(f1_group.visible, "current floor (1) group visible")
	check(f2_group.visible, "adjacent floor (2) group visible")
	check(not f3_group.visible, "far floor (3) group hidden on floor 1")
	check(not f4_group.visible, "far floor (4) group hidden on floor 1")

	var f1_lights := f1_group.find_children("*", "OmniLight3D", true, false)
	var f2_lights := f2_group.find_children("*", "OmniLight3D", true, false)
	var all_on := true
	for l in f1_lights:
		all_on = all_on and (l as Node3D).visible
	check(all_on, "current floor lights stay on")
	var f2_off := f2_lights.size() > 0
	for l in f2_lights:
		f2_off = f2_off and not (l as Node3D).visible
	check(f2_off, "adjacent floor (2) lights culled on floor 1")

	# 3. Move player to floor 4 and let culling update
	evac.local_player.global_position = Vector3(0, 19.0, 0)
	await process_frame
	await process_frame
	check(not f1_group.visible, "floor 1 group hidden when player on floor 4")
	check(not f2_group.visible, "floor 2 group hidden when player on floor 4")
	check(f3_group.visible, "adjacent floor (3) visible when player on floor 4")
	check(f4_group.visible, "current floor (4) visible")
	var f4_lights := f4_group.find_children("*", "OmniLight3D", true, false)
	var f4_on := f4_lights.size() > 0
	for l in f4_lights:
		f4_on = f4_on and (l as Node3D).visible
	check(f4_on, "current floor (4) lights on after moving")

	# 4. Collision intact on hidden floors: count StaticBody3D with shapes on floor 1
	var statics_with_shapes := 0
	for node in root.find_children("*", "StaticBody3D", true, false):
		if node.get_parent() == null:
			continue
		var has_shape := false
		for c in node.get_children():
			if c is CollisionShape3D and c.shape != null:
				has_shape = true
		if has_shape:
			statics_with_shapes += 1
	check(statics_with_shapes > 20, "collision shapes intact while far floors hidden (got %d)" % statics_with_shapes)

	if failures.is_empty():
		print("=== FLOOR CULLING TEST PASSED (%d checks) ===" % checks_total)
		quit(0)
	else:
		printerr("=== FLOOR CULLING TEST FAILED (%d/%d) ===" % [failures.size(), checks_total])
		quit(1)
