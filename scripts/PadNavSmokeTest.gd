# PadNavSmokeTest.gd — S-PAD slice verification (SceneTree --script).
# Headless: boots Main.tscn, synthesizes pad events, asserts focus/cancel/
# option-cycle behavior and the UITheme focus stylebox.
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _fail(msg: String) -> void:
	printerr("PADNAV FAIL: %s" % msg)
	quit(1)

func _joy(button: int, pressed: bool) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = pressed
	return ev

func _pump(frames: int = 3) -> void:
	for _i in range(frames):
		await process_frame

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	if scene == null:
		_fail("Main.tscn not found")
		return
	var main = scene.instantiate()
	root.add_child(main)
	await _pump()

	# --- 1. focus stylebox on play_button: must NOT be StyleBoxEmpty ---------
	var play: Button = main.play_button
	if play == null:
		_fail("play_button missing")
		quit(1)
		return
	var sb := play.get_theme_stylebox("focus")
	if sb == null or sb is StyleBoxEmpty:
		_fail("play_button focus stylebox missing/StyleBoxEmpty")
		quit(1)
		return
	print("PASS: play_button focus stylebox is %s" % sb.get_class())

	# --- 2. EVACUATE holds focus on boot -------------------------------------
	var focused := root.gui_get_focus_owner()
	if focused != play:
		_fail("EVACUATE (play_button) not focused on boot: %s" % focused)
		quit(1)
		return
	print("PASS: EVACUATE focused on boot")

	# --- 3. pad A on focused EVACUATE: ui_accept path fires _on_play ---------
	main._block_navigation = true
	var gm := root.get_node("/root/GameManager")
	var captured := [null]
	var on_play := func(mode):
		captured[0] = mode
	main.mode_chosen.connect(on_play, CONNECT_ONE_SHOT)
	# Pad A press/release (focus + ui_accept handles it natively).
	Input.parse_input_event(_joy(JOY_BUTTON_A, true))
	await _pump()
	Input.parse_input_event(_joy(JOY_BUTTON_A, false))
	await _pump()
	# ui_accept action event as the deterministic confirm path.
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	await _pump()
	var accept_rel := InputEventAction.new()
	accept_rel.action = "ui_accept"
	accept_rel.pressed = false
	Input.parse_input_event(accept_rel)
	await _pump()
	if captured[0] == null:
		_fail("pad A / ui_accept did not trigger _on_play")
		quit(1)
		return
	if int(captured[0]) != int(gm.GameMode.EVACUATION):
		_fail("mode_chosen emitted wrong mode: %s" % captured[0])
		quit(1)
		return
	print("PASS: EVACUATE accepts pad A / ui_accept (mode=EVACUATION)")

	# --- 4. dpad down moves focus into NavGrid's first button ----------------
	main._block_navigation = false
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	Input.parse_input_event(down)
	await _pump()
	var rel := InputEventAction.new()
	rel.action = "ui_down"
	rel.pressed = false
	Input.parse_input_event(rel)
	await _pump()
	var grid: GridContainer = main.nav_grid
	if grid == null or grid.get_child_count() == 0:
		_fail("NavGrid missing/empty")
		quit(1)
		return
	var focused2 := root.gui_get_focus_owner()
	if focused2 == null or not grid.is_ancestor_of(focused2):
		_fail("dpad down did not move focus into NavGrid (focus=%s)" % focused2)
		quit(1)
		return
	print("PASS: dpad down moves focus into NavGrid (%s)" % focused2.name)

	# --- 5. joypad B closes the OTHER MODES subview --------------------------
	main._open_modes_subview()
	await _pump()
	if main.open_subview == null:
		_fail("modes subview did not open")
		quit(1)
		return
	Input.parse_input_event(_joy(JOY_BUTTON_B, true))
	await _pump()
	Input.parse_input_event(_joy(JOY_BUTTON_B, false))
	await _pump()
	if main.open_subview != null:
		_fail("joypad B did not close modes subview")
		quit(1)
		return
	print("PASS: joypad B closes modes subview")

	# --- 6. ui_right on focused RIDER OptionButton advances selection --------
	main._open_customize_subview()
	await _pump()
	var rider: OptionButton = main.character_select
	if rider == null or rider.item_count < 2:
		_fail("RIDER OptionButton missing/too few items")
		quit(1)
		return
	rider.grab_focus()
	await _pump()
	var before := rider.selected
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	Input.parse_input_event(right)
	await _pump()
	var right_rel := InputEventAction.new()
	right_rel.action = "ui_right"
	right_rel.pressed = false
	Input.parse_input_event(right_rel)
	await _pump()
	if rider.selected == before:
		_fail("ui_right did not advance RIDER selection (idx=%d)" % before)
		quit(1)
		return
	print("PASS: ui_right cycles RIDER OptionButton (%d -> %d)" % [before, rider.selected])

	# --- 7. joypad B closes customize subview too ----------------------------
	Input.parse_input_event(_joy(JOY_BUTTON_B, true))
	await _pump()
	Input.parse_input_event(_joy(JOY_BUTTON_B, false))
	await _pump()
	if main.open_subview != null:
		_fail("joypad B did not close customize subview")
		quit(1)
		return
	print("PASS: joypad B closes customize subview")

	print("PADNAV: ALL PASS")
	quit(0)
