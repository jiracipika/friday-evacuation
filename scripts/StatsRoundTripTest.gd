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

	# --- audio volume path (bug hunt 2): bus-only, no double-apply -------
	var am = load("res://scripts/AudioManager.gd").new()
	root.add_child(am)
	am.set_sfx_volume(0.5)
	am.set_music_volume(0.0)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_db := AudioServer.get_bus_volume_db(sfx_bus) if sfx_bus >= 0 else 0.0
	var expected_db := linear_to_db(0.5)
	# linear_to_db + db_to_linear round-trips a float32 exactly; compare
	# linear values, not dB (0.5000001 != 0.5 at float32 precision).
	var sfx_linear := db_to_linear(sfx_db)
	var audio_ok: bool = absf(sfx_linear - 0.5) < 0.001
	var mute_ok: bool = sfx_bus < 0 or (not AudioServer.is_bus_mute(sfx_bus))
	var zero_ok: bool = music_bus < 0 or AudioServer.is_bus_mute(music_bus)
	am.set_music_volume(0.7)
	var music_unmute_ok: bool = music_bus < 0 or (not AudioServer.is_bus_mute(music_bus))
	if not (audio_ok and mute_ok and zero_ok and music_unmute_ok):
		print("AUDIO BUS: sfx_linear=%f expected~0.5 mute_sfx=%s mute_music_at_zero=%s unmute=%s" % [
			sfx_linear, str(not mute_ok), str(zero_ok), str(music_unmute_ok)])

	# --- PB time (2026-09-26 batch): sentinel + record semantics ----------
	s2.reset_stats()
	var first_is_record: bool = s2.record_finish_time(74.5)
	var no_record: bool = s2.record_finish_time(80.0)
	var beat_record: bool = s2.record_finish_time(70.2)
	var zero_ignored: bool = s2.record_finish_time(0.0)
	var negative_ignored: bool = s2.record_finish_time(-5.0)
	var pb_ok: bool = first_is_record and (not no_record) and beat_record \
		and (not zero_ignored) and (not negative_ignored) \
		and absf(s2.best_time - 70.2) < 0.01
	if not pb_ok:
		print("PB TIME: first=%s slower=%s faster=%s zero=%s neg=%s best=%f" % [
			first_is_record, no_record, beat_record, zero_ignored, negative_ignored, s2.best_time])
	s2.reset_stats()
	if ok and audio_ok and mute_ok and zero_ok and music_unmute_ok and pb_ok:
		print("STATS_ROUND_TRIP_PASS")
		quit(0)
	else:
		print("STATS_ROUND_TRIP_FAIL")
		quit(1)
