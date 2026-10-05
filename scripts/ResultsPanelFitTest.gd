# ResultsPanelFitTest.gd — shrink-to-fit contract for the Evacuation results
# panel (UI-LAYOUTS §1 follow-through; the menu responsiveness work's
# in-match counterpart).
#
# The panel is anchored center and sized by _clamp_results_panel(): designed
# 560x520, stretched to hold its content minimum when that is bigger, capped
# at 92% of the visible rect so it NEVER bleeds off-screen. Inside, the
# content lives in a "Body" ScrollContainer: when a tiny viewport (640x360
# windowed) forces the cap below the content minimum, the content scrolls
# instead of clipping. Width never scrolls — every content minimum must fit
# the 390px portrait inner width (the container-min-size trap: a Control
# refuses to shrink below get_combined_minimum_size(), so the old 170px
# meter minimum and the 348px pill row minimum were the offenders).
#
# Checks:
#   At 390x844 portrait (solo win): panel fully on-screen with margins,
#   centered, content minimum fully inside the panel (no scroll needed),
#   content min width respects the narrowest window, scroll body forbids
#   horizontal scroll, D5 button targets survive the restructure.
#   At 640x360 windowed (runtime resize, solo win): panel fully on-screen
#   with margins (re-clamp on VIEWPORT resize — the old code only re-clamped
#   on panel resize and bled 60px off the top and bottom), height pinned to
#   the cap, vertical overflow reachable via the scroll body.
#   Back up to 1280x720: panel grows back to the designed 560x520, centered
#   both axes.
#   Fresh boot at 1280x720: designed size, centered, content inside, cap
#   respected, S-F structure (tape/header/pills/standings) intact.
#   5-finisher LAN at 390x844: panel stretches to hold the taller standings
#   (still capped/on-screen), every standings row inside the panel bounds.
# Run:
#   godot --headless --path . --script scripts/ResultsPanelFitTest.gd -- --test-mode
extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _set_size(size: Vector2i) -> void:
	root.size = size
	root.content_scale_size = size

func _boot() -> Node:
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var scene: Node = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(scene)
	for i in 8:
		await process_frame
	return scene

func _finish(scene: Node, names: Array) -> void:
	var order: Array[Dictionary] = []
	for i in names.size():
		order.append({
			"player_id": scene.local_player.get_instance_id() if i == 0 else 1000 + i,
			"name": String(names[i]),
			"time": 60.0 + i,
		})
	scene.top_speed = 12.5
	scene.traps_hit = 3
	scene.finish_order = order
	scene._end_race()
	# Real-time wait: the entrance tween + the deferred content re-clamp.
	await create_timer(0.7).timeout
	await process_frame

func _panel(scene: Node) -> Panel:
	return scene.get_node("UI/ResultsPanel")

func _vbox(scene: Node) -> Control:
	return _panel(scene).get_node("Body/VBox")

## True when the panel rect sits fully inside the viewport with >= margin px
## of slack on every edge.
func _on_screen(p: Panel, margin: float) -> bool:
	var vp: Vector2 = p.get_viewport_rect().size
	var pos: Vector2 = p.global_position
	return pos.x >= margin and pos.y >= margin \
		and vp.x - (pos.x + p.size.x) >= margin \
		and vp.y - (pos.y + p.size.y) >= margin

