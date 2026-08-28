extends Control

signal closed

var config := ConfigFile.new()
var quality_option: OptionButton
var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var shake_toggle: CheckButton
var flash_toggle: CheckButton
var ghost_toggle: CheckButton
var reduced_motion_toggle: CheckButton
var high_contrast_toggle: CheckButton
var subtitles_toggle: CheckButton
var time_scale_option: OptionButton
var keyboard_sens_slider: HSlider
var camera_sens_slider: HSlider
var _input_toggles: Dictionary = {}

const TIME_SCALE_LABELS := ["0.75x (SLOWER)", "1.0x (NORMAL)", "1.25x (FASTER)"]

func _ready() -> void:
	_load_settings()
	_build_ui()
	_apply_settings()

func _load_settings() -> void:
	config.load("user://settings.cfg")

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.04, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 620)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -310)
	add_child(panel)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("1c1c2e")
	style.border_color = Color("ff9a1a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)

	# Outer column: title / scrollable body / pinned BACK. (PanelContainer
	# stacks bare children on top of each other, so they must live in a
	# VBox.)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("ff9a1a"))
	column.add_child(title)

	# Scrollable body: the input section (sensitivity + mouse + controller
	# prefs) grew the panel past 720p, so rows live in a ScrollContainer
	# and BACK stays pinned below it.
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)

	quality_option = OptionButton.new()
	quality_option.add_item("LOW")
	quality_option.add_item("MEDIUM")
	quality_option.add_item("HIGH")
	_add_setting(box, "GRAPHICS QUALITY", quality_option)
	quality_option.item_selected.connect(func(_index): _apply_settings())

	master_slider = _make_slider()
	_add_setting(box, "MASTER VOLUME", master_slider)
	master_slider.value_changed.connect(func(_value): _apply_settings())
	music_slider = _make_slider()
	_add_setting(box, "MUSIC VOLUME", music_slider)
	music_slider.value_changed.connect(func(_value): _apply_settings())
	sfx_slider = _make_slider()
	_add_setting(box, "SFX VOLUME", sfx_slider)
	sfx_slider.value_changed.connect(func(_value): _apply_settings())

	shake_toggle = CheckButton.new()
	shake_toggle.text = "ENABLE SCREEN SHAKE"
	shake_toggle.button_pressed = bool(config.get_value("accessibility", "screen_shake", true))
	box.add_child(shake_toggle)
	shake_toggle.toggled.connect(func(_value): _apply_settings())

	flash_toggle = CheckButton.new()
	flash_toggle.text = "ENABLE FLASH EFFECTS"
	flash_toggle.button_pressed = bool(config.get_value("accessibility", "flash_effects", true))
	box.add_child(flash_toggle)
	flash_toggle.toggled.connect(func(_value): _apply_settings())

	ghost_toggle = CheckButton.new()
	ghost_toggle.text = "SINGLE-PLAYER GHOST PACER"
	ghost_toggle.button_pressed = bool(config.get_value("race", "ghost_enabled", true))
	box.add_child(ghost_toggle)
	ghost_toggle.toggled.connect(func(_value): _apply_settings())

	reduced_motion_toggle = CheckButton.new()
	reduced_motion_toggle.text = "REDUCED MOTION"
	reduced_motion_toggle.button_pressed = bool(config.get_value("accessibility", "reduced_motion", false))
	box.add_child(reduced_motion_toggle)
	reduced_motion_toggle.toggled.connect(func(_value): _apply_settings())

	high_contrast_toggle = CheckButton.new()
	high_contrast_toggle.text = "HIGH CONTRAST HUD"
	high_contrast_toggle.button_pressed = bool(config.get_value("accessibility", "high_contrast", false))
	box.add_child(high_contrast_toggle)
	high_contrast_toggle.toggled.connect(func(_value): _apply_settings())

	subtitles_toggle = CheckButton.new()
	subtitles_toggle.text = "AUDIO CUE SUBTITLES"
	subtitles_toggle.button_pressed = bool(config.get_value("accessibility", "subtitles", false))
	box.add_child(subtitles_toggle)
	subtitles_toggle.toggled.connect(func(_value): _apply_settings())

	time_scale_option = OptionButton.new()
	for label in TIME_SCALE_LABELS:
		time_scale_option.add_item(label)
	var saved_scale := float(config.get_value("accessibility", "time_scale", 1.0))
	time_scale_option.selected = _time_scale_index(saved_scale)
	_add_setting(box, "GAME SPEED (SINGLE PLAYER ONLY)", time_scale_option)
	time_scale_option.item_selected.connect(func(_index): _apply_settings())

	# --- INPUT: sensitivity, mouse look, controller prefs -------------------
	var kb_sens_label = Label.new()
	kb_sens_label.text = "INPUT"
	kb_sens_label.add_theme_font_size_override("font_size", 13)
	kb_sens_label.add_theme_color_override("font_color", Color("ff9a1a"))
	box.add_child(kb_sens_label)

	keyboard_sens_slider = HSlider.new()
	keyboard_sens_slider.min_value = 0.5
	keyboard_sens_slider.max_value = 1.5
	keyboard_sens_slider.step = 0.05
	keyboard_sens_slider.custom_minimum_size = Vector2(0, 28)
	keyboard_sens_slider.value = float(config.get_value("input", "keyboard_sensitivity", 0.7))
	_add_setting(box, "KEYBOARD SENSITIVITY (LOW = GENTLER STEERING)", keyboard_sens_slider)

	camera_sens_slider = HSlider.new()
	camera_sens_slider.min_value = 0.25
	camera_sens_slider.max_value = 2.0
	camera_sens_slider.step = 0.05
	camera_sens_slider.custom_minimum_size = Vector2(0, 28)
	camera_sens_slider.value = float(config.get_value("input", "mouse_sensitivity", 1.0))
	_add_setting(box, "CAMERA SENSITIVITY (MOUSE + RIGHT STICK)", camera_sens_slider)

	var mouse_look_toggle = CheckButton.new()
	mouse_look_toggle.text = "MOUSE CAMERA LOOK (MOVE MOUSE TO ORBIT)"
	mouse_look_toggle.button_pressed = bool(config.get_value("input", "mouse_look_enabled", true))
	box.add_child(mouse_look_toggle)
	_input_toggles["mouse_look_enabled"] = mouse_look_toggle

	var stick_look_toggle = CheckButton.new()
	stick_look_toggle.text = "RIGHT-STICK CAMERA LOOK"
	stick_look_toggle.button_pressed = bool(config.get_value("input", "stick_look_enabled", true))
	box.add_child(stick_look_toggle)
	_input_toggles["stick_look_enabled"] = stick_look_toggle

	var vibration_toggle = CheckButton.new()
	vibration_toggle.text = "CONTROLLER VIBRATION"
	vibration_toggle.button_pressed = bool(config.get_value("input", "vibration_enabled", true))
	box.add_child(vibration_toggle)
	_input_toggles["vibration_enabled"] = vibration_toggle

	var controller_hint = Label.new()
	controller_hint.text = "CONTROLLER: LEFT STICK MOVE / A BOOST / X ACTION / B SABOTAGE / START PAUSE / RIGHT STICK CAMERA / R RECENTERS ON KEYBOARD"
	controller_hint.add_theme_font_size_override("font_size", 10)
	controller_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	controller_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(controller_hint)

	var back = Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_size_override("font_size", 20)
	column.add_child(back)
	back.pressed.connect(_close)
	# Controller navigation: initial focus on BACK; dpad/stick walks the
	# settings rows (ui_up/ui_down), A presses the focused control.
	back.call_deferred("grab_focus")

