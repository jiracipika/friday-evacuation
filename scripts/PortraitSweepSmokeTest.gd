# PortraitSweepSmokeTest.gd — FINAL-day 390px portrait in-match UI sweep,
# pinned headlessly. Fixes under test (each proven by a movie capture in
# docs/ui-continuation/evidence/portrait-sweep/ before the fix):
#   1. Evac HUD header/strip insets (±352px desktop) pushed the race timer
#      off-viewport at 390px; status chip landed on the minimap
#      (evac-match f9 before). HUD.gd now re-applies narrow insets.
#   2. SubtitleOverlay's fixed -140px band sat fully behind the opaque
#      instruments card at 390x844 (evac-caption f10 before); band now lifts
#      above the card and its min width honors MAX_WIDTH_RATIO.
#   3. Hauled RoundBanner's fixed 640px box clipped long hazard lines off
#      both edges (hauled-match f9 before); box now half-viewport + autowrap.
#   4. MobileControls BOOST/JUMP/stick-rest drew under the opaque instruments
#      card at 390px (evac-touch f9 before); narrow layouts lift the cluster
#      into a right-edge column above the card.
# Desktop 1280x720 layout is re-asserted at the end so the narrow paths stay
# gated behind the 520px breakpoint.
#
# FE_TOUCH=1 is set for the whole run (MobileControls mount); at 1280x720 the
# legacy corner layout must be byte-identical, at 390x844 the lifted column.
extends SceneTree

var checks := 0
var passed := 0
var failures: Array[String] = []
var _completed := false

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		print("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _set_size(win: Window, size: Vector2i) -> void:
	win.size = size
	win.content_scale_size = size

func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)

