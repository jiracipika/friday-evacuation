extends Control

signal closed

var config := ConfigFile.new()
var quality_option: OptionButton
var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var shake_toggle: CheckButton

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
	panel.custom_minimum_size = Vector2(520, 500)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -250)
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

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("ff9a1a"))
	box.add_child(title)

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
	shake_toggle.button_pressed = true
	box.add_child(shake_toggle)
	shake_toggle.toggled.connect(func(_value): _apply_settings())

	var back = Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_size_override("font_size", 20)
	box.add_child(back)
	back.pressed.connect(_close)

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
	config.save("user://settings.cfg")
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.set_sfx_volume((master_slider.value / 100.0) * (sfx_slider.value / 100.0))
		audio.set_music_volume((master_slider.value / 100.0) * (music_slider.value / 100.0))

func _apply_graphics_quality(quality: int) -> void:
	var root = get_tree().current_scene
	if not root:
		return
	var environment = root.get_node_or_null("WorldEnvironment")
	if environment and environment.environment:
		var env = environment.environment
		env.fog_enabled = quality > 0
		env.glow_enabled = quality > 0
	var lights = root.find_children("*", "OmniLight3D", true, false)
	for light in lights:
		light.shadow_enabled = quality >= 2

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
