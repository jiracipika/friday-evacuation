# SplashScreen.gd — faded "click to start" gate before the main menu.
#
# The backdrop menu stays visible but dimmed behind a dark scrim; a large
# brand title, tagline, and pulsing CLICK / TAP / PRESS A prompt invite
# entry. Any ui_accept (Enter/Space), mouse click, touch, or pad A
# dismisses it with a quick fade and hands focus to the menu's play
# button. Godot web exports famously swallow the first input events and
# audio playback is blocked until a user gesture — this layer is that
# gesture, so the menu (and its sounds) always start warm.
#
# mount(parent) is idempotent (deduped by node name) per the repo
# convention for reusable overlays.
extends CanvasLayer

const UI_THEME = preload("res://scripts/UITheme.gd")

const ACCENT := Color("ff9a1a")
const FADE_TIME := 0.45

var _time := 0.0
var _dismissed := false
var _root: Control
var _prompt_label: Label
var _title_label: Label
var _sub_label: Label
var _scrim: ColorRect

static func mount(parent: Node) -> CanvasLayer:
	var existing: Node = parent.get_node_or_null("SplashLayer")
	if existing:
		return existing as CanvasLayer
	var layer: CanvasLayer = load("res://scripts/SplashScreen.gd").new()
	layer.name = "SplashLayer"
	parent.add_child(layer)
	return layer

func _ready() -> void:
	layer = 95  # above menu HUD (10), pause (50), PreMatchModal (90)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Guarantee pad A accepts on this layer even before Godot's default
	# map registers the joypad (headless / web cold start).
	if not InputMap.has_action("ui_accept"):
		InputMap.add_action("ui_accept")
	var pad_ev := InputEventJoypadButton.new()
	pad_ev.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept", pad_ev):
		InputMap.action_add_event("ui_accept", pad_ev)
	_build_ui()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "SplashRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Scrim: near-opaque brand black — the menu backdrop's sunset bleeds
	# through just enough to hint at what's behind, but menu TEXT must
	# not ghost through the title (vision QA at 0.94 read as clutter).
	_scrim = ColorRect.new()
	_scrim.color = Color(0.04, 0.03, 0.055, 0.965)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_scrim)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	# Touch phrasing only on real touch platforms — headless/desktop must
	# not claim taps (DisplayServer.is_touchscreen_available() lies in
	# headless runs and with emulate_touch_from_mouse).
	var pad := OS.get_name() in ["Android", "iOS"] or (
		OS.get_name() == "Web" and DisplayServer.is_touchscreen_available())
	var kicker := Label.new()
	kicker.text = "4:59 PM FRIDAY"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 16)
	kicker.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	center.add_child(kicker)

	_title_label = Label.new()
	_title_label.text = "FRIDAY 5PM\nEVACUATION"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 56)
	_title_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.ORANGE))
	_title_label.add_theme_constant_override("line_spacing", -8)
	center.add_child(_title_label)

	_sub_label = Label.new()
	_sub_label.text = "IT'S 4:59. ONE MINUTE TO FREEDOM."
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 15)
	_sub_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	center.add_child(_sub_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 26)
	center.add_child(spacer)

	_prompt_label = Label.new()
	_prompt_label.text = "TAP TO START" if pad else "CLICK TO START"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT))
	center.add_child(_prompt_label)

	var hint := Label.new()
	hint.text = "ENTER / SPACE / GAMEPAD A" if not pad else "ANY TAP"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	center.add_child(hint)

	# Small version tag bottom-right.
	var version := Label.new()
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.1.0")
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -140
	version.offset_top = -34
	version.offset_right = -16
	version.offset_bottom = -12
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED, 0.7))
	_root.add_child(version)

	# Hide the menu's UI column for the duration: ghost text under the
	# scrim reads as a rendering bug (vision QA). The animated backdrop
	# (MenuBackdrop) stays visible — that's the intended scenery.
	var menu := get_parent()
	if menu and menu.has_node("VBox"):
		(menu.get_node("VBox") as Control).modulate.a = 0.0

func _process(delta: float) -> void:
	_time += delta
	if _root:
		_root.modulate.a = clampf(_root.modulate.a + delta / 0.5, 0.0, 1.0)
	if _prompt_label:
		# Gentle breathing pulse on the prompt — invites without nagging.
		var pulse := 0.62 + 0.38 * (0.5 + 0.5 * sin(_time * 2.2))
		_prompt_label.modulate.a = pulse
	if _title_label:
		_title_label.modulate = Color(1, 1, 1, 1).lerp(
			Color(1.06, 0.94, 0.86), 0.5 + 0.5 * sin(_time * 1.1))

func _input(event: InputEvent) -> void:
	# _input, not _unhandled_input: the menu's focused PLAY button eats
	# ui_accept during GUI focus before unhandled input ever reaches us.
	if _dismissed:
		return
	if event.is_action_pressed("ui_accept"):
		_dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_dismiss()
		get_viewport().set_input_as_handled()

func _dismiss() -> void:
	if _dismissed:
		return
	_dismissed = true
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("powerup", 0.9)
	set_process_input(false)
	# Reveal the menu UI under the splash, then fade the layer out and
	# hand focus to the play button.
	var menu := get_parent()
	if menu and menu.has_node("VBox"):
		(menu.get_node("VBox") as Control).modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(func():
		var btn := _find_menu_play_button()
		if btn:
			btn.grab_focus()
		queue_free()
	)

func _find_menu_play_button() -> Button:
	var parent_menu := get_parent()
	if parent_menu == null:
		return null
	var btn = parent_menu.get_node_or_null("VBox/PlayButton")
	if btn and btn is Button:
		return btn
	return null
