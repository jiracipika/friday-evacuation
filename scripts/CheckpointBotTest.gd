# CheckpointBotTest.gd — automated checkpoint-traversal bot for Evacuation.
#
# Drives the REAL chair through the REAL scene: floor 1 → elevator → floor 2
# → elevator → floor 3 → elevator → floor 4 → ExitZone (finish). Unlike
# WinnabilityProbe (which writes chair.velocity directly and fights
# friction), this bot steers through the same input route touch players
# use: chair.set_mobile_input(Vector2) — so the input ramp, acceleration,
# brake/reverse logic, and camera-relative steering are all exercised.
#
# The run is PRE-RACE (never calls _start_race): elevator triggers, respawn
# checkpoint advancement, and the ExitZone are not race-gated, so the bot
# runs deterministic and hazard-free while still proving the full
# checkpoint → checkpoint → finish traversal machinery.
#
# PASS = every checkpoint reached in order, respawn_point advanced with
# each floor, and finish_order non-empty (real exit signal), within budget.
#
# Run: godot --headless --path . --script scripts/CheckpointBotTest.gd
extends SceneTree

# Elevator pads in travel order — MUST match Evacuation._build_elevator
# calls in _setup_arena (single source of truth: Evacuation.gd).
const GATES := [
	{"y": 0.5, "pos": Vector3(12, 0.5, 14)},    # floor 1 pad -> floor 2
	{"y": 6.5, "pos": Vector3(-12, 6.5, -2)},   # floor 2 pad -> floor 3
	{"y": 12.5, "pos": Vector3(12, 12.5, 14)},  # floor 3 pad -> floor 4
]
const EXIT_TARGET := Vector3(0, 0.0, 15.0)  # exit ring at (0, 19.3, 15)
const RESPAWN_EXPECT := [   # respawn_point after each teleport (to_pos + up 1.0)
	Vector3(12, 7.5, -2),
	Vector3(-12, 13.5, 14),
	Vector3(12, 19.5, -2),
]
const TIME_BUDGET := 100.0      # seconds of simulated time
const TARGET_SWITCH_EPS := 3.0  # y proximity for gate selection (matches probe)
const ARRIVE_DIST := 0.9        # horizontal arrival radius at a gate
const FINISH_DIST := 1.4        # horizontal arrival radius at the exit
const STUCK_TICKS := 70         # ~1.2s without progress -> detour
const DETOUR_TICKS := 50        # sidestep duration

var checks := 0
var fails: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("[PASS] " + label)
	else:
		fails.append(label)
		printerr("[FAIL] " + label)

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _chair_in(evac: Node) -> CharacterBody3D:
	for n in evac.get_children():
		if n is CharacterBody3D and n.is_in_group("players"):
			return n
	return null

## Current waypoint: the gate on the chair's floor, or the exit on floor 4.
func _current_target(pos: Vector3) -> Vector3:
	for g in GATES:
		if absf(pos.y - (g["y"] as float)) < TARGET_SWITCH_EPS:
			return g["pos"]
	return EXIT_TARGET

## Transform a desired world-space direction into the camera-relative input
## vector PlayerChair._handle_input expects (right*x + forward*(-y) = D).
func _steer_input(chair: CharacterBody3D, evac: Node, target: Vector3) -> Vector2:
	var D := target - chair.global_position
	D.y = 0.0
	if D.length() < 0.05:
		return Vector2.ZERO
	var dn := D.normalized()
	var cam: Camera3D = evac.get_viewport().get_camera_3d()
	if cam == null:
		return Vector2(dn.x, dn.z)  # headless fallback path in _handle_input
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var r := cam.global_transform.basis.x
	r.y = 0.0
	r = r.normalized()
	var inp := Vector2(dn.dot(r), -dn.dot(f))
	if inp.length() > 1.0:
		inp = inp.normalized()
	# Terminal approach: proportional slow-down near the target (real
	# analog-stick behavior). Full throw far away, feather touch inside
	# ~5m — prevents overshoot orbits on the slippery floor-4 lot, where
	# the ice patch eats friction and a full-speed miss circles the exit.
	var dist := D.length()
	var scalef: float = clampf(dist / 5.0, 0.25, 1.0)
	return inp * scalef

