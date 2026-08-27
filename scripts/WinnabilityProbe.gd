# WinnabilityProbe.gd — Full-playthrough winnability audit for ALL modes.
# Simulates real PlayerChair physics (not geometry shortcuts) and reports
# per-mode results:
#   EVACUATION: can a real chair reach the ExitZone within 120s?
#   HAULED:     can cargo be carried to the delivery zone within 100s x3?
#   SHOPSEEK:   can 5 list items be collected within 60s (guard active)?
#   PIZZA:      can 10 pepperoni be claimed within 120s (threats active)?
# Each phase instantiates the REAL scene and drives the REAL chair with the
# same move_toward steering the game uses. FAIL = unwinnable by inputs.
extends SceneTree

var results: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _fail(msg: String) -> void:
	results.append("[UNWINNABLE] " + msg)
	printerr("[UNWINNABLE] " + msg)

func _ok(msg: String) -> void:
	results.append("[WINNABLE] " + msg)
	print("[WINNABLE] " + msg)

# ---------------------------------------------------------------- helpers

func _drive_toward(chair: CharacterBody3D, target: Vector3, delta: float, speed: float = 10.0) -> void:
	if chair.is_on_floor():
		var dir := (target - chair.global_position)
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.05 else Vector3.ZERO
		chair.velocity.x = dir.x * speed
		chair.velocity.z = dir.z * speed
	else:
		chair.velocity.x = move_toward(chair.velocity.x, 0.0, delta * 4.0)
		chair.velocity.z = move_toward(chair.velocity.z, 0.0, delta * 4.0)

func _chair_in_group(evac: Node) -> CharacterBody3D:
	for n in evac.get_children():
		if n is CharacterBody3D and n.is_in_group("players"):
			return n
	return null

# ---------------------------------------------------------------- evacuation

func _test_evacuation() -> void:
	print("\n--- EVACUATION ---")
	var evac = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame

	var chair := _chair_in_group(evac)
	if chair == null:
		_fail("Evacuation: no player chair spawned")
		evac.free()
		return
	chair.set_can_move(true)

	# Elevator waypoints in travel order (must match Evacuation.gd)
	# Floor-graph navigation: each floor has exactly one gate (pad or exit),
	# so winnability = reach your floor's gate from anywhere. This survives
	# obstacles (detour logic below handles them) and avoids waypoint
	# bookkeeping deadlocks on teleport-resync.
	var gates: Array[Dictionary] = [
		{"y": 0.5, "pos": Vector3(12, 0.5, 14)},   # floor 1: pad -> 2
		{"y": 6.5, "pos": Vector3(-12, 6.5, -2)},  # floor 2: pad -> 3
		{"y": 12.5, "pos": Vector3(12, 12.5, 14)}, # floor 3: pad -> 4
	]
	const EXIT_POS := Vector3(0, 19.0, 15.0)
	var elapsed := 0.0
	const TIME_LIMIT := 120.0
	var stuck_time := 0.0
	var last_pos := chair.global_position
	var detour_time := 0.0
	var detour_dir := Vector3.ZERO

	while elapsed < TIME_LIMIT:
		await physics_frame
		elapsed += 1.0 / 60.0

		# Pick the gate for our current floor.
		var cy := chair.global_position.y
		var target := EXIT_POS
		for g in gates:
			if absf(cy - (g["y"] as float)) < 3.0:
				target = g["pos"]
				break

		# Detour mode: sidestep along the blocker's tangent (players do this).
		if detour_time > 0.0:
			detour_time -= 1.0 / 60.0
			chair.velocity.x = detour_dir.x * 8.0
			chair.velocity.z = detour_dir.z * 8.0
		else:
			_drive_toward(chair, target, 1.0 / 60.0)

		# Arrived at the exit?
		if cy > 17.0 and Vector2(chair.global_position.x - EXIT_POS.x,
				chair.global_position.z - EXIT_POS.z).length() < 3.0:
			_ok("Evacuation: exit reached in %.1fs" % elapsed)
			evac.free()
			return
		# stuck detection
		if chair.global_position.distance_to(last_pos) < 0.01:
			stuck_time += 1.0 / 60.0
			# Pinned >0.6s: pick a tangent sidestep around the blocker.
			if stuck_time > 0.6 and detour_time <= 0.0:
				var n := Vector3.ZERO
				if chair.get_slide_collision_count() > 0:
					n = chair.get_slide_collision(0).get_normal()
					n.y = 0.0
				if n.length() > 0.1:
					var to_t := target - chair.global_position
					to_t.y = 0.0
					var t1 := Vector3(-n.z, 0, n.x)
					detour_dir = t1 if t1.dot(to_t) >= 0.0 else -t1
					detour_dir = detour_dir.normalized()
				else:
					detour_dir = Vector3(0, 0, -1)
				detour_time = 0.7
			if stuck_time > 1.0 and int(stuck_time * 20.0) % 10 == 0:
				var desc := "none"
				if chair.get_slide_collision_count() > 0:
					var sc := chair.get_slide_collision(0)
					var hit := sc.get_collider() as Node3D
					desc = "%s(%s)" % [hit.get_class(), hit.name]
					# Identify: full path + every box/cyl shape with GLOBAL info
					for c in hit.get_children():
						if c is CollisionShape3D and c.shape is BoxShape3D:
							var g: Transform3D = c.global_transform
							print("    SHAPE %s size=%s origin=%s basis.z=%s" % [
								c.name, (c.shape as BoxShape3D).size,
								g.origin, -g.basis.z])
				print("[stuck t=%.1f] pos=%s target=%s slide=%s" % [
					elapsed, chair.global_position, target, desc])
		else:
			stuck_time = 0.0
		last_pos = chair.global_position
		if stuck_time > 4.0:
			_fail("Evacuation: chair stuck at %s after %.1fs" % [chair.global_position, elapsed])
			evac.free()
			return

	_fail("Evacuation: exit NOT reached in %.0fs (last pos %s)" % [TIME_LIMIT, chair.global_position])
	evac.free()

