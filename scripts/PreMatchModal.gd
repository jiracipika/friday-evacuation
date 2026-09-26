# PreMatchModal.gd — blocking pre-game briefing, "After Hours" S-E restyle.
#
# When a match scene opens, the whole SceneTree is PAUSED and a modal
# shows: a hazard-tape header ("HOW IT WORKS" + step count), one card per
# objective step (drawn pictogram, 01/02/03 numeral, title, copy), the
# control maps as keycap chips / pad circles in two columns, and the
# orange CLOCK OUT — GO gate. The timer and game do not run — the user
# must press the CTA (or Enter / Space / gamepad A) to dismiss. Only
# then does the countdown (frozen until now) begin ticking.
#
# FINAL-SPEC section 6 + board f4-howto.png. The in-match HUD layers are
# hidden while the modal is up (spec: "paused = invisible") and restored
# on dismissal. Rules honored: R2 pictos drawn (no emoji), R3 tabular
# numerals, R6 INK-on-ORANGE CTA, R7 exactly one hazard-tape use here,
# R10 radius scale. Keycaps show the REAL default binds, not the board's
# mock ones (honesty over the mock).
#
# Mount at the END of each mode's _ready:
#   PreMatchModal.mount(self, "EVACUATION", objective_lines)
#
# All modes already set match_state/countdown/round vars in _ready;
# because the tree is paused, nothing ticks until agreement. The
# round-start ControlsOverlay recap (behind this modal) resumes its
# 7s window after dismissal, so players still get the in-world recap
# as the countdown runs.
extends CanvasLayer

const UI_THEME = preload("res://scripts/UITheme.gd")

const SCRIM := Color(0.016, 0.016, 0.031, 0.8)  # rgba(4,4,8,.8) per spec
const PICTO_KINDS := ["flag", "lift", "home"]
const ACTION_LABEL_COLOR := Color("c4c4d2")  # spec: action labels, not faint

static var _suppress_once := false  # headless tests / rematches can skip

var agree_button: Button
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _agreed := false
var _hidden_layers: Array = []

## mode_title: e.g. "EVACUATION". objective_lines: 1-4 short strings;
## "TITLE — copy" lines become step cards, plain sentences become
## copy-only cards titled STEP N.
static func mount(parent: Node, mode_title: String, objective_lines: Array) -> CanvasLayer:
	if _suppress_once:
		_suppress_once = false
		return null
	if parent.has_node("PreMatchModal"):
		return null
	var layer: CanvasLayer = CanvasLayer.new()
	layer.set_script(load("res://scripts/PreMatchModal.gd"))
	layer.name = "PreMatchModal"
	layer.mode_title = mode_title
	layer.objective_lines = objective_lines
	# Pause FIRST so not one frame of gameplay runs before agreement.
	parent.get_tree().paused = true
	parent.add_child(layer)
	return layer

## Headless tests / internal rematches set this to skip the modal once.
static func suppress_next() -> void:
	_suppress_once = true

