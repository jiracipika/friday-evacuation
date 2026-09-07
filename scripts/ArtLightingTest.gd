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
	scene.queue_free()
	await process_frame
	print("ArtLightingTest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 and checks > 0 else 1)
