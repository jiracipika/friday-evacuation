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
var _remap_buttons: Dictionary = {}  # action -> {"key": Button, "pad": Button}
var _remap_action := ""  # non-empty while listening for a key or pad button
var _remap_kind := ""  # "kb" or "pad" — which column is armed
var _restoring := false  # blocks reentrant _apply_settings during value restore
const UI_THEME = preload("res://scripts/UITheme.gd")

const TIME_SCALE_LABELS := ["0.75x (SLOWER)", "1.0x (NORMAL)", "1.25x (FASTER)"]

class MeterTrack extends Control:
	## S-D slider fill: StyleBoxFlat grooves can't do partial fill and
	## HSlider has none either, so each HSlider is wrapped in this Control
	## which _draw()s the two-part track BEHIND the (transparent-groove)
	## native slider. Wrapper is mouse-IGNORE: input passes to the child.
	var slider: HSlider
	var _bg := StyleBoxFlat.new()
	var _fill_a := StyleBoxFlat.new()
	var _fill_b := StyleBoxFlat.new()

	func _init() -> void:
		custom_minimum_size = Vector2(0, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg.bg_color = Color("262638")
		_bg.set_corner_radius_all(3)
		_fill_a.bg_color = Color("ff9a1a")  # ORANGE
		_fill_a.set_corner_radius_all(3)
		_fill_b.bg_color = Color("ffbd4a")  # ORANGE_BRIGHT
		_fill_b.set_corner_radius_all(3)

	func _ready() -> void:
		slider.value_changed.connect(func(_v): queue_redraw())
		slider.resized.connect(queue_redraw)

	func track_rect() -> Rect2:
		var h := 6.0
		return Rect2(0.0, (size.y - h) * 0.5, size.x, h)

	func get_fill_fraction() -> float:
		if slider == null or slider.max_value <= slider.min_value:
			return 0.0
		return clampf((slider.value - slider.min_value) / (slider.max_value - slider.min_value), 0.0, 1.0)

	func get_fill_width() -> float:
		return get_fill_fraction() * track_rect().size.x

	func _draw() -> void:
		var track := track_rect()
		draw_style_box(_bg, track)
		var w := get_fill_width()
		if w <= 0.0:
			return
		var split := w * 0.6  # cheap two-rect ORANGE -> ORANGE_BRIGHT gradient
		draw_style_box(_fill_a, Rect2(track.position, Vector2(split, track.size.y)))
		draw_style_box(_fill_b, Rect2(track.position + Vector2(split, 0.0), Vector2(w - split, track.size.y)))

## S-D scroll fade: 6 stacked INK rects, alpha 0.0 (top) -> 0.9 (bottom).
class ScrollFade extends Control:
	const STEPS := 6
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var h := size.y / STEPS
		for i in STEPS:
			var a := 0.9 * float(i) / float(STEPS - 1)
			draw_rect(Rect2(0.0, i * h, size.x, h), Color(0.137, 0.075, 0.012, a))  # INK

## Safe bool read for cfg values: GDScript's bool() CRASHES on String
## values ("Nonexistent 'bool' constructor") and a hand-edited cfg can
## hold "yes"/"no". Non-bool -> default.
static func _cfg_bool(cfg: ConfigFile, section: String, key: String, default: bool) -> bool:
	var v: Variant = cfg.get_value(section, key, default)
	return v if v is bool else default

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
	# S-D portrait: below 560px the desktop 520px panel cannot fit, so it
	# becomes a full-bleed sheet; the body scroll + row ellipsis absorb the
	# remaining squeeze. Desktop keeps the centered 520x620 card.
	if get_viewport_rect().size.x < 560.0:
		panel.custom_minimum_size = Vector2(0, 620)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	else:
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

	# S-D header: title row carries the autosave indicator (LIME, tracked).
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title = Label.new()
	title.text = "SETTINGS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("ff9a1a"))
	title_row.add_child(title)
	var autosave = Label.new()
	autosave.name = "AutosaveLabel"
	autosave.text = "● AUTOSAVED"
	autosave.add_theme_font_size_override("font_size", 11)
	autosave.add_theme_color_override("font_color", Color("b9f34a"))
	title_row.add_child(autosave)

	# Scrollable body: the input section (sensitivity + mouse + controller
	# prefs) grew the panel past 720p, so rows live in a ScrollContainer
	# and BACK stays pinned below it.
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	# S-D scroll fade: 6-step INK gradient pinned to the bottom edge.
	var scroll_fade := ScrollFade.new()
	scroll_fade.name = "ScrollFade"
	scroll_fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	scroll_fade.offset_top = -26.0
	scroll_fade.z_index = 10
	column.add_child(scroll_fade)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)

	box.add_child(UI_THEME.make_section_header("VIDEO"))
	quality_option = OptionButton.new()
	quality_option.add_item("STANDARD")
	quality_option.add_item("ENHANCED")
	quality_option.clip_text = true
	quality_option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI_THEME.style_option_button(quality_option)
	_add_setting(box, "GRAPHICS QUALITY", quality_option)
	quality_option.item_selected.connect(func(_index): _apply_settings())

	box.add_child(UI_THEME.make_section_header("AUDIO"))
	master_slider = _make_slider()
	_add_slider_setting(box, "MASTER VOLUME", master_slider)
	master_slider.value_changed.connect(func(_value): _apply_settings())
	music_slider = _make_slider()
	_add_slider_setting(box, "MUSIC VOLUME", music_slider)
	music_slider.value_changed.connect(func(_value): _apply_settings())
	sfx_slider = _make_slider()
	_add_slider_setting(box, "SFX VOLUME", sfx_slider)
	sfx_slider.value_changed.connect(func(_value): _apply_settings())

	box.add_child(UI_THEME.make_section_header("ACCESSIBILITY"))
	shake_toggle = CheckButton.new()
	shake_toggle.text = "ENABLE SCREEN SHAKE"
	shake_toggle.button_pressed = _cfg_bool(config, "accessibility", "screen_shake", true)
	UI_THEME.styled_checkbutton(shake_toggle)
	_add_toggle_row(box, shake_toggle)
	shake_toggle.toggled.connect(func(_value): _apply_settings())

	flash_toggle = CheckButton.new()
	flash_toggle.text = "ENABLE FLASH EFFECTS"
	flash_toggle.button_pressed = _cfg_bool(config, "accessibility", "flash_effects", true)
	UI_THEME.styled_checkbutton(flash_toggle)
	_add_toggle_row(box, flash_toggle)
	flash_toggle.toggled.connect(func(_value): _apply_settings())

	ghost_toggle = CheckButton.new()
	ghost_toggle.text = "SINGLE-PLAYER GHOST PACER"
	ghost_toggle.button_pressed = _cfg_bool(config, "race", "ghost_enabled", true)
	UI_THEME.styled_checkbutton(ghost_toggle)
	_add_toggle_row(box, ghost_toggle)
	ghost_toggle.toggled.connect(func(_value): _apply_settings())

	reduced_motion_toggle = CheckButton.new()
	reduced_motion_toggle.text = "REDUCED MOTION"
	reduced_motion_toggle.button_pressed = _cfg_bool(config, "accessibility", "reduced_motion", false)
	UI_THEME.styled_checkbutton(reduced_motion_toggle)
	_add_toggle_row(box, reduced_motion_toggle)
	reduced_motion_toggle.toggled.connect(func(_value): _apply_settings())

	high_contrast_toggle = CheckButton.new()
	high_contrast_toggle.text = "HIGH CONTRAST HUD"
	high_contrast_toggle.button_pressed = _cfg_bool(config, "accessibility", "high_contrast", false)
	UI_THEME.styled_checkbutton(high_contrast_toggle)
	_add_toggle_row(box, high_contrast_toggle)
	high_contrast_toggle.toggled.connect(func(_value): _apply_settings())

	subtitles_toggle = CheckButton.new()
	subtitles_toggle.text = "AUDIO CUE SUBTITLES"
	subtitles_toggle.button_pressed = _cfg_bool(config, "accessibility", "subtitles", false)
	UI_THEME.styled_checkbutton(subtitles_toggle)
	_add_toggle_row(box, subtitles_toggle)
	subtitles_toggle.toggled.connect(func(_value): _apply_settings())

	time_scale_option = OptionButton.new()
	for label in TIME_SCALE_LABELS:
		time_scale_option.add_item(label)
	time_scale_option.clip_text = true
	time_scale_option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI_THEME.style_option_button(time_scale_option)
	var saved_scale := float(config.get_value("accessibility", "time_scale", 1.0))
	time_scale_option.selected = _time_scale_index(saved_scale)
	_add_setting(box, "GAME SPEED (SINGLE PLAYER ONLY)", time_scale_option)
	time_scale_option.item_selected.connect(func(_index): _apply_settings())

	# --- INPUT: scheme, sensitivity, mouse look, controller prefs --------
	box.add_child(UI_THEME.make_section_header("INPUT"))

	# Control scheme: AUTO follows whichever device was touched last
	# (persisted); manual entries pin one scheme. This is the "easy switch".
	scheme_option = OptionButton.new()
	scheme_option.add_item("AUTO (FOLLOWS LAST DEVICE USED)")
	scheme_option.add_item("KEYBOARD & MOUSE")
	scheme_option.add_item("CONTROLLER")
	scheme_option.clip_text = true
	scheme_option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI_THEME.style_option_button(scheme_option)
	var saved_scheme: String = String(config.get_value("input", "control_scheme", "auto"))
	scheme_option.selected = 0 if saved_scheme == "auto" else (1 if saved_scheme == "keyboard_mouse" else 2)
	_add_setting(box, "CONTROL SCHEME", scheme_option)
	scheme_option.item_selected.connect(func(_index): _apply_settings())

	keyboard_sens_slider = HSlider.new()
	keyboard_sens_slider.min_value = 0.15
	keyboard_sens_slider.max_value = 1.5
	keyboard_sens_slider.step = 0.05
	keyboard_sens_slider.custom_minimum_size = Vector2(0, 28)
	keyboard_sens_slider.value = float(config.get_value("input", "keyboard_sensitivity", 0.35))
	UI_THEME.styled_slider(keyboard_sens_slider)
	_add_slider_setting(box, "KEYBOARD SENSITIVITY (LOW = GENTLER STEERING)", keyboard_sens_slider)

	camera_sens_slider = HSlider.new()
	camera_sens_slider.min_value = 0.25
	camera_sens_slider.max_value = 2.0
	camera_sens_slider.step = 0.05
	camera_sens_slider.custom_minimum_size = Vector2(0, 28)
	camera_sens_slider.value = float(config.get_value("input", "mouse_sensitivity", 0.8))
	UI_THEME.styled_slider(camera_sens_slider)
	_add_slider_setting(box, "CAMERA SENSITIVITY (MOUSE + RIGHT STICK)", camera_sens_slider)

	invert_toggle = CheckButton.new()
	invert_toggle.text = "INVERT CAMERA PAN"
	invert_toggle.button_pressed = bool(config.get_value("input", "invert_camera_x", false))
	UI_THEME.styled_checkbutton(invert_toggle)
	_add_toggle_row(box, invert_toggle)
	invert_toggle.toggled.connect(func(_value): _apply_settings())

	var mouse_look_toggle = CheckButton.new()
	mouse_look_toggle.text = "MOUSE CAMERA LOOK (MOVE MOUSE TO ORBIT)"
	mouse_look_toggle.button_pressed = bool(config.get_value("input", "mouse_look_enabled", true))
	UI_THEME.styled_checkbutton(mouse_look_toggle)
	_add_toggle_row(box, mouse_look_toggle)
	_input_toggles["mouse_look_enabled"] = mouse_look_toggle

	var stick_look_toggle = CheckButton.new()
	stick_look_toggle.text = "RIGHT-STICK CAMERA LOOK"
	stick_look_toggle.button_pressed = bool(config.get_value("input", "stick_look_enabled", true))
	UI_THEME.styled_checkbutton(stick_look_toggle)
	_add_toggle_row(box, stick_look_toggle)
	_input_toggles["stick_look_enabled"] = stick_look_toggle

	var vibration_toggle = CheckButton.new()
	vibration_toggle.text = "CONTROLLER VIBRATION"
	vibration_toggle.button_pressed = bool(config.get_value("input", "vibration_enabled", true))
	UI_THEME.styled_checkbutton(vibration_toggle)
	_add_toggle_row(box, vibration_toggle)
	_input_toggles["vibration_enabled"] = vibration_toggle

	# PHASE 3: stick response curve selector.
	var narrow: bool = get_viewport_rect().size.x < 560.0
	var curve_row := HBoxContainer.new()
	var curve_label := Label.new()
	curve_label.text = "STICK RESPONSE"
	curve_label.add_theme_font_size_override("font_size", 12)
	curve_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	# S-D portrait: the 190px label column + 190px dropdown cannot fit 390;
	# at narrow the label clips and the dropdown keeps the row's width.
	curve_label.custom_minimum_size = Vector2(0 if narrow else 190, 0)
	curve_label.clip_text = true
	curve_label.size_flags_horizontal = Control.SIZE_FILL
	curve_row.add_child(curve_label)
	var curve_option := OptionButton.new()
	curve_option.add_item("LINEAR", 0)
	curve_option.add_item("EXPO (RACING)", 1)
	curve_option.add_item("PRECISION", 2)
	var saved_curve := str(config.get_value("input", "stick_response_curve", "expo"))
	curve_option.select({"linear": 0, "expo": 1, "precision": 2}.get(saved_curve, 1))
	curve_option.custom_minimum_size = Vector2(190, 0)
	curve_option.clip_text = true
	curve_option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UI_THEME.style_option_button(curve_option)
	curve_row.add_child(curve_option)
	box.add_child(curve_row)
	self.curve_option = curve_option

	# --- button remapping (keyboard/mouse + controller, live-applied) ----
	var remap_title = Label.new()
	remap_title.text = "CONTROLS — TAP A ROW, THEN PRESS A KEY OR PAD BUTTON"
	remap_title.add_theme_font_size_override("font_size", 13)
	remap_title.add_theme_color_override("font_color", Color("ff9a1a"))
	# S-D portrait: 13px one-liner measured 388px — wrap instead of overflow.
	remap_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(remap_title)

	remap_grid = GridContainer.new()
	remap_grid.columns = 3
	remap_grid.add_theme_constant_override("h_separation", 10)
	remap_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(remap_grid)
	_build_remap_rows()

	var reset_remap = Button.new()
	reset_remap.text = "RESET ALL CONTROLS TO DEFAULT"
	reset_remap.add_theme_font_size_override("font_size", 13)
	reset_remap.clip_text = true
	reset_remap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(reset_remap)
	reset_remap.pressed.connect(_reset_remap)

	var controller_hint = Label.new()
	controller_hint.text = "STICKS MOVE/CAMERA  •  DEDICATED RECENTER: Y / TRIANGLE (PAD) OR R (KEYBOARD)  •  SCHEME AUTO-SWITCHES WHEN YOU GRAB THE OTHER DEVICE — OR PIN IT ABOVE"
	controller_hint.add_theme_font_size_override("font_size", 10)
	controller_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	controller_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(controller_hint)

	# S-D footer: hairline + BACK + version in one row.
	var hairline := HSeparator.new()
	var hb_style := StyleBoxFlat.new()
	hb_style.bg_color = Color(1, 1, 1, 0.09)
	hb_style.content_margin_top = 1.0
	hb_style.content_margin_bottom = 1.0
	hairline.add_theme_stylebox_override("separator", hb_style)
	column.add_child(hairline)
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	var back = Button.new()
	back.text = "BACK"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_size_override("font_size", 20)
	footer.add_child(back)
	back.pressed.connect(_close)
	var version = Label.new()
	version.name = "VersionLabel"
	version.text = "v0.9 · 26 SEP 26"
	version.add_theme_font_size_override("font_size", 10)
	version.add_theme_color_override("font_color", Color("9a9aae"))
	version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(version)
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

