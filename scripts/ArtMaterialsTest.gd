# ArtMaterialsTest.gd — materials-slice invariants for calm premium surfaces.
#   Rejects (by sampling REAL generated textures / material params):
#     1. Excessive wall bump: wall normal map must stay near-neutral outside
#        structural features; normal_scale restrained.
#     2. Excessive floor seam contrast: grout lines visible but fine —
#        darkened-luminance ratio bounded.
#     3. Matte surfaces: roughness in calm matte range (no shiny floors/walls).
#     4. Not dark: mean wall albedo luminance above a floor for warm lighting.
#   Invariant-style bounds (broad), NOT exact-color snapshots or source greps.
# Run: godot --headless --path . --script scripts/ArtMaterialsTest.gd
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
	var WM: GDScript = load("res://scripts/WallMaterials.gd")
	var FM: GDScript = load("res://scripts/FloorMaterials.gd")
	check(WM != null and FM != null, "material scripts load")

	# --- 1. Wall normal map calmness -------------------------------------
	# Sample the flat upper-wall field (above wainscot, away from stud
	# joints/trim): normals must be near neutral (0.5,0.5). Current
	# generation has coarse plaster noise that pushes channels far off.
	var n0: ImageTexture = WM.wall_normal(0)
	check(n0 != null, "wall_normal(0) builds")
	var n_img: Image = n0.get_image()
	var max_dev := 0.0
	var sum_dev := 0.0
	var samples := 0
	for y in range(8, int(n_img.get_height() * 0.7), 4):
		for x in range(8, n_img.get_width() - 8, 4):
			if (x % 128) < 6:
				continue  # skip panel-joint grooves (structural, kept)
			var c := n_img.get_pixel(x, y)
			var dev := maxf(absf(c.r - 0.5), absf(c.g - 0.5))
			sum_dev += dev
			max_dev = maxf(max_dev, dev)
			samples += 1
	print("  wall field normal deviation: mean %.4f max %.4f (%d samples)" % [
		(sum_dev / float(samples)), max_dev, samples])
	check(max_dev < 0.20, "wall field bump bounded (max dev %.3f < 0.20)" % max_dev)
	check((sum_dev / float(samples)) < 0.05,
		"wall field bump calm on average (mean dev %.4f < 0.05)" % (sum_dev / float(samples)))

	# Structural grooves must survive (geometry kept, just gentler).
	# Sobel is central-difference, so the gradient lives on groove EDGE
	# columns (x=2..3 / x=126..127), not mid-groove — scan the strip.
	var joint_dev := 0.0
	for x in [2, 3, 4, 125, 126, 127]:
		var jc := n_img.get_pixel(x, 32)
		joint_dev = maxf(joint_dev, maxf(absf(jc.r - 0.5), absf(jc.g - 0.5)))
	check(joint_dev > 0.02,
		"panel joint groove still present (edge dev %.3f > 0.02)" % joint_dev)

	# Wall material normal_scale restrained.
	var wall_mat: StandardMaterial3D = WM.make(Color(0.5, 0.5, 0.6), 0)
	check(wall_mat.normal_scale <= 0.45,
		"wall normal_scale restrained (%.2f <= 0.45)" % wall_mat.normal_scale)
	check(wall_mat.roughness >= 0.75 and wall_mat.roughness <= 0.97,
		"wall roughness matte [0.75,0.97] (%.2f)" % wall_mat.roughness)

	# --- 2. Wall albedo: warm eggshell, not dark, grain bounded ----------
	var a0: ImageTexture = WM.wall_albedo(0)
	var a_img: Image = a0.get_image()
	# Mean luminance over the whole wall (readable warm midtone).
	var lum_sum := 0.0
	var lum_n := 0
	for y in range(4, a_img.get_height(), 4):
		for x in range(4, a_img.get_width(), 4):
			lum_sum += a_img.get_pixel(x, y).get_luminance()
			lum_n += 1
	var mean_lum := lum_sum / float(lum_n)
	# Compare actual horizontal neighbors, never the last sample of one
	# row with the first sample of the next (which crosses trim bands).
	var grain_max_swing := 0.0
	for y in range(4, 190, 4):
		for x in range(8, a_img.get_width() - 8, 4):
			if (x % 128) < 8 or (x % 128) > 120:
				continue
			var l := a_img.get_pixel(x, y).get_luminance()
			var adjacent := a_img.get_pixel(x - 1, y).get_luminance()
			grain_max_swing = maxf(grain_max_swing, absf(l - adjacent))
	print("  wall albedo mean luminance %.3f, adjacent-pixel max swing %.3f" % [
		mean_lum, grain_max_swing])
	check(mean_lum > 0.30 and mean_lum < 0.85,
		"wall albedo readable midtone (%.3f in (0.30,0.85))" % mean_lum)
	check(grain_max_swing < 0.09,
		"wall fine-grain bounded (adjacent swing %.3f < 0.09)" % grain_max_swing)

	# --- 3. Floor seams: fine, low-contrast -------------------------------
	var f0: ImageTexture = FM.floor_albedo(Color(0.2, 0.2, 0.25), 0)
	var f_img: Image = f0.get_image()
	# Grout center vs tile interior on the SAME row (seam is at x%128<3).
	var seam_lum := f_img.get_pixel(1, 64).get_luminance()
	var field_lum := f_img.get_pixel(64, 64).get_luminance()
	var seam_ratio := seam_lum / maxf(field_lum, 0.001)
	print("  floor seam lum %.3f vs field %.3f (ratio %.2f)" % [
		seam_lum, field_lum, seam_ratio])
	check(seam_ratio > 0.75 and seam_ratio < 0.98,
		"seam visible but low-contrast (ratio %.2f in (0.75,0.98))" % seam_ratio)

	# Mean floor luminance not crushed (parent adds warm/cool light).
	var fl_sum := 0.0
	var fl_n := 0
	for y in range(4, f_img.get_height(), 8):
		for x in range(4, f_img.get_width(), 8):
			fl_sum += f_img.get_pixel(x, y).get_luminance()
			fl_n += 1
	var fl_mean := fl_sum / float(fl_n)
	print("  floor albedo mean luminance %.3f" % fl_mean)
	check(fl_mean > 0.08,
		"floor albedo not crushed to black (%.3f > 0.08)" % fl_mean)

	# Floor material: matte + gentler normal.
	var floor_mat: StandardMaterial3D = FM.make(Color(0.2, 0.2, 0.25), 0)
	check(floor_mat.normal_scale <= 0.6,
		"floor normal_scale restrained (%.2f <= 0.6)" % floor_mat.normal_scale)
	check(floor_mat.roughness >= 0.85,
		"floor roughness matte (%.2f >= 0.85)" % floor_mat.roughness)
	# Floor grout groove geometry still present in normal map. Gradients
	# live on groove edges (x=2..4), not mid-groove; field is x=64.
	var fn_tex: ImageTexture = floor_mat.normal_texture
	var fn_img: Image = fn_tex.get_image()
	var f_edge_dev := 0.0
	for x in [2, 3, 4]:
		var fc := fn_img.get_pixel(x, 64)
		f_edge_dev = maxf(f_edge_dev, maxf(absf(fc.r - 0.5), absf(fc.g - 0.5)))
	var ffield := fn_img.get_pixel(64, 64)
	var ff_dev := maxf(absf(ffield.r - 0.5), absf(ffield.g - 0.5))
	print("  floor normal: groove-edge dev %.3f, field dev %.3f" % [f_edge_dev, ff_dev])
	check(f_edge_dev > ff_dev + 0.02,
		"floor grout groove geometry survives (edge>field by %.3f)" % (f_edge_dev - ff_dev))

	# Floor identities preserved: distinct per floor.
	var fa0: ImageTexture = FM.floor_albedo(Color(0.2, 0.2, 0.25), 0)
	var fa1: ImageTexture = FM.floor_albedo(Color(0.2, 0.2, 0.25), 1)
	check(fa0 != fa1, "floor textures remain per-floor distinct")

	WM.clear_cache()
	FM.clear_cache()
	check(checks_total > 0, "checks ran")
	print("ArtMaterialsTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
