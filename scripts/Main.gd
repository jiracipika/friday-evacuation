# Main.gd — Friday departure board menu (UI-LAYOUTS.md section 3, Phase 1A).
#
# Left 40%: opaque ink nav column with kicker + brand + stacked actions.
# Right 60%: MenuBackdrop office art + YOUR RIDE hero panel.
# Subviews (OTHER MODES / CUSTOMIZE RIDE / OFFICE SETUP) open as opaque ink
# panels sized exactly over the nav field; the home column hides while one is
# open. Escape pops one layer. No splash on entry; EVACUATE is usable first.
extends Control

const UI_THEME = preload("res://scripts/UITheme.gd")

const MODE_INFO = [
	{
		"title": "Friday 5PM: Evacuation",
		"subtitle": "PRIMARY MODE",
		"desc": "It's 4:59 PM. Race your office chair through the building to the parking lot. Coffee boosts, water traps, stapler sabotage. Last one buys beers.",
		"mode": GameManager.GameMode.EVACUATION,
		"color": Color(1.0, 0.65, 0.1),
	},
	{
		"title": "HAULED",
		"subtitle": "CO-OP PHYSICS DELIVERY",
		"desc": "Delivery of absurd HOSTILE cargo — a fridge full of bees, a haunted sofa — through impossible terrain. Drop it, you owe money.",
		"mode": GameManager.GameMode.HAULED,
		"color": Color(1.0, 0.35, 0.3),
	},
	{
		"title": "SHOP & SEEK",
		"subtitle": "HIDE & SEEK",
		"desc": "Half of you disguise as groceries in a supermarket. The other half are frantic shoppers with a list and 60 seconds. Spot the fake avocado.",
		"mode": GameManager.GameMode.SHOP_SEEK,
		"color": Color(0.3, 0.85, 0.4),
	},
	{
		"title": "PIZZA COLONY",
		"subtitle": "CO-OP SURVIVAL",
		"desc": "You're toppings on a GIANT living pizza. Claim pepperoni territory, dodge the chef's slice-cutter, harvest cheese.",
		"mode": GameManager.GameMode.PIZZA_COLONY,
		"color": Color(1.0, 0.8, 0.2),
	},
]

const MODE_STATUS := ["PLAYABLE", "DELIVERY PLAYABLE", "SHOPPER PLAYABLE", "SURVIVAL PLAYABLE"]

# Signals re-used by the old flow so callers can detect navigation intent.
signal mode_chosen(mode: GameManager.GameMode)

# Public surface kept for tests/other callers.
var selected_index: int = 0
var buttons: Array[Button] = []
var settings_overlay: Control
var lobby_overlay: Control
var credits_overlay: CanvasLayer
var settings_button: Button
var layout_option: OptionButton
var touch_button: Button
var credits_button: Button
var modifier_menu: Control
var character_row: HBoxContainer
var character_select: OptionButton
var character_detail: Label
var skin_row: HBoxContainer
var skin_select: OptionButton
var skin_detail: Label
var stats_label: Label
var menu_time: float = 0.0
var hero_panel: Control
var hero: Control
var backdrop: Control
var nav_grid: GridContainer
var modes_subview: Control
var customize_subview: Control
var office_subview: Control
var open_subview: Control
var last_focused: Control
var _subview_owner: Control
var _block_navigation: bool = false  # test seam: run handlers, skip scene change
# S-PAD: OptionButton pad-cycling — tracks the last OptionButton that gained
# focus so ui_left/ui_right (joypad axis 0 / dpad 7-8) can step its selection.
var _focused_option: OptionButton
var _remap_capture_active := false  # set true while Settings captures raw keys


## S-PAD: Settings remap capture toggles this via set("remap_capture_active").
# Modes subview selected-mode readout (title/description + PLAY SELECTED).
var modes_title_label: Label
var modes_desc_label: Label

# Scene nodes (built in Main.tscn).
@onready var nav_field: ColorRect = $NavField
@onready var scroll: ScrollContainer = $NavField/Scroll
@onready var nav_column: VBoxContainer = $NavField/Scroll/NavColumn
@onready var kicker_label: Label = $NavField/Scroll/NavColumn/Kicker
@onready var brand_label: Label = $NavField/Scroll/NavColumn/Title
@onready var title_label: Label = $NavField/Scroll/NavColumn/Title
@onready var subtitle_label: Label = $NavField/Scroll/NavColumn/Subtitle
@onready var desc_label: Label = $NavField/Scroll/NavColumn/Description
@onready var play_button: Button = $NavField/Scroll/NavColumn/PlayButton
@onready var host_button: Button = $NavField/Scroll/NavColumn/HostButton
@onready var other_modes_button: Button = $NavField/Scroll/NavColumn/OtherModesButton
@onready var customize_button: Button = $NavField/Scroll/NavColumn/CustomizeButton
@onready var office_button: Button = $NavField/Scroll/NavColumn/OfficeButton
@onready var settings_button_node: Button = $NavField/Scroll/NavColumn/SettingsButton
@onready var credits_button_node: Button = $NavField/Scroll/NavColumn/CreditsButton