## Two-column binding rows: ACTION | KEY/MOUSE | PAD. Capture is armed per
## cell ("kb" listens for key/mouse, "pad" for pad buttons).
func _build_remap_rows() -> void:
	if remap_grid == null:
		return
	for child in remap_grid.get_children():
		child.queue_free()
	_remap_buttons.clear()
	var headers := ["ACTION", "KEY / MOUSE", "CONTROLLER"]
	for h in headers:
		var hl = Label.new()
		hl.text = h
		hl.add_theme_font_size_override("font_size", 11)
		hl.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		remap_grid.add_child(hl)
	for action in REMAP_ACTIONS:
		var label = Label.new()
		label.text = REMAP_LABELS[action]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
		remap_grid.add_child(label)
		var kbtn = Button.new()
		kbtn.custom_minimum_size = Vector2(0, 34)
		kbtn.add_theme_font_size_override("font_size", 13)
		kbtn.clip_text = true
		kbtn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var bound_kb: String = action
		kbtn.pressed.connect(func(): _remap_listen(bound_kb, "kb", kbtn))
		remap_grid.add_child(kbtn)
		var pbtn = Button.new()
		pbtn.custom_minimum_size = Vector2(0, 34)
		pbtn.add_theme_font_size_override("font_size", 13)
		pbtn.clip_text = true
		pbtn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var bound_pad: String = action
		pbtn.pressed.connect(func(): _remap_listen(bound_pad, "pad", pbtn))
		remap_grid.add_child(pbtn)
		_remap_buttons[action] = {"key": kbtn, "pad": pbtn}
	_refresh_remap_labels()

