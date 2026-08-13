extends CanvasLayer

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
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.055, 0.09, 0.94)
	style.border_color = Color(1.0, 0.6, 0.12, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	title_label = _label("MODE", 24, Color("ffb52e"))
	objective_label = _label("OBJECTIVE", 14, Color("d0d0df"))
	timer_label = _label("TIME  --", 16, Color("ffffff"))
	progress_label = _label("PROGRESS  0%", 14, Color("a8ffbd"))
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 14)
	progress_bar.show_percentage = false
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color("ff9a1a")
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
