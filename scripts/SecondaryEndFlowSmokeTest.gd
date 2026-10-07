# SecondaryEndFlowSmokeTest.gd — PLAYTEST.md Session 5 end-of-round flow for
# the three secondary modes (Hauled, Shop & Seek, Pizza Colony).
#
# Regression guard over the Session 5 checklist: "All three secondary modes
# show PLAY AGAIN and MAIN MENU on both win and loss; mouse and controller
# input work, rematch resets the mode". For EACH mode we drive a WIN and a
# LOSS through the mode's own seams (mirroring HauledBehaviorsTest /
# ShopSeekSmokeTest patterns) and pin:
#   (a) the shared ModeResults end screen mounts on BOTH outcomes,
#   (b) PLAY AGAIN / MAIN MENU affordances exist, are visible and focusable,
#   (c) PLAY AGAIN actually reloads the mode (pristine state, full timer, no
#       stale results overlay) instead of leaking the ended round,
#   (d) the mode HUD is honest on the end screen (timer stopped; loss ends
#       read 0:00 and keep the loss reason).
# The ShopSeek guard-catch ladder is re-checked at the OVERLAY level (two
# strikes stay playable, the third ends the round); the flag-level ladder
# lives in ShopSeekSmokeTest and is intentionally not duplicated here.
# Run: godot --headless --path . --script scripts/SecondaryEndFlowSmokeTest.gd -- --test-mode
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

# ============================ harness ============================

func _mount(scene_path: String) -> Node:
	# PreMatchModal pauses the tree on mount — suppressed per instantiation.
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var mode: Node = (load(scene_path) as PackedScene).instantiate()
	root.add_child(mode)
	await process_frame
	await process_frame
	return mode

## Untyped on purpose: a successful PLAY AGAIN / MAIN MENU reload frees the
## old mode scene, and a freed instance may no longer be passed to a Node
## —typed parameter. The is_instance_valid guard makes teardown a no-op there.
func _teardown(mode) -> void:
	if current_scene == mode:
		current_scene = null
	if mode != null and is_instance_valid(mode):
		mode.queue_free()
	await process_frame

func _results_overlay(mode: Node) -> Node:
	for child in mode.get_children():
		if child is CanvasLayer and child.name == "ModeResults":
			return child
	return null

func _hud_label(mode: Node, prop: String) -> String:
	var hud = mode.get("mode_hud")
	if hud == null or not is_instance_valid(hud):
		return ""
	var lbl: Label = hud.get(prop)
	return lbl.text if lbl != null else ""

func _timer_text(mode: Node) -> String:
	return _hud_label(mode, "timer_label")

## The end screen must stop the mode's own clock: the HUD timer label may not
## move while the results are up (modes early-return their _process once
## match_over; a ticking label means stale simulation is still running).
func _timer_frozen(mode: Node) -> bool:
	var before := _timer_text(mode)
	await create_timer(1.2).timeout
	return before != "" and _timer_text(mode) == before

## Shared end-screen contract: mount + headline + win/loss title token +
## both affordances visible and controller-reachable.
func _end_screen_checks(mode: Node, overlay: Node, headline: String,
		outcome: String, won: bool) -> void:
	var tag := "%s %s" % [mode.name, outcome]
	check(overlay != null, "%s: results end screen mounts on %s" % [tag, outcome])
	if overlay == null:
		return
	var title := overlay.get("title_label") as Label
	check(title != null and title.text == headline,
		"%s: end screen headline reads \"%s\"" % [tag, headline])
	var UIT = load("res://scripts/UITheme.gd")
	var want: Color = UIT.color(UIT.LIME) if won else UIT.color(UIT.CORAL)
	check(title != null and title.get_theme_color("font_color").is_equal_approx(want),
		"%s: end screen title token marks %s" % [tag, "the win" if won else "the loss"])
	var rematch := overlay.get("rematch_button") as Button
	var menu := overlay.get("menu_button") as Button
	check(rematch != null and rematch.text == "PLAY AGAIN" and rematch.visible,
		"%s: PLAY AGAIN affordance is visible" % tag)
	check(menu != null and menu.text == "MAIN MENU" and menu.visible,
		"%s: MAIN MENU affordance is visible" % tag)
	check(rematch != null and rematch.focus_mode != Control.FOCUS_NONE,
		"%s: PLAY AGAIN is focusable (controller entry point)" % tag)

## Press PLAY AGAIN on the live end screen; the mode scene must reload as
## current_scene. Returns the fresh instance (null if the reload failed).
func _rematch_reloads(mode: Node, overlay: Node, tag: String) -> Node:
	var rematch := overlay.get("rematch_button") as Button
	if rematch == null:
		return null
	# The reloaded scene must skip its briefing modal (documented test seam).
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var scene_path: String = mode.scene_file_path
	current_scene = mode
	rematch.pressed.emit()
	var fresh: Node = null
	for i in range(600):
		await process_frame
		if current_scene != null and current_scene != mode \
				and current_scene.scene_file_path == scene_path:
			fresh = current_scene
			break
	check(fresh != null, "%s: PLAY AGAIN reloads the mode scene" % tag)
	check(not paused, "%s: rematch leaves the tree unpaused" % tag)
	if fresh != null:
		await process_frame
		await process_frame
	return fresh

