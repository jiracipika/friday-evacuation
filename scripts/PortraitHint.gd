# PortraitHint.gd — UI SLICE: full-screen "rotate your phone" gate shown
# while the in-match viewport is PORTRAIT (width < height). The game is
# landscape-first; portrait play works but the FOV and touch controls are
# tuned for wide viewports, so we ask once (tap to continue anyway) instead
# of silently degrading. Auto-hides the moment the viewport goes wide, and
# never shows on desktop-width screens.
#
# Static mount helper keeps wiring one line per mode, like PreMatchModal.
class_name PortraitHint
extends CanvasLayer

const ROTATE_TEXT := "Rotate your phone"
const SUB_TEXT := "This game plays best in landscape.\nTap to play in portrait anyway."

var _panel: PanelContainer
var _dismissed := false

static func mount(parent: Node) -> void:
	var hint := CanvasLayer.new()
	hint.set_script(load("res://scripts/PortraitHint.gd"))
	hint.name = "PortraitHint"
	hint.layer = 40  # REVIEW FIX: was 90 — same as PreMatchModal; now under the pre-match modal (90) and pause menu (50)
	parent.add_child(hint)

func _ready() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.039, 0.039, 0.058, 0.97)
	style.border_color = Color(1.0, 0.60, 0.22, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vb)

	var icon := Label.new()
	icon.text = "📱↻"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 64)
	vb.add_child(icon)

	var title := Label.new()
	title.text = ROTATE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.60, 0.22))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = SUB_TEXT
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	vb.add_child(sub)

	var proceed := Button.new()
	proceed.text = "PLAY IN PORTRAIT"
	proceed.custom_minimum_size = Vector2(220, 52)
	proceed.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	proceed.pressed.connect(_dismiss)
	vb.add_child(proceed)

	_update_visibility()

func _process(_delta: float) -> void:
	# Live tracking: rotating mid-match (sensor landscape lock release,
	# desktop window dragged narrow) hides/shows the hint automatically.
	_update_visibility()

func _update_visibility() -> void:
	if _panel == null:
		return
	var size := get_viewport().get_visible_rect().size
	_panel.visible = (not _dismissed) and size.y > size.x and size.x < 900.0

func _dismiss() -> void:
	_dismissed = true
	_panel.visible = false
