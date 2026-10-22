extends VBoxContainer

const Design = preload("res://scripts/CharacterDesign.gd")
const Roster = preload("res://scripts/CharacterRoster.gd")
const Hero = preload("res://scripts/MenuHero.gd")
const UI = preload("res://scripts/UITheme.gd")
signal design_changed

var selectors: Dictionary = {}
var preview: SubViewportContainer
var identity_label: Label

func _ready() -> void:
	name = "CharacterDesigner"
	add_theme_constant_override("separation", 8)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182130")
	style.border_color = Color("415166")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	identity_label = Label.new()
	identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity_label.add_theme_font_size_override("font_size", 14)
	identity_label.add_theme_color_override("font_color", Color("ffd65c"))
	column.add_child(identity_label)
	preview = Hero.new()
	preview.name = "DesignerPreview"
	preview.custom_minimum_size = Vector2(0, 260)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(preview)
	var rotation_row := HBoxContainer.new()
	rotation_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(rotation_row)
	for direction in [-1, 1]:
		var button := Button.new()
		button.text = "TURN LEFT" if direction < 0 else "TURN RIGHT"
		button.custom_minimum_size = Vector2(0, 48)
		UI.apply_secondary(button)
		button.pressed.connect(func():
			if preview.turntable:
				preview.turntable.rotation.y += direction * PI / 4.0
			preview.spin = 0.0)
		rotation_row.add_child(button)
	var hint := Label.new()
	hint.text = "Make your own coworker. Changes save automatically."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("b8b5ae"))
	add_child(hint)
	for key in Design.OPTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var label := Label.new()
		label.text = Design.LABELS[key]
		label.custom_minimum_size.x = 106
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)
		var option := OptionButton.new()
		option.name = key.to_pascal_case()
		option.custom_minimum_size = Vector2(0, 48)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.fit_to_longest_item = false
		option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		UI.style_option_button(option)
		for value in Design.OPTIONS[key]:
			option.add_item(Design.display_name(value))
			option.set_item_metadata(option.item_count - 1, value)
			if key.ends_with("color") or key == "skin_tone":
				var swatch := Image.create(20, 20, false, Image.FORMAT_RGBA8)
				swatch.fill(Color(value))
				option.set_item_icon(option.item_count - 1, ImageTexture.create_from_image(swatch))
		option.item_selected.connect(func(index: int): _choose(key, str(option.get_item_metadata(index))))
		row.add_child(option)
		selectors[key] = option
	var actions := HBoxContainer.new()
	add_child(actions)
	for reset in [false, true]:
		var button := Button.new()
		button.name = "ResetDesign" if reset else "ShuffleDesign"
		button.text = "RESET PRESET" if reset else "SURPRISE ME"
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.apply_secondary(button)
		button.pressed.connect(func():
			var design := {}
			if not reset:
				for key in Design.OPTIONS:
					design[key] = Design.OPTIONS[key].pick_random()
			GameManager.set_character_design(design)
			sync_for_pick()
			design_changed.emit())
		actions.add_child(button)
	sync_for_pick()

func _choose(key: String, value: String) -> void:
	var design: Dictionary = GameManager.get_character_design()
	design[key] = value
	GameManager.set_character_design(design)
	preview.refresh_for_pick()
	design_changed.emit()

func sync_for_pick() -> void:
	if not is_instance_valid(preview):
		return
	var character := Roster.get_character(GameManager.selected_character_id)
	var design := Design.resolve(character, GameManager.get_character_design())
	identity_label.text = str(character.name) + " / " + str(character.role)
	identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for key in selectors:
		selectors[key].select(Design.OPTIONS[key].find(design[key]))
	preview.refresh_for_pick()
