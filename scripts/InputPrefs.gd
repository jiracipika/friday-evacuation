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
const KEY_PAD_MAP := "pad_button_map"            # action -> joypad button index (legacy v1)
const KEY_BINDINGS := "action_bindings_serialized"  # InputHelper JSON blob (keys+mouse+pad)
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
	apply_saved_bindings()

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

# --- action bindings (InputHelper-backed) ------------------------------------
#
# Since the Input Helper addon (addons/input_helper/input_helper.gd) is
# available, ALL button/key remapping goes through it:
#   - set_*_input_for_action gives automatic conflict swapping (taking a
#     binding moves the other action's binding to the old one — no more
#     silently colliding maps).
#   - serialize_inputs_for_actions / deserialize_inputs_for_actions give a
#     stable save format for keys, mouse buttons AND joypad buttons.
# Persisted as one JSON blob (KEY_BINDINGS) covering the five button
# actions ONLY. Movement actions keep their project.godot events: their
# joypad STICK-AXIS events would be destroyed by deserialize (it erases
# the action's whole event list), and arrow-key movement shouldn't be
# broken by a bad save either.
# Legacy v1 (KEY_PAD_MAP action->button dict) is migrated once: if the
# blob is absent but a pad map exists, pad defaults are re-applied through
# InputHelper and saved as the blob.

## Actions whose key/mouse/pad bindings the player may change.
const REMAPPABLE_ACTIONS := ["boost", "action", "sabotage", "pause", "recenter_camera"]

static func _helper() -> Node:
	var ml := Engine.get_main_loop()
	if ml == null or not (ml is SceneTree):
		return null
	return (ml as SceneTree).root.get_node_or_null("InputHelper")

## Apply the saved bindings blob to the live InputMap. Handles, in order:
## v2 physical-faithful blobs, upstream v1 blobs (keycode-only, from the
## d1195f0 release), and the pre-InputHelper pad dict. Corrupt data is
## discarded (defaults kept) instead of crashing — JSON.parse_string on
## garbage used to hard-crash here and kill bindings for the session.
static func apply_saved_bindings() -> void:
	var blob: Variant = get_setting(KEY_BINDINGS, "")
	var applied := false
	if blob is String and blob != "":
		var parsed: Variant = JSON.parse_string(blob)
		if parsed is Dictionary:
			if int(parsed.get("v", 0)) == 2 and parsed.get("actions") is Dictionary:
				_apply_bindings_v2(parsed.actions)
				applied = true
			elif parsed.has("version") and parsed.get("map") is Dictionary:
				# Upstream InputHelper v1 format: keycode-only. Convert to
				# v2 (best effort) so non-QWERTY users get keys on the
				# right LOGICAL key until they rebind.
				_apply_bindings_v2(_convert_v1_blob(parsed.map))
				applied = true
		if not applied:
			push_warning("InputPrefs: discarding corrupt bindings blob")
	elif _helper() != null:
		applied = _migrate_legacy_pad_map()
	apply_pad_map_to_input_map()

## v1 -> v2 migration: old pad-button dict becomes a real bindings blob.
## Returns true when a blob was produced. Clears the stale dict afterwards
## so the legacy code paths and the overlay signature stop churning.
static func _migrate_legacy_pad_map() -> bool:
	var raw: Variant = get_setting(KEY_PAD_MAP, {})
	if not (raw is Dictionary) or raw.is_empty():
		return false
	var changed := false
	for action in REMAPPABLE_ACTIONS:
		if not raw.has(action):
			continue
		var idx := clampi(int(raw[action]), 0, 30)
		if idx == int(DEFAULT_PAD_MAP.get(action, -1)):
			continue  # default binding: nothing to migrate
		var ev := InputEventJoypadButton.new()
		ev.button_index = idx
		InputMap.action_erase_events(action)
		for keep_ev in _non_button_events(action):
			InputMap.action_add_event(action, keep_ev)
		InputMap.action_add_event(action, ev)
		changed = true
	if changed:
		save_bindings()
		clear_setting(KEY_PAD_MAP)
	return changed

