extends CanvasLayer

# D2 HUD hierarchy (UI-LAYOUTS §6): objective first, player state second,
# supporting data third. Top-center objective header+strip, floor/map group
# top-left, player state bottom-left, supporting status top-right. All
# chrome via UITheme tokens — no local color literals.

var speed_label: Label
var floor_label: Label
var boost_label: Label
var sabotage_label: Label
var timer_label: Label
var pb_label: Label
var status_label: Label
var timer_caption: Label
var speed_bar: ProgressBar
var boost_bar: ProgressBar
var minimap: Control
var item_label: Label
var objective_label: Label
var state_panel: PanelContainer
var _state_accented := false
var _last_objective_floor := -1
# Narrow-viewport layout (390px portrait sweep, FINAL day): the desktop
# insets (±352px header, 312px status chip) assume a wide screen. Under 520px
# they push the timer/objective header clean off the viewport and drop the
# status chip on top of the minimap. Nodes kept as members so the insets can
# re-apply on viewport resize (rotate mid-match).
var _header: PanelContainer
var _objective_panel: PanelContainer
var _status_panel: PanelContainer
var _floor_group: VBoxContainer

var UIT: GDScript

# D2 objective copy per §6 "Evacuation objective copy" — replaces the old
# GOAL/GREEN EXIT GATE wording (spec: do not reuse).
const FLOOR_GOALS := [
	"REACH CHAIR LIFT ↑ 02",
	"REACH CHAIR LIFT ↑ 03",
	"CROSS LANDINGS / REACH LIFT ↑ 04",
	"CROSS THE PARKING EXIT",
]

func _ready() -> void:
	UIT = load("res://scripts/UITheme.gd")
	_build_hud()

# MOBILE PASS: scale HUD chrome with viewport height so phones get readable
# text and desktop keeps the current sizes. 720p => 1.0; a 360px-tall
# landscape phone viewport => ~0.72; tall portrait windows => up to ~1.6.
func _ui_scale() -> float:
	var h := get_viewport().get_visible_rect().size.y
	return clampf(h / 720.0, 0.85, 1.6)

func _px(v: float) -> int:
	return int(round(v * _ui_scale()))

func _c(hex: String, alpha: float = 1.0) -> Color:
	if UIT:
		return UIT.color(hex, alpha)
	var col := Color(hex)
	col.a = alpha
	return col

