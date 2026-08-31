# ShopSeekSmokeTest.gd — Phase 6B supermarket hide & seek verification.
# Instantiates the real scene and verifies: store layout, 20+ disguise
# props, list/prop pickup loop, disguise entry/exit with freeze + slowdown +
# wobble, guard patrol + stun, scan cooldown scaffolding, and win/fail flow.
extends SceneTree

var checks := 0
var passed := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed = load("res://scenes/ShopSeek.tscn")
	check(packed != null, "ShopSeek scene resource loads")
	if packed == null:
		_report()
		return
	# PreMatchModal pauses the tree on mount — suppressed for this harness.
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var mode: Node3D = packed.instantiate()
	root.add_child(mode)
	await process_frame
	await process_frame

	# --- layout ---
	check(mode.player != null and is_instance_valid(mode.player), "shopper chair spawned")
	check(mode.guard != null and is_instance_valid(mode.guard), "security guard patrols")
	check(mode.guard_path.size() >= 4, "guard has a patrol loop (%d waypoints)" % mode.guard_path.size())
	var prop_count: int = mode.get_tree().get_nodes_in_group("disguise_props").size()
	check(prop_count >= 20, "20+ disguise props placed (%d)" % prop_count)
	var shelf_count := 0
	for child in mode.get_children():
		if child is StaticBody3D:
			for sub in child.get_children():
				if sub is CollisionShape3D and sub.shape is BoxShape3D and (sub.shape as BoxShape3D).size.x > 10.0:
					shelf_count += 1
					break
	check(shelf_count >= 12, "aisle shelves built (%d long shelves)" % shelf_count)

	# --- shopper list loop ---
	check(mode.list_items.size() == mode.list_target, "shopping list has %d items" % mode.list_target)
	check(mode.list_collected.is_empty(), "list starts empty")
	# Simulate collecting every listed prop by walking pickup logic directly.
	for prop in mode.get_tree().get_nodes_in_group("disguise_props").duplicate():
		if not is_instance_valid(prop):
			continue
		var label: String = prop.get_meta("kind", {}).get("label", "")
		if label in mode.list_items and not mode.list_collected.has(label):
			mode.player.global_position = prop.global_position
			mode._check_item_pickups()
	check(mode.list_collected.size() == mode.list_target, "proximity pickups collect the full list (%d/%d)" % [mode.list_collected.size(), mode.list_target])
	# _process only evaluates the win when the timer ticks; settle a frame.
	for i in 3:
		await process_frame
	check(mode.won and mode.match_over, "full list wins the round")

	# --- disguise flow (fresh round state) ---
	mode.won = false
	mode.match_over = false
	mode.list_collected.clear()
	var prop: Node3D = mode.get_tree().get_nodes_in_group("disguise_props")[0]
	mode.player.global_position = prop.global_position
	mode._try_interact()
	check(mode.disguised, "E near a prop disguises the chair")
	check(mode.disguise_node != null and is_instance_valid(mode.disguise_node), "disguise mesh replaces the chair model")
	check(not mode.player.model_parent.visible, "chair model hidden while disguised")
	check(mode.disguise_freeze_timer > 0.0, "disguise starts with 2s freeze")
	check(is_equal_approx(mode.player.carry_slowdown, mode.DISGUISE_SPEED), "disguise applies 50% speed cap")
	# wobble tell
	var before_wobble: Vector3 = mode.disguise_node.scale
	for i in 30:
		await process_frame
	check(mode.disguise_node.scale != before_wobble, "disguise wobbles (the tell)")
	# Headless frames run uncapped (~8ms each); fast-forward the freeze
	# instead of waiting ~250 frames for the full 2 seconds.
	mode.disguise_freeze_timer = 0.05
	for i in 10:
		await process_frame
	check(mode.disguise_freeze_timer <= 0.0 and mode.player.can_move, "movement restores after freeze")
	mode._try_interact()
	check(not mode.disguised, "E again undisguises")
	check(mode.player.model_parent.visible and is_equal_approx(mode.player.carry_slowdown, 1.0), "undisguise restores model and speed")

	# --- guard stun ---
	var gs_before: float = mode.player.is_stunned
	mode.player.global_position = mode.guard.global_position
	for i in 20:
		await process_frame
	check(mode.player.is_stunned > 0.0 or gs_before > 0.0, "touching the guard stuns the shopper")

	# --- scan scaffolding ---
	check(mode.role == &"shopper", "single-player default role is shopper")
	check(mode.try_scan() == false, "scan is seeker-only in the fallback round")
	mode.role = &"seeker"
	check(mode.try_scan() == true, "seeker scan fires")
	check(mode.try_scan() == false, "scan obeys cooldown")

	# --- fail flow ---
	mode.role = &"shopper"
	mode.match_over = false
	mode.remaining_time = 0.05
	for i in 10:
		await process_frame
	check(mode.failed and mode.match_over, "time-up fails the round")

	mode.queue_free()
	await process_frame
	_report()

func _report() -> void:
	if failures.is_empty():
		print("=== SHOPSEEK SMOKE TEST PASSED (%d checks) ===" % passed)
		quit(0)
	else:
		printerr("=== SHOPSEEK SMOKE TEST FAILED (%d/%d) ===" % [failures.size(), checks])
		quit(1)
