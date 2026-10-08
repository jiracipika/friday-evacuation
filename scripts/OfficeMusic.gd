extends RefCounted
## OfficeMusic — composed loops for the soundtrack, synthesized at request
## time and cached by AudioManager. Zero external audio assets.
##
## MENU ("lobby radio", 92 BPM, 4 bars): soft Am7–Fmaj7–Cmaj7–G6 pads, slow
## sine bass roots, light offbeat ticks and a pentatonic sparkle pluck.
## RACE ("5PM evac groove", 122 BPM, 8 bars): an Am–D dorian vamp (i–IV–
## i–bVII) with four-floor kick, snare backbeat, offbeat hats, a syncopated
## funk bass with octave pops, square clav stabs, and a pentatonic lead riff
## that rides the second half of the form.
##
## Both render through one additive voice bank into 16-bit mono
## AudioStreamWAV loops; the last 5 ms fade so LOOP_FORWARD never clicks.

const RATE := 22050
const MASTER := 0.85

const KIND_SINE := 0
const KIND_SQUARE := 1
const KIND_TRI := 2
const KIND_HAT := 3
const KIND_KICK := 4
const KIND_SNARE := 5
const KIND_STAB := 6

const MENU_BPM := 92.0
const RACE_BPM := 122.0

## i–VI–III–VII with jazzy extensions for the lobby radio.
const MENU_CHORDS := [
	[57, 60, 64, 67], # Am7
	[53, 57, 60, 64], # Fmaj7
	[60, 64, 67, 71], # Cmaj7
	[55, 59, 62, 64], # G6
]
const MENU_ROOTS := [45, 41, 48, 43]

## Race vamp roots per bar: Am Am D D Am Am G G.
const RACE_ROOTS := [45, 45, 50, 50, 45, 45, 43, 43]
## Funk bass: per-eighth octave shifts (0 = root, 12 = octave pop).
const RACE_BASS_OCT := [0, 0, 12, 0, 0, 12, 0, 12]
## Lead riff (bars 5-8), A-minor pentatonic, eighth grid, 0 = rest.
const RACE_LEAD := [
	[69, 0, 72, 74, 0, 72, 69, 67], # Am
	[72, 0, 74, 76, 0, 74, 72, 69], # Am
	[74, 0, 77, 79, 0, 77, 74, 72], # D
	[79, 0, 76, 74, 0, 71, 74, 76], # G — hands back to the loop top
]


static func make_menu_loop() -> AudioStreamWAV:
	var eighth: float = 60.0 / MENU_BPM / 2.0
	var bar: float = eighth * 8.0
	var events: Array = []
	for b in range(4):
		var t0: float = b * bar
		for midi in MENU_CHORDS[b]:
			events.append([t0, bar, _hz(midi), 0.038, KIND_TRI, 0.7])
		events.append([t0, 1.1, _hz(MENU_ROOTS[b] - 12), 0.12, KIND_SINE, 0.02])
		events.append([t0 + 4.0 * eighth, 1.0, _hz(MENU_ROOTS[b] - 12), 0.1, KIND_SINE, 0.02])
		events.append([t0 + 3.0 * eighth, 0.05, 0.0, 0.035, KIND_HAT, 0.001])
		events.append([t0 + 7.0 * eighth, 0.05, 0.0, 0.035, KIND_HAT, 0.001])
		# Radio sparkle: two quiet plucks from the chord, deterministic.
		events.append([t0 + 2.0 * eighth, 0.4, _hz(MENU_CHORDS[b][b % 4] + 12), 0.05, KIND_TRI, 0.004])
		events.append([t0 + 5.0 * eighth, 0.4, _hz(MENU_CHORDS[b][(b + 2) % 4]), 0.045, KIND_TRI, 0.004])
	return _render(events, bar * 4.0)


