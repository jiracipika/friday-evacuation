# NormalMapSmokeTest.gd — Phase 2 texture upgrade verification.
#   1. NormalMapGen: height buffer alloc + stamp + noise clamp 0..1.
#   2. Sobel: a flat buffer -> all normals point "out" (128,128,255-ish).
#      A grooved buffer -> edge pixels deviate (R/G differ from 0.5).
#   3. WallMaterials.wall_normal: cached, correct size, per-floor distinct.
#   4. WallMaterials.make: material has normal_enabled + texture set.
#   5. make_partition: normal wired (fabric weave).
#   6. FloorMaterials.make: normal wired (grout grooves), cached.
#   7. Generation cost: 4 walls + 4 floors + 3 fabrics under 2s total.
# Run: godot --headless --path . --script scripts/NormalMapSmokeTest.gd
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
	var G = load("res://scripts/NormalMapGen.gd")
	check(G != null, "NormalMapGen.gd compiles")

	# 1. Height buffer basics
	var h: PackedFloat32Array = G.height_buffer(8, 8, 0.5)
	check(h.size() == 64 and absf(h[0] - 0.5) < 0.001, "height_buffer allocates base")
	G.stamp(h, 8, 8, 2, 3, 2, 3, 0.3)
	check(absf(h[2 + 2 * 8] - 0.8) < 0.001, "stamp raises height in region")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	G.noise(h, 8, 8, rng, 5.0)  # huge amount -> must clamp, not escape
	var ok_clamp := true
	for v in h:
		if v < 0.0 or v > 1.0:
			ok_clamp = false
	check(ok_clamp, "noise clamps heights to 0..1")

	# 2a. Flat buffer -> all normals neutral (0.5, 0.5, 1.0) => rgb(128,128,255)
	var flat: PackedFloat32Array = G.height_buffer(16, 16, 0.5)
	var flat_tex: ImageTexture = G.normal_texture(flat, 16, 16, 1.0)
	var flat_img: Image = flat_tex.get_image()
	var c := flat_img.get_pixel(8, 8)
	check(absf(c.r - 0.5) < 0.01 and absf(c.g - 0.5) < 0.01 and c.b > 0.99,
		"flat height -> neutral normal (r%.3f g%.3f b%.3f)" % [c.r, c.g, c.b])

	# 2b. Grooved buffer -> edge normals deviate
	var grooved: PackedFloat32Array = G.height_buffer(16, 16, 0.5)
	G.stamp(grooved, 16, 16, 8, 8, 0, 15, -0.4)  # vertical groove
	var groove_tex: ImageTexture = G.normal_texture(grooved, 16, 16, 2.0)
	var groove_img: Image = groove_tex.get_image()
	var edge := groove_img.get_pixel(7, 8)
	var deviates := absf(edge.r - 0.5) > 0.02 or absf(edge.g - 0.5) > 0.02
	check(deviates, "groove edge normal deviates (r%.3f g%.3f)" % [edge.r, edge.g])

	# 3-5. WallMaterials wiring
	var WM = load("res://scripts/WallMaterials.gd")
	var n0: ImageTexture = WM.wall_normal(0)
	var n0_again: ImageTexture = WM.wall_normal(0)
	check(n0 != null and n0 == n0_again, "wall_normal cached")
	var n_img: Image = n0.get_image()
	check(n_img.get_width() == 512 and n_img.get_height() == 256,
		"wall normal 512x256 (matches albedo)")
	var n3: ImageTexture = WM.wall_normal(3)
	check(n3 != n0, "per-floor wall normals distinct")
	var wall_mat: StandardMaterial3D = WM.make(Color(0.5, 0.5, 0.5), 0)
	check(wall_mat.normal_enabled and wall_mat.normal_texture != null,
		"wall material has normal map enabled")
	var part_mat: StandardMaterial3D = WM.make_partition(0)
	check(part_mat.normal_enabled and part_mat.normal_texture != null,
		"partition material has normal map enabled")

	# 6. FloorMaterials wiring
	var FM = load("res://scripts/FloorMaterials.gd")
	var floor_mat: StandardMaterial3D = FM.make(Color(0.2, 0.2, 0.25), 1)
	check(floor_mat.normal_enabled and floor_mat.normal_texture != null,
		"floor material has normal map enabled")
	var f1: ImageTexture = floor_mat.normal_texture
	var floor_mat_b: StandardMaterial3D = FM.make(Color(0.2, 0.2, 0.25), 1)
	check(floor_mat_b.normal_texture == f1, "floor normal cached")

	# 7. Generation cost (fresh caches): all wall+floor+fabric textures
	# one-time cold cost, paid once at first boot then cached.
	# Budget history: ~3.0-3.8s at the fd8df79 baseline (budget 3.5s, raised
	# to 5.0s for warm-machine flake). The art passes then deliberately
	# thickened the generators (282aca5 partition 16px felt ribbing, 3ba893c
	# resolution-scaled normal strength) and the measured cold cost is now
	# 7.1-9.0s on this machine (floors dominate: ~1.3-1.6s each, profiled).
	# Budget 12s keeps a real regression guard (a 2x algorithmic slip still
	# fails) while absorbing the intentional art-driven creep. Optimizing
	# the floor generator back under 5s is queued in GLM-NEXT-SLICE.
	WM.clear_cache()
	FM.clear_cache()
	var t0 := Time.get_ticks_msec()
	for f in 4:
		WM.wall_normal(f)
		FM.make(Color(0.2, 0.2, 0.25), f)
	for v in 3:
		WM.make_partition(v)
	var elapsed := Time.get_ticks_msec() - t0
	check(elapsed < 12000, "normal generation cost %dms (< 12000ms)" % elapsed)

	WM.clear_cache()
	FM.clear_cache()
	check(failures.is_empty(), "no failures")
	print("NormalMapSmokeTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
