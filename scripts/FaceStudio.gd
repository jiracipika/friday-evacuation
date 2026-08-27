# FaceStudio.gd — procedural comedy faces for office-chair riders.
#
# Lethal-Company-adjacent: slightly unhinged, very readable, cheap.
# Each face is one 96x96 RGBA texture wrapped on a head sphere
# (head UVs put the front face around u=0.5), plus physical googly
# eye spheres that jiggle with chair motion (spring-damper per frame).
#
# Face variants:
#   panic      — huge white eyes, tiny pupils, gaping O mouth
#   determined — flat brow line, gritted teeth bar
#   deranged   — asymmetric huge pupils, wavy grin
#   exhausted  — half-lidded bags, squiggle mouth
#   screaming  — full black void mouth, stretched eyes
class_name FaceStudio
extends RefCounted

const TEX := 96
static var _cache: Dictionary = {}

## Deterministic variant pick from any string id.
static func variant_for(character_id: String) -> String:
	var table := ["panic", "determined", "deranged", "exhausted", "screaming"]
	var h := 0
	for c in character_id:
		h = (h * 31 + c.unicode_at(0)) % 9973
	return table[h % table.size()]

static func _skin() -> Color:
	return Color(0.94, 0.71, 0.56)  # f0b58f-ish, matches old flat tint

## Build the face texture for a variant.
static func face_albedo(variant: String) -> ImageTexture:
	var key := "face_" + variant
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	img.fill(_skin())
	var ink := Color(0.08, 0.07, 0.09)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(variant)

	## local helpers ---------------------------------------------------
	# Eyes occupy the band y in [22..48]. Pupil placement is per-variant.
	var eye_cy := 34.0
	var eye_dx := 19.0

	match variant:
		"panic":
			for e in [-1, 1]:
				_huge_eye(img, 48 + e * eye_dx, eye_cy, 15.0, Color.WHITE, ink)
				_pupil(img, 48 + e * eye_dx - 4, eye_cy + 5, 3.2, ink)
			_mouth_ellipse(img, 48, 68, 9.0, 12.0, ink)
		"determined":
			for e in [-1, 1]:
				_brow_bar(img, 48 + e * eye_dx, 20, 22, 6, ink)
				_eye(img, 48 + e * eye_dx, eye_cy, 10.0, Color.WHITE, ink)
				_pupil(img, 48 + e * eye_dx, eye_cy - 2, 4.0, ink)
			_teeth_bar(img, 62, 78, ink)
		"deranged":
			# Asymmetric pupils, lopsided wavy grin.
			_huge_eye(img, 48 - eye_dx, eye_cy, 16.0, Color.WHITE, ink)
			_pupil(img, 48 - eye_dx + 6, eye_cy - 4, 6.0, ink)
			_huge_eye(img, 48 + eye_dx, eye_cy - 4, 12.0, Color.WHITE, ink)
			_pupil(img, 48 + eye_dx - 3, eye_cy + 3, 2.0, ink)
			_wavy_mouth(img, 26, 82, 66, ink)
		"exhausted":
			for e in [-1, 1]:
				_lidded_eye(img, 48 + e * eye_dx, eye_cy, ink)
			_squiggle_mouth(img, 32, 72, 44, ink)
			_bag_lines(img, 24, 46, ink)
		"screaming":
			for e in [-1, 1]:
				_huge_eye(img, 48 + e * eye_dx, eye_cy - 2, 14.0, Color.WHITE, ink)
				_pupil(img, 48 + e * eye_dx, eye_cy - 6, 2.2, ink)
			# Void mouth: dark rounded rect, no teeth.
			for y in range(58, 84):
				for x in range(30, 66):
					var dx := float(x - 48)
					var dy := float(y - 71)
					if (dx * dx) / 324.0 + (dy * dy) / 169.0 <= 1.0:
						img.set_pixel(x, y, ink)

	# Light grime speckle so the skin isn't plastic-clean.
	for i in 40:
		var gx := rng.randi_range(0, TEX - 1)
		var gy := rng.randi_range(0, TEX - 1)
		var g := img.get_pixel(gx, gy)
		img.set_pixel(gx, gy, g.darkened(0.10))

	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Head material: skin tone only where the face texture has alpha.
