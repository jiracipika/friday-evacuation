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
