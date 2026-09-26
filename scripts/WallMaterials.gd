# WallMaterials.gd — procedural office-wall surfaces for all modes.
#
# Replaces flat-color walls with a generated drywall/paint treatment:
#   - fine surface grain (simplex noise)
#   - soft vertical paint-sheen banding (wallpaper feel)
#   - warm paint tint varying per floor theme
#   - optional painted wainscot panel line baked into the texture
#
# Textures are generated once per (floor_index) and cached in a static
# Dictionary, so 4 floors cost ~4 image builds total (~50ms) and zero
# per-frame cost afterwards. Mobile-friendly: <=256px, no shader, no
# extra draw passes beyond what a plain material costs.
class_name WallMaterials
extends RefCounted

const TEX_W := 512
const TEX_H := 256

# Cache: key = floor_index -> {albedo: ImageTexture}
static var _cache: Dictionary = {}
static var _normal_cache: Dictionary = {}

## Paint tint per floor: derived from the themed-floor palette already used
## for carpets, kept desaturated so walls read as "office", not candy.
static func _paint_for_floor(floor_index: int) -> Color:
	var paints: Array[Color] = [
		Color(0.62, 0.66, 0.72),  # floor 1: cool gray-blue
		Color(0.70, 0.64, 0.58),  # floor 2: warm beige
		Color(0.58, 0.66, 0.62),  # floor 3: sage
		Color(0.66, 0.60, 0.68),  # floor 4: mauve (executive)
	]
	return paints[clampi(floor_index, 0, paints.size() - 1)]

