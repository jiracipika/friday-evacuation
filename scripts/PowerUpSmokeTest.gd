# PowerUpSmokeTest.gd — Phase 4B power-up variety verification.
# Standalone (extends SceneTree): no autoloads required; GameManager etc.
# are resolved defensively. Run:
#   godot --headless --path . --script scripts/PowerUpSmokeTest.gd
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
	_run_tests.call_deferred()

func _run_tests() -> void:
	var PowerUp := load("res://scripts/PowerUpVisual.gd")
	var TrapScene := load("res://scenes/objects/SabotageTrap.tscn")
	var BoltScript := load("res://scripts/StaplerBolt.gd")
	var ChairScene := load("res://scenes/PlayerChair.tscn")
	var HUDScript := load("res://scripts/HUD.gd")
	var OverlayScript := load("res://scripts/SubtitleOverlay.gd")

	# --- 1. Weighted distribution sanity -------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var counts := {}
	for i in range(6000):
		var k: int = PowerUp.pick_weighted(rng)
		counts[k] = int(counts.get(k, 0)) + 1
	check(int(counts.get(PowerUp.Kind.COFFEE, 0)) > 2600, "coffee dominates (60%%) — got %d/6000" % int(counts.get(PowerUp.Kind.COFFEE, 0)))
	check(counts.has(PowerUp.Kind.EXTINGUISHER) or counts.has(PowerUp.Kind.PRINTER), "rare kinds appear in 6000 rolls")
	var kinds_seen: int = 0
	for key in PowerUp.WEIGHTS:
		if counts.has(key):
			kinds_seen += 1
	check(kinds_seen >= 5, "at least 5 kinds appear in 6000 rolls (got %d)" % kinds_seen)

	# --- 2. Trap forced type + spill visuals ----------------------------
	var trap = TrapScene.instantiate()
	trap._set_forced_type("spill")
	var test_root := Node3D.new()
	root.add_child(test_root)
	test_root.add_child(trap)
	await process_frame
	check(trap.trap_type == "spill", "forced spill type applied")
	var col_node = trap.get_node_or_null("CollisionShape3D")
	var spill_shape = col_node.shape as CylinderShape3D if col_node else null
	check(spill_shape != null and is_equal_approx(spill_shape.radius, 1.6), "spill trap has wide cylinder shape")
	trap.queue_free()

	# Random traps still work
	var trap2 = TrapScene.instantiate()
	test_root.add_child(trap2)
	await process_frame
	check(trap2.trap_type in ["water", "banana", "stapler"], "random trap type unchanged (%s)" % trap2.trap_type)
	trap2.queue_free()

	# --- 3. PlayerChair give_item / _use_item ----------------------------
	var chair = ChairScene.instantiate()
	test_root.add_child(chair)
	await physics_frame
	check(chair.item_kind == &"none" and chair.item_charges == 0, "chair starts with no item")
	chair.give_item(&"stapler", 3)
	check(chair.item_kind == &"stapler" and chair.item_charges == 3, "give_item sets stapler x3")
	chair.item_ready = true
	chair._use_item()
	await physics_frame
	check(chair.item_charges == 2, "use_item consumes a stapler charge (3->2)")

	# Spill item drops a forced-spill trap behind the chair
	chair.give_item(&"spill", 2)
	chair.item_ready = true
	chair._use_item()
	await physics_frame
	var dropped := false
	for node in test_root.get_children():
		if node is Area3D and "trap_type" in node and node.trap_type == "spill":
			dropped = true
			node.queue_free()
	check(dropped, "spill item drops a wide spill trap")

	# Stapler bolt flies and never hits its firer
	var bolt = CharacterBody3D.new()
	bolt.set_script(BoltScript)
	test_root.add_child(bolt)
	bolt.owner_id = chair.get_instance_id()
	bolt.launch(Vector3.FORWARD, Vector3.ZERO)
	await physics_frame
	var bolt_valid = is_instance_valid(bolt)
	check(bolt_valid, "stapler bolt survives a frame in flight")
	if bolt_valid:
		bolt.queue_free()

	# --- 4. Pickup nodes of every kind build cleanly ---------------------
	for kind_key in PowerUp.WEIGHTS:
		var pu = PowerUp.create(kind_key)
		test_root.add_child(pu)
		await process_frame
		var label3d: Label3D = null
		for child in pu.get_children():
			if child is Label3D:
				label3d = child
		check(label3d != null and label3d.text.length() > 0, "pickup %s has colorblind label" % PowerUp.KIND_NAMES[kind_key])
		var has_collision := false
		for child in pu.get_children():
			if child is CollisionShape3D:
				has_collision = true
		check(has_collision, "pickup %s has collision shape" % PowerUp.KIND_NAMES[kind_key])
		pu.queue_free()
	await process_frame

	# --- 5. HUD set_item / set_boost ------------------------------------
	var hud_layer = CanvasLayer.new()
	hud_layer.set_script(HUDScript)
	test_root.add_child(hud_layer)
	await process_frame
	hud_layer.set_item(&"stapler", 2)
	check(hud_layer.item_label != null and hud_layer.item_label.text.contains("STAPLER"), "HUD shows stapler item")
	hud_layer.set_item(&"spill", 3)
	check(hud_layer.item_label.text.contains("SPILL"), "HUD shows spill item")
	hud_layer.set_item(&"none", 0)
	check(hud_layer.item_label.text == "", "HUD clears item readout")
	hud_layer.set_boost(1.2, 0.8, false, 2.5)
	check(hud_layer.boost_label != null and hud_layer.boost_label.text.contains("1.2"), "set_boost uses real cooldown max")
	hud_layer.queue_free()

	# --- 6. SubtitleOverlay.mount dedupes --------------------------------
	OverlayScript.mount(test_root)
	await process_frame
	var overlays := root.get_tree().get_nodes_in_group("caption_overlays") if false else get_nodes_in_group("caption_overlays")
	check(overlays.size() == 1, "mount creates exactly one overlay (got %d)" % overlays.size())
	OverlayScript.mount(test_root)
	await process_frame
	overlays = get_nodes_in_group("caption_overlays")
	check(overlays.size() == 1, "second mount call is a no-op")

	# --- 7. Pickup effect: energy drink applies stronger boost ------------
	var chair2 = ChairScene.instantiate()
	test_root.add_child(chair2)
	await physics_frame
	chair2.velocity = Vector3(6, 0, 0)
	var pu_energy = PowerUp.create(PowerUp.Kind.ENERGY_DRINK)
	test_root.add_child(pu_energy)
	pu_energy.global_position = chair2.global_position
	await physics_frame
	await physics_frame
	var boosted: bool = chair2.is_boosting
	check(boosted, "energy drink pickup triggers boost")
	check(chair2.boost_timer > chair2.boost_duration * 1.5, "energy drink doubles boost duration (%.2f > %.2f)" % [chair2.boost_timer, chair2.boost_duration * 1.5])
	chair2.queue_free()

	chair.queue_free()
	test_root.queue_free()
	await process_frame

	_report()

func _report() -> void:
	print("")
	if failures.is_empty():
		print("=== POWER-UP SMOKE TEST PASSED (%d checks) ===" % checks_passed)
		quit(0)
	else:
		for f in failures:
			printerr("[FAILED] %s" % f)
		print("=== POWER-UP SMOKE TEST FAILED (%d/%d) ===" % [failures.size(), checks_total])
		quit(1)
