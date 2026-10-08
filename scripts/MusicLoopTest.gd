# MusicLoopTest.gd — composed soundtrack verification (menu theme + race groove).
#   1. Both loops synthesize as seamless LOOP_FORWARD WAVs and actually sound.
#   2. start_music("menu"/"race") drives ONE Music-bus player; kinds swap the
#      stream; same-kind calls are idempotent.
#   3. stop_music stops it; is_music_playing(kind) tracks truth.
#   4. The Music bus volume chain still governs audibility (mute at 0).
# Run: godot --headless --path . --script scripts/MusicLoopTest.gd
extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + description)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var music = load("res://scripts/OfficeMusic.gd")
	var menu: AudioStreamWAV = music.make_menu_loop()
	var race: AudioStreamWAV = music.make_race_loop()
	check(menu != null and race != null, "both loops synthesize")
	check(menu.loop_mode == AudioStreamWAV.LOOP_FORWARD and race.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"loops are LOOP_FORWARD")
	var menu_secs: float = menu.data.size() / 2.0 / menu.mix_rate
	var race_secs: float = race.data.size() / 2.0 / race.mix_rate
	check(menu_secs >= 8.0, "menu theme runs at least 8s (%.1f)" % menu_secs)
	check(race_secs >= 14.0, "race groove runs at least 14s (%.1f)" % race_secs)
	check(_peak(menu.data) > 2000 and _peak(menu.data) < 30000,
			"menu theme sounds with headroom (peak %d)" % _peak(menu.data))
	check(_peak(race.data) > 6000 and _peak(race.data) < 30000,
			"race groove sounds with headroom (peak %d)" % _peak(race.data))
	check(absi(race.data.decode_s16(race.data.size() - 2)) < 900,
			"race tail fades so the wrap never clicks")

	var AM = load("res://scripts/AudioManager.gd").new()
	root.add_child(AM)
	await process_frame

	check(not AM.is_music_playing(), "music starts silent")
	check(not AM.is_ambient_playing(), "music API leaves the ambient bed alone")
	AM.start_music("menu")
	check(AM.is_music_playing("menu"), "menu theme plays")
	check(AM._music_player.bus == "Music", "theme rides the Music bus")
	check(AM._music_kind == "menu", "player tracks the menu kind")
	AM.start_music("menu")
	check(AM.is_music_playing("menu"), "same-kind start is idempotent")
	AM.start_music("race")
	check(AM.is_music_playing("race"), "race groove takes over from the theme")
	check(AM._music_player.stream != null and AM._music_kind == "race", "stream swapped with the kind")
	var music_players := 0
	for child in AM.get_children():
		# The 6 pooled SFX players carry a null stream until first use; the
		# only stream-bearing non-ambient player should be the music one.
		if child is AudioStreamPlayer and child != AM._ambient_player and child.stream != null:
			music_players += 1
	check(music_players == 1, "exactly one stream-bearing music player (got %d)" % music_players)
	AM.stop_music()
	check(not AM.is_music_playing(), "stop_music stops playback")
	check(AM._music_kind == "", "stop clears the kind")
	AM.stop_music()
	check(not AM.is_music_playing(), "stop is idempotent")

	AM.set_music_volume(0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),
			"music volume 0 mutes the Music bus")
	AM.set_music_volume(0.5)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),
			"restoring volume unmutes the bus")

	AM.queue_free()
	await process_frame
	var passed := checks - failures
	print("MusicLoopTest: %d/%d checks PASS" % [passed, checks])
	quit(1 if failures else 0)

func _peak(data: PackedByteArray) -> int:
	var peak := 0
	for i in range(0, data.size(), 2):
		var v: int = absi(data.decode_s16(i))
		if v > peak:
			peak = v
	return peak
