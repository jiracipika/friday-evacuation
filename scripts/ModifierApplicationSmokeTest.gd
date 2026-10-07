# ModifierApplicationSmokeTest.gd — PLAYTEST.md Session 5 leftover: modifiers
# must actually reach the race, and LAN must ignore them.
#
# PLAYTEST checklist: "Modifiers: toggle 2-3 chips (NO COFFEE + JUST WAXED)
# → race applies them; LAN match ignores modifiers (single-player only)".
#
# Existing coverage (intentionally not duplicated):
#   RaceModifiersSmokeTest — toggle semantics + cfg persistence.
#   ModifierMenuSmokeTest  — chip UI sync, summaries, CLEAR.
# This suite covers the missing leg: what the CHIPS DO inside a live
# Evacuation match, pinning each chip's REAL effect at its application site:
#   NO_COFFEE      -> _spawn_powerups() returns early (zero pickups spawn)
#   SLIPPERY       -> local_player.friction *= 0.3 (_apply_player_modifiers)
#   LOW_GRAVITY    -> local_player.gravity  *= 0.6 (_apply_player_modifiers)
#   DOUBLE_TRAPS   -> trap_count 8 instead of 4 (_spawn_traps)
#   TIME_ATTACK_90 -> time_limit 90.0 instead of 120.0 (_setup_arena)
# and the single-player-only gate: with a REAL ENet host peer on the Network
# singleton (same isolation NetworkSmokeTest uses), sp_modifiers flips false
# and every chip is ignored — stock race despite all five selected.
# Run: godot --headless --path . --script scripts/ModifierApplicationSmokeTest.gd -- --test-mode
extends SceneTree

var checks := 0
var passed := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

# ============================ harness ============================

func _mount_evacuation() -> Node:
	# PreMatchModal pauses the tree on mount — suppressed per instantiation
	# (single-shot seam, same as CheckpointBotTest / LayoutPacingTest).
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var evac: Node = (load("res://scenes/Evacuation.tscn") as PackedScene).instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame
	# Skip the 3s countdown: _start_race is the mode's own go-horn seam and
	# is where _spawn_traps() runs (traps only exist once the race starts).
	evac._start_race()
	await process_frame
	await process_frame
	return evac

func _teardown(evac: Node) -> void:
	if evac != null and evac.is_inside_tree():
		evac.free()
	await process_frame

func _chair(evac: Node) -> CharacterBody3D:
	return evac.get("local_player") as CharacterBody3D

## Pickups are the only evac children carrying a `sync_name` (Evacuation's
## own net-pickup lookup keys on that property — no group needed).
func _powerup_count(evac: Node) -> int:
	var n := 0
	for child in evac.get_children():
		if "sync_name" in child:
			n += 1
	return n

## Arena traps are SabotageTrap.gd-scripted children spawned by _spawn_traps.
func _trap_count(evac: Node) -> int:
	var trap_script: Script = load("res://scripts/SabotageTrap.gd")
	var n := 0
	for child in evac.get_children():
		if child.get_script() == trap_script:
			n += 1
	return n

func _select(mods: Array) -> void:
	var RM = load("res://scripts/RaceModifiers.gd")
	RM.selected.clear()
	for mod in mods:
		RM.toggle(mod)

# ============================ phases ============================