## We paint a transparent EXTERIOR so the head keeps its base color away
## from the face by wrapping the face decal on a separate billboard-free
## sphere overlay instead of blending into the shared head material.
static func make_head_overlay(variant: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = face_albedo(variant)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat

## Pure-white sclera for googly eyes (with painted iris offset per side).
static func googly_texture(iris_offset_x: float) -> ImageTexture:
	var key := "googly_%d" % int(absf(iris_offset_x) * 100.0)
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var ink := Color(0.06, 0.06, 0.08)
	for y in S:
		for x in S:
			var dx := float(x - S / 2)
			var dy := float(y - S / 2)
			var d2 := dx * dx + dy * dy
			if d2 <= 225.0:
				img.set_pixel(x, y, Color(0.97, 0.97, 0.95))
			if d2 <= 40.0:
				var px := S / 2 + int(iris_offset_x)
				var py := S / 2 + 2
				if absi(x - px) <= 4 and absi(y - py) <= 4:
					img.set_pixel(x, y, ink)
				elif d2 > 40.0:
					pass
	# ring outline so eyes read on bright floors
	for y in S:
		for x in S:
			var dx := float(x - S / 2)
			var dy := float(y - S / 2)
			var d := sqrt(dx * dx + dy * dy)
			if d <= 15.5 and d >= 13.8:
				img.set_pixel(x, y, Color(0.15, 0.15, 0.18))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## --- face drawing helpers -------------------------------------------
static func _eye(img: Image, cx: float, cy: float, r: float, sclera: Color, ink: Color) -> void:
	for y in range(int(cy - r) - 1, int(cy + r) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, sclera)

static func _huge_eye(img: Image, cx: float, cy: float, r: float, sclera: Color, ink: Color) -> void:
	_eye(img, cx, cy, r, sclera, ink)
	_eye_ring(img, cx, cy, r, ink)

static func _eye_ring(img: Image, cx: float, cy: float, r: float, ink: Color) -> void:
	for y in range(int(cy - r) - 2, int(cy + r) + 2):
		for x in range(int(cx - r) - 2, int(cx + r) + 2):
			var dx := x - cx
			var dy := y - cy
			var d := sqrt(dx * dx + dy * dy)
			if d <= r + 1.5 and d >= r - 1.5:
				img.set_pixel(x, y, ink)

static func _pupil(img: Image, cx: float, cy: float, r: float, ink: Color) -> void:
	_eye(img, cx, cy, r, ink, ink)

static func _mouth_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, ink: Color) -> void:
	for y in range(int(cy - ry), int(cy + ry) + 1):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, ink)

static func _teeth_bar(img: Image, y0: int, y1: int, ink: Color) -> void:
	var gum := Color(0.85, 0.83, 0.80)
	for y in range(y0, y1 + 1):
		for x in range(34, 63):
			var col := gum if (x / 7) % 2 == 0 else ink
			if y == y0 or y == y1 or x == 34 or x == 62:
				col = ink
			img.set_pixel(x, y, col)

static func _brow_bar(img: Image, cx: float, y: int, w: int, t: int, ink: Color) -> void:
	for yy in range(y, y + t):
		for xx in range(int(cx - w / 2.0), int(cx + w / 2.0)):
			img.set_pixel(xx, yy, ink)

static func _wavy_mouth(img: Image, x0: int, x1: int, cy: int, ink: Color) -> void:
	for x in range(x0, x1 + 1):
		var yy := cy + int(round(sin(float(x) * PI / 6.0) * 4.0))
		img.set_pixel(x, yy, ink)
		img.set_pixel(x, yy + 1, ink)

static func _squiggle_mouth(img: Image, x0: int, x1: int, cy: int, ink: Color) -> void:
	for x in range(x0, x1 + 1):
		var yy := cy + int(round(sin(float(x) * PI / 10.0) * 2.0))
		img.set_pixel(x, yy, ink)

static func _bag_lines(img: Image, y0: int, y1: int, ink: Color) -> void:
	for e in [-1, 1]:
		var bx: int = 48 + e * 19
		for d in range(-4, 5):
			var yy := y1 + 6 + absi(d)
			img.set_pixel(bx + d, yy, ink.darkened(0.25))

static func _lidded_eye(img: Image, cx: float, cy: float, ink: Color) -> void:
	# Half-lidded tired eye: white upper arc hidden under a skin lid bar.
	_eye(img, cx, cy, 10.0, Color.WHITE, ink)
	_pupil(img, cx, cy + 3, 3.0, ink)
	_brow_bar(img, cx, int(cy) - 8, 24, 9, _skin())

## Under-HUD confusion? No. This returns the face decal mesh sizing used
## by the rider builder: a slightly-flattened sphere shells the head's
## front hemisphere.
const DECAL_SCALE := Vector3(1.04, 1.04, 1.04)

static func clear_cache() -> void:
	_cache.clear()