## Build (or fetch cached) albedo texture for a floor's walls.
static func wall_albedo(floor_index: int) -> ImageTexture:
	var key := clampi(floor_index, 0, 3)
	if _cache.has(key):
		return _cache[key] as ImageTexture

	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGB8)
	var paint := _paint_for_floor(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + key * 13

	for y in TEX_H:
		# Structural bands survive mip/minification; random grain does not.
		var v := float(y) / float(TEX_H)
		var baseboard := v > 0.96            # dark skirting: bottom 7cm band
		var wainscot := (not baseboard) and v > 0.78
		var trim_row := absf(v - 0.78) < 0.02
		for x in TEX_W:
			var col := paint
			var stud := (x % 128) < 2         # panel joint every 1.25m
			if baseboard:
				col = paint.darkened(0.62)
			elif trim_row:
				col = paint.darkened(0.55)
			elif wainscot:
				col = paint.darkened(0.35)
			else:
				# Vertical sheen bands: GRAPHICS PASS halved (0.10->0.05) —
				# the full-strength bands read as wavy stripes on the tall
				# walls from the chase camera (movie-frame QA).
				var band := 0.05 * sin(float(x) * TAU * 2.0 / float(TEX_W))
				col = Color(col.r + band, col.g + band, col.b + band)
			if stud and not baseboard:
				col = col.darkened(0.22)
			# Grunge: faint drip stains under the trim line and dark scuffs
			# at wainscot level — office decay, structural enough for mips.
			# ART PASS: softened (0.18/0.22 -> 0.05/0.12) — the brief calls
			# for quiet premium eggshell, and hard drip edges read as noise
			# clutter from the chase camera.
			var u := float(x) / float(TEX_W)
			var vg := float(y) / float(TEX_H)
			if not baseboard and sin(u * TAU * 3.0 + float(key) * 2.0) > 0.86 and vg < 0.45:
				col = col.darkened(0.05)
			if not baseboard and vg > 0.80 and (x / 45) % 7 == 0:
				col = col.darkened(0.12)
			# Fine grain stays modest: noise mostly vanishes under mips.
			# ART PASS: 0.09/0.16 -> 0.03/0.04 — high-frequency random bump
			# shattered into shimmer at distance; premium matte wins.
			var n := (rng.randf() - 0.5) * (0.04 if wainscot else 0.03)
			col = Color(
				clampf(col.r + n, 0.0, 1.0),
				clampf(col.g + n, 0.0, 1.0),
				clampf(col.b + n, 0.0, 1.0)
			)
			img.set_pixel(x, y, col)

	# Mipmaps are mandatory for 3D surfaces on mobile: without them distant
	# walls shimmer badly. Cheap one-time cost per floor texture.
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Normal map mirroring the wall's structure: panel joints as grooves,
## wainscot/trim/baseboard as horizontal ledges. Derived, not painted —
## the Sobel reads the same coordinates the albedo generator uses.
static func wall_normal(floor_index: int) -> ImageTexture:
	var key := clampi(floor_index, 0, 3)
	if _normal_cache.has(key):
		return _normal_cache[key] as ImageTexture
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	var height: PackedFloat32Array = NormalGen.height_buffer(TEX_W, TEX_H, 0.5)
	for y in TEX_H:
		var v := float(y) / float(TEX_H)
		var baseboard := v > 0.96
		var wainscot := (not baseboard) and v > 0.78
		var trim_row := absf(v - 0.78) < 0.02
		for x in TEX_W:
			var stud := (x % 128) < 2
			var h := 0.5
			if baseboard:
				h = 0.56       # skirting steps forward slightly (ART: gentler)
			elif trim_row:
				h = 0.44       # trim shadow line
			elif wainscot:
				h = 0.46
			if stud and not baseboard:
				h = 0.40       # panel joint groove
			NormalGen.set_height(height, TEX_W, TEX_H, x, y, h)
	# ART PASS: plaster noise REMOVED — per-pixel random bump is
	# high-frequency shimmer under mips and fought the calm-premium
	# direction. Only the structural ledges/grooves above remain.
	var tex: ImageTexture = NormalGen.normal_texture(height, TEX_W, TEX_H, 0.6)
	_normal_cache[key] = tex
	return tex

## Full wall material: textured, satin paint finish.
static func make(base_color: Color, floor_index: int = 0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = wall_albedo(floor_index)
	mat.normal_enabled = true
	mat.normal_texture = wall_normal(floor_index)
	# ART PASS: 0.7 -> 0.38 — walls read as broad matte planes; structure
	# (wainscot/baseboard/joints) comes from the albedo bands.
	mat.normal_scale = 0.38
	# Anisotropic filtering keeps the panel joints crisp at grazing angles
	# down long 40m walls (where mip selection would otherwise smear them).
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# A BoxMesh face spans the FULL 40m wall with 0..1 UVs, so scale U by 8
	# => one tile per 5m; vertical stays 1x so wainscot lines sit at real
	# heights. NOTE: there is NO BaseMaterial3D.texture_repeat property/
	# enum in Godot 4.7 — the spatial default sampler already wraps, so
	# uv1_scale alone tiles correctly.
	mat.uv1_scale = Vector3(8, 1, 1)
	# Keep a hint of the theme color so each floor still reads distinct
	# under its own ceiling lights even though texture tints are similar.
	mat.albedo_color = Color(1, 1, 1).lerp(base_color, 0.22)
	mat.roughness = 0.82
	mat.metallic = 0.0
	return mat

## Cubicle-partition fabric: felt-like weave with subtle vertical ribbing.
static func fabric_albedo(variant: int) -> ImageTexture:
	var key := 100 + clampi(variant, 0, 2)
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGB8)
	var base: Color = [Color(0.26, 0.33, 0.40), Color(0.34, 0.30, 0.36),
		Color(0.28, 0.36, 0.32)][clampi(variant, 0, 2)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5500 + variant * 7
	for y in TEX_H:
		for x in TEX_W:
			# Weave: broad felt ribbing — ribs every 16px (2 at 512px = ~1.4m on a
	# 2.7m tile) survive mips; the old 4px ribs shattered into moiré at
	# gameplay distance (highest-frequency surface in the office).
			var rib := 0.03 if (x % 16) < 8 else -0.015
			if y % 24 == 0:
				rib -= 0.015
			var n := (rng.randf() - 0.5) * 0.04
			var d := rib + n
			img.set_pixel(x, y, Color(
				clampf(base.r + d, 0.0, 1.0),
				clampf(base.g + d, 0.0, 1.0),
				clampf(base.b + d, 0.0, 1.0)))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Ready-to-use cubicle partition material (fabric, tile per ~2.7m).
static func make_partition(variant: int = 0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = fabric_albedo(variant)
	# Fabric weave ribs as normal map — felt texture you can almost feel.
	var NormalGen: GDScript = load("res://scripts/NormalMapGen.gd")
	var key := 100 + clampi(variant, 0, 2)
	if not _normal_cache.has(key):
		# PERF: ribs (x%16<8 -> 0.54) and weave beats (y%24==0 -> 0.46)
		# filled as rects — ~43 fill_rect calls replaced 131k per-pixel
		# set_height calls. Beats stay AFTER ribs so a beat row overrides
		# the rib value on its row, exactly like the old two ifs.
		var height: PackedFloat32Array = NormalGen.height_buffer(TEX_W, TEX_H, 0.5)
		var px := 0
		while px < TEX_W:
			NormalGen.fill_rect(height, TEX_W, TEX_H, px, mini(px + 7, TEX_W - 1), 0, TEX_H - 1, 0.54)
			px += 16
		var beat := 0
		while beat < TEX_H:
			NormalGen.fill_rect(height, TEX_W, TEX_H, 0, TEX_W - 1, beat, beat, 0.46)
			beat += 24
		var ntex: ImageTexture = NormalGen.normal_texture(height, TEX_W, TEX_H, 0.012)
		_normal_cache[key] = ntex
	mat.normal_enabled = true
	mat.normal_texture = _normal_cache[key]
	mat.normal_scale = 0.35
	mat.uv1_scale = Vector3(2, 1, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.95
	mat.metallic = 0.0
	return mat

static func clear_cache() -> void:
	_cache.clear()
	_normal_cache.clear()
