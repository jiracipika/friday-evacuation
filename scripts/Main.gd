# Main.gd — Main menu / mode select screen
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

var selected_index: int = 0
var buttons: Array[Button] = []
var settings_overlay: Control
var lobby_overlay: Control
var settings_button: Button
var layout_option: OptionButton
var touch_button: Button
var credits_button: Button
var utility_row: Container
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
var tagline_scrim: Control

# UI nodes
@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var desc_label: Label = $VBox/Description
@onready var mode_list: VBoxContainer = $VBox/ModeListScroll/ModeList
@onready var play_button: Button = $VBox/PlayButton
@onready var host_button: Button = $VBox/HostButton
@onready var join_button: Button = $VBox/JoinButton
@onready var back_button: Button = $VBox/BackButton

func _ready() -> void:
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
	_build_mode_buttons()
	_select_mode(0)
	_build_hero_panel()
	_build_character_selector()
	_build_skin_selector()

	play_button.pressed.connect(_on_play)
	play_button.pressed.connect(_play_click_sound)
	_build_modifier_row()
	# D3 regroup order: mode cards > RIDER/CHAIR > TODAY'S OFFICE CHAOS > PLAY > MULTIPLAYER.
	# Build order produces: mode list, char_row, skin_row, modifier_menu, play, host, utility, stats.
	# That matches the spec — char/skin rows were moved before play in their build functions.

	# Utility row — D2: utility buttons use apply_utility() for hover + focus.
	if _is_narrow():
		utility_row = HFlowContainer.new()
	else:
		utility_row = HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 8)
	$VBox.add_child(utility_row)
	settings_button = Button.new()
	settings_button.text = "SETTINGS"
	settings_button.custom_minimum_size = Vector2(0, 28)
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.add_theme_font_size_override("font_size", 12)
	UI_THEME.apply_utility(settings_button, UI_THEME.color(UI_THEME.CYAN))
	utility_row.add_child(settings_button)
	settings_button.pressed.connect(_open_settings)
	credits_button = Button.new()
	credits_button.text = "CREDITS"
	credits_button.custom_minimum_size = Vector2(0, 28)
	credits_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_button.add_theme_font_size_override("font_size", 12)
	UI_THEME.apply_utility(credits_button, UI_THEME.color(UI_THEME.VIOLET))
	utility_row.add_child(credits_button)
	credits_button.pressed.connect(_open_credits)
	layout_option = OptionButton.new()
	var narrow := _is_narrow()
	layout_option.add_item("MAP: OPEN PLAN" if not narrow else "OPEN PLAN", 0)
	layout_option.add_item("MAP: CUBICLE MAZE" if not narrow else "CUBICLES", 1)
	layout_option.add_item("MAP: EXECUTIVE" if not narrow else "EXECUTIVE", 2)
	layout_option.custom_minimum_size = Vector2(0, 28)
	layout_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_option.add_theme_font_size_override("font_size", 12)
	utility_row.add_child(layout_option)
	var saved_layout := str(_load_saved_layout())
	layout_option.select({"open_plan": 0, "cubicle_maze": 1, "executive": 2}.get(saved_layout, 0))
	layout_option.item_selected.connect(_on_layout_selected)
	var LayoutsScript = load("res://scripts/LevelLayouts.gd")
	if LayoutsScript:
		LayoutsScript.set_current(saved_layout)
	touch_button = Button.new()
	touch_button.custom_minimum_size = Vector2(0, 28)
	touch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	touch_button.add_theme_font_size_override("font_size", 12)
	UI_THEME.apply_utility(touch_button, UI_THEME.color(UI_THEME.ORANGE))
	utility_row.add_child(touch_button)
	var prefs_touch = load("res://scripts/InputPrefs.gd")
	var touch_pref := "auto"
	if prefs_touch and prefs_touch.has_method("touch_mode"):
		touch_pref = prefs_touch.touch_mode()
	touch_button.text = _touch_button_label(touch_pref)
	touch_button.pressed.connect(_on_touch_button)
	stats_label = Label.new()
	stats_label.text = ""
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	$VBox.add_child(stats_label)
	_register_small_label(stats_label)
	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		stats_label.text = stats.get_summary_line()
		stats.stats_updated.connect(func(): stats_label.text = stats.get_summary_line())
	_build_menu_theme()
	host_button.visible = true
	host_button.text = "MULTIPLAYER"
	host_button.pressed.connect(_open_lobby)
	join_button.visible = false
	back_button.visible = false
	var splash = load("res://scripts/SplashScreen.gd")
	if splash and splash.has_method("mount"):
		splash.mount(self)

func _build_mode_buttons() -> void:
	for i in range(MODE_INFO.size()):
		var info = MODE_INFO[i]
		var btn = Button.new()
		var card_script = load("res://scripts/ModeCard.gd")
		btn.set_script(card_script)
		var is_hero := (i == 0)
		btn.configure(info.title, info.subtitle, MODE_STATUS[i], info.color, is_hero)
		# D2: hero card 84px min height; others 56px.
		btn.custom_minimum_size = Vector2(0, 84 if is_hero else 56)
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(_select_mode.bind(i))
		mode_list.add_child(btn)
		buttons.append(btn)

