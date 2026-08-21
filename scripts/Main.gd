# Main.gd — Main menu / mode select screen
extends Control

const UI_THEME = preload("res://scripts/UITheme.gd")

const MODE_INFO = [
	{
		"title": "FRIDAY 5PM: EVACUATION",
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

var selected_index: int = 0
var buttons: Array[Button] = []
var settings_overlay: Control
var lobby_overlay: Control
var settings_button: Button
var credits_button: Button
var utility_row: HBoxContainer
var modifier_row: HBoxContainer
var modifier_toggles: Array[CheckButton] = []
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
	_build_mode_buttons()
	_select_mode(0)
	
	play_button.pressed.connect(_on_play)
	_build_modifier_row()
	utility_row = HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 8)
	$VBox.add_child(utility_row)
	settings_button = Button.new()
	settings_button.text = "⚙ SETTINGS"
	settings_button.custom_minimum_size = Vector2(0, 42)
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.add_theme_font_size_override("font_size", 14)
	utility_row.add_child(settings_button)
	settings_button.pressed.connect(_open_settings)
	credits_button = Button.new()
	credits_button.text = "★ CREDITS"
	credits_button.custom_minimum_size = Vector2(0, 42)
	credits_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_button.add_theme_font_size_override("font_size", 14)
	utility_row.add_child(credits_button)
	credits_button.pressed.connect(_open_credits)
	stats_label = Label.new()
	stats_label.text = ""
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	$VBox.add_child(stats_label)
	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		stats_label.text = stats.get_summary_line()
		stats.stats_updated.connect(func(): stats_label.text = stats.get_summary_line())
	_build_menu_theme()
	host_button.visible = true
	host_button.text = "MULTIPLAYER LOBBY"
	host_button.pressed.connect(_open_lobby)
	join_button.visible = false
	back_button.visible = false

func _build_mode_buttons() -> void:
	for i in range(MODE_INFO.size()):
		var info = MODE_INFO[i]
		var btn = Button.new()
		var card_script = load("res://scripts/ModeCard.gd")
		btn.set_script(card_script)
		btn.configure(info.title, info.subtitle, "PLAYABLE" if i == 0 else "PROTOTYPE", info.color)
		btn.custom_minimum_size = Vector2(0, 62)
		btn.pressed.connect(_select_mode.bind(i))
		mode_list.add_child(btn)
		buttons.append(btn)

func _build_modifier_row() -> void:
	# Race-modifier quick toggles — single-player Evacuation only.
	var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
	if not RaceModifiersScript:
		return
	RaceModifiersScript.load_from_cfg()
	modifier_row = HBoxContainer.new()
	modifier_row.add_theme_constant_override("separation", 6)
	$VBox.add_child(modifier_row)
	$VBox.move_child(modifier_row, play_button.get_index() + 1)
	var idx := 0
	for mod in RaceModifiersScript.ALL:
		var toggle := CheckButton.new()
		toggle.text = RaceModifiersScript.LABELS[mod].split(" — ")[0]
		toggle.tooltip_text = RaceModifiersScript.LABELS[mod]
		toggle.button_pressed = RaceModifiersScript.is_active(mod)
		toggle.add_theme_font_size_override("font_size", 11)
		toggle.toggled.connect(func(on: bool):
			RaceModifiersScript.toggle(mod)
			RaceModifiersScript.save_to_cfg()
		)
		modifier_row.add_child(toggle)
		modifier_toggles.append(toggle)
		idx += 1
	modifier_row.visible = selected_index == 0

func _select_mode(idx: int) -> void:
	selected_index = idx
	var info = MODE_INFO[idx]
	title_label.text = info.title
	subtitle_label.text = info.subtitle
	subtitle_label.modulate = info.color
	desc_label.text = info.desc
	if modifier_row:
		modifier_row.visible = idx == 0
	
	for i in range(buttons.size()):
		if buttons[i].has_method("set_selected"):
			buttons[i].set_selected(i == idx)
		else:
			buttons[i].disabled = i == idx
		if i == idx:
			buttons[i].text = ">> %s\n%s  •  %s <<" % [MODE_INFO[i].title, MODE_INFO[i].subtitle, "PLAYABLE" if i == 0 else "PROTOTYPE"]
		else:
			buttons[i].text = "%s\n%s  •  %s" % [MODE_INFO[i].title, MODE_INFO[i].subtitle, "PLAYABLE" if i == 0 else "PROTOTYPE"]

func _on_play() -> void:
	GameManager.select_mode(MODE_INFO[selected_index].mode)
	var scene_path = GameManager.get_mode_scene(MODE_INFO[selected_index].mode)
	var loading = load("res://scripts/LoadingScreen.gd")
	if loading:
		loading.show_loading(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

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
	title_label.add_theme_font_size_override("font_size", 46)
	subtitle_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	desc_label.add_theme_font_size_override("font_size", 16)
	UI_THEME.apply_primary(play_button)
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
