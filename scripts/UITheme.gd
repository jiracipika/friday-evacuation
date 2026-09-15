class_name FridayUITheme
extends RefCounted

const BG := "0a0a0f"
const SURFACE := "15151f"
const SURFACE_RAISED := "1c1c2e"
const SURFACE_HOVER := "25253a"
const TEXT := "f7f6f2"
const TEXT_MUTED := "9b9baa"
const ORANGE := "ff9a1a"
const ORANGE_BRIGHT := "ffbd4a"
const CYAN := "57d7ff"
const LIME := "b9f34a"
const CORAL := "ff6f61"
const VIOLET := "9b82ff"

static func color(hex: String, alpha: float = 1.0) -> Color:
	var value := Color(hex)
	value.a = alpha
	return value

static func panel_style(accent: Color = color(ORANGE), strong: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color(SURFACE_RAISED if strong else SURFACE, 0.96)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.5 if strong else 0.2)
	style.set_border_width_all(1 if not strong else 2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 10 if strong else 6
	style.shadow_offset = Vector2(0, 5)
	return style

static func button_style(bg: Color, border: Color, width: int = 1, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 4)
	return style

static func apply_mode_card(button: Button, accent: Color, selected: bool = false) -> void:
	button.add_theme_font_size_override("font_size", 18)
	# UI SLICE: two-line card labels must wrap instead of forcing a 455px
	# minimum button width (the mode list was the menu column's width floor
	# in portrait; wrapping lets cards reflow at any window size).
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = false
	button.add_theme_color_override("font_color", color(TEXT))
	button.add_theme_color_override("font_hover_color", color(TEXT))
	button.add_theme_color_override("font_disabled_color", accent.lightened(0.18))
	button.add_theme_stylebox_override("normal", panel_style(accent, false))
	button.add_theme_stylebox_override("hover", button_style(color(SURFACE_HOVER), accent, 2))
	button.add_theme_stylebox_override("pressed", button_style(accent.darkened(0.68), accent.lightened(0.18), 2))
	button.add_theme_stylebox_override("disabled", panel_style(accent, true))
	button.modulate = Color.WHITE if selected else Color(1, 1, 1, 0.94)

static func apply_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(color(ORANGE), color(ORANGE_BRIGHT), 2, 14))
	button.add_theme_stylebox_override("hover", button_style(color(ORANGE_BRIGHT), Color.WHITE, 2, 14))
	button.add_theme_stylebox_override("pressed", button_style(color(ORANGE).darkened(0.18), color(ORANGE_BRIGHT), 2, 14))
	button.add_theme_color_override("font_color", color(BG))
	button.add_theme_color_override("font_hover_color", color(BG))
	button.add_theme_font_size_override("font_size", 24)

static func apply_secondary(button: Button, accent: Color = color(CYAN)) -> void:
	button.add_theme_stylebox_override("normal", button_style(color(SURFACE), Color(accent.r, accent.g, accent.b, 0.28), 1))
	button.add_theme_stylebox_override("hover", button_style(color(SURFACE_HOVER), accent, 2))
	button.add_theme_color_override("font_color", color(TEXT, 0.86))
	button.add_theme_color_override("font_hover_color", color(TEXT))

## D6: styled slider — 8px ORANGE grabber, 4px SURFACE_HOVER groove, radius 2
static func styled_slider(slider: HSlider) -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = color(ORANGE)
	grabber.set_corner_radius_all(4)
	grabber.content_margin_left = 3.0
	grabber.content_margin_right = 3.0
	grabber.content_margin_top = 3.0
	grabber.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("grabber_area", grabber)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber)
	var groove := StyleBoxFlat.new()
	groove.bg_color = color(SURFACE_HOVER)
	groove.set_corner_radius_all(2)
	slider.add_theme_stylebox_override("slider", groove)

## D6: CheckButton — 14px text, matches panel identity
static func styled_checkbutton(cb: CheckButton) -> void:
	cb.add_theme_font_size_override("font_size", 14)

## D6: section header — 13px ORANGE, returns a Label with +10px top margin
## Modern dark OptionButton: styled closed button + themed popup list.
## Without this the dropdowns render Godot-default grey — the single most
## dated-looking control on the menu.
static func style_option_button(ob: OptionButton) -> void:
	var sb := button_style(color(SURFACE), Color(color(CYAN).r, color(CYAN).g, color(CYAN).b, 0.28), 1, 10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	ob.add_theme_stylebox_override("normal", sb)
	var sbh := button_style(color(SURFACE_HOVER), color(CYAN), 1, 10)
	sbh.content_margin_left = 14.0
	sbh.content_margin_right = 14.0
	ob.add_theme_stylebox_override("hover", sbh)
	ob.add_theme_stylebox_override("pressed", sbh)
	ob.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	ob.add_theme_color_override("font_color", color(TEXT, 0.92))
	ob.add_theme_color_override("font_hover_color", color(TEXT))
	ob.add_theme_color_override("font_pressed_color", color(TEXT))
	ob.add_theme_icon_override("arrow", _arrow_icon())
	# Popup list (the menu that drops down).
	var pop := ob.get_popup()
	if pop != null:
		var psb := panel_style(color(CYAN), false)
		psb.content_margin_left = 4.0
		psb.content_margin_right = 4.0
		psb.content_margin_top = 6.0
		psb.content_margin_bottom = 6.0
		pop.add_theme_stylebox_override("panel", psb)
		pop.add_theme_stylebox_override("hover", button_style(color(SURFACE_HOVER), color(CYAN), 1, 8))
		pop.add_theme_color_override("font_color", color(TEXT, 0.88))
		pop.add_theme_color_override("font_hover_color", color(TEXT))
		pop.add_theme_color_override("font_hover_pressed_color", color(TEXT))
		pop.add_theme_constant_override("v_separation", 6)

static func _arrow_icon() -> ImageTexture:
	# 12x12 chevron in muted text color (crisp at 1x; menus are 1x UI).
	var size := 12
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var col := color(TEXT_MUTED)
	for y in range(3, 9):
		var x := y - 2  # 1..7 downward slope
		img.set_pixel(x, y, col)
		img.set_pixel(size - 1 - x, y, col)
	return ImageTexture.create_from_image(img)


## D6: section header — 13px ORANGE, returns a Label with +10px top margin
static func make_section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color(ORANGE))
	# +10px top margin: the Label's own rect includes the gap so the
	# following row sits 10px below the header text.
	label.custom_minimum_size.y = 23
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label

## D2: utility button — 28px pill with hover brighten + ORANGE focus outline
static func apply_utility(button: Button, accent: Color = color(CYAN)) -> void:
	button.add_theme_stylebox_override("normal", button_style(color(SURFACE), Color(accent.r, accent.g, accent.b, 0.2), 1, 10))
	button.add_theme_stylebox_override("hover", button_style(color(SURFACE_HOVER), accent, 2, 10))
	button.add_theme_stylebox_override("focus", button_style(color(SURFACE), accent, 2, 10))
	button.add_theme_color_override("font_color", color(TEXT, 0.82))
	button.add_theme_color_override("font_hover_color", color(TEXT))
