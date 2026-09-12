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
var objective_label: Label
var _last_objective_floor := -1

# GOAL/CHECKPOINT LABELING: what the player must do on each floor. The
# floor index IS the checkpoint count (respawn checkpoints advance on
# elevator teleport). Shown as a persistent strip under the top bar so
# the goal is always legible, not just in the round-start recap.
const FLOOR_GOALS := [
	"GOAL 1/4 — FIND THE ELEVATOR • GLASS TUBE AT THE EDGE",
	"GOAL 2/4 — UP TO FLOOR 3 • RIDE THE ELEVATOR",
	"GOAL 3/4 — TOP FLOOR LOT • LAST ELEVATOR",
	"FINAL GOAL — CROSS THE GREEN EXIT GATE!",
]

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
	top_style.bg_color = Color(0.045, 0.045, 0.08, 1.0)
	top_style.border_color = Color(1, 0.6, 0.1, 0.5)
	top_style.border_width_bottom = 3
	top.add_theme_stylebox_override("panel", top_style)
	add_child(top)
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", _px(26))
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(top_row)
	floor_label = _make_label("FLOOR 1", _px(20), Color(1, 1, 1, 0.92))
	top_row.add_child(floor_label)
	timer_label = _make_label("2:00", _px(34), Color("ff9a1a"))
	top_row.add_child(timer_label)
	status_label = _make_label("RACE", _px(18), Color(0.4, 1, 0.65))
	top_row.add_child(status_label)

	# Objective strip: persistent goal line under the top bar.
	# D4: the strip gets its own dark panel bg so the goal text never sits
	# on raw 3D ceiling lights.
	var objective_panel := PanelContainer.new()
	objective_panel.name = "ObjectivePanel"
	var obj_style := StyleBoxFlat.new()
	obj_style.bg_color = Color(0.02, 0.02, 0.04, 0.72)
	obj_style.set_corner_radius_all(8)
	obj_style.content_margin_left = 12.0
	obj_style.content_margin_right = 12.0
	obj_style.content_margin_top = 2.0
	obj_style.content_margin_bottom = 2.0
	objective_panel.add_theme_stylebox_override("panel", obj_style)
	objective_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	objective_panel.offset_left = _px(180)
	objective_panel.offset_right = -_px(180)
	objective_panel.offset_top = _px(78)
	objective_panel.offset_bottom = _px(104)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(objective_panel)
	objective_label = _make_label(
		FLOOR_GOALS[0], _px(14), Color(1.0, 0.72, 0.30))
	objective_label.name = "ObjectiveStrip"
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_constant_override("outline_size", 4)
	objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	objective_panel.add_child(objective_label)
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
	bottom.offset_top = -_px(152)
	bottom.add_theme_constant_override("margin_left", _px(28))
	bottom.add_theme_constant_override("margin_right", _px(28))
	bottom.add_theme_constant_override("margin_bottom", _px(24))
	add_child(bottom)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", _px(24))
	bottom.add_child(row)
	# Dusk pass: HUD text sat directly on the world, where the warm/cool
	# light pools now fight every readout. Opaque card panels (same dark
	# chrome as the menu) group speed and abilities, with a warm identity
	# on the meters instead of the engine-default grey fill.
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.045, 0.08, 1.0)
	panel_style.border_color = Color(1, 0.6, 0.1, 0.5)
	panel_style.border_width_left = 3
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_bottom = 12.0
	var meter_fill = StyleBoxFlat.new()
	meter_fill.bg_color = Color("ff9a1a")
	meter_fill.set_corner_radius_all(4)
	var meter_bg = StyleBoxFlat.new()
	meter_bg.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	meter_bg.set_corner_radius_all(4)
	var instruments = PanelContainer.new()
	instruments.name = "Instruments"
	instruments.add_theme_stylebox_override("panel", panel_style)
	row.add_child(instruments)
	var speed_box = VBoxContainer.new()
	speed_box.add_theme_constant_override("separation", _px(6))
	instruments.add_child(speed_box)
	speed_label = _make_label("0", _px(24), Color.WHITE)
	speed_box.add_child(speed_label)
	# D4: separate muted unit label next to the readout.
	var unit_label = _make_label("km/h", _px(11), Color("9b9baa"))
	unit_label.name = "SpeedUnit"
	speed_box.add_child(unit_label)
	speed_bar = ProgressBar.new()
	speed_bar.custom_minimum_size = Vector2(_px(220), _px(14))
	speed_bar.show_percentage = false
	speed_bar.add_theme_stylebox_override("fill", meter_fill)
	speed_bar.add_theme_stylebox_override("background", meter_bg)
	speed_box.add_child(speed_bar)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var abilities = PanelContainer.new()
	abilities.name = "Abilities"
	abilities.add_theme_stylebox_override("panel", panel_style)
	row.add_child(abilities)
	var ability_stack = VBoxContainer.new()
	ability_stack.add_theme_constant_override("separation", _px(4))
	abilities.add_child(ability_stack)
	boost_label = _make_label("☕ BOOST READY [SPACE]", _px(18), Color("ff9a1a"))
	ability_stack.add_child(boost_label)
	boost_bar = ProgressBar.new()
	boost_bar.custom_minimum_size = Vector2(_px(240), _px(12))
	boost_bar.show_percentage = false
	boost_bar.add_theme_stylebox_override("fill", meter_fill)
	boost_bar.add_theme_stylebox_override("background", meter_bg)
	ability_stack.add_child(boost_bar)
	sabotage_label = _make_label("Q  SABOTAGE", _px(16), Color(1, 1, 1, 0.72))
	ability_stack.add_child(sabotage_label)
	item_label = _make_label("", _px(16), Color(0.7, 0.9, 1.0))
	ability_stack.add_child(item_label)

