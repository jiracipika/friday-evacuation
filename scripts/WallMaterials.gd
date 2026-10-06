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

	# PERF: x-dependent terms (sheen band color, drip-stain test, scuff
	# columns, stud joints) are identical for every row — computed once per
	# texture into per-x tables instead of 131k times. Row-dependent terms
	# (baseboard/trim/wainscot tints, grunge/scuff row gates, noise
	# amplitude) are computed once per row. The float expressions are
	# unchanged, so output stays byte-identical (verified against
	# pre-change reference buffers). Plain 64-bit Arrays, NOT packed
	# 32-bit arrays — see FloorMaterials for that quantization trap.
	var band_col: Array = []
	band_col.resize(TEX_W)
	var grunge_x: Array = []
	grunge_x.resize(TEX_W)
	var scuff_x: Array = []
	scuff_x.resize(TEX_W)
	var stud_x: Array = []
	stud_x.resize(TEX_W)
	for x in TEX_W:
		# Vertical sheen bands: GRAPHICS PASS halved (0.10->0.05) — the
		# full-strength bands read as wavy stripes on the tall walls from
		# the chase camera (movie-frame QA).
		var band := 0.05 * sin(float(x) * TAU * 2.0 / float(TEX_W))
		band_col[x] = Color(paint.r + band, paint.g + band, paint.b + band)
		grunge_x[x] = sin(float(x) / float(TEX_W) * TAU * 3.0 + float(key) * 2.0) > 0.86
		scuff_x[x] = (x / 45) % 7 == 0
		stud_x[x] = (x % 128) < 2         # panel joint every 1.25m
	var bb_col: Color = paint.darkened(0.62)
	var trim_col: Color = paint.darkened(0.55)
	var wains_col: Color = paint.darkened(0.35)

	for y in TEX_H:
		# Structural bands survive mip/minification; random grain does not.
		var v := float(y) / float(TEX_H)
		var baseboard := v > 0.96            # dark skirting: bottom 7cm band
		var wainscot := (not baseboard) and v > 0.78
		var trim_row := absf(v - 0.78) < 0.02
		var row_col: Color = paint
		var row_banded := false
		if baseboard:
			row_col = bb_col
		elif trim_row:
			row_col = trim_col
		elif wainscot:
			row_col = wains_col
		else:
			row_banded = true
		var vg45 := v < 0.45
		var vg80 := v > 0.80
		var namp := 0.04 if wainscot else 0.03
		for x in TEX_W:
			var col: Color = band_col[x] if row_banded else row_col
			if stud_x[x] and not baseboard:
				col = col.darkened(0.22)
			# Grunge: faint drip stains under the trim line and dark scuffs
			# at wainscot level — office decay, structural enough for mips.
			# ART PASS: softened (0.18/0.22 -> 0.05/0.12) — the brief calls
			# for quiet premium eggshell, and hard drip edges read as noise
			# clutter from the chase camera.
			if not baseboard and grunge_x[x] and vg45:
				col = col.darkened(0.05)
			if not baseboard and vg80 and scuff_x[x]:
				col = col.darkened(0.12)
			# Fine grain stays modest: noise mostly vanishes under mips.
			# ART PASS: 0.09/0.16 -> 0.03/0.04 — high-frequency random bump
			# shattered into shimmer at distance; premium matte wins.
			var n := (rng.randf() - 0.5) * namp
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
	# PERF: the height field is row-constant (baseboard/trim/wainscot bands)
	# plus 8 stud columns — 131k per-pixel set_height calls replaced by ~13
	# fill_rect calls derived from the SAME y/x predicates. Row spans are
	# scanned (not hardcoded) so the band edges stay whatever the predicates
	# below say; stud fills stop one row above the baseboard exactly like
	# the old `if stud and not baseboard` guard. Byte-identical output
	# (verified against pre-change reference buffers).
	var span_start := 0
	var span_h := 0.5
	for y in TEX_H + 1:
		var h := 0.5
		if y < TEX_H:
			var v := float(y) / float(TEX_H)
			if v > 0.96:       # skirting steps forward slightly (ART: gentler)
				h = 0.56
			elif absf(v - 0.78) < 0.02:  # trim shadow line
				h = 0.44
			elif v > 0.78:     # wainscot ledge
				h = 0.46
		if h != span_h or y == TEX_H:
			if span_h != 0.5:
				NormalGen.fill_rect(height, TEX_W, TEX_H,
					0, TEX_W - 1, span_start, y - 1, span_h)
			span_h = h
			span_start = y
	# First baseboard row: stud grooves never reach it (old guard).
	var bb_start := TEX_H
	for y in TEX_H:
		if float(y) / float(TEX_H) > 0.96:
			bb_start = y
			break
	var px := 0
	while px < TEX_W:
		if px % 128 < 2:  # panel joint groove, every 1.25m
			NormalGen.fill_rect(height, TEX_W, TEX_H, px, px, 0, bb_start - 1, 0.40)
		px += 1
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
	# PERF: the rib value is x-dependent only (same 16px cycle every row)
	# and the weave-beat test is y-dependent only — hoisted into per-x /
	# per-row lookups (identical float expressions, byte-identical output).
	var rib_x: Array = []
	rib_x.resize(TEX_W)
	for x in TEX_W:
		# Weave: broad felt ribbing — ribs every 16px (2 at 512px = ~1.4m on a
		# 2.7m tile) survive mips; the old 4px ribs shattered into moiré at
		# gameplay distance (highest-frequency surface in the office).
		rib_x[x] = 0.03 if (x % 16) < 8 else -0.015
	for y in TEX_H:
		var beat := y % 24 == 0
		for x in TEX_W:
			var rib: float = rib_x[x]
			if beat:
				rib = rib - 0.015
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
