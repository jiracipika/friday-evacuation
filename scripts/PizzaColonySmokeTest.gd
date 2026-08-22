# PizzaColonySmokeTest.gd — Phase 6C survival mode verification.
# Instantiates the real scene and verifies: pizza zones, pepperoni claim
# flow (progress + steal timing), resource generation from owned pads,
# cheese harvest while standing still, sauce slow zone, fort building with
# cost gating, chef patrol + acceleration, cutter sweep + line-hit
# elimination, olive bombs, fall-off elimination, and win conditions.
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

func _run() -> void:
	var packed = load("res://scenes/PizzaColony.tscn")
	check(packed != null, "PizzaColony scene resource loads")
	if packed == null:
		_report()
		return
	var mode: Node3D = packed.instantiate()
	root.add_child(mode)
	await process_frame
	await process_frame

	# --- terrain + spawns ---
	check(mode.player != null and is_instance_valid(mode.player), "topping chair spawned")
	check(mode.chef != null and is_instance_valid(mode.chef), "chef spawned with hat")
	check(mode.cutter_mesh != null and not mode.cutter_mesh.visible, "cutter idle and hidden at start")
	check(mode.pepperonis.size() == 10, "10 pepperoni pads placed (%d)" % mode.pepperonis.size())
	check(mode._zone_at(Vector3(24, 0, 0)) == &"crust", "rim registers as crust zone")
	check(mode._zone_at(Vector3(3, 0, 0)) == &"sauce", "inner disc registers as sauce zone")
	check(mode._zone_at(Vector3(20, 0, 0)) == &"cheese", "outer plain registers as cheese zone")

	# --- claim flow ---
	var pad: MeshInstance3D = mode.pepperonis[0]["node"]
	mode.player.global_position = (mode.pepperonis[0]["pos"] as Vector3) + Vector3(0, 0.5, 0)
	mode._update_claims(1.0)
	check(float(mode.pepperonis[0]["progress"]) > 0.0, "standing on a pad accrues claim progress")
	mode._update_claims(2.5)
	check(mode.pepperonis[0]["owner"] == &"player", "3 continuous seconds claims a neutral pad")
	check(mode._progress() > 0.0, "claimed pad counts toward win progress")
	# Leaving resets the claim pointer
	var pad2: MeshInstance3D = mode.pepperonis[1]["node"]
	mode.player.global_position = (mode.pepperonis[1]["pos"] as Vector3) + Vector3(0, 0.5, 0)
	mode._update_claims(1.0)
	mode.player.global_position = Vector3(0, 1.0, 0)
	mode._update_claims(1.0)
	check(float(mode.pepperonis[1]["progress"]) == 0.0 or mode.pepperonis[1]["owner"] != &"none", "leaving a pad stops claim progress")

	# --- owned pads generate resources ---
	var cheese_before: int = mode.cheese
	mode._update_resources(mode.RESOURCE_INTERVAL + 0.01)
	check(mode.cheese > cheese_before, "owned pepperoni generates cheese over time")

	# --- harvest while still ---
	mode.player.velocity = Vector3.ZERO
	mode.player.global_position = Vector3(16, 0.5, 0)
	var cheese_h: int = mode.cheese
	mode._update_harvest(mode.HARVEST_TIME + 0.01)
	check(mode.cheese > cheese_h, "standing still on cheese harvests +2")

	# --- sauce slow zone ---
	mode.player.global_position = Vector3(3, 0.5, 0)
	mode._update_zone_speed()
	check(is_equal_approx(mode.player.carry_slowdown, mode.SAUCE_SLOW), "sauce sea applies slow movement")
	mode.player.global_position = Vector3(16, 0.5, 0)
	mode._update_zone_speed()
	check(is_equal_approx(mode.player.carry_slowdown, 1.0), "leaving sauce restores speed")

	# --- fort building ---
	mode.cheese = 0
	mode.toppings = 0
	check(mode.try_build_fort() == false, "fort refuses to build without resources")
	var forts_before := mode.get_children().filter(func(c): return c is StaticBody3D and c.name != "PizzaBase").size()
	mode.cheese = 5
	mode.toppings = 3
	check(mode.try_build_fort() == true, "fort builds with 5 cheese + 3 toppings")
	check(mode.cheese == 0 and mode.toppings == 0, "fort consumes its resources")
	var forts_after := mode.get_children().filter(func(c): return c is StaticBody3D and c.name != "PizzaBase").size()
	check(forts_after == forts_before + 1, "fort wall placed in the world (%d -> %d)" % [forts_before, forts_after])

	# --- chef patrol + acceleration ---
	var chef_ang_before := atan2(mode.chef.global_position.z, mode.chef.global_position.x)
	mode._update_chef(0.5)
	var chef_ang_after := atan2(mode.chef.global_position.z, mode.chef.global_position.x)
	check(not is_equal_approx(chef_ang_before, chef_ang_after), "chef walks the rim")
	var speed_before: float = mode.chef_speed
	mode._update_chef(5.0)
	check(mode.chef_speed > speed_before, "chef accelerates over time")

	# --- cutter sweep + line hit ---
	mode.cutter_timer = mode.CUTTER_PERIOD  # force the sweep
	mode._update_chef(0.1)
	check(mode.cutter_active and mode.cutter_mesh.visible, "cutter sweep activates periodically")
	# Stand exactly on the cutter line: line dir (cos, 0, -sin); a point along it.
	var line_point := Vector3(cos(mode.cutter_angle) * 10.0, 0.5, -sin(mode.cutter_angle) * 10.0)
	mode.player.global_position = line_point
	mode._check_cutter_hit()
	check(mode.eliminated and mode.match_over, "touching the cutter line eliminates")
	check(mode.won == false, "elimination is a loss")
	# Launch impulse applied for the comedy send-off
	check(mode.player.velocity.length() > 20.0, "elimination launches the chair off the pizza")

	# --- olive bombs ---
	# Fresh scene for the olive path (eliminated mode won't throw).
	var mode2: Node3D = packed.instantiate()
	root.add_child(mode2)
	await process_frame
	await process_frame
	# Prior instances can leave stale transforms in the packed-scene cache;
	# force the canonical spawn so this phase is independent of ordering.
	mode2.player.global_position = Vector3(0.0, 1.5, 12.0)
	mode2.olive_timer = 0.0
	mode2._update_olives(0.1)
	check(mode2.olives.size() >= 1, "chef throws olive bombs on a timer")
	check(mode2.player.is_stunned <= 0.0, "unrelated olives do not stun instantly")
	# Force a direct hit: olive lands on the player.
	mode2.olives.clear()
	mode2._throw_olive()
	mode2.player.global_position = (mode2.olives[0]["node"] as Node3D).global_position
	mode2._pop_olive(mode2.olives[0])
	check(mode2.player.is_stunned > 0.0, "olive detonation stuns players in radius")

	# --- fall-off elimination ---
	mode2.player.is_stunned = 0.0
	mode2.player.global_position = Vector3(40, 1.0, 0)  # beyond the pizza edge
	mode2._check_fell_off()
	check(mode2.eliminated, "falling off the pizza edge eliminates")

	# --- win: survive the timer ---
	var mode3: Node3D = packed.instantiate()
	root.add_child(mode3)
	await process_frame
	await process_frame
	mode3.player.global_position = Vector3(0.0, 1.5, 12.0)
	print("PROBE mode3 spawn pos=", mode3.player.global_position)
	mode3.remaining_time = 0.05
	for i in 10:
		await process_frame
		if mode3.eliminated:
			print("PROBE mode3 eliminated at frame ", i, " pos=", mode3.player.global_position)
			break
	check(mode3.match_over and mode3.won, "surviving the full timer wins")

	# --- win: claim all pepperoni ---
	var mode4: Node3D = packed.instantiate()
	root.add_child(mode4)
	await process_frame
	await process_frame
	mode4.player.global_position = Vector3(0.0, 1.5, 12.0)
	for p in mode4.pepperonis:
		p["owner"] = &"player"
	for i in 3:
		await process_frame
	check(mode4.match_over and mode4.won, "claiming every pepperoni wins")

	mode.queue_free()
	mode2.queue_free()
	mode3.queue_free()
	mode4.queue_free()
	await process_frame
	_report()

func _report() -> void:
	if failures.is_empty():
		print("=== PIZZA COLONY SMOKE TEST PASSED (%d checks) ===" % passed)
		quit(0)
	else:
		printerr("=== PIZZA COLONY SMOKE TEST FAILED (%d/%d) ===" % [failures.size(), checks])
		quit(1)
