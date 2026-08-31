# ControlsOverlaySmokeTest.gd — verifies the round-start controls recap:
#   1. mount() is deduped (second mount returns the same node).
#   2. show_for() makes the panel visible with both scheme columns and
#      all rows present (keyboard AND controller).
#   3. The active scheme's column is the highlighted one (checks the
#      header text carries the ACTIVE marker on the right column).
#   4. Device flip while visible re-highlights the other column live.
#   5. Auto-hide after the duration; hide_now() hides immediately.
#   6. All four real modes mount the overlay and trigger it at round
#      start (fresh scene instantiation, several frames).
#   7. ControlsOverlay feeds note_device: synthesized pad motion flips
#      the scheme while the overlay is mounted in a mode scene.
# Runs with the real project (autoloads): 
#   godot --headless --path . --script scripts/ControlsOverlaySmokeTest.gd
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
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _find_overlay(root: Node) -> Node:
	for child in root.get_children():
		if child.name == "ControlsOverlay":
			return child
	return null

func _header_texts(overlay: Node) -> Dictionary:
	var out := {}
	for box_name in ["kb_box", "pad_box"]:
		var box = overlay.get(box_name)
		if box:
			var header: Label = box.get_child(0)
			out[box_name] = header.text
	return out

func _run() -> void:
	var P = load("res://scripts/InputPrefs.gd")
	check(P != null, "InputPrefs compiles")
	var OverlayScript = load("res://scripts/ControlsOverlay.gd")
	check(OverlayScript != null, "ControlsOverlay.gd compiles")

	# Isolate prefs from the real save.
	var real_cfg: String = P.CFG_PATH
	P.CFG_PATH = "user://settings_controls_overlay_test.cfg"
	var cfg := ConfigFile.new()
	cfg.save(P.CFG_PATH)
	P.set_scheme_mode(P.SCHEME_AUTO)
	P.refresh_cache()

	# 1. mount dedupe on a bare Node root
	var host := Node.new()
	root.add_child(host)
	await process_frame
	var o1: Node = OverlayScript.mount(host)
	var o2: Node = OverlayScript.mount(host)
	check(o1 != null and o1 == o2, "mount() deduped (same node returned)")
	check(o1.name == "ControlsOverlay", "overlay node named ControlsOverlay")

	# 2+3. show_for: visible, both columns, active highlight correct
	o1.show_for(6.0)
	await process_frame
	check(o1.root_control.visible == true, "show_for makes panel visible")
	var headers := _header_texts(o1)
	check(headers.has("kb_box") and headers.has("pad_box"), "both columns built")
	check(headers["kb_box"].contains("ACTIVE"), "keyboard column marked ACTIVE (keyboard last device)")
	check(not String(headers["pad_box"]).contains("ACTIVE"), "controller column not ACTIVE")
	var kb_rows: int = o1.kb_box.get_child_count() - 1
	var pad_rows: int = o1.pad_box.get_child_count() - 1
	check(kb_rows == 7, "keyboard column has 7 rows (was %d)" % kb_rows)
	check(pad_rows == 7, "controller column has 7 rows (was %d)" % pad_rows)
	# Controller rows reflect remapped buttons.
	var pad_texts: Array = []
	for i in range(1, o1.pad_box.get_child_count()):
		pad_texts.append(o1.pad_box.get_child(i).text)
	check(pad_texts.any(func(t): return String(t).contains(P.pad_button_name("boost"))),
		"controller rows use remap-aware pad button names")

	# 4. Device flip while visible re-highlights live.
	var stick := InputEventJoypadMotion.new()
	stick.axis = 0
	stick.axis_value = 0.8
	o1._input(stick)  # overlay feeds note_device
	await process_frame
	var headers2 := _header_texts(o1)
	check(String(headers2["pad_box"]).contains("ACTIVE"), "device flip re-highlights controller column live")
	check(not String(headers2["kb_box"]).contains("ACTIVE"), "keyboard column loses highlight on flip")

	# 5. Auto-hide after duration (real-time wait: headless frames run fast).
	o1.show_for(1.8)  # min duration = FADE_TIME + 0.5
	await create_timer(2.6).timeout
	check(o1.root_control.visible == false, "overlay auto-hides after duration (reduced-motion off)")
	o1.show_for(6.0)
	o1.hide_now()
	check(o1.root_control.visible == false, "hide_now hides immediately")

	host.free()

	# 6. All four modes mount + trigger the overlay at round start.
	var modes := [
		["res://scenes/Evacuation.tscn", "Evacuation"],
		["res://scenes/Hauled.tscn", "Hauled"],
		["res://scenes/ShopSeek.tscn", "ShopSeek"],
		["res://scenes/PizzaColony.tscn", "PizzaColony"],
	]
	for entry in modes:
		var packed = load(entry[0])
		if packed == null:
			check(false, "%s scene loads" % entry[1])
			continue
		# PreMatchModal pauses the tree on mount — suppressed per instance.
		load("res://scripts/PreMatchModal.gd").suppress_next()
		var instance = packed.instantiate()
		root.add_child(instance)
		for i in 8:
			await process_frame
		var overlay := _find_overlay(instance)
		check(overlay != null, "%s mounts ControlsOverlay" % entry[1])
		if overlay:
			check(overlay.root_control.visible == true,
				"%s shows controls at round start" % entry[1])
		instance.free()
		await process_frame

	# Cleanup + restore
	var prefs = load("res://scripts/InputPrefs.gd")
	prefs.set_scheme_mode(prefs.SCHEME_AUTO)
	var cleanup := ConfigFile.new()
	cleanup.save(P.CFG_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P.CFG_PATH))
	P.CFG_PATH = real_cfg
	P.refresh_cache()
	prefs.reset_yaw()

	check(failures.is_empty(), "no failures")
	print("ControlsOverlaySmokeTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
