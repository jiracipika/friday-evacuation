extends Control
## Phase 7A: on-screen touch controls — virtual joystick (left) + action
## buttons BOOST / JUMP / TRAP (right). Auto-active on Android/iOS; on
## desktop only when the FE_TOUCH env var is "1" (preview + headless tests).

const ACCENT := Color(1.0, 0.6, 0.1)
const BOOST_BTN := Vector2(-130.0, -150.0)
const JUMP_BTN := Vector2(-260.0, -100.0)
const TRAP_BTN := Vector2(-130.0, -290.0)
const STICK_LIMIT := 92.0
const BOOST_R := 58.0
const JUMP_R := 44.0
const TRAP_R := 40.0
const STICK_REST := Vector2(130.0, 0.0)

var move_vector := Vector2.ZERO
var knob_center := Vector2.ZERO
var active_touch := -1
var boost_flash := 0.0
var boost_locked := false
var pressed_button := &""
var press_feedback_timer := 0.0
var local_chair_ref: Node = null
var touch_enabled := false

signal move_changed(value: Vector2)
signal action_pressed(action_name: StringName)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Web jump-right-in: auto-detect via InputPrefs (touchscreen on web /
	# mobile), desktop still gated behind FE_TOUCH=1 preview.
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs and prefs.has_method("touch_enabled"):
		touch_enabled = prefs.touch_enabled()
	else:
		touch_enabled = OS.get_name() in ["Android", "iOS"] or OS.get_environment("FE_TOUCH") == "1"
	if touch_enabled:
		queue_redraw()

## Called by the mode scene so the BOOST ring can mirror the local chair's
## actual boost cooldown (dim while locked).
func bind_local_chair(chair: Node) -> void:
	local_chair_ref = chair

## Phase 7A: one-line mount for any mode scene. Deduplicates and wires
## move/action signals to the local chair. Returns the mounted control
## (or existing one if already present).
static func mount_for_mode(parent: Node, chair: Node) -> Control:
	var existing: Node = parent.get_node_or_null("MobileControls")
	if existing and existing is Control:
		if chair and existing.has_method("bind_local_chair"):
			existing.bind_local_chair(chair)
		return existing
	# Gate via the shared InputPrefs decision (web touchscreen, mobile,
	# FE_TOUCH=1 override, or a pinned "on" from the main-screen button).
	var prefs_gate = load("res://scripts/InputPrefs.gd")
	var should_mount := false
	if prefs_gate and prefs_gate.has_method("touch_enabled"):
		should_mount = prefs_gate.touch_enabled()
	else:
		should_mount = OS.get_name() in ["Android", "iOS"] or OS.get_environment("FE_TOUCH") == "1"
	if not should_mount:
		return null
	var script = load("res://scripts/MobileControls.gd")
	if script == null:
		return null
	var control = Control.new()
	control.set_script(script)
	control.name = "MobileControls"
	parent.add_child(control)
	if chair and control.has_method("bind_local_chair"):
		control.bind_local_chair(chair)
		# Every mode gets direct movement/action routing from the one shared
		# control. This avoids dead secondary-mode touch UIs.
		if control.has_signal("move_changed") and chair.has_method("set_mobile_input"):
			control.move_changed.connect(chair.set_mobile_input)
		if control.has_signal("action_pressed") and chair.has_method("trigger_mobile_action"):
			control.action_pressed.connect(chair.trigger_mobile_action)
	return control

func _process(delta: float) -> void:
	if not touch_enabled:
		return
	var dirty := false
	if boost_flash > 0.0:
		boost_flash = maxf(0.0, boost_flash - delta * 4.0)
		dirty = true
	if pressed_button != &"":
		press_feedback_timer -= delta
		if press_feedback_timer <= 0.0:
			pressed_button = &""
			dirty = true
	if local_chair_ref and is_instance_valid(local_chair_ref):
		var locked: bool = local_chair_ref.boost_cd_timer > 0.0
		if locked != boost_locked:
			boost_locked = locked
			dirty = true
	if dirty:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not touch_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if active_touch < 0 and event.position.x < size.x * 0.52:
				active_touch = event.index
				knob_center = event.position
				_update_stick(event.position)
			else:
				_try_button(event.position)
		elif event.index == active_touch:
			active_touch = -1
			move_vector = Vector2.ZERO
			move_changed.emit(move_vector)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update_stick(event.position)

func _try_button(pos: Vector2) -> void:
	var boost_c: Vector2 = size + BOOST_BTN
	var jump_c: Vector2 = size + JUMP_BTN
	var trap_c: Vector2 = size + TRAP_BTN
	if pos.distance_to(boost_c) <= BOOST_R:
		_press(&"boost")
	elif pos.distance_to(jump_c) <= JUMP_R:
		_press(&"action")
	elif pos.distance_to(trap_c) <= TRAP_R:
		_press(&"sabotage")

func _press(action: StringName) -> void:
	pressed_button = action
	press_feedback_timer = 0.15
	if action == &"boost":
		# Read the chair synchronously: _process may not have run since the
		# previous press, so the cached ring state can be one frame stale.
		if local_chair_ref and is_instance_valid(local_chair_ref):
			boost_locked = local_chair_ref.boost_cd_timer > 0.0 or local_chair_ref.boost_locked
		if boost_locked:
			# On cooldown: show the press, but do not flash or fire.
			queue_redraw()
			return
		boost_flash = 1.0
	Input.vibrate_handheld(30)
	action_pressed.emit(action)
	if action == &"boost" and local_chair_ref and is_instance_valid(local_chair_ref):
		# action_pressed is synchronous; the chair cooldown is already set.
		boost_locked = local_chair_ref.boost_cd_timer > 0.0 or local_chair_ref.boost_locked
	queue_redraw()

func _update_stick(position: Vector2) -> void:
	move_vector = (position - knob_center).limit_length(STICK_LIMIT) / STICK_LIMIT
	move_changed.emit(move_vector)
	queue_redraw()

func _draw() -> void:
	if not touch_enabled:
		return
	# Joystick: base follows the initial touch point, rests bottom-left.
	var base: Vector2 = knob_center if active_touch >= 0 else Vector2(STICK_REST.x, size.y + STICK_REST.y)
	draw_circle(base, 88.0, Color(0.04, 0.04, 0.08, 0.52))
	draw_arc(base, 88.0, 0.0, TAU, 32, Color(1, 0.6, 0.1, 0.5), 3.0)
	draw_circle(base + move_vector * 62.0, 34.0, Color(1, 0.6, 0.1, 0.72))

	var boost_c: Vector2 = size + BOOST_BTN
	var jump_c: Vector2 = size + JUMP_BTN
	var trap_c: Vector2 = size + TRAP_BTN

	var boost_col := Color(1.0, 0.55, 0.08, 0.65)
	if boost_locked:
		boost_col = Color(0.45, 0.28, 0.1, 0.4)
	if boost_flash > 0.0:
		boost_col = boost_col.lerp(Color.WHITE, boost_flash * 0.8)
	draw_circle(boost_c, BOOST_R, boost_col)
	draw_string(ThemeDB.fallback_font, boost_c - Vector2(26, -6), "BOOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	draw_circle(jump_c, JUMP_R, Color(0.35, 0.7, 1.0, 0.62))
	draw_string(ThemeDB.fallback_font, jump_c - Vector2(18, -6), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	draw_circle(trap_c, TRAP_R, Color(0.9, 0.25, 0.25, 0.62))
	draw_string(ThemeDB.fallback_font, trap_c - Vector2(16, -6), "TRAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

	if pressed_button != &"":
		var pc: Vector2 = boost_c
		if pressed_button == &"action":
			pc = jump_c
		elif pressed_button == &"sabotage":
			pc = trap_c
		draw_arc(pc, 12.0, 0.0, TAU, 20, ACCENT, 2.0)
