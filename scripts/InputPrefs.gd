# InputPrefs.gd — keyboard/mouse/controller input preferences.
#
# Single source of truth for steering sensitivity, mouse look, and
# controller quality-of-life prefs. Persisted in user://settings.cfg
# (section "input") alongside the Settings screen values.
#
# Static-only on purpose (mirrors Accessibility.gd): readable from any
# script without node wiring, and standalone-compilable for raw
# SceneTree tests. The Settings screen writes through set_setting();
# PlayerChair/Evacuation read through the typed getters.
#
# Sensitivity model:
#   The chair is a target-velocity controller (move_toward at
#   `acceleration`). Steering response scales LINEARLY with
#   keyboard_sensitivity over [0.15 .. 1.5]; 1.0 = the original shipped
#   feel. The user asked for a LOWER default THREE times (1.0 -> 0.7 ->
#   0.55 -> 0.35), so KEYBOARD_DEFAULT is 0.35 — acceleration ~12
#   (34 * 0.35), gentle turn-in without touching top speed. Controller
#   play runs at full acceleration: the analog stick IS the finesse
#   control there.
class_name InputPrefs
extends RefCounted

## Test seam: overridable so smoke tests never clobber the real save.
static var CFG_PATH := "user://settings.cfg"

const SECTION := "input"

# --- persisted keys -------------------------------------------------------
const KEY_KB_SENS := "keyboard_sensitivity"      # 0.15 .. 1.5 (1.0 = old feel)
const KEY_MOUSE_LOOK := "mouse_look_enabled"     # bool
const KEY_MOUSE_SENS := "mouse_sensitivity"      # 0.25 .. 2.0 (0.8 default)
const KEY_STICK_LOOK := "stick_look_enabled"     # right-stick camera orbit
const KEY_STICK_SENS := "stick_sensitivity"      # 0.25 .. 2.0 (0.8 default)
const KEY_VIBRATION := "vibration_enabled"       # controller rumble
const KEY_SCHEME := "control_scheme"             # auto|keyboard_mouse|controller
const KEY_PAD_MAP := "pad_button_map"            # action -> joypad button index
const KEY_INVERT := "invert_camera_x"            # mirrored camera pan
const KEY_TOUCH := "touch_controls"              # auto|on|off (web/mobile UI)

# --- defaults ---------------------------------------------------------------
# Keyboard deliberately LOWER than 1.0: the pre-settings feel (accel 34)
# read twitchy to new players. 0.35 -> accel ~12 keeps full top speed but
# makes turn-in genuinely gentle (user asked THREE times: 1.0 -> 0.7 ->
# 0.55 -> 0.35). Mouse/stick look default 0.8: same "a notch gentler"
# reasoning, and the range still reaches the old 1.0 feel if a player
# wants it back.
const KEYBOARD_DEFAULT := 0.35
const KEYBOARD_MIN := 0.15
const KEYBOARD_MAX := 1.5
const MOUSE_DEFAULT := 0.8
const MOUSE_MIN := 0.25
const MOUSE_MAX := 2.0
const STICK_DEFAULT := 0.8
const STICK_MIN := 0.25
const STICK_MAX := 2.0

# --- control scheme ---------------------------------------------------------
# "auto" switches whichscheme() reports whenever the player actually
# touches the other device — whatever they grab last round is what they
# get this round, remembered in the cfg. Manual modes pin one scheme.
const SCHEME_AUTO := &"auto"
const SCHEME_KEYBOARD := &"keyboard_mouse"
const SCHEME_CONTROLLER := &"controller"

## Default joypad button per action (Godot joy button indices: 0=A/Cross,
## 1=B/Circle, 2=X/Square, 3=Y/Triangle, 6=Start, 7=Options.. 9/10=L/R
## shoulder, 13/14=L/R dpad). Mirrors the project.godot InputMap defaults.
const DEFAULT_PAD_MAP := {
	"boost": 0,
	"action": 2,
	"sabotage": 1,
	"pause": 6,
	"recenter_camera": 3,
}

## Camera yaw state lives HERE (not in the chair) because the camera
## follows chair facing — the offset must be applied by the mode scene's
## camera rig. Chair writes, Evacuation reads. Radians, unbounded wrap.
static var camera_yaw_offset := 0.0

## Per-device sensitivity multiplier, cached at race start so a
## mid-race settings change applies next race (avoids mid-race feel pop).
static var keyboard_scale := KEYBOARD_DEFAULT