func _run() -> void:
	# StatsManager writes the REAL user://save.cfg during _end_race —
	# snapshot and restore it around the whole run.
	var save_path: String = ProjectSettings.globalize_path("user://save.cfg")
	var saved_bytes := PackedByteArray()
	if FileAccess.file_exists(save_path):
		saved_bytes = FileAccess.get_file_as_bytes(save_path)

	# ============ 390x844 PORTRAIT, solo win ============
	# Boot at the narrow size BEFORE the first layout pass, and sync
	# content_scale_size (canvas_items stretch: a stale 1280 design size
	# desyncs anchors — same recipe as MenuLayoutSmokeTest).
	_set_size(Vector2i(390, 844))
	var scene: Node = await _boot()
	await _finish(scene, ["YOU"])
	var panel: Panel = _panel(scene)
	var vbox: Control = _vbox(scene)
	var vmin: Vector2 = vbox.get_combined_minimum_size()

	check(_on_screen(panel, 8.0),
		"portrait: panel fully on-screen with margins (pos=%s size=%s vp=%s)"
			% [panel.global_position, panel.size, panel.get_viewport_rect().size])
	var vp: Vector2 = panel.get_viewport_rect().size
	check(panel.size.x >= vmin.x + 40.0 - 0.5 and panel.size.y >= vmin.y + 40.0 - 0.5,
		"portrait: content minimum inside panel minus 20px margins (panel=%.0fx%.0f vbox_min=%.0fx%.0f)"
			% [panel.size.x, panel.size.y, vmin.x, vmin.y])
	var edge_l: float = panel.global_position.x
	var edge_r: float = vp.x - (panel.global_position.x + panel.size.x)
	check(absf(edge_l - edge_r) <= 1.0, "portrait: panel centered horizontally")
	check(vmin.x <= vp.x - 48.0,
		"portrait: content min width respects the narrowest window (%.0f vs %.0f)" % [vmin.x, vp.x - 48.0])
	var body: ScrollContainer = panel.get_node_or_null("Body")
	check(body != null and body.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"scroll body forbids horizontal scroll (content compacts instead)")

	var rematch: Button = vbox.get_node_or_null("RematchButton")
	var menu_btn: Button = vbox.get_node_or_null("MenuButton")
	check(rematch != null and menu_btn != null
		and rematch.custom_minimum_size.y >= 52.0 and menu_btn.custom_minimum_size.y >= 52.0,
		"D5 52px button targets survive the scroll-body restructure")

	# ============ 640x360 WINDOWED, runtime resize ============
	_set_size(Vector2i(640, 360))
	for i in 8:
		await process_frame
	vp = panel.get_viewport_rect().size
	check(_on_screen(panel, 8.0),
		"640x360 runtime resize: panel re-clamps fully on-screen (pos=%s size=%s)"
			% [panel.global_position, panel.size])
	check(panel.size.y <= vp.y * 0.92 + 0.5,
		"640x360: panel height pinned to the 92%% cap (%.0f vs %.0f)" % [panel.size.y, vp.y * 0.92])
	vmin = vbox.get_combined_minimum_size()
	check(vmin.x + 40.0 <= panel.size.x + 0.5,
		"640x360: content min width still fits the panel inner width (%.0f vs %.0f)"
			% [vmin.x + 40.0, panel.size.x])
	var overflow: float = vbox.size.y - body.size.y
	var bar: VScrollBar = body.get_v_scroll_bar()
	check(overflow > 0.0 and bar != null and bar.max_value >= overflow - 1.0,
		"640x360: vertical overflow (%.0fpx) is scroll-reachable, not clipped" % overflow)
	# Scrolling to the bottom must actually reveal the last content line.
	body.scroll_vertical = int(bar.max_value)
	await process_frame
	var content_bottom: float = vbox.global_position.y + vbox.size.y
	check(content_bottom <= panel.global_position.y + panel.size.y + 1.0,
		"640x360: scrolled-to-bottom content ends inside the panel")

	# ============ RESIZE BACK UP: grow-back + centering ============
	_set_size(Vector2i(1280, 720))
	for i in 8:
		await process_frame
	check(panel.size.is_equal_approx(Vector2(560, 520)),
		"resize up: panel returns to the designed 560x520 (got %.0fx%.0f)" % [panel.size.x, panel.size.y])
	var center_err: float = absf(panel.global_position.x - (1280.0 - panel.size.x) / 2.0)
	check(center_err <= 1.0, "resize up: panel stays centered (%.1f)" % center_err)
	scene.queue_free()
	await process_frame

	# ============ FRESH DESKTOP BOOT ============
	_set_size(Vector2i(1280, 720))
	var scene2: Node = await _boot()
	await _finish(scene2, ["YOU"])
	var panel2: Panel = _panel(scene2)
	var vbox2: Control = _vbox(scene2)
	var vmin2: Vector2 = vbox2.get_combined_minimum_size()
	check(panel2.size.is_equal_approx(Vector2(560, 520)),
		"desktop boot: designed 560x520 (got %.0fx%.0f)" % [panel2.size.x, panel2.size.y])
	var vp2: Vector2 = panel2.get_viewport_rect().size
	var l2: float = panel2.global_position.x
	var r2: float = vp2.x - (panel2.global_position.x + panel2.size.x)
	var t2: float = panel2.global_position.y
	var b2: float = vp2.y - (panel2.global_position.y + panel2.size.y)
	check(absf(l2 - r2) <= 1.0 and absf(t2 - b2) <= 1.0,
		"desktop boot: centered on both axes (L%.0f R%.0f T%.0f B%.0f)" % [l2, r2, t2, b2])
	check(panel2.size.x >= vmin2.x + 40.0 - 0.5 and panel2.size.y >= vmin2.y + 40.0 - 0.5,
		"desktop boot: content minimum fully inside the panel (vbox_min=%.0fx%.0f)" % [vmin2.x, vmin2.y])
	check(panel2.size.x <= vp2.x * 0.92 + 0.5 and panel2.size.y <= vp2.y * 0.92 + 0.5,
		"desktop boot: designed size stays inside the 92% cap")
	# The S-F restyle structure must have survived the reparent into Body.
	check(vbox2.get_node_or_null("TapeStrip") != null
		and vbox2.get_node_or_null("HeaderRow") != null
		and vbox2.get_node_or_null("StatsGrid") != null
		and vbox2.get_node_or_null("PillRow") is Container
		and vbox2.get_node_or_null("StandingsList") != null,
		"S-F structure (tape/header/grid/pills/standings) intact under the scroll body")
	scene2.queue_free()
	await process_frame

	# ============ 390x844 PORTRAIT, 5-finisher LAN ============
	_set_size(Vector2i(390, 844))
	var scene3: Node = await _boot()
	await _finish(scene3, ["YOU", "Speedy Gonzalez Lopez", "Chair Wizard", "Crash Tester", "Slowpoke Rodriguez"])
	var panel3: Panel = _panel(scene3)
	var vbox3: Control = _vbox(scene3)
	var vmin3: Vector2 = vbox3.get_combined_minimum_size()
	check(_on_screen(panel3, 8.0),
		"LAN5 portrait: taller panel still fully on-screen (size=%.0fx%.0f)" % [panel3.size.x, panel3.size.y])
	check(panel3.size.y >= vmin3.y + 40.0 - 0.5,
		"LAN5 portrait: panel stretches to hold the standings minimum (%.0f vs %.0f)"
			% [panel3.size.y, vmin3.y + 40.0])
	check(panel3.size.y <= 844.0 * 0.92 + 0.5, "LAN5 portrait: stretch respects the 92% cap")
	var row_ok := true
	var row_worst := 0.0
	for row in vbox3.get_node_or_null("StandingsList").get_children():
		if row is HBoxContainer and not row.is_queued_for_deletion():
			var spill: float = row.global_position.x + row.size.x - (panel3.global_position.x + panel3.size.x)
			row_worst = maxf(row_worst, spill)
			if spill > 1.0:
				row_ok = false
	check(row_ok, "LAN5 portrait: every standings row ends inside the panel (worst spill %.1f)" % row_worst)
	scene3.queue_free()
	await process_frame

	# Restore the user's real career stats no matter how the checks landed.
	if saved_bytes.size() > 0:
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		if f:
			f.store_buffer(saved_bytes)
			f.flush()
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

	if failures.is_empty() and checks > 0:
		print("=== RESULTS PANEL FIT TEST PASS (%d/%d) ===" % [checks, checks])
		quit(0)
	else:
		print("=== RESULTS PANEL FIT TEST FAILED (%d/%d) ===" % [checks - failures.size(), checks])
		for f in failures:
			print("  - %s" % f)
		quit(1)
