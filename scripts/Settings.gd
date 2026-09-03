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
var scheme_option: OptionButton
var curve_option: OptionButton
var invert_toggle: CheckButton
var remap_grid: GridContainer
var _input_toggles: Dictionary = {}
var _remap_buttons: Dictionary = {}  # action -> Button
var _remap_action := ""  # non-empty while listening for a pad button
var _restoring := false  # blocks reentrant _apply_settings during value restore

const TIME_SCALE_LABELS := ["0.75x (SLOWER)", "1.0x (NORMAL)", "1.25x (FASTER)"]

func _ready() -> void:
	_load_settings()
	_build_ui()
	_restore_persisted_values()
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

	# --- INPUT: scheme, sensitivity, mouse look, controller prefs --------
	var kb_sens_label = Label.new()
	kb_sens_label.text = "INPUT"
	kb_sens_label.add_theme_font_size_override("font_size", 13)
	kb_sens_label.add_theme_color_override("font_color", Color("ff9a1a"))
	box.add_child(kb_sens_label)

	# Control scheme: AUTO follows whichever device was touched last
	# (persisted); manual entries pin one scheme. This is the "easy switch".
	scheme_option = OptionButton.new()
	scheme_option.add_item("AUTO (FOLLOWS LAST DEVICE USED)")
	scheme_option.add_item("KEYBOARD & MOUSE")
	scheme_option.add_item("CONTROLLER")
	var saved_scheme: String = String(config.get_value("input", "control_scheme", "auto"))
	scheme_option.selected = 0 if saved_scheme == "auto" else (1 if saved_scheme == "keyboard_mouse" else 2)
	_add_setting(box, "CONTROL SCHEME", scheme_option)
	scheme_option.item_selected.connect(func(_index): _apply_settings())

	keyboard_sens_slider = HSlider.new()
	keyboard_sens_slider.min_value = 0.35
	keyboard_sens_slider.max_value = 1.5
	keyboard_sens_slider.step = 0.05
	keyboard_sens_slider.custom_minimum_size = Vector2(0, 28)
	keyboard_sens_slider.value = float(config.get_value("input", "keyboard_sensitivity", 0.55))
	_add_setting(box, "KEYBOARD SENSITIVITY (LOW = GENTLER STEERING)", keyboard_sens_slider)

	camera_sens_slider = HSlider.new()
	camera_sens_slider.min_value = 0.25
	camera_sens_slider.max_value = 2.0
	camera_sens_slider.step = 0.05
	camera_sens_slider.custom_minimum_size = Vector2(0, 28)
	camera_sens_slider.value = float(config.get_value("input", "mouse_sensitivity", 0.8))
	_add_setting(box, "CAMERA SENSITIVITY (MOUSE + RIGHT STICK)", camera_sens_slider)

	invert_toggle = CheckButton.new()
	invert_toggle.text = "INVERT CAMERA PAN"
	invert_toggle.button_pressed = bool(config.get_value("input", "invert_camera_x", false))
	box.add_child(invert_toggle)
	invert_toggle.toggled.connect(func(_value): _apply_settings())

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

	# PHASE 3: stick response curve selector.
	var curve_row := HBoxContainer.new()
	var curve_label := Label.new()
	curve_label.text = "STICK RESPONSE"
	curve_label.add_theme_font_size_override("font_size", 12)
	curve_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	curve_label.custom_minimum_size = Vector2(190, 0)
	curve_row.add_child(curve_label)
	var curve_option := OptionButton.new()
	curve_option.add_item("LINEAR", 0)
	curve_option.add_item("EXPO (RACING)", 1)
	curve_option.add_item("PRECISION", 2)
	var saved_curve := str(config.get_value("input", "stick_response_curve", "expo"))
	curve_option.select({"linear": 0, "expo": 1, "precision": 2}.get(saved_curve, 1))
	curve_option.custom_minimum_size = Vector2(190, 0)
	curve_row.add_child(curve_option)
	box.add_child(curve_row)
	self.curve_option = curve_option

	# --- controller button remapping (easy, live-applied) ----------------
	var remap_title = Label.new()
	remap_title.text = "CONTROLLER BUTTONS — TAP A ROW, THEN PRESS A PAD BUTTON"
	remap_title.add_theme_font_size_override("font_size", 13)
	remap_title.add_theme_color_override("font_color", Color("ff9a1a"))
	box.add_child(remap_title)

	remap_grid = GridContainer.new()
	remap_grid.columns = 2
	remap_grid.add_theme_constant_override("h_separation", 10)
	remap_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(remap_grid)
	_build_remap_rows()

	var reset_remap = Button.new()
	reset_remap.text = "RESET CONTROLLER BUTTONS TO DEFAULT"
	reset_remap.add_theme_font_size_override("font_size", 13)
	box.add_child(reset_remap)
	reset_remap.pressed.connect(_reset_remap)

	var controller_hint = Label.new()
	controller_hint.text = "STICKS MOVE/CAMERA  •  DEDICATED RECENTER: Y / TRIANGLE (PAD) OR R (KEYBOARD)  •  SCHEME AUTO-SWITCHES WHEN YOU GRAB THE OTHER DEVICE — OR PIN IT ABOVE"
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

# --- controller remap helpers ------------------------------------------------

const REMAP_ACTIONS := ["boost", "action", "sabotage", "pause", "recenter_camera"]
const REMAP_LABELS := {
	"boost": "BOOST",
	"action": "ACTION / INTERACT",
	"sabotage": "SABOTAGE",
	"pause": "PAUSE",
	"recenter_camera": "RECENTER CAMERA",
}

