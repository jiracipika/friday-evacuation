# Shared, deterministic prop surfaces. Broad grain and restrained relief keep
# furniture readable at race distance (docs/redesign/step1/ART-BIBLE.md).
# All maps are cached 256px tiles with mipmaps; no additional draw passes.
class_name PropMaterials
extends RefCounted

const TEX := 256
static var _cache: Dictionary = {}


static func _build_material(height: PackedFloat32Array, albedo: Image,
		roughness: Image, normal_strength: float) -> StandardMaterial3D:
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	# Wrapped derivatives match the periodic albedo/roughness at tile edges.
	var ntex: ImageTexture = NormalGen.normal_texture(height, TEX, TEX, normal_strength, true)
	albedo.generate_mipmaps()
	roughness.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(albedo)
	mat.roughness_texture = ImageTexture.create_from_image(roughness)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	# The map stores absolute roughness; the scalar must not darken it.
	mat.roughness = 1.0
	mat.normal_enabled = true
	mat.normal_texture = ntex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


## Laminate boards: grain follows the long horizontal axis, with gently
## wandering fibers and quiet joins. No pixel noise or baked highlights.
static func wood_planks() -> StandardMaterial3D:
	if _cache.has("wood"):
		return _cache["wood"]
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	var height: PackedFloat32Array = NormalGen.height_buffer(TEX, TEX)
	var albedo := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var roughness := Image.create(TEX, TEX, false, Image.FORMAT_L8)
	var base := Color("a86f39")
	for y in TEX:
		var v := float(y) / TEX
		var board := y / 64
		var tone := sin(float(board) * 2.4) * 0.025
		var edge := mini(y % 64, 64 - y % 64)
		var joint := 1.0 - smoothstep(0.0, 2.0, float(edge))
		for x in TEX:
			var u := float(x) / TEX
			var bend := sin(TAU * u) * 0.36 + sin(TAU * (2.0 * u + v)) * 0.12
			var grain := sin(TAU * 12.0 * v + bend)
			var fiber := sin(TAU * 28.0 * v + bend * 2.0)
			var variation := tone + grain * 0.035 + fiber * 0.012 - joint * 0.06
			albedo.set_pixel(x, y, Color(base.r, base.g, base.b) * (1.0 + variation))
			height[x + y * TEX] = 0.5 + grain * 0.018 + fiber * 0.004 - joint * 0.045
			var r := 0.56 + grain * 0.025 + joint * 0.04
			roughness.set_pixel(x, y, Color(r, r, r))
	var mat := _build_material(height, albedo, roughness, 0.015)
	mat.normal_scale = 0.10
	_cache["wood"] = mat
	return mat


## Exposed metal: broad directional brushing under a neutral cool base.
## Relief is shallow; the old resolution-scaled 0.9 strength made ridges
## almost tangent to the surface and broke up the manufactured silhouette.
static func brushed_metal() -> StandardMaterial3D:
	if _cache.has("metal"):
		return _cache["metal"]
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	var height: PackedFloat32Array = NormalGen.height_buffer(TEX, TEX)
	var albedo := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var roughness := Image.create(TEX, TEX, false, Image.FORMAT_L8)
	var base := Color("929ca2")
	for y in TEX:
		var v := float(y) / TEX
		var brush := sin(TAU * 16.0 * v) * 0.65 + sin(TAU * 29.0 * v) * 0.35
		for x in TEX:
			var u := float(x) / TEX
			var drift := sin(TAU * (u + 2.0 * v))
			albedo.set_pixel(x, y, base * (1.0 + brush * 0.018 + drift * 0.006))
			height[x + y * TEX] = 0.5 + brush * 0.012
			var r := 0.32 + brush * 0.025 + drift * 0.008
			roughness.set_pixel(x, y, Color(r, r, r))
	var mat := _build_material(height, albedo, roughness, 0.018)
	mat.normal_scale = 0.04
	mat.metallic = 1.0
	_cache["metal"] = mat
	return mat


## Molded plastic: broad, almost invisible molded waviness. Color stays
## close to its assigned tint instead of accumulating noisy pale speckles.
static func plastic(tint: Color) -> StandardMaterial3D:
	var key := "plastic_" + tint.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	var height: PackedFloat32Array = NormalGen.height_buffer(TEX, TEX)
	var albedo := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var roughness := Image.create(TEX, TEX, false, Image.FORMAT_L8)
	for y in TEX:
		var v := float(y) / TEX
		for x in TEX:
			var u := float(x) / TEX
			var wave := sin(TAU * (3.0 * u + 2.0 * v)) * 0.6 \
				+ sin(TAU * (5.0 * v - 2.0 * u)) * 0.4
			albedo.set_pixel(x, y, Color(tint.r, tint.g, tint.b) * (1.0 + wave * 0.012))
			height[x + y * TEX] = 0.5 + wave * 0.018
			var r := 0.48 + wave * 0.02
			roughness.set_pixel(x, y, Color(r, r, r))
	var mat := _build_material(height, albedo, roughness, 0.025)
	mat.normal_scale = 0.08
	_cache[key] = mat
	return mat


static func clear_cache() -> void:
	_cache.clear()
