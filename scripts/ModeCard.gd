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
	# Text is owned by Main._select_mode (it re-labels cards on every switch).
	UI_THEME.apply_mode_card(self, accent)

func set_selected(selected: bool) -> void:
	# Selected card keeps its strong style but stays hoverable/clickable
	# (re-clicking the active mode is harmless and keeps controls alive).
	UI_THEME.apply_mode_card(self, accent, selected)
