# CreditsScreen.gd — Overlay credits screen (Phase 8C)
# Opened from the main menu. Esc/back returns to the menu.
extends CanvasLayer

signal closed

const ACCENT := Color("ff9a1a")

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

	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.position = Vector2(-260, -260)
	box.custom_minimum_size = Vector2(520, 520)
	root.add_child(box)

	var title = Label.new()
	title.text = "CREDITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)

	for entry in CREDITS:
		var label = Label.new()
		label.text = entry[0] if entry[1] == "" else "%s\n%s" % [entry[0], entry[1]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(520, 0)
		label.add_theme_font_size_override("font_size", 18 if entry[1] == "" else 16)
		if entry[1] == "":
			label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9 if entry[0].begins_with("FRIDAY") else 0.7))
		else:
			label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		box.add_child(label)

	var back = Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_close)
	box.add_child(back)

func _close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()