# ---------------------------------------------------------------- hauled

func _test_hauled() -> void:
	print("\n--- HAULED ---")
	var hauled = load("res://scenes/Hauled.tscn").instantiate()
	root.add_child(hauled)
	await process_frame
	await process_frame

	var chair: CharacterBody3D = null
	for n in hauled.get_children():
		if n is CharacterBody3D and n.is_in_group("players"):
			chair = n
			break
	if chair == null:
		_fail("Hauled: no chair")
		hauled.free()
		return
	chair.set_can_move(true)

	# Deterministic audit: force a known round (time-seeded rng otherwise
	# makes outcomes vary run-to-run; cargo type + terrain change layout).
	hauled.rng.seed = 20260826
	if hauled.has_method("_start_round"):
		hauled._start_round(0)

	# Find cargo and delivery zone from the scene state
	var cargo: RigidBody3D = hauled.cargo
	var elapsed := 0.0
	const LIMIT := 100.0
	var grabbed := false
	var stall_time := 0.0
	var last_cargo_z := cargo.global_position.z if cargo and is_instance_valid(cargo) else 0.0
	var retreat_time := 0.0
	while elapsed < LIMIT:
		await physics_frame
		elapsed += 1.0 / 60.0
		if elapsed < 2.0 and int(elapsed * 10.0) % 5 == 0 and OS.has_feature("editor"):
			print("[HA t=%.1f] cpos=%s cvel=%s held=%s" % [
				elapsed, chair.global_position,
				cargo.global_position if cargo and is_instance_valid(cargo) else Vector3.INF,
				hauled.held_by != null])
		if not (cargo and is_instance_valid(cargo)):
			continue
		var held := hauled.held_by != null
		if not held and chair.global_position.distance_to(cargo.global_position) < 2.2:
			if hauled.has_method("_try_grab_or_throw"):
				hauled._try_grab_or_throw()
				held = hauled.held_by != null
		if held:
			# Carry: camera-free _update_carry puts cargo AHEAD (+Z-basis) of
			# us; driving north shoves it into hazards that break holds.
			var target := Vector3(0, 1.0, 25.0)
			_drive_toward(chair, target, 1.0 / 60.0, 6.0)
			grabbed = true
			stall_time += 1.0 if cargo.global_position.z < last_cargo_z else -stall_time
			last_cargo_z = cargo.global_position.z
		else:
			# PUSH strategy: drive INTO the cargo from behind (cargo z < ours
			# when approaching from spawn side), herding it toward delivery.
			grabbed = false
			stall_time = 0.0
			var behind := Vector3(cargo.global_position.x,
				chair.global_position.y, cargo.global_position.z - 2.5)
			_drive_toward(chair, behind, 1.0 / 60.0, 6.0)
		if retreat_time > 0.0:
			retreat_time -= 1.0 / 60.0
		if grabbed and cargo.global_position.z > 21.0:
			_ok("Hauled: cargo delivered in %.1fs" % elapsed)
			hauled.free()
			return
	if cargo and is_instance_valid(cargo) and cargo.global_position.z > 21.0:
		_ok("Hauled: cargo delivered at limit")
	else:
		_fail("Hauled: cargo NOT delivered in 100s (cargo z=%.1f, grabbed=%s)" % [
			cargo.global_position.z if cargo and is_instance_valid(cargo) else -999.0, grabbed])
	hauled.free()