## Rebuild the five remappable actions from a v2 actions dict
## ({action: {"k": int, "p": 0/1, "m": int, "j": int}}). Helper-free by
## design: raw SceneTree tests and headless boots can restore bindings.
static func _apply_bindings_v2(actions: Dictionary) -> void:
	for action in REMAPPABLE_ACTIONS:
		if not actions.has(action):
			continue
		if not InputMap.has_action(action):
			continue
		var spec: Dictionary = actions[action]
		var keep: Array[InputEvent] = _non_button_events(action)
		InputMap.action_erase_events(action)
		for ev in keep:
			InputMap.action_add_event(action, ev)
		var k := int(spec.get("k", 0))
		if k > 0:
			var key_ev := InputEventKey.new()
			if int(spec.get("p", 0)) == 1:
				key_ev.physical_keycode = k
			else:
				key_ev.keycode = k
			InputMap.action_add_event(action, key_ev)
		var m := int(spec.get("m", -1))
		if m >= 0:
			var mouse_ev := InputEventMouseButton.new()
			mouse_ev.button_index = m
			InputMap.action_add_event(action, mouse_ev)
		var j := int(spec.get("j", -1))
		if j >= 0:
			var pad_ev := InputEventJoypadButton.new()
			pad_ev.button_index = j
			InputMap.action_add_event(action, pad_ev)

## Everything in an action that is NOT a key/mouse/pad-button event
## (nothing today for the five remappables, but future-proof).
static func _non_button_events(action: String) -> Array[InputEvent]:
	var keep: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton:
			continue
		keep.append(ev)
	return keep

## Convert an upstream-format blob map into a v2 actions dict. Upstream
## serializes keys by KEYCODE string ("key:J"), so physical info is gone —
## that loss is exactly why v2 exists; this path keeps old saves working.
static func _convert_v1_blob(map: Dictionary) -> Dictionary:
	var out := {}
	for action in REMAPPABLE_ACTIONS:
		if not map.has(action):
			continue
		var spec := {"k": 0, "p": 0, "m": -1, "j": -1}
		var entry: String = String(map[action])
		for part in entry.split(";"):
			var bits := part.split(":")
			if bits.size() < 2:
				continue
			match bits[0]:
				"key":
					var code := OS.find_keycode_from_string(bits[1])
					if code > 0:
						spec["k"] = code
						spec["p"] = 0
				"mouse":
					spec["m"] = int(bits[1])
				"joypad":
					if "|" in bits[1]:
						continue  # axis events are not part of v2
					spec["j"] = int(bits[1])
		out[action] = spec
	return out

## Snapshot the five remappable actions' current events into the cfg as a
## v2 blob. PHYSICAL keycodes are preserved (upstream's serializer stores
## logical keycodes only, which rebinds non-QWERTY layouts on restore).
## Helper-free: reads the live InputMap directly.
static func save_bindings() -> void:
	var actions := {}
	for action in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var spec := {"k": 0, "p": 0, "m": -1, "j": -1}
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and int(spec["k"]) == 0:
				if (ev as InputEventKey).physical_keycode > 0:
					spec["k"] = (ev as InputEventKey).physical_keycode
					spec["p"] = 1
				else:
					spec["k"] = (ev as InputEventKey).keycode
					spec["p"] = 0
			elif ev is InputEventMouseButton and int(spec["m"]) < 0:
				spec["m"] = (ev as InputEventMouseButton).button_index
			elif ev is InputEventJoypadButton and int(spec["j"]) < 0:
				spec["j"] = (ev as InputEventJoypadButton).button_index
		actions[action] = spec
	set_setting(KEY_BINDINGS, JSON.stringify({"v": 2, "actions": actions}))

## Find another REMAPPABLE action whose same-class binding matches `event`.
## Conflict swaps must NEVER touch movement/camera actions — the upstream
## swap scans ALL actions and would happily hand move_forward's W to boost.
## Returns [other_action, their_event] or [].
static func _fenced_conflict(action: String, event: InputEvent) -> Array:
	for other in REMAPPABLE_ACTIONS:
		if other == action:
			continue
		for ev in InputMap.action_get_events(other):
			if _same_class_match(ev, event):
				return [other, ev]
	return []