## Arm one cell to capture the next key/mouse button or pad button press.
func _remap_listen(action: String, kind: String, btn: Button) -> void:
	_remap_action = action
	_remap_kind = kind
	btn.text = "PRESS…"
	btn.grab_focus()

func _reset_remap() -> void:
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs == null:
		return
	prefs.reset_bindings()
	_refresh_remap_labels()

func _refresh_remap_labels() -> void:
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs == null:
		return
	for action in _remap_buttons:
		var cells: Dictionary = _remap_buttons[action]
		if action == _remap_action:
			var armed: Button = cells.get(_remap_kind, cells["key"])
			armed.text = "PRESS…"
			var idle: Button = cells.get("pad" if _remap_kind == "kb" else "key")
			if idle:
				idle.text = prefs.key_binding_name(action) if _remap_kind == "pad" else prefs.pad_button_name(action)
			continue
		var kb: Button = cells["key"]
		kb.text = prefs.key_binding_name(action)
		var pb: Button = cells["pad"]
		pb.text = prefs.pad_button_name(action)

## Capture the pressed key/mouse/pad button for the armed action.
## InputHelper auto-swaps conflicts; InputPrefs persists the whole blob.
func _input(event: InputEvent) -> void:
	if _remap_action == "":
		return
	# S-PAD: while a remap cell is armed, suppress Main's OptionButton
	# pad-cycling so ui_left/right binds instead of cycling dropdowns.
	var main_ctl := get_tree().root.get_node_or_null("Main")
	if main_ctl and "remap_capture_active" in main_ctl:
		main_ctl.set("remap_capture_active", true)
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs == null:
		_remap_action = ""
		return
	var accepted := false
	if _remap_kind == "pad" and event is InputEventJoypadButton and event.pressed:
		accepted = prefs.set_pad_binding(_remap_action, event)
	elif _remap_kind == "kb" and event is InputEventKey and event.pressed and not event.echo:
		# Escape cancels listening; other keys bind (physical keycode kept).
		if event.physical_keycode == KEY_ESCAPE:
			accepted = false
		else:
			accepted = prefs.set_key_binding(_remap_action, event)
	elif _remap_kind == "kb" and event is InputEventMouseButton and event.pressed:
		accepted = prefs.set_key_binding(_remap_action, event)
	if accepted or event is InputEventKey:
		_remap_action = ""
		if main_ctl and "remap_capture_active" in main_ctl:
			main_ctl.set("remap_capture_active", false)
		_refresh_remap_labels()
		get_viewport().set_input_as_handled()