## HERO PANEL: D2 — YOUR RIDE panel in right column grid (340px), shares
## vertical rhythm with mode list; not a floating card. Hidden <1080px.
func _build_hero_panel() -> void:
	backdrop = Control.new()
	backdrop.set_script(load("res://scripts/MenuBackdrop.gd"))
	backdrop.name = "MenuBackdrop"
	get_node("BG").add_child(backdrop)

	hero_panel = PanelContainer.new()
	hero_panel.name = "HeroPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.055, 0.09, 0.92)
	style.border_color = Color(1.0, 0.60, 0.22, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	hero_panel.add_theme_stylebox_override("panel", style)
	hero_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	hero_panel.anchor_left = 0.70
	hero_panel.offset_left = 12
	hero_panel.offset_top = 10
	hero_panel.offset_right = -12
	hero_panel.offset_bottom = -10
	# D2: 340px right column.
	hero_panel.custom_minimum_size = Vector2(340, 0)
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

func _refresh_hero() -> void:
	if hero and hero.has_method("refresh_for_pick"):
		hero.refresh_for_pick()

func _build_modifier_row() -> void:
	var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
	if not RaceModifiersScript:
		return
	RaceModifiersScript.load_from_cfg()
	var menu_script = load("res://scripts/ModifierMenu.gd")
	if not menu_script:
		return
	modifier_menu = menu_script.mount($VBox, play_button)
	modifier_menu.visible = selected_index == 0

func _build_character_selector() -> void:
	var roster = load("res://scripts/CharacterRoster.gd")
	if not roster:
		return
	character_row = HBoxContainer.new()
	character_row.name = "CharacterSelector"
	character_row.custom_minimum_size = Vector2(0, 30)
	character_row.add_theme_constant_override("separation", 10)
	$VBox.add_child(character_row)
	$VBox.move_child(character_row, play_button.get_index())
	var label := Label.new()
	label.text = "RIDER"
	label.custom_minimum_size.x = 62
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	character_row.add_child(label)
	character_select = OptionButton.new()
	character_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_select.add_theme_font_size_override("font_size", 14)
	character_row.add_child(character_select)
	character_detail = Label.new()
	# D3: detail labels autowrap, min height 44px — no clip_text/ellipsis.
	character_detail.custom_minimum_size = Vector2(0, 44)
	character_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_detail.clip_text = false
	character_detail.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	character_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	character_detail.add_theme_font_size_override("font_size", 11)
	character_detail.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	character_row.add_child(character_detail)
	_register_detail_label(character_detail)
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

func _build_skin_selector() -> void:
	var skins = load("res://scripts/ChairSkins.gd")
	if not skins:
		return
	var stats = get_node_or_null("/root/StatsManager")
	var wins: int = stats.races_won if stats else 0

	skin_row = HBoxContainer.new()
	skin_row.name = "SkinSelector"
	skin_row.custom_minimum_size = Vector2(0, 28)
	skin_row.add_theme_constant_override("separation", 10)
	$VBox.add_child(skin_row)
	$VBox.move_child(skin_row, character_row.get_index() + 1)

	var label := Label.new()
	label.text = "CHAIR"
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	skin_row.add_child(label)

	skin_select = OptionButton.new()
	skin_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_select.add_theme_font_size_override("font_size", 14)
	skin_row.add_child(skin_select)

	skin_detail = Label.new()
	# D3: detail labels autowrap, min height 44px — no clip_text/ellipsis.
	skin_detail.custom_minimum_size = Vector2(0, 44)
	skin_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skin_detail.clip_text = false
	skin_detail.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	skin_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skin_detail.add_theme_font_size_override("font_size", 11)
	skin_detail.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	skin_row.add_child(skin_detail)
	_register_detail_label(skin_detail)

	var all_skins: Array[Dictionary] = skins.all()
	var selected := 0
	var locked_count := 0
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
			locked_count += 1
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

func _select_mode(idx: int) -> void:
	selected_index = idx
	var info = MODE_INFO[idx]
	subtitle_label.text = "%s — %s" % [info.subtitle, info.title.to_upper()]
	subtitle_label.modulate = info.color
	desc_label.text = info.desc
	if modifier_menu:
		modifier_menu.visible = idx == 0

	for i in range(buttons.size()):
		if buttons[i].has_method("set_selected"):
			buttons[i].set_selected(i == idx)
			if i == 0:
				buttons[i].text = MODE_INFO[i].title
			else:
				buttons[i].text = "%s\n%s  •  %s" % [MODE_INFO[i].title, MODE_INFO[i].subtitle, MODE_STATUS[i]]

func _play_click_sound() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("powerup", 0.9)

func _on_play() -> void:
	GameManager.select_mode(MODE_INFO[selected_index].mode)
	var scene_path = GameManager.get_mode_scene(MODE_INFO[selected_index].mode)
	var loading = load("res://scripts/LoadingScreen.gd")
	if loading:
		loading.show_loading(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

const LAYOUT_CFG_PATH := "user://settings.cfg"

func _load_saved_layout() -> String:
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_CFG_PATH)
	return str(cfg.get_value("game", "map_layout", "open_plan"))

func _on_layout_selected(index: int) -> void:
	var names := ["open_plan", "cubicle_maze", "executive"]
	var picked: String = names[clampi(index, 0, 2)]
	var LevelLayouts = load("res://scripts/LevelLayouts.gd")
	if LevelLayouts:
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

func _open_credits() -> void:
	var overlay = CanvasLayer.new()
	overlay.set_script(load("res://scripts/CreditsScreen.gd"))
	add_child(overlay)

func _process(delta: float) -> void:
	menu_time += delta
	if title_label:
		title_label.modulate = Color(1, 1, 1, 1.0).lerp(Color(1.08, 0.95, 0.85), 0.5 + sin(menu_time * 1.6) * 0.5)
	_update_layout()

func _update_layout() -> void:
	var w := get_viewport_rect().size.x
	var wide := w >= 1080.0
	if hero_panel:
		hero_panel.visible = wide
	var vbox := get_node_or_null("VBox") as Control
	if vbox == null:
		return
	var margin: float
	if wide:
		margin = 80.0
	elif w >= 700.0:
		margin = 40.0
	elif w >= 500.0:
		margin = 20.0
	else:
		margin = 12.0
	vbox.offset_left = margin
	vbox.offset_right = -420.0 if wide else -margin
	var needed := vbox.get_combined_minimum_size().y
	var view_h := get_viewport_rect().size.y
	if needed > view_h - 34.0:
		vbox.grow_vertical = Control.GROW_DIRECTION_END
		vbox.anchor_bottom = 0.0
		vbox.offset_bottom = needed
	var center_header := w >= 700.0
	var small := w < 560.0
	if utility_row and utility_row is HBoxContainer:
		(utility_row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER if center_header \
			else BoxContainer.ALIGNMENT_BEGIN
	if stats_label:
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center_header \
			else HORIZONTAL_ALIGNMENT_LEFT
	for child in [title_label, subtitle_label, desc_label]:
		if child:
			child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center_header \
				else HORIZONTAL_ALIGNMENT_LEFT
	for label in _small_labels:
		if is_instance_valid(label):
			label.add_theme_font_size_override("font_size", 10 if small else 12)
	# D2: tagline scrim — bottom-up gradient black 0.0->0.55 behind subtitle+desc.
	if tagline_scrim:
		tagline_scrim.visible = backdrop != null and backdrop.visible
		if tagline_scrim.visible and subtitle_label and desc_label:
			var sub_y := subtitle_label.global_position.y
			var desc_bottom := desc_label.global_position.y + desc_label.size.y
			if desc_bottom > sub_y:
				tagline_scrim.position = Vector2(margin, sub_y - 4.0)
				tagline_scrim.size = Vector2(w - margin * 2.0, desc_bottom - sub_y + 8.0)

var _small_labels: Array[Label] = []

func _is_narrow() -> bool:
	return get_viewport_rect().size.x < 560.0

func _register_detail_label(label: Label) -> void:
	_small_labels.append(label)
	if get_viewport_rect().size.x < 560.0:
		label.custom_minimum_size.x = 0

func _register_small_label(label: Label) -> void:
	_small_labels.append(label)
	label.add_theme_font_size_override("font_size", 12)

func _build_menu_theme() -> void:
	title_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.ORANGE))
	var w := get_viewport_rect().size.x
	title_label.add_theme_font_size_override("font_size", 34 if w >= 700.0 else 26)
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	if title_label.text.length() > 0 and not title_label.text.contains("\n"):
		title_label.text = "FRIDAY 5PM\nEVACUATION"
		title_label.add_theme_constant_override("line_spacing", -6)
	desc_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	desc_label.add_theme_font_size_override("font_size", 13)
	# D2: tagline scrim panel — bottom-up gradient black 0.0->0.55 so text
	# reads over the skyline backdrop. ColorRect can't gradient; use a
	# custom Control that draws vertical bands.
	tagline_scrim = Control.new()
	tagline_scrim.name = "TaglineScrim"
	tagline_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tagline_scrim.set_script(load("res://scripts/TaglineScrim.gd"))
	# Insert behind the VBox (draw order = tree order; BG is child 0).
	add_child(tagline_scrim)
	move_child(tagline_scrim, 0)
	UI_THEME.apply_primary(play_button)
	play_button.grab_focus()
	UI_THEME.apply_secondary(host_button, UI_THEME.color(UI_THEME.CYAN))
	UI_THEME.apply_secondary(join_button, UI_THEME.color(UI_THEME.LIME))
	UI_THEME.apply_secondary(back_button, UI_THEME.color(UI_THEME.CORAL))

func _open_lobby() -> void:
	if lobby_overlay:
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
	)

func _open_settings() -> void:
	if settings_overlay:
		return
	var script = load("res://scripts/Settings.gd")
	settings_overlay = Control.new()
	settings_overlay.set_script(script)
	add_child(settings_overlay)
	settings_overlay.closed.connect(func(): settings_overlay = null)
