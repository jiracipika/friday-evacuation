# VirtualPad.gd — debug virtual gamepad for pad-play QA without hardware.
#
# Enable by launching with `--virtual-pad` (OS.get_cmdline_user_args, i.e.
# `godot --path . -- --virtual-pad`) or the env var FE_VIRTUAL_PAD=1.
# Pumps REAL InputEventJoypadButton / InputEventJoypadMotion events into
# Godot's input pipeline on a scripted schedule, so every downstream
# system (InputMap, InputPrefs curves + scheme detection, PlayerChair,
# ControlsOverlay device flip) is exercised exactly as with a physical
# pad. This is NOT a fake: the events are identical to real hardware's.
#
# Demo loop (period ~14s):
#   0.0s  stick CENTER        (idle)
#   0.5s  stick FORWARD 1.0   (drive)
#   5.0s  button A press      (boost) / release 0.3s
#   6.0s  stick LEFT 0.7      (drift turn) until 9.5s
#   10.0s stick CENTER
#   11.0s button X press      (action/jump) / release 0.3s
#
# Mounted by Main.gd when the flag is present. Logs one line per phase
# so the run is auditable. Also flips InputPrefs' device tracker to
# controller via the real input path (no direct state writes).
extends Node

var _phase := -1
var _t := 0.0
var _active := false

const STICK_CENTER := Vector2(0, 0)
const STICK_FORWARD := Vector2(0, -1)
const STICK_LEFT := Vector2(-0.7, 0)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var enabled := "virtual-pad" in args or OS.get_environment("FE_VIRTUAL_PAD") == "1"
	if not enabled:
		set_process(false)
		return
	_active = true
	print("[VirtualPad] ACTIVE — scripted pad loop every ~14s")
	print("[VirtualPad] connected pads (before): ", Input.get_connected_joypads())

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	var prev := _phase
	# Phase schedule within a 14s loop.
	var t := fmod(_t, 14.0)
	if t < 0.5:
		_phase = 0
	elif t < 5.0:
		_phase = 1
	elif t < 5.3:
		_phase = 2
	elif t < 6.0:
		_phase = 3
	elif t < 9.5:
		_phase = 4
	elif t < 10.0:
		_phase = 5
	elif t < 10.3:
		_phase = 6
	elif t < 11.0:
		_phase = 7
	else:
		_phase = 8
	if _phase == prev:
		return
	match _phase:
		0:
			_stick(STICK_CENTER)
			print("[VirtualPad] phase 0: stick center")
		1:
			_stick(STICK_FORWARD)
			print("[VirtualPad] phase 1: stick FORWARD (drive)")
		2:
			_button(JOY_BUTTON_A, true)
			print("[VirtualPad] phase 2: A down (boost)")
		3:
			_button(JOY_BUTTON_A, false)
			print("[VirtualPad] phase 3: A up")
		4:
			_stick(STICK_LEFT)
			print("[VirtualPad] phase 4: stick LEFT 0.7 (drift)")
		5:
			_stick(STICK_CENTER)
			print("[VirtualPad] phase 5: stick center")
		6:
			_button(JOY_BUTTON_X, true)
			print("[VirtualPad] phase 6: X down (jump)")
		7:
			_button(JOY_BUTTON_X, false)
			print("[VirtualPad] phase 7: X up")
		8:
			print("[VirtualPad] phase 8: loop complete — restarting")

## Emit left-stick motion as two axis events (x + y), like real hardware.
func _stick(v: Vector2) -> void:
	_motion(JOY_AXIS_LEFT_X, v.x)
	_motion(JOY_AXIS_LEFT_Y, v.y)

func _motion(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0  # device id 0 = "the pad" (Godot accepts unconnected ids)
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)

func _button(index: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index
	ev.pressed = pressed
	Input.parse_input_event(ev)
