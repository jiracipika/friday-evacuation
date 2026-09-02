extends Node

var sfx_volume: float = 0.8
var music_volume: float = 0.5
var _players: Array[AudioStreamPlayer] = []

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

func _ready() -> void:
	_ensure_buses()
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
		player.volume_db = linear_to_db(sfx_volume)
		player.stream = stream
		player.play()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	var bus = AudioServer.get_bus_index(SFX_BUS)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(sfx_volume))

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	var bus = AudioServer.get_bus_index(MUSIC_BUS)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(music_volume))

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