## Live caches for per-event reads (mouse motion fires hundreds of times
## per second — never ConfigFile.load inside the handler). Refreshed by
## refresh_cache() at mode start and whenever Settings saves.
static var _mouse_look_on := true
static var _mouse_sens := MOUSE_DEFAULT
static var _stick_look_on := true
static var _stick_sens := STICK_DEFAULT
static var _invert_x := false

## Control-scheme memory. _scheme_mode is the persisted player choice
## (AUTO by default); _last_device tracks whichever device was touched
## last so AUTO follows the player's hands. Both survive restarts —
## _last_device is persisted whenever it flips (see note_device).
static var _scheme_mode: StringName = SCHEME_AUTO
static var _last_device: StringName = SCHEME_KEYBOARD
static var _last_device_dirty := false  # cfg write pending (avoid IO in input handlers)


## Sync the per-event caches from the cfg. Cheap; call on mode _ready
## and whenever the Settings screen applies (pause-menu changes then
## take effect immediately on resume).
static func refresh_cache() -> void:
	migrate_defaults()
	_mouse_look_on = mouse_look_enabled()
	_mouse_sens = mouse_sensitivity()
	_stick_look_on = stick_look_enabled()
	_stick_sens = stick_sensitivity()
	_invert_x = invert_camera_x()
	keyboard_scale = keyboard_sensitivity()
	var raw_scheme: Variant = get_setting(KEY_SCHEME, SCHEME_AUTO)
	_scheme_mode = raw_scheme if raw_scheme is StringName or raw_scheme is String else SCHEME_AUTO
	if _scheme_mode != SCHEME_AUTO and _scheme_mode != SCHEME_KEYBOARD and _scheme_mode != SCHEME_CONTROLLER:
		_scheme_mode = SCHEME_AUTO
	var raw_device: Variant = get_setting(KEY_LAST_DEVICE, SCHEME_KEYBOARD)
	_last_device = raw_device if raw_device is StringName or raw_device is String else SCHEME_KEYBOARD
	apply_pad_map_to_input_map()

## One-time migrations to lower sensitivity defaults. Only values still
## sitting EXACTLY on an old default move — anything the player
## personalized is left alone. v2: 0.7 -> 0.55. v3: 0.55 -> 0.35 (user
## asked for gentler turn-in a third time). Each flag fires once per save.
const KEY_MIGRATED := "sens_migration_v2"
const KEY_MIGRATED_V3 := "sens_migration_v3"
const KEY_LAST_DEVICE := "last_device"

static func migrate_defaults() -> void:
	var config := _cfg()
	if not _as_bool(config.get_value(SECTION, KEY_MIGRATED, false), false):
		if is_equal_approx(float(config.get_value(SECTION, KEY_KB_SENS, 0.7)), 0.7):
			config.set_value(SECTION, KEY_KB_SENS, 0.55)
		if is_equal_approx(float(config.get_value(SECTION, KEY_MOUSE_SENS, 1.0)), 1.0):
			config.set_value(SECTION, KEY_MOUSE_SENS, MOUSE_DEFAULT)
		if is_equal_approx(float(config.get_value(SECTION, KEY_STICK_SENS, 1.0)), 1.0):
			config.set_value(SECTION, KEY_STICK_SENS, STICK_DEFAULT)
		config.set_value(SECTION, KEY_MIGRATED, true)
		config.save(CFG_PATH)
	# v3: re-run migrate_defaults() from any state — a save that JUST did
	# v2 in the same call also gets v3 in the same call.
	if not _as_bool(config.get_value(SECTION, KEY_MIGRATED_V3, false), false):
		if is_equal_approx(float(config.get_value(SECTION, KEY_KB_SENS, KEYBOARD_DEFAULT)), 0.55):
			config.set_value(SECTION, KEY_KB_SENS, KEYBOARD_DEFAULT)
		config.set_value(SECTION, KEY_MIGRATED_V3, true)
		config.save(CFG_PATH)

# --- control scheme ---------------------------------------------------------

## The persisted player choice: AUTO (follow last device), or a pinned
## KEYBOARD / CONTROLLER scheme.
static func scheme_mode() -> StringName:
	return _scheme_mode

static func set_scheme_mode(mode: StringName) -> void:
	_scheme_mode = mode
	set_setting(KEY_SCHEME, String(mode))