func _build_remap_rows() -> void:
	var prefs = load("res://scripts/InputPrefs.gd")
	if remap_grid == null:
		return
	for child in remap_grid.get_children():
		child.queue_free()
	_remap_buttons.clear()
	for action in REMAP_ACTIONS:
		var label = Label.new()
		label.text = REMAP_LABELS[action]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
		remap_grid.add_child(label)
		var btn = Button.new()
		btn.text = "…" if prefs == null else prefs.pad_button_name(action)
		btn.custom_minimum_size = Vector2(0, 34)
		btn.add_theme_font_size_override("font_size", 13)
		var bound_action: String = action
		btn.pressed.connect(func(): _remap_listen(bound_action, btn))
		remap_grid.add_child(btn)
		_remap_buttons[action] = btn

## Arm one row to capture the next pad button press. The button caption
## flips to "PRESS A PAD BUTTON…"; the next InputEventJoypadButton wins.
func _remap_listen(action: String, btn: Button) -> void:
	_remap_action = action
	btn.text = "PRESS A PAD BUTTON…"
	btn.grab_focus()

func _reset_remap() -> void:
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs == null:
		return
	for action in REMAP_ACTIONS:
		prefs.set_pad_button(action, prefs.DEFAULT_PAD_MAP[action])
	config.set_value("input", "pad_button_map", prefs.pad_button_map())
	_refresh_remap_labels()

func _refresh_remap_labels() -> void:
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs == null:
		return
	for action in _remap_buttons:
		if action == _remap_action:
			continue
		var b: Button = _remap_buttons[action]
		b.text = prefs.pad_button_name(action)

## Capture the pressed pad button for the armed action.
func _input(event: InputEvent) -> void:
	if _remap_action == "":
		return
	if event is InputEventJoypadButton and event.pressed:
		var prefs = load("res://scripts/InputPrefs.gd")
		if prefs:
			prefs.set_pad_button(_remap_action, event.button_index)
			# Keep the local snapshot in sync so the next _apply_settings
			# save doesn't clobber the remap on disk.
			config.set_value("input", "pad_button_map", prefs.pad_button_map())
		_remap_action = ""
		_refresh_remap_labels()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		# Any key press cancels listening (escape hatch without a pad).
		_remap_action = ""
		_refresh_remap_labels()
		get_viewport().set_input_as_handled()

func _make_slider() -> HSlider:
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(0, 28)
	return slider

func _apply_settings() -> void:
	# Reentrancy guard: setting a slider value inside _restore_persisted_values
	# fires value_changed -> this function, which would save the NOT-YET-
	# restored sliders (music/sfx read 0) over the live cfg. That race is
	# exactly how opening Settings used to zero the audio settings.
	if _restoring:
		return
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
		# Phase 8B live-apply: pause-menu change takes effect immediately
		# (no restart). apply_time_scale() resolves network-peer safety and
		# snaps corrupt values; reset if no option is selected.
		var a11y = load("res://scripts/Accessibility.gd")
		if a11y:
			if time_scale_option.selected >= 0:
				a11y.apply_time_scale()
			else:
				a11y.reset_time_scale()
	if keyboard_sens_slider and camera_sens_slider:
		config.set_value("input", "keyboard_sensitivity", keyboard_sens_slider.value)
		config.set_value("input", "mouse_sensitivity", camera_sens_slider.value)
		config.set_value("input", "stick_sensitivity", camera_sens_slider.value)
		for key in _input_toggles:
			config.set_value("input", key, _input_toggles[key].button_pressed)
		# Stick response curve (Phase 3).
		if curve_option:
			var curve_names := ["linear", "expo", "precision"]
			config.set_value("input", "stick_response_curve",
				curve_names[clampi(curve_option.selected, 0, 2)])
		# Live-apply: refresh InputPrefs caches so pause-menu changes take
		# effect the moment the player resumes (no restart needed).
		var prefs = load("res://scripts/InputPrefs.gd")
		if prefs and prefs.has_method("refresh_cache"):
			prefs.refresh_cache()
	if scheme_option:
		var scheme := "auto"
		if scheme_option.selected == 1:
			scheme = "keyboard_mouse"
		elif scheme_option.selected == 2:
			scheme = "controller"
		config.set_value("input", "control_scheme", scheme)
		var prefs2 = load("res://scripts/InputPrefs.gd")
		if prefs2:
			prefs2.set_scheme_mode(StringName(scheme))
	if invert_toggle:
		config.set_value("input", "invert_camera_x", invert_toggle.button_pressed)
		var prefs3 = load("res://scripts/InputPrefs.gd")
		if prefs3:
			prefs3.set_invert_camera_x(invert_toggle.button_pressed)
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

## Restore every control's value from the persisted cfg BEFORE the first
## _apply_settings() save. (The old _notification(READY) hook was dead:
## NOTIFICATION_READY fires before _ready() builds the controls, so its
## quality_option guard was always false — and the first _apply_settings
## then persisted quality=0 + audio 0.0, silently zeroing the player's
## graphics/audio settings on every Settings open.)
func _restore_persisted_values() -> void:
	if quality_option == null:
		return
	_restoring = true
	quality_option.select(int(config.get_value("graphics", "quality", 1)))
	master_slider.value = float(config.get_value("audio", "master", 1.0)) * 100.0
	music_slider.value = float(config.get_value("audio", "music", 0.5)) * 100.0
	sfx_slider.value = float(config.get_value("audio", "sfx", 0.8)) * 100.0
	shake_toggle.button_pressed = bool(config.get_value("accessibility", "screen_shake", true))
	_restoring = false