var mode_title := "MODE"
var objective_lines: Array = []

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hide_hud_layers(get_parent())
	_deferred_rehide()

	# Scrim: spec rgba(4,4,8,.8) — the scene reads as a muted game behind.
	var backdrop := ColorRect.new()
	backdrop.name = "Scrim"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = SCRIM
	add_child(backdrop)

	var vp_w: float = get_viewport().get_visible_rect().size.x
	var panel := PanelContainer.new()
	panel.name = "Panel"
	var style := UI_THEME.panel_style(UI_THEME.color(UI_THEME.ORANGE), true)
	style.bg_color = UI_THEME.color(UI_THEME.SURFACE_RAISED, 0.98)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", style)
	if vp_w < 720.0:
		# Narrow fallback: full-bleed sheet (portrait play is gated by
		# PortraitHint anyway; this keeps landscape phones safe).
		add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	else:
		# CanvasLayer children have no sized parent, so anchor/grow
		# centering collapses to an edge (measured off-screen both ways).
		# A full-rect CenterContainer is the reliable centering.
		panel.custom_minimum_size = Vector2(680, 0)
		var center := CenterContainer.new()
		center.name = "Center"
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center)
		center.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "Column"
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	# S-E hazard-tape strip: the panel's single tape use (spec R7).
	var tape := TapeStrip.new()
	tape.name = "TapeStrip"
	tape.custom_minimum_size = Vector2(0, 12)
	box.add_child(tape)

	# Header: HOW IT WORKS (white, tracked caps) + step-count micro meta.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	var title := Label.new()
	title.text = "HOW IT WORKS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT))
	header.add_child(title)
	var meta := Label.new()
	meta.name = "StepsMeta"
	meta.text = "%d STEPS" % objective_lines.size()
	meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_FAIR))
	header.add_child(meta)

	# Step cards: picto circle + 01/02/03 numeral + title + copy.
	var cards := HBoxContainer.new()
	cards.name = "StepCards"
	cards.add_theme_constant_override("separation", 12)
	box.add_child(cards)
	var counter := 0
	for line in objective_lines:
		cards.add_child(_step_card(String(line), counter))
		counter += 1

	# Controls: two columns split by a hairline.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	box.add_child(cols)
	cols.add_child(_control_column("KEYBOARD & MOUSE", [
		[["W", "A", "S", "D"], "MOVE"],
		[["SPACE"], "BOOST"],
		[["E"], "ACTION"],
		[["Q"], "SABOTAGE"],
		[["MOUSE", "R"], "CAMERA · RECENTER"],
		[["ESC"], "PAUSE"],
	]))
	var hairline := ColorRect.new()
	hairline.custom_minimum_size = Vector2(1, 0)
	hairline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hairline.color = Color(1, 1, 1, 0.09)
	cols.add_child(hairline)
	cols.add_child(_control_column("CONTROLLER", [
		[["LS"], "MOVE"],
		[["A"], "BOOST"],
		[["X"], "ACTION"],
		[["B"], "SABOTAGE"],
		[["RS", "Y"], "CAMERA · RECENTER"],
		[["START"], "PAUSE"],
	]))
	var touch := Label.new()
	touch.text = _touch_line()
	touch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	touch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	touch.add_theme_font_size_override("font_size", 12)
	touch.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_FAIR))
	box.add_child(touch)

	var rule := Label.new()
	rule.text = "Timer and world are paused until you start."
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.add_theme_font_size_override("font_size", 11)
	rule.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_FAIR))
	box.add_child(rule)

	# CTA: INK text on ORANGE (spec R6, >= 7:1) with pad/key hint parked
	# right inside the button like the board.
	agree_button = Button.new()
	agree_button.name = "CtaButton"
	agree_button.text = "CLOCK OUT — GO"
	agree_button.custom_minimum_size = Vector2(0, 54)
	agree_button.add_theme_font_size_override("font_size", 21)
	var cta_style := UI_THEME.button_style(UI_THEME.color(UI_THEME.ORANGE), UI_THEME.color(UI_THEME.ORANGE_BRIGHT), 1, 12)
	cta_style.bg_color = UI_THEME.color(UI_THEME.ORANGE)
	cta_style.shadow_color = Color(0, 0, 0, 0.45)
	agree_button.add_theme_stylebox_override("normal", cta_style)
	agree_button.add_theme_stylebox_override("hover", cta_style)
	agree_button.add_theme_stylebox_override("pressed", cta_style)
	agree_button.add_theme_stylebox_override("focus", cta_style)
	agree_button.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.INK))
	agree_button.add_theme_color_override("font_hover_color", UI_THEME.color(UI_THEME.INK))
	agree_button.add_theme_color_override("font_pressed_color", UI_THEME.color(UI_THEME.INK))
	agree_button.add_theme_color_override("font_focus_color", UI_THEME.color(UI_THEME.INK))
	agree_button.pressed.connect(_agree)
	box.add_child(agree_button)
	var hint := Label.new()
	hint.name = "CtaHint"
	hint.text = "SPACE / A"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(UI_THEME.color(UI_THEME.INK), 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	agree_button.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	hint.offset_left = -96.0
	hint.offset_right = -16.0
	hint.offset_top = -9.0
	hint.offset_bottom = 9.0
	agree_button.grab_focus()

## One step card. "TITLE — copy" lines (Evacuation) use the parsed title;
## plain sentences keep their whole text as copy under "STEP N".
func _step_card(line: String, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "StepCard%d" % index
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UI_THEME.color(UI_THEME.SURFACE)
	card_style.set_corner_radius_all(12)
	card_style.content_margin_left = 12.0
	card_style.content_margin_right = 12.0
	card_style.content_margin_top = 10.0
	card_style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", card_style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	var icon := PictoIcon.new()
	icon.kind = PICTO_KINDS[index % PICTO_KINDS.size()]
	icon.name = "Picto"
	icon.custom_minimum_size = Vector2(46, 46)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.add_child(icon)
	var num := Label.new()
	num.text = "%02d" % (index + 1)
	num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.add_theme_font_size_override("font_size", 13)
	num.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_FAIR))
	top.add_child(num)

	var parsed := _parse_step(line, index)
	var head := Label.new()
	head.text = parsed["title"]
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.ORANGE))
	col.add_child(head)
	var copy := Label.new()
	copy.text = parsed["copy"]
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size = Vector2(150, 0)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_font_size_override("font_size", 12)
	copy.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_FAIR))
	col.add_child(copy)
	return card

