# Main.gd — Main menu / mode select screen
extends Control

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
	host_button.visible = false
	join_button.visible = false
	back_button.visible = false

func _build_mode_buttons() -> void:
	for i in range(MODE_INFO.size()):
		var info = MODE_INFO[i]
		var btn = Button.new()
		btn.text = info.title
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_select_mode.bind(i))
		mode_list.add_child(btn)
		buttons.append(btn)

func _select_mode(idx: int) -> void:
	selected_index = idx
	var info = MODE_INFO[idx]
	title_label.text = info.title
	subtitle_label.text = info.subtitle
	subtitle_label.modulate = info.color
	desc_label.text = info.desc
	
	for i in range(buttons.size()):
		buttons[i].disabled = i == idx
		if i == idx:
			buttons[i].text = ">> " + MODE_INFO[i].title + " <<"
		else:
			buttons[i].text = MODE_INFO[i].title

func _on_play() -> void:
	GameManager.select_mode(MODE_INFO[selected_index].mode)
	var scene_path = GameManager.get_mode_scene(MODE_INFO[selected_index].mode)
	get_tree().change_scene_to_file(scene_path)
