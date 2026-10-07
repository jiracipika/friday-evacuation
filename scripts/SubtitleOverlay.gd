# SubtitleOverlay.gd — reusable audio-cue caption overlay.
# Mounts itself on any CanvasLayer (usually the HUD's). Joins the
# "caption_overlays" group so Accessibility.caption() can find it from
# anywhere (traps, powerups, elevators, race events) without signals or
# autoload wiring. Self-cleans captions; replaces in-flight captions.
extends Control

const DEFAULT_DURATION := 1.5
const MAX_WIDTH_RATIO := 0.7

var caption_label: Label
var caption_panel: PanelContainer
var _hide_timer: SceneTreeTimer = null
var _pending_token: int = 0

func _ready() -> void:
	add_to_group("caption_overlays")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	caption_panel = PanelContainer.new()
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_panel.visible = false
	# Bottom-center placement, above mobile controls territory (the exact
	# reserve is viewport-aware — see _relayout).
	caption_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption_panel.size = Vector2(0, 0)
	caption_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(caption_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.04, 0.88)
	style.border_color = Color(1, 1, 1, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	caption_panel.add_theme_stylebox_override("panel", style)

	caption_label = Label.new()
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 20)
	caption_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_panel.add_child(caption_label)

	# Narrow-aware relayout: the caption band must clear the bottom HUD chrome
	# (Evacuation's opaque instruments card owns the bottom band under 520px —
	# the fixed -140px offset let the card cover the caption completely at
	# 390x844) and its min width must honor MAX_WIDTH_RATIO at any viewport
	# (a fixed 320px min overflows a 305px-min window once margins are added).
	get_viewport().size_changed.connect(_relayout)
	_relayout()

func _relayout() -> void:
	var vp := get_viewport().get_visible_rect().size
	caption_label.custom_minimum_size = Vector2(minf(320.0, vp.x * MAX_WIDTH_RATIO), 0.0)
	var bottom_reserve := 140.0
	if vp.x < 520.0:
		# HUD.gd's instruments card: top edge at 176*ui_scale above the bottom.
		bottom_reserve = 176.0 * clampf(vp.y / 720.0, 0.85, 1.6) + 16.0
	# Explicit bottom-center base rect: a zero-size point on the bottom
	# anchor, raised by the reserve; grow directions (BEGIN vertical, BOTH
	# horizontal) expand it around that point. (The old `position = ` setter
	# fought the anchors/grow combo and could land the panel off-viewport.)
	caption_panel.offset_left = 0.0
	caption_panel.offset_right = 0.0
	caption_panel.offset_top = -bottom_reserve
	caption_panel.offset_bottom = -bottom_reserve

func show_caption(text: String, duration: float = DEFAULT_DURATION) -> void:
	if caption_label == null:
		return
	_pending_token += 1
	var token := _pending_token
	caption_label.text = text
	caption_panel.visible = true

	var tree := get_tree()
	if tree:
		_hide_timer = tree.create_timer(maxf(0.2, duration))
		_hide_timer.timeout.connect(func():
			# Only hide if no newer caption replaced this one.
			if token == _pending_token:
				caption_panel.visible = false
		)

func _exit_tree() -> void:
	if is_in_group("caption_overlays"):
		remove_from_group("caption_overlays")

## Mount the overlay on a CanvasLayer (or any Node parent) if none exists yet.
## Modes call this once from their HUD setup; multiple calls are no-ops.
static func mount(parent_node: Node) -> void:
	if parent_node == null:
		return
	var tree := parent_node.get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("caption_overlays"):
		if node and is_instance_valid(node):
			return  # already mounted somewhere in this scene
	var overlay := Control.new()
	overlay.name = "SubtitleOverlay"
	overlay.set_script(load("res://scripts/SubtitleOverlay.gd"))
	parent_node.add_child(overlay)