func _add_setting(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	parent.add_child(label)
	parent.add_child(control)

func _make_slider() -> HSlider:
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(0, 28)
	return slider

func _apply_settings() -> void:
	if not quality_option:
		return
	var quality = quality_option.selected
	_apply_graphics_quality(quality)
	config.set_value("graphics", "quality", quality)
	config.set_value("audio", "master", master_slider.value / 100.0)
	config.set_value("audio", "music", music_slider.value / 100.0)
	config.set_value("audio", "sfx", sfx_slider.value / 100.0)
	config.set_value("accessibility", "screen_shake", shake_toggle.button_pressed)
	config.set_value("accessibility", "flash_effects", flash_toggle.button_pressed if flash_toggle else true)
	config.set_value("race", "ghost_enabled", ghost_toggle.button_pressed if ghost_toggle else true)
	config.set_value("accessibility", "reduced_motion", reduced_motion_toggle.button_pressed if reduced_motion_toggle else false)
	config.set_value("accessibility", "high_contrast", high_contrast_toggle.button_pressed if high_contrast_toggle else false)
	config.set_value("accessibility", "subtitles", subtitles_toggle.button_pressed if subtitles_toggle else false)
	if time_scale_option:
		config.set_value("accessibility", "time_scale", _time_scale_value(time_scale_option.selected))
	if keyboard_sens_slider and camera_sens_slider:
		config.set_value("input", "keyboard_sensitivity", keyboard_sens_slider.value)
		config.set_value("input", "mouse_sensitivity", camera_sens_slider.value)
		for key in _input_toggles:
			config.set_value("input", key, _input_toggles[key].button_pressed)
		# Live-apply: refresh InputPrefs caches so pause-menu changes take
		# effect the moment the player resumes (no restart needed).
		var prefs = load("res://scripts/InputPrefs.gd")
		if prefs and prefs.has_method("refresh_cache"):
			prefs.refresh_cache()
	config.save("user://settings.cfg")
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.set_sfx_volume((master_slider.value / 100.0) * (sfx_slider.value / 100.0))
		audio.set_music_volume((master_slider.value / 100.0) * (music_slider.value / 100.0))

func _time_scale_index(value: float) -> int:
	# Snap to the nearest supported option index (0=0.75, 1=1.0, 2=1.25)
	var options := [0.75, 1.0, 1.25]
	var best := 1
	var best_dist := absf(value - 1.0)
	for i in options.size():
		var dist := absf(value - options[i])
		if dist < best_dist:
			best_dist = dist
			best = i
	return best

func _time_scale_value(index: int) -> float:
	match index:
		0: return 0.75
		2: return 1.25
		_: return 1.0

func _apply_graphics_quality(quality: int) -> void:
	var root = get_tree().current_scene
	if not root:
		return
	var environment = root.get_node_or_null("WorldEnvironment")
	if environment and environment.environment:
		var env = environment.environment
		env.fog_enabled = quality > 0
		env.glow_enabled = quality > 0
		env.vignette_enabled = quality > 0
	var lights = root.find_children("*", "OmniLight3D", true, false)
	for light in lights:
		light.shadow_enabled = quality >= 2
	# Dust motes: hide (not free) so re-raising quality restores them.
	for motes in root.find_children("DustMotes*", "GPUParticles3D", true, false):
		motes.emitting = quality > 0
		motes.visible = quality > 0

func _close() -> void:
	closed.emit()
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY and quality_option:
		quality_option.select(int(config.get_value("graphics", "quality", 1)))
		master_slider.value = float(config.get_value("audio", "master", 1.0)) * 100.0
		music_slider.value = float(config.get_value("audio", "music", 0.5)) * 100.0
		sfx_slider.value = float(config.get_value("audio", "sfx", 0.8)) * 100.0
		shake_toggle.button_pressed = bool(config.get_value("accessibility", "screen_shake", true))