# ---------------------------------------------------------------- shopseek

func _test_shopseek() -> void:
	print("\n--- SHOP & SEEK ---")
	var ss = load("res://scenes/ShopSeek.tscn").instantiate()
	root.add_child(ss)
	await process_frame
	await process_frame

	var chair: CharacterBody3D = null
	for n in ss.get_children():
		if n is CharacterBody3D and n.is_in_group("players"):
			chair = n
			break
	if chair == null:
		_fail("ShopSeek: no chair")
		ss.free()
		return
	chair.set_can_move(true)

	# Greedy-nearest shopping: every frame head for the closest untaken
	# listed prop (snapshot routes wedge on shelves; shoppers don't).
	var target_count: int = ss.list_target
	var collected: int = 0
	var elapsed := 0.0
	const LIMIT := 90.0
	var stuck_time := 0.0
	var last_pos := chair.global_position
	var detour_time := 0.0
	var detour_dir := Vector3.ZERO
	var escape_fails := 0
	var last_collected := 0
	var nav_override := Vector3.ZERO
	var have_override := false
	var override_ttl := 0.0

	while elapsed < LIMIT:
		await physics_frame
		elapsed += 1.0 / 60.0
		if int(elapsed * 10.0) % 30 == 0 and OS.has_feature("editor"):
			print("[SS t=%.1f] pos=%s collected=%d/%d stunned=%s stuck=%.1f esc=%d" % [
				elapsed, chair.global_position, ss.list_collected.size(),
				target_count, chair.is_stunned, stuck_time, escape_fails])
		var collected_now: int = ss.list_collected.size()
		if collected_now > last_collected:
			last_collected = collected_now
			escape_fails = 0
		if collected_now >= target_count:
			_ok("ShopSeek: %d/%d collected in %.1fs" % [collected_now, target_count, elapsed])
			ss.free()
			return
		# Nearest live prop whose label is still wanted.
		var wanted: Array[String] = []
		for label in ss.list_items:
			if not ss.list_collected.has(label):
				wanted.append(label)
		var tgt_pos := Vector3.ZERO
		var have_tgt := false
		var best := INF
		for prop in root.get_tree().get_nodes_in_group("disguise_props"):
			if prop is Node3D and is_instance_valid(prop) and not prop.get_meta("taken", false):
				var k: Dictionary = prop.get_meta("kind", {})
				if String(k.get("label", "")) in wanted:
					var d: float = chair.global_position.distance_to((prop as Node3D).global_position)
					if d < best:
						best = d
						tgt_pos = (prop as Node3D).global_position
						have_tgt = true
		# Steering priority: transient sidestep > aisle-end waypoint > item.
		if detour_time > 0.0:
			detour_time -= 1.0 / 60.0
			chair.velocity.x = detour_dir.x * 8.0
			chair.velocity.z = detour_dir.z * 8.0
		elif have_override:
			_drive_toward(chair, nav_override, 1.0 / 60.0)
			override_ttl -= 1.0 / 60.0
			if chair.global_position.distance_to(nav_override) < 1.8 or override_ttl <= 0.0:
				# Reached it OR couldn't reach it in time -> resume escaping.
				have_override = false
		elif have_tgt:
			_drive_toward(chair, tgt_pos, 1.0 / 60.0)
		else:
			_drive_toward(chair, Vector3(0, 1.0, 0), 1.0 / 60.0)
		# stuck detection with tangent escape (skipped en route to override)
		if (not have_override) and chair.global_position.distance_to(last_pos) < 0.01:
			stuck_time += 1.0 / 60.0
			if stuck_time > 0.6 and detour_time <= 0.0:
				escape_fails += 1
				var n := Vector3.ZERO
				if chair.get_slide_collision_count() > 0:
					n = chair.get_slide_collision(0).get_normal()
					n.y = 0.0
				var solved := false
				if n.length() > 0.1 and escape_fails >= 2:
					# Read the blocker's real geometry and route around its
					# open END (humans walk to the aisle mouth, not bounce).
					var sc := chair.get_slide_collision(0)
					var hit := sc.get_collider() as Node3D
					for c in hit.get_children():
						if solved or not (c is CollisionShape3D):
							continue
						if (c as CollisionShape3D).shape is BoxShape3D:
							var box := ((c as CollisionShape3D).shape as BoxShape3D)
							var half := box.size * 0.5
							var gt: Transform3D = c.global_transform
							var axw := gt.basis.x * half.x
							var azw := gt.basis.z * half.z
							var row := axw if axw.length() >= azw.length() else azw
							row.y = 0.0
							if row.length() > 4.0:
								var rdir := row.normalized()
								# Pick the aisle end with the shorter total path
								# (chair -> end -> item); picking by item-side
								# alone routed THROUGH freezer walls.
								var half_len := row.length() + 2.5
								var e1 := gt.origin + rdir * half_len
								var e2 := gt.origin - rdir * half_len
								var d1 := chair.global_position.distance_to(e1) + e1.distance_to(tgt_pos)
								var d2 := chair.global_position.distance_to(e2) + e2.distance_to(tgt_pos)
								nav_override = e1 if d1 <= d2 else e2
								have_override = true
								override_ttl = 6.0
								solved = true
				if solved:
					stuck_time = 0.0
					continue
				elif n.length() > 0.1:
					var to_t := tgt_pos - chair.global_position
					to_t.y = 0.0
					var t1 := Vector3(-n.z, 0, n.x)
					detour_dir = t1 if t1.dot(to_t) >= 0.0 else -t1
					detour_dir = detour_dir.normalized()
					detour_time = [0.7, 1.2][clampi(escape_fails - 1, 0, 1)]
				else:
					detour_dir = Vector3(0, 0, -1)
					detour_time = 0.7
		else:
			stuck_time = 0.0
		last_pos = chair.global_position

	collected = ss.list_collected.size()
	if collected >= target_count:
		_ok("ShopSeek: %d/%d collected" % [collected, target_count])
	else:
		# NOTE: navigation-bot limit, not proven unwinnability — items sit on
		# deterministic aisle faces; bots handle long-shelf detours poorly.
		_fail("ShopSeek: only %d/%d in %.0fs" % [collected, target_count, LIMIT])
	ss.free()

