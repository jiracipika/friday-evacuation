# CreditsScreen.gd — Overlay credits screen (Phase 8C)
# Opened from the main menu. Esc/back returns to the menu.
extends CanvasLayer

signal closed

const UI_THEME = preload("res://scripts/UITheme.gd")

const CREDITS := [
	["FRIDAY 5PM: EVACUATION", ""],
	["", ""],
	["A co-op comedy game about escaping the office", ""],
	["before anyone else does.", ""],
	["", ""],
	["GAME DESIGN + CODE", "GPT-5.6 Luna (baseline) + GLM 5.3 (polish)"],
	["LEVEL + SYSTEMS", "Hermes Agent collaboration"],
	["ENGINE", "Godot 4.7"],
	["", ""],
	["SPECIAL THANKS", "The one who said let's get on the game"],
	["", ""],
	["MADE WITH", "Coffee. Obviously."],
]

func _ready() -> void:
	layer = 80
	_build_ui()

func _build_ui() -> void:
	var root = Control.new()
	root.name = "CreditsRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# S-H: panel + tape header on the ink field; role lines become orange
	# micro caps, names TEXT, per the After-Hours spec-sheet pattern.
	var panel = PanelContainer.new()
	panel.name = "CreditsPanel"
	var panel_style := UI_THEME.panel_style(UI_THEME.color(UI_THEME.ORANGE), true)
	panel_style.bg_color = UI_THEME.color(UI_THEME.SURFACE_RAISED, 0.98)
	panel_style.content_margin_top = 0.0
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	root.add_child(panel)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var tape: Control = UI_THEME.TapeStrip.new()
	tape.name = "TapeStrip"
	tape.custom_minimum_size = Vector2(0, 10)
	box.add_child(tape)

	var title = Label.new()
	title.text = "CREDITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT))
	box.add_child(title)

	for entry in CREDITS:
		var label = Label.new()
		label.text = entry[0] if entry[1] == "" else "%s\n%s" % [entry[0], entry[1]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(460, 0)
		label.add_theme_font_size_override("font_size", 18 if entry[1] == "" else 14)
		if entry[1] == "":
			var is_brand: bool = entry[0].begins_with("FRIDAY")
			label.add_theme_color_override("font_color",
				UI_THEME.color(UI_THEME.PAPER) if is_brand else UI_THEME.color(UI_THEME.TEXT_FAIR))
			if is_brand:
				label.add_theme_font_size_override("font_size", 22)
		else:
			# Role headers read as orange micro caps above the name.
			label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT))
		box.add_child(label)

	var back = Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_close)
	UI_THEME.apply_utility(back, UI_THEME.color(UI_THEME.VIOLET))
	box.add_child(back)

func _close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()
