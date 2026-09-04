# BindingsSmokeTest.gd — InputHelper-backed action bindings (v2 remap).
#
# Verifies, with the REAL InputHelper addon mounted on /root:
#   1. set_key_binding replaces the primary key/mouse event live.
#   2. Conflict auto-swap: binding a taken key swaps the other action's
#      binding to the old key (InputHelper semantics).
#   3. save_bindings persists a blob; apply_saved_bindings restores it
#      into a fresh InputMap state.
#   4. reset_bindings returns every action to project defaults.
#   5. Legacy v1 pad-map dict migrates into a blob once.
#   6. Labels: key_binding_name/pad_binding_name reflect live remaps;
#      helperless fallbacks still resolve (raw-test mode).
#   7. set_pad_button legacy shim routes through InputHelper when present.
#
# Run: godot --headless --path . --script scripts/BindingsSmokeTest.gd
extends SceneTree

var checks := 0
var failures := 0

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  ok  %s" % label)
	else:
		failures += 1
		print("FAIL  %s" % label)

func feq(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var P: GDScript = load("res://scripts/InputPrefs.gd")
	var helper_script: GDScript = load("res://addons/input_helper/input_helper.gd")
	check(helper_script != null, "addon script loads")
	check(P != null, "InputPrefs loads")

	# Isolated cfg so the real save is never touched.
	P.CFG_PATH = "user://test_bindings.cfg"
	# Fresh file: wipe any prior run's keys.
	var fresh := ConfigFile.new()
	fresh.save(P.CFG_PATH)
	P.clear_cache()

	# With --path ., the REAL InputHelper autoload (project.godot) is live
	# in this SceneTree — verify InputPrefs resolves it. (Mounting a second
	# copy fails: add_child auto-renames on collision and get_node finds
	# the autoload, not ours.)
	await process_frame
	check(P._helper() != null, "real InputHelper autoload resolves via InputPrefs")

	# --- 1. key remap replaces the primary keyboard/mouse event ---------
	var space_ev := InputEventKey.new()
	space_ev.physical_keycode = KEY_SPACE
	var before_events := InputMap.action_get_events("boost")
	var had_space := false
	for ev in before_events:
		if ev is InputEventKey and ev.physical_keycode == KEY_SPACE:
			had_space = true
	check(had_space, "boost starts bound to SPACE")

	var w_ev := InputEventKey.new()
	w_ev.physical_keycode = KEY_W
	check(P.set_key_binding("boost", w_ev), "set_key_binding reports OK")
	var now_events := InputMap.action_get_events("boost")
	var has_w := false
	var still_has_space := false
	var kept_pad := false
	var kept_mouse := false
	for ev in now_events:
		if ev is InputEventKey and ev.physical_keycode == KEY_W:
			has_w = true
		if ev is InputEventKey and ev.physical_keycode == KEY_SPACE:
			still_has_space = true
		if ev is InputEventJoypadButton:
			kept_pad = true
		if ev is InputEventMouseButton:
			kept_mouse = true
	check(has_w, "boost now bound to W")
	check(not still_has_space, "old SPACE binding replaced (not duplicated)")
	check(kept_pad and kept_mouse, "joypad + mouse slots survive a key remap")

	# --- 2. conflict auto-swap ------------------------------------------
	# boost is on W now; bind action (default E) to W and expect the swap:
	# action keeps W, boost inherits E.
	var e_before: String = P.key_binding_name("action")
	var w2 := InputEventKey.new()
	w2.physical_keycode = KEY_W
	check(P.set_key_binding("action", w2), "conflicting bind reported OK")
	check(P.key_binding_name("action") == "W", "action took W")
	check(P.key_binding_name("boost") == "E", "boost auto-swapped to action's old key (E) (was %s)" % e_before)

	# --- 3. persist / restore round trip --------------------------------
	P.save_bindings()
	var blob: String = P.get_setting(P.KEY_BINDINGS, "")
	check(blob != "", "bindings blob persisted")
	check("\"boost\"" in blob and "\"action\"" in blob, "blob covers remappable actions")
	# Scrub the live InputMap back to project defaults, then restore.
	InputMap.load_from_project_settings()
	check(P.key_binding_name("boost") == "SPACE", "scrubbed InputMap back to defaults")
	P.apply_saved_bindings()
	check(P.key_binding_name("boost") == "E", "apply_saved_bindings restored the remap")
	check(P.key_binding_name("action") == "W", "restored action->W too")

	# --- 4. pad remap through the new path ------------------------------
	var rb := InputEventJoypadButton.new()
	rb.button_index = 10  # RB
	check(P.set_pad_binding("boost", rb), "set_pad_binding reports OK")
	var boost_pad: Array[InputEvent] = InputMap.action_get_events("boost").filter(
		func(ev): return ev is InputEventJoypadButton)
	check(boost_pad.size() == 1 and boost_pad[0].button_index == 10,
		"pad slot moved to RB (10)")
	check(P.pad_binding_name("boost") == P._helper().get_label_for_input(rb).to_upper(),
		"pad label self-consistent with InputHelper tables")

	# --- 5. legacy v1 dict migrates once --------------------------------
	var legacy := ConfigFile.new()
	legacy.set_value("input", "pad_button_map", {"boost": 9})
	legacy.save(P.CFG_PATH)
	P.clear_cache()
	# Simulate a fresh boot: defaults in InputMap, blob absent.
	InputMap.load_from_project_settings()
	# Erase the blob key by pointing at a fresh file (already done) and
	# re-resolve; apply path should migrate the dict into a blob.
	P.apply_saved_bindings()
	var migrated_blob: String = P.get_setting(P.KEY_BINDINGS, "")
	check(migrated_blob != "", "legacy dict produced a blob")
	var boost_pad2: Array[InputEvent] = InputMap.action_get_events("boost").filter(
		func(ev): return ev is InputEventJoypadButton)
	check(boost_pad2.size() >= 1 and boost_pad2[0].button_index == 9,
		"migrated boost pad binding = L1 (9)")

	# --- 6. reset restores project defaults ------------------------------
	P.reset_bindings()
	var reset_pad: Array[InputEvent] = InputMap.action_get_events("boost").filter(
		func(ev): return ev is InputEventJoypadButton)
	check(reset_pad.size() == 1 and reset_pad[0].button_index == 0,
		"reset_bindings restored boost pad default (A)")
	var reset_keys: Array[InputEvent] = InputMap.action_get_events("boost").filter(
		func(ev): return ev is InputEventKey or ev is InputEventMouseButton)
	var back_to_space := false
	for ev in reset_keys:
		if ev is InputEventKey and ev.physical_keycode == KEY_SPACE:
			back_to_space = true
	check(back_to_space, "reset_bindings restored SPACE")

	# --- 7. legacy set_pad_button shim routes through InputHelper --------
	P.set_pad_button("sabotage", 9)
	var sab_pad: Array[InputEvent] = InputMap.action_get_events("sabotage").filter(
		func(ev): return ev is InputEventJoypadButton)
	check(sab_pad.size() == 1 and sab_pad[0].button_index == 9,
		"legacy set_pad_button rewrote the live pad slot")
	var sab_keys: Array[InputEvent] = InputMap.action_get_events("sabotage").filter(
		func(ev): return ev is InputEventKey or ev is InputEventMouseButton)
	check(sab_keys.size() >= 1, "legacy shim kept keyboard slots")

	# --- 8. overlay/settings label helpers -------------------------------
	check(P.key_binding_name("boost") == "SPACE", "key_binding_name default SPACE")
	check(P.pad_button_name("sabotage") == P.pad_binding_name("sabotage"),
		"pad_button_name mirrors pad_binding_name")

	# --- cleanup ----------------------------------------------------------
	fresh.save(P.CFG_PATH)

	print("")
	print("Checks: %d  Failures: %d" % [checks, failures])
	if failures == 0 and checks > 0:
		print("PASS")
	else:
		print("FAIL")
	quit(1 if (failures > 0 or checks == 0) else 0)
