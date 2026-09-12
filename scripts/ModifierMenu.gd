# ModifierMenu.gd — "TODAY'S OFFICE CHAOS" picker for single-player Evacuation.
# Game-style chip panel that replaces the old raw CheckButton debug row:
#   - header with a plain-language title + CLEAR action (only when something is on)
#   - wrapping toggle chips, each with its own accent color and a readable hint
#   - a live summary line that states what will actually happen in the race
#   - gamepad/touch friendly: chips are focusable Buttons, not hover-only checkboxes
# Mounted by Main.gd directly above the PLAY button; hidden unless Evacuation
# is the selected mode. State lives in RaceModifiers.gd (persisted to cfg).
class_name ModifierMenu
extends VBoxContainer

const UI_THEME = preload("res://scripts/UITheme.gd")

const TITLE_TEXT := "TODAY'S OFFICE CHAOS"
const SUB_TEXT := "Optional rules for your solo race. Tap to mix and match."
const CLASSIC_SUMMARY := "Classic race — no special rules today."
const FULL_CHAOS_SUMMARY := "FULL CHAOS. Every rule at once. Good luck."

# Per-modifier presentation data. Names stay in RaceModifiers.LABELS (single
# source of truth); this adds the accent color and the plain-language hint.
const HINTS := {
	RaceModifiers.Modifier.NO_COFFEE: "Coffee machine is broken. No boost.",
	RaceModifiers.Modifier.DOUBLE_TRAPS: "Facilities went ham. 8 traps out.",
	RaceModifiers.Modifier.LOW_GRAVITY: "Window's open. Moon gravity on.",
	RaceModifiers.Modifier.SLIPPERY: "Cleaning night ran late. Waxed floors.",
	RaceModifiers.Modifier.TIME_ATTACK_90: "Building demo at 5:30. 90 seconds.",
}

const ACCENTS := {
	RaceModifiers.Modifier.NO_COFFEE: "ff6f61",
	RaceModifiers.Modifier.DOUBLE_TRAPS: "9b82ff",
	RaceModifiers.Modifier.LOW_GRAVITY: "57d7ff",
	RaceModifiers.Modifier.SLIPPERY: "b9f34a",
	RaceModifiers.Modifier.TIME_ATTACK_90: "ff9a1a",
}

var title_label: Label
var sub_label: Label
var clear_button: Button
var chip_flow: HFlowContainer
var summary_label: Label
var chips: Dictionary = {}


## Mount the menu inside `parent`, positioned directly above `above_node`.
## Loads its own script instead of using the global class name: raw SceneTree
## test harnesses don't register class_name globals, and a bare self-reference
## would fail compilation there (same pattern as Network.gd's autoload guard).
static func mount(parent: Control, above_node: Node) -> Control:
	var menu: Control = load("res://scripts/ModifierMenu.gd").new()
	menu.name = "ModifierMenu"
	parent.add_child(menu)
	parent.move_child(menu, above_node.get_index())
	return menu


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var panel := PanelContainer.new()
	var panel_style: StyleBoxFlat = UI_THEME.panel_style(UI_THEME.color(UI_THEME.ORANGE), false)
	# Slimmer than the default 12px — this panel lives in a tight menu budget.
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)

	inner.add_child(_build_header())
	chip_flow = HFlowContainer.new()
	chip_flow.add_theme_constant_override("h_separation", 8)
	chip_flow.add_theme_constant_override("v_separation", 8)
	inner.add_child(chip_flow)
	_build_chips()
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 11)
	summary_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	inner.add_child(summary_label)

	refresh()


func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	var headings := VBoxContainer.new()
	headings.add_theme_constant_override("separation", 1)
	headings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label = Label.new()
	title_label.text = TITLE_TEXT
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.ORANGE))
	headings.add_child(title_label)
	sub_label = Label.new()
	sub_label.text = SUB_TEXT
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	headings.add_child(sub_label)
	header.add_child(headings)

	clear_button = Button.new()
	clear_button.text = "CLEAR"
	clear_button.flat = true
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.add_theme_font_size_override("font_size", 11)
	clear_button.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	clear_button.add_theme_color_override("font_hover_color", UI_THEME.color(UI_THEME.CORAL))
	clear_button.add_theme_color_override("font_pressed_color", UI_THEME.color(UI_THEME.CORAL))
	clear_button.pressed.connect(_on_clear_pressed)
	header.add_child(clear_button)
	return header


