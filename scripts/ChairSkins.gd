class_name ChairSkins
extends RefCounted

# Phase 8A — unlockable chair skins with light stat personalities.
# Static-only (mirrors CharacterRoster.gd): standalone-compilable, resolved
# via load("res://scripts/ChairSkins.gd") at call sites (class_name globals
# are unreliable across raw SceneTree tests — see ModifierMenu gotcha).
#
# Unlocks key off career WINS (StatsManager.races_won). Multipliers apply
# once in PlayerChair._ready() before physics starts.

const DEFAULT_ID := "office_standard"

const SKINS: Array[Dictionary] = [
	{
		"id": "office_standard",
		"name": "Office Standard",
		"tagline": "Beige. Agonizingly beige.",
		"unlock_wins": 0,
		"jump_mult": 1.0,
		"friction_mult": 1.0,
		"boost_mult": 1.0,
		"seat_rise": 0.0,
		"sfx": "",  # boost sfx override (empty = default whoosh)
	},
	{
		"id": "bean_bag",
		"name": "Bean Bag",
		"tagline": "Sinks when idle. Regrets everything.",
		"unlock_wins": 1,
		"jump_mult": 0.75,
		"friction_mult": 1.45,
		"boost_mult": 0.85,
		"seat_rise": -0.12,
		"sfx": "",
	},
	{
		"id": "exercise_ball",
		"name": "Exercise Ball",
		"tagline": "Bouncy. Nobody asked for this.",
		"unlock_wins": 3,
		"jump_mult": 1.45,
		"friction_mult": 0.7,
		"boost_mult": 1.0,
		"seat_rise": 0.22,
		"sfx": "",
	},
	{
		"id": "shopping_cart",
		"name": "Shopping Cart",
		"tagline": "Pulls hard left since 2019.",
		"unlock_wins": 5,
		"jump_mult": 0.95,
		"friction_mult": 0.85,
		"boost_mult": 1.15,
		"seat_rise": 0.05,
		"sfx": "",
	},
	{
		"id": "toilet",
		"name": "The Throne",
		"tagline": "Porcelain. Flush-powered.",
		"unlock_wins": 10,
		"jump_mult": 1.1,
		"friction_mult": 1.1,
		"boost_mult": 1.25,
		"seat_rise": 0.15,
		"sfx": "flush",
	},
	{
		"id": "racing_seat",
		"name": "Racing Seat",
		"tagline": "Zero lumbar support. All commitment.",
		"unlock_wins": 25,
		"jump_mult": 0.9,
		"friction_mult": 0.75,
		"boost_mult": 1.1,
		"seat_rise": -0.04,
		"sfx": "",
	},
]


static func all() -> Array[Dictionary]:
	return SKINS


static func ids() -> Array:
	var out: Array = []
	for skin in SKINS:
		out.append(skin["id"])
	return out


static func get_skin(id: String) -> Dictionary:
	for skin in SKINS:
		if skin["id"] == id:
			return skin
	return SKINS[0]


static func display_name(id: String) -> String:
	return String(get_skin(id)["name"])


static func is_unlocked(id: String, wins: int) -> bool:
	return wins >= int(get_skin(id)["unlock_wins"])


## Skins whose unlock threshold lands in (before_wins, after_wins] —
## i.e. what a race that pushed wins from before to after just unlocked.
static func newly_unlocked(before_wins: int, after_wins: int) -> Array[String]:
	var out: Array[String] = []
	for skin in SKINS:
		var threshold := int(skin["unlock_wins"])
		if threshold > before_wins and threshold <= after_wins:
			out.append(String(skin["name"]))
	return out


## The next locked skin at a given win count, with progress fields for UI.
## Returns {} when everything is unlocked.
static func next_unlock(wins: int) -> Dictionary:
	for skin in SKINS:
		if wins < int(skin["unlock_wins"]):
			return {
				"id": skin["id"],
				"name": skin["name"],
				"unlock_wins": skin["unlock_wins"],
				"progress": wins,
			}
	return {}
