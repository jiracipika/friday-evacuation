# ResultsCelebrationTest.gd — D5 results celebration contract.
#
# Drives the REAL Evacuation scene through _end_race twice (win + no-winner)
# and pins the D5 delta behavior:
#   - Winner banner: 32px, warm orange (1,0.65,0.1), 4px dark outline.
#   - Stat values 24px; TOP SPEED value carries the orange accent.
#   - Record pills: top-speed LIME, chair unlock VIOLET.
#   - Results entrance: fade+scale tween (modulate/scale settle to identity),
#     instant when the user's real settings enable reduced motion.
#   - In-match HUD cards dim to 0.35 behind the panel; the panel is exempt.
#   - Confetti (CPUParticles2D burst over the panel) is a WIN-only reward;
#     a timed-out race with no winner stays quiet.
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

func _boot() -> Node:
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var scene: Node = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(scene)
	for i in 8:
		await process_frame
	return scene

func _ui(scene: Node) -> Node:
	return scene.get_node("UI")

func _particles_under(layer: Node) -> Array:
	var found: Array = []
	for child in layer.get_children():
		if child is CPUParticles2D:
			found.append(child)
	return found

func _run() -> void:
	var a11y = load("res://scripts/Accessibility.gd")
	var reduced: bool = a11y != null and a11y.reduced_motion_enabled()
	print("reduced_motion=%s (live user cfg — branch honored, not modified)" % reduced)

	# StatsManager IS an autoload here (Godot 4.7 loads autoloads in --script
	# mode) and _end_race records into the REAL user://save.cfg. Snapshot and
	# restore it around the whole run so the user's career stats are untouched.
	var save_path: String = ProjectSettings.globalize_path("user://save.cfg")
	var saved_bytes := PackedByteArray()
	if FileAccess.file_exists(save_path):
		saved_bytes = FileAccess.get_file_as_bytes(save_path)

	# ================= WIN CASE =================
	var scene: Node = await _boot()
	scene.top_speed = 12.5
	scene.traps_hit = 3
	# Drive the REAL StatsManager so the pills happen through the actual
	# record path: a genuine top-speed PB (12.5 > 10) and a genuine chair
	# unlock (races_won 0 -> 1 crosses Bean Bag's 1-win threshold).
	var stats = root.get_node_or_null("/root/StatsManager")
	check(stats != null, "StatsManager autoload available for the record path")
	if stats:
		stats.total_races = 3
		stats.races_won = 0
		stats.top_speed_ever = 10.0
		# No PB yet → the best-time pill stays quiet; exactly 2 pills here.
		stats.best_time = 0.0
	var order: Array[Dictionary] = [{
		"player_id": scene.local_player.get_instance_id(),
		"name": "YOU",
		"time": 61.5,
	}]
	scene.finish_order = order
	scene._end_race()

	var panel: Panel = scene.get_node("UI/ResultsPanel")
	check(panel.visible, "results panel shown on race end")

	if not reduced:
		for i in 3:
			await process_frame
		check(panel.modulate.a < 1.0,
			"entrance anim in flight right after end (a=%.2f)" % panel.modulate.a)
	# Real-time wait: headless process frames accumulate far less than the
	# tween's 0.4s, so frame-count waits never see the tween finish.
	await create_timer(0.6).timeout
	check(is_equal_approx(panel.modulate.a, 1.0), "panel fades fully in")
	check(panel.scale.is_equal_approx(Vector2.ONE), "panel scale settles at 1:1")

	var vbox := panel.get_node("VBox")
	var winner: Label = vbox.get_node_or_null("WinnerLabel")
	check(winner != null and winner.text.begins_with("YOU"), "winner banner names the winner")
	check(winner != null and winner.get_theme_font_size("font_size") == 32,
		"winner banner is 32px")
	check(winner != null
		and winner.get_theme_color("font_color").is_equal_approx(Color(1.0, 0.65, 0.1)),
		"winner banner uses the warm orange")
	check(winner != null and winner.get_theme_constant("outline_size") == 4
		and winner.get_theme_color("font_outline_color").is_equal_approx(Color("0a0a0f")),
		"winner banner carries the 4px dark outline")

	var speed_value: Label = vbox.get_node_or_null("StatsGrid/TopSpeedRow/TopSpeedValue")
	check(speed_value != null and speed_value.get_theme_font_size("font_size") == 24,
		"TOP SPEED value is 24px")
	check(speed_value != null
		and speed_value.get_theme_color("font_color").is_equal_approx(Color("ff9a1a")),
		"TOP SPEED value is orange-accented")
	var traps_value: Label = vbox.get_node_or_null("StatsGrid/TrapsRow/TrapsValue")
	check(traps_value != null and traps_value.text == "3"
		and traps_value.get_theme_font_size("font_size") == 24,
		"TRAPS HIT value populated at 24px")

	var pills: HBoxContainer = vbox.get_node_or_null("PillRow")
	var pill_labels: Array = []
	if pills:
		for child in pills.get_children():
			var lbl: Label = child.get_child(0) if child.get_child_count() > 0 else null
			if lbl:
				pill_labels.append({"text": lbl.text, "color": lbl.get_theme_color("font_color")})
			else:
				print("    pill child without label: %s (%d children)" % [child, child.get_child_count()])
		print("    staged pb=%s unlocks=%s → pills=%s" % [scene.new_personal_best,
			str(scene.skin_unlock_names), str(pill_labels.map(func(p): return p.text))])
	check(pill_labels.size() == 2, "both record pills present (got %d)" % pill_labels.size())
	# LAN standings: the single-player win shows exactly one row — yours.
	var standings: VBoxContainer = vbox.get_node_or_null("StandingsList")
	check(standings != null, "standings list present")
	if standings:
		var rows := 0
		var own_row_text := ""
		for row in standings.get_children():
			if row is HBoxContainer and not row.is_queued_for_deletion():
				rows += 1
				for cell in row.get_children():
					if cell is Label and "(you)" in cell.text:
						own_row_text = cell.text
		check(rows == 1, "single-finish standings shows one row (got %d)" % rows)
		check(own_row_text != "", "own row carries the (you) tag (%s)" % own_row_text)
	if pill_labels.size() == 2:
		var lime_ok := false
		var violet_ok := false
		for p in pill_labels:
			if String(p.text).contains("TOP-SPEED") and p.color.is_equal_approx(Color("b9f34a")):
				lime_ok = true
			if String(p.text).contains("NEW CHAIR") and p.color.is_equal_approx(Color("9b82ff")):
				violet_ok = true
		check(lime_ok, "top-speed record pill is LIME")
		check(violet_ok, "chair unlock pill is VIOLET")

	var rematch: Button = vbox.get_node_or_null("RematchButton")
	check(rematch != null and rematch.custom_minimum_size.y >= 52.0,
		"REMATCH is a 52px primary target")
	var menu_btn: Button = vbox.get_node_or_null("MenuButton")
	check(menu_btn != null and menu_btn.custom_minimum_size.y >= 52.0,
		"MAIN MENU is a 52px target")

	check(_particles_under(_ui(scene)).size() == 1,
		"win ends with one CPUParticles2D burst over the panel")
	var dim_ok := true
	# The real race HUD is hud_ext (CanvasLayer layer=10); D5 dims its card
	# groups (CanvasLayer itself has no modulate — not a CanvasItem).
	if scene.hud_ext:
		for child in scene.hud_ext.get_children():
			if child is CanvasItem and (child as CanvasItem).modulate.a > 0.36:
				dim_ok = false
				print("    hud_ext card not dimmed: %s a=%.2f" % [child.name, (child as CanvasItem).modulate.a])
	for child in _ui(scene).get_children():
		if child == panel or not (child is CanvasItem) or child is CPUParticles2D:
			continue
		# PanicCam animates its own modulate every frame — it is not a HUD
		# card and a dim tween cannot win against its _process. Subtitle
		# overlay stays readable for a11y captions.
		if String(child.name).begins_with("PanicCam") or String(child.name) == "SubtitleOverlay":
			continue
		if (child as CanvasItem).modulate.a > 0.36:
			dim_ok = false
			print("    undimmed HUD child: %s a=%.2f" % [child.name, (child as CanvasItem).modulate.a])
	check(dim_ok, "in-match HUD dimmed to 0.35 behind the panel")
	check(is_equal_approx(panel.modulate.a, 1.0), "results panel exempt from the HUD dim")

	scene.queue_free()
	await process_frame

	# ================= NO-WINNER CASE =================
	var scene2: Node = await _boot()
	var none: Array[Dictionary] = []
	scene2.finish_order = none
	scene2._end_race()
	await create_timer(0.6).timeout
	var panel2: Panel = scene2.get_node("UI/ResultsPanel")
	var winner2: Label = panel2.get_node("VBox/WinnerLabel")
	check(winner2.text == "NO WINNER", "timed-out race reports NO WINNER")
	check(_particles_under(_ui(scene2)).is_empty(),
		"no confetti when nobody wins")
	scene2.queue_free()
	await process_frame

	# ================= GHOST-ROW CASE =================
	# Replay ghosts finish too; their standings rows must read dimmed so a
	# LAN player can tell a ghost's time from a real finisher's.
	var scene3: Node = await _boot()
	var mixed: Array[Dictionary] = [
		{"player_id": 424242, "name": "GHOST", "time": 58.0, "is_ghost": true},
		{"player_id": scene3.local_player.get_instance_id(), "name": "YOU", "time": 63.3},
	]
	scene3.finish_order = mixed
	scene3._end_race()
	await create_timer(0.6).timeout
	var standings3: VBoxContainer = scene3.get_node("UI/ResultsPanel/VBox").get_node_or_null("StandingsList")
	check(standings3 != null, "ghost-case standings list present")
	var winner3: Label = scene3.get_node("UI/ResultsPanel/VBox/WinnerLabel")
	check(winner3.text == "YOU WINS!",
		"winner banner names the first human, never the ghost (%s)" % winner3.text)
	if standings3:
		var ghost_dimmed := false
		var own_opaque := false
		for row in standings3.get_children():
			if not (row is HBoxContainer) or row.is_queued_for_deletion():
				continue
			var name_text := ""
			for cell in row.get_children():
				if cell is Label:
					var t: String = cell.text
					if t != "1ST" and t != "2ND" and t != "3RD" and not t.ends_with("s"):
						name_text = t
			if name_text == "GHOST":
				ghost_dimmed = row.modulate.a < 1.0
			elif "(you)" in name_text:
				own_opaque = is_equal_approx(row.modulate.a, 1.0)
		check(ghost_dimmed, "ghost standings row renders dimmed")
		check(own_opaque, "human standings row stays opaque")
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
		print("=== RESULTS CELEBRATION TEST PASS (%d/%d) ===" % [checks, checks])
		quit(0)
	else:
		print("=== RESULTS CELEBRATION TEST FAILED (%d/%d) ===" % [checks - failures.size(), checks])
		for f in failures:
			print("  - %s" % f)
		quit(1)
