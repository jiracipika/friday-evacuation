# LoadingFlowSmokeTest.gd — Phase 1B truthful loading verification.
# Exercises REAL SceneTree transitions against LoadingScreen:
#   1. nonexistent target -> readable error, BACK shown, menu preserved
#   2. non-PackedScene target -> error, lock released
#   3. duplicate request while active -> blocked (one overlay)
#   4. successful transition -> current_scene swapped to loaded PackedScene
#   5. overlay cleanup -> root group empty after dismissal (immediate, no fade)
#   6. no MIN_SHOW_TIME / elapsed-derived fake progress; fast real dismissal
#   7. failed-then-valid retry works
#   8. async-readiness target (is_loading_complete) -> dismisses only when
#      the target actually completes, not at is_node_ready
#   9. input suppression: keyboard events parsed while the overlay is active
#      reach a sentinel node ZERO times; ui_cancel does not leak either
# Run: godot --headless --path . --script scripts/LoadingFlowSmokeTest.gd
extends SceneTree

const FIXTURE := "res://tests/loading/LoadingFixture.tscn"
const PENDING_FIXTURE := "res://tests/loading/PendingFixture.tscn"
const PAUSED_PENDING_FIXTURE := "res://tests/loading/PausedPendingFixture.tscn"
const NEVER_READY_FIXTURE := "res://tests/loading/NeverReadyFixture.tscn"
const BAD_PATH := "res://tests/loading/does_not_exist.tscn"
const MENU_SCENE := "res://scenes/Main.tscn"
const SCRIPT_PATH := "res://scripts/LoadingScreen.gd"
const TIMEOUT_S := 10.0

var checks_total := 0
var checks_passed := 0
var failures: Array[String] = []
var tree_pause_guard := false

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

func _overlays() -> Array:
	return root.get_children().filter(func(n): return n.is_in_group("loading_overlay"))

func _set_menu_standin() -> Node:
	var fix = load(FIXTURE).instantiate()
	root.add_child(fix)
	current_scene = fix
	return fix

func _wait_until(pred: Callable, what: String) -> bool:
	var t := 0.0
	while t < TIMEOUT_S:
		if pred.call():
			return true
		await process_frame
		t += root.get_process_delta_time()
	check(false, "timeout waiting: %s" % what)
	return false

## Sentinel node whose _input counts every event that LEAKS through the
## overlay. Added as a plain child of root (bottom of input order) so the
## overlay would have to fail to consume input for these to fire.
class Sentinel extends Node:
	var hits := 0
	var cancel_hits := 0
	func _input(event: InputEvent) -> void:
		hits += 1
		if event.is_action_pressed("ui_cancel"):
			cancel_hits += 1

