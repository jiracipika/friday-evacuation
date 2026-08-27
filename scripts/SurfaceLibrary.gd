# SurfaceLibrary.gd — shared procedural surface materials for all modes.
#
# One home for the themed material recipes beyond Evacuation's
# WallMaterials/FloorMaterials pair. All recipes: static-cached, <=256px,
# mipmapped once, no shaders — mobile-cheap by construction.
class_name SurfaceLibrary
extends RefCounted

const TEX := 256
static var _cache: Dictionary = {}

## Retail checkout-lino: pale tiles with dark grout + subtle checker sheen.
static func market_lino_albedo() -> ImageTexture:
	if _cache.has("mkt_lino"):
		return _cache["mkt_lino"] as ImageTexture
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4411
	for y in TEX:
		for x in TEX:
			var col := Color(0.30, 0.30, 0.34)
			var ex := x % 128
			var ey := y % 128
			# 2x2 big lino squares with grout + faint per-tile tint wobble.
			if ex < 4 or ey < 4:
				col = col.darkened(0.5)
			var h := float(((x / 128) * 3 + (y / 128) * 7) % 4) / 4.0
			col = Color(col.r * (0.9 + 0.25 * h), col.g * (0.9 + 0.25 * h),
				col.b * (0.9 + 0.25 * h))
			var n := (rng.randf() - 0.5) * 0.06
			img.set_pixel(x, y, Color(clampf(col.r + n, 0, 1),
				clampf(col.g + n, 0, 1), clampf(col.b + n, 0, 1)))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache["mkt_lino"] = tex
	return tex

static func make_market_floor() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = market_lino_albedo()
	mat.uv1_scale = Vector3(7, 7, 1)
	mat.roughness = 0.55        # lino is semi-glossy under fluorescents
	return mat

## Warehouse loading-dock concrete: mottled gray with expansion joints.
static func dock_concrete_albedo() -> ImageTexture:
	if _cache.has("dock_conc"):
		return _cache["dock_conc"] as ImageTexture
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5522
	for y in TEX:
		for x in TEX:
			var base := 0.20
			# Large slow blotches: poured-slab mottling.
			var blotch := sin(float(x) * PI / 47.0) * sin(float(y) * PI / 61.0)
			base += blotch * 0.02
			var col := Color(base, base - 0.008, base - 0.016)
			# Expansion joints every 85px, 2px wide.
			if x % 85 < 2 or y % 85 < 2:
				col = col.darkened(0.45)
			var n := (rng.randf() - 0.5) * 0.10
			img.set_pixel(x, y, Color(clampf(col.r + n, 0, 1),
				clampf(col.g + n, 0, 1), clampf(col.b + n, 0, 1)))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache["dock_conc"] = tex
	return tex

static func make_dock_floor() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = dock_concrete_albedo()
	mat.uv1_scale = Vector3(6, 6, 1)
	mat.roughness = 0.92
	return mat

## Pizza melt: bubbly cheese surface — warm base with darker bubble spots
## and a slight directional grill sheen. Applied over the cheese disc.
static func cheese_melt_albedo() -> ImageTexture:
	if _cache.has("cheese"):
		return _cache["cheese"] as ImageTexture
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6633
	for y in TEX:
		for x in TEX:
			var col := Color(0.92, 0.78, 0.35)
			var b := float((x * x * 31 + y * y * 17) % 97) / 97.0
			if b > 0.86:
				col = col.darkened(0.35 + 0.25 * b)   # browned bubbles
			elif b < 0.08:
				col = col.lightened(0.12)             # bright molten pools
			var n := (rng.randf() - 0.5) * 0.05
			img.set_pixel(x, y, Color(clampf(col.r + n, 0, 1),
				clampf(col.g + n, 0, 1), clampf(col.b + n, 0, 1)))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache["cheese"] = tex
	return tex

static func make_cheese_surface() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = cheese_melt_albedo()
	mat.uv1_scale = Vector3(5, 5, 1)
	mat.roughness = 0.75
	return mat

## Aisle drywall for ShopSeek/Hauled perimeter walls (single warm variant).
static func make_mode_wall(tint: Color) -> StandardMaterial3D:
	var helper := load("res://scripts/WallMaterials.gd")
	if helper != null and helper.has_method("make"):
		return helper.make(tint, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	return mat

static func clear_cache() -> void:
	_cache.clear()
