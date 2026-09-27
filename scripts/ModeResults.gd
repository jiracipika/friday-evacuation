extends CanvasLayer

# Consistent, controller-friendly completion flow for the secondary modes.
const UI_THEME = preload("res://scripts/UITheme.gd")

var title_label: Label
var detail_label: Label
var rematch_button: Button
var menu_button: Button
var panel: PanelContainer

static func mount(parent: Node, headline: String, detail: String, won: bool) -> CanvasLayer:
	var overlay := CanvasLayer.new()
	overlay.name = "ModeResults"
	overlay.set_script(load("res://scripts/ModeResults.gd"))
	parent.add_child(overlay)
	overlay.call_deferred("configure", headline, detail, won)
	return overlay

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	layer = 20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.04, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	panel = PanelContainer.new()
	panel.name = "ResultsPanel"
	var panel_style: StyleBoxFlat = UI_THEME.panel_style(UI_THEME.color(UI_THEME.ORANGE), true)
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 28)
	box.add_child(title_label)

	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 16)
	detail_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT))
	box.add_child(detail_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)

	rematch_button = Button.new()
	rematch_button.text = "PLAY AGAIN"
	rematch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rematch_button.custom_minimum_size = Vector2(0, 48)
	rematch_button.pressed.connect(_rematch)
	UI_THEME.apply_primary(rematch_button)
	actions.add_child(rematch_button)

	menu_button = Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_button.custom_minimum_size = Vector2(0, 48)
	menu_button.pressed.connect(_return_to_menu)
	UI_THEME.apply_secondary(menu_button, UI_THEME.color(UI_THEME.CYAN))
	actions.add_child(menu_button)

	get_viewport().size_changed.connect(_layout_panel)
	_layout_panel()
	rematch_button.call_deferred("grab_focus")

func configure(headline: String, detail: String, won: bool) -> void:
	if not is_instance_valid(title_label):
		await ready
	title_label.text = headline
	title_label.add_theme_color_override("font_color", Color("a8ffbd") if won else Color("ff7070"))
	detail_label.text = detail

func _layout_panel() -> void:
	if not is_instance_valid(panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(480.0, maxf(0.0, viewport_size.x - 32.0))
	var height := minf(280.0, maxf(0.0, viewport_size.y - 32.0))
	panel.size = Vector2(width, height)
	panel.position = (viewport_size - panel.size) * 0.5

func _rematch() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