func _make_slider() -> HSlider:
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(0, 28)
	UI_THEME.styled_slider(slider)
	# S-D: transparent groove — the MeterTrack wrapper draws the visible
	# fill BEHIND the slider (wrapper added as sibling-parent below).
	var empty := StyleBoxEmpty.new()
	slider.add_theme_stylebox_override("slider", empty)
	return slider

## S-D: ONE label pattern for slider rows — name left, tabular orange value
## right, full-width slider (inside its MeterTrack wrapper) beneath.
func _add_slider_setting(parent: VBoxContainer, label_text: String, slider: HSlider) -> void:
	var label = Label.new()
	label.text = label_text
	label.clip_text = true
	label.custom_minimum_size = Vector2(0, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	var value = Label.new()
	value.name = "ValueLabel"
	value.text = str(int(slider.value))
	value.custom_minimum_size = Vector2(44, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", Color("ff9a1a"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(label)
	row.add_child(value)
	parent.add_child(row)
	var wrapper := MeterTrack.new()
	wrapper.name = "MeterTrack"
	wrapper.slider = slider
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(slider)
	slider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slider.size_flags_vertical = Control.SIZE_FILL
	parent.add_child(wrapper)
	# Keep the value label live as the slider moves.
	slider.value_changed.connect(func(v: float):
		if is_instance_valid(value):
			value.text = str(int(round(v))))

## S-D toggle row: text state tag ("ON" LIME / "OFF" faint) BEFORE the
## CheckButton, kept in sync on every toggle so ON state reads at a glance.
func _add_toggle_row(parent: VBoxContainer, toggle: CheckButton) -> void:
	var tag := Label.new()
	tag.name = "StateTag"
	tag.custom_minimum_size = Vector2(30, 0)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.name = "ToggleRow"
	row.add_theme_constant_override("separation", 10)
	# S-D portrait: CheckButton text is the row's only unbounded width —
	# clip to ellipsis so long toggles shrink instead of overflowing 390px
	# (desktop has the space and never truncates).
	toggle.clip_text = true
	toggle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(tag)
	row.add_child(toggle)
	parent.add_child(row)
	_refresh_toggle_tag(toggle)
	toggle.toggled.connect(func(_pressed): _refresh_toggle_tag(toggle))

func _refresh_toggle_tag(toggle: CheckButton) -> void:
	var row := toggle.get_parent()
	if row == null or not (row is HBoxContainer):
		return
	var tag: Label = row.get_node_or_null("StateTag")
	if tag == null:
		return
	tag.text = "ON" if toggle.button_pressed else "OFF"
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color("b9f34a") if toggle.button_pressed else Color("9a9aae"))

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
	# Sync keys Settings itself doesn't own into the snapshot BEFORE
	# saving. Remaps and device-memory write through InputPrefs immediately
	# (separate cfg writes); without these syncs, config.save would
	# restore the mount-time snapshot and wipe them (clobber class bug).
	var bprefs = load("res://scripts/InputPrefs.gd")
	if bprefs:
		config.set_value("input", "action_bindings_serialized",
			bprefs.get_setting(bprefs.KEY_BINDINGS, ""))
		config.set_value("input", "last_device", bprefs.get_setting(bprefs.KEY_LAST_DEVICE, "keyboard_mouse"))
	config.save("user://settings.cfg")
	# Volume math: master is applied ONCE at the bus level by combining it
	# with each category here. AudioManager.set_*_volume drives ONLY the
	# bus — it must not also set per-player volume_db, or the combined
	# value gets squared ((master*sfx)² → 50%+50% played at ~6%).
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

## A2 preset remap (PRESETS.md §2-§4): Standard/Enhanced differ only in
## resolution cap, frame cap, filtering, and shadow sharpness — NEVER in
## effects. Fog/glow/vignette are off on every preset; omni shadows are off
## on every preset; the decorative mote pool is fixed, not quality-gated.
## Quality never removes hiding cover (fairness invariant §9).
func _apply_graphics_quality(quality: int) -> void:
	var root = get_tree().current_scene
	if not root:
		return
	var enhanced := quality >= 1
	var environment = root.get_node_or_null("WorldEnvironment")
	if environment and environment.environment:
		var env = environment.environment
		env.fog_enabled = false
		env.glow_enabled = false
		if "vignette_enabled" in env:
			env.vignette_enabled = false
	var key = root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if key:
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		key.directional_shadow_max_distance = 28.0
		key.shadow_blur = 1.0 if enhanced else 2.0
		key.directional_shadow_blend_splits = true
		key.shadow_bias = 0.05
		key.shadow_normal_bias = 1.0

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
	var raw_q := int(config.get_value("graphics", "quality", 0))
	# Migration: LOW/MEDIUM/HIGH era values (0/1/2) collapse to Standard(0);
	# Enhanced(1) is opt-in under the new two-preset model (PRESETS.md §1).
	if raw_q > 1:
		raw_q = 0
	quality_option.select(raw_q)
	master_slider.value = float(config.get_value("audio", "master", 1.0)) * 100.0
	music_slider.value = float(config.get_value("audio", "music", 0.5)) * 100.0
	sfx_slider.value = float(config.get_value("audio", "sfx", 0.8)) * 100.0
	shake_toggle.button_pressed = _cfg_bool(config, "accessibility", "screen_shake", true)
	_restoring = false
