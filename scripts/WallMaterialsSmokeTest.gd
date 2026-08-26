# WallMaterialsSmokeTest.gd — verifies the procedural wall texture system:
#   - per-floor textures differ
#   - paint tint stays in readable range (not crushed to black/blown out)
#   - wainscot panel line exists (trim darker than both neighbors)
#   - cache returns the SAME resource instance per floor
# Standalone SceneTree script (no autoloads needed).
extends SceneTree

const WM := preload("res://scripts/WallMaterials.gd")

func _init() -> void:
	var failures := PackedStringArray()
	# NOTE: no clear_cache() call here — under a concurrent editor the
	# preloaded script can resolve stale and drop statics (seen once as
	# "Nonexistent function 'clear_cache'"); cache identity checks below
	# only need same-session consistency, which holds without clearing.
	var t0: ImageTexture = WM.wall_albedo(0)
	if t0 == null:
		failures.append("wall_albedo(0) returned null")
		_finish(failures)
		return
	var img := t0.get_image()
	if img == null:
		failures.append("could not read back image data")
		_finish(failures)
		return

	# Readability: sample a grid, assert no fully-black / fully-white pixels.
	var black_px := 0
	var white_px := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c := img.get_pixel(x, y)
			if c.get_luminance() < 0.05:
				black_px += 1
			elif c.get_luminance() > 0.95:
				white_px += 1
	if black_px > 0:
		failures.append("texture has %d crushed-black samples" % black_px)
	if white_px > 0:
		failures.append("texture has %d blown-out samples" % white_px)

	# Wainscot: bottom band must be notably darker than upper field.
	var top := img.get_pixel(64, int(img.get_height() * 0.25)).get_luminance()
	var bot := img.get_pixel(64, int(img.get_height() * 0.92)).get_luminance()
	if bot >= top:
		failures.append("wainscot (%.2f) not darker than upper wall (%.2f)" % [bot, top])
	elif top - bot < 0.03:
		failures.append("wainscot contrast too subtle (%.3f)" % (top - bot))

	# Per-floor variety.
	var t1 := WM.wall_albedo(1)
	if t1 == null:
		failures.append("wall_albedo(1) returned null")
	elif t1 == t0:
		failures.append("floor 0 and 1 share one texture instance")

	# Cache identity.
	var t0_again := WM.wall_albedo(0)
	if t0_again != t0:
		failures.append("cache miss: second call returned a different instance")

	# Material wiring.
	var mat := WM.make(Color(0.5, 0.5, 0.6), 2)
	if mat.albedo_texture == null:
		failures.append("make() produced material without albedo_texture")
	elif mat.albedo_texture != WM.wall_albedo(2):
		failures.append("material does not reuse cached floor-2 texture")
	if mat.roughness <= 0.0 or mat.roughness >= 1.0:
		failures.append("roughness %.2f outside satin range" % mat.roughness)

	# Partition fabric materials.
	for variant in 3:
		var pmat := WM.make_partition(variant)
		if pmat.albedo_texture == null:
			failures.append("make_partition(%d) missing texture" % variant)
		elif pmat.uv1_scale.x < 1.0:
			failures.append("partition uv scale too small (%.1f)" % pmat.uv1_scale.x)
	var fab0 := WM.fabric_albedo(0)
	var fab1 := WM.fabric_albedo(1)
	if fab0 == null or fab1 == null:
		failures.append("fabric_albedo returned null")
	elif fab0 == fab1:
		failures.append("fabric variants 0/1 share one instance")

	_finish(failures)

func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("[PASS] WallMaterials: per-floor textures, readable range, wainscot, cache")
		quit(0)
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		quit(1)
