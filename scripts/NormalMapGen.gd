# NormalMapGen.gd — derive normal maps from grayscale height fields.
#
# Phase 2 texture upgrade: procedural albedo generators already encode
# STRUCTURE (panel joints, wainscot steps, weave ribs, tile grooves).
# A Sobel over a matching height buffer turns that structure into a
# tangent-space normal map, which makes 512px textures read like 1024+
# under moving light — for a one-time generation cost, zero draw-pass
# overhead (normal mapping rides the existing material).
#
# Usage:
#   var height := NormalMapGen.height_buffer(TEX_W, TEX_H)
#   NormalMapGen.stamp(height, x0, x1, y0, y1, depth)  # emboss features
#   var tex := NormalMapGen.normal_texture(height, strength)
#
# Height values are 0..1 floats stored in a PackedFloat32Array (row-major,
# x + y * width). `strength` is multiplied by the smaller texture dimension; use small
# values (e.g. 0.015 at 256px) for shallow prop relief.
class_name NormalMapGen
extends RefCounted


static func height_buffer(width: int, height: int, base := 0.5) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(width * height)
	buf.fill(base)
	return buf


## Emboss a rectangular feature (joint/groove: negative depth; ridge: positive).
static func stamp(buf: PackedFloat32Array, width: int, height: int,
		x0: int, x1: int, y0: int, y1: int, depth: float) -> void:
	for y in range(maxi(y0, 0), mini(y1 + 1, height)):
		for x in range(maxi(x0, 0), mini(x1 + 1, width)):
			buf[x + y * width] = clampf(buf[x + y * width] + depth, 0.0, 1.0)


## Fast single-pixel write (generators loop per pixel; stamp() per pixel
## would re-run its range clamps 512x256 times — measured 3x slower).
static func set_height(buf: PackedFloat32Array, width: int, height: int,
		x: int, y: int, value: float) -> void:
	if x >= 0 and x < width and y >= 0 and y < height:
		buf[x + y * width] = clampf(value, 0.0, 1.0)


## Add smooth noise to a region (or all of it with x0=0 etc. defaults).
static func noise(buf: PackedFloat32Array, width: int, height: int,
		rng: RandomNumberGenerator, amount: float,
		x0 := 0, x1 := -1, y0 := 0, y1 := -1) -> void:
	var ex := (width - 1) if x1 < 0 else x1
	var ey := (height - 1) if y1 < 0 else y1
	for y in range(maxi(y0, 0), mini(ey + 1, height)):
		for x in range(maxi(x0, 0), mini(ex + 1, width)):
			buf[x + y * width] = clampf(
				buf[x + y * width] + (rng.randf() - 0.5) * amount, 0.0, 1.0)


## Derive central-difference tangent-space normals from a height buffer.
## Set seamless for periodic tiles; other callers retain clamped edges.
## world_scale maps texel steps to world units per tile — panels that
## stretch over 5m need larger world_scale than a 1m tile for the same
## visual strength, so callers tune strength instead.
static func normal_texture(buf: PackedFloat32Array, width: int, height: int,
		strength := 1.0, seamless := false) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGB8)
	var s := strength * float(mini(width, height))
	img.fill(Color(0.5, 0.5, 1.0))  # neutral baseline; only deviations written
	for y in height:
		var y_up := posmod(y - 1, height) if seamless else maxi(y - 1, 0)
		var y_dn := (y + 1) % height if seamless else mini(y + 1, height - 1)
		for x in width:
			var x_l := posmod(x - 1, width) if seamless else maxi(x - 1, 0)
			var x_r := (x + 1) % width if seamless else mini(x + 1, width - 1)
			var dx := (buf[x_r + y * width] - buf[x_l + y * width]) * 2.0
			var dy := (buf[x + y_dn * width] - buf[x + y_up * width]) * 2.0
			if dx == 0.0 and dy == 0.0:
				continue  # flat area: keep pre-filled neutral normal
			var nx := -dx * s
			var ny := -dy * s
			var nz := 1.0
			var len := sqrt(nx * nx + ny * ny + nz * nz)
			# Godot tangent-space normal maps: +X right, +Y DOWN (OpenGL
			# style is +Y up; Godot expects the Y-down convention).
			var r := (nx / len) * 0.5 + 0.5
			var g := (ny / len) * 0.5 + 0.5
			var b := (nz / len) * 0.5 + 0.5
			img.set_pixel(x, y, Color(r, g, b))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
