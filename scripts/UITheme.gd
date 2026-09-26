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

# S-A tokens (FINAL-SPEC.md section 2 — locked "After Hours" palette).
const TEXT_FAIR := "9a9aae"
const PAPER := "f2ecdc"
const GREEN := "2fa05a"
const YELLOW := "f2c230"
const RED := "e04a3a"
const INK := "231303"
const TICKER_BG := Color(0, 0, 0, 0.35)
const DIM := Color(0.02, 0.02, 0.04, 0.72)

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

## S-PAD: shared focus ring — StyleBoxFlat outline, ORANGE border 2,
## draw_center false, radius 12, expand_margin 2 (visible pad/kb affordance).
static func apply_focus(button: Button) -> void:
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = color(ORANGE)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(12)
	focus.set_expand_margin_all(2.0)
	button.add_theme_stylebox_override("focus", focus)

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
	apply_focus(button)
	button.modulate = Color.WHITE if selected else Color(1, 1, 1, 0.94)

static func apply_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(color(ORANGE), color(ORANGE_BRIGHT), 2, 14))
	button.add_theme_stylebox_override("hover", button_style(color(ORANGE_BRIGHT), Color.WHITE, 2, 14))
	button.add_theme_stylebox_override("pressed", button_style(color(ORANGE).darkened(0.18), color(ORANGE_BRIGHT), 2, 14))
	apply_focus(button)
	button.add_theme_color_override("font_color", color(BG))
	button.add_theme_color_override("font_hover_color", color(BG))
	button.add_theme_font_size_override("font_size", 24)

static func apply_secondary(button: Button, accent: Color = color(CYAN)) -> void:
	button.add_theme_stylebox_override("normal", button_style(color(SURFACE), Color(accent.r, accent.g, accent.b, 0.28), 1))
	button.add_theme_stylebox_override("hover", button_style(color(SURFACE_HOVER), accent, 2))
	apply_focus(button)
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
	# S-PAD: real focus outline (was StyleBoxEmpty). Kept non-invasive for the
	# popup: only the closed-button "focus" stylebox changes.
	apply_focus(ob)
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
	apply_focus(button)
	button.add_theme_color_override("font_color", color(TEXT, 0.82))
	button.add_theme_color_override("font_hover_color", color(TEXT))

## S-E/S-F hazard-tape band: yellow 45deg stripes on near-black, drawn
## (spec R2: vector, no bitmaps/emoji). One use per screen max (R7).
class TapeStrip extends Control:
	const YELLOW := Color("f2c230")
	const GROUND := Color("191411")
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), GROUND)
		var slope := size.y * 1.4
		var period := slope * 2.0
		var x := 0.0
		while x < size.x + period:
			var poly := PackedVector2Array([
				Vector2(x - slope, size.y), Vector2(x, 0.0),
				Vector2(x + slope * 0.7, 0.0), Vector2(x + slope * 0.7 - slope, size.y),
			])
			draw_polygon(poly, [YELLOW])
			x += period

## S-F honest meter (spec R5): track + fill + baseline tick. Fill width is
## value/max clamped; the tick marks a reference (e.g. previous best) at
## tick/max. Debuff styling is the caller's job (dashed coral not drawn here).
class MeterBar extends Control:
	# Inner classes cannot reach outer-class statics/constants, and a
	# class_name self-reference breaks raw SceneTree compiles — literals
	# duplicated here on purpose (keep in sync with SURFACE_HOVER/ORANGE/
	# TEXT). Track is SURFACE_HOVER: the panel bg is SURFACE_RAISED, and
	# the original SURFACE track rendered invisible against it.
	const TRACK := Color("25253a")
	const FILL := Color("ff9a1a")
	const TICK := Color("f7f6f2")
	var value := 0.0: set = _set_value
	var maximum := 1.0
	var tick := -1.0  # <0 hides the reference tick
	func _set_value(v: float) -> void:
		value = v
		queue_redraw()
	func _draw() -> void:
		var track := Rect2(Vector2.ZERO, size)
		draw_rect(track, TRACK)
		var frac := 0.0
		if maximum > 0.0:
			frac = clampf(value / maximum, 0.0, 1.0)
		if frac > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), FILL)
		if tick >= 0.0 and maximum > 0.0:
			var tx := size.x * clampf(tick / maximum, 0.0, 1.0)
			draw_rect(Rect2(Vector2(tx - 1.0, 0.0), Vector2(2.0, size.y)), TICK)
