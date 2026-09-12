# CountdownOverlay.gd — D4: big center-screen countdown moment.
# CanvasLayer with 64px ORANGE numerals (dark outline), scale 1.3->1.0 +
# fade per numeral: 0.7s for 3/2/1, 0.5s for GO!. Reduced motion = instant
# show/hide. Purely visual; never blocks input.
extends CanvasLayer

const UI_THEME = preload("res://scripts/UITheme.gd")

var _root: Control
var _label: Label

static func mount(parent: Node) -> CanvasLayer:
	var existing: Node = parent.get_node_or_null("CountdownOverlay")
	if existing:
		return existing as CanvasLayer
	var layer: CanvasLayer = load("res://scripts/CountdownOverlay.gd").new()
	layer.name = "CountdownOverlay"
	parent.add_child(layer)
	return layer

func _ready() -> void:
	layer = 40  # above HUD (10), below pause (50)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_label = Label.new()
	_label.text = ""
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_label.add_theme_font_size_override("font_size", 64)
	_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.ORANGE))
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_label.pivot_offset = _label.size * 0.5
	_root.add_child(_label)

## seq: e.g. ["3", "2", "1", "GO!"]; reduced_motion shows each instantly.
func play_sequence(seq: Array) -> void:
	var reduced := false
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y and a11y.has_method("reduced_motion"):
		reduced = a11y.reduced_motion()
	var tween := create_tween()
	for step in seq:
		var dur := 0.5 if step == "GO!" else 0.7
		tween.tween_callback(func():
			_label.text = step
			_label.visible = true
			_label.modulate = Color(1, 1, 1, 1)
			_label.pivot_offset = _label.size * 0.5
			if not reduced:
				_label.scale = Vector2(1.3, 1.3)
		)
		if not reduced:
			tween.tween_property(_label, "scale", Vector2(1.0, 1.0), dur * 0.4)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_interval(dur * 0.6)
		else:
			tween.tween_interval(dur)
	tween.tween_callback(func(): _label.visible = false)
