# PreMatchModal.gd — Boomerang-Fu-style blocking pre-game briefing.
#
# When a match scene opens, the whole SceneTree is PAUSED and a modal
# shows: objective, how-to-play bullets, and the control maps (keyboard
# + controller + touch when enabled). The timer and game do not run —
# the user must press the big "I AGREE" button at the bottom (or
# Enter / Space / gamepad A) to dismiss. Only then does the countdown
# (frozen until now) begin ticking.
#
# Mount at the END of each mode's _ready:
#   PreMatchModal.mount(self, "EVACUATION", objective_lines)
#
# All modes already set match_state/countdown/round vars in _ready;
# because the tree is paused, nothing ticks until agreement. The
# round-start ControlsOverlay recap (behind this modal) resumes its
# 7s window after dismissal, so players still get the in-world recap
# as the countdown runs.
extends CanvasLayer

const ACCENT := Color(1.0, 0.6, 0.1)
const BG := Color(0.02, 0.02, 0.05, 0.97)
const CARD := Color(0.11, 0.11, 0.18)

static var _suppress_once := false  # headless tests / rematches can skip

var agree_button: Button
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _agreed := false

## mode_title: e.g. "EVACUATION". objective_lines: 1-3 short strings.
## control_rows: optional override; default = the standard maps.
static func mount(parent: Node, mode_title: String, objective_lines: Array) -> CanvasLayer:
	if _suppress_once:
		_suppress_once = false
		return null
	if parent.has_node("PreMatchModal"):
		return null
	var layer: CanvasLayer = CanvasLayer.new()
	layer.set_script(load("res://scripts/PreMatchModal.gd"))
	layer.name = "PreMatchModal"
	layer.mode_title = mode_title
	layer.objective_lines = objective_lines
	# Pause FIRST so not one frame of gameplay runs before agreement.
	parent.get_tree().paused = true
	parent.add_child(layer)
	return layer

## Headless tests / internal rematches set this to skip the modal once.
static func suppress_next() -> void:
	_suppress_once = true

var mode_title := "MODE"
var objective_lines: Array = []

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = BG
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override("panel", _card_style())
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(0.5 * panel.get_viewport_rect().size.x - 320, 40)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "HOW TO PLAY — %s" % mode_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)

	for line in objective_lines:
		var obj := Label.new()
		obj.text = line
		obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		obj.add_theme_font_size_override("font_size", 15)
		obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		obj.custom_minimum_size = Vector2(600, 0)
		box.add_child(obj)

	box.add_child(HSeparator.new())

	# Control maps: keyboard column + controller column (+ touch note).
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	box.add_child(cols)
	cols.add_child(_control_column("KEYBOARD & MOUSE", [
		"WASD / ARROWS — MOVE", "SPACE / LEFT CLICK — BOOST",
		"E / MIDDLE CLICK — ACTION", "Q / RIGHT CLICK — SABOTAGE",
		"MOUSE — CAMERA   R — RECENTER", "ESC — PAUSE",
	]))
	cols.add_child(_control_column("CONTROLLER", [
		"LEFT STICK — MOVE", "A / CROSS — BOOST",
		"X / SQUARE — ACTION (RT = PRESSURE BOOST)",
		"B / CIRCLE — SABOTAGE", "RIGHT STICK — CAMERA  Y — RECENTER",
		"START — PAUSE",
	]))
	var touch := Label.new()
	touch.text = _touch_line()
	touch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	touch.add_theme_font_size_override("font_size", 12)
	touch.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	box.add_child(touch)

	var rule := Label.new()
	rule.text = "The timer and world are PAUSED until you agree."
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.add_theme_font_size_override("font_size", 12)
	rule.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(rule)

	agree_button = Button.new()
	agree_button.text = "I AGREE — START"
	agree_button.custom_minimum_size = Vector2(0, 54)
	agree_button.add_theme_font_size_override("font_size", 22)
	agree_button.pressed.connect(_agree)
	box.add_child(agree_button)
	agree_button.grab_focus()

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = ACCENT
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _control_column(heading: String, rows: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	var head := Label.new()
	head.text = heading
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", ACCENT)
	col.add_child(head)
	for row_text in rows:
		var row := Label.new()
		row.text = row_text
		row.add_theme_font_size_override("font_size", 12)
		col.add_child(row)
	return col

func _touch_line() -> String:
	var prefs = load("res://scripts/InputPrefs.gd")
	var on := false
	if prefs and prefs.has_method("touch_enabled"):
		on = prefs.touch_enabled()
	if on:
		return "TOUCH: left joystick moves — BOOST / JUMP / TRAP buttons bottom-right."
	return "Playing on a phone or tablet? The touch overlay appears automatically (or tap TOUCH: ON in the menu)."

func _unhandled_input(event: InputEvent) -> void:
	# Gamepad A / Start also agree (Boomerang-Fu behavior: any confirm).
	if event is InputEventJoypadButton and event.pressed \
			and (event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_START):
		_agree()
		get_viewport().set_input_as_handled()

func _agree() -> void:
	if _agreed:
		return
	_agreed = true
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse_mode
	queue_free()