func _fresh_has_no_results(fresh: Node, tag: String) -> void:
	check(not fresh.get("match_over"), "%s: reloaded match is live again" % tag)
	check(_results_overlay(fresh) == null,
		"%s: reload leaves no stale results overlay" % tag)

# ============================ drivers ============================

## Walk Hauled's own round ladder to the end panel. Win = positive total.
func _haul_to_end(mode: Node, win: bool) -> void:
	for r in range(mode.TOTAL_ROUNDS):
		mode._finish_round(250 if win else 0, "TEST ROUND", Color("a8ffbd"))
		if not mode.match_over:
			mode._next_round_timer = 0.01  # fast-forward the inter-round gap
			for i in range(30):
				await process_frame
				if mode.round_index == r + 1:
					break

## Collect Shop & Seek's full shopping list through the real pickup path.
func _shop_to_win(mode: Node) -> void:
	for prop in mode.get_tree().get_nodes_in_group("disguise_props").duplicate():
		if not is_instance_valid(prop) or mode.match_over:
			continue
		var label: String = prop.get_meta("kind", {}).get("label", "")
		if label in mode.list_items and not mode.list_collected.has(label):
			mode.player.global_position = prop.global_position
			mode._check_item_pickups()
	for i in range(8):
		await process_frame
		if mode.match_over:
			break

## Claim every pepperoni pad — Pizza Colony's win-by-domination path.
func _pizza_to_win(mode: Node) -> void:
	for p in mode.pepperonis:
		p["owner"] = &"player"
	for i in range(8):
		await process_frame
		if mode.match_over:
			break

# ============================ phases ============================

func _run_hauled() -> void:
	# ---------- WIN ----------
	var mode = await _mount("res://scenes/Hauled.tscn")
	await _haul_to_end(mode, true)
	await process_frame
	await process_frame
	var tag := "Hauled win"
	check(mode.match_over and mode.total_score > 0,
		"%s: three delivered rounds end the match as a win" % tag)
	var overlay := _results_overlay(mode)
	_end_screen_checks(mode, overlay, "SHIFT COMPLETE", "win", true)
	check(await _timer_frozen(mode), "%s: HUD timer is stopped on the end screen" % tag)
	if overlay != null:
		var fresh = await _rematch_reloads(mode, overlay, tag)
		if fresh != null:
			check(fresh.round_index == 0 and fresh.round_scores.is_empty(),
				"%s: reload resets the round ladder" % tag)
			check(is_zero_approx(fresh.total_score),
				"%s: reload resets the total score" % tag)
			check(fresh.remaining_time > fresh.ROUND_TIME - 1.0,
				"%s: reload restores the full round timer" % tag)
			_fresh_has_no_results(fresh, tag)
			await _teardown(fresh)
	await _teardown(mode)

	# ---------- LOSS ----------
	mode = await _mount("res://scenes/Hauled.tscn")
	await _haul_to_end(mode, false)
	await process_frame
	await process_frame
	tag = "Hauled loss"
	check(mode.match_over and is_zero_approx(mode.total_score),
		"%s: three zero-score rounds end the match empty-handed" % tag)
	overlay = _results_overlay(mode)
	_end_screen_checks(mode, overlay, "SHIFT COMPLETE", "loss", false)
	if overlay != null:
		var detail := (overlay.get("detail_label") as Label).text
		check(detail.contains("TOTAL SCORE  0"),
			"%s: end screen reports the zero total" % tag)
	check(_timer_text(mode).contains("0:00"), "%s: loss HUD timer reads 0:00" % tag)
	check(await _timer_frozen(mode), "%s: HUD timer is stopped on the end screen" % tag)
	await _teardown(mode)

