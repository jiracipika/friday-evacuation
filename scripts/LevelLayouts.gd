# LevelLayouts.gd — data-driven layout variants for Evacuation (Phase 4).
#
# The building BLOCKS (floors, perimeter walls, elevators, floor-3
# landing rects, exit) are layout-independent and stay put — FLOOR3_LANDINGS
# is triple-synced (Evacuation._floor3_landing_layout / LevelClearTest /
# Hazards) and must NOT vary per layout. Layouts instead vary the FURNITURE
# layer: desk/crate placement, floor-1 corridor plan, floor-2 density,
# floor-4 ice coverage, and the obstacle seed.
#
# Adding a layout:
#   1. Add a LAYOUTS entry below (all fields required).
#   2. Verify: python point-in-rect check that every desk/crate spawn is on
#      solid floor (never over a floor-3 gap — layout desks avoid floor 3
#      entirely, so this is mostly about not spawning inside walls).
#   3. Add the name to LevelLayoutSmokeTest's expected list.
#
# Layouts:
#   OPEN_PLAN    — the shipped default: scattered desks, wide floor-1
#                  corridors, standard ice patch.
#   CUBICLE_MAZE — dense floor-1 cubicle grid with narrow lanes; fewer,
#                  larger desk clusters on floors 1/2; more power-ups pace.
#   EXECUTIVE    — floor-2 "suite": long sightlines, few obstacles, extra
#                  crates on floor 4, wider ice (skill floor).
class_name LevelLayouts
extends RefCounted

const OPEN_PLAN := "open_plan"
const CUBICLE_MAZE := "cubicle_maze"
const EXECUTIVE := "executive"
const DEFAULT_LAYOUT := OPEN_PLAN

const LAYOUT_NAMES := [OPEN_PLAN, CUBICLE_MAZE, EXECUTIVE]

## Per-layout tuning table. Everything a layout touches lives here so the
## mode script stays identical for all three.
##   desk_counts:      desks per floor y-level [0.5, 6.5, 18.5] (never 12.5)
##   desk_range:       desk spawn |x|,|z| bound
##   obstacle_seed:    deterministic RNG seed for desk placement
##   powerup_count:    coffee pickups per match
##   f1_corridor_gap:  cubicle grid gap (0 = shipped 3-wide corridor)
##   f2_tables:        conference tables on floor 2
##   f4_ice_size:      ice zone half-extent (26 = shipped)
##   f4_crates:        crates on floor 4 lot
static func get_layout(layout_name: String) -> Dictionary:
	var base := {
		"desk_counts": [5, 5, 5],
		"desk_range": 15.0,
		"obstacle_seed": 1337,
		"powerup_count": 8,
		"f1_corridor_gap": 0,
		"f2_tables": [-6.0, 6.0],
		"f4_ice_size": 26.0,
		"f4_crates": [Vector3(-6, 18.5, 12), Vector3(6, 18.5, 12)],
	}
	match layout_name:
		CUBICLE_MAZE:
			base["desk_counts"] = [3, 6, 6]
			base["obstacle_seed"] = 4242
			base["powerup_count"] = 10
			base["f1_corridor_gap"] = 1   # narrower center corridor
			base["f2_tables"] = []        # tables removed: pure desk weave
			base["f4_crates"] = [
				Vector3(-6, 18.5, 12), Vector3(6, 18.5, 12),
				Vector3(0, 18.5, 10), Vector3(-12, 18.5, 14),
			]
		EXECUTIVE:
			base["desk_counts"] = [2, 2, 8]
			base["desk_range"] = 16.0
			base["obstacle_seed"] = 909
			base["powerup_count"] = 6
			base["f2_tables"] = [-9.0, 0.0, 9.0]  # long suite tables
			base["f4_ice_size"] = 34.0            # nearly the whole floor
			base["f4_crates"] = [
				Vector3(-10, 18.5, 12), Vector3(0, 18.5, 12),
				Vector3(10, 18.5, 12), Vector3(-5, 18.5, 9),
				Vector3(5, 18.5, 9),
			]
		_:
			pass  # OPEN_PLAN keeps the base table
	return base

static func is_valid(name_value: String) -> bool:
	return name_value in LAYOUT_NAMES

## Current selection (persisted via GameManager-style cfg through the mode
## scene; single-player picks from the menu, LAN host sends via match
## start payload). Stored here as process state; default OPEN_PLAN.
static var current := DEFAULT_LAYOUT

static func set_current(name_value: String) -> void:
	if is_valid(name_value):
		current = name_value

static func current_layout() -> Dictionary:
	return get_layout(current)

## Pretty label for HUD/lobby display. Falls back to the raw key.
static func display_name(name_value: String) -> String:
	match name_value:
		OPEN_PLAN:
			return "Open Plan"
		CUBICLE_MAZE:
			return "Cubicle Maze"
		EXECUTIVE:
			return "Executive Suite"
	return name_value.capitalize()