func _panel_style(alpha: float, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# Spec §6 header uses alpha 0.96; ArtHUDTest's readability contract
	# requires fully opaque world isolation for the player-state panel.
	style.bg_color = _c(UIT.BG, alpha)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

## P1B: the one chip look — story chip and sabotage hint share it.
func _chip_style() -> StyleBoxFlat:
	return _panel_style(0.96, 10)

func _build_hud() -> void:
	# --- OBJECTIVE HEADER (top-center): caption left, timer right. ---
	var header := PanelContainer.new()
	header.name = "ObjectiveHeader"
	_header = header
	header.add_theme_stylebox_override("panel", _panel_style(0.96))
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = _px(16)
	header.offset_bottom = _px(64)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", _px(16))
	header.add_child(header_row)
	timer_caption = _make_label("EVACUATION WINDOW", _px(14), _c(UIT.TEXT))
	timer_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(timer_caption)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)
	timer_label = _make_label("2:00", _px(34), _c(UIT.ORANGE))
	header_row.add_child(timer_label)
	pb_label = _make_label("", _px(12), _c(UIT.LIME))
	pb_label.name = "PbChip"
	pb_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb_label.visible = false
	header_row.add_child(pb_label)

	# --- OBJECTIVE STRIP: arrow + immediate action, two lines max. ---
	var objective_panel := PanelContainer.new()
	objective_panel.name = "ObjectivePanel"
	_objective_panel = objective_panel
	objective_panel.add_theme_stylebox_override("panel", _panel_style(0.92))
	objective_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	objective_panel.offset_top = _px(68)
	objective_panel.offset_bottom = _px(104)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(objective_panel)
	var obj_row := HBoxContainer.new()
	obj_row.add_theme_constant_override("separation", _px(10))
	obj_row.alignment = BoxContainer.ALIGNMENT_CENTER
	objective_panel.add_child(obj_row)
	var arrow := _make_label("▲", _px(28), _c(UIT.ORANGE))
	arrow.name = "ObjectiveArrow"
	obj_row.add_child(arrow)
	objective_label = _make_label(FLOOR_GOALS[0], _px(18), _c(UIT.TEXT))
	objective_label.name = "ObjectiveStrip"
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_label.add_theme_constant_override("outline_size", 4)
	objective_label.add_theme_color_override("font_outline_color", _c(UIT.BG, 0.85))
	obj_row.add_child(objective_label)

	# --- FLOOR / MAP GROUP (top-left): story label above the map. ---
	var floor_group := VBoxContainer.new()
	floor_group.name = "FloorGroup"
	_floor_group = floor_group
	floor_group.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	floor_group.offset_left = _px(24)
	floor_group.offset_top = _px(16)
	floor_group.add_theme_constant_override("separation", _px(6))
	floor_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_group)
	var floor_panel := PanelContainer.new()
	floor_panel.add_theme_stylebox_override("panel", _chip_style())
	floor_group.add_child(floor_panel)
	floor_label = _make_label("FLOOR 1", _px(20), _c(UIT.TEXT))
	floor_panel.add_child(floor_label)
	var minimap_script = load("res://scripts/Minimap.gd")
	minimap = Control.new()
	minimap.set_script(minimap_script)
	var map_size := _px(168)
	minimap.custom_minimum_size = Vector2(map_size, map_size)
	minimap.size = Vector2(map_size, map_size)
	floor_group.add_child(minimap)

	# --- SUPPORTING STATUS (top-right). ---
	var status_panel := PanelContainer.new()
	status_panel.name = "StatusPanel"
	_status_panel = status_panel
	status_panel.add_theme_stylebox_override("panel", _panel_style(0.96, 10))
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_panel)
	status_label = _make_label("RACE", _px(18), _c(UIT.TEXT))
	status_panel.add_child(status_label)

	# --- PLAYER STATE (bottom-left): speed, thrust, item/charges. ---
	state_panel = PanelContainer.new()
	state_panel.name = "Instruments"
	# Readability contract (ArtHUDTest): world-facing player-state chrome is
	# fully opaque; header/strip keep their spec alphas (0.96/0.92).
	state_panel.add_theme_stylebox_override("panel", _panel_style(1.0, 10))
	state_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	state_panel.offset_left = _px(24)
	state_panel.offset_top = -_px(176)
	state_panel.offset_bottom = -_px(24)
	state_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(state_panel)
	var state_cols := VBoxContainer.new()
	state_cols.add_theme_constant_override("separation", _px(6))
	state_panel.add_child(state_cols)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", _px(8))
	state_cols.add_child(speed_row)
	speed_label = _make_label("0", _px(24), _c(UIT.TEXT))
	speed_row.add_child(speed_label)
	var unit_label = _make_label("km/h", _px(12), _c(UIT.TEXT_MUTED))
	unit_label.name = "SpeedUnit"
	unit_label.size_flags_vertical = Control.SIZE_SHRINK_END
	speed_row.add_child(unit_label)
	speed_bar = ProgressBar.new()
	speed_bar.custom_minimum_size = Vector2(_px(112), _px(8))
	speed_bar.show_percentage = false
	speed_bar.add_theme_stylebox_override("fill", _meter_fill())
	speed_bar.add_theme_stylebox_override("background", _meter_bg())
	state_cols.add_child(speed_bar)
	# Keep the legacy "Abilities" group name addressable (tests/callers).
	var abilities := VBoxContainer.new()
	abilities.name = "Abilities"
	abilities.add_theme_constant_override("separation", _px(4))
	state_cols.add_child(abilities)
	boost_label = _make_label("COFFEE BOOST READY [SPACE]", _px(14), _c(UIT.ORANGE))
	abilities.add_child(boost_label)
	boost_bar = ProgressBar.new()
	boost_bar.custom_minimum_size = Vector2(_px(252), _px(12))
	boost_bar.show_percentage = false
	boost_bar.add_theme_stylebox_override("fill", _meter_fill())
	boost_bar.add_theme_stylebox_override("background", _meter_bg())
	abilities.add_child(boost_bar)
	# P1B: sabotage hint shares the story chip's panel style (one chip look).
	sabotage_label = _make_label("Q  SABOTAGE", _px(14), _c(UIT.TEXT, 0.72))
	var sabotage_chip := PanelContainer.new()
	sabotage_chip.name = "SabotageChip"
	sabotage_chip.add_theme_stylebox_override("panel", _chip_style())
	sabotage_chip.add_child(sabotage_label)
	abilities.add_child(sabotage_chip)
	item_label = _make_label("", _px(14), _c(UIT.VIOLET))
	abilities.add_child(item_label)

	# Narrow/desktop insets + live re-apply on rotate (see member docs).
	get_viewport().size_changed.connect(_apply_insets)
	_apply_insets()

