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
var credits_button: Button
var utility_row: HBoxContainer
var modifier_menu: Control
var character_row: HBoxContainer
var character_select: OptionButton
var character_detail: Label
var stats_label: Label
var menu_time: float = 0.0

# UI nodes
@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var desc_label: Label = $VBox/Description
@onready var mode_list: VBoxContainer = $VBox/ModeList
@onready var play_button: Button = $VBox/PlayButton
@onready var host_button: Button = $VBox/HostButton
@onready var join_button: Button = $VBox/JoinButton
@onready var back_button: Button = $VBox/BackButton

func _ready() -> void:
	get_window().title = "Friday 5PM: Evacuation"
	# Debug virtual gamepad (--virtual-pad or FE_VIRTUAL_PAD=1): pumps real
	# joypad events for pad-play QA without hardware. Lives on the root so
	# it survives scene changes into the race.
	if "virtual-pad" in OS.get_cmdline_user_args() or OS.get_environment("FE_VIRTUAL_PAD") == "1":
		var vpad = load("res://scripts/VirtualPad.gd")
		if vpad:
			var vpad_node: Node = vpad.new()
			vpad_node.name = "VirtualPad"
			get_tree().root.add_child.call_deferred(vpad_node)
	_build_mode_buttons()
	_select_mode(0)
	_build_character_selector()
	
	play_button.pressed.connect(_on_play)
	play_button.pressed.connect(_play_click_sound)
	_build_modifier_row()
	utility_row = HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 8)
	$VBox.add_child(utility_row)
	settings_button = Button.new()
	settings_button.text = "SETTINGS"
	settings_button.custom_minimum_size = Vector2(0, 28)
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.add_theme_font_size_override("font_size", 12)
	utility_row.add_child(settings_button)
	settings_button.pressed.connect(_open_settings)
	credits_button = Button.new()
	credits_button.text = "CREDITS"
	credits_button.custom_minimum_size = Vector2(0, 28)
	credits_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_button.add_theme_font_size_override("font_size", 12)
	utility_row.add_child(credits_button)
	credits_button.pressed.connect(_open_credits)
	# PHASE 4: map layout picker (single-player + host authority).
	layout_option = OptionButton.new()
	layout_option.add_item("MAP: OPEN PLAN", 0)
	layout_option.add_item("MAP: CUBICLE MAZE", 1)
	layout_option.add_item("MAP: EXECUTIVE", 2)
	layout_option.custom_minimum_size = Vector2(0, 28)
	layout_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_option.add_theme_font_size_override("font_size", 12)
	utility_row.add_child(layout_option)
	var saved_layout := str(_load_saved_layout())
	layout_option.select({"open_plan": 0, "cubicle_maze": 1, "executive": 2}.get(saved_layout, 0))
	layout_option.item_selected.connect(_on_layout_selected)
	# Apply the persisted pick so a menu-skip (LAN auto-start) still gets it.
	var LayoutsScript = load("res://scripts/LevelLayouts.gd")
	if LayoutsScript:
		LayoutsScript.set_current(saved_layout)
	stats_label = Label.new()
	stats_label.text = ""
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	$VBox.add_child(stats_label)
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

func _build_mode_buttons() -> void:
	for i in range(MODE_INFO.size()):
		var info = MODE_INFO[i]
		var btn = Button.new()
		var card_script = load("res://scripts/ModeCard.gd")
		btn.set_script(card_script)
		btn.configure(info.title, info.subtitle, MODE_STATUS[i], info.color)
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_select_mode.bind(i))
		mode_list.add_child(btn)
		buttons.append(btn)

func _build_modifier_row() -> void:
	# Race-modifier picker panel — single-player Evacuation only.
	# Sits ABOVE the play button (rules are chosen before you launch, like a
	# real game's pre-match options), not below it like a debug row.
	var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
	if not RaceModifiersScript:
		return
	RaceModifiersScript.load_from_cfg()
	# load()-based mount (file convention): keeps Main.gd parse-safe even when
	# the global class_name cache is stale (fresh checkout before --import).
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
	character_detail.custom_minimum_size.x = 250
	character_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	character_detail.add_theme_font_size_override("font_size", 11)
	character_detail.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	character_row.add_child(character_detail)
	var selected := 0
	var characters: Array[Dictionary] = roster.all()
	for i in range(characters.size()):
		var character: Dictionary = characters[i]
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
	if character_detail:
		character_detail.text = character["tagline"]
		character_detail.tooltip_text = "%s • %s" % [character["silhouette"], character["accessory"]]

func _select_mode(idx: int) -> void:
	selected_index = idx
	var info = MODE_INFO[idx]
	title_label.text = info.title
	subtitle_label.text = info.subtitle
	subtitle_label.modulate = info.color
	desc_label.text = info.desc
	if modifier_menu:
		modifier_menu.visible = idx == 0

	for i in range(buttons.size()):
		if buttons[i].has_method("set_selected"):
			buttons[i].set_selected(i == idx)
			# Card label: title + subtitle for secondary modes (honest status
			# tags); the primary card is title-only — the page header above it
			# already says what it is, so repeating it reads as duplication.
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

## PHASE 4: layout selection — persisted to the game cfg, applied via
## LevelLayouts.set_current so the next match builds the picked variant.
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

func _open_credits() -> void:
	var overlay = CanvasLayer.new()
	overlay.set_script(load("res://scripts/CreditsScreen.gd"))
	add_child(overlay)

func _process(delta: float) -> void:
	menu_time += delta
	if title_label:
		title_label.modulate.a = 0.96 + sin(menu_time * 2.0) * 0.04

func _build_menu_theme() -> void:
	title_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.ORANGE))
	title_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	desc_label.add_theme_font_size_override("font_size", 13)
	UI_THEME.apply_primary(play_button)
	# Controller-friendly menu: focus PLAY so dpad/left-stick + A navigates
	# the main menu out of the box (mouse still works as before).
	play_button.grab_focus()
	UI_THEME.apply_secondary(host_button, UI_THEME.color(UI_THEME.CYAN))
	UI_THEME.apply_secondary(join_button, UI_THEME.color(UI_THEME.LIME))
	UI_THEME.apply_secondary(back_button, UI_THEME.color(UI_THEME.CORAL))
	if settings_button:
		UI_THEME.apply_secondary(settings_button, UI_THEME.color(UI_THEME.CYAN))
	if credits_button:
		UI_THEME.apply_secondary(credits_button, UI_THEME.color(UI_THEME.VIOLET))

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
