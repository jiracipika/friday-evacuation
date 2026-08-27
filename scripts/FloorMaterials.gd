# FloorMaterials.gd — procedural office-floor surfaces for Evacuation.
#
# Upgrades the old flat-color+noise carpet: adds structural carpet-tile
# grid (survives mip minification, unlike noise grain), a subtle wear
# gradient per tile quarter, and keeps the themed tint so floors still
# read distinct. Static-cached like WallMaterials: one build per floor,
# zero per-frame cost. Mobile-friendly 256px, no shader.
class_name FloorMaterials
extends RefCounted

const TEX := 256
const TILE_PX := 64          # office carpet tiles ~50cm -> tile every 64px
static var _cache: Dictionary = {}

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
			# Structural tile grid: dark grout line on each tile edge —
			# this is what survives mips and kills the "flat slab" look.
			var edge_x := x % TILE_PX
			var edge_y := y % TILE_PX
			if edge_x < 3 or edge_y < 3:
				col = col.darkened(0.55)
			elif edge_x == 3 or edge_y == 3:
				col = col.darkened(0.25)
			else:
				# Per-quarter luminance jitter: tiles subtly differ, like
				# real worn carpet. Deterministic per tile coordinate.
				var h := float((tx * 73856093) ^ (ty * 19349663)) / 2147483647.0
				col = Color(col.r * (0.86 + 0.28 * h),
					col.g * (0.86 + 0.28 * h),
					col.b * (0.86 + 0.28 * h))
				# Directional nap: faint diagonal brush streaks inside tiles.
				var nap := sin(float(x + y) * PI / 11.0) * 0.05
				col = Color(col.r + nap, col.g + nap, col.b + nap)
			var n := (rng.randf() - 0.5) * 0.09
			img.set_pixel(x, y, Color(
				clampf(col.r + n, 0.0, 1.0),
				clampf(col.g + n, 0.0, 1.0),
				clampf(col.b + n, 0.0, 1.0)))

	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Full floor material: textured carpet tiles, matte finish.
## One tile spans ~2m (uv scale 8 over 40m => 5m... narrowed to 8 repeats
## of a 4x4-tile texture: 32 tiles across 40m ≈ 1.25m/tile).
static func make(base_color: Color, floor_index: int = 0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = floor_albedo(base_color, floor_index)
	mat.uv1_scale = Vector3(4, 4, 1)
	mat.albedo_color = Color(1, 1, 1)
	mat.roughness = 0.96
	mat.metallic = 0.0
	return mat

static func clear_cache() -> void:
	_cache.clear()
