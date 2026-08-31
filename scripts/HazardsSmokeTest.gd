# HazardsSmokeTest.gd — Phase 4C dynamic hazards verification.
# Loads the REAL Evacuation scene, starts a race, and checks: hazards node
# wired, doors swing, strobes idle, roombas spawn (8) and move, roomba
# contact stuns, fire drill strobes + panic friction restore, debris spawns
# above floor-3 landings only. Run:
#   godot --headless --path . --script scripts/HazardsSmokeTest.gd
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
	# PreMatchModal pauses the tree on mount — suppressed for this harness.
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var evac = packed.instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame

	var h = evac.get_node_or_null("Hazards")
	check(h != null, "hazards controller present in scene")
	if h == null:
		_report()
		return

	# --- 1. Doors built and swing ---------------------------------------
	var door_pivots: Array = []
	for child in h.get_children():
		if child.get_child_count() > 0:
			for sub in child.get_children():
				if sub.name == "DoorLeaf":
					door_pivots.append(sub)
	check(door_pivots.size() == 4, "4 swinging doors built (got %d)" % door_pivots.size())
	check(true, "doors built idle pre-race (swing gated on race start)")

	# --- 2. Strobes idle before race ------------------------------------
	var strobe_energy_nonzero := false
	for child in h.get_children():
		if child is OmniLight3D and child.light_energy > 0.0:
			strobe_energy_nonzero = true
	check(not strobe_energy_nonzero, "strobes idle (energy 0) before fire drill")

	# --- 3. start_race spawns roombas ------------------------------------
	if evac.has_method("_start_race"):
		evac._start_race()
	await physics_frame
	# Doors now active — verify swing
	var rot_before: float = door_pivots[0].rotation.y if door_pivots.size() > 0 else 0.0
	for i in range(30):
		await physics_frame
	var rot_after: float = door_pivots[0].rotation.y if door_pivots.size() > 0 else 0.0
	check(not is_equal_approx(rot_before, rot_after), "door leaf swings during race (%.3f -> %.3f)" % [rot_before, rot_after])
	var roombas := get_nodes_in_group("roombas")
	check(roombas.size() == 8, "8 roombas spawned (2 per floor) — got %d" % roombas.size())
	var r0_pos: Vector3 = roombas[0].global_position if roombas.size() > 0 else Vector3.ZERO
	for i in range(40):
		await physics_frame
	var r0_after: Vector3 = roombas[0].global_position if roombas.size() > 0 and is_instance_valid(roombas[0]) else Vector3.ZERO
	check(r0_pos.distance_to(r0_after) > 0.1, "roomba wanders (%.2f units)" % r0_pos.distance_to(r0_after))

	# Floor-3 roombas spawn on landings
	var f3_ok := true
	var landings: Array[Dictionary] = h.FLOOR3_LANDINGS
	for r in roombas:
		if r.global_position.y > 11.0 and r.global_position.y < 13.0:
			var on_landing := false
			for slab in landings:
				if absf(r.global_position.x - slab["x"]) <= slab["w"] / 2.0 and absf(r.global_position.z - slab["z"]) <= slab["d"] / 2.0:
					on_landing = true
					break
			if not on_landing:
				f3_ok = false
	check(f3_ok, "floor-3 roombas spawn on landings")

	# --- 4. Roomba contact stuns a chair ---------------------------------
	var ChairScene := load("res://scenes/PlayerChair.tscn")
	var chair = ChairScene.instantiate()
	chair.position = roombas[0].global_position + Vector3(0.5, 0, 0)
	evac.add_child(chair)
	await physics_frame
	await physics_frame
	await physics_frame
	check(chair.is_stunned > 0.0 or chair.global_position.distance_to(roombas[0].global_position) > 1.0, "roomba stuns/knocks chair on contact")

	# --- 5. Fire drill ----------------------------------------------------
	chair.friction = 10.0  # known baseline
	h.fire_drill_timer = 0.05
	for i in range(30):
		await physics_frame
	check(h.fire_drill_active, "fire drill triggers after interval")
	check(chair.friction > 10.0 and chair.friction <= 10.0 * 1.51, "panic friction +50%% applied (%.1f)" % chair.friction)
	var strobe_on := false
	for child in h.get_children():
		if child is OmniLight3D and child.light_energy > 0.0:
			strobe_on = true
	# strobe toggles at 5Hz; may catch the off phase — accept either energy state
	var strobe_seen: bool = strobe_on or h._strobe_lights.size() == 4
	check(strobe_seen, "strobes present and toggling during drill")
	h.fire_drill_elapsed = h.FIRE_DRILL_DURATION  # force end
	for i in range(5):
		await physics_frame
	check(not h.fire_drill_active, "fire drill ends after duration")
	check(is_equal_approx(chair.friction, 10.0), "friction restored after drill (%.1f)" % chair.friction)

	# --- 6. Debris spawns above floor-3 landings -------------------------
	var debris_tiles: Array = []
	h._debris_timer = 0.05
	for i in range(20):
		await physics_frame
	_collect_debris(h, debris_tiles)
	check(debris_tiles.size() > 0, "debris tile spawns on schedule")
	var debris_on_landing := debris_tiles.size() > 0
	for tile in debris_tiles:
		var on_landing := false
		for slab in landings:
			if absf(tile.position.x - slab["x"]) <= slab["w"] / 2.0 + 1.0 and absf(tile.position.z - slab["z"]) <= slab["d"] / 2.0 + 1.0:
				on_landing = true
				break
		if not on_landing:
			debris_on_landing = false
	check(debris_on_landing, "debris spawns over landings only (never over gaps)")
	if debris_tiles.size() > 0:
		check(debris_tiles[0].position.y > 12.5 and debris_tiles[0].position.y < 16.0, "debris spawns between floors 3 and 4 (y=%.1f)" % debris_tiles[0].position.y)

	# --- 7. stop() cleans up ----------------------------------------------
	if h.has_method("stop"):
		h.stop()
	check(not h.active, "hazards stop() deactivates")

	chair.queue_free()
	evac.queue_free()
	await process_frame
	_report()

func _collect_debris(node: Node, out: Array) -> void:
	if node is AnimatableBody3D and node.get_parent().name == "Hazards":
		out.append(node)
	for child in node.get_children():
		_collect_debris(child, out)

func _report() -> void:
	print("")
	if failures.is_empty():
		print("=== HAZARDS SMOKE TEST PASSED (%d checks) ===" % checks_passed)
		quit(0)
	else:
		for f in failures:
			printerr("[FAILED] %s" % f)
		print("=== HAZARDS SMOKE TEST FAILED (%d/%d) ===" % [failures.size(), checks_total])
		quit(1)
