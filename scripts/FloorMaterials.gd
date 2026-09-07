# FloorMaterials.gd — procedural office-floor surfaces for Evacuation.
#
# Upgrades the old flat-color+noise carpet: adds structural carpet-tile
# grid (survives mip minification, unlike noise grain), a subtle wear
# gradient per tile quarter, and keeps the themed tint so floors still
# read distinct. Static-cached like WallMaterials: one build per floor,
# zero per-frame cost. Mobile-friendly 256px, no shader.
class_name FloorMaterials
extends RefCounted

const TEX := 512
const TILE_PX := 128         # office carpet tiles ~50cm -> tile every 128px
static var _cache: Dictionary = {}
static var _normal_cache: Dictionary = {}

## Themed base tints mirror the palette Evacuation passes in; keyed by floor.
static func _base_for_floor(floor_index: int) -> Color:
	var bases: Array[Color] = [
		Color(0.15, 0.15, 0.22),   # 1: cool slate
		Color(0.18, 0.15, 0.20),   # 2: warm plum-gray
		Color(0.13, 0.16, 0.20),   # 3: steel blue (landing gaps theme)
		Color(0.10, 0.18, 0.15),   # 4: executive green-carpet
	]
	return bases[clampi(floor_index, 0, bases.size() - 1)]

## Build (or fetch cached) albedo texture for a floor's carpet.
static func floor_albedo(base_color: Color, floor_index: int) -> ImageTexture:
	var key := clampi(floor_index, 0, 3)
	if _cache.has(key):
		return _cache[key] as ImageTexture

	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3300 + key * 17
	# Theme color wins over the default table (callers pass their own).
	var paint := _base_for_floor(key).lerp(base_color, 0.5)

	for y in TEX:
		var ty := y / TILE_PX
		for x in TEX:
			var tx := x / TILE_PX
			var col := paint
			# PHASE 2 per-floor identity: traffic-lane wear — a soft
			# horizontal band across the middle of each tile row where
			# feet actually travel. Darkened + slight sheen loss. Wide
			# gaussian-ish falloff so it reads as wear, not a stripe.
			var lane := absf(float(x) - float(TEX) * 0.5) / float(TEX)
			# GRAPHICS PASS: wear amplitude halved — at 4 repeats over the
			# slab it painted one dark 10m band down EVERY floor, reading
			# as a giant diagonal smear from the chase camera.
			var lane_wear := exp(-pow(lane * 5.5, 2.0)) * 0.06
			# Structural tile grid: dark grout line on each tile edge —
			# this is what survives mips and kills the "flat slab" look.
			var edge_x := x % TILE_PX
			var edge_y := y % TILE_PX
			if edge_x < 3 or edge_y < 3:
				col = col.darkened(0.18)
			elif edge_x == 3 or edge_y == 3:
				col = col.darkened(0.08)
			else:
				# Per-quarter luminance jitter: tiles subtly differ, like real
				# worn carpet. GRAPHICS PASS: amplitude halved (0.28->0.14) —
				# at gameplay distance the old ±14% jitter banded into wavy
				# moiré across the floor (pixel-measured in movie QA).
				var h := float((tx * 73856093) ^ (ty * 19349663)) / 2147483647.0
				col = Color(col.r * (0.93 + 0.14 * h),
					col.g * (0.93 + 0.14 * h),
					col.b * (0.93 + 0.14 * h))
				# Directional nap REMOVED: a 22cm-period sine reads as
				# diagonal stripe moiré under mips; per-pixel grain below
				# carries the carpet fiber feel instead.
			# Apply traffic wear last (after grid), darkening the lane.
			col = Color(
				clampf(col.r - lane_wear, 0.0, 1.0),
				clampf(col.g - lane_wear, 0.0, 1.0),
				clampf(col.b - lane_wear, 0.0, 1.0))
			var n := (rng.randf() - 0.5) * 0.06
			img.set_pixel(x, y, Color(
				clampf(col.r + n, 0.0, 1.0),
				clampf(col.g + n, 0.0, 1.0),
				clampf(col.b + n, 0.0, 1.0)))

	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Full floor material: textured carpet tiles, matte finish.
## uv 4 over the 40m slab = 4 texture repeats; the texture carries a 4x4
## tile grid, so 16 grout crossings per edge ≈ 2.5m per carpet tile.
static func make(base_color: Color, floor_index: int = 0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = floor_albedo(base_color, floor_index)
	# Carpet tile grout lines as grooves in a normal map — the single
	# biggest "this floor has depth" win under the ceiling lights.
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	var key := clampi(floor_index, 0, 3)
	if not _normal_cache.has(key):
		var height: PackedFloat32Array = NormalGen.height_buffer(TEX, TEX, 0.5)
		for y in TEX:
			for x in TEX:
				var edge_x := x % TILE_PX
				var edge_y := y % TILE_PX
				var h := 0.5
				if edge_x < 3 or edge_y < 3:
					h = 0.42  # grout recess (ART: shallower)
				elif edge_x == 3 or edge_y == 3:
					h = 0.46  # bevel shoulder
				NormalGen.set_height(height, TEX, TEX, x, y, h)
		var ntex: ImageTexture = NormalGen.normal_texture(height, TEX, TEX, 0.01)
		_normal_cache[key] = ntex
	mat.normal_enabled = true
	mat.normal_texture = _normal_cache[key]
	# ART PASS: 0.9 -> 0.5 — seams read as fine low-contrast relief, not
	# black grid lines carved into the slab.
	mat.normal_scale = 0.5
	mat.uv1_scale = Vector3(4, 4, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.albedo_color = Color(1, 1, 1)
	mat.roughness = 0.96
	mat.metallic = 0.0
	return mat

static func clear_cache() -> void:
	_cache.clear()
	_normal_cache.clear()
