# Announcer.gd — procedural race announcer with potty-mouth energy.
#
# Generates short, punchy, family-friendly-sassy callouts for race events
# (boosts, traps, near-misses, wins). Text-only via Accessibility.caption;
# the pooled SFX engine handles any audio. Static + stateless-ish by
# design so any mode can mount it with one line:
#   Announcer.mount(self)  -> adds an Announcer node, returns it
#
# A11y: every announcement routes through Accessibility.caption so screen
# reader users see the same hype. Anti-spam: per-category cooldown.
extends Node

const COOLDOWNS := {
	"boost": 6.0,
	"trap": 4.0,
	"hazard": 6.0,
	"pickup": 8.0,
	"progress": 10.0,
	"misc": 3.0,
}

var _last_said := {}  # category -> time of last line
var _clock := 0.0

static func mount(parent: Node) -> Node:
	for child in parent.get_children():
		if child is Node and child.get_script() == load("res://scripts/Announcer.gd"):
			return child
	var announcer: Node = new()
	announcer.name = "Announcer"
	parent.add_child(announcer)
	return announcer

func _process(delta: float) -> void:
	_clock += delta

## Category-gated announcement. Returns the line (or "" if suppressed).
func say(category: String, lines: Array, force := false) -> String:
	var ready_at: float = _last_said.get(category, -999.0) + float(COOLDOWNS.get(category, 4.0))
	if not force and _clock < ready_at:
		return ""
	var line: String = lines[randi() % lines.size()]
	_last_said[category] = _clock
	_caption(line)
	return line

func _caption(text: String) -> void:
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption(text, 2.0)

# ---- Line banks ------------------------------------------------------------

const BOOST_LINES := [
	"WHEEE!",
	"Chair mode: ENGAGED.",
	"HR said no speeding. HR is not here.",
	"That coffee was DECAF? Couldn't tell.",
	"Physics remaining: zero.",
]

const TRAP_HIT_LINES := [
	"And DOWN goes the intern!",
	"That banana had a family, you know.",
	"OSHA has entered the chat.",
	"You've been HR'd.",
	"Direct hit! The chair files a complaint.",
]

const TRAP_DROP_LINES := [
	"Trap deployed. Evil laugh optional.",
	"Somewhere, a janitor just sighed.",
	"Sabotage rating: five stars.",
]

const HAZARD_LINES := [
	"The roomba union strikes again.",
	"Fire drill! The stairs are a lie.",
	"Debris! Very expensive debris.",
	"That door had opinions.",
]

const PICKUP_LINES := [
	"Fuel acquired!",
	"Item get! Inventory unclear.",
	"Pocketed. Don't ask what it does.",
]

const FINAL_STRETCH_LINES := [
	"FINAL FLOOR — GO GO GO!",
	"Exit's close! Chairs are screaming.",
	"Down the stretch they come!",
]

const WIN_LINES := [
	"WINNER! Tell your chair it did great.",
	"First one out! The parking lot salutes you.",
	"VICTORY! Everyone else: walk of shame.",
]

const LOSE_LINES := [
	"So close. The elevator mourns.",
	"Time! HR is asking questions.",
	"Next time, less coffee. Actually no, more coffee.",
]

const START_LINES := [
	"GO! The 5PM exodus begins!",
	"Doors open! May the best chair win!",
	"It is 5PM on a Friday. RUN.",
]
