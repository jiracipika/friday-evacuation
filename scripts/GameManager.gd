# GameManager.gd — Autoload singleton
# Holds global game state across scenes
extends Node

# Game modes
enum GameMode {
	EVACUATION,
	HAULED,
	SHOP_SEEK,
	PIZZA_COLONY
}

# Player data
var player_name: String = "Player1"
var player_color: Color = Color(0.4, 0.8, 1.0)
var selected_mode: GameMode = GameMode.EVACUATION

# Multiplayer
var is_multiplayer: bool = false
var is_host: bool = false
var server_ip: String = "127.0.0.1"
var server_port: int = 5005
var max_players: int = 8

# Match state
var players_in_lobby: Array[String] = []

# Results
var race_results: Array[Dictionary] = []

signal mode_selected(mode: GameMode)

const PLAYER_COLORS: Array[Color] = [
	Color(0.4, 0.8, 1.0),   # cyan-blue
	Color(1.0, 0.6, 0.1),  # orange
	Color(0.72, 0.4, 1.0), # violet
	Color(0.95, 0.35, 0.4),# coral
	Color(0.45, 0.9, 0.4), # lime
	Color(1.0, 0.85, 0.3), # amber
	Color(0.4, 0.85, 0.75),# teal
	Color(0.9, 0.9, 0.95), # white
]

func _ready() -> void:
	_load_identity()

func _load_identity() -> void:
	var config := ConfigFile.new()
	if config.load("user://identity.cfg") == OK:
		player_name = config.get_value("player", "name", player_name)
		var color_hex: String = config.get_value("player", "color", player_color.to_html(false))
		player_color = Color.from_string(color_hex, player_color)

func save_identity() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("player", "color", player_color.to_html(false))
	config.save("user://identity.cfg")

func select_mode(mode: GameMode) -> void:
	selected_mode = mode
	mode_selected.emit(mode)

func get_mode_scene(mode: GameMode) -> String:
	match mode:
		GameMode.EVACUATION:
			return "res://scenes/Evacuation.tscn"
		GameMode.HAULED:
			return "res://scenes/Hauled.tscn"
		GameMode.SHOP_SEEK:
			return "res://scenes/ShopSeek.tscn"
		GameMode.PIZZA_COLONY:
			return "res://scenes/PizzaColony.tscn"
		_:
			return "res://scenes/Evacuation.tscn"

func get_mode_display_name(mode: GameMode) -> String:
	match mode:
		GameMode.EVACUATION:
			return "FRIDAY 5PM: EVACUATION"
		GameMode.HAULED:
			return "HAULED"
		GameMode.SHOP_SEEK:
			return "SHOP & SEEK"
		GameMode.PIZZA_COLONY:
			return "PIZZA COLONY"
		_:
			return "UNKNOWN"

func get_mode_description(mode: GameMode) -> String:
	match mode:
		GameMode.EVACUATION:
			return "It's 4:59 PM. Race your office chair through the building to the parking lot. Coffee boosts, water traps, stapler sabotage. Last one buys beers."
		GameMode.HAULED:
			return "Co-op delivery of absurd HOSTILE cargo — a fridge full of bees, a haunted sofa — through impossible terrain. Drop it, you owe money."
		GameMode.SHOP_SEEK:
			return "Half of you disguise as groceries in a supermarket. The other half are frantic shoppers with a list and 60 seconds. Spot the fake avocado."
		GameMode.PIZZA_COLONY:
			return "You're toppings on a GIANT living pizza. Claim pepperoni territory, dodge the chef's slice-cutter, harvest cheese. Co-op survival."
		_:
			return ""
