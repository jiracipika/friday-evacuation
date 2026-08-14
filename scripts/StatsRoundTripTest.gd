# StatsRoundTripTest.gd — Verifies StatsManager record/persist/reload cycle
# Run: godot --headless --path . --script scripts/StatsRoundTripTest.gd
extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var script = load("res://scripts/StatsManager.gd")
	var s = script.new()
	root.add_child(s)
	s.reset_stats()
	s.record_race(true, 42.5, 0)
	s.record_race(false, 30.0, 0)
	s.record_trap_landed()
	var s2 = script.new()
	root.add_child(s2)
	print("races=%d won=%d beers=%d traps=%d best=%.1f" % [s2.total_races, s2.races_won, s2.beers_owed, s2.traps_landed, s2.top_speed_ever])
	var ok: bool = s2.total_races == 2 and s2.races_won == 1 and s2.beers_owed == 1 and s2.traps_landed == 1 and absf(s2.top_speed_ever - 42.5) < 0.01
	s2.reset_stats()
	if ok:
		print("STATS_ROUND_TRIP_PASS")
		quit(0)
	else:
		print("STATS_ROUND_TRIP_FAIL")
		quit(1)
