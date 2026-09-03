# CheckpointBot.gd — shared traversal harness for the Evacuation bot runs.
# Extracted from CheckpointBotTest (Phase 8B) so the base test AND the
# per-skin sanity suite drive the IDENTICAL steering/assertion logic —
# no copy drift. CheckpointBotTest.gd remains the canonical suite; this
# file is a library, never added to the ladder on its own.
#
# Drives the REAL chair through the REAL scene: floor 1 -> elevator ->
# floor 2 -> elevator -> floor 3 -> elevator -> floor 4 -> ExitZone
# (finish), via chair.set_mobile_input (the touch input route).
class_name CheckpointBot
extends RefCounted

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

var checks: int = 0
var fails: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("[PASS] " + label)
	else:
		fails.append(label)
		printerr("[FAIL] " + label)

func _wait(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds).timeout

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

## One full traversal. Returns the per-skin timing stats dictionary.
## Caller owns scene setup (layout pin, modal suppress, evac instance) and
## teardown (frees evac).
func run(evac: Node, tree: SceneTree) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	await tree.process_frame
	await tree.process_frame

	var chair := _chair_in(evac)
	check(chair != null, "player chair spawned in real scene")
	if chair == null:
		return {"finished": false, "sim": TIME_BUDGET, "wall": 0.0, "jumps": 0, "gates": 0}
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
	var last_gate_idx := -1
	var gate_hits := 0

	# Free the GHOST racer: it spawns by default and appends ITSELF to
	# finish_order (~75s) — poisoning the finish check and adding a
	# nondeterministic moving actor. The chair must finish on its merits.
	if "ghost_racer" in evac and evac.ghost_racer != null and is_instance_valid(evac.ghost_racer):
		evac.ghost_racer.queue_free()
		evac.ghost_racer = null

	while elapsed < TIME_BUDGET:
		await tree.physics_frame
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
			gate_hits += 1
			print("[bot] CHECKPOINT floor 2 at %.1fs" % elapsed)
		if not floor_reached[1] and cy > 11.0:
			floor_reached[1] = true
			gate_hits += 1
			print("[bot] CHECKPOINT floor 3 at %.1fs" % elapsed)
		if not floor_reached[2] and cy > 17.0:
			floor_reached[2] = true
			gate_hits += 1
			print("[bot] CHECKPOINT floor 4 at %.1fs" % elapsed)

		# respawn_point must advance with each elevator teleport (one-shot:
		# verified right after each gate; later floors have moved on).
		for ri in 3:
			if respawn_checked[ri] or cy <= 5.0 + 6.0 * ri:
				continue
			respawn_checked[ri] = true
			var want: Vector3 = RESPAWN_EXPECT[ri]
			var rp: Vector3 = chair.respawn_point
			var ok := rp.distance_to(want) < 2.0
			check(ok, "respawn checkpoint advanced to floor %d entry (got %s)" % [ri + 2, rp])
			if not ok:
				return _stats(false, elapsed, t0, gate_hits)

		# finish: the REAL ExitZone signal — finish entry must be THIS chair.
		if not finish_seen:
			for entry in evac.finish_order:
				if entry.player_id == chair.get_instance_id():
					finish_seen = true
					chair.set_mobile_input(Vector2.ZERO)
					print("[bot] FINISH — chair entered ExitZone at %.1fs (real signal, chair id match)" % elapsed)
					break
			if finish_seen:
				break  # leave the WHILE loop (the inner break only left the for)

	check(floor_reached[0], "checkpoint: floor 2 reached (elevator 1)")
	check(floor_reached[1], "checkpoint: floor 3 reached (elevator 2)")
	check(floor_reached[2], "checkpoint: floor 4 reached (elevator 3)")
	check(finish_seen, "checkpoint: FINISH — real ExitZone fired (finish_order non-empty)")
	var stats := _stats(finish_seen, elapsed, t0, gate_hits)
	check(elapsed < TIME_BUDGET - 1.0, "traversal completed within %.0fs sim budget (%.1fs sim, %.1fs wall)" % [TIME_BUDGET, elapsed, stats["wall"]])
	return stats

func _stats(finished: bool, elapsed: float, t0: int, gates: int) -> Dictionary:
	return {
		"finished": finished,
		"sim": elapsed,
		"wall": (Time.get_ticks_msec() - t0) / 1000.0,
		"gates": gates,
	}