static func make_race_loop() -> AudioStreamWAV:
	var eighth: float = 60.0 / RACE_BPM / 2.0
	var bar: float = eighth * 8.0
	var events: Array = []
	for b in range(8):
		var t0: float = b * bar
		for e in range(8):
			var t: float = t0 + e * eighth
			# Kick four-floor; the last bar pushes with an extra "and".
			if e % 2 == 0:
				events.append([t, 0.15, 0.0, 0.48, KIND_KICK, 0.001])
			elif b == 7 and e == 7:
				events.append([t, 0.12, 0.0, 0.4, KIND_KICK, 0.001])
			else:
				events.append([t, 0.05, 0.0, 0.08, KIND_HAT, 0.001])
			if e == 2 or e == 6:
				events.append([t, 0.13, 190.0, 0.21, KIND_SNARE, 0.001])
			# Funk bass: syncopated square with octave pops.
			events.append([t, eighth * 0.85, _hz(RACE_ROOTS[b] + RACE_BASS_OCT[e]), 0.15, KIND_SQUARE, 0.003])
			# Clav stabs on the "and of 1" and "and of 3".
			if e == 1 or e == 5:
				var root: int = RACE_ROOTS[b]
				for iv in [0, 7, 12]:
					events.append([t, eighth * 0.7, _hz(root + 12 + iv), 0.035, KIND_SQUARE, 0.002])
		# The riff rides the second half of the form.
		if b >= 4:
			for e in range(8):
				var midi: int = RACE_LEAD[b - 4][e]
				if midi > 0:
					var t: float = t0 + e * eighth
					events.append([t, eighth * 0.8, _hz(midi), 0.09, KIND_SQUARE, 0.003])
					events.append([t, eighth * 0.8, _hz(midi - 12), 0.04, KIND_SQUARE, 0.003])
	return _render(events, bar * 8.0)


static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


static func _render(events: Array, length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var mix := PackedFloat32Array()
	mix.resize(n)
	for ev in events:
		_add(mix, ev[0], ev[1], ev[2], ev[3], ev[4], ev[5])
	return _stream(mix)


## Additive voice bank: one note, straight into the mix buffer.
static func _add(mix: PackedFloat32Array, start: float, dur: float, freq: float,
		gain: float, kind: int, attack: float) -> void:
	var n := mix.size()
	var i0 := maxi(0, int(start * RATE))
	var i1 := mini(n, int((start + dur) * RATE))
	var ph := 0.0
	var ph2 := 0.0
	var prev_noise := 0.0
	var decay := 5.0
	match kind:
		KIND_SINE:
			decay = 2.0
		KIND_TRI:
			decay = 6.0
		KIND_HAT:
			decay = 55.0
		KIND_KICK:
			decay = 22.0
		KIND_SNARE:
			decay = 26.0
		KIND_STAB:
			decay = 14.0
	for i in range(i0, i1):
		var t := float(i - i0) / RATE
		var env := gain * minf(1.0, t / attack) * exp(-t * decay)
		var s := 0.0
		match kind:
			KIND_SINE:
				s = sin(TAU * ph)
				ph += freq / RATE
			KIND_SQUARE:
				s = 0.8 if fmod(ph, 1.0) < 0.5 else -0.8
				ph += freq / RATE
			KIND_TRI:
				s = 2.0 * absf(2.0 * fmod(ph, 1.0) - 1.0) - 1.0
				ph += freq / RATE
			KIND_HAT:
				var nz := randf() * 2.0 - 1.0
				s = nz - prev_noise
				prev_noise = nz
			KIND_KICK:
				var f := 150.0 * pow(45.0 / 150.0, minf(t / 0.1, 1.0))
				s = sin(ph2)
				ph2 += TAU * f / RATE
			KIND_SNARE:
				var nz2 := randf() * 2.0 - 1.0
				s = nz2 + 0.5 * sin(ph2)
				ph2 += TAU * 190.0 / RATE
			KIND_STAB:
				s = 0.8 if fmod(ph, 1.0) < 0.5 else -0.8
				ph += freq / RATE
		mix[i] += s * env


static func _stream(mix: PackedFloat32Array) -> AudioStreamWAV:
	var n := mix.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	# Fade the last 5 ms so LOOP_FORWARD wraps without a seam click.
	var fade := maxi(1, int(RATE * 0.005))
	for i in range(n):
		var v := clampf(mix[i] * MASTER, -1.0, 1.0)
		if i >= n - fade:
			v *= float(n - i) / fade
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	wav.data = bytes
	return wav
