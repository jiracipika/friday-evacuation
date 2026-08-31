# ControlsOverlay.gd — round-start controls recap + input device tracker.
#
# Mounted once per mode session; two jobs:
#   1. show_for(duration): a two-column CONTROLS panel (keyboard+mouse vs
#      controller) at the start of EVERY round. The active scheme's
#      column is highlighted; controller labels come from
#      InputPrefs.pad_button_name() so remaps are reflected instantly.
#   2. _input(event) feeds InputPrefs.note_device() for the whole session
#      so AUTO scheme follows whichever device the player actually uses
#      (stick-drift/jitter filtered inside note_device).
#
# Mount from a mode (deduped, survives the whole session):
#   var overlay = load("res://scripts/ControlsOverlay.gd").mount(self)
#   overlay.show_for(6.0)
#
# Layer 30: above gameplay HUD (10), below pause menu (50).
# Reduced motion: fade is skipped, panel just hides at the end.
extends CanvasLayer

const LAYER := 30
const FADE_TIME := 1.2

var panel: PanelContainer
var kb_header: Label
var pad_header: Label
var kb_box: VBoxContainer
var pad_box: VBoxContainer
var tip_label: Label
var root_control: Control

var _time_left := 0.0
var _visible_duration := 6.0
var _a11y: Variant = null
var _prefs: Variant = null
var _last_signature := ""  # scheme + pad map identity; rebuild only on change


static func mount(parent: Node) -> Node:
	if parent == null:
		return null
	var script = load("res://scripts/ControlsOverlay.gd")
	for child in parent.get_children():
		if child is Node and child.get_script() == script:
			return child
	var overlay: Node = new()
	overlay.name = "ControlsOverlay"
	overlay.layer = LAYER
	parent.add_child(overlay)
	return overlay


func _ready() -> void:
	_prefs = load("res://scripts/InputPrefs.gd")
	_build_ui()
	_a11y = load("res://scripts/Accessibility.gd")


func _build_ui() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.visible = false
	add_child(root_control)

	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-330, -268)
	panel.custom_minimum_size = Vector2(660, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.055, 0.09, 0.94)
	style.border_color = Color("ff9a1a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(panel)

	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var title = _label("CONTROLS", 22, Color("ff9a1a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(columns)

	# --- keyboard & mouse column ---
	kb_box = VBoxContainer.new()
	kb_box.add_theme_constant_override("separation", 3)
	kb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kb_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(kb_box)
	kb_header = _label("KEYBOARD & MOUSE", 15, Color("ffffff"))
	kb_box.add_child(kb_header)

	# --- controller column (labels filled per show, honors remap) ---
	pad_box = VBoxContainer.new()
	pad_box.add_theme_constant_override("separation", 3)
	pad_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(pad_box)
	pad_header = _label("CONTROLLER", 15, Color("ffffff"))
	pad_box.add_child(pad_header)

	tip_label = _label("", 11, Color(1, 1, 1, 0.55))
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tip_label)


func _label(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Show the recap. Call at the start of every round; safe to call before
## _ready (duration is applied on the first frame).
func show_for(duration := 6.0) -> void:
	_visible_duration = maxf(duration, FADE_TIME + 0.5)
	_time_left = _visible_duration
	_last_signature = ""  # force a rebuild on show
	_refresh()
	if root_control:
		root_control.visible = true
		root_control.modulate.a = 1.0
	if _a11y and _a11y.has_method("caption"):
		var scheme: String = "KEYBOARD" if not _active_is_pad() else "CONTROLLER"
		_a11y.caption("CONTROLS RECAP — %s SCHEME ACTIVE" % scheme, 2.5)


func hide_now() -> void:
	_time_left = 0.0
	if root_control:
		root_control.visible = false


func _active_is_pad() -> bool:
	return _prefs != null and _prefs.is_controller_active()


## Rebuild the row labels from current state (active scheme + remap).
## Called on show and, while visible, only when scheme/remap changes.
func _refresh() -> void:
	if kb_box == null:
		return  # not ready yet; show_for re-calls this on first frame
	var pad_active := _active_is_pad()
	var signature := "%s|%s|%s" % [
		"pad" if pad_active else "kb",
		_prefs.scheme_mode() if _prefs else "none",
		str(_prefs.pad_button_map()) if _prefs else "{}",
	]
	if signature == _last_signature:
		return
	_last_signature = signature

	_fill_column(kb_box, kb_header, "KEYBOARD & MOUSE", [
		["WASD / ARROWS", "MOVE"],
		["SPACE / LEFT CLICK", "BOOST"],
		["E / MIDDLE CLICK", "ACTION"],
		["Q / RIGHT CLICK", "SABOTAGE"],
		["MOVE MOUSE", "CAMERA"],
		["R", "RECENTER CAMERA"],
		["ESC", "PAUSE"],
	], not pad_active)

	var pad_rows: Array = [
		["LEFT STICK", "MOVE"],
		[_pad_name(_prefs, "boost"), "BOOST"],
		[_pad_name(_prefs, "action"), "ACTION"],
		[_pad_name(_prefs, "sabotage"), "SABOTAGE"],
		["RIGHT STICK", "CAMERA"],
		[_pad_name(_prefs, "recenter_camera"), "RECENTER CAMERA"],
		[_pad_name(_prefs, "pause"), "PAUSE"],
	]
	_fill_column(pad_box, pad_header, "CONTROLLER", pad_rows, pad_active)

	if tip_label:
		if _prefs and _prefs.scheme_mode() == _prefs.SCHEME_AUTO:
			tip_label.text = "AUTO-SCHEME: JUST GRAB THE OTHER DEVICE — CONTROLS FOLLOW"
		else:
			tip_label.text = "SWITCH SCHEME ANY TIME: SETTINGS (ESC) → INPUT"


func _pad_name(prefs: Variant, action: String) -> String:
	if prefs and prefs.has_method("pad_button_name"):
		return prefs.pad_button_name(action)
	return action.to_upper()


func _fill_column(box: VBoxContainer, header: Label, header_text: String,
		rows: Array, active: bool) -> void:
	header.text = "%s%s" % [header_text, "  ● ACTIVE" if active else ""]
	header.add_theme_color_override("font_color",
		Color("ffb52e") if active else Color(1, 1, 1, 0.45))
	# Rebuild rows below the header (header is child 0).
	while box.get_child_count() > 1:
		var last = box.get_child(box.get_child_count() - 1)
		box.remove_child(last)
		last.queue_free()
	for row in rows:
		var line = _label("%s  —  %s" % [row[0], row[1]], 12,
			Color(1, 1, 1, 0.9) if active else Color(1, 1, 1, 0.38))
		box.add_child(line)


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	# A device flip mid-display must re-highlight immediately (cheap:
	# _refresh no-ops unless scheme/pad-map signature changed).
	_refresh()
	_time_left -= delta
	if _time_left <= 0.0:
		if root_control:
			root_control.visible = false
		return
	var reduced := false
	if _a11y and _a11y.has_method("reduced_motion_enabled"):
		reduced = _a11y.reduced_motion_enabled()
	if not reduced and root_control:
		var fade := clampf(_time_left / FADE_TIME, 0.0, 1.0)
		root_control.modulate.a = fade if _time_left <= FADE_TIME else 1.0


# Feed every event to scheme detection. Runs before GUI/input handling;
# note_device is a couple of type checks — cheap enough for _input.
func _input(event: InputEvent) -> void:
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs:
		prefs.note_device(event)
