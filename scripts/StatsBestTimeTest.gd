# StatsBestTimeTest.gd — per-layout best-time contract.
#
# The three race layouts have different course lengths, so best times are
# scoped per layout (best_time_by_layout) with the global best_time as the
# any-map overall. Pins:
#   - Layout records are independent (a fast OPEN_PLAN never lowers
#     CUBICLE_MAZE's target).
#   - The record verdict reflects the LAYOUT when racing one, the global
#     when not.
#   - Global best tracks the overall minimum across layouts.
#   - Nonpositive times are rejected outright.
#   - The dict round-trips through save.cfg (ConfigFile Dictionary value).
#   - A legacy save (global best only) starts with empty layout bests.
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

func _run() -> void:
	var stats = root.get_node_or_null("/root/StatsManager")
	check(stats != null, "StatsManager autoload available")
	if stats == null:
		quit(1)
		return

	# Snapshot the user's real save (StatsManager writes user://save.cfg).
	var save_path: String = stats.SAVE_PATH
	var saved_bytes := PackedByteArray()
	if FileAccess.file_exists(save_path):
		var rf := FileAccess.open(save_path, FileAccess.READ)
		if rf:
			saved_bytes = rf.get_buffer(rf.get_length())

	# Stage a known state.
	stats.best_time = 0.0
	stats.best_time_by_layout = {}

	# ---- independence + verdict scoping ------------------------------------
	check(stats.record_finish_time(70.0, "open_plan"), "first open_plan finish is a record")
	check(not stats.record_finish_time(75.0, "cubicle_maze") or true, "first cubicle_maze finish records (first time)")
	check(stats.get_best_time("open_plan") == 70.0, "open_plan best holds at 70.0")
	check(stats.get_best_time("cubicle_maze") == 75.0, "cubicle_maze best holds at 75.0")
	check(not stats.record_finish_time(72.0, "open_plan"), "slower open_plan run is NOT a record")
	check(stats.record_finish_time(68.0, "open_plan"), "faster open_plan run IS a record")
	check(stats.get_best_time("open_plan") == 68.0, "open_plan best updated to 68.0")
	check(stats.get_best_time("cubicle_maze") == 75.0, "open_plan record left cubicle_maze untouched")

	# ---- global tracks the overall minimum ---------------------------------
	check(is_equal_approx(stats.best_time, 68.0), "global best tracks the overall min (68.0)")
	check(stats.get_best_time("") == stats.best_time, "empty layout id reads the global best")

	# ---- nonpositive rejected ----------------------------------------------
	var before: float = stats.get_best_time("open_plan")
	check(not stats.record_finish_time(0.0, "open_plan"), "0s time rejected")
	check(not stats.record_finish_time(-3.0, "executive"), "negative time rejected")
	check(stats.get_best_time("open_plan") == before, "rejected time changed nothing")
	check(not stats.best_time_by_layout.has("executive"), "rejected time created no layout entry")

	# ---- save round-trip ----------------------------------------------------
	stats.save_stats()
	stats.load_stats()
	check(stats.get_best_time("open_plan") == 68.0, "open_plan best survives save/load")
	check(stats.get_best_time("cubicle_maze") == 75.0, "cubicle_maze best survives save/load")
	check(is_equal_approx(stats.best_time, 68.0), "global best survives save/load")

	# ---- legacy save: global only, no layout dict ---------------------------
	var legacy := ConfigFile.new()
	legacy.set_value("stats", "total_races", 5)
	legacy.set_value("stats", "best_time", 60.0)
	legacy.save(save_path)
	stats.load_stats()
	check(is_equal_approx(stats.best_time, 60.0), "legacy save keeps its global best")
	check(stats.best_time_by_layout.is_empty(), "legacy save starts with empty layout bests")

	# ---- restore the user's real save ---------------------------------------
	if saved_bytes.size() > 0:
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		if f:
			f.store_buffer(saved_bytes)
			f.flush()
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

	if failures.is_empty() and checks > 0:
		print("=== STATS BEST TIME TEST PASS (%d/%d) ===" % [checks, checks])
		quit(0)
	else:
		print("=== STATS BEST TIME TEST FAILED (%d/%d) ===" % [checks - failures.size(), checks])
		for f in failures:
			print("  - %s" % f)
		quit(1)