func _parse_step(line: String, index: int) -> Dictionary:
	var parts := line.split(" — ", true, 1)
	if parts.size() == 2:
		var head: String = String(parts[0]).strip_edges()
		if head.length() <= 10 and head == head.to_upper():
			return {"title": head, "copy": String(parts[1]).strip_edges()}
	return {"title": "STEP %d" % (index + 1), "copy": line}

## Keycap chip row: [keys] left, action label right (#c4c4d2 per spec).
func _control_column(heading: String, rows: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.name = "ControlColumn"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 7)
	var head := Label.new()
	head.text = heading
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.ORANGE))
	col.add_child(head)
	for row in rows:
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 5)
		col.add_child(row_box)
		for key in row[0]:
			row_box.add_child(_chip(String(key), heading == "CONTROLLER"))
		var action := Label.new()
		action.text = String(row[1])
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action.add_theme_font_size_override("font_size", 12)
		action.add_theme_color_override("font_color", ACTION_LABEL_COLOR)
		row_box.add_child(action)
	return col

## 30x26 raised keycap chip (keyboard) or pad circle (controller glyphs).
func _chip(glyph: String, is_pad: bool) -> PanelContainer:
	# Kind comes from the COLUMN, not the glyph: WASD contains an "A".
	var chip := PanelContainer.new()
	var chip_name := "PadChip" if is_pad else "Keycap"
	var style := StyleBoxFlat.new()
	style.bg_color = UI_THEME.color(UI_THEME.SURFACE_HOVER)
	style.set_corner_radius_all(13 if chip.name == "PadChip" else 5)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 0
	style.shadow_offset = Vector2(0, 2)
	# StyleBoxFlat shadow renders behind the box: emulate the board's
	# "raised, bottom shadow 2px" with a 1px darker bottom border instead.
	style.border_width_bottom = 2
	style.border_color = Color(0, 0, 0, 0.55)
	chip.add_theme_stylebox_override("panel", style)
	chip.name = "%s_%s" % [chip_name, glyph]
	chip.custom_minimum_size = Vector2(30, 26)
	var label := Label.new()
	label.text = glyph
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT))
	chip.add_child(label)
	return chip

func _deferred_rehide() -> void:
	await get_tree().process_frame
	if _agreed or not is_inside_tree():
		return
	_hide_hud_layers(get_parent())

