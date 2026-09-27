# LayoutPacingTest.gd — every shipped layout must stay completable, with pacing.
#
# CheckpointBotTest proves open_plan traversable. But layouts ship in threes
# (open_plan / cubicle_maze / executive), and layout tuning changes desk
# counts, ice size, and corridors — the WinnabilityProbe lesson says a layout
# can quietly become unwinnable or miserably slow and no suite would notice.
# This suite drives the SAME bot through EACH layout and pins:
#   1. every layout is finishable by the standard driving policy,
#   2. every finish lands well inside the 120s race clock,
#   3. no layout is an outlier (slowest within 4x of fastest — a huge spread
#      means the layout's obstacles fight the intended route).
# It also prints the pacing table so design tuning eats real numbers.
#
# Run: godot --headless --path . --script scripts/LayoutPacingTest.gd -- --test-mode
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

func _run_layout(layout_id: String) -> Dictionary:
	var layouts = load("res://scripts/LevelLayouts.gd")
	if layouts:
		layouts.set_current(layout_id)
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var bot = load("res://scripts/CheckpointBot.gd").new()
	var evac = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(evac)
	var stats: Dictionary = await bot.run(evac, self)
	for f in bot.fails:
		print("    [%s bot] %s" % [layout_id, f])
	if evac.is_inside_tree():
		evac.free()
	await process_frame
	return stats

func _run() -> void:
	var rows: Array = []
	for layout_id in ["open_plan", "cubicle_maze", "executive"]:
		var stats: Dictionary = await _run_layout(layout_id)
		rows.append({"layout": layout_id, "stats": stats})
		print("    %s: finished=%s sim=%.1fs wall=%.1fs gates=%d" % [
			layout_id, stats.get("finished", false),
			stats.get("sim", -1.0) if stats.get("sim", -1.0) != null else -1.0,
			stats.get("wall", -1.0), stats.get("gates", -1)])

	check(rows.size() == 3, "all three layouts exercised")

	var all_names := ""
	for r in rows:
		all_names += String(r.layout) + " "
	check(all_names.contains("open_plan") and all_names.contains("cubicle_maze")
		and all_names.contains("executive"), "exactly the three shipped layouts ran")

	for r in rows:
		var s: Dictionary = r.stats
		check(s.get("finished", false) == true,
			"%s is completable by the standard driving policy" % r.layout)
		var sim: float = s.get("sim", 999.0)
		check(sim > 1.0 and sim < 118.0,
			"%s finish lands inside the 120s race clock (%.1fs sim)" % [r.layout, sim])

	var sims: Array = []
	for r in rows:
		sims.append(r.stats.get("sim", 999.0))
	sims.sort()
	if sims.size() == 3:
		check(sims[2] <= sims[0] * 4.0,
			"no pacing outlier (slowest %.1fs <= 4x fastest %.1fs)" % [sims[2], sims[0]])

	print("")
	print("    PACING TABLE (sim seconds to finish):")
	for r in rows:
		print("      %-13s %6.1fs" % [r.layout, r.stats.get("sim", -1.0)])

	if failures.is_empty() and checks_total > 0:
		print("=== LAYOUT PACING TEST PASS (%d/%d) ===" % [checks_total, checks_total])
		quit(0)
	else:
		print("=== LAYOUT PACING TEST FAILED (%d/%d) ===" % [checks_total - failures.size(), checks_total])
		for f in failures:
			print("  - %s" % f)
		quit(1)