const LAYOUT_CFG_PATH := "user://settings.cfg"
const TEXT_MUTED := Color("b8b5ae")
const IVORY := Color("f3e7d3")
const ORANGE := Color("ff9a1a")
const INK := Color("0a0a0f")

func _ready() -> void:
	var focus_watch := func(_control: Control) -> void:
		var owner_ctl: Control = get_viewport().gui_get_focus_owner()
		_focused_option = owner_ctl as OptionButton if owner_ctl is OptionButton else null
	get_viewport().gui_focus_changed.connect(focus_watch)
	get_window().title = "Friday 5PM: Evacuation"
	var prefs_boot = load("res://scripts/InputPrefs.gd")
	if prefs_boot and prefs_boot.has_method("refresh_cache"):
		prefs_boot.refresh_cache()
	if "virtual-pad" in OS.get_cmdline_user_args() or OS.get_environment("FE_VIRTUAL_PAD") == "1":
		var vpad = load("res://scripts/VirtualPad.gd")
		if vpad:
			var vpad_node: Node = vpad.new()
			vpad_node.name = "VirtualPad"
			get_tree().root.add_child.call_deferred(vpad_node)

	_build_menu_theme()
	_build_home_column()
	_build_backdrop_and_hero()
	_apply_theme_to_home_actions()
	# Saved office setup must apply on boot, independent of the lazy
	# OFFICE SETUP subview build — a direct EVACUATE honors the saved config.
	var mods_script = load("res://scripts/RaceModifiers.gd")
	if mods_script and mods_script.has_method("load_from_cfg"):
		mods_script.load_from_cfg()
	var saved_layout := _load_saved_layout()
	var layouts_boot = load("res://scripts/LevelLayouts.gd")
	if layouts_boot and layouts_boot.has_method("set_current"):
		layouts_boot.set_current(saved_layout)
	_layout_responsive()

	get_viewport().size_changed.connect(_layout_responsive)

## Ink nav field, ivory brand, orange kicker (UI-LAYOUTS section 1 + 3).
func _build_menu_theme() -> void:
	nav_field.color = INK
	kicker_label.add_theme_color_override("font_color", ORANGE)
	kicker_label.add_theme_font_size_override("font_size", 14)
	brand_label.add_theme_color_override("font_color", IVORY)
	brand_label.add_theme_font_size_override("font_size", 52)
	brand_label.add_theme_constant_override("line_spacing", -6)
	subtitle_label.add_theme_color_override("font_color", Color(UI_THEME.color(UI_THEME.PAPER)))
	desc_label.add_theme_color_override("font_color", TEXT_MUTED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _apply_theme_to_home_actions() -> void:
	UI_THEME.apply_primary(play_button)
	play_button.add_theme_font_size_override("font_size", 28)
	UI_THEME.apply_secondary(host_button, UI_THEME.color(UI_THEME.ORANGE))
	host_button.add_theme_font_size_override("font_size", 18)
	for btn in [other_modes_button, customize_button, office_button,
			settings_button, credits_button]:
		if btn == null:
			continue
		UI_THEME.apply_secondary(btn, UI_THEME.color(UI_THEME.SURFACE))
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT))

func _build_home_column() -> void:
	settings_button = settings_button_node
	credits_button = credits_button_node
	play_button.pressed.connect(_on_play)
	play_button.pressed.connect(_play_click_sound)
	host_button.pressed.connect(_open_lobby)
	other_modes_button.pressed.connect(_open_modes_subview)
	customize_button.pressed.connect(_open_customize_subview)
	office_button.pressed.connect(_open_office_subview)
	settings_button.pressed.connect(_open_settings)
	credits_button.pressed.connect(_open_credits)
	host_button.visible = true
	# Home is a departure board: no dense description copy on entry.
	desc_label.visible = false
	# S-B1 "After Hours" home column: clock subtitle, departures ticker,
	# CTA subline, 2x2 nav grid, version footer (FINAL-SPEC.md section 3).
	subtitle_label.text = "4:59 — one minute to freedom"
	subtitle_label.add_theme_font_size_override("font_size", 20)
	var ticker := _build_departures_ticker()
	var spacer := Control.new()
	spacer.name = "FlexSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav_column.add_child(spacer)
	nav_column.move_child(spacer, ticker.get_index() + 1)
	var subline := Label.new()
	subline.name = "CtaSubline"
	subline.text = "LAST ONE BUYS BEERS"
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subline.add_theme_font_size_override("font_size", 11)
	subline.add_theme_color_override("font_color", Color(UI_THEME.color(UI_THEME.ORANGE_BRIGHT), 0.75))
	nav_column.add_child(subline)
	nav_column.move_child(subline, play_button.get_index() + 1)
	var grid := GridContainer.new()
	grid.name = "NavGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for btn: Button in [host_button, other_modes_button, customize_button,
			office_button]:
		# Buttons are scene children of NavColumn — detach before re-parenting.
		nav_column.remove_child(btn)
		if btn.custom_minimum_size.y < 48.0:
			btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(btn)
	nav_column.add_child(grid)
	nav_column.move_child(grid, subline.get_index() + 1)
	nav_grid = grid
	var version_label := Label.new()
	version_label.name = "VersionLabel"
	version_label.text = "v0.9 · 26 SEP 26"
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", Color("9a9aae"))
	nav_column.add_child(version_label)
	# Single scroll surface; gamepad focus scrolls the list along.
	scroll.follow_focus = true
	# S-PAD: every home-column action is pad-reachable (Button default is
	# FOCUS_ALL already; enforce it so scene edits can never drop nav).
	for btn in [play_button, host_button, other_modes_button, customize_button,
			office_button, settings_button, credits_button]:
		if btn:
			btn.focus_mode = Control.FOCUS_ALL
	play_button.grab_focus()