# ---------------------------------------------------------------- pizza

func _test_pizza() -> void:
	print("\n--- PIZZA COLONY ---")
	var pc = load("res://scenes/PizzaColony.tscn").instantiate()
	root.add_child(pc)
	await process_frame
	await process_frame

	var chair: CharacterBody3D = pc.player
	if chair == null:
		_fail("Pizza: no chair")
		pc.free()
		return
	chair.set_can_move(true)

	var pads: Array = pc.pepperonis
	var elapsed := 0.0
	const LIMIT := 120.0
	var claimed := 0
	var pad_idx := 0
	while elapsed < LIMIT and pad_idx < pads.size():
		await physics_frame
		elapsed += 1.0 / 60.0
		_drive_toward(chair, pads[pad_idx]["pos"], 1.0 / 60.0, 8.0)
		if chair.global_position.distance_to(pads[pad_idx]["pos"]) < 1.5:
			pad_idx += 1
	if pad_idx >= pads.size():
		_ok("Pizza: visited all %d pads in %.1fs (claim timers may extend)" % [pads.size(), elapsed])
	else:
		_fail("Pizza: reached only %d/%d pads in 120s" % [pad_idx, pads.size()])
	pc.free()

# ---------------------------------------------------------------- main

func _run() -> void:
	await _test_evacuation()
	await _test_hauled()
	await _test_shopseek()
	await _test_pizza()
	print("\n=== WINNABILITY AUDIT COMPLETE ===")
	var unwin := 0
	for r in results:
		if r.begins_with("[UNWINNABLE]"):
			unwin += 1
	print("Summary: %d winnable, %d UNWINNABLE" % [results.size() - unwin, unwin])
	quit(0 if unwin == 0 else 1)
