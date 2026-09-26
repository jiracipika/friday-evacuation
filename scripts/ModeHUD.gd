extends CanvasLayer

# UI SLICE: shared After-Hours token system (MenuBackdrop/Settings preload
# pattern — a class_name self-reference breaks standalone SceneTree compiles).
const UI_THEME = preload("res://scripts/UITheme.gd")

var title_label: Label
var objective_label: Label
var timer_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var status_label: Label
var panel: PanelContainer

func _ready() -> void:
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.size = Vector2(420, 142)
	var style: StyleBoxFlat = UI_THEME.panel_style(UI_THEME.color(UI_THEME.ORANGE), true)
	# Keep the old ad-hoc box's compact footprint: panel_style's content
	# margins would grow the PanelContainer minimum size, so zero them (the
	# VBox separation already spaces the rows). Shadow draws outside the
	# rect and does not affect layout budgets.
	style.set_content_margin_all(0.0)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	title_label = _label("MODE", 24, UI_THEME.color(UI_THEME.ORANGE))
	objective_label = _label("OBJECTIVE", 14, UI_THEME.color(UI_THEME.TEXT, 0.85))
	timer_label = _label("TIME  --", 16, UI_THEME.color(UI_THEME.PAPER))
	progress_label = _label("PROGRESS  0%", 14, UI_THEME.color(UI_THEME.LIME))
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 14)
	progress_bar.show_percentage = false
	var fill = StyleBoxFlat.new()
	fill.bg_color = UI_THEME.color(UI_THEME.ORANGE)
	fill.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(title_label)
	box.add_child(objective_label)
	box.add_child(timer_label)
	box.add_child(progress_label)
	box.add_child(progress_bar)
	status_label = _label("READY", 14, Color("a8ffbd"))
	box.add_child(status_label)

func configure(title: String, objective: String, time_limit: float) -> void:
	if not is_instance_valid(title_label):
		await ready
	title_label.text = title
	objective_label.text = objective
	timer_label.text = "TIME  %s" % _format_time(time_limit)

func update_state(remaining: float, progress: float, status: String, status_color := Color("a8ffbd")) -> void:
	if not is_instance_valid(timer_label):
		return
	timer_label.text = "TIME  %s" % _format_time(remaining)
	progress_bar.value = clampf(progress * 100.0, 0.0, 100.0)
	progress_label.text = "PROGRESS  %d%%" % roundi(progress * 100.0)
	status_label.text = status
	status_label.modulate = status_color

func _format_time(seconds: float) -> String:
	var safe = maxi(0, ceili(seconds))
	return "%d:%02d" % [safe / 60, safe % 60]

func _label(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
