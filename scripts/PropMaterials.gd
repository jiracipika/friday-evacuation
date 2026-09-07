# PropMaterials.gd — shared procedural materials for props (Phase 2).
#
# Desks, file cabinets, vending machines, plants, elevators all used to
# build flat-color or lone-noise materials ad hoc. This script owns three
# reusable surface families, each with a DERIVED NORMAL MAP so props read
# with real depth under the ceiling lights:
#   wood_planks()   — desk wood: plank seams + grain streaks
#   brushed_metal() — cabinets/vending: fine horizontal brushing
#   plastic()       — chair shells/trash bins: matte, faint grain
#
# All textures 256px, generated once, cached statically (same policy as
# WallMaterials). Mobile-friendly: no extra passes, normal rides the
# existing material.
class_name PropMaterials
extends RefCounted

const TEX := 256
static var _cache: Dictionary = {}


## Shared height->material pipeline: build albedo + normal in one go.
## `paint(buf, x, y)` fills the caller's albedo color at (x, y); the
## caller ALSO writes the height via `set_h` so structure stays in sync.
static func _build_material(height: PackedFloat32Array, albedo: Image,
		tex_size: int, normal_strength: float) -> StandardMaterial3D:
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	var ntex: ImageTexture = NormalGen.normal_texture(height, tex_size, tex_size, normal_strength)
	# A mipmapped sampler cannot invent mip levels on ImageTexture.
	albedo.generate_mipmaps()
	var atex := ImageTexture.create_from_image(albedo)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = atex
	mat.normal_enabled = true
	mat.normal_texture = ntex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


## Desk wood: horizontal planks (32px each) with 1px seams and vertical
## grain streaks. Warm walnut base.
static func wood_planks() -> StandardMaterial3D:
	if _cache.has("wood"):
		return _cache["wood"]
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	var height: PackedFloat32Array = NormalGen.height_buffer(TEX, TEX, 0.5)
	var albedo := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8101
	for y in TEX:
		var plank := float(y) / 32.0
		var plank_id := int(plank)
		var in_seam := (y % 32) < 1
		# Per-plank tone offset — each plank slightly different warmth.
		var tone := 0.9 + 0.2 * absf(sin(float(plank_id) * 12.9898))
		for x in TEX:
			var col := Color(0.34, 0.23, 0.13)
			col = col.lightened(0.06 * (tone - 1.0) * 8.0)
			# Grain streaks: sin-based vertical bands + per-pixel jitter.
			var grain := sin(float(x) * 0.55 + float(plank_id) * 3.7) * 0.03
			var n := (rng.randf() - 0.5) * 0.05
			var c := clampf(col.r + grain + n, 0.0, 1.0)
			var h := 0.5 + grain
			if in_seam:
				c *= 0.55
				h = 0.34  # seam groove
			albedo.set_pixel(x, y, Color(c, c * 0.82, c * 0.6))
			NormalGen.set_height(height, TEX, TEX, x, y, h)
	# NormalMapGen multiplies strength by texture resolution. At 256px,
	# 1.2 saturated wood ridges sideways; use shallow physical relief.
	var mat := _build_material(height, albedo, TEX, 0.018)
	mat.normal_scale = 0.25
	mat.roughness = 0.78
	_cache["wood"] = mat
	return mat


## Brushed metal: horizontal micro-scratches, cool gray, slight sheen.
static func brushed_metal() -> StandardMaterial3D:
	if _cache.has("metal"):
		return _cache["metal"]
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	var height: PackedFloat32Array = NormalGen.height_buffer(TEX, TEX, 0.5)
	var albedo := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8203
	for y in TEX:
		# Per-row brightness: brushing runs horizontally.
		var row := 0.5 + (rng.randf() - 0.5) * 0.08
		for x in TEX:
			var n := (rng.randf() - 0.5) * 0.05
			var v := clampf(0.58 + row - 0.58 + n, 0.0, 1.0)
			var c := Color(v, v * 1.02, v * 1.08)  # cool tint
			albedo.set_pixel(x, y, c)
			# Brush ridges: rows themselves are the height variation.
			NormalGen.set_height(height, TEX, TEX, x, y, 0.5 + (row - 0.5) * 4.0)
	var mat := _build_material(height, albedo, TEX, 0.9)
	mat.roughness = 0.35
	mat.metallic = 0.75
	_cache["metal"] = mat
	return mat


## Matte plastic: near-flat with faint orange-peel grain. `tint` controls
## the color (chair shell, bin, keyboard base...).
static func plastic(tint: Color) -> StandardMaterial3D:
	var key := "plastic_" + tint.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	var height: PackedFloat32Array = NormalGen.height_buffer(TEX, TEX, 0.5)
	var albedo := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8307
	for y in TEX:
		for x in TEX:
			var n := (rng.randf() - 0.5) * 0.04
			albedo.set_pixel(x, y, Color(
				clampf(tint.r + n, 0.0, 1.0),
				clampf(tint.g + n, 0.0, 1.0),
				clampf(tint.b + n, 0.0, 1.0)))
			NormalGen.set_height(height, TEX, TEX, x, y, 0.5 + n)
	var mat := _build_material(height, albedo, TEX, 0.5)
	mat.roughness = 0.85
	mat.metallic = 0.0
	_cache[key] = mat
	return mat


static func clear_cache() -> void:
	_cache.clear()