## DEPARTURES board panel (iter3 board: 3 gate rows + status pills).
func _build_departures_ticker() -> PanelContainer:
	var ticker := PanelContainer.new()
	ticker.name = "DeparturesTicker"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.09)
	ticker.add_theme_stylebox_override("panel", style)
	ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows_box := VBoxContainer.new()
	rows_box.name = "Rows"
	rows_box.add_theme_constant_override("separation", 4)
	rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticker.add_child(rows_box)
	var header := HBoxContainer.new()
	header.name = "TickerHeader"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := Label.new()
	head.text = "DEPARTURES"
	head.add_theme_font_size_override("font_size", 11)
	head.add_theme_color_override("font_color", ORANGE)
	header.add_child(head)
	var head_spacer := Control.new()
	head_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(head_spacer)
	var floors := Label.new()
	floors.text = "ALL FLOORS"
	floors.add_theme_font_size_override("font_size", 11)
	floors.add_theme_color_override("font_color", Color("9a9aae"))
	header.add_child(floors)
	rows_box.add_child(header)
	var yellow := Color("f2c230")
	var lime := Color("b9f34a")
	var data := [
		["GATE A", "PARKING LOT", "BOARDING"],
		["GATE B", "PATIO · BEERS", "ON TIME"],
		["GATE C", "HOME", "DELAYED"],
	]
	for i in range(data.size()):
		var row := HBoxContainer.new()
		row.name = "GateRow%d" % (i + 1)
		row.custom_minimum_size = Vector2(0, 30)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		var gate := Label.new()
		gate.name = "Gate"
		gate.text = data[i][0]
		gate.custom_minimum_size.x = 88
		gate.add_theme_font_size_override("font_size", 13)
		gate.add_theme_color_override("font_color", yellow)
		row.add_child(gate)
		var dest := Label.new()
		dest.name = "Dest"
		dest.text = data[i][1]
		dest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dest.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		dest.add_theme_font_size_override("font_size", 13)
		dest.add_theme_color_override("font_color", Color("f7f6f2"))
		row.add_child(dest)
		var pill := PanelContainer.new()
		pill.name = "Status"
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pill_style := StyleBoxFlat.new()
		pill_style.set_corner_radius_all(999)
		pill_style.content_margin_left = 8.0
		pill_style.content_margin_right = 8.0
		pill_style.content_margin_top = 4.0
		pill_style.content_margin_bottom = 4.0
		var status := Label.new()
		status.text = data[i][2]
		status.add_theme_font_size_override("font_size", 11)
		match data[i][2]:
			"BOARDING":
				pill_style.bg_color = ORANGE
				status.add_theme_color_override("font_color", Color("231303"))
			"ON TIME":
				pill_style.draw_center = false
				pill_style.set_border_width_all(1)
				pill_style.border_color = lime
				status.add_theme_color_override("font_color", lime)
			"DELAYED":
				pill_style.draw_center = false
				pill_style.set_border_width_all(1)
				pill_style.border_color = Color(yellow.r, yellow.g, yellow.b, 0.55)
				status.add_theme_color_override("font_color", yellow)
		pill.add_theme_stylebox_override("panel", pill_style)
		pill.add_child(status)
		row.add_child(pill)
		rows_box.add_child(row)
	nav_column.add_child(ticker)
	nav_column.move_child(ticker, subtitle_label.get_index() + 1)
	return ticker

