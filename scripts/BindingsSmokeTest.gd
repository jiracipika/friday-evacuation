# BindingsSmokeTest.gd — action bindings (v2 physical-faithful format).
#
# Verifies, with the REAL InputHelper autoload live (or its absence in raw
# runs):
#   1. set_key_binding replaces the primary key/mouse slot live.
#   2. Conflict swaps are FENCED to the five remappable actions — the
#      movement actions' keys can never be stolen (regression: binding
#      boost to W used to hand move_forward's W to boost).
#   3. save/restore preserves PHYSICAL keycodes (non-QWERTY layouts keep
#      working after restart; upstream's v1 serializer loses them).
#   4. A corrupt blob is discarded with defaults kept — no crash, no
#      lost bindings (upstream JSON parse used to crash the boot path).
#   5. Legacy v1 pad dict migrates into a blob once and is cleared.
#   6. reset returns every action to project defaults.
#   7. Legacy set_pad_button shim keeps working.
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

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var P: GDScript = load("res://scripts/InputPrefs.gd")
	check(P != null, "InputPrefs loads")

	# Isolated cfg so the real save is never touched.
	P.CFG_PATH = "user://test_bindings.cfg"
	var fresh := ConfigFile.new()
	fresh.save(P.CFG_PATH)
	P.clear_cache()

	# With --path ., autoloads from project.godot are live in this tree.
	await process_frame
	check(P._helper() != null, "InputHelper resolves via InputPrefs")

	# --- 1. key remap replaces the primary keyboard/mouse slot ----------
	var had_space := false
	for ev in InputMap.action_get_events("boost"):
		if ev is InputEventKey and ev.physical_keycode == KEY_SPACE:
			had_space = true
	check(had_space, "boost starts bound to SPACE")

	var w_ev := InputEventKey.new()
	w_ev.physical_keycode = KEY_W
	check(P.set_key_binding("boost", w_ev), "set_key_binding reports OK")
	var has_w := false
	var still_has_space := false
	var kept_pad := false
	var kept_mouse := false
	for ev in InputMap.action_get_events("boost"):
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

	# --- 2. FENCED conflict swap: movement keys are untouchable ---------
	# boost is on W; bind action (default E) to W and expect a swap between
	# the two REMAPPABLE actions only.
	check(P.set_key_binding("action", w_ev), "conflicting bind reported OK")
	check(P.key_binding_name("action") == "W", "action took W")
	check(P.key_binding_name("boost") == "E", "boost auto-swapped to action's old key (E)")

	# THE REGRESSION: binding boost directly onto move_forward's W must
	# NOT remove W from move_forward (upstream swap used to steal it).
	InputMap.load_from_project_settings()
	P.clear_cache()
	var w2 := InputEventKey.new()
	w2.physical_keycode = KEY_W
	check(P.set_key_binding("boost", w2), "boost->W bind reported OK")
	var mf_has_w := false
	for ev in InputMap.action_get_events("move_forward"):
		if ev is InputEventKey and ev.physical_keycode == KEY_W:
			mf_has_w = true
	check(mf_has_w, "move_forward keeps W when boost takes W (fenced swap)")
	var boost_has_w := false
	for ev in InputMap.action_get_events("boost"):
		if ev is InputEventKey and ev.physical_keycode == KEY_W:
			boost_has_w = true
	check(boost_has_w, "boost got W anyway (duplicate binding allowed, movement intact)")

	# --- 3. physical-key fidelity round trip ----------------------------
	InputMap.load_from_project_settings()
	P.clear_cache()
	var j_ev := InputEventKey.new()
	j_ev.physical_keycode = KEY_J
	check(P.set_key_binding("boost", j_ev), "boost->J bind reported OK")
	P.save_bindings()
	InputMap.load_from_project_settings()
	check(P.key_binding_name("boost") == "SPACE", "scrubbed InputMap back to defaults")
	P.apply_saved_bindings()
	var found_phys := false
	for ev in InputMap.action_get_events("boost"):
		if ev is InputEventKey and ev.physical_keycode == KEY_J:
			found_phys = true
	check(found_phys, "restore preserves PHYSICAL keycode (non-QWERTY safe)")

	# --- 4. corrupt blob is discarded, defaults kept --------------------
	P.set_setting(P.KEY_BINDINGS, "{not valid json!!")
	P.clear_cache()
	InputMap.load_from_project_settings()
	P.apply_saved_bindings()
	var boost_events := InputMap.action_get_events("boost")
	var pad_ok := false
	for ev in boost_events:
		if ev is InputEventJoypadButton and ev.button_index == 0:
			pad_ok = true
	check(boost_events.size() == 3 and pad_ok, "corrupt blob: defaults kept, no crash")

	# --- 5. legacy v1 dict migrates once and is cleared -----------------
	var legacy := ConfigFile.new()
	legacy.set_value("input", "pad_button_map", {"boost": 9})
	legacy.save(P.CFG_PATH)
	P.clear_cache()
	InputMap.load_from_project_settings()
	P.apply_saved_bindings()
	var migrated_blob: String = P.get_setting(P.KEY_BINDINGS, "")
	check(migrated_blob != "", "legacy dict produced a blob")
	var boost_pad: Array = InputMap.action_get_events("boost").filter(
		func(ev): return ev is InputEventJoypadButton)
	check(boost_pad.size() >= 1 and boost_pad[0].button_index == 9,
		"migrated boost pad binding = L1 (9)")
	var blob_actions: Dictionary = JSON.parse_string(migrated_blob).actions
	check(int(blob_actions.boost.j) == 9, "migrated blob records boost j=9")

	# --- 6. reset restores project defaults ------------------------------
	P.reset_bindings()
	var reset_pad: Array = InputMap.action_get_events("boost").filter(
		func(ev): return ev is InputEventJoypadButton)
	check(reset_pad.size() == 1 and reset_pad[0].button_index == 0,
		"reset_bindings restored boost pad default (A)")
	var back_to_space := false
	for ev in InputMap.action_get_events("boost"):
		if ev is InputEventKey and ev.physical_keycode == KEY_SPACE:
			back_to_space = true
	check(back_to_space, "reset_bindings restored SPACE")

	# --- 7. legacy set_pad_button shim -----------------------------------
	P.set_pad_button("sabotage", 9)
	var sab_pad: Array = InputMap.action_get_events("sabotage").filter(
		func(ev): return ev is InputEventJoypadButton)
	check(sab_pad.size() == 1 and sab_pad[0].button_index == 9,
		"legacy set_pad_button rewrote the live pad slot")
	var sab_keys: Array = InputMap.action_get_events("sabotage").filter(
		func(ev): return ev is InputEventKey or ev is InputEventMouseButton)
	check(sab_keys.size() >= 1, "legacy shim kept keyboard slots")

	# --- 8. labels ---------------------------------------------------------
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
