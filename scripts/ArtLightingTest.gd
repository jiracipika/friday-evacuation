extends SceneTree

var checks: int = 0
var failures: int = 0

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func _run() -> void:
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var scene: Node = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var world: WorldEnvironment = scene.get_node("WorldEnvironment")
	check(world.environment.ambient_light_energy >= 0.4 and world.environment.ambient_light_energy <= 0.65,
		"ambient supports readable shadow masses without flattening warm pools")
	check(world.environment.ambient_light_color.b > world.environment.ambient_light_color.r,
		"cool ambient contrasts warm fixtures")
	var total: int = 0
	for floor_y in [0, 6, 12, 18]:
		var group: Node = scene.get_node("CeilingLights_%d" % floor_y)
		var lights: Array = group.find_children("*", "OmniLight3D", true, false)
		check(lights.size() == 9, "floor %d retains existing nine-light budget" % floor_y)
		var minimum: float = INF
		var maximum: float = 0.0
		var safe: bool = true
		for light: OmniLight3D in lights:
			total += 1
			minimum = minf(minimum, light.light_energy)
			maximum = maxf(maximum, light.light_energy)
			safe = safe and not light.shadow_enabled and light.omni_range <= 16.0
		check(maximum - minimum > 0.15, "floor %d has deliberate light hierarchy" % floor_y)
		check(safe, "floor %d local pools have bounded range and no shadows" % floor_y)
	check(total == 36, "no added ceiling lights")

	# --- ART DIRECTION GATE: OFF pins the pre-slice scene ----------------
	# Standard/LOW must render identically to before the slice: no warm-pool
	# containers anywhere and exact base grid colors restored on floor 3.
	scene.set_art_direction_lighting(false)
	await process_frame
	var pools_off := 0
	for child in scene.get_children():
		if String(child.name).begins_with("ArtPools_F"):
			pools_off += 1
	check(pools_off == 0, "gate OFF removes every ArtPools container")
	var tint_restored := true
	var stair_group: Node = scene.get_node("CeilingLights_12")
	for light in stair_group.find_children("*", "OmniLight3D", true, false):
		if light.has_meta("base_color") \
				and (light as OmniLight3D).light_color != (light.get_meta("base_color") as Color):
			tint_restored = false
	check(tint_restored, "gate OFF restores exact stairwell base colors")

	# --- ART DIRECTION GATE: ON builds the cull-registered warm pools ----
	scene.set_art_direction_lighting(true)
	await process_frame
	var pools_on := 0
	for child in scene.get_children():
		if String(child.name).begins_with("ArtPools_F"):
			pools_on += 1
	check(pools_on == 4, "gate ON builds one ArtPools container per floor")
	var cull_registered := true
	for floor_index in range(4):
		var found := false
		for node in scene._floor_groups.get(floor_index, []):
			if String(node.name).begins_with("ArtPools_F"):
				found = true
		cull_registered = cull_registered and found
	check(cull_registered, "ArtPools containers ride the floor culling groups")
	var art_lights: Array = []
	for floor_index in range(4):
		var pools: Node = scene.get_node("ArtPools_F%d" % floor_index)
		art_lights.append_array(pools.find_children("*", "OmniLight3D", true, false))
	var expected_pools := 3  # one warm pool per portal EXIT sign
	for pu in scene._pickups:
		if is_instance_valid(pu):
			expected_pools += 1
	check(art_lights.size() == expected_pools,
		"one pool per EXIT sign + per live pickup (%d == %d)" % [art_lights.size(), expected_pools])
	var pool_safe := true
	var pool_warm := true
	for light in art_lights:
		var l := light as OmniLight3D
		pool_safe = pool_safe and not l.shadow_enabled and l.omni_range <= 5.0
		pool_warm = pool_warm and l.light_color.r > l.light_color.b
	check(pool_safe, "art pools are small-range and shadow-free")
	check(pool_warm, "art pools read warm (guide-light language)")
	# Warm pool per pickup must sit at the pickup's spawn XZ (it never moves
	# in XZ), pendant-height over the carpet — not orbiting with the bobbing
	# pickup and not saturating the texels directly beneath it.
	var pickup_pool_ok := true
	for pu in scene._pickups:
		if not is_instance_valid(pu):
			continue
		var matched := false
		for light in art_lights:
			var l := light as OmniLight3D
			var dxz := Vector2(l.position.x, l.position.z).distance_to(Vector2(pu.position.x, pu.position.z))
			if dxz < 0.6 and absf(l.position.y - (float(pu.get("base_y")) + 0.9)) < 0.1:
				matched = true
		pickup_pool_ok = pickup_pool_ok and matched
	check(pickup_pool_ok, "every pickup has its warm pool at the spawn XZ")

	# --- STAIRWELL COOL TINT (Enhanced only) -----------------------------
	# Colors shift cooler on floor 3's grid; energies stay put so the
	# deliberate hierarchy survives (checked live, same frame — the random
	# flicker pulse only ever touches energy, never color).
	var tinted := 0
	for light in stair_group.find_children("*", "OmniLight3D", true, false):
		if not light.has_meta("base_color"):
			continue
		if (light as OmniLight3D).light_color != (light.get_meta("base_color") as Color):
			tinted += 1
		var cooler := (light as OmniLight3D).light_color
		var base := light.get_meta("base_color") as Color
		if (light as OmniLight3D).light_color != base:
			# Cooler = warm red pulled down, blue never pulled down (lane
			# lights start at b=1.0, so blue can only hold or rise).
			check(cooler.r < base.r and cooler.b >= base.b,
				"stairwell tint moves toward blue on role %s" % String(light.get_meta("light_role")))
	check(tinted > 0, "gate ON tints the stairwell grid cooler")
	var other_floor_groups_cool := true
	for floor_y in [0, 6, 18]:
		for light in scene.get_node("CeilingLights_%d" % floor_y).find_children("*", "OmniLight3D", true, false):
			if light.has_meta("base_color") \
					and (light as OmniLight3D).light_color != (light.get_meta("base_color") as Color):
				other_floor_groups_cool = false
	check(other_floor_groups_cool, "tint never leaks onto office floors")

	# --- FLICKER MATCHED PULSE (world-density pass wiring, pinned here) --
	# The flicker is NOT emissive-only: every flagged troffer must have a
	# sibling grid OmniLight at the same XZ for _tick_light_flicker to dim
	# in rhythm (one flickering troffer per floor minimum, one light each).
	var flicker_wired := true
	var flicker_floors := {}
	for floor_y in [0, 6, 12, 18]:
		var group: Node = scene.get_node("CeilingLights_%d" % floor_y)
		for panel in group.find_children("*", "MeshInstance3D", true, false):
			if not panel.has_meta("flicker"):
				continue
			flicker_floors[floor_y] = true
			var panel_xz := Vector2(panel.position.x, panel.position.z)
			var has_sibling := false
			for candidate in group.find_children("*", "OmniLight3D", true, false):
				if Vector2(candidate.position.x, candidate.position.z).distance_to(panel_xz) < 0.5:
					has_sibling = true
			flicker_wired = flicker_wired and has_sibling
	check(flicker_wired, "every flicker troffer has a matched grid light at its XZ")
	check(flicker_floors.size() == 4, "each floor has at least one flicker troffer")

	# --- LIVE FLICKER PULSE: the matched OmniLight really dips -----------
	# Force an event (_flicker_t <= 0 makes the next tick fire) and sample
	# grid-light energies across the pulse window with WALL timers — headless
	# frame counts accumulate almost no wall time, so timers are the only
	# honest clock for the tween-driven pulse.
	var all_grid_lights: Array = []
	var base_energies := {}
	for floor_y in [0, 6, 12, 18]:
		for light in scene.get_node("CeilingLights_%d" % floor_y).find_children("*", "OmniLight3D", true, false):
			all_grid_lights.append(light)
			base_energies[light.get_instance_id()] = (light as OmniLight3D).light_energy
	scene._flicker_t = 0.0
	scene._tick_light_flicker(0.016)
	var min_energies := {}
	for light in all_grid_lights:
		min_energies[light.get_instance_id()] = (light as OmniLight3D).light_energy
	for i in range(16):
		await create_timer(0.04).timeout
		for light in all_grid_lights:
			var id: int = light.get_instance_id()
			min_energies[id] = minf(min_energies[id], (light as OmniLight3D).light_energy)
	var dipped := false
	for light in all_grid_lights:
		var id: int = light.get_instance_id()
		dipped = dipped or min_energies[id] < float(base_energies[id]) * 0.5
	check(dipped, "flicker pulse dips a matched OmniLight to half energy")
	var restored := true
	for light in all_grid_lights:
		var id: int = light.get_instance_id()
		restored = restored and absf((light as OmniLight3D).light_energy - float(base_energies[id])) < 0.01
	check(restored, "flicker pulse restores every grid light's base energy")

	scene.queue_free()
	await process_frame
	print("ArtLightingTest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 and checks > 0 else 1)
