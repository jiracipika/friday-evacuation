# HauledBehaviorsTest.gd — hostile-cargo personality behaviors (2026-10-05).
# Pins the three deterministic per-cargo behaviors:
#   fridge_of_bees  — bump/damage -> capped screen vision debuff (no stun)
#   haunted_sofa    — told, cooldown-spaced self-drag away from the drop zone
#   wet_cardboard   — monotone, capped soak ramp (mass up, friction down)
# All state transitions are driven through Hauled's deterministic seams
# (_register_bump / _register_cargo_damage / _tick_bee_vision / _tick_haunted);
# the mode's own _process is disabled so every step is test-controlled.
# Run: godot --headless --path . --script scripts/HauledBehaviorsTest.gd -- --test-mode
extends SceneTree

var checks := 0
var passed := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

var mode: Node3D

## Swap in a specific cargo type with pristine per-round behavior state.
## Terrain from the initial round is cleared; behaviors don't need it.
func _mount_behavior(key: String) -> void:
	mode._clear_round_nodes()
	mode.cargo_type_key = key
	mode.round_active = true
	mode.delivered_this_round = false
	mode.match_over = false
	mode.exploded = false
	mode.cargo_value = 1.0
	mode.cargo_damage_events = 0
	mode.cargo_bump_events = 0
	mode.bee_vision_timer = 0.0
	mode.soggy_steps = 0
	mode.sofa_drag_count = 0
	mode._bump_cooldown = 0.0
	mode._sofa_drag_timer = mode.SOFA_DRAG_INTERVAL
	mode._sofa_tell_shown = false
	mode._spawn_cargo(key)
	mode.held_by = null
	# Determinism seam: mode._process owns no part of the behaviors under
	# test once stopped — every transition below is driven manually.
	mode.set_process(false)
	await create_timer(0.1).timeout

func _caption_text() -> String:
	var caps := get_nodes_in_group("caption_overlays")
	if caps.is_empty():
		return ""
	var lbl: Label = caps[0].caption_label
	return lbl.text

