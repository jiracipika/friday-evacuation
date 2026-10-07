# CoreAudioSmokeTest.gd — core-event SFX gap-fill verification (2026-10-05).
#   1. Every core-event voice generates a valid 16-bit PCM stream: non-empty
#      audible samples, 22050 mix rate, within duration caps (<=0.5s for
#      blips/stings, <=2s for the defeat jingle).
#   2. Distinct motifs: win vs lose stream data differs; countdown tick vs
#      GO horn differs; no two core voices share identical bytes.
#   3. Volume gating mirrors the existing bus-level scheme: set_sfx_volume(0)
#      mutes the SFX bus, playback still routes through an AudioStreamPlayer
#      (bus-only gating, no per-player dB), and 0.8 restores bus levels.
#   4. Wiring guards (text-level, ChairSkinSmokeTest pattern): the mode
#      scripts actually call the new voices through AudioManager.
# Run: godot --headless --path . --script scripts/CoreAudioSmokeTest.gd
extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + description)

func _peak(data: PackedByteArray) -> int:
	var peak := 0
	for i in range(0, data.size(), 2):
		var v: int = abs(int(data.decode_s16(i)))
		if v > peak:
			peak = v
	return peak

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var AM = load("res://scripts/AudioManager.gd").new()
	root.add_child(AM)
	await process_frame

	# --- 1. stream generation (name -> duration cap) ---------------------
	var caps := {
		"go_horn": 0.5, "defeat": 2.0, "countdown_tick": 0.5,
		"ui_click": 0.5, "recover": 0.5, "low_time": 0.5,
		"victory": 2.0,
	}
	var streams := {}
	for voice in caps:
		var stream: AudioStreamWAV = AM._make_effect(voice, 1.0)
		streams[voice] = stream
		check(stream != null, voice + " generates a stream")
		if stream == null:
			continue
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS,
			voice + " is 16-bit PCM")
		check(stream.mix_rate == 22050, voice + " mixes at 22050")
		var samples: int = stream.data.size() / 2
		var seconds := float(samples) / float(stream.mix_rate)
		check(samples > 0, voice + " has non-empty samples")
		check(seconds <= caps[voice],
			voice + " within duration cap (%.2fs <= %.1fs)" % [seconds, caps[voice]])
		check(_peak(stream.data) > 100,
			voice + " is audible (peak %d)" % _peak(stream.data))
		check(_peak(stream.data) <= 31000,
			voice + " has clipping headroom (peak %d)" % _peak(stream.data))

	# --- 2. distinct motifs ----------------------------------------------
	check(streams["victory"].data != streams["defeat"].data,
		"win vs lose motifs differ")
	check(streams["countdown_tick"].data != streams["go_horn"].data,
		"countdown tick vs GO horn differ")
	var core: Array = caps.keys()
	var distinct := true
	for i in range(core.size()):
		for j in range(i + 1, core.size()):
			if streams[core[i]].data == streams[core[j]].data:
				distinct = false
				print("  identical: " + str(core[i]) + " vs " + str(core[j]))
	check(distinct, "no two core voices share identical waveform bytes")
	# Defeat must descend where victory ascends: victory is stepped UP from
	# 330 Hz, defeat stepped DOWN from 523.25 Hz — assert the synthesis math
	# via frequency probes at the start of each stream.
	var vic_start := _dominant_start(streams["victory"])
	var def_start := _dominant_start(streams["defeat"])
	check(vic_start < def_start,
		"victory starts lower than defeat (win ascends, lose descends)")

	# --- 3. mute/volume gating (bus-level, mirrors existing scheme) ------
	var sfx_bus := AudioServer.get_bus_index("SFX")
	check(sfx_bus >= 0, "SFX bus exists")
	AM.set_sfx_volume(0.0)
	check(AudioServer.is_bus_mute(sfx_bus), "volume 0 mutes the SFX bus")
	AM.play_sfx("ui_click", 1.0)
	var routed := false
	for child in AM.get_children():
		if child is AudioStreamPlayer and child.playing and child.stream != null:
			routed = true
	check(routed, "play_sfx at volume 0 still routes through a player (bus-gated)")
	var per_player_db_zero := true
	for child in AM.get_children():
		if child is AudioStreamPlayer and child.stream != null:
			if child.bus != "SFX" or absf(child.volume_db) > 0.001:
				per_player_db_zero = false
	check(per_player_db_zero, "gating is bus-only (no per-player dB)")
	AM.set_sfx_volume(0.8)
	check(not AudioServer.is_bus_mute(sfx_bus), "volume 0.8 unmutes the SFX bus")
	check(absf(AudioServer.get_bus_volume_db(sfx_bus) - linear_to_db(0.8)) < 0.01,
		"bus volume tracks set_sfx_volume")

	# --- 4. wiring guards (text-level, like ChairSkinSmokeTest) ----------
	var ev = FileAccess.open("res://scripts/Evacuation.gd", FileAccess.READ)
	var ev_text: String = ev.get_as_text() if ev else ""
	check("countdown_tick" in ev_text, "Evacuation wires countdown ticks")
	check("go_horn" in ev_text, "Evacuation wires the GO horn")
	check("low_time" in ev_text, "Evacuation wires the low-time warning")
	check("defeat" in ev_text, "Evacuation wires the defeat sting")
	var pc = FileAccess.open("res://scripts/PlayerChair.gd", FileAccess.READ)
	var pc_text: String = pc.get_as_text() if pc else ""
	check("recover" in pc_text, "PlayerChair wires the stun-recover chirp")
	var mn = FileAccess.open("res://scripts/Main.gd", FileAccess.READ)
	var mn_text: String = mn.get_as_text() if mn else ""
	check("ui_click" in mn_text, "Main wires menu clicks to ui_click")

	AM.queue_free()
	await process_frame
	var passed := checks - failures
	print("CoreAudioSmokeTest: %d/%d checks PASS" % [passed, checks])
	quit(1 if failures else 0)

## Rough opening-pitch probe: zero crossings per second over the first
## eighth of the stream — victory (330 Hz stepped) must cross less often
## than defeat's opening (523.25 Hz).
func _dominant_start(stream: AudioStreamWAV) -> int:
	var data: PackedByteArray = stream.data
	var n: int = data.size() / 2 / 8
	var crossings := 0
	var prev := 0
	for i in range(n):
		var v := data.decode_s16(i * 2)
		if i > 0 and (v >= 0) != (prev >= 0):
			crossings += 1
		prev = v
	return crossings