static func _same_class_match(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		if ka.physical_keycode > 0 and kb.physical_keycode > 0:
			return ka.physical_keycode == kb.physical_keycode
		return ka.keycode > 0 and ka.keycode == kb.keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	return false

## Same SLOT class (key->key, mouse->mouse, pad-button->pad-button) but
## ignoring WHICH binding — used to decide which old event a new binding
## replaces (upstream semantics: the primary key slot is replaced, not
## appended after).
static func _same_slot_class(a: InputEvent, b: InputEvent) -> bool:
	return (a is InputEventKey and b is InputEventKey) \
		or (a is InputEventMouseButton and b is InputEventMouseButton) \
		or (a is InputEventJoypadButton and b is InputEventJoypadButton)

## Remove one specific event from an action (for conflict handoffs when
## there is no spare binding to give back).
static func _remove_event(action: String, dead: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	var keep: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action):
		if ev == dead or _same_class_match(ev, dead):
			continue
		keep.append(ev)
	InputMap.action_erase_events(action)
	for ev in keep:
		InputMap.action_add_event(action, ev)

## Player pressed a key/mouse/pad button while remapping `action`. Conflicts
## are swapped ONLY within the remappable set: taking a button moves the
## other remappable action's binding aside; movement keys are untouchable.
## The old occupant of the replaced slot is handed to the displaced action
## (upstream swap semantics, fenced).
static func set_key_binding(action: String, event: InputEvent) -> bool:
	if not InputMap.has_action(action):
		return false
	var conflict := _fenced_conflict(action, event)
	# Scan FIRST (the list is invalid after action_erase_events), replacing
	# the first SAME-CLASS slot (key->key, mouse->mouse, pad->pad) with the
	# new event.
	var kept: Array[InputEvent] = []
	var old_occupant: InputEvent = null
	var replaced := false
	for ev in InputMap.action_get_events(action):
		var is_button := ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton
		if is_button and not replaced and _same_slot_class(ev, event):
			old_occupant = ev
			kept.append(event)
			replaced = true
		else:
			kept.append(ev)
	if not replaced:
		kept.append(event)
	InputMap.action_erase_events(action)
	for ev in kept:
		InputMap.action_add_event(action, ev)
	# Hand the old binding to the displaced remappable action.
	if conflict.size() == 2:
		var other: String = conflict[0]
		var their: InputEvent = conflict[1]
		if old_occupant != null:
			var other_kept: Array[InputEvent] = []
			for ev in InputMap.action_get_events(other):
				if _same_class_match(ev, their):
					other_kept.append(old_occupant)
				else:
					other_kept.append(ev)
			InputMap.action_erase_events(other)
			for ev in other_kept:
				InputMap.action_add_event(other, ev)
		else:
			_remove_event(other, their)
	save_bindings()
	return true

## Player pressed a pad button while remapping `action` (fenced swap).
static func set_pad_binding(action: String, event: InputEventJoypadButton) -> bool:
	return set_key_binding(action, event)

## Reset the five actions to project defaults and persist.
static func reset_bindings() -> void:
	var helper := _helper()
	if helper != null:
		helper.reset_all_actions()
	else:
		InputMap.load_from_project_settings()
	save_bindings()

## Primary KEYBOARD/MOUSE label for the HUD/overlay ("SPACE", "LMB", "E").
static func key_binding_name(action: String) -> String:
	var helper := _helper()
	if helper == null:
		return KEY_FALLBACK_NAMES.get(action, action.to_upper())
	var ev: InputEvent = helper.get_keyboard_input_for_action(action)
	if ev == null:
		return KEY_FALLBACK_NAMES.get(action, action.to_upper())
	return helper.get_label_for_input(ev).to_upper()

## Primary PAD label via InputHelper's per-device tables (real
## Xbox/PlayStation/Switch names — no more "A / CROSS" dual labels).
static func pad_binding_name(action: String) -> String:
	var helper := _helper()
	if helper == null:
		var index := pad_button_for(action)
		return PAD_BUTTON_NAMES.get(index, "BUTTON %d" % index)
	var ev: InputEvent = helper.get_joypad_input_for_action(action)
	if ev == null:
		return "?"
	return helper.get_label_for_input(ev).to_upper()

## Keyboard/mouse fallback labels when InputHelper is absent (raw tests).
const KEY_FALLBACK_NAMES := {
	"boost": "SPACE",
	"action": "E",
	"sabotage": "Q",
	"pause": "ESC",
	"recenter_camera": "R",
}

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

# --- legacy v1 pad-map API (kept for existing call sites) ---------------------

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
	# The live InputMap is the source of truth: the fenced remap writer
	# updates events immediately but intentionally no longer maintains the
	# legacy dict. Dict falls back only when the action has no pad button.
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton:
				return (ev as InputEventJoypadButton).button_index
	return pad_button_map().get(action, DEFAULT_PAD_MAP.get(action, -1))

## Friendly label for HUD/overlay text ("BOOST: A / CROSS").
## LIVE path: reads the real InputMap through InputHelper so a remap made
## this session is reflected. Helperless fallback uses the legacy dict.
static func pad_button_name(action: String) -> String:
	return pad_binding_name(action)

## v1 writer: still works (routes through InputHelper) but Settings now
## uses set_pad_binding directly.
static func set_pad_button(action: String, button_index: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button_index
	if not set_pad_binding(action, ev):
		# Helperless fallback: legacy dict + manual InputMap rewrite.
		var map := pad_button_map()
		map[action] = button_index
		set_setting(KEY_PAD_MAP, map)
		apply_pad_map_to_input_map()

## Rewrite the joypad BUTTON events of the pad actions so a remap (or a
## saved map at boot) takes effect immediately — WITHOUT clobbering
## keyboard/mouse events (those belong to InputHelper now). Movement axes
## are untouched.
static func apply_pad_map_to_input_map() -> void:
	var helper := _helper()
	for action in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		if helper != null:
			# InputHelper owns the joypad slots for these actions now.
			continue
		# Helperless legacy path (raw SceneTree tests): dict-driven rewrite.
		var map := pad_button_map()
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
	var config := _cfg()
	if not config.has_section_key(SECTION, key):
		return default
	return config.get_value(SECTION, key, default)

static func set_setting(key: String, value: Variant) -> void:
	var config := _cfg()
	config.set_value(SECTION, key, value)
	config.save(CFG_PATH)

## Remove a key from the cfg (retires legacy formats after migration so
## stale data stops churning signature-based UI).
static func clear_setting(key: String) -> void:
	var config := _cfg()
	if config.has_section_key(SECTION, key):
		config.erase_section_key(SECTION, key)
		config.save(CFG_PATH)

## Safe float coercion: float("garbage") returns 0.0 (no crash), which
## clampf would turn into the MINIMUM — a corrupt value should fall back
## to the default, not pin the slider to the floor.
static func _as_float(value: Variant, default: float) -> float:
	return float(value) if value is float or value is int else default

# --- typed getters (clamped against corrupt/legacy cfg values) -------------

static func keyboard_sensitivity() -> float:
	return clampf(_as_float(get_setting(KEY_KB_SENS, KEYBOARD_DEFAULT), KEYBOARD_DEFAULT), KEYBOARD_MIN, KEYBOARD_MAX)

## Safe bool coercion: GDScript's bool() crashes on a String value
## ("Nonexistent 'bool' constructor"), and a hand-edited cfg can hold
## anything. Anything not literally a bool falls back to the default.
static func _as_bool(value: Variant, default: bool) -> bool:
	return value if value is bool else default

static func mouse_look_enabled() -> bool:
	return _as_bool(get_setting(KEY_MOUSE_LOOK, true), true)

static func mouse_sensitivity() -> float:
	return clampf(_as_float(get_setting(KEY_MOUSE_SENS, MOUSE_DEFAULT), MOUSE_DEFAULT), MOUSE_MIN, MOUSE_MAX)

static func stick_look_enabled() -> bool:
	return _as_bool(get_setting(KEY_STICK_LOOK, true), true)

static func stick_sensitivity() -> float:
	return clampf(_as_float(get_setting(KEY_STICK_SENS, STICK_DEFAULT), STICK_DEFAULT), STICK_MIN, STICK_MAX)

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
