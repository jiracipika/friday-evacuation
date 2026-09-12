extends Button

const UI_THEME = preload("res://scripts/UITheme.gd")

var mode_title := "MODE"
var mode_subtitle := ""
var mode_status := "PROTOTYPE"
var accent := Color("ff9a1a")

# D2: hero flag — Evacuation card gets 84px height, 20px title, ORANGE pill.
var _hero := false
var _selected := false
var _bar_w := 4.0

func configure(title: String, subtitle: String, status: String, color: Color, hero: bool = false) -> void:
	mode_title = title
	mode_subtitle = subtitle
	mode_status = status
	accent = color
	_hero = hero
	UI_THEME.apply_mode_card(self, accent)
	# D2: hero cards get 20px title font; others 18px.
	add_theme_font_size_override("font_size", 20 if _hero else 18)
	queue_redraw()

func set_selected(selected: bool) -> void:
	_selected = selected
	UI_THEME.apply_mode_card(self, accent, selected)
	queue_redraw()

func _process(delta: float) -> void:
	# Smooth grow of the accent bar on selection.
	var target := 6.0 if _selected else 4.0
	_bar_w = lerpf(_bar_w, target, 1.0 - exp(-14.0 * delta))
	queue_redraw()

func _draw() -> void:
	var sz := size
	if sz.x < 8.0 or sz.y < 8.0:
		return
	# Left accent bar: color identity strip, vertically centered.
	var bar_h := minf(sz.y - 6.0, 72.0 if _hero else 42.0)
	draw_rect(Rect2(Vector2(3, sz.y * 0.5 - bar_h * 0.5), Vector2(_bar_w, bar_h)),
		accent.lightened(0.25) if _selected else accent, true)
	# Status pill: top-right chip. Text width via a cached font.
	var font := get_theme_default_font()
	var fs := 9
	if font:
		# D2: hero pill shows subtitle ("PRIMARY MODE") with ORANGE fill + dark text.
		# Others show status with muted styling.
		var pill_text := mode_subtitle if _hero else mode_status
		var text_w := font.get_string_size(pill_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pad := 7.0
		var pill_w := text_w + pad * 2.0
		var pill_h := 15.0
		var pill_pos := Vector2(sz.x - pill_w - 8.0, 6.0)
		if _hero:
			# PRIMARY MODE pill: ORANGE fill, dark text.
			var pill_bg := accent
			draw_rect_rect_style(pill_pos, Vector2(pill_w, pill_h), pill_bg, pill_bg)
			var txt_col := Color(0.04, 0.04, 0.06)
			draw_string(font, pill_pos + Vector2(pad, pill_h - 4.0), pill_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt_col)
		else:
			var playable := not "PROTOTYPE" in mode_status
			var pill_bg := Color(0.055, 0.055, 0.09, 0.95)
			draw_rect_rect_style(pill_pos, Vector2(pill_w, pill_h), pill_bg,
				Color(accent.r, accent.g, accent.b, 0.65 if playable else 0.35))
			var txt_col := Color(0.55, 1.0, 0.65) if playable else Color(0.95, 0.75, 0.35)
			draw_string(font, pill_pos + Vector2(pad, pill_h - 4.0), pill_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt_col)

## Rounded-rect pill via 4 quads + 4 corner circles (StyleBox drawing on a
## Button subclass isn't available; plain rects keep it crisp and opaque).
func draw_rect_rect_style(pos: Vector2, sz: Vector2, bg: Color, border: Color) -> void:
	var r := 6.0
	draw_rect(Rect2(pos + Vector2(r, 0), Vector2(sz.x - r * 2.0, sz.y)), bg, true)
	draw_rect(Rect2(pos + Vector2(0, r), Vector2(sz.x, sz.y - r * 2.0)), bg, true)
	draw_circle(pos + Vector2(r, r), r, bg, true)
	draw_circle(pos + Vector2(sz.x - r, r), r, bg, true)
	draw_circle(pos + Vector2(r, sz.y - r), r, bg, true)
	draw_circle(pos + Vector2(sz.x - r, sz.y - r), r, bg, true)
	draw_rect(Rect2(pos + Vector2(r, 0), Vector2(sz.x - r * 2.0, 1.0)), border, true)
	draw_rect(Rect2(pos + Vector2(r, sz.y - 1.0), Vector2(sz.x - r * 2.0, 1.0)), border, true)
	draw_rect(Rect2(pos + Vector2(0, r), Vector2(1.0, sz.y - r * 2.0)), border, true)
	draw_rect(Rect2(pos + Vector2(sz.x - 1.0, r), Vector2(1.0, sz.y - r * 2.0)), border, true)