## Narrow-viewport inset pass (390px portrait sweep): under 520px the header
## and objective strip collapse to a touch-safe 12px side inset (desktop's
## ±352px put the timer off-viewport), and the status chip drops below the
## objective strip on the right so it never lands on the minimap (desktop's
## 312px-wide chip overlapped the top-left floor group at 390px).
func _apply_insets() -> void:
	if _header == null:
		return
	var narrow := get_viewport().get_visible_rect().size.x < 520.0
	var side := _px(12) if narrow else _px(352)
	_header.offset_left = side
	_header.offset_right = -side
	_objective_panel.offset_left = side
	_objective_panel.offset_right = -side
	if narrow:
		_floor_group.offset_top = _px(132)
		_status_panel.offset_left = -_px(150)
		_status_panel.offset_right = -_px(12)
		_status_panel.offset_top = _px(132)
		_status_panel.offset_bottom = _px(184)
	else:
		_floor_group.offset_top = _px(16)
		_status_panel.offset_left = -_px(312)
		_status_panel.offset_right = -_px(24)
		_status_panel.offset_top = _px(16)
		_status_panel.offset_bottom = _px(64)

func _meter_fill() -> StyleBoxFlat:
	var fill := StyleBoxFlat.new()
	fill.bg_color = _c(UIT.ORANGE)  # spec §6: ORANGE throughout, no ramp
	fill.set_corner_radius_all(3)
	return fill

func _meter_bg() -> StyleBoxFlat:
	var bg := StyleBoxFlat.new()
	bg.bg_color = _c(UIT.SURFACE)
	bg.set_corner_radius_all(3)
	return bg

func _make_label(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func set_timer_text(value: String, remaining: float = -1.0) -> void:
	if timer_label:
		timer_label.text = value
	# §6: hero timer goes CORAL + pulses when critical (<15s).
	_timer_remaining = remaining

## PB target chip: your saved best finish, parked beside the timer so there's
## a number to chase. Hidden entirely until a real best exists.
func set_personal_best(best: float) -> void:
	if pb_label == null:
		return
	pb_label.visible = best > 0.0
	if best > 0.0:
		pb_label.text = "PB %.1fs" % best

var _timer_remaining := -1.0
var _pulse_time := 0.0

func set_floor(value: int) -> void:
	if floor_label:
		floor_label.text = "STORY %02d / 04" % value
	# Objective strip tracks the checkpoint: elevator teleports advance the
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
	# Critical-timer pulse (CORAL, alpha 0.75-1.0 at 0.5s cycle; reduced
	# motion = solid per §6).
	if timer_label and _timer_remaining >= 0.0:
		var reduced := false
		var a11y = load("res://scripts/Accessibility.gd")
		if a11y and a11y.has_method("reduced_motion"):
			reduced = a11y.reduced_motion()
		if _timer_remaining < 15.0:
			timer_label.add_theme_color_override("font_color", _c(UIT.CORAL))
			var pulse := 1.0
			if not reduced:
				_pulse_time += delta
				pulse = 0.75 + 0.25 * (0.5 + 0.5 * sin(_pulse_time * TAU / 0.5))
			timer_label.modulate.a = pulse
		else:
			timer_label.add_theme_color_override("font_color", _c(UIT.ORANGE))
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
		# §6: meter is ORANGE throughout — the old amber→coral speed lerp
		# is retired (no green-to-red ramp, no value-revealing color shift).

func set_boost(cooldown: float, duration: float, active: bool, cooldown_max := 3.0) -> void:
	if boost_bar:
		boost_bar.value = 100.0 if active else clampf(100.0 - cooldown / cooldown_max * 100.0, 0.0, 100.0)
	if boost_label:
		# §6: READY / ACTIVE / cooldown text at 14px.
		boost_label.text = "COFFEE BOOST ACTIVE" if active else ("COFFEE BOOST READY [SPACE]" if cooldown <= 0.0 else "COFFEE BOOST %.1fs" % cooldown)
		boost_label.add_theme_color_override("font_color", _c(UIT.ORANGE_BRIGHT) if active or cooldown <= 0.0 else _c(UIT.TEXT, 0.45))
	_apply_state_accent(active or cooldown <= 0.0)

## P1B: the player-state panel glows an ORANGE border while boost is
## READY/ACTIVE and returns to the plain surface while cooling. Toggles only
## on state change (no per-frame stylebox churn).
func _apply_state_accent(on: bool) -> void:
	if state_panel == null or on == _state_accented:
		return
	_state_accented = on
	var sb: StyleBoxFlat = state_panel.get_theme_stylebox("panel")
	if sb:
		sb.set_border_width_all(2 if on else 0)
		sb.border_color = UIT.color(UIT.ORANGE)

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
			display = "STAPLER x%d [Q]" % charges
		&"spill":
			display = "SPILL x%d [Q]" % charges
		_:
			display = "ITEM x%d [Q]" % charges
	item_label.text = display
	item_label.add_theme_color_override("font_color", _c(UIT.CORAL) if kind == &"stapler" else _c(UIT.YELLOW))
