# PauseMenu.gd — Reusable in-match pause overlay (Phase 8C)
# Esc opens pause, resume/settings/quit. Runs while tree is paused.
# Wire-up: mode script adds `PauseMenu.create(self, on_quit_callable)`.
extends CanvasLayer

signal resumed

const ACCENT := Color("ff9a1a")
const BG_PANEL := Color("1c1c2e")
const UI_THEME = preload("res://scripts/UITheme.gd")

var _root: Control
var _panel: Control
var _quit_callable: Callable
var _settings_open: bool = false

static func create(mode_root: Node, on_quit: Callable) -> CanvasLayer:
	var menu: CanvasLayer = load("res://scripts/PauseMenu.gd").new()
	menu.name = "PauseMenu"
	menu._quit_callable = on_quit
	mode_root.add_child(menu)
	return menu

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	get_tree().paused = true
	# Pausing frees the cursor for the menu; resume re-captures it.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_resume()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "PauseRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop = ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.04, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)

	# S-F: a CanvasLayer child has no sized parent, so PRESET_CENTER
	# centering drifts as the panel's min size grows — a full-rect
	# CenterContainer is the reliable pattern (same fix as PreMatchModal).
	var center := CenterContainer.new()
	center.name = "PauseCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "PausePanel"
	_panel.custom_minimum_size = Vector2(420, 0)
	var style := UI_THEME.panel_style(UI_THEME.color(UI_THEME.ORANGE), true)
	style.border_color = UI_THEME.color(UI_THEME.ORANGE)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 24.0
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel.add_child(box)

	# S-F: hazard-tape header strip (drawn vector, R7 single use).
	var tape: Control = UI_THEME.TapeStrip.new()
	tape.name = "TapeStrip"
	tape.custom_minimum_size = Vector2(0, 10)
	box.add_child(tape)

	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT))
	box.add_child(title)

	var hint = Label.new()
	hint.text = "ESC to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	box.add_child(hint)

	var resume_btn = _make_button("RESUME", _resume)
	box.add_child(resume_btn)
	box.add_child(_make_button("SETTINGS", _open_settings))
	box.add_child(_make_button("QUIT TO MENU", _quit))
	# Controller/keyboard focus: dpad + left stick drive ui_* actions, so
	# grabbing focus on RESUME makes the whole pause menu pad-navigable.
	resume_btn.grab_focus()

func _make_button(text: String, handler: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(handler)
	return button

func _resume() -> void:
	if _settings_open:
		return
	_close_settings_if_any()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()
	queue_free()

func _quit() -> void:
	_close_settings_if_any()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _quit_callable.is_valid():
		_quit_callable.call()
	else:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _open_settings() -> void:
	if _settings_open:
		return
	_settings_open = true
	_panel.visible = false
	var settings_script = load("res://scripts/Settings.gd")
	var settings = Control.new()
	settings.name = "SettingsOverlay"
	settings.set_script(settings_script)
	_root.add_child(settings)
	settings.closed.connect(_on_settings_closed)

func _on_settings_closed() -> void:
	_settings_open = false
	_panel.visible = true

func _close_settings_if_any() -> void:
	var settings = get_node_or_null("PauseRoot/SettingsOverlay")
	if settings and is_instance_valid(settings):
		settings.queue_free()
	_settings_open = false
	_panel.visible = true

func _exit_tree() -> void:
	if get_tree():
		get_tree().paused = false
