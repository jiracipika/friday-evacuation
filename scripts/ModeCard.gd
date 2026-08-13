extends Button

var mode_title := "MODE"
var mode_subtitle := ""
var mode_status := "PROTOTYPE"
var accent := Color("ff9a1a")

func configure(title: String, subtitle: String, status: String, color: Color) -> void:
	mode_title = title
	mode_subtitle = subtitle
	mode_status = status
	accent = color
	text = "%s\n%s  •  %s" % [mode_title, mode_subtitle, mode_status]
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", accent)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("1c1c2e")
	normal.border_color = Color(1, 1, 1, 0.12)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 16.0
	normal.content_margin_right = 16.0
	add_theme_stylebox_override("normal", normal)
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.15, 0.15, 0.25)
	hover.border_color = accent
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(10)
	hover.content_margin_left = 16.0
	hover.content_margin_right = 16.0
	add_theme_stylebox_override("hover", hover)
	var disabled = StyleBoxFlat.new()
	disabled.bg_color = Color(0.22, 0.18, 0.12)
	disabled.border_color = accent
	disabled.set_border_width_all(3)
	disabled.set_corner_radius_all(10)
	disabled.content_margin_left = 16.0
	disabled.content_margin_right = 16.0
	add_theme_stylebox_override("disabled", disabled)
