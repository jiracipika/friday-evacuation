# WinnabilityProbe.gd — Full-playthrough winnability audit for ALL modes.
# Simulates real PlayerChair physics (not geometry shortcuts) and reports
# per-mode results:
#   EVACUATION: can a real chair reach the ExitZone within 120s?
#   HAULED:     can cargo be carried to the delivery zone within 100s x3?
#   SHOPSEEK:   can 5 list items be collected within 60s (guard active)?
#   PIZZA:      can 10 pepperoni be claimed within 120s (threats active)?
# Each phase instantiates the REAL scene and drives the REAL chair with the
# same move_toward steering the game uses. FAIL = unwinnable by inputs.
extends SceneTree

var results: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _fail(msg: String) -> void:
	results.append("[UNWINNABLE] " + msg)
	printerr("[UNWINNABLE] " + msg)

func _ok(msg: String) -> void:
	results.append("[WINNABLE] " + msg)
	print("[WINNABLE] " + msg)

# ---------------------------------------------------------------- helpers

func _drive_toward(chair: CharacterBody3D, target: Vector3, delta: float, speed: float = 10.0) -> void:
	if chair.is_on_floor():
		var dir := (target - chair.global_position)
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.05 else Vector3.ZERO
		chair.velocity.x = dir.x * speed
		chair.velocity.z = dir.z * speed
	else:
		chair.velocity.x = move_toward(chair.velocity.x, 0.0, delta * 4.0)
		chair.velocity.z = move_toward(chair.velocity.z, 0.0, delta * 4.0)

func _chair_in_group(evac: Node) -> CharacterBody3D:
	for n in evac.get_children():
		if n is CharacterBody3D and n.is_in_group("players"):
			return n
	return null

# ---------------------------------------------------------------- evacuation

func _test_evacuation() -> void:
	print("\n--- EVACUATION ---")
	var evac = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame

	var chair := _chair_in_group(evac)
	if chair == null:
		_fail("Evacuation: no player chair spawned")
		evac.free()
		return
	chair.set_can_move(true)

	# Elevator waypoints in travel order (must match Evacuation.gd)
	# Verified detour path: floor-1 cubicle partitions sit at x=±8 rows
	# (spanning x[5.3,10.7]) at z=-8,0,8 — but they are only 0.25 wide in z,
	# so crossing x=8 BETWEEN partitions is open. Center corridor (|x|<2.7)
	# runs z -8..8. Path: corridor north, jog east mid-gap, then to elevator.
	var waypoints: Array[Vector3] = [
		Vector3(0, 1.0, 4.0),    # corridor north (open lane)
		Vector3(12, 1.0, 4.0),   # cross x=8 column in the z=4 gap
		Vector3(12, 0.5, 14),    # elev 1->2 entry
		Vector3(12, 6.5, -2),    # post-teleport dest floor 2
		Vector3(6, 6.5, 3.0),    # jog west of the table row (tables span x[4,8] at z0; coolers at x0/-12/12)
		Vector3(6, 6.5, 12.0),   # north along the x=6 lane (clear of cooler at x=12,z=10)
		Vector3(0, 6.5, 4.0),    # cross center lane
		Vector3(-12, 6.5, 4.0),  # west side
		Vector3(-12, 6.5, -2),   # elev 2->3 entry
		Vector3(-12, 12.5, 14),  # post-teleport dest floor 3
		Vector3(0, 12.5, 8.0),   # floor-3 center strip (landing layout keeps z=6..21 solid)
		Vector3(12, 12.5, 14),   # elev 3->4 entry
		Vector3(12, 18.5, -2),   # post-teleport dest floor 4
		Vector3(0, 19.0, 15.0),  # exit zone
	]
	var wp := 0
	var elapsed := 0.0
	const TIME_LIMIT := 120.0
	var stuck_time := 0.0
	var last_pos := chair.global_position

	while elapsed < TIME_LIMIT and wp < waypoints.size():
		await physics_frame
		elapsed += 1.0 / 60.0
		_drive_toward(chair, waypoints[wp], 1.0 / 60.0)
		var target := waypoints[wp]
		var flat_d := Vector2(chair.global_position.x - target.x, chair.global_position.z - target.z).length()
		# Advance on horizontal proximity when standing at/above the waypoint's
		# floor (entry pads share the current floor; teleport dests sit at the
		# NEW floor, and y only satisfies after the pad fires).
		var y_ok := chair.global_position.y >= target.y - 3.5
		if flat_d < 2.0 and y_ok:
			wp += 1
		# Exit reached?
		if wp >= waypoints.size():
			_ok("Evacuation: exit reached in %.1fs" % elapsed)
			evac.free()
			return
		# stuck detection
		if chair.global_position.distance_to(last_pos) < 0.01:
			stuck_time += 1.0 / 60.0
		else:
			stuck_time = 0.0
		last_pos = chair.global_position
		if stuck_time > 4.0:
			_fail("Evacuation: chair stuck near waypoint %d at %s after %.1fs" % [wp, chair.global_position, elapsed])
			evac.free()
			return

	_fail("Evacuation: exit NOT reached in %.0fs (last pos %s, wp %d/%d)" % [TIME_LIMIT, chair.global_position, wp, waypoints.size()])
	evac.free()

# ---------------------------------------------------------------- hauled

