extends Node

var sfx_volume: float = 0.8
var music_volume: float = 0.5
var _players: Array[AudioStreamPlayer] = []

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

func _ready() -> void:
	_ensure_buses()
	# Apply the defaults to the actual buses at boot. Without this the
	# SFX/Music buses sit at Godot's 0 dB default until the player opens
	# the Settings screen, so saved volume prefs were ignored every session.
	set_sfx_volume(sfx_volume)
	set_music_volume(music_volume)
	for i in range(6):
		var player = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)

func _ensure_buses() -> void:
	if AudioServer.get_bus_index(SFX_BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, SFX_BUS)
	if AudioServer.get_bus_index(MUSIC_BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, MUSIC_BUS)

func play_sfx(effect_name: String, intensity: float = 1.0) -> void:
	var player = _next_player()
	if not player:
		return
	var stream = _make_effect(effect_name, clampf(intensity, 0.2, 2.0))
	if stream:
		# Bus-only volume: set_*_volume already carries the master×category
		# product on the SFX bus. Per-player dB here would square it.
		player.volume_db = 0.0
		player.stream = stream
		player.play()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	var bus = AudioServer.get_bus_index(SFX_BUS)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(sfx_volume, 0.0001)))
		AudioServer.set_bus_mute(bus, sfx_volume <= 0.0)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	var bus = AudioServer.get_bus_index(MUSIC_BUS)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(music_volume, 0.0001)))
		AudioServer.set_bus_mute(bus, music_volume <= 0.0)

func _next_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return _players[0] if not _players.is_empty() else null

func _make_effect(effect_name: String, intensity: float) -> AudioStream:
	var duration = 0.18
	match effect_name:
		"boost": duration = 0.34
		"flush": duration = 0.6
		"jump": duration = 0.20
		"land": duration = 0.14
		"trap": duration = 0.38
		"powerup": duration = 0.24
		"go_horn": duration = 0.5
		"victory": duration = 0.75
		"defeat": duration = 0.9
		"countdown_tick": duration = 0.12
		"ui_click": duration = 0.06
		"recover": duration = 0.12
		"low_time": duration = 0.45
		"wall_bonk": duration = 0.08
		_: duration = 0.12
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var data = PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var frequency = 440.0
		var amplitude = 0.22 * intensity
		match effect_name:
			"boost":
				frequency = lerpf(180.0, 70.0, progress)
				amplitude *= 1.0 - progress
			"flush":
				# Bubbling swoosh: warbling mid band rising into a
				# gurgle tail, like water spiraling down a drain.
				frequency = lerpf(320.0, 90.0, progress) + sin(t * 47.0) * 40.0
				amplitude *= sin(PI * minf(progress * 1.4, 1.0)) * 0.85
				amplitude += (1.0 - progress) * 0.1 * intensity
			"jump":
				frequency = lerpf(220.0, 720.0, progress)
				amplitude *= 1.0 - progress
			"land":
				frequency = lerpf(110.0, 55.0, progress)
				amplitude *= exp(-10.0 * progress)
			"trap":
				frequency = lerpf(520.0, 120.0, progress)
				amplitude *= sin(PI * progress) * 0.9
			"powerup":
				frequency = 620.0 if progress < 0.5 else 930.0
				amplitude *= sin(PI * progress)
			"go_horn":
				frequency = 220.0 + progress * 55.0
			"victory":
				frequency = 330.0 + floor(progress * 4.0) * 110.0
				amplitude *= sin(PI * progress)
			"defeat":
				# Descending 4-step arpeggio — the mirror of victory's
				# ascending 330/440/550/660, so win/lose are assertably
				# distinct motifs (523→436→349→262 over a longer window).
				frequency = 523.25 - floor(progress * 4.0) * 87.0
				amplitude *= sin(PI * progress)
			"countdown_tick":
				# Flat-pitch blip with a fast decay; same pitch every tick,
				# while GO! (go_horn) sits a full octave-plus lower.
				frequency = 660.0
				amplitude *= exp(-14.0 * progress)
			"ui_click":
				# Menu tick: much shorter and brighter than a countdown
				# blip so clicks never read as race countdowns.
				frequency = 1150.0
				amplitude *= exp(-40.0 * progress)
			"recover":
				# Un-stun chirp: quick upward sweep, bell-shaped — narrower
				# and higher than the jump sweep (220→720 over 0.2s).
				frequency = lerpf(500.0, 880.0, progress)
				amplitude *= sin(PI * progress) * 0.8
			"low_time":
				# Urgent double-beep at 880 Hz with a silent gap; the
				# on/off gate is the motif — no other voice gates like this.
				frequency = 880.0
				var gated := progress < 0.28 or (progress > 0.44 and progress < 0.72)
				amplitude *= (0.9 if gated else 0.04) * (1.0 - 0.3 * progress)
			"wall_bonk":
				frequency = 90.0
				amplitude *= 1.0 - progress
		var sample = sin(TAU * frequency * t) * amplitude
		# Add a tiny transient for tactile impacts.
		if effect_name in ["land", "wall_bonk"]:
			sample += (1.0 if i % 2 == 0 else -1.0) * amplitude * 0.12 * (1.0 - progress)
		var pcm = int(clampi(roundi(sample * 32767.0), -32768, 32767))
		data[i * 2] = pcm & 0xff
		data[i * 2 + 1] = (pcm >> 8) & 0xff
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

# --- S-AMBIENT: looping office bed under races (2026-09-26) --------------

var _ambient_player: AudioStreamPlayer = null

## Seamless ~4s HVAC/fluorescent bed: two detuned low sines + shaped air
## noise + a quiet 7.3kHz shimmer, looped forward. Swell periods divide
## the buffer so the loop point is inaudible.
func _make_ambient() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 4.0
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var swell := 0.8 + 0.2 * sin(TAU * t / duration * 2.0)
		var hum := (sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 58.0 * t) * 0.35) * 0.06
		var air := (rng.randf() * 2.0 - 1.0) * 0.012
		var shimmer := sin(TAU * 7300.0 * t) * 0.004 * (0.5 + 0.5 * sin(TAU * t / duration * 5.0))
		var sample := (hum + air + shimmer) * swell
		var pcm := int(clampi(roundi(sample * 32767.0), -32768, 32767))
		data[i * 2] = pcm & 0xff
		data[i * 2 + 1] = (pcm >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = data
	return stream

## Start the ambience — rides the Music bus (a bed, not an effect).
## Idempotent; safe when called from every mode's _ready.
func start_ambient() -> void:
	if _ambient_player and _ambient_player.playing:
		return
	if _ambient_player == null:
		_ambient_player = AudioStreamPlayer.new()
		_ambient_player.bus = MUSIC_BUS
		_ambient_player.volume_db = -14.0
		add_child(_ambient_player)
		_ambient_player.stream = _make_ambient()
	_ambient_player.play()

func stop_ambient() -> void:
	if _ambient_player and _ambient_player.playing:
		_ambient_player.stop()

func is_ambient_playing() -> bool:
	return _ambient_player != null and _ambient_player.playing
