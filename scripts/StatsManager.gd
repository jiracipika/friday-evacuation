# StatsManager.gd — Persistent career stats (Phase 8A)
# Autoload singleton. Persists to user://save.cfg via ConfigFile.
extends Node

const SAVE_PATH := "user://save.cfg"

var total_races: int = 0
var races_won: int = 0
var beers_owed: int = 0
var traps_landed: int = 0
var top_speed_ever: float = 0.0

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
	else:
		reset_stats()

func reset_stats() -> void:
	total_races = 0
	races_won = 0
	beers_owed = 0
	traps_landed = 0
	top_speed_ever = 0.0
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
	config.save(SAVE_PATH)
	stats_updated.emit()
