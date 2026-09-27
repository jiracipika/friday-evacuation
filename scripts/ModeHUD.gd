extends CanvasLayer

# Shared HUD for secondary modes. Keep its layout bounded by the viewport so
# objective text and the timer remain visible on phones and small windows.
const UI_THEME = preload("res://scripts/UITheme.gd")
const HUD_MAX_WIDTH := 420.0
const HUD_SIDE_MARGIN := 12.0
const HUD_TOP_MARGIN := 12.0
const HUD_NORMAL_HEIGHT := 142.0
const HUD_COMPACT_HEIGHT := 154.0

var title_label: Label
var objective_label: Label
var timer_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var status_label: Label
var panel: PanelContainer
var _progress_fill: StyleBoxFlat
var _time_limit := 1.0

func _ready() -> void:
	var root := Control.new()
	root.name = "ModeHUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.name = "ModePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = UI_THEME.panel_style(UI_THEME.color(UI_THEME.ORANGE), true)
	style.set_content_margin_all(0.0)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	title_label = _label("MODE", 24, UI_THEME.color(UI_THEME.ORANGE))
	objective_label = _label("OBJECTIVE", 14, UI_THEME.color(UI_THEME.TEXT, 0.85))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timer_label = _label("TIME  --", 16, UI_THEME.color(UI_THEME.PAPER))
	progress_label = _label("PROGRESS  0%", 14, UI_THEME.color(UI_THEME.LIME))
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 12)
	progress_bar.show_percentage = false
	_progress_fill = StyleBoxFlat.new()
	_progress_fill.bg_color = UI_THEME.color(UI_THEME.ORANGE)
	_progress_fill.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("fill", _progress_fill)
	status_label = _label("READY", 14, UI_THEME.color(UI_THEME.LIME))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for item in [title_label, objective_label, timer_label, progress_label, progress_bar, status_label]:
		box.add_child(item)

	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()

func _layout_hud() -> void:
	if not is_instance_valid(panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 520.0
	var available_width := maxf(0.0, viewport_size.x - HUD_SIDE_MARGIN * 2.0)
	panel.position = Vector2(HUD_SIDE_MARGIN, HUD_TOP_MARGIN)
	panel.size = Vector2(minf(HUD_MAX_WIDTH, available_width), HUD_COMPACT_HEIGHT if compact else HUD_NORMAL_HEIGHT)
	title_label.add_theme_font_size_override("font_size", 20 if compact else 24)
	objective_label.add_theme_font_size_override("font_size", 12 if compact else 14)
	timer_label.add_theme_font_size_override("font_size", 15 if compact else 16)
	progress_label.add_theme_font_size_override("font_size", 12 if compact else 14)
	status_label.add_theme_font_size_override("font_size", 12 if compact else 14)

func configure(title: String, objective: String, time_limit: float) -> void:
	if not is_instance_valid(title_label):
		await ready
	_time_limit = maxf(time_limit, 1.0)
	title_label.text = title
	objective_label.text = objective
	timer_label.text = "TIME  %s" % _format_time(time_limit)
	_layout_hud()

func update_state(remaining: float, progress: float, status: String, status_color := Color(0, 0, 0, 0)) -> void:
	if status_color.a <= 0.0:
		status_color = UI_THEME.color(UI_THEME.LIME)
	if not is_instance_valid(timer_label):
		return
	var safe_remaining := maxf(remaining, 0.0)
	var urgent := safe_remaining > 0.0 and safe_remaining / _time_limit <= 0.2
	timer_label.text = "TIME  %s" % _format_time(safe_remaining)
	timer_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.CORAL) if urgent else UI_THEME.color(UI_THEME.PAPER))
	progress_bar.value = clampf(progress * 100.0, 0.0, 100.0)
	_progress_fill.bg_color = UI_THEME.color(UI_THEME.CORAL) if urgent else UI_THEME.color(UI_THEME.ORANGE)
	progress_label.text = "PROGRESS  %d%%" % roundi(progress * 100.0)
	status_label.text = status
	status_label.add_theme_color_override("font_color", status_color)

func _format_time(seconds: float) -> String:
	var safe := maxi(0, ceili(seconds))
	return "%d:%02d" % [safe / 60, safe % 60]

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