func _run() -> void:
	# Deterministic arena regardless of the machine's saved map preference
	# (process state only — never touches the saved cfg).
	var layouts = load("res://scripts/LevelLayouts.gd")
	if layouts:
		layouts.set_current("open_plan")
	# Skip the pre-match modal (single-shot suppress, like all harnesses).
	load("res://scripts/PreMatchModal.gd").suppress_next()

	var t0 := Time.get_ticks_msec()
	var evac = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame

	var chair := _chair_in(evac)
	check(chair != null, "player chair spawned in real scene")
	if chair == null:
		_finish(evac)
		return
	check(evac.get_viewport().get_camera_3d() != null, "race camera present for camera-relative steering")
	chair.set_can_move(true)

	# Modifiers are single-player runtime state; clear them so friction/
	# gravity are stock for the bot run (saved cfg is untouched — only
	# ModifierMenu.toggle() persists).
	var modifiers = load("res://scripts/RaceModifiers.gd")
	if modifiers and "selected" in modifiers:
		modifiers.selected.clear()

	var floor_reached := [false, false, false]   # y gates: >5, >11, >17
	var respawn_checked := [false, false, false]
	var finish_seen := false
	var elapsed := 0.0
	var stuck := 0
	var detour := 0
	var detour_inp := Vector2.ZERO
	var last_dist := INF
	var last_progress_pos: Vector3 = chair.global_position
	var last_gate_idx := -1

	# Free the GHOST racer: it spawns by default (ghost_enabled cfg default
	# true, NOT race-gated) and appends ITSELF to finish_order when its
	# scripted course completes (~75s) — which poisoned our finish check
	# (bot "finished" when the ghost did). It is also a nondeterministic
	# moving actor on the course. The chair must finish on its own merits.
	if "ghost_racer" in evac and evac.ghost_racer != null and is_instance_valid(evac.ghost_racer):
		evac.ghost_racer.queue_free()
		evac.ghost_racer = null
		print("[bot] ghost racer freed (finish_order must be chair-only)")

	while elapsed < TIME_BUDGET:
		await physics_frame
		elapsed += 1.0 / 60.0
		if not is_instance_valid(chair):
			break

		var pos := chair.global_position
		var target := _current_target(pos)
		var gate_idx := -1
		for gi in GATES.size():
			if target == GATES[gi]["pos"]:
				gate_idx = gi
				break

		# --- stuck detection + tangent detour (players sidestep blockers)
		if detour > 0:
			detour -= 1
			chair.set_mobile_input(detour_inp)
		else:
			if gate_idx != last_gate_idx:
				last_gate_idx = gate_idx
				stuck = 0
				last_progress_pos = pos
				last_dist = INF
			var dist := Vector2(pos.x - target.x, pos.z - target.z).length()
			if dist > last_dist - 0.05:
				stuck += 1
			else:
				stuck = 0
				last_dist = dist
			if stuck > STUCK_TICKS:
				# Sidestep along the tangent (right-hand of desired dir).
				var dirv := Vector2(target.x - pos.x, target.z - pos.z).normalized()
				var tangent := Vector2(-dirv.y, dirv.x)
				detour_inp = tangent
				detour = DETOUR_TICKS
				stuck = 0
				last_dist = INF
				print("[bot] detour at %.1fs (%.1f, %.1f, %.1f)" % [elapsed, pos.x, pos.y, pos.z])
			else:
				chair.set_mobile_input(_steer_input(chair, evac, target))

		# --- checkpoint assertions (ordered, one-shot each)
		var cy := pos.y
		if not floor_reached[0] and cy > 5.0:
			floor_reached[0] = true
			print("[bot] CHECKPOINT floor 2 at %.1fs" % elapsed)
		if not floor_reached[1] and cy > 11.0:
			floor_reached[1] = true
			print("[bot] CHECKPOINT floor 3 at %.1fs" % elapsed)
		if not floor_reached[2] and cy > 17.0:
			floor_reached[2] = true
			print("[bot] CHECKPOINT floor 4 at %.1fs" % elapsed)

		# respawn_point must advance with each elevator teleport
		for ri in 3:
			if not respawn_checked[ri] and cy > 5.0 + 6.0 * ri:
				respawn_checked[ri] = true
				var rp: Vector3 = chair.respawn_point
				var want: Vector3 = RESPAWN_EXPECT[ri]
				var ok := rp.distance_to(want) < 2.0
				check(ok, "respawn checkpoint advanced to floor %d entry (got %s)" % [ri + 2, rp])
				if not ok:
					_finish(evac)
					return

		# finish: the REAL ExitZone signal — and the finish entry must be
		# THIS chair (finish_order also receives the ghost racer, which we
		# freed, but the invariant stays strict: chair's instance id only).
		if not finish_seen:
			for entry in evac.finish_order:
				if entry.player_id == chair.get_instance_id():
					finish_seen = true
					chair.set_mobile_input(Vector2.ZERO)
					print("[bot] FINISH — chair entered ExitZone at %.1fs (real signal, chair id match)" % elapsed)
					break
			if finish_seen:
				break  # leave the WHILE loop (the inner break only left the for)

		# Guard: if the exit proxy is reached but the Area never fires,
		# keep circling inside the zone for up to 8s before giving up.
		if cy > 17.0 and Vector2(pos.x - EXIT_TARGET.x, pos.z - EXIT_TARGET.z).length() < FINISH_DIST \
				and elapsed > TIME_BUDGET - 8.0:
			pass  # inside zone; ExitZone should have fired — loop waits it out

	check(floor_reached[0], "checkpoint: floor 2 reached (elevator 1)")
	check(floor_reached[1], "checkpoint: floor 3 reached (elevator 2)")
	check(floor_reached[2], "checkpoint: floor 4 reached (elevator 3)")
	check(finish_seen, "checkpoint: FINISH — real ExitZone fired (finish_order non-empty)")
	var wall := (Time.get_ticks_msec() - t0) / 1000.0
	check(elapsed < TIME_BUDGET - 1.0, "traversal completed within %.0fs sim budget (%.1fs sim, %.1fs wall)" % [TIME_BUDGET, elapsed, wall])
	_finish(evac)

func _finish(evac: Node) -> void:
	if is_instance_valid(evac):
		evac.free()
	print("")
	if fails.is_empty():
		print("=== CHECKPOINT BOT: ALL PASS (%d checks) ===" % checks)
		quit(0)
	else:
		for f in fails:
			printerr("[BOT FAILED] " + f)
		print("=== CHECKPOINT BOT: FAILED (%d/%d) ===" % [fails.size(), checks])
		quit(1)
