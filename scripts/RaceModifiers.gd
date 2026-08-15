# RaceModifiers.gd — optional single-player race modifiers (Phase C).
# Selected in the main menu before starting Evacuation; applied by
# Evacuation.gd at match start. Multiplayer always ignores modifiers.
class_name RaceModifiers
extends RefCounted

enum Modifier {
	NONE,
	NO_COFFEE,     # coffee power-ups disabled
	DOUBLE_TRAPS,  # 8 traps instead of 4
	LOW_GRAVITY,   # 60% gravity
	SLIPPERY,      # 30% ground friction
	TIME_ATTACK_90 # 90s hard time limit
}

const ALL: Array[Modifier] = [
	Modifier.NO_COFFEE,
	Modifier.DOUBLE_TRAPS,
	Modifier.LOW_GRAVITY,
	Modifier.SLIPPERY,
	Modifier.TIME_ATTACK_90,
]

const LABELS := {
	Modifier.NO_COFFEE: "NO COFFEE — no boost pickups",
	Modifier.DOUBLE_TRAPS: "DOUBLE TROUBLE — 8 traps",
	Modifier.LOW_GRAVITY: "MOON OFFICE — low gravity",
	Modifier.SLIPPERY: "JUST WAXED — slippery floors",
	Modifier.TIME_ATTACK_90: "TIME ATTACK — 90s limit",
}

## Active selections (persisted so the menu restores them).
static var selected: Array[Modifier] = []

static func is_active(mod: Modifier) -> bool:
	return mod in selected

## Modifiers are a single-player feature; callers gate on network state
## themselves (Evacuation ignores modifiers whenever a peer exists).
static func any_active() -> bool:
	return not selected.is_empty()

static func toggle(mod: Modifier) -> void:
	if mod in selected:
		selected.erase(mod)
	else:
		selected.append(mod)

static func save_to_cfg() -> void:
	var config := ConfigFile.new()
	var ids: Array = []
	for mod in selected:
		ids.append(int(mod))
	config.set_value("race", "modifiers", ids)
	config.save("user://settings.cfg")

static func load_from_cfg() -> void:
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	selected.clear()
	var ids: Array = config.get_value("race", "modifiers", [])
	for id in ids:
		var mod := int(id) as Modifier
		if mod in ALL:
			selected.append(mod)
