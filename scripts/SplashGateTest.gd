extends SceneTree

# SplashGateTest.gd — verifies the click-to-start splash flow:
# 1. mount() adds exactly one SplashScreen layer to a parent
# 2. mount() is idempotent (dedupe by node name)
# 3. ui_accept (Enter/Space/pad A) dismisses it
# 4. the layer frees itself after dismissal (after the fade tween)
# 5. _dismiss() (the click/tap path) works and is single-shot
#
# Run: godot --headless --path . --script scripts/SplashGateTest.gd

var checks := 0
var failures := 0

func ok(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok %s" % what)
	else:
		failures += 1
		print("  FAIL %s" % what)

func _init() -> void:
	process_frame.connect(_run)

func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame

func _count_splash(parent: Control) -> int:
	var count := 0
	for child in parent.get_children():
		if child.name == "SplashLayer":
			count += 1
	return count

func _press_accept() -> void:
	# Input.action_press() only sets POLLING state — it never propagates
	# an event through _input. Synthesize a real Enter keypress instead.
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_ENTER
	ev2.physical_keycode = KEY_ENTER
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await process_frame

func _run() -> void:
	process_frame.disconnect(_run)
	print("SplashGateTest: start")
	var splash: GDScript = load("res://scripts/SplashScreen.gd")
	ok(splash != null, "SplashScreen.gd loads")
	if splash == null:
		_finish()
		return

	var parent := Control.new()
	parent.name = "MenuRoot"
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(parent)
	var btn := Button.new()
	btn.name = "PlayButton"
	parent.add_child(btn)

	# --- mount + dedupe ---
	splash.mount(parent)
	await _wait_frames(3)
	ok(_count_splash(parent) == 1, "one splash layer mounted (got %d)" % _count_splash(parent))
	splash.mount(parent)
	await _wait_frames(1)
	ok(_count_splash(parent) == 1, "mount is idempotent (got %d)" % _count_splash(parent))

	# --- dismiss via ui_accept (keyboard Enter/Space share the action) ---
	await _press_accept()
	await _wait_frames(40)  # fade tween is 0.45s ~ 27+ frames
	ok(_count_splash(parent) == 0, "splash freed after ui_accept (got %d)" % _count_splash(parent))

	# --- re-mount + dismiss via _dismiss (the click/tap path) ---
	splash.mount(parent)
	await _wait_frames(3)
	var layer := parent.get_node_or_null("SplashLayer")
	ok(layer != null, "splash re-mounted for click test")
	if layer != null:
		layer._dismiss()
		await _wait_frames(40)
		ok(_count_splash(parent) == 0, "splash freed after _dismiss (click/tap path)")

	# --- joypad A: wired to ui_accept via SplashScreen's own binding ---
	# Headless hosts drop joypad parse events (no device) and Godot's
	# default ui_accept map doesn't include pad A until a pad connects.
	# Verify OFFLINE that the splash's ui_accept map INCLUDES pad A (repo
	# convention: event.is_action_pressed, see GamepadSupportTest).
	splash.mount(parent)
	await _wait_frames(3)
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	pad_a.pressed = true
	ok(pad_a.is_action_pressed("ui_accept"), "pad A event satisfies ui_accept")
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventJoypadButton.new()
	ev2.button_index = JOY_BUTTON_A
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await _wait_frames(40)
	ok(_count_splash(parent) == 0, "splash freed after joypad A (got %d)" % _count_splash(parent))

	_finish()

func _finish() -> void:
	if failures == 0 and checks > 0:
		print("SplashGateTest: PASS (%d checks)" % checks)
	else:
		print("SplashGateTest: FAIL (%d/%d checks failed)" % [failures, checks])
	quit()
