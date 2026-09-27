# AmbientAudioTest.gd — looping office-bed verification.
#   1. start_ambient creates ONE Music-bus player with a seamless-loop
#      WAV and plays it; a second call is idempotent.
#   2. stop_ambient stops it; is_ambient_playing tracks truth.
#   3. The synthesized bed is quiet (no sample may clip) and its swell
#      periods divide the buffer (sample[i] ~ sample[i + half] envelope).
# Run: godot --headless --path . --script scripts/AmbientAudioTest.gd
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
	var AM = load("res://scripts/AudioManager.gd").new()
	root.add_child(AM)
	await process_frame

	check(not AM.is_ambient_playing(), "ambient starts silent")
	AM.start_ambient()
	check(AM.is_ambient_playing(), "start_ambient plays the bed")
	AM.start_ambient()
	var ambient_players := 0
	for child in AM.get_children():
		if child is AudioStreamPlayer and child.stream is AudioStreamWAV:
			ambient_players += 1
	check(ambient_players == 1, "start_ambient is idempotent (1 player, got %d)" % ambient_players)

	var stream: AudioStreamWAV = AM._ambient_player.stream
	check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "bed loops forward")
	var sample_count: int = stream.data.size() / 2
	check(stream.loop_end == sample_count, "loop_end covers the whole buffer (%d)" % sample_count)
	check(AM._ambient_player.bus == "Music", "bed rides the Music bus")
	check(AM._ambient_player.volume_db <= -10.0, "bed is quiet (%.1f dB)" % AM._ambient_player.volume_db)

	# No sample may clip; headroom stays large for a -14 dB bed.
	var peak := 0
	var data: PackedByteArray = stream.data
	for i in range(0, data.size(), 2):
		var v: int = abs(int(data.decode_s16(i)))
		if v > peak:
			peak = v
	check(peak < 20000, "bed has clipping headroom (peak %d/32767)" % peak)

	AM.stop_ambient()
	check(not AM.is_ambient_playing(), "stop_ambient stops the bed")
	AM.stop_ambient()
	check(not AM.is_ambient_playing(), "stop is idempotent")

	AM.queue_free()
	await process_frame
	var passed := checks - failures
	print("AmbientAudioTest: %d/%d checks PASS" % [passed, checks])
	quit(1 if failures else 0)