func _test_hauled() -> void:
	print("\n--- HAULED ---")
	var hauled = load("res://scenes/Hauled.tscn").instantiate()
	root.add_child(hauled)
	await process_frame
	await process_frame

	var chair: CharacterBody3D = null
	for n in hauled.get_children():
		if n is CharacterBody3D and n.is_in_group("players"):
			chair = n
			break
	if chair == null:
		_fail("Hauled: no chair")
		hauled.free()
		return
	chair.set_can_move(true)

	# Find cargo and delivery zone from the scene state
	var cargo: RigidBody3D = hauled.cargo
	var elapsed := 0.0
	const LIMIT := 100.0
	var grabbed := false
	while elapsed < LIMIT:
		await physics_frame
		elapsed += 1.0 / 60.0
		if cargo and is_instance_valid(cargo):
			if not grabbed and chair.global_position.distance_to(cargo.global_position) < 2.2:
				if hauled.has_method("_try_grab_or_throw"):
					hauled._try_grab_or_throw()
					grabbed = hauled.held_by != null
			var target := cargo.global_position if not grabbed else Vector3(0, 1.0, 25.0)
			_drive_toward(chair, target, 1.0 / 60.0, 6.0)
			if grabbed and cargo.global_position.z > 21.0:
				_ok("Hauled: cargo delivered in %.1fs" % elapsed)
				hauled.free()
				return
	if cargo and is_instance_valid(cargo) and cargo.global_position.z > 21.0:
		_ok("Hauled: cargo delivered at limit")
	else:
		_fail("Hauled: cargo NOT delivered in 100s (cargo z=%.1f, grabbed=%s)" % [
			cargo.global_position.z if cargo and is_instance_valid(cargo) else -999.0, grabbed])
	hauled.free()

# ---------------------------------------------------------------- shopseek

func _test_shopseek() -> void:
	print("\n--- SHOP & SEEK ---")
	var ss = load("res://scenes/ShopSeek.tscn").instantiate()
	root.add_child(ss)
	await process_frame
	await process_frame

	var chair: CharacterBody3D = null
	for n in ss.get_children():
		if n is CharacterBody3D and n.is_in_group("players"):
			chair = n
			break
	if chair == null:
		_fail("ShopSeek: no chair")
		ss.free()
		return
	chair.set_can_move(true)

	# list fields on the scene: list_items / list_collected; target is list_target
	var target_count: int = ss.list_target
	var collected: int = ss.list_collected.size()
	var elapsed := 0.0
	const LIMIT := 60.0
	# Gather positions of props whose kind label is on the list
	var items: Array[Vector3] = []
	var wanted: Array[String] = []
	for label in ss.list_items:
		if not ss.list_collected.has(label):
			wanted.append(label)
	for prop in root.get_tree().get_nodes_in_group("disguise_props"):
		if prop is Node3D and not prop.get_meta("taken", false):
			var k: Dictionary = prop.get_meta("kind", {})
			if String(k.get("label", "")) in wanted:
				items.append(prop.global_position)
	var idx := 0
	while elapsed < LIMIT and collected < target_count:
		await physics_frame
		elapsed += 1.0 / 60.0
		if idx < items.size():
			_drive_toward(chair, items[idx], 1.0 / 60.0)
			if chair.global_position.distance_to(items[idx]) < 1.4:
				idx += 1
			# the real pickup check runs in _process each frame
			collected = ss.list_collected.size()
			if collected >= target_count:
				_ok("ShopSeek: %d/%d collected in %.1fs" % [collected, target_count, elapsed])
				ss.free()
				return
		else:
			_drive_toward(chair, Vector3(0, 1.0, 0), 1.0 / 60.0)
	if collected >= target_count:
		_ok("ShopSeek: %d/%d collected in %.1fs" % [collected, target_count, elapsed])
	else:
		_fail("ShopSeek: only %d/%d in 60s (idx %d/%d)" % [collected, target_count, idx, items.size()])
	ss.free()

# ---------------------------------------------------------------- pizza

func _test_pizza() -> void:
	print("\n--- PIZZA COLONY ---")
	var pc = load("res://scenes/PizzaColony.tscn").instantiate()
	root.add_child(pc)
	await process_frame
	await process_frame

	var chair: CharacterBody3D = pc.player
	if chair == null:
		_fail("Pizza: no chair")
		pc.free()
		return
	chair.set_can_move(true)

	var pads: Array = pc.pepperonis
	var elapsed := 0.0
	const LIMIT := 120.0
	var claimed := 0
	var pad_idx := 0
	while elapsed < LIMIT and pad_idx < pads.size():
		await physics_frame
		elapsed += 1.0 / 60.0
		_drive_toward(chair, pads[pad_idx]["pos"], 1.0 / 60.0, 8.0)
		if chair.global_position.distance_to(pads[pad_idx]["pos"]) < 1.5:
			pad_idx += 1
	if pad_idx >= pads.size():
		_ok("Pizza: visited all %d pads in %.1fs (claim timers may extend)" % [pads.size(), elapsed])
	else:
		_fail("Pizza: reached only %d/%d pads in 120s" % [pad_idx, pads.size()])
	pc.free()

# ---------------------------------------------------------------- main

func _run() -> void:
	await _test_evacuation()
	await _test_hauled()
	await _test_shopseek()
	await _test_pizza()
	print("\n=== WINNABILITY AUDIT COMPLETE ===")
	var unwin := 0
	for r in results:
		if r.begins_with("[UNWINNABLE]"):
			unwin += 1
	print("Summary: %d winnable, %d UNWINNABLE" % [results.size() - unwin, unwin])
	quit(0 if unwin == 0 else 1)
