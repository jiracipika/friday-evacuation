# PropMaterialsSmokeTest.gd — Phase 2 prop material verification.
#   1. Script compiles; wood/metal/plastic build with albedo+normal.
#   2. Cached (same instance returned).
#   3. Plastic tints cache separately.
#   4. Normal maps actually deviate from neutral (structure exists).
#   5. Cost: all three families < 1.5s cold.
# Run: godot --headless --path . --script scripts/PropMaterialsSmokeTest.gd
extends SceneTree

var checks_total := 0
var checks_passed := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks_total += 1
	if cond:
		checks_passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var PM = load("res://scripts/PropMaterials.gd")
	check(PM != null, "PropMaterials.gd compiles")
	PM.clear_cache()

	var wood: StandardMaterial3D = PM.wood_planks()
	check(wood != null and wood.albedo_texture != null and wood.normal_enabled \
		and wood.normal_texture != null, "wood: albedo + normal wired")
	var wood2: StandardMaterial3D = PM.wood_planks()
	check(wood == wood2, "wood cached")

	var metal: StandardMaterial3D = PM.brushed_metal()
	check(metal != null and metal.normal_enabled and metal.metallic > 0.5,
		"metal: normal wired, metallic")
	check(PM.brushed_metal() == metal, "metal cached")

	var plast: StandardMaterial3D = PM.plastic(Color(0.2, 0.4, 0.9))
	var plast2: StandardMaterial3D = PM.plastic(Color(0.2, 0.4, 0.9))
	var plast_red: StandardMaterial3D = PM.plastic(Color(0.9, 0.2, 0.2))
	check(plast == plast2, "plastic cached per tint")
	check(plast != plast_red, "different tints = different materials")

	# Normal maps deviate from neutral: sample many pixels, expect some
	# with R or G away from 0.5.
	var nimg: Image = wood.normal_texture.get_image()
	var deviating := 0
	for y in range(0, 256, 8):
		for x in range(0, 256, 8):
			var c := nimg.get_pixel(x, y)
			if absf(c.r - 0.5) > 0.02 or absf(c.g - 0.5) > 0.02:
				deviating += 1
	check(deviating > 20, "wood normal has structure (%d deviating samples)" % deviating)

	PM.clear_cache()
	var t0 := Time.get_ticks_msec()
	PM.wood_planks()
	PM.brushed_metal()
	PM.plastic(Color(0.3, 0.3, 0.3))
	var elapsed := Time.get_ticks_msec() - t0
	check(elapsed < 1500, "prop material generation %dms (< 1500ms)" % elapsed)

	PM.clear_cache()
	check(failures.is_empty(), "no failures")
	print("PropMaterialsSmokeTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