## Backdrop + YOUR RIDE hero panel in the right field (existing components).
func _build_backdrop_and_hero() -> void:
	backdrop = Control.new()
	backdrop.set_script(load("res://scripts/MenuBackdrop.gd"))
	backdrop.name = "MenuBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	$BG.add_child(backdrop)

	hero_panel = PanelContainer.new()
	hero_panel.name = "HeroPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.055, 0.09, 1.0)  # opaque, no purple wash
	style.border_color = Color(1.0, 0.60, 0.22, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	hero_panel.add_theme_stylebox_override("panel", style)
	# Top-right ANCHORS with fixed offsets: the card tracks the right edge and
	# can never land offscreen at any window size (no absolute positions).
	hero_panel.anchor_left = 1.0
	hero_panel.anchor_right = 1.0
	hero_panel.anchor_top = 0.0
	hero_panel.anchor_bottom = 0.0
	hero_panel.offset_left = -376.0   # 340 wide
	hero_panel.offset_right = -36.0
	hero_panel.offset_top = 36.0      # 140 tall
	hero_panel.offset_bottom = 176.0
	var hero_vb := VBoxContainer.new()
	hero_vb.add_theme_constant_override("separation", 10)
	hero_panel.add_child(hero_vb)
	var hero_title := Label.new()
	hero_title.text = "YOUR RIDE"
	hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_title.add_theme_font_size_override("font_size", 15)
	hero_title.add_theme_color_override("font_color", Color(1.0, 0.60, 0.22))
	hero_vb.add_child(hero_title)
	var hero_script = load("res://scripts/MenuHero.gd")
	if hero_script:
		hero = hero_script.new()
		hero_vb.add_child(hero)
	var hero_hint := Label.new()
	hero_hint.text = "Rider & chair update live"
	hero_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_hint.add_theme_font_size_override("font_size", 11)
	hero_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hero_vb.add_child(hero_hint)
	add_child(hero_panel)

# --- departure board home actions -------------------------------------------

## The main CTA always launches Evacuation (mode cards no longer own PLAY).
func _on_play() -> void:
	selected_index = 0
	GameManager.select_mode(GameManager.GameMode.EVACUATION)
	mode_chosen.emit(GameManager.GameMode.EVACUATION)
	if _block_navigation:
		return
	var scene_path = GameManager.get_mode_scene(GameManager.GameMode.EVACUATION)
	var loading = load("res://scripts/LoadingScreen.gd")
	if loading:
		loading.show_loading(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

func _open_modes_subview() -> void:
	if modes_subview == null:
		_build_modes_subview()
	_show_subview(modes_subview, other_modes_button)

func _open_customize_subview() -> void:
	if customize_subview == null:
		_build_customize_subview()
	_show_subview(customize_subview, customize_button)

func _open_office_subview() -> void:
	if office_subview == null:
		_build_office_subview()
	_show_subview(office_subview, office_button)

func _show_subview(sub: Control, opener: Button) -> void:
	_subview_owner = opener
	last_focused = get_viewport().gui_get_focus_owner()
	# Home column hides; the subview paints its own opaque ink field sized
	# exactly over the nav width (no content floating on the art).
	scroll.visible = false
	_sync_subview_field(sub)
	sub.visible = true
	open_subview = sub
	_focus_subview.call_deferred(sub)

func _close_subview() -> void:
	if open_subview == null:
		return
	open_subview.visible = false
	open_subview = null
	scroll.visible = true
	if _subview_owner and is_instance_valid(_subview_owner):
		_subview_owner.grab_focus()
	_subview_owner = null

## Focus entry point: the actual first focusable child Button of the subview
## content (or the BACK button if the content list is empty). No external
## subview wrapper script is involved.
func _focus_subview(sub_wrap: Control) -> void:
	if open_subview != sub_wrap or not is_instance_valid(sub_wrap):
		return
	var list: Node = sub_wrap.get_meta("focus_list") if sub_wrap.has_meta("focus_list") else null
	if list:
		for node in list.find_children("*", "Button", true, false):
			var btn := node as Button
			if btn and btn.is_visible_in_tree() and btn.focus_mode != Control.FOCUS_NONE:
				btn.call_deferred("grab_focus")
				return
	var back: Button = sub_wrap.get_meta("back_button") if sub_wrap.has_meta("back_button") else null
	if back and is_instance_valid(back):
		back.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	# S-PAD: joypad B (button 1) mirrors ui_cancel on the menu layers; pad
	# Start (button 6) also closes a subview for one-press dismissal.
	var joy := event as InputEventJoypadButton
	var pad_cancel: bool = joy != null and joy.pressed and joy.button_index == JOY_BUTTON_B
	var pad_start: bool = joy != null and joy.pressed and joy.button_index == JOY_BUTTON_START
	if event.is_action_pressed("ui_cancel") or pad_cancel or (pad_start and open_subview != null):
		if open_subview:
			_close_subview()
			get_viewport().set_input_as_handled()
			return
	# S-PAD: focused OptionButton + ui_left/ui_right (keyboard OR joypad
	# axis 0 / dpad) cycles the selection — Godot doesn't do this natively.
	if _remap_capture_active or _focused_option == null \
			or not is_instance_valid(_focused_option):
		return
	var step := 0
	if event.is_action_pressed("ui_right"):
		step = 1
	elif event.is_action_pressed("ui_left"):
		step = -1
	else:
		return
	var ob := _focused_option
	var idx := ob.selected
	var count := ob.item_count
	for _i in range(count):
		idx = wrapi(idx + step, 0, count)
		if not ob.is_item_disabled(idx):
			break
	if idx != ob.selected:
		ob.select(idx)
		ob.item_selected.emit(idx)
	get_viewport().set_input_as_handled()

func _build_modes_subview() -> void:
	modes_subview = _subview_shell("MODES", _build_mode_rows)

## Mode cards + selected readout + PLAY SELECTED. The card buttons select;
## the pinned PLAY SELECTED button launches the selected mode.
func _build_mode_rows(list: VBoxContainer, play_out: Array, _back_out: Array) -> Control:
	var card_script = load("res://scripts/ModeCard.gd")
	for i in range(MODE_INFO.size()):
		var info = MODE_INFO[i]
		var btn = Button.new()
		if card_script:
			btn.set_script(card_script)
			btn.configure(info.title, info.subtitle, MODE_STATUS[i], info.color, i == 0)
			btn.custom_minimum_size = Vector2(0, 84 if i == 0 else 56)
		else:
			btn.custom_minimum_size = Vector2(0, 56)
		btn.text = info.title
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(_select_mode.bind(i))
		list.add_child(btn)
		buttons.append(btn)

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	modes_title_label = Label.new()
	modes_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modes_title_label.add_theme_font_size_override("font_size", 16)
	modes_title_label.add_theme_color_override("font_color", IVORY)
	footer.add_child(modes_title_label)
	modes_desc_label = Label.new()
	modes_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modes_desc_label.custom_minimum_size = Vector2(0, 44)
	modes_desc_label.add_theme_font_size_override("font_size", 14)
	modes_desc_label.add_theme_color_override("font_color", TEXT_MUTED)
	footer.add_child(modes_desc_label)
	var play_selected := Button.new()
	play_selected.text = "PLAY SELECTED"
	play_selected.custom_minimum_size = Vector2(0, 52)
	play_selected.focus_mode = Control.FOCUS_ALL
	play_selected.add_theme_font_size_override("font_size", 20)
	UI_THEME.apply_primary(play_selected)
	play_selected.pressed.connect(_play_selected_mode)
	play_selected.pressed.connect(_play_click_sound)
	footer.add_child(play_selected)
	play_out.append(play_selected)
	_select_mode(selected_index)
	return footer

func _build_customize_subview() -> void:
	customize_subview = _subview_shell("RIDE", _build_ride_rows)

func _build_ride_rows(list: VBoxContainer, _play_out: Array, _back_out: Array) -> void:
	_build_character_selector(list)
	_build_skin_selector(list)

func _build_office_subview() -> void:
	office_subview = _subview_shell("OFFICE", _build_office_rows)

func _build_office_rows(list: VBoxContainer, _play_out: Array, _back_out: Array) -> void:
	var menu_script = load("res://scripts/ModifierMenu.gd")
	if menu_script:
		var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
		if RaceModifiersScript:
			RaceModifiersScript.load_from_cfg()
		# ModifierMenu.mount(parent, above_node) moves the menu to
		# above_node.get_index() INSIDE parent — pass a real child anchor of
		# the list, never the list itself (its index belongs to another
		# parent, producing an invalid move_child index).
		var anchor := Control.new()
		anchor.name = "MenuAnchor"
		list.add_child(anchor)
		modifier_menu = menu_script.mount(list, anchor)
		modifier_menu.visible = true

	var label := Label.new()
	label.text = "MAP"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", TEXT_MUTED)
	list.add_child(label)
	layout_option = OptionButton.new()
	FridayUITheme.style_option_button(layout_option)
	layout_option.add_item("MAP: OPEN PLAN", 0)
	layout_option.add_item("MAP: CUBICLE MAZE", 1)
	layout_option.add_item("MAP: EXECUTIVE", 2)
	layout_option.custom_minimum_size = Vector2(0, 48)
	layout_option.add_theme_font_size_override("font_size", 14)
	layout_option.fit_to_longest_item = false
	layout_option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.add_child(layout_option)
	var saved_layout := str(_load_saved_layout())
	layout_option.select({"open_plan": 0, "cubicle_maze": 1, "executive": 2}.get(saved_layout, 0))
	layout_option.item_selected.connect(_on_layout_selected)
	var LayoutsScript = load("res://scripts/LevelLayouts.gd")
	if LayoutsScript and LayoutsScript.has_method("set_current"):
		LayoutsScript.set_current(saved_layout)

	touch_button = Button.new()
	touch_button.custom_minimum_size = Vector2(0, 48)
	touch_button.add_theme_font_size_override("font_size", 14)
	UI_THEME.apply_utility(touch_button, UI_THEME.color(UI_THEME.ORANGE))
	list.add_child(touch_button)
	var prefs_touch = load("res://scripts/InputPrefs.gd")
	var touch_pref := "auto"
	if prefs_touch and prefs_touch.has_method("touch_mode"):
		touch_pref = prefs_touch.touch_mode()
	touch_button.text = _touch_button_label(touch_pref)
	touch_button.pressed.connect(_on_touch_button)

## Shared subview scaffold: opaque ink field over the nav width, header with
## pinned BACK, scrollable content, plus an optional builder footer (the
## modes subview's selected readout + PLAY SELECTED). No missing scripts:
## focus entry is handled by Main._focus_subview via real child Buttons.
func _subview_shell(title_text: String, builder: Callable) -> Control:
	var wrap := Control.new()
	wrap.name = "%sSubview" % title_text
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	var field := ColorRect.new()
	field.name = "Field"
	field.color = INK
	field.anchor_left = 0.0
	field.anchor_top = 0.0
	field.anchor_bottom = 1.0
	field.anchor_right = 0.4
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.add_child(field)
	var sub := VBoxContainer.new()
	sub.name = "Content"
	sub.anchor_left = 0.0
	sub.anchor_top = 0.0
	sub.anchor_bottom = 1.0
	sub.anchor_right = 1.0
	sub.offset_left = 24.0
	sub.offset_right = -24.0
	sub.offset_top = 24.0
	sub.offset_bottom = -16.0
	sub.add_theme_constant_override("separation", 10)
	field.add_child(sub)
	var back_holder: Array = []
	var play_holder: Array = []
	var header := HBoxContainer.new()
	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", IVORY)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(heading)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 48)
	back.add_theme_font_size_override("font_size", 16)
	back.focus_mode = Control.FOCUS_ALL  # S-PAD: BACK is pad-reachable
	back.pressed.connect(_close_subview)
	header.add_child(back)
	sub.add_child(header)
	var scroll_sub := ScrollContainer.new()
	scroll_sub.name = "ScrollSub"
	scroll_sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_sub.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_sub.follow_focus = true
	sub.add_child(scroll_sub)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll_sub.add_child(list)
	var footer: Control = builder.call(list, play_holder, back_holder)
	if footer is Control:
		sub.add_child(footer)
	wrap.visible = false
	add_child(wrap)
	wrap.set_meta("play_button", play_holder[0] if not play_holder.is_empty() else back)
	wrap.set_meta("back_button", back)
	wrap.set_meta("focus_list", list)
	return wrap

func _sync_subview_field(sub: Control) -> void:
	var field: Control = sub.get_node_or_null("Field")
	if field:
		field.anchor_right = _nav_frac

# --- modes subview play routing ---------------------------------------------

func _select_mode(idx: int) -> void:
	selected_index = clampi(idx, 0, MODE_INFO.size() - 1)
	var info = MODE_INFO[selected_index]
	# Selected style on the actual card buttons (ModeCard.set_selected or a
	# dim fallback), plus the visible selected readout inside the subview.
	for i in range(buttons.size()):
		var card = buttons[i]
		if card == null or not is_instance_valid(card):
			continue
		if card.has_method("set_selected"):
			card.set_selected(i == selected_index)
		else:
			card.modulate = Color(1, 1, 1, 1.0 if i == selected_index else 0.55)
	if modes_title_label:
		modes_title_label.text = "%s — %s" % [info.title.to_upper(), info.subtitle]
	if modes_desc_label:
		modes_desc_label.text = info.desc

## Play the currently selected mode from the OTHER MODES subview.
func _play_selected_mode() -> void:
	var mode: GameManager.GameMode = MODE_INFO[selected_index].mode
	GameManager.select_mode(mode)
	mode_chosen.emit(mode)
	if _block_navigation:
		return
	var scene_path = GameManager.get_mode_scene(mode)
	var loading = load("res://scripts/LoadingScreen.gd")
	if loading:
		loading.show_loading(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

func _play_click_sound() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("powerup", 0.9)

# --- rider / chair selectors (existing persistence paths) --------------------

func _build_character_selector(parent: Control) -> void:
	var roster = load("res://scripts/CharacterRoster.gd")
	if not roster:
		return
	# Stacked layout: label + OptionButton in the row, the tagline BELOW the
	# row (an HBox with a long expanding detail made the min width huge).
	character_row = HBoxContainer.new()
	character_row.name = "CharacterSelector"
	character_row.custom_minimum_size = Vector2(0, 48)
	character_row.add_theme_constant_override("separation", 10)
	parent.add_child(character_row)
	var label := Label.new()
	label.text = "RIDER"
	label.custom_minimum_size.x = 62
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	character_row.add_child(label)
	character_select = OptionButton.new()
	FridayUITheme.style_option_button(character_select)
	character_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_select.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	character_select.custom_minimum_size = Vector2(0, 48)
	character_select.add_theme_font_size_override("font_size", 14)
	character_select.fit_to_longest_item = false
	character_select.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	character_row.add_child(character_select)
	character_detail = Label.new()
	character_detail.custom_minimum_size = Vector2(0, 44)
	character_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_detail.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	character_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	character_detail.add_theme_font_size_override("font_size", 14)
	character_detail.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	parent.add_child(character_detail)
	var selected := 0
	var characters: Array[Dictionary] = roster.all()
	var short_items := _is_narrow()
	for i in range(characters.size()):
		var character: Dictionary = characters[i]
		if short_items:
			character_select.add_item(String(character["name"]))
		else:
			character_select.add_item("%s — %s" % [character["name"], character["role"]])
		character_select.set_item_metadata(i, character["id"])
		if character["id"] == GameManager.selected_character_id:
			selected = i
	character_select.select(selected)
	character_select.item_selected.connect(_on_character_selected)
	_on_character_selected(selected)

func _on_character_selected(index: int) -> void:
	var roster = load("res://scripts/CharacterRoster.gd")
	if not roster or not character_select:
		return
	var character_id := String(character_select.get_item_metadata(index))
	var character: Dictionary = roster.get_character(character_id)
	GameManager.selected_character_id = character_id
	GameManager.player_color = Color.from_string(character["body"], GameManager.player_color)
	GameManager.save_identity()
	_refresh_hero()
	if character_detail:
		character_detail.text = character["tagline"]
		character_detail.tooltip_text = "%s • %s" % [character["silhouette"], character["accessory"]]

func _build_skin_selector(parent: Control) -> void:
	var skins = load("res://scripts/ChairSkins.gd")
	if not skins:
		return
	var stats = get_node_or_null("/root/StatsManager")
	var wins: int = stats.races_won if stats else 0

	skin_row = HBoxContainer.new()
	skin_row.name = "SkinSelector"
	skin_row.custom_minimum_size = Vector2(0, 48)
	skin_row.add_theme_constant_override("separation", 10)
	parent.add_child(skin_row)
	var label := Label.new()
	label.text = "CHAIR"
	label.custom_minimum_size.x = 62
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	skin_row.add_child(label)
	skin_select = OptionButton.new()
	FridayUITheme.style_option_button(skin_select)
	skin_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_select.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skin_select.custom_minimum_size = Vector2(0, 48)
	skin_select.add_theme_font_size_override("font_size", 14)
	skin_select.fit_to_longest_item = false
	skin_select.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	skin_row.add_child(skin_select)
	skin_detail = Label.new()
	skin_detail.custom_minimum_size = Vector2(0, 44)
	skin_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skin_detail.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	skin_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skin_detail.add_theme_font_size_override("font_size", 14)
	skin_detail.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	parent.add_child(skin_detail)

	var all_skins: Array[Dictionary] = skins.all()
	var selected := 0
	for i in range(all_skins.size()):
		var skin: Dictionary = all_skins[i]
		var id := String(skin["id"])
		var unlocked: bool = skins.is_unlocked(id, wins)
		if unlocked:
			skin_select.add_item(String(skin["name"]))
			skin_select.set_item_metadata(skin_select.item_count - 1, id)
			if id == GameManager.selected_skin_id:
				selected = skin_select.item_count - 1
		else:
			var need := int(skin["unlock_wins"])
			if _is_narrow():
				skin_select.add_item("%s 🔒%d" % [skin["name"], need])
			else:
				skin_select.add_item("%s  —  LOCKED (win %d)" % [skin["name"], need])
			skin_select.set_item_metadata(skin_select.item_count - 1, "")
			skin_select.set_item_disabled(skin_select.item_count - 1, true)
			if id == GameManager.selected_skin_id:
				selected = 0
	var _next = skins.next_unlock(wins)
	if _next.is_empty():
		skin_detail.text = "ALL CHAIRS UNLOCKED — flex accordingly."
	else:
		skin_detail.text = "%d/%d WINS → %s" % [_next["progress"], _next["unlock_wins"], _next["name"]]
	if skin_select.item_count > 0:
		skin_select.select(selected)
	skin_select.item_selected.connect(_on_skin_selected)
	_on_skin_selected(selected)

func _on_skin_selected(index: int) -> void:
	var skins = load("res://scripts/ChairSkins.gd")
	if not skins or not skin_select:
		return
	var id := String(skin_select.get_item_metadata(index))
	if id == "":
		return
	var skin: Dictionary = skins.get_skin(id)
	GameManager.selected_skin_id = id
	GameManager.save_identity()
	_refresh_hero()
	if skin_detail:
		var stats = get_node_or_null("/root/StatsManager")
		var wins: int = stats.races_won if stats else 0
		var mods := "JUMP x%.2f  GRIP x%.2f  BOOST x%.2f" % [
			float(skin["jump_mult"]), float(skin["friction_mult"]), float(skin["boost_mult"])
		]
		skin_detail.text = "%s — %s" % [skin["tagline"], mods]
		var _next = skins.next_unlock(wins)
		if not _next.is_empty():
			skin_detail.tooltip_text = "next unlock: %s at %d wins (you have %d)" % [
				_next["name"], _next["unlock_wins"], wins
			]
		else:
			skin_detail.tooltip_text = "everything unlocked"

func _refresh_hero() -> void:
	if hero and hero.has_method("refresh_for_pick"):
		hero.refresh_for_pick()

# --- office setup persistence (existing paths) --------------------------------

func _load_saved_layout() -> String:
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_CFG_PATH)
	return str(cfg.get_value("game", "map_layout", "open_plan"))

func _on_layout_selected(index: int) -> void:
	var names := ["open_plan", "cubicle_maze", "executive"]
	var picked: String = names[clampi(index, 0, 2)]
	var LevelLayouts = load("res://scripts/LevelLayouts.gd")
	if LevelLayouts and LevelLayouts.has_method("set_current"):
		LevelLayouts.set_current(picked)
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_CFG_PATH)
	cfg.set_value("game", "map_layout", picked)
	cfg.save(LAYOUT_CFG_PATH)
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("ui_click", 1.0)

func _touch_button_label(mode: String) -> String:
	var prefs = load("res://scripts/InputPrefs.gd")
	var short := _is_narrow()
	match mode:
		"on":
			return "TOUCH ON" if short else "TOUCH: ON"
		"off":
			return "TOUCH OFF" if short else "TOUCH: OFF"
		_:
			var resolved := false
			if prefs and prefs.has_method("touch_enabled"):
				resolved = prefs.touch_enabled()
			if short:
				return "TOUCH AUTO (%s)" % ("ON" if resolved else "OFF")
			return "TOUCH: AUTO (%s)" % ("ON" if resolved else "OFF")

func _on_touch_button() -> void:
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs == null or not prefs.has_method("touch_mode"):
		return
	var order := ["auto", "on", "off"]
	var current: String = prefs.touch_mode()
	var next: String = order[(order.find(current) + 1) % order.size()]
	prefs.set_touch_mode(next)
	touch_button.text = _touch_button_label(next)
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("ui_click", 1.0)

# --- overlays ------------------------------------------------------------------

func _open_credits() -> void:
	# Dedupe: one credits layer at a time; restore focus on close.
	if credits_overlay != null and is_instance_valid(credits_overlay):
		return
	var script = load("res://scripts/CreditsScreen.gd")
	if script == null:
		return
	credits_overlay = CanvasLayer.new()
	credits_overlay.name = "CreditsOverlay"
	credits_overlay.set_script(script)
	add_child(credits_overlay)
	if credits_overlay.has_signal("closed"):
		credits_overlay.closed.connect(_on_credits_closed)

func _on_credits_closed() -> void:
	credits_overlay = null
	if credits_button and is_instance_valid(credits_button):
		credits_button.grab_focus()

func _open_settings() -> void:
	if settings_overlay and is_instance_valid(settings_overlay):
		return
	var script = load("res://scripts/Settings.gd")
	settings_overlay = Control.new()
	settings_overlay.set_script(script)
	add_child(settings_overlay)
	settings_overlay.closed.connect(func():
		settings_overlay = null
		if settings_button and is_instance_valid(settings_button):
			settings_button.grab_focus()
	)

func _open_lobby() -> void:
	if lobby_overlay and is_instance_valid(lobby_overlay):
		return
	var script = load("res://scripts/Lobby.gd")
	if not script:
		return
	lobby_overlay = Control.new()
	lobby_overlay.set_script(script)
	add_child(lobby_overlay)
	lobby_overlay.close_requested.connect(func():
		lobby_overlay.queue_free()
		lobby_overlay = null
		if host_button and is_instance_valid(host_button):
			host_button.grab_focus()
	)

# --- responsive layout ---------------------------------------------------------

var _nav_frac: float = 0.4

func _process(delta: float) -> void:
	menu_time += delta
	# Kicker blink dot: whole label pulses 1.0 -> 0.55 -> 1.0 over 1.6s.
	if kicker_label:
		var t := fmod(menu_time, 1.6) / 1.6
		kicker_label.modulate.a = 1.0 - 0.45 * sin(PI * t)

func _layout_responsive() -> void:
	if nav_field == null:
		return
	var w := get_viewport_rect().size.x
	var h := get_viewport_rect().size.y
	# Margins: 16px under 1080 (keeps 960 legible), 32px on desktop.
	var margin := 16.0 if w < 1080.0 else 32.0
	# Field width: exactly 40% at >= 960 (512 at 1280), FULL viewport minus
	# margins below 960 (no 56% rule — the compact nav owns the screen).
	var field_w := w * 0.4 if w >= 960.0 else w - margin * 2.0
	_nav_frac = field_w / w
	nav_field.anchor_right = _nav_frac
	# Top brand sits at y=40; the column scrolls the rest of the height.
	scroll.offset_left = margin
	scroll.offset_right = -margin
	scroll.offset_top = 40.0
	scroll.offset_bottom = -16.0
	# Hero preview: desktop-only (>= 1080), anchored inside the right field.
	if hero_panel:
		hero_panel.visible = w >= 1080.0
	for sub in [modes_subview, customize_subview, office_subview]:
		if sub and is_instance_valid(sub):
			_sync_subview_field(sub)
	# S-B1 responsive: the 2x2 nav grid exceeds portrait width — collapse
	# to one column under 560px and slim the ticker gate column.
	if nav_grid:
		nav_grid.columns = 1 if w < 560.0 else 2
	if w < 560.0:
		var ticker_ref := nav_column.get_node_or_null("Scroll/NavColumn/DeparturesTicker")
		if ticker_ref == null:
			ticker_ref = nav_column.get_node_or_null("DeparturesTicker")
		if ticker_ref:
			for row in ticker_ref.find_children("GateRow*", "HBoxContainer", true, false):
				var gate: Label = row.get_node_or_null("Gate")
				if gate:
					gate.custom_minimum_size.x = 64

func _is_narrow() -> bool:
	return get_viewport_rect().size.x < 560.0
