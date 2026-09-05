extends CanvasLayer

var speed_label: Label
var floor_label: Label
var boost_label: Label
var sabotage_label: Label
var timer_label: Label
var status_label: Label
var speed_bar: ProgressBar
var boost_bar: ProgressBar
var minimap: Control
var item_label: Label

func _ready() -> void:
	_build_hud()

# MOBILE PASS: scale HUD chrome with viewport height so phones get readable
# text and desktop keeps the current sizes. 720p => 1.0; a 360px-tall
# landscape phone viewport => ~0.72; tall portrait windows => up to ~1.6.
func _ui_scale() -> float:
	var h := get_viewport().get_visible_rect().size.y
	return clampf(h / 720.0, 0.85, 1.6)

func _px(v: float) -> int:
	return int(round(v * _ui_scale()))

func _build_hud() -> void:
	var top = PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = _px(76)
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.03, 0.03, 0.06, 0.88)
	top_style.border_color = Color(1, 0.6, 0.1, 0.7)
	top_style.border_width_bottom = 2
	top.add_theme_stylebox_override("panel", top_style)
	add_child(top)
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", _px(26))
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(top_row)
	floor_label = _make_label("FLOOR 1", _px(18), Color(1, 1, 1, 0.75))
	top_row.add_child(floor_label)
	timer_label = _make_label("2:00", _px(34), Color("ffb52e"))
	top_row.add_child(timer_label)
	status_label = _make_label("RACE", _px(18), Color(0.4, 1, 0.65))
	top_row.add_child(status_label)
	var minimap_script = load("res://scripts/Minimap.gd")
	minimap = Control.new()
	minimap.set_script(minimap_script)
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var map_size := _px(150)
	minimap.position = Vector2(-map_size - _px(24), _px(92))
	minimap.size = Vector2(map_size, map_size)
	add_child(minimap)

	var bottom = MarginContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -_px(118)
	bottom.add_theme_constant_override("margin_left", _px(28))
	bottom.add_theme_constant_override("margin_right", _px(28))
	bottom.add_theme_constant_override("margin_bottom", _px(24))
	add_child(bottom)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", _px(18))
	bottom.add_child(row)
	var speed_box = VBoxContainer.new()
	speed_label = _make_label("0 km/h", _px(24), Color.WHITE)
	speed_box.add_child(speed_label)
	speed_bar = ProgressBar.new()
	speed_bar.custom_minimum_size = Vector2(_px(220), _px(18))
	speed_bar.show_percentage = false
	speed_box.add_child(speed_bar)
	row.add_child(speed_box)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var abilities = VBoxContainer.new()
	boost_label = _make_label("☕ BOOST READY [SPACE]", _px(18), Color("ff9a1a"))
	abilities.add_child(boost_label)
	boost_bar = ProgressBar.new()
	boost_bar.custom_minimum_size = Vector2(_px(240), _px(16))
	boost_bar.show_percentage = false
	abilities.add_child(boost_bar)
	sabotage_label = _make_label("Q  SABOTAGE", _px(16), Color(1, 1, 1, 0.72))
	abilities.add_child(sabotage_label)
	item_label = _make_label("", _px(16), Color(0.7, 0.9, 1.0))
	abilities.add_child(item_label)
	row.add_child(abilities)

func _make_label(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func set_timer_text(value: String) -> void:
	if timer_label:
		timer_label.text = value

func set_floor(value: int) -> void:
	if floor_label:
		floor_label.text = "FLOOR %d" % value
	if minimap and minimap.has_method("set_player"):
		minimap.set_player(Vector3.ZERO, value - 1)

func set_player_position(world_position: Vector3, floor_index: int) -> void:
	if minimap and minimap.has_method("set_player"):
		minimap.set_player(world_position, floor_index)

func set_status(value: String, color: Color = Color.WHITE) -> void:
	if status_label:
		status_label.text = value
		status_label.add_theme_color_override("font_color", color)

func set_speed(value: float, max_speed: float = 12.0) -> void:
	if speed_label:
		speed_label.text = "%d km/h" % roundi(value * 3.6)
	if speed_bar:
		speed_bar.value = clampf(value / max_speed * 100.0, 0.0, 100.0)
		speed_bar.modulate = Color(0.35, 1.0, 0.55).lerp(Color(1.0, 0.25, 0.15), clampf(value / max_speed, 0.0, 1.0))

func set_boost(cooldown: float, duration: float, active: bool, cooldown_max := 3.0) -> void:
	if boost_bar:
		boost_bar.value = 100.0 if active else clampf(100.0 - cooldown / cooldown_max * 100.0, 0.0, 100.0)
	if boost_label:
		boost_label.text = "☕ BOOST ACTIVE" if active else ("☕ BOOST READY [SPACE]" if cooldown <= 0.0 else "☕ BOOST %.1fs" % cooldown)
		boost_label.add_theme_color_override("font_color", Color("ffcf55") if active or cooldown <= 0.0 else Color(1, 1, 1, 0.45))

## Phase 4B item readout: kind × charges, or the plain sabotage hint.
func set_item(kind: StringName, charges: int) -> void:
	if item_label == null:
		return
	if kind == &"none" or charges <= 0:
		item_label.text = ""
		return
	var display := ""
	match kind:
		&"stapler":
			display = "📎 STAPLER ×%d  [Q]" % charges
		&"spill":
			display = "💧 SPILL ×%d  [Q]" % charges
		_:
			display = "ITEM ×%d  [Q]" % charges
	item_label.text = display
	item_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45) if kind == &"stapler" else Color(1.0, 0.9, 0.4))
