# HUDThemeSmokeTest.gd — P1B in-race HUD token contract.
#
# Pins the unification of the race HUD onto UITheme:
#   1. HUD.gd routes every color through UIT token constants — no raw hex
#      string literals left in _c() call sites (token drift like the old
#      off-palette "f2c66d" item color becomes impossible).
#   2. Minimap.gd loads UITheme and its frame uses the tokens; blip colors
#      are named consts, not inline literals in _draw.
#   3. Behavioral, against the REAL scene: the instruments panel carries a
#      2px ORANGE border while boost is READY/ACTIVE and a plain surface
#      while cooling; the sabotage hint sits in a chip with the story chip's
#      radius; the item readout uses the YELLOW token for spills.
extends SceneTree

var checks_total := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks_total += 1
	if cond:
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		print("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# ---- source audits -----------------------------------------------------
	var hud_src := FileAccess.get_file_as_string("res://scripts/HUD.gd")
	check(not hud_src.contains('_c("'), "HUD.gd has no raw hex literals in _c() calls")
	for token in ["UIT.BG", "UIT.ORANGE", "UIT.TEXT", "UIT.TEXT_MUTED", "UIT.SURFACE", "UIT.ORANGE_BRIGHT", "UIT.CORAL", "UIT.VIOLET", "UIT.YELLOW"]:
		check(hud_src.contains(token), "HUD.gd references token %s" % token)
	var map_src := FileAccess.get_file_as_string("res://scripts/Minimap.gd")
	check(map_src.contains("load(\"res://scripts/UITheme.gd\")"), "Minimap loads UITheme")
	check(map_src.contains("const EXIT_BLIP") and map_src.contains("const PLAYER_BLIP"),
		"Minimap blip colors are named consts")

	# ---- behavioral, real scene --------------------------------------------
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var scene: Node = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(scene)
	for i in 8:
		await process_frame
	var hud: CanvasLayer = scene.get("hud_ext")
	check(hud != null, "race HUD (hud_ext) present")
	if hud == null:
		quit(1)
		return
	var UIT = load("res://scripts/UITheme.gd")
	var state_panel: PanelContainer = hud.get("state_panel")
	check(state_panel != null and state_panel.name == "Instruments", "instruments panel addressable")
	var sb: StyleBoxFlat = state_panel.get_theme_stylebox("panel")

	hud.set_boost(3.0, 3.0, false)
	check(sb.border_width_left == 0, "cooling boost: plain surface (no border)")
	hud.set_boost(0.0, 3.0, false)
	check(sb.border_width_left == 2
		and sb.border_color.is_equal_approx(UIT.color(UIT.ORANGE)),
		"READY boost: 2px orange border")
	hud.set_boost(0.0, 1.5, true)
	check(sb.border_width_left == 2, "ACTIVE boost: border holds")
	hud.set_boost(1.2, 3.0, false)
	check(sb.border_width_left == 0, "back to cooling: border drops")

	var sabotage_chip: PanelContainer = state_panel.find_child("SabotageChip", true, false)
	check(sabotage_chip != null, "sabotage hint is a chip")
	if sabotage_chip:
		var chip_sb: StyleBoxFlat = sabotage_chip.get_theme_stylebox("panel")
		check(chip_sb != null and chip_sb.corner_radius_top_left == 10,
			"sabotage chip shares the story chip radius")

	hud.set_item(&"spill", 2)
	var item_label: Label = hud.get("item_label")
	check(item_label != null and item_label.text.contains("SPILL")
		and item_label.get_theme_color("font_color").is_equal_approx(UIT.color(UIT.YELLOW)),
		"spill item readout uses the YELLOW token")

	scene.queue_free()
	await process_frame

	if failures.is_empty() and checks_total > 0:
		print("=== HUD THEME SMOKE TEST PASS (%d/%d) ===" % [checks_total, checks_total])
		quit(0)
	else:
		print("=== HUD THEME SMOKE TEST FAILED (%d/%d) ===" % [checks_total - failures.size(), checks_total])
		for f in failures:
			print("  - %s" % f)
		quit(1)