func _make_label(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func set_timer_text(value: String, remaining: float = -1.0) -> void:
	if timer_label:
		timer_label.text = value
	# D4: hero timer goes CORAL + pulses when critical (<15s).
	_timer_remaining = remaining

var _timer_remaining := -1.0
var _pulse_time := 0.0

func set_floor(value: int) -> void:
	if floor_label:
		floor_label.text = "FLOOR %d" % value
	# Goal strip tracks the checkpoint: elevator teleports advance the
	# floor, which IS the checkpoint. Brief flash on change.
	if objective_label:
		var idx := clampi(value - 1, 0, FLOOR_GOALS.size() - 1)
		if idx != _last_objective_floor:
			_last_objective_floor = idx
			objective_label.text = FLOOR_GOALS[idx]
			objective_label.modulate.a = 1.6  # over-bright, decays to 1
	if minimap and minimap.has_method("set_player"):
		minimap.set_player(Vector3.ZERO, value - 1)

func _process(delta: float) -> void:
	# Decay the over-bright flash from a goal change back to 1.0.
	if objective_label and objective_label.modulate.a > 1.0:
		objective_label.modulate.a = maxf(1.0, objective_label.modulate.a - delta * 2.0)
	# D4: critical-timer pulse (CORAL, alpha 0.6-1.0 at 0.5s cycle).
	if timer_label and _timer_remaining >= 0.0:
		var reduced := false
		var a11y = load("res://scripts/Accessibility.gd")
		if a11y and a11y.has_method("reduced_motion"):
			reduced = a11y.reduced_motion()
		if _timer_remaining < 15.0:
			timer_label.add_theme_color_override("font_color", Color("ff6f61"))
			var pulse := 1.0
			if not reduced:
				_pulse_time += delta
				pulse = 0.6 + 0.4 * (0.5 + 0.5 * sin(_pulse_time * TAU / 0.5))
			timer_label.modulate.a = pulse
		else:
			timer_label.add_theme_color_override("font_color", Color("ff9a1a"))
			timer_label.modulate.a = 1.0

func set_player_position(world_position: Vector3, floor_index: int) -> void:
	if minimap and minimap.has_method("set_player"):
		minimap.set_player(world_position, floor_index)

func set_status(value: String, color: Color = Color.WHITE) -> void:
	if status_label:
		status_label.text = value
		status_label.add_theme_color_override("font_color", color)

func set_speed(value: float, max_speed: float = 12.0) -> void:
	if speed_label:
		speed_label.text = "%d" % roundi(value * 3.6)
	if speed_bar:
		speed_bar.value = clampf(value / max_speed * 100.0, 0.0, 100.0)
		# Dusk identity: warm meter fill scaled by speed (amber -> coral);
		# the old green->red ramp clashed with the orange UI and read as
		# an engine-default progress bar at 0 km/h.
		var fill: StyleBoxFlat = speed_bar.get_theme_stylebox("fill")
		if fill is StyleBoxFlat:
			var warm := Color("ffb52e").lerp(Color(1.0, 0.42, 0.20), clampf(value / max_speed, 0.0, 1.0))
			fill.bg_color = warm

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