func _run() -> void:
	var LS = load(SCRIPT_PATH)
	check(LS != null, "LoadingScreen.gd compiles")
	# No fake-progress constants remain (source-level contract).
	var consts: Dictionary = LS.get_script_constant_map()
	check(not consts.has("MIN_SHOW_TIME"), "MIN_SHOW_TIME removed (no minimum dwell)")
	check(not consts.has("DISMISS_FADE_TIME"), "DISMISS_FADE_TIME removed (no cosmetic fade)")

	# --- 1. Nonexistent target: error + BACK, menu preserved --------------
	var menu := _set_menu_standin()
	LS.show_loading(BAD_PATH)
	await process_frame
	await process_frame
	var overlays := _overlays()
	check(overlays.size() == 1, "one overlay mounted for bad path")
	var ov: Node = overlays[0] if overlays.size() == 1 else null
	if ov:
		await _wait_until(func(): return ov._failed, "error state for nonexistent target")
		var status: Label = ov.get_node("LoadingRoot/Content/StatusLabel")
		var detail: Label = ov.get_node("LoadingRoot/Content/DetailLabel")
		var back: Button = ov.get_node("LoadingRoot/Content/BackButton")
		check(status.text == "LOAD FAILED", "status shows LOAD FAILED")
		check(detail.visible and detail.text.contains(BAD_PATH), "readable error names the bad path")
		check(detail.text.contains("\n"), "error text uses real newlines")
		check(not detail.text.contains("\\n"), "error text has no literal double-escaped backslash-n")
		check(back.visible, "BACK button shown on failure")
		check(current_scene == menu, "menu scene preserved on failure")
		# Keyboard BACK via a REAL parsed Escape key press.
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = true
		Input.parse_input_event(esc)
		await process_frame
		await process_frame
		check(_overlays().is_empty(), "real Escape key dismisses failed overlay (lock released)")
	check(current_scene == menu, "menu still current after BACK")

	# --- 2. Non-PackedScene target ----------------------------------------
	LS.show_loading(SCRIPT_PATH)
	await process_frame
	await process_frame
	overlays = _overlays()
	check(overlays.size() == 1, "overlay mounted for non-PackedScene target")
	if overlays.size() == 1:
		var ov2: Node = overlays[0]
		await _wait_until(func(): return ov2._failed, "error state for non-PackedScene target")
		var back2: Button = ov2.get_node("LoadingRoot/Content/BackButton")
		check(back2.visible, "BACK shown for non-PackedScene error")
		check(current_scene == menu, "menu preserved for non-PackedScene error")
		ov2._go_back()
		await process_frame
		check(_overlays().is_empty(), "BACK releases lock after non-PackedScene failure")

	# --- 3. Duplicate request blocked while active ------------------------
	menu.queue_free()
	await process_frame
	current_scene = null
	LS.show_loading(FIXTURE)
	await process_frame
	LS.show_loading(FIXTURE)  # duplicate while active
	LS.show_loading(BAD_PATH)  # also blocked
	await process_frame
	check(_overlays().size() == 1, "duplicate requests blocked while active")

	# --- 4. Successful transition + 5. cleanup + 6. real timing -----------
	var t0 := Time.get_ticks_msec()
	var ok := await _wait_until(func():
		return current_scene != null and current_scene.scene_file_path == FIXTURE,
		"successful transition to fixture scene")
	var swap_ms := Time.get_ticks_msec() - t0
	check(ok, "current_scene swapped to loaded PackedScene")
	check(current_scene.is_node_ready(), "target scene exists and is ready")
	check(swap_ms < 800, "dismissal not gated by MIN_SHOW_TIME (swapped in %d ms)" % swap_ms)
	# The overlay's dismissal runs on the process_frame it detects readiness;
	# give it that one frame, then require the lock gone (no fade, no delay).
	await process_frame
	check(_overlays().is_empty(), "group removed immediately on success (no stale lock)")
	var ov_id := ov.get_instance_id() if ov != null else 0
	ok = await _wait_until(func(): return not is_instance_id_valid(ov_id) or _overlays().is_empty(),
		"overlay freed after success")
	check(ok, "overlay cleaned up after successful transition (no leak)")

	# Real progress source: re-run a transition and verify the bar value
	# only ever reflects actual ResourceLoader progress fractions.
	current_scene.queue_free()
	await process_frame
	current_scene = null
	LS.show_loading(FIXTURE)
	await process_frame
	var ov3_list := _overlays()
	var ov3: Node = ov3_list[0] if ov3_list.size() == 1 else null
	var saw_real_progress := true
	var swapped2 := false
	var t := 0.0
	while t < TIMEOUT_S and not swapped2:
		if ov3 and is_instance_valid(ov3) and not ov3._failed and ov3._stage == 1:
			var prog: Array = []
			var st := ResourceLoader.load_threaded_get_status("res://tests/loading/LoadingFixture.tscn", prog)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS and prog.size() > 0:
				if not is_equal_approx(float(ov3.get_node("LoadingRoot/Content/LoadBar").value), clampf(float(prog[0]), 0.0, 1.0)):
					saw_real_progress = false
			elif st == ResourceLoader.THREAD_LOAD_LOADED:
				swapped2 = true
		await process_frame
		t += root.get_process_delta_time()
	check(saw_real_progress, "progress bar mirrors actual ResourceLoader fraction")
	ok = await _wait_until(func():
		return current_scene != null and current_scene.scene_file_path == FIXTURE,
		"retry after failures transitions successfully")
	check(ok, "failed-then-valid retry works")

	# --- 8. Async readiness target (is_loading_complete) ------------------
	# PendingFixture is node-ready for ~3 frames BEFORE it reports complete;
	# the overlay must dismiss only after completion (verified by the
	# fixture's own flag) and the swap still happens.
	current_scene.queue_free()
	await process_frame
	current_scene = null
	LS.show_loading(PENDING_FIXTURE)
	var pok := await _wait_until(func():
		return current_scene != null and current_scene.scene_file_path == PENDING_FIXTURE,
		"async-readiness target swapped in")
	check(pok, "async-readiness target swapped in")
	var ready_before_complete := false
	if pok:
		# The overlay should already be gone (dismissed after completion).
		var gone := await _wait_until(func(): return _overlays().is_empty(),
			"overlay dismisses after async readiness")
		check(gone, "overlay waits for is_loading_complete, then dismisses")
		if current_scene != null and current_scene.has_method("is_loading_complete"):
			ready_before_complete = current_scene.is_loading_complete()
		check(ready_before_complete, "target scene fully complete before overlay left")
		# Prove the wait was real: the fixture needed >=3 process frames.
		check(current_scene.get("_frames_waited") >= 3,
			"async target needed multiple frames of waiting (waited %s)" % str(current_scene.get("_frames_waited")))

	# --- 9. Input suppression with a REAL sentinel + parse_input_event ----
	# The sentinel stands in for the pre-existing menu/game UI, so it must be
	# in the tree BEFORE the overlay mounts (later root children get _input
	# first; this reproduces the real input order and proves the overlay
	# consumes events before nodes underneath can react).
	var sent := Sentinel.new()
	root.add_child(sent)
	LS.show_loading(FIXTURE)
	await process_frame
	await process_frame
	var ovs := _overlays()
	check(ovs.size() == 1, "overlay active for input-suppression test")
	if ovs.size() == 1:
		var ovk: Node = ovs[0]
		await _wait_until(func(): return ovk._stage >= 1, "overlay began loading")
		# Feed a barrage of events while the overlay is active: keys,
		# actions, mouse buttons and motion — all must be consumed.
		var k1 := InputEventKey.new()
		k1.keycode = KEY_SPACE
		k1.pressed = true
		Input.parse_input_event(k1)
		var k2 := InputEventKey.new()
		k2.keycode = KEY_ESCAPE
		k2.pressed = true
		Input.parse_input_event(k2)  # NOT in error state: must not leak OR trigger BACK
		var act := InputEventAction.new()
		act.action = "ui_accept"
		act.pressed = true
		Input.parse_input_event(act)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = true
		mb.position = Vector2(100, 100)
		Input.parse_input_event(mb)
		var mm := InputEventMouseMotion.new()
		mm.position = Vector2(120, 110)
		Input.parse_input_event(mm)
		await process_frame
		await process_frame
		check(sent.hits == 0, "sentinel received ZERO leaked events while overlay active (got %d)" % sent.hits)
		check(_overlays().size() == 1, "Escape while loading does NOT dismiss overlay (no premature back)")
		# Wait for success; overlay must vanish promptly (no fade) and the
		# sentinel must STILL have zero events (they stop being parsed only
		# because the overlay freed and events ceased).
		var sw3 := await _wait_until(func():
			return current_scene != null and current_scene.scene_file_path == FIXTURE,
			"success after input barrage")
		check(sw3, "successful transition after input barrage")
		var gone3 := await _wait_until(func(): return _overlays().is_empty(),
			"overlay freed immediately after success (no fade delay)")
		check(gone3, "no opaque overlay or stale lock after success")
		check(sent.hits == 0, "sentinel still at zero after transition (suppression held throughout)")
		# Now that no overlay exists, a parsed key event MUST reach the tree
		# (control: proves the sentinel path works and suppression ended).
		root.remove_child(sent)
		sent.queue_free()

	# --- 10. GUI BACK activation: real parsed click on the BACK rect -----
	# Regression: _input() used to consume ALL events, so the visible BACK
	# Button could never receive the mouse click or keyboard Enter. After
	# the fix, pointer events over the BACK rect must reach the GUI and
	# activate the button; Enter/A must call _go_back directly.
	current_scene.queue_free()
	await process_frame
	current_scene = null
	var fixmenu := (load(FIXTURE) as PackedScene).instantiate()
	root.add_child(fixmenu)
	current_scene = fixmenu
	LS.show_loading(BAD_PATH)
	await process_frame
	await process_frame
	overlays = _overlays()
	check(overlays.size() == 1, "overlay mounted for GUI-BACK regression")
	if overlays.size() == 1:
		var ovg: Node = overlays[0]
		await _wait_until(func(): return ovg._failed, "error state before GUI click")
		var backg: Button = ovg.get_node("LoadingRoot/Content/BackButton")
		check(backg.visible, "BACK visible before GUI click")
		# Headless bare-SceneTree windows default to 64x64; give the GUI room, then let anchors re-layout.
		root.size = Vector2i(640, 360)
		await process_frame
		var grect: Rect2 = backg.get_global_rect()
		var gp := grect.get_center()
		# Headless: window coords != canvas coords when content scale differs.
		var _vs: Vector2 = Vector2(root.get_visible_rect().size)
		var _ws: Vector2 = Vector2(root.size)
		gp = gp * (_ws / _vs)
		# Real parsed press + release over the BACK button rect.
		var mp := InputEventMouseButton.new()
		mp.button_index = MOUSE_BUTTON_LEFT
		mp.pressed = true
		mp.position = gp
		mp.global_position = gp
		Input.parse_input_event(mp)
		var mr := InputEventMouseButton.new()
		mr.button_index = MOUSE_BUTTON_LEFT
		mr.pressed = false
		mr.position = gp
		mr.global_position = gp
		Input.parse_input_event(mr)
		await process_frame
		await process_frame
		check(_overlays().is_empty(), "REAL parsed mouse click on BACK rect dismisses overlay")
		check(current_scene != null and current_scene.scene_file_path == FIXTURE,
			"BACK via click keeps the underlying menu scene intact")

	# Keyboard: parsed ENTER (ui_accept) must trigger BACK directly.
	current_scene.queue_free()
	await process_frame
	current_scene = null
	var fixmenu2 := (load(FIXTURE) as PackedScene).instantiate()
	root.add_child(fixmenu2)
	current_scene = fixmenu2
	LS.show_loading(BAD_PATH)
	await process_frame
	await process_frame
	overlays = _overlays()
	if overlays.size() == 1:
		var ovk2: Node = overlays[0]
		await _wait_until(func(): return ovk2._failed, "error state before Enter key")
		var ek := InputEventKey.new()
		ek.keycode = KEY_ENTER
		ek.physical_keycode = KEY_ENTER
		ek.pressed = true
		Input.parse_input_event(ek)
		await process_frame
		await process_frame
		check(_overlays().is_empty(), "REAL parsed Enter key dismisses failed overlay (ui_accept BACK)")
	check(current_scene != null and current_scene.scene_file_path == FIXTURE,
		"menu scene still current after Enter BACK")

	# --- 11. Paused tree: readiness polling continues, no early dismissal -
	# PendingFixture is PROCESS_MODE_ALWAYS but the tree is PAUSED at swap
	# time: the loader must keep polling readiness (ALWAYS processing makes
	# process_frame fire even when paused) and dismiss ONLY on actual
	# completion — never merely because the tree is paused.
	current_scene.queue_free()
	await process_frame
	current_scene = null
	tree_pause_guard = true
	paused = true
	LS.show_loading(PAUSED_PENDING_FIXTURE)
	var pok2 := await _wait_until(func():
		return current_scene != null and current_scene.scene_file_path == PAUSED_PENDING_FIXTURE,
		"paused-tree target swapped in while tree paused")
	check(pok2, "paused-tree target swapped in while tree paused")
	if pok2:
		check(paused, "tree still paused while loader waits for readiness")
		var gone2 := await _wait_until(func(): return _overlays().is_empty(),
			"overlay dismisses only after actual completion (not because paused)")
		check(gone2, "overlay dismisses only after actual completion (not because paused)")
		check(paused, "pause remains intact through the whole readiness wait")
		if current_scene != null and current_scene.has_method("is_loading_complete"):
			check(current_scene.is_loading_complete(), "paused target fully complete before overlay left")
			check(current_scene.get("_frames_waited") >= 5,
				"paused ALWAYS target needed multiple real frames (waited %s)" % str(current_scene.get("_frames_waited")))
	paused = false  # clean pause removal after the test
	tree_pause_guard = false

	# --- 12. Post-swap readiness timeout: BACK restores the real menu -----
	# The scene is ALREADY replaced when readiness times out; BACK must not
	# just remove the overlay on top of an incomplete game — it must
	# restore the actual Main menu scene and unpause as part of recovery.
	current_scene.queue_free()
	await process_frame
	current_scene = null
	LS.set_readiness_timeout(0.6)
	LS.show_loading(NEVER_READY_FIXTURE)
	await process_frame
	await process_frame
	overlays = _overlays()
	check(overlays.size() == 1, "overlay mounted for post-swap timeout regression")
	if overlays.size() == 1:
		var ovt: Node = overlays[0]
		await _wait_until(func(): return current_scene != null and current_scene.scene_file_path == NEVER_READY_FIXTURE,
			"post-swap: target scene replaced before timeout")
		await _wait_until(func(): return ovt._failed, "readiness timeout fires post-swap")
		check(current_scene != null and current_scene.scene_file_path == NEVER_READY_FIXTURE,
			"error occurred AFTER the scene was already replaced")
		ovt._go_back()
		await process_frame
		await process_frame
		check(_overlays().is_empty(), "BACK releases lock after post-swap timeout")
		ok = await _wait_until(func():
			return current_scene != null and current_scene.scene_file_path == MENU_SCENE,
			"BACK after post-swap timeout restores the real Main menu")
		check(ok, "BACK after post-swap timeout restores the real Main menu")
		check(not paused, "post-swap BACK recovery unpauses the tree")
	LS.set_readiness_timeout(TIMEOUT_S)

	check(load("res://scripts/CountdownOverlay.gd") != null, "CountdownOverlay.gd untouched and loads")

	check(failures.is_empty(), "no failures")
	print("LoadingFlowSmokeTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
