extends RefCounted
const INK := Color("18343d")
const PAPER := Color("f0eee4")
const ORANGE := Color("e88c45")

static func style(color: Color, radius := 12, padding := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 19
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", PAPER)
	t.set_color("font_focus_color", "Button", PAPER)
	t.set_stylebox("normal", "Button", style(INK, 8, 13))
	t.set_stylebox("hover", "Button", style(Color("367c7d"), 8, 13))
	t.set_stylebox("pressed", "Button", style(Color("a75e31"), 8, 13))
	var focus := style(Color.TRANSPARENT, 8, 13)
	focus.border_color = ORANGE
	focus.set_border_width_all(3)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("panel", "PanelContainer", style(PAPER))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 12)
	return t

static func label(parent: Node, words: String, size := 19, color := INK) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

static func button(parent: Node, words: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size.y = 44
	b.pressed.connect(action)
	parent.add_child(b)
	return b

static func option(parent: Node, words: Array, selected: int, action: Callable) -> OptionButton:
	var o := OptionButton.new()
	for word in words:
		o.add_item(str(word))
	o.selected = selected
	o.item_selected.connect(action)
	o.custom_minimum_size.y = 38
	parent.add_child(o)
	return o