func _build_chips() -> void:
	for mod in RaceModifiers.ALL:
		var accent: Color = UI_THEME.color(ACCENTS[mod])
		var chip := Button.new()
		chip.toggle_mode = true
		chip.focus_mode = Control.FOCUS_ALL
		# Fixed-width chips that WRAP via the HFlowContainer: EXPAND_FILL
		# chips force-shrunk to one per row at narrow menu widths, shredding
		# their labels (caught in 720p vision QA). Chips now take a fixed
		# minimum and flow 5/4/3-up as space allows.
		# OVERHAUL: 62px chips made the panel 208px tall and pushed the
		# whole menu past 720p; two-line chips at 48px keep hints readable.
		chip.custom_minimum_size = Vector2(150, 48)
		chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		chip.add_theme_stylebox_override("normal", _chip_style(UI_THEME.color(UI_THEME.SURFACE), UI_THEME.color(UI_THEME.TEXT_MUTED, 0.3), 1))
		chip.add_theme_stylebox_override("hover", _chip_style(UI_THEME.color(UI_THEME.SURFACE_HOVER), UI_THEME.color(UI_THEME.TEXT_MUTED, 0.5), 1))
		chip.add_theme_stylebox_override("pressed", _chip_style(Color(accent.r, accent.g, accent.b, 0.12), accent, 2))
		chip.add_theme_stylebox_override("hover_pressed", _chip_style(Color(accent.r, accent.g, accent.b, 0.18), accent, 2))
		chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		chip.tooltip_text = RaceModifiers.LABELS[mod]
		chip.toggled.connect(_on_chip_toggled.bind(mod))
		chip_flow.add_child(chip)
		chips[mod] = chip

		# STACKED layout: name on top, hint underneath. The old side-by-side
		# (88px name + expanding hint) shredded both at 150px chip width
		# (vision QA: mid-word breaks + overlapping labels). Stacking keeps
		# every chip readable down to two-per-row widths.
		var content := VBoxContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 12.0
		content.offset_right = -10.0
		content.offset_top = 5.0
		content.offset_bottom = -5.0
		content.add_theme_constant_override("separation", 1)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(content)

		var name_label := Label.new()
		name_label.name = "NameLabel"
		name_label.text = RaceModifiers.LABELS[mod].split(" — ")[0]
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(name_label)

		var hint_label := Label.new()
		hint_label.name = "HintLabel"
		hint_label.text = HINTS[mod]
		hint_label.add_theme_font_size_override("font_size", 9)
		hint_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
		# Wrap inside the chip — hints stay 1-2 short lines at all widths.
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(hint_label)


func _chip_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


## Re-sync every chip, the summary line, and CLEAR visibility from the
## authoritative RaceModifiers state (call after any external change).
func refresh() -> void:
	var active: Array[String] = []
	for mod in RaceModifiers.ALL:
		var chip: Button = chips.get(mod)
		if chip == null:
			continue
		var on := RaceModifiers.is_active(mod)
		chip.set_pressed_no_signal(on)
		var accent: Color = UI_THEME.color(ACCENTS[mod])
		var name_label: Label = _chip_label(chip, "NameLabel")
		var hint_label: Label = _chip_label(chip, "HintLabel")
		if name_label:
			name_label.add_theme_color_override("font_color", accent.lightened(0.25) if on else UI_THEME.color(UI_THEME.TEXT, 0.86))
		if hint_label:
			hint_label.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.66) if on else UI_THEME.color(UI_THEME.TEXT_MUTED))
		if on:
			active.append(RaceModifiers.LABELS[mod].split(" — ")[0])

	clear_button.visible = not active.is_empty()
	if active.is_empty():
		summary_label.text = CLASSIC_SUMMARY
	elif active.size() == RaceModifiers.ALL.size():
		summary_label.text = FULL_CHAOS_SUMMARY
	elif active.size() == 1:
		summary_label.text = "%s will be in play." % active[0]
	else:
		summary_label.text = "%s will be in play." % " + ".join(active)


func _chip_label(chip: Button, label_name: String) -> Label:
	for child in chip.get_children():
		for sub in child.get_children():
			if sub is Label and sub.name == label_name:
				return sub
	return null


func _on_chip_toggled(on: bool, mod: RaceModifiers.Modifier) -> void:
	# Chips start in sync with RaceModifiers, so a toggle always flips state.
	if on == RaceModifiers.is_active(mod):
		return
	RaceModifiers.toggle(mod)
	RaceModifiers.save_to_cfg()
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("powerup" if on else "wall_bonk", 0.7)
	refresh()


func _on_clear_pressed() -> void:
	for mod in RaceModifiers.ALL:
		if RaceModifiers.is_active(mod):
			RaceModifiers.toggle(mod)
	RaceModifiers.save_to_cfg()
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("wall_bonk", 0.7)
	refresh()
