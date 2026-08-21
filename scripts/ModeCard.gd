extends Button

const UI_THEME = preload("res://scripts/UITheme.gd")

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
	UI_THEME.apply_mode_card(self, accent)

func set_selected(selected: bool) -> void:
	disabled = selected
	UI_THEME.apply_mode_card(self, accent, selected)
