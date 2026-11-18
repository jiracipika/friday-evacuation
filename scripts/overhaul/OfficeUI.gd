extends RefCounted
## Shared palette and typography for the active office game.
const INK := Color("202c2b")
const PAPER := Color("f3eddf")
const ORANGE := Color("ed632b")
const MUTED := Color("59645e")
const LINE := Color("cdc6b4")
const TEAL := Color("356e64")
const BODY = preload("res://assets/fonts/Body.ttf")
const DISPLAY = preload("res://assets/fonts/Display.ttf")

static func style(color: Color, radius := 3, padding := 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box

static func outlined(color: Color, border := LINE, padding := 10) -> StyleBoxFlat:
	var box := style(color, 3, padding)
	box.border_color = border
	box.set_border_width_all(1)
	return box

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = BODY
	t.default_font_size = 16
	t.set_color("font_color", "Label", INK)
	for type in ["Button", "OptionButton", "CheckButton"]:
		t.set_color("font_color", type, INK)
		t.set_color("font_hover_color", type, INK)
		t.set_color("font_focus_color", type, INK)
		t.set_color("font_pressed_color", type, PAPER)
		t.set_color("font_hover_pressed_color", type, PAPER)
		t.set_stylebox("normal", type, outlined(PAPER))
		t.set_stylebox("hover", type, outlined(Color("e7dfcd"), INK))
		t.set_stylebox("pressed", type, outlined(INK, INK))
		t.set_stylebox("hover_pressed", type, outlined(INK.lightened(0.12), INK))
		var focus := outlined(Color.TRANSPARENT, ORANGE)
		focus.draw_center = false
		focus.set_border_width_all(3)
		focus.set_expand_margin_all(2)
		t.set_stylebox("focus", type, focus)
	t.set_stylebox("panel", "PanelContainer", style(PAPER, 3, 20))
	t.set_stylebox("normal", "LineEdit", outlined(Color("fffaf0")))
	t.set_stylebox("focus", "LineEdit", outlined(Color("fffaf0"), ORANGE))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_stylebox("panel", "PopupMenu", outlined(PAPER, INK))
	t.set_stylebox("hover", "PopupMenu", style(INK, 0, 8))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", PAPER)
	t.set_constant("v_separation", "PopupMenu", 12)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_stylebox("scroll", "VScrollBar", style(Color("dfd8c9"), 2, 2))
	t.set_stylebox("grabber", "VScrollBar", style(MUTED, 2, 3))
	return t

static func label(parent: Node, words: String, size := 16, color := INK) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

static func heading(parent: Node, words: String, size := 42, color := INK) -> Label:
	var l := label(parent, words, size, color)
	l.add_theme_font_override("font", DISPLAY)
	return l

static func rule(parent: Node) -> void:
	var line := HSeparator.new()
	var divider := StyleBoxLine.new()
	divider.color = LINE
	divider.thickness = 1
	line.add_theme_stylebox_override("separator", divider)
	parent.add_child(line)

static func button(parent: Node, words: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size.y = 44
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	parent.add_child(b)
	return b

static func primary(parent: Node, words: String, action: Callable) -> Button:
	var b := button(parent, words, action)
	b.custom_minimum_size.y = 54
	b.add_theme_font_override("font", DISPLAY)
	b.add_theme_font_size_override("font_size", 27)
	b.add_theme_stylebox_override("normal", style(ORANGE, 3, 9))
	b.add_theme_stylebox_override("hover", style(Color("fa7940"), 3, 9))
	b.add_theme_stylebox_override("pressed", style(Color("db541e"), 3, 9))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK)
	return b

static func option(parent: Node, words: Array, selected: int, action: Callable) -> OptionButton:
	var option_button := OptionButton.new()
	for word in words:
		option_button.add_item(str(word))
	option_button.selected = selected
	option_button.item_selected.connect(action)
	option_button.custom_minimum_size.y = 44
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(option_button)
	return option_button

static func fit_window(window: Window) -> void:
	var portrait := window.size.x < window.size.y
	window.content_scale_size = Vector2i(480, 850) if portrait else Vector2i(1280, 720)
