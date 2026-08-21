# ThemedFloorsSmokeTest.gd — Phase 4A themed floors verification.
# Loads the REAL Evacuation scene and checks: themed dressing exists per
# floor, floor 3 has gapped landings (no full slab), checkpoints advance,
# respawn works, surface zones apply grip. Headless; autoloads resolved
# defensively. Run:
#   godot --headless --path . --script scripts/ThemedFloorsSmokeTest.gd
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
		print("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://scenes/Evacuation.tscn")
	var evac = packed.instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame

	# --- 1. Themed dressing exists --------------------------------------
	var static_bodies: Array = []
	var areas: Array = []
	evac.get_tree() == null  # noop
	_collect(evac, static_bodies, areas)

	var has_partition := false
	var has_plant := false
	var has_conference := false
	var has_crate := false
	var has_round_table := false
	var has_car := false
	for sb in static_bodies:
		var col: CollisionShape3D = _first_col(sb)
		if col == null:
			continue
		var shape = col.shape
		if shape is BoxShape3D:
			var bs: BoxShape3D = shape
			if is_equal_approx(bs.size.x, 5.4) and is_equal_approx(bs.size.z, 0.25):
				has_partition = true
			if is_equal_approx(bs.size.x, 4.0) and is_equal_approx(bs.size.z, 1.2) and absf(sb.global_position.y) < 9.0 and absf(sb.global_position.y - 6.0) < 3.0:
				has_conference = true
			if is_equal_approx(bs.size.x, 1.4) and is_equal_approx(bs.size.y, 1.4):
				has_crate = true
			if is_equal_approx(bs.size.x, 1.9) and is_equal_approx(bs.size.z, 4.2):
				has_car = true
		if shape is CylinderShape3D:
			var cs: CylinderShape3D = shape
			if is_equal_approx(cs.radius, 1.1):
				has_round_table = true
			if is_equal_approx(cs.radius, 0.4) and is_equal_approx(cs.height, 1.2):
				has_plant = true
	check(has_partition, "floor 1 cubicle partitions present")
	check(has_plant, "floor 1 office plants present")
	check(has_conference, "floor 2 conference tables present")
	check(has_crate, "floor 3 crates present")
	check(has_round_table, "floor 4 round tables present")
	check(has_car, "floor 4 parked cars present")

	# --- 2. Floor 3 gaps: no full 40x40 slab at y=12 --------------------
	var full_slab_at_12 := false
	for sb in static_bodies:
		if absf(sb.global_position.y - 12.0) > 0.5:
			continue
		var col: CollisionShape3D = _first_col(sb)
		if col == null:
			continue
		var shape = col.shape
		if shape is BoxShape3D and (shape as BoxShape3D).size.x >= 40.0 and (shape as BoxShape3D).size.z >= 40.0:
			full_slab_at_12 = true
	check(not full_slab_at_12, "floor 3 base slab removed (real fall-through gaps)")

	# Elevator pads rest on solid landings
	var landings_at := func(x: float, z: float) -> bool:
		for sb in static_bodies:
			if absf(sb.global_position.y - 12.0) > 0.5:
				continue
			var col2: CollisionShape3D = _first_col(sb)
			if col2 == null or not (col2.shape is BoxShape3D):
				continue
			var bs2: BoxShape3D = col2.shape
			if absf(x - sb.global_position.x) <= bs2.size.x / 2.0 and absf(z - sb.global_position.z) <= bs2.size.z / 2.0:
				return true
		return false
	check(landings_at.call(-12.0, 14.0), "elevator-2 destination on solid landing")
	check(landings_at.call(12.0, 14.0), "elevator-3 entry on solid landing")

	# --- 3. Surface zones present with correct friction -----------------
	var zone_count := 0
	var has_ice := false
	for node in areas:
		if node.get_script() != null and "friction_mult" in node:
			zone_count += 1
			if is_equal_approx(float(node.friction_mult), 0.16):
				has_ice = true
	check(zone_count >= 4, "surface zones present (tile/carpet/ice/lot) — got %d" % zone_count)
	check(has_ice, "ice zone on floor 4 (friction 0.16)")

	# --- 4. Stun fixtures (water coolers + spills) ----------------------
	var cooler_count := 0
	for node in static_bodies:
		if node.get_script() != null and "stun_duration" in node:
			cooler_count += 1
	check(cooler_count >= 6, "stun fixtures present (3 coolers + 3 spills) — got %d" % cooler_count)

	# --- 5. Checkpoint + respawn wiring ---------------------------------
	var player = evac.local_player
	check(player != null and "respawn_point" in player, "player has respawn checkpoint")
	if player:
		check(player.respawn_point.y < 2.0, "initial checkpoint at floor 1 spawn")
		# Simulate a fall: park the chair 5+ units below the floor-1 checkpoint
		player.global_position = Vector3(0, -5.0, 0)
		await physics_frame
		if evac.has_method("_respawn_if_fell"):
			evac._respawn_if_fell()
		check(is_instance_valid(player) and absf(player.global_position.y - 1.0) < 0.5, "fallen player respawned at checkpoint (y=%.1f)" % player.global_position.y)

	# --- 6. Chair surface-grip API --------------------------------------
	var ChairScene := load("res://scenes/PlayerChair.tscn")
	var chair = ChairScene.instantiate()
	evac.add_child(chair)
	await physics_frame
	chair.set_surface(0.16)
	chair.velocity = Vector3(10, 0, 0)
	# friction application is internal; verify state via a probe of behavior
	chair._apply_friction(0.016)
	var v_after_ice: float = chair.velocity.x
	chair.clear_surface()
	chair.velocity = Vector3(10, 0, 0)
	chair._apply_friction(0.016)
	var v_after_normal: float = chair.velocity.x
	check(v_after_ice > v_after_normal, "ice keeps speed better than normal floor (%.2f > %.2f)" % [v_after_ice, v_after_normal])
	chair.queue_free()

	evac.queue_free()
	await process_frame
	_report()


## Procedural nodes get @-names, so find the first CollisionShape3D child.
func _first_col(node: Node) -> CollisionShape3D:
	for child in node.get_children():
		if child is CollisionShape3D:
			return child
	return null

func _collect(node: Node, static_bodies: Array, areas: Array) -> void:
	if node is StaticBody3D:
		static_bodies.append(node)
	if node is Area3D:
		areas.append(node)
	for child in node.get_children():
		_collect(child, static_bodies, areas)

func _report() -> void:
	print("")
	if failures.is_empty():
		print("=== THEMED FLOORS SMOKE TEST PASSED (%d checks) ===" % checks_passed)
		quit(0)
	else:
		for f in failures:
			printerr("[FAILED] %s" % f)
		print("=== THEMED FLOORS SMOKE TEST FAILED (%d/%d) ===" % [failures.size(), checks_total])
		quit(1)
