# StatsManager.gd — Persistent career stats (Phase 8A)
# Autoload singleton. Persists to user://save.cfg via ConfigFile.
extends Node

const SAVE_PATH := "user://save.cfg"

var total_races: int = 0
var races_won: int = 0
var beers_owed: int = 0
var traps_landed: int = 0
var top_speed_ever: float = 0.0
var best_time: float = 0.0  # 0.0 = none yet (times are positive seconds)
## Layout-scoped bests (LevelLayouts id -> seconds). The three race layouts
## have different course lengths, so a single global PB is unbeatable on the
## longer maps once set on the shortest — per-layout is the honest record.
## The global best_time stays as the any-map overall.
var best_time_by_layout: Dictionary = {}

signal stats_updated

func _ready() -> void:
	load_stats()

func load_stats() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		total_races = int(config.get_value("stats", "total_races", 0))
		races_won = int(config.get_value("stats", "races_won", 0))
		beers_owed = int(config.get_value("stats", "beers_owed", 0))
		traps_landed = int(config.get_value("stats", "traps_landed", 0))
		top_speed_ever = float(config.get_value("stats", "top_speed_ever", 0.0))
		best_time = float(config.get_value("stats", "best_time", 0.0))
		var saved_layouts = config.get_value("stats", "best_time_by_layout", {})
		best_time_by_layout = saved_layouts.duplicate() if saved_layouts is Dictionary else {}
	else:
		reset_stats()

func reset_stats() -> void:
	total_races = 0
	races_won = 0
	beers_owed = 0
	traps_landed = 0
	top_speed_ever = 0.0
	best_time = 0.0
	best_time_by_layout = {}
	save_stats()

func record_race(won: bool, top_speed: float, traps: int) -> void:
	total_races += 1
	if won:
		races_won += 1
	else:
		beers_owed += 1
	traps_landed += traps
	top_speed_ever = maxf(top_speed_ever, top_speed)
	save_stats()

func get_win_rate() -> float:
	if total_races <= 0:
		return 0.0
	return float(races_won) / float(total_races)

## Record a finished race time. Returns true when it's a new personal
## best (including the first-ever finish). Nonpositive times are ignored —
## a 0s entry would poison the "no time yet" sentinel.
## With layout_id, the record verdict is scoped to that layout (what you
## were racing against); the global best_time tracks the any-map overall.
func record_finish_time(time_seconds: float, layout_id: String = "") -> bool:
	if time_seconds <= 0.0:
		return false
	var is_record := best_time <= 0.0 or time_seconds < best_time
	if is_record:
		best_time = time_seconds
	var is_layout_record := true
	if layout_id != "":
		var layout_best: float = float(best_time_by_layout.get(layout_id, 0.0))
		is_layout_record = layout_best <= 0.0 or time_seconds < layout_best
		if is_layout_record:
			best_time_by_layout[layout_id] = time_seconds
	if is_record or is_layout_record:
		save_stats()
	return is_layout_record if layout_id != "" else is_record

## Best finish for a layout (0.0 = none yet). Empty layout_id returns the
## global any-map best.
func get_best_time(layout_id: String = "") -> float:
	if layout_id == "":
		return best_time
	return float(best_time_by_layout.get(layout_id, 0.0))

func record_trap_landed() -> void:
	traps_landed += 1
	save_stats()

func get_summary_line() -> String:
	return "RACES %d   WINS %d   BEERS OWED %d   TRAPS %d   BEST %d km/h" % [
		total_races, races_won, beers_owed, traps_landed, int(top_speed_ever)
	]

func save_stats() -> void:
	var config := ConfigFile.new()
	config.set_value("stats", "total_races", total_races)
	config.set_value("stats", "races_won", races_won)
	config.set_value("stats", "beers_owed", beers_owed)
	config.set_value("stats", "traps_landed", traps_landed)
	config.set_value("stats", "top_speed_ever", top_speed_ever)
	config.set_value("stats", "best_time", best_time)
	config.set_value("stats", "best_time_by_layout", best_time_by_layout)
	config.save(SAVE_PATH)
	stats_updated.emit()
