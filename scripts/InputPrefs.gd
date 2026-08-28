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
#   keyboard_sensitivity over [0.5 .. 1.5]; 1.0 = the shipped default
#   feel. The user asked for a LOWER default, so KEYBOARD_DEFAULT is
#   0.7 — that maps to acceleration ~24 (34 * 0.7), a noticeably
#   gentler turn-in than before without changing top speed.
class_name InputPrefs
extends RefCounted

## Test seam: overridable so smoke tests never clobber the real save.
static var CFG_PATH := "user://settings.cfg"

const SECTION := "input"

# --- persisted keys -------------------------------------------------------
const KEY_KB_SENS := "keyboard_sensitivity"      # 0.5 .. 1.5 (1.0 = old feel)
const KEY_MOUSE_LOOK := "mouse_look_enabled"     # bool
const KEY_MOUSE_SENS := "mouse_sensitivity"      # 0.25 .. 2.0 (1.0 default)
const KEY_STICK_LOOK := "stick_look_enabled"     # right-stick camera orbit
const KEY_STICK_SENS := "stick_sensitivity"      # 0.25 .. 2.0
const KEY_VIBRATION := "vibration_enabled"       # controller rumble

# --- defaults ---------------------------------------------------------------
# Keyboard deliberately LOWER than 1.0: the pre-settings feel (accel 34)
# read twitchy to new players. 0.7 -> accel ~24 keeps full top speed but
# smooths turn-in. Mouse/stick look ship ON because the game is 3D and
# every "any controller" peer expects right-stick camera.
const KEYBOARD_DEFAULT := 0.7
const KEYBOARD_MIN := 0.5
const KEYBOARD_MAX := 1.5
const MOUSE_DEFAULT := 1.0
const MOUSE_MIN := 0.25
const MOUSE_MAX := 2.0
const STICK_DEFAULT := 1.0
const STICK_MIN := 0.25
const STICK_MAX := 2.0

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


## Sync the per-event caches from the cfg. Cheap; call on mode _ready
## and whenever the Settings screen applies (pause-menu changes then
## take effect immediately on resume).
static func refresh_cache() -> void:
	_mouse_look_on = mouse_look_enabled()
	_mouse_sens = mouse_sensitivity()
	_stick_look_on = stick_look_enabled()
	_stick_sens = stick_sensitivity()
	keyboard_scale = keyboard_sensitivity()

const _RUMBLE_MS := 250
static var _rumble_until_ms := 0


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
## default cfg ships 0.7. Remote chairs never scale (host physics only
## drives the local chair; remote chairs are interpolated).
static func acceleration_multiplier() -> float:
	return keyboard_scale

## Mouse-motion camera yaw. event.relative.x * sens * 0.003 rad/px is a
## comfortable third-person orbit speed at sens 1.0.
static func apply_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _mouse_look_on:
		return
	camera_yaw_offset += event.relative.x * _mouse_sens * 0.003

## Right-stick camera yaw. Mirror-x so pushing stick right orbits the
## camera right (matches every third-person console title).
static func apply_stick(strength: float, delta: float) -> void:
	if not _stick_look_on:
		return
	camera_yaw_offset += strength * _stick_sens * 2.2 * delta

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

## Constant rumble envelope on the first connected joypad. No-ops when
## disabled, unsupported (web), or no pad. Godot 4.7 web export has no
## Input.start_joy_vibration — guard with feature tags.
static func rumble(strength: float = 0.6) -> void:
	if not vibration_enabled():
		return
	if OS.has_feature("web"):
		return
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var until := Time.get_ticks_msec()
	if until < _rumble_until_ms:
		return  # an envelope is already active — don't reset it mid-hum
	_rumble_until_ms = until + _RUMBLE_MS
	Input.start_joy_vibration(pads[0], clampf(strength, 0.1, 1.0), 0.0, _RUMBLE_MS / 1000.0)

static func clear_cache() -> void:
	pass  # parity with FloorMaterials.clear_cache() test hooks