func _run() -> void:
	var packed: PackedScene = load("res://scenes/Hauled.tscn")
	check(packed != null, "Hauled scene resource loads")
	if packed == null:
		_report()
		return
	load("res://scripts/PreMatchModal.gd").suppress_next()
	mode = packed.instantiate()
	root.add_child(mode)
	await create_timer(0.2).timeout
	check(mode.bee_overlay != null and is_instance_valid(mode.bee_overlay),
		"bee vision overlay mounted with the HUD")

	# ================= fridge of bees =================
	await _mount_behavior("fridge_of_bees")
	check(mode._behavior() == "bees", "fridge of bees exposes bees behavior")
	check(is_zero_approx(mode.bee_overlay.modulate.a), "bee vignette dormant before abuse")
	check(is_zero_approx(mode.bee_vision_timer), "no vision debuff before abuse")

	mode._register_bump(10.0)
	check(mode.cargo_bump_events == 1, "hard contact counts as a bump")
	check(mode.bee_vision_timer <= mode.BEE_VISION_DURATION
		and mode.bee_vision_timer > mode.BEE_VISION_DURATION - 1.0,
		"bump starts the vision debuff at its capped duration")
	mode._tick_bee_vision(0.0)
	check(mode.bee_overlay.modulate.a > 0.9, "vignette fully veils right after a bump")
	check(_caption_text().contains("BEES"), "bee abuse tell reaches the caption overlay")

	mode._register_bump(10.0)
	check(mode.cargo_bump_events == 1, "bump cooldown suppresses instant retrigger")

	mode._bump_cooldown = 0.0
	mode._register_bump(1.0)
	check(mode.cargo_bump_events == 1, "sub-threshold contact is not a bump")

	mode.bee_vision_timer = 0.5
	mode._tick_bee_vision(0.5)
	check(is_zero_approx(mode.bee_vision_timer), "debuff expires exactly after its duration")
	mode._tick_bee_vision(0.0)
	check(is_zero_approx(mode.bee_overlay.modulate.a), "vignette clears with the debuff")

	mode._register_bump(10.0)
	mode._bump_cooldown = 0.0
	mode._register_bump(10.0)
	check(mode.bee_vision_timer <= mode.BEE_VISION_DURATION,
		"refreshed debuff never stacks past the cap")
	check(mode.cargo_bump_events == 3, "each countable bump is recorded")

	var bees_mass: float = mode.cargo.mass
	mode._register_cargo_damage()
	check(mode.cargo_damage_events == 1, "scored damage event registered")
	check(mode.bee_vision_timer > mode.BEE_VISION_DURATION - 1.0,
		"scored damage also refreshes the bee debuff")
	check(is_equal_approx(mode.cargo.mass, bees_mass),
		"bee abuse never mutates cargo mass")

	# ================= haunted sofa =================
	await _mount_behavior("haunted_sofa")
	check(mode._behavior() == "haunted", "haunted sofa exposes haunted behavior")
	check(mode.sofa_drag_count == 0, "no drag before its timer elapses")

	mode._sofa_drag_timer = mode.SOFA_DRAG_TELL_LEAD + 0.3
	mode._tick_haunted(0.3)  # ends exactly at the tell threshold
	check(not mode._sofa_tell_shown, "sofa tell waits until T-1s")
	mode._tick_haunted(0.5)  # next tick starts inside the tell window
	check(mode._sofa_tell_shown, "sofa shows its tell before dragging")
	check(_caption_text().contains("SOFa".to_upper()), "sofa tell reaches the caption overlay")
	check(mode.sofa_drag_count == 0, "tell alone does not drag")
	mode._tick_haunted(0.4)
	check(mode._sofa_tell_shown, "tell is not re-fired inside one cycle")

	var pm := PhysicsMaterial.new()
	pm.friction = 0.0  # isolate the impulse from floor friction decay
	mode.cargo.physics_material_override = pm
	mode._tick_haunted(mode.SOFA_DRAG_TELL_LEAD + 0.05)
	check(mode.sofa_drag_count == 1, "sofa drag fires after its tell window")
	check(mode._sofa_drag_timer > mode.SOFA_DRAG_INTERVAL - 0.001,
		"drag restarts its full cooldown")
	check(_caption_text().contains("DRAGS"), "drag announcement reaches the caption overlay")
	await create_timer(0.06).timeout
	check(mode.cargo.linear_velocity.z <= 0.0,
		"drag impulse pushes the sofa away from the drop zone")

	mode.cargo.freeze = true  # carried cargo is kinematic
	var saved_timer: float = mode._sofa_drag_timer
	mode._sofa_drag_timer = 0.01
	mode._tick_haunted(0.02)
	check(mode.sofa_drag_count == 1, "carried sofa cannot drag itself")
	mode.cargo.freeze = false
	mode._sofa_drag_timer = saved_timer  # un-grab restores the pending schedule

	mode._tick_haunted(mode.SOFA_DRAG_INTERVAL - 1.0)
	check(mode.sofa_drag_count == 1, "drag honors its interval cooldown")

	# Deterministic replay: the same manual timeline yields the same count.
	await _mount_behavior("haunted_sofa")
	for i in range(8):
		mode._tick_haunted(1.0)
	check(mode.sofa_drag_count == 1, "8s timeline fires exactly one drag (7s interval)")

	# ================= wet cardboard =================
	await _mount_behavior("wet_cardboard")
	check(mode._behavior() == "wet", "wet cardboard exposes wet behavior")
	check(is_equal_approx(mode.cargo.mass, 1.0), "dry cardboard starts at base mass")

	var masses: Array[float] = [mode.cargo.mass]
	var frictions: Array[float] = [1.0]

	mode._register_cargo_damage()
	mode._register_cargo_damage()
	masses.append(mode.cargo.mass)
	frictions.append(mode.cargo.physics_material_override.friction)
	check(is_equal_approx(mode.cargo.mass, 1.6), "two soak steps add 0.3 mass each")
	check(is_equal_approx(frictions[1], 0.6), "two soak steps drop friction 0.2 each")
	check(is_equal_approx(mode.cargo_value, 1.0), "abuse seam never touches scored value")
	check(_caption_text().length() > 0, "soak tell reaches the caption overlay")

	mode._bump_cooldown = 0.0
	mode._register_bump(10.0)
	masses.append(mode.cargo.mass)
	frictions.append(mode.cargo.physics_material_override.friction)
	check(mode.cargo_bump_events == 1, "bumps feed the cardboard's soak ramp")
	check(is_equal_approx(mode.cargo.mass, 1.9), "bump step wets the cardboard further")

	mode._register_cargo_damage()
	mode._register_cargo_damage()
	masses.append(mode.cargo.mass)
	frictions.append(mode.cargo.physics_material_override.friction)
	check(is_equal_approx(mode.cargo.mass, mode.WET_MASS_CAP),
		"mass ramp caps at WET_MASS_CAP")
	check(is_equal_approx(mode.cargo.physics_material_override.friction,
		mode.WET_FRICTION_FLOOR), "friction floors at WET_FRICTION_FLOOR")

	mode._register_cargo_damage()
	mode._bump_cooldown = 0.0
	mode._register_bump(10.0)
	check(is_equal_approx(mode.cargo.mass, mode.WET_MASS_CAP),
		"mass stays capped under further abuse")
	check(is_equal_approx(mode.cargo.physics_material_override.friction,
		mode.WET_FRICTION_FLOOR), "friction stays floored under further abuse")

	var mass_mono := true
	var friction_mono := true
	for i in range(1, masses.size()):
		if masses[i] < masses[i - 1]:
			mass_mono = false
		if frictions[i] > frictions[i - 1]:
			friction_mono = false
	check(mass_mono, "mass ramp is monotone in abuse")
	check(friction_mono, "friction ramp is monotone down in abuse")
	check(mode.cargo_material != null
		and mode.cargo_material.albedo_color.r < 0.6,
		"soggy cardboard visibly darkens")

	# ================= other cargo types stay stock =================
	await _mount_behavior("exploding_cake")
	var cake_mass: float = mode.cargo.mass
	mode._register_bump(10.0)
	mode._bump_cooldown = 0.0
	mode._register_cargo_damage()
	check(is_zero_approx(mode.bee_vision_timer), "no bee debuff leaks onto other cargo")
	check(is_equal_approx(mode.cargo.mass, cake_mass), "no soak leaks onto other cargo")

	_report()

func _report() -> void:
	if failures.is_empty():
		print("=== HAULED BEHAVIORS TEST PASSED (%d checks) ===" % passed)
		quit(0)
	else:
		printerr("=== HAULED BEHAVIORS TEST FAILED (%d/%d) ===" % [failures.size(), checks])
		for f in failures:
			printerr("  [FAIL] %s" % f)
		quit(1)