func _run() -> void:
	var win := root.get_window()
	# Watchdog: a mid-coroutine script error would otherwise leave the booted
	# scene running forever (ladder timeout in 300s — fail fast instead).
	create_timer(90.0).timeout.connect(func() -> void:
		if not _completed:
			printerr("PORTRAIT SWEEP SMOKE TEST WATCHDOG TIMEOUT (script error above?)")
			quit(1))
	OS.set_environment("FE_TOUCH", "1")
	load("res://scripts/PreMatchModal.gd").suppress_next()

	# ---------------- 390x844: Evacuation ----------------
	_set_size(win, Vector2i(390, 844))
	var evac: Node = (load("res://scenes/Evacuation.tscn") as PackedScene).instantiate()
	root.add_child(evac)
	current_scene = evac
	for i in 8:
		await process_frame

	var vp_w: float = evac.get_viewport().get_visible_rect().size.x
	check(is_equal_approx(vp_w, 390.0), "viewport reports 390px wide")
	var hud: Node = evac.get("hud_ext")
	check(hud != null and is_instance_valid(hud), "evac HUD mounted")
	if hud == null:
		_report()
		return

	var header: PanelContainer = hud.get("_header")
	var strip: PanelContainer = hud.get("_objective_panel")
	var status: PanelContainer = hud.get("_status_panel")
	var floor_group: VBoxContainer = hud.get("_floor_group")
	var instruments: PanelContainer = hud.get("state_panel")
	var map: Control = hud.get("minimap")

	var header_rect := _rect(header)
	check(header_rect.position.x >= -0.5 and header_rect.end.x <= vp_w + 0.5,
		"objective header (race timer) inside the 390px viewport")
	check(hud.get("timer_label").is_visible_in_tree(),
		"race timer visible in portrait")
	check(_rect(strip).position.x >= -0.5 and _rect(strip).end.x <= vp_w + 0.5,
		"objective strip inside the 390px viewport")
	check(not _rect(status).intersects(_rect(map)),
		"status chip does not overlap the minimap")
	check(_rect(floor_group).position.y >= _rect(strip).end.y - 1.0,
		"floor group starts below the objective strip (no header overlap)")
	var inst_rect := _rect(instruments)
	check(inst_rect.position.x >= -0.5 and inst_rect.end.x <= vp_w + 0.5,
		"instruments card inside the 390px viewport")

	# Caption band: fits the viewport and clears the opaque instruments card.
	var overlay: Control = evac.get_node_or_null("UI/SubtitleOverlay")
	check(overlay != null, "SubtitleOverlay mounted on evac HUD")
	if overlay != null:
		var cap_label: Label = overlay.get("caption_label")
		check(cap_label.custom_minimum_size.x <= vp_w * 0.7 + 0.5,
			"caption min width honors MAX_WIDTH_RATIO (%.0f)" % cap_label.custom_minimum_size.x)
		overlay.call("show_caption", "GHOST FINISHED — 61.4s. BEAT IT FOR THE OFFICE RECORD", 2.0)
		await process_frame
		await process_frame
		var cap_rect := _rect(overlay.get("caption_panel"))
		check(cap_rect.position.x >= -0.5 and cap_rect.end.x <= vp_w + 0.5,
			"caption band inside the 390px viewport (%s)" % cap_rect)
		check(cap_rect.end.y <= inst_rect.position.y + 0.5,
			"caption clears the opaque instruments card")

	# Touch cluster: every target in-viewport and above the instruments card.
	var mc: Control = evac.get_node_or_null("MobileControls")
	check(mc != null, "FE_TOUCH mounts MobileControls in portrait")
	if mc != null:
		var centers: Dictionary = mc.call("_button_centers")
		var boost_c: Vector2 = centers[&"boost"]
		var jump_c: Vector2 = centers[&"action"]
		var trap_c: Vector2 = centers[&"sabotage"]
		check(boost_c.y + 58.0 <= inst_rect.position.y + 0.5,
			"BOOST ring above the instruments card")
		check(jump_c.y + 44.0 <= boost_c.y - 58.0 + 0.5
			and trap_c.y + 40.0 <= jump_c.y - 44.0 + 0.5,
			"JUMP/TRAP stacked clear of BOOST")
		for pair in [[&"boost", boost_c, 58.0], [&"action", jump_c, 44.0], [&"sabotage", trap_c, 40.0]]:
			var c: Vector2 = pair[1]
			check(c.x - pair[2] >= -0.5 and c.x + pair[2] <= vp_w + 0.5
				and c.y - pair[2] >= -0.5,
				"%s target fully inside the viewport" % String(pair[0]))

	evac.queue_free()
	await process_frame

	# ---------------- 390x844: Hauled banner ----------------
	var hauled: Node = (load("res://scenes/Hauled.tscn") as PackedScene).instantiate()
	root.add_child(hauled)
	current_scene = hauled
	for i in 8:
		await process_frame
	var banner: Label = hauled.get("round_banner")
	check(banner != null and is_instance_valid(banner), "hauled round banner mounted")
	if banner != null:
		var brect := _rect(banner)
		check(brect.position.x >= -0.5 and brect.end.x <= vp_w + 0.5,
			"round banner box inside the 390px viewport (%s)" % brect)
		check(banner.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"round banner autowraps long hazard lines")
	hauled.queue_free()
	await process_frame

	# ---------------- 390x844: ShopSeek controls recap ----------------
	var shopseek: Node = (load("res://scenes/ShopSeek.tscn") as PackedScene).instantiate()
	root.add_child(shopseek)
	current_scene = shopseek
	for i in 8:
		await process_frame
	var recap: CanvasLayer = null
	for child in shopseek.get_children():
		if String(child.name) == "ControlsOverlay":
			recap = child
	check(recap != null, "shopseek round-start controls recap mounted")
	if recap != null:
		var recap_panel: PanelContainer = recap.get("panel")
		var rrect := _rect(recap_panel)
		check(rrect.position.x >= -0.5 and rrect.end.x <= vp_w + 0.5
			and rrect.position.y >= -0.5 and rrect.end.y <= 844.0 + 0.5,
			"controls recap panel inside the 390x844 viewport (%s)" % rrect)
	shopseek.queue_free()
	await process_frame

	# ---------------- 390x844: Pause menu ----------------
	var pause_scene: Node = (load("res://scenes/Evacuation.tscn") as PackedScene).instantiate()
	root.add_child(pause_scene)
	current_scene = pause_scene
	for i in 6:
		await process_frame
	var pause_menu: CanvasLayer = load("res://scripts/PauseMenu.gd").create(
		pause_scene, Callable())
	await process_frame
	await process_frame
	var pause_panel: PanelContainer = pause_menu.get("_panel")
	check(pause_panel != null, "pause menu panel mounted")
	if pause_panel != null:
		var prect := _rect(pause_panel)
		check(prect.position.x >= -0.5 and prect.end.x <= vp_w + 0.5,
			"pause panel inside the 390px viewport (%s)" % prect)
	paused = false
	pause_menu.queue_free()
	pause_scene.queue_free()
	await process_frame

	# ---------------- 1280x720 desktop regression ----------------
	_set_size(win, Vector2i(1280, 720))
	evac = (load("res://scenes/Evacuation.tscn") as PackedScene).instantiate()
	root.add_child(evac)
	current_scene = evac
	for i in 8:
		await process_frame
	hud = evac.get("hud_ext")
	var header2: PanelContainer = hud.get("_header")
	check(_rect(header2).position.x >= 300.0,
		"desktop header keeps its wide inset (%.0f)" % _rect(header2).position.x)
	check(_rect(hud.get("_status_panel")).position.y <= 80.0,
		"desktop status chip stays top-right")
	var overlay2: Control = evac.get_node_or_null("UI/SubtitleOverlay")
	var cap_label2: Label = overlay2.get("caption_label")
	check(is_equal_approx(cap_label2.custom_minimum_size.x, 320.0),
		"desktop caption min width unchanged (320)")
	check(is_equal_approx(overlay2.get("caption_panel").offset_top, -140.0),
		"desktop caption reserve unchanged (-140)")
	var mc2: Control = evac.get_node_or_null("MobileControls")
	check(mc2 != null and mc2.call("_instruments_reserve") == 0.0,
		"desktop touch layout keeps the Phase 7A corner")
	if mc2 != null:
		var centers2: Dictionary = mc2.call("_button_centers")
		check(centers2[&"boost"] == Vector2(mc2.size) + Vector2(-130.0, -150.0),
			"desktop BOOST at its legacy corner center")
		check(centers2[&"sabotage"] == Vector2(mc2.size) + Vector2(-130.0, -290.0),
			"desktop TRAP at its legacy corner center")
	evac.queue_free()
	await process_frame

	_report()

func _report() -> void:
	_completed = true
	if failures.is_empty() and checks > 0:
		print("=== PORTRAIT SWEEP SMOKE TEST PASS (%d/%d) ===" % [passed, checks])
		quit(0)
	else:
		print("=== PORTRAIT SWEEP SMOKE TEST FAILED (%d/%d) ===" % [passed, checks])
		for f in failures:
			print("  - %s" % f)
		quit(1)