func _run_shopseek() -> void:
	# ---------- WIN ----------
	var mode = await _mount("res://scenes/ShopSeek.tscn")
	await _shop_to_win(mode)
	await process_frame
	await process_frame
	var tag := "Shop & Seek win"
	check(mode.won and mode.match_over, "%s: the full list ends the round as a win" % tag)
	var overlay := _results_overlay(mode)
	_end_screen_checks(mode, overlay, "LIST COMPLETE — ESCAPED", "win", true)
	check(await _timer_frozen(mode), "%s: HUD timer is stopped on the end screen" % tag)
	if overlay != null:
		var fresh = await _rematch_reloads(mode, overlay, tag)
		if fresh != null:
			check(fresh.list_collected.is_empty(),
				"%s: reload empties the shopping list" % tag)
			check(fresh.caught_count == 0 and not fresh.failed and not fresh.won,
				"%s: reload resets strikes and outcome flags" % tag)
			check(fresh.remaining_time > fresh.ROUND_TIME - 1.0,
				"%s: reload restores the full 90s round timer" % tag)
			_fresh_has_no_results(fresh, tag)
			await _teardown(fresh)
	await _teardown(mode)

	# ---------- LOSS: the guard-catch ladder, judged at the overlay level ----------
	mode = await _mount("res://scenes/ShopSeek.tscn")
	tag = "Shop & Seek loss"
	mode._register_security_catch()
	mode.catch_grace_timer = 0.0
	mode._register_security_catch()
	check(not mode.match_over and mode.caught_count == 2,
		"%s: two security catches keep the shift alive" % tag)
	check(_results_overlay(mode) == null,
		"%s: no end screen while the round is still playable" % tag)
	mode.catch_grace_timer = 0.0
	mode._register_security_catch()
	await process_frame
	await process_frame
	check(mode.failed and mode.match_over, "%s: the third strike ends the shift" % tag)
	overlay = _results_overlay(mode)
	_end_screen_checks(mode, overlay, "THREE STRIKES — SHIFT OVER", "loss", false)
	check(_timer_text(mode).contains("0:00"), "%s: loss HUD timer reads 0:00" % tag)
	check(await _timer_frozen(mode), "%s: HUD timer is stopped on the end screen" % tag)
	# MAIN MENU affordance press (once, on a live end screen).
	if overlay != null:
		var menu := overlay.get("menu_button") as Button
		if menu != null:
			current_scene = mode
			menu.pressed.emit()
			var back := false
			for i in range(600):
				await process_frame
				if current_scene != null \
						and current_scene.scene_file_path == "res://scenes/Main.tscn":
					back = true
					break
			check(back, "%s: MAIN MENU returns to the main menu" % tag)
			if back:
				current_scene.queue_free()
				await process_frame
				current_scene = null
	await _teardown(mode)

func _run_pizza_colony() -> void:
	# ---------- WIN ----------
	var mode = await _mount("res://scenes/PizzaColony.tscn")
	await _pizza_to_win(mode)
	await process_frame
	await process_frame
	var tag := "Pizza Colony win"
	check(mode.won and mode.match_over,
		"%s: claiming every pepperoni ends the round as a win" % tag)
	var overlay := _results_overlay(mode)
	_end_screen_checks(mode, overlay, "SERVICE COMPLETE", "win", true)
	check(await _timer_frozen(mode), "%s: HUD timer is stopped on the end screen" % tag)
	if overlay != null:
		var fresh = await _rematch_reloads(mode, overlay, tag)
		if fresh != null:
			var unowned := true
			for p in fresh.pepperonis:
				if p["owner"] != &"none":
					unowned = false
			check(unowned, "%s: reload resets pepperoni ownership" % tag)
			check(fresh.cheese == 0 and fresh.toppings == 0,
				"%s: reload zeroes the economy" % tag)
			check(not fresh.eliminated and fresh.remaining_time > fresh.ROUND_TIME - 1.0,
				"%s: reload restores a live, fully-timed colony" % tag)
			_fresh_has_no_results(fresh, tag)
			await _teardown(fresh)
	await _teardown(mode)

	# ---------- LOSS: launched off the pizza ----------
	mode = await _mount("res://scenes/PizzaColony.tscn")
	tag = "Pizza Colony loss"
	mode.player.global_position = Vector3(40.0, 1.0, 0.0)  # beyond the rim
	for i in range(30):
		await process_frame
		if mode.match_over:
			break
	check(mode.eliminated and mode.match_over,
		"%s: falling off the pizza eliminates and ends the round" % tag)
	overlay = _results_overlay(mode)
	_end_screen_checks(mode, overlay, "SERVICE FAILED", "loss", false)
	# End-of-round HUD honesty: the elimination must OWN the HUD in its end
	# state (0:00 + the loss reason), and _update_hud must not clobber it in
	# the same frame.
	check(_timer_text(mode).contains("0:00"),
		"%s: loss HUD timer reads 0:00" % tag)
	check(_hud_label(mode, "status_label").contains("LAUNCHED OFF THE PIZZA"),
		"%s: loss HUD keeps the loss reason" % tag)
	check(await _timer_frozen(mode), "%s: HUD timer is stopped on the end screen" % tag)
	await _teardown(mode)

# ============================ entry ============================

func _run() -> void:
	await _run_hauled()
	await _run_shopseek()
	await _run_pizza_colony()
	if failures.is_empty():
		print("SecondaryEndFlowSmokeTest: %d/%d checks passed" % [passed, checks])
		quit(0)
	else:
		printerr("SecondaryEndFlowSmokeTest: %d/%d checks failed — %s"
			% [failures.size(), checks, ", ".join(failures)])
		quit(1)