func _run() -> void:
	var RM = load("res://scripts/RaceModifiers.gd")
	var layouts = load("res://scripts/LevelLayouts.gd")
	if layouts:
		layouts.set_current("open_plan")  # deterministic arena (process state only)
	# Fresh modifier state (menu persists to the shared user cfg — start clean).
	_select([])
	RM.save_to_cfg()

	# ---------- control race: no chips, everything stock ----------
	print("[phase] control race mounting...")
	var evac := await _mount_evacuation()
	print("[phase] control race mounted")
	var stock_gravity: float = _chair(evac).gravity
	var stock_friction: float = _chair(evac).friction
	check(evac.get("sp_modifiers") == true,
		"control race: no peer -> modifiers are live (sp_modifiers=true)")
	check(is_equal_approx(evac.get("time_limit"), 120.0),
		"control race: default 120s clock with no chips")
	check(_powerup_count(evac) > 0,
		"control race: pickups spawn with no chips (%d)" % _powerup_count(evac))
	check(_trap_count(evac) == 4,
		"control race: 4 arena traps with no chips (%d)" % _trap_count(evac))
	check(is_equal_approx(stock_gravity,
			float(ProjectSettings.get_setting("physics/3d/default_gravity")))
		and stock_friction > 0.0,
		"control race: stock chair physics captured (g=%.1f f=%.1f)"
			% [stock_gravity, stock_friction])
	await _teardown(evac)

	# ---------- PLAYTEST pairing: NO COFFEE + JUST WAXED ----------
	_select([RM.Modifier.NO_COFFEE, RM.Modifier.SLIPPERY])
	evac = await _mount_evacuation()
	check(_powerup_count(evac) == 0,
		"NO COFFEE: chip removes every pickup spawn (0 found)")
	check(is_equal_approx(_chair(evac).friction, stock_friction * 0.3),
		"JUST WAXED: chip applies 30 percent ground friction (f=%.1f)" % _chair(evac).friction)
	check(is_equal_approx(_chair(evac).gravity, stock_gravity),
		"NO COFFEE + JUST WAXED: other chair physics untouched (g=%.1f)"
			% _chair(evac).gravity)
	check(is_equal_approx(evac.get("time_limit"), 120.0),
		"NO COFFEE + JUST WAXED: clock stays 120s (no time chip)")
	check(_trap_count(evac) == 4,
		"NO COFFEE + JUST WAXED: traps stay 4 (no double chip)")
	await _teardown(evac)

	# ---------- the remaining three chips ----------
	_select([RM.Modifier.LOW_GRAVITY, RM.Modifier.DOUBLE_TRAPS, RM.Modifier.TIME_ATTACK_90])
	evac = await _mount_evacuation()
	check(is_equal_approx(_chair(evac).gravity, stock_gravity * 0.6),
		"MOON OFFICE: chip applies 60 percent gravity (g=%.1f)" % _chair(evac).gravity)
	check(is_equal_approx(_chair(evac).friction, stock_friction),
		"MOON OFFICE: friction untouched by gravity chip (f=%.1f)"
			% _chair(evac).friction)
	check(_trap_count(evac) == 8,
		"DOUBLE TROUBLE: chip doubles arena traps (%d)" % _trap_count(evac))
	check(is_equal_approx(evac.get("time_limit"), 90.0),
		"TIME ATTACK: chip sets the 90s clock (%.0fs)" % float(evac.get("time_limit")))
	check(_powerup_count(evac) > 0,
		"DOUBLE TROUBLE + TIME ATTACK: pickups still spawn (no coffee chip)")
	await _teardown(evac)

	# ---------- LAN ignores modifiers (single-player only) ----------
	# Real isolation, same as NetworkSmokeTest: an actual ENet host peer on
	# the Network singleton (not a stub flag), so the production gate
	# `sp_modifiers = not (network and network.peer)` is exercised as shipped.
	var network: Node = root.get_node_or_null("Network")
	check(network != null, "LAN leg: Network autoload present")
	if network != null:
		var hosted: bool = network.host_game(5533)
		check(hosted and network.peer != null,
			"LAN leg: real ENet host peer created")
		_select([RM.Modifier.NO_COFFEE, RM.Modifier.SLIPPERY, RM.Modifier.LOW_GRAVITY,
			RM.Modifier.DOUBLE_TRAPS, RM.Modifier.TIME_ATTACK_90])
		evac = await _mount_evacuation()
		check(evac.get("sp_modifiers") == false,
			"LAN race: modifiers gate OFF with a peer (sp_modifiers=false)")
		check(is_equal_approx(evac.get("time_limit"), 120.0),
			"LAN race: TIME ATTACK ignored — clock stays 120s")
		check(_powerup_count(evac) > 0,
			"LAN race: NO COFFEE ignored — pickups spawn (%d)" % _powerup_count(evac))
		check(_trap_count(evac) == 4,
			"LAN race: DOUBLE TROUBLE ignored — traps stay 4 (%d)" % _trap_count(evac))
		check(is_equal_approx(_chair(evac).gravity, stock_gravity)
			and is_equal_approx(_chair(evac).friction, stock_friction),
			"LAN race: MOON OFFICE + JUST WAXED ignored — stock chair physics")
		await _teardown(evac)
		network.close_connection()
		check(network.peer == null, "LAN leg: peer closed cleanly")

	# Leave clean state for other suites (shared user cfg).
	_select([])
	RM.save_to_cfg()

	if failures.is_empty():
		print("ModifierApplicationSmokeTest: %d/%d checks passed" % [passed, checks])
		quit(0)
	else:
		printerr("ModifierApplicationSmokeTest: %d/%d checks failed — %s"
			% [failures.size(), checks, ", ".join(failures)])
		quit(1)