func _hide_hud_layers(parent: Node) -> void:
	# Spec section 6: the HUD timer must not ghost through the scrim.
	# Only the known HUD layers; ControlsOverlay recap stays behind the
	# modal and resumes after dismissal.
	for prop in ["hud_ext", "mode_hud"]:
		var n = parent.get(prop)
		if n is CanvasLayer and n.visible:
			n.visible = false
			_hidden_layers.append(n)
	var legacy: Node = parent.get_node_or_null("UI")
	if legacy is CanvasLayer and legacy.visible:
		legacy.visible = false
		_hidden_layers.append(legacy)

func _restore_hud_layers() -> void:
	for n in _hidden_layers:
		if is_instance_valid(n):
			(n as CanvasLayer).visible = true
	_hidden_layers.clear()

func _touch_line() -> String:
	var prefs = load("res://scripts/InputPrefs.gd")
	var on := false
	if prefs and prefs.has_method("touch_enabled"):
		on = prefs.touch_enabled()
	if on:
		return "TOUCH: left joystick moves — BOOST / JUMP / TRAP buttons bottom-right."
	return "Playing on a phone or tablet? The touch overlay appears automatically (or tap TOUCH: ON in the menu)."

func _unhandled_input(event: InputEvent) -> void:
	# Gamepad A / Start also agree (Boomerang-Fu behavior: any confirm).
	if event is InputEventJoypadButton and event.pressed \
			and (event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_START):
		_agree()
		get_viewport().set_input_as_handled()

func _agree() -> void:
	if _agreed:
		return
	_agreed = true
	_restore_hud_layers()
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse_mode
	queue_free()

## Hazard-tape band: yellow 45deg stripes on near-black, drawn (spec R2:
## no emoji/bitmaps — vector), one use per screen max (R7).
class TapeStrip extends Control:
	const YELLOW := Color("f2c230")
	const GROUND := Color("191411")
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), GROUND)
		var slope := size.y * 1.4
		var period := slope * 2.0
		var x := 0.0
		while x < size.x + period:
			var poly := PackedVector2Array([
				Vector2(x - slope, size.y), Vector2(x, 0.0),
				Vector2(x + slope * 0.7, 0.0), Vector2(x + slope * 0.7 - slope, size.y),
			])
			draw_polygon(poly, [YELLOW])
			x += period

## 46px circle icon frame with a drawn pictogram (spec R2).
class PictoIcon extends Control:
	var kind := "flag"
	func _draw() -> void:
		var orange := Color("ff9a1a")
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.5
		draw_arc(c, r, 0.0, TAU, 40, orange, 2.2, true)
		match kind:
			"flag":
				var pole := c + Vector2(-r * 0.22, -r * 0.5)
				draw_line(pole, pole + Vector2(0.0, r), orange, 2.2, true)
				draw_polygon(PackedVector2Array([
					pole, pole + Vector2(r * 0.62, r * 0.2), pole + Vector2(0.0, r * 0.42),
				]), [orange])
			"lift":
				var w := r * 1.05
				var h := r * 1.15
				var o := c + Vector2(-w * 0.5, -h * 0.5)
				draw_rect(Rect2(o, Vector2(w, h)), orange, false, 2.2)
				draw_line(c + Vector2(0.0, -h * 0.5), c + Vector2(0.0, h * 0.5), orange, 2.2, true)
			"home":
				var roof_apex := c + Vector2(0.0, -r * 0.52)
				var eave_l := c + Vector2(-r * 0.55, -r * 0.02)
				var eave_r := c + Vector2(r * 0.55, -r * 0.02)
				var base_l := c + Vector2(-r * 0.46, r * 0.5)
				var base_r := c + Vector2(r * 0.46, r * 0.5)
				draw_polyline(PackedVector2Array([
					eave_l, roof_apex, eave_r, base_r, base_l, eave_l,
				]), orange, 2.2, true)
				draw_rect(Rect2(c + Vector2(-r * 0.14, r * 0.08), Vector2(r * 0.28, r * 0.42)), orange, false, 2.2)
