extends Button

# S-C / FINAL-SPEC section 4 (F2) "PICK YOUR EXIT" mode card.
# Grid: [icon 40px][title 18px + desc 12px][meta 2 lines right-aligned].
# Selection is a HARD state (R9): ORANGE 2px border + ORANGE icon ring +
# "SELECTED" mini-pill pinned top-right overlapping -8px. The 4px left rail
# is the category color ALWAYS (orange/coral/lime/violet), selected or not.

const UI_THEME = preload("res://scripts/UITheme.gd")

const MUTED_STROKE := Color("c4c4d2")
const ORANGE := Color("ff9a1a")
const INK_TEXT := Color(0.04, 0.04, 0.06)

var mode_title := "MODE"
var mode_subtitle := ""
var mode_status := "PROTOTYPE"
var accent := Color("ff9a1a")  # category color: rail + icon fill + meta line1
var category := ""
var crew := ""
var icon_kind := "flag"  # flag | flag_mirrored | eye | pizza
var two_line_meta := true

var _selected := false
var _glyph: Control
var _meta_cat: Label
var _meta_crew: Label
var _pill: Control


func configure(title: String, subtitle: String, status: String, color: Color,
		hero: bool = false, category_ := "", crew_ := "", icon_kind_ := "flag",
		two_line_meta_ := true) -> void:
	mode_title = title
	mode_subtitle = subtitle
	mode_status = status
	accent = color
	category = category_
	crew = crew_
	icon_kind = icon_kind_
	two_line_meta = two_line_meta_
	_apply_style()
	queue_redraw()


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_style()
	if _pill != null:
		_pill.visible = selected
	queue_redraw()
	if _glyph != null:
		_glyph.queue_redraw()


func _ready() -> void:
	if _glyph != null:
		return
	_build_content()
	_apply_style()
	if _pill != null:
		_pill.visible = _selected


func _build_content() -> void:
	var row := HBoxContainer.new()
	row.name = "CardRow"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14.0
	row.offset_right = -12.0
	row.offset_top = 6.0
	row.offset_bottom = -6.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_glyph = Control.new()
	_glyph.name = "IconGlyph"
	_glyph.custom_minimum_size = Vector2(40, 40)
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.draw.connect(_draw_icon)
	row.add_child(_glyph)

	var col := VBoxContainer.new()
	col.name = "TextCol"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = mode_title
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)

	var desc := Label.new()
	desc.name = "DescLabel"
	desc.text = mode_subtitle
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_FAIR))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(desc)

	var meta := VBoxContainer.new()
	meta.name = "MetaBox"
	meta.size_flags_horizontal = Control.SIZE_SHRINK_END
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.alignment = BoxContainer.ALIGNMENT_CENTER
	meta.add_theme_constant_override("separation", 1)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(meta)

	_meta_cat = _make_meta_label(category, accent)
	meta.add_child(_meta_cat)
	_meta_crew = _make_meta_label(crew, UI_THEME.color(UI_THEME.TEXT_FAIR))
	meta.add_child(_meta_crew)
	_meta_cat.visible = two_line_meta and not category.is_empty()
	_meta_crew.visible = not crew.is_empty()

	# SELECTED mini-pill: radius 999, ORANGE bg, INK text, pinned top-right
	# overlapping the card edge by 8px.
	_pill = Control.new()
	_pill.name = "SelectedPillAnchor"
	_pill.anchor_left = 1.0
	_pill.anchor_right = 1.0
	_pill.offset_left = -92.0
	_pill.offset_right = -10.0
	_pill.offset_top = -8.0
	_pill.offset_bottom = 8.0
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pill)

	var pill_panel := PanelContainer.new()
	pill_panel.name = "SelectedPill"
	var psb := StyleBoxFlat.new()
	psb.bg_color = ORANGE
	psb.set_corner_radius_all(999)
	psb.content_margin_left = 8.0
	psb.content_margin_right = 8.0
	psb.content_margin_top = 2.0
	psb.content_margin_bottom = 2.0
	pill_panel.add_theme_stylebox_override("panel", psb)
	pill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_label := Label.new()
	pill_label.text = "SELECTED"
	pill_label.add_theme_font_size_override("font_size", 9)
	pill_label.add_theme_color_override("font_color", INK_TEXT)
	pill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_panel.add_child(pill_label)
	_pill.add_child(pill_panel)


func _make_meta_label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", col)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _apply_style() -> void:
	var border := Color(accent.r, accent.g, accent.b, 0.22)
	var width := 1
	if _selected:
		border = ORANGE
		width = 2
	add_theme_stylebox_override("normal",
		UI_THEME.button_style(UI_THEME.color(UI_THEME.SURFACE), border, width, 12))
	add_theme_stylebox_override("hover",
		UI_THEME.button_style(UI_THEME.color(UI_THEME.SURFACE_HOVER), border, width, 12))
	add_theme_stylebox_override("pressed",
		UI_THEME.button_style(UI_THEME.color(UI_THEME.SURFACE_HOVER), border, width, 12))
	add_theme_stylebox_override("disabled",
		UI_THEME.button_style(UI_THEME.color(UI_THEME.SURFACE), border, width, 12))
	UI_THEME.apply_focus(self)


func _draw() -> void:
	var sz := size
	if sz.x < 8.0 or sz.y < 8.0:
		return
	# 4px left rail — category color, always visible.
	draw_rect(Rect2(Vector2(0, 2), Vector2(4.0, sz.y - 4.0)), accent, true)


## Pictogram drawn inside the nested IconGlyph control (no emoji):
## pennant flag / mirrored flag / eye outline + pupil / dashed pizza circle.
## Strokes are muted unselected; a full ORANGE ring appears when selected.
func _draw_icon() -> void:
	if _glyph == null:
		return
	var c := _glyph.size * 0.5
	var stroke := ORANGE if _selected else MUTED_STROKE
	match icon_kind:
		"flag":
			draw_rect(Rect2(c + Vector2(-9.0, -13.0), Vector2(2.5, 26.0)), stroke, true)
			var pts := PackedVector2Array([
				c + Vector2(-6.5, -13.0), c + Vector2(11.0, -8.0), c + Vector2(-6.5, -3.0)])
			draw_colored_polygon(pts, accent)
		"flag_mirrored":
			draw_rect(Rect2(c + Vector2(6.5, -13.0), Vector2(2.5, 26.0)), stroke, true)
			var pts := PackedVector2Array([
				c + Vector2(6.5, -13.0), c + Vector2(-11.0, -8.0), c + Vector2(6.5, -3.0)])
			draw_colored_polygon(pts, accent)
		"eye":
			draw_arc(c + Vector2(0, 2.0), 11.0, PI, TAU, 20, stroke, 2.0, true)
			draw_arc(c + Vector2(0, -2.0), 11.0, 0.0, PI, 20, stroke, 2.0, true)
			draw_circle(c, 3.5, stroke)
		"pizza":
			for i in range(8):
				var a0 := TAU * float(i) / 8.0
				draw_arc(c, 12.0, a0, a0 + TAU / 12.0, 6, accent, 2.0, true)
			draw_circle(c, 2.5, accent)
	if _selected:
		draw_arc(c, 19.0, 0.0, TAU, 40, ORANGE, 2.0, true)