## Feed every input event you see through here (mode _unhandled_input,
## first line). AUTO then always reports whichever device the player is
## actually holding; manual pins ignore it. Stick drift and sub-pixel
## mouse jitter are filtered so a resting pad never flips the scheme.
static func note_device(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		if absf(event.axis_value) >= 0.25:
			_set_last_device(SCHEME_CONTROLLER)
	elif event is InputEventJoypadButton:
		if event.pressed:
			_set_last_device(SCHEME_CONTROLLER)
	elif event is InputEventKey:
		if event.pressed:
			_set_last_device(SCHEME_KEYBOARD)
	elif event is InputEventMouseButton:
		_set_last_device(SCHEME_KEYBOARD)

static func _set_last_device(device: StringName) -> void:
	if _last_device == device:
		return
	_last_device = device
	_last_device_dirty = true
	call_deferred_flush_device()

## Persist the device flip outside the input event (cfg IO in an input
## handler would stutter the frame). Static-safe: no node needed.
static func call_deferred_flush_device() -> void:
	if not _last_device_dirty:
		return
	_last_device_dirty = false
	set_setting(KEY_LAST_DEVICE, String(_last_device))

## What the game should assume RIGHT NOW: the pinned scheme, or under
## AUTO whatever device was used last (persisted across sessions).
static func which_scheme() -> StringName:
	return _scheme_mode if _scheme_mode != SCHEME_AUTO else _last_device

static func is_controller_active() -> bool:
	return which_scheme() == SCHEME_CONTROLLER

## Acceleration scale for PlayerChair. Keyboard play gets the gentler
## tuned scale; controller play runs FULL acceleration because the
## analog stick is already the finesse control.
static func active_keyboard_scale() -> float:
	return 1.0 if is_controller_active() else keyboard_scale

# --- stick response curves (Phase 3) -----------------------------------------

## Keys/consts for the three curve shapes. LINEAR = raw; EXPO = gentle
## center for precision, strong edge for full-speed racing (racing
## default); PRECISION = strong center dial-in, softer edges.
const CURVE_LINEAR := "linear"
const CURVE_EXPO := "expo"
const CURVE_PRECISION := "precision"
const KEY_STICK_CURVE := "stick_response_curve"

## Reshape an analog magnitude [0..1]. vector must already have deadzone
## applied (Input.get_vector does this).
static func apply_stick_curve(strength: float) -> float:
	var s := clampf(strength, 0.0, 1.0)
	match _stick_curve_mode():
		CURVE_EXPO:
			# v = s^2 blended 55% with linear: gentle center, full edge.
			return s * 0.45 + s * s * 0.55
		CURVE_PRECISION:
			# inverse-expo: fast response near center, softer top end.
			return s * 0.30 + sqrt(s) * 0.70
		_:
			return s

static func _stick_curve_mode() -> String:
	var raw: Variant = get_setting(KEY_STICK_CURVE, CURVE_EXPO)
	var mode := str(raw)
	if mode != CURVE_LINEAR and mode != CURVE_EXPO and mode != CURVE_PRECISION:
		return CURVE_EXPO
	return mode

static func stick_curve() -> String:
	return _stick_curve_mode()

static func set_stick_curve(mode: String) -> void:
	if mode != CURVE_LINEAR and mode != CURVE_EXPO and mode != CURVE_PRECISION:
		return
	set_setting(KEY_STICK_CURVE, mode)

# --- rumble vocabulary (Phase 3) ---------------------------------------------
# Distinct feel per event family instead of one generic thump:
#   hum     — boost burn: low long motor, soft
#   thump   — impacts/stun: both motors, sharp
#   sputter — trap scrapes/landing: low motor, stuttery short pulses
#   chirp   — UI/pickup: high motor, very short and light

static func rumble_hum(duration := 0.45) -> void:
	_vibrate(clampf(duration, 0.1, 1.2), 0.35, 0.0)

# --- touch controls (web jump-right-in) ---------------------------------------

const TOUCH_AUTO := "auto"
const TOUCH_ON := "on"
const TOUCH_OFF := "off"

## Touch mode: auto resolves to ON on mobile/web-with-touchscreen, else
## OFF. Manual "on"/"off" pins it (desktop preview, tablets with keyboards).
static func touch_mode() -> String:
	var raw: Variant = get_setting(KEY_TOUCH, TOUCH_AUTO)
	var mode := str(raw)
	if mode == TOUCH_ON or mode == TOUCH_OFF:
		return mode
	return TOUCH_AUTO

static func set_touch_mode(mode: String) -> void:
	if mode != TOUCH_AUTO and mode != TOUCH_ON and mode != TOUCH_OFF:
		return
	set_setting(KEY_TOUCH, mode)

## The decision MobileControls consults. Web builds (and mobile) with a
## touchscreen auto-enable; desktop stays off unless pinned on. FE_TOUCH=1
## keeps overriding everything for headless tests.
static func touch_enabled() -> bool:
	if OS.get_environment("FE_TOUCH") == "1":
		return true
	var mode := touch_mode()
	if mode == TOUCH_ON:
		return true
	if mode == TOUCH_OFF:
		return false
	# AUTO: touch devices self-select.
	if OS.has_feature("web") or OS.get_name() in ["Android", "iOS"]:
		return DisplayServer.is_touchscreen_available()
	return false

static func rumble_thump(strength := 1.0) -> void:
	_vibrate(0.22, clampf(strength, 0.2, 1.0), clampf(strength, 0.2, 1.0) * 0.8)

static func rumble_sputter() -> void:
	# Two quick low pulses — reads as a scrape/grumble.
	_vibrate(0.06, 0.45, 0.0)
	_vibrate(0.09, 0.45, 0.0, 90)

static func rumble_chirp() -> void:
	_vibrate(0.05, 0.0, 0.4)

## Envelope gate: a stronger rumble pre-empts a weaker one, so a thump
## during a boost hum is felt. (Replaces the old first-wins gate.)
static func _vibrate(duration_s: float, low: float, high: float, delay_ms := 0) -> void:
	if not vibration_enabled():
		return
	if OS.has_feature("web"):
		return
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var now := Time.get_ticks_msec()
	var start_ms := now + delay_ms
	if start_ms < _rumble_until_ms:
		# Active envelope: only a HIGHER peak may interrupt.
		if maxf(low, high) <= _rumble_peak:
			return
	Input.stop_joy_vibration(pads[0])
	Input.start_joy_vibration(pads[0], low, high, duration_s)
	_rumble_until_ms = start_ms + int(duration_s * 1000.0)
	_rumble_peak = maxf(low, high)

static func rumble(strength: float = 0.6) -> void:
	# Legacy entry point kept for existing call sites: maps to the
	# vocabulary (medium thump).
	rumble_thump(strength)

static func clear_cache() -> void:
	_rumble_until_ms = 0
	_rumble_peak = 0.0  # parity with FloorMaterials.clear_cache() test hooks

# --- camera helpers ----------------------------------------------------------

static func invert_camera_x() -> bool:
	return _as_bool(get_setting(KEY_INVERT, false), false)

static func set_invert_camera_x(value: bool) -> void:
	set_setting(KEY_INVERT, value)
	_invert_x = value

## Camera panning sign: -1 when inverted so apply_* can multiply once.
static func camera_x_sign() -> float:
	return -1.0 if _invert_x else 1.0

# --- controller button remapping --------------------------------------------

## Common joypad buttons offered in the remap UI. Dpad left/right are
## excluded (bound to camera pan); stick clicks are reserved.
const PAD_BUTTON_NAMES := {
	0: "A / CROSS",
	1: "B / CIRCLE",
	2: "X / SQUARE",
	3: "Y / TRIANGLE",
	4: "SELECT / SHARE",
	5: "HOME / GUIDE",
	6: "START / OPTIONS",
	9: "L SHOULDER (L1)",
	10: "R SHOULDER (R1)",
}

static func pad_button_map() -> Dictionary:
	var raw: Variant = get_setting(KEY_PAD_MAP, {})
	var map := {}
	if raw is Dictionary:
		for action in DEFAULT_PAD_MAP:
			map[action] = clampi(int(raw.get(action, DEFAULT_PAD_MAP[action])), 0, 30)
	else:
		map = DEFAULT_PAD_MAP.duplicate()
	return map

static func pad_button_for(action: String) -> int:
	return pad_button_map().get(action, DEFAULT_PAD_MAP.get(action, -1))

## Friendly label for HUD/overlay text ("BOOST: A / CROSS").
static func pad_button_name(action: String) -> String:
	var index := pad_button_for(action)
	return PAD_BUTTON_NAMES.get(index, "BUTTON %d" % index)

static func set_pad_button(action: String, button_index: int) -> void:
	var map := pad_button_map()
	map[action] = button_index
	set_setting(KEY_PAD_MAP, map)
	apply_pad_map_to_input_map()

## Rewrite the joypad BUTTON events of the pad actions so a remap (or a
## saved map at boot) takes effect immediately. Movement axes and every
## keyboard/mouse event are untouched.
static func apply_pad_map_to_input_map() -> void:
	var map := pad_button_map()
	for action in map:
		if not InputMap.has_action(action):
			continue
		var keep: Array[InputEvent] = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton:
				continue
			keep.append(ev)
		InputMap.action_erase_events(action)
		for ev in keep:
			InputMap.action_add_event(action, ev)
		var btn := InputEventJoypadButton.new()
		btn.button_index = map[action]
		InputMap.action_add_event(action, btn)


const _RUMBLE_MS := 250
static var _rumble_until_ms := 0
static var _rumble_peak := 0.0


static func _cfg() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(CFG_PATH)
	return config

static func get_setting(key: String, default: Variant) -> Variant:
	return _cfg().get_value(SECTION, key, default)

static func set_setting(key: String, value: Variant) -> void:
	var config := _cfg()
	config.set_value(SECTION, key, value)
	config.save(CFG_PATH)

# --- typed getters (clamped against corrupt/legacy cfg values) -------------

static func keyboard_sensitivity() -> float:
	var raw := float(get_setting(KEY_KB_SENS, KEYBOARD_DEFAULT))
	return clampf(raw, KEYBOARD_MIN, KEYBOARD_MAX)

## Safe bool coercion: GDScript's bool() crashes on a String value
## ("Nonexistent 'bool' constructor"), and a hand-edited cfg can hold
## anything. Anything not literally a bool falls back to the default.
static func _as_bool(value: Variant, default: bool) -> bool:
	return value if value is bool else default

static func mouse_look_enabled() -> bool:
	return _as_bool(get_setting(KEY_MOUSE_LOOK, true), true)

static func mouse_sensitivity() -> float:
	return clampf(float(get_setting(KEY_MOUSE_SENS, MOUSE_DEFAULT)), MOUSE_MIN, MOUSE_MAX)

static func stick_look_enabled() -> bool:
	return _as_bool(get_setting(KEY_STICK_LOOK, true), true)

static func stick_sensitivity() -> float:
	return clampf(float(get_setting(KEY_STICK_SENS, STICK_DEFAULT)), STICK_MIN, STICK_MAX)

static func vibration_enabled() -> bool:
	return _as_bool(get_setting(KEY_VIBRATION, true), true)

# --- chair-facing helpers ---------------------------------------------------

## Acceleration multiplier for PlayerChair. 1.0 would be the old feel;
## default cfg ships 0.35 for keyboard play, 1.0 (full accel) when a
## controller is the active scheme. Remote chairs never scale (host
## physics only drives the local chair; remote chairs are interpolated).
static func acceleration_multiplier() -> float:
	return active_keyboard_scale()

## Mouse-motion camera yaw. event.relative.x * sens * 0.003 rad/px is a
## comfortable third-person orbit speed at sens 1.0.
static func apply_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _mouse_look_on:
		return
	camera_yaw_offset += event.relative.x * camera_x_sign() * _mouse_sens * 0.003

## Right-stick camera yaw. Mirror-x so pushing stick right orbits the
## camera right (matches every third-person console title).
static func apply_stick(strength: float, delta: float) -> void:
	if not _stick_look_on:
		return
	camera_yaw_offset += strength * camera_x_sign() * _stick_sens * 2.2 * delta

## Wrap to [-PI, PI] so the float never degrades after long play.
static func wrapped_yaw() -> float:
	return wrapf(camera_yaw_offset, -PI, PI)

static func reset_yaw() -> void:
	camera_yaw_offset = 0.0

## Mouse-motion handler for mode scenes: parse an InputEventMouseMotion
## through InputPrefs (reads the toggle + sensitivity). Call from
## _unhandled_input before treating other events.
static func handle_mouse_motion(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		apply_mouse_motion(event)

# --- controller rumble -------------------------------------------------------
# (Vocabulary lives ABOVE with the stick-curve section; legacy rumble()
# there maps to rumble_thump so every existing call site keeps working.)
# clear_cache() in that section resets the rumble envelope state.
