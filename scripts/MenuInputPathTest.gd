# MenuInputPathTest.gd — P1A menu input-path contract (resumed by parent on main).
#
# MenuDepartureSmokeTest drives buttons via Button.pressed.emit(), which cannot
# catch input interception: an overlapping Control, a full-rect scrim, or a
# broken focus path all stay invisible to .emit(). This suite exercises the
# REAL input routes instead:
#   1. Mouse hover lands on EVACUATE (proves visible + top-most at that point).
#   2. Real mouse press/release at its rect center selects Evacuation.
#   3. ui_accept activates the focused secondary action (keyboard path).
#   4. A real Escape KEY event closes the open subview layer.
#   5. Clicking where a HIDDEN control sits must not activate it.
#   6. The subview BACK button works via a real click, focus restored.
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

func _center(ctrl: Control) -> Vector2:
	return ctrl.get_global_rect().get_center()

func _mouse_move(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)

func _click(pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	release.global_position = pos
	Input.parse_input_event(release)

func _key(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventKey.new()
	up.physical_keycode = keycode
	up.keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)

func _run() -> void:
	var packed := load("res://scenes/Main.tscn")
	var win := root.get_window()
	win.size = Vector2i(1280, 720)
	win.content_scale_size = Vector2i(1280, 720)
	var gm = root.get_node("/root/GameManager")
	var main = packed.instantiate()
	main._block_navigation = true
	root.add_child(main)
	for i in 8:
		await process_frame

	# ---- 1+2. Real mouse path to EVACUATE ---------------------------------
	var target: Vector2 = _center(main.play_button)
	_mouse_move(target)
	await process_frame
	await process_frame
	var hovered: Control = main.get_viewport().gui_get_hovered_control()
	check(hovered == main.play_button,
		"hover at EVACUATE rect center lands on EVACUATE (got %s)" % [hovered])
	gm.selected_mode = GameManager.GameMode.HAULED
	await _click(target)
	for i in 3:
		await process_frame
	check(gm.selected_mode == GameManager.GameMode.EVACUATION,
		"real mouse click on EVACUATE selects Evacuation")

	# ---- 3. Keyboard path: ui_accept activates the focused action ---------
	main.play_button.release_focus()
	main.other_modes_button.grab_focus()
	await process_frame
	check(main.get_viewport().gui_get_focus_owner() == main.other_modes_button,
		"OTHER MODES holds focus before keyboard activation")
	await _key(KEY_ENTER)
	for i in 3:
		await process_frame
	check(main.modes_subview.visible,
		"real Enter keypress opens the focused OTHER MODES subview")

	# ---- 4. Real Escape key closes the layer -------------------------------
	await _key(KEY_ESCAPE)
	for i in 3:
		await process_frame
	check(not main.modes_subview.visible, "real Escape keypress closes the subview")
	check(main.scroll.visible, "home column restored after Escape")
	check(main.get_viewport().gui_get_focus_owner() == main.other_modes_button,
		"focus restored to the opening control after Escape")

	# ---- 5. Hidden control must not activate ------------------------------
	main.office_button.pressed.emit()
	await process_frame
	check(main.office_subview.visible and not main.scroll.visible,
		"office subview open with home column hidden")
	gm.selected_mode = GameManager.GameMode.HAULED
	# EVACUATE is hidden now; a click at its old rect center must NOT select it.
	await _click(target)
	for i in 3:
		await process_frame
	check(gm.selected_mode == GameManager.GameMode.HAULED,
		"click at the hidden EVACUATE position does not activate it")
	main._close_subview()
	await process_frame
	check(not main.office_subview.visible, "office subview closes for cleanup")

	# ---- 6. Subview BACK via a real click, focus restored ------------------
	main.other_modes_button.pressed.emit()
	await process_frame
	var back_btn: Button = main.modes_subview.get_meta("back_button")
	var back_center: Vector2 = _center(back_btn)
	_mouse_move(back_center)
	await process_frame
	var hovered_back: Control = main.get_viewport().gui_get_hovered_control()
	check(back_btn.is_ancestor_of(hovered_back) or hovered_back == back_btn,
		"hover at BACK rect center lands on BACK (got %s)" % [hovered_back])
	await _click(back_center)
	for i in 3:
		await process_frame
	check(not main.modes_subview.visible, "real mouse click on BACK closes the subview")
	check(main.get_viewport().gui_get_focus_owner() == main.other_modes_button,
		"focus restored after real BACK click")

	main.queue_free()
	await process_frame

	if failures.is_empty() and checks_total > 0:
		print("=== MENU INPUT PATH TEST PASS (%d/%d) ===" % [checks_passed, checks_total])
		quit(0)
	else:
		print("=== MENU INPUT PATH TEST FAILED (%d/%d) ===" % [checks_passed, checks_total])
		for f in failures:
			print("  - %s" % f)
		quit(1)
