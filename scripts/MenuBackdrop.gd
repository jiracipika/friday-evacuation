# MenuBackdrop.gd — animated hero backdrop for the main menu.
#
# Draws the after-hours office skyline: an opaque deep-space gradient,
# a big low sun disc (orange, brand accent), silhouetted skyline blocks
# with lit windows, and drifting clouds — multi-axis parallax driven by
# menu time (design language: dramatic, artsy, fully opaque fills; the
# moving layers sell depth without 3D cost).
extends Control

const UI_THEME = preload("res://scripts/UITheme.gd")

var time: float = 0.0

# Deterministic skyline: [x_norm, width_norm, height_norm, window_seed]
const BUILDINGS := [
	[0.02, 0.10, 0.30, 1], [0.13, 0.07, 0.44, 2], [0.21, 0.12, 0.24, 3],
	[0.35, 0.08, 0.52, 4], [0.44, 0.14, 0.36, 5], [0.60, 0.07, 0.58, 6],
	[0.68, 0.12, 0.30, 7], [0.82, 0.09, 0.48, 8], [0.92, 0.07, 0.26, 9],
]

func _ready() -> void:
	# Offsets AND anchors — plain set_anchors_preset left runtime-built
	# offsets at (0,0,0,0) which collapsed the control (backdrop rendered
	# nothing; caught by probe + vision QA).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var size_vec := size
	if size_vec.x < 2.0 or size_vec.y < 2.0:
		return
	# Deep dusk gradient — opaque, no alpha blending between sky bands.
	# Brighter than the UI surface tones so the art reads BEHIND the dark
	# panels (first capture was invisible: too-dark bands + sun hidden
	# behind the hero panel at 0.78 width).
	var sky_top := Color(0.05, 0.04, 0.09)
	var sky_mid := Color(0.16, 0.09, 0.14)
	var sky_low := Color(0.34, 0.14, 0.12)
	draw_rect(Rect2(Vector2.ZERO, size_vec), sky_top, true)
	draw_rect(Rect2(Vector2(0, size_vec.y * 0.55), Vector2(size_vec.x, size_vec.y * 0.25)), sky_mid, true)
	draw_rect(Rect2(Vector2(0, size_vec.y * 0.80), Vector2(size_vec.x, size_vec.y * 0.20)), sky_low, true)

	# Low sun disc with a wide haze ring (both opaque) — placed LEFT of
	# center so the hero panel doesn't cover it at wide aspect ratios.
	var sun_center := Vector2(size_vec.x * 0.30, size_vec.y * 0.66)
	var sun_r := minf(size_vec.x, size_vec.y) * 0.16
	draw_circle(Vector2(sun_center.x, sun_center.y + sun_r * 1.7), sun_r * 3.4, Color(0.32, 0.16, 0.10), true, -1, true)
	draw_circle(sun_center, sun_r * 1.35, Color(0.85, 0.38, 0.16), true, -1, true)
	draw_circle(sun_center, sun_r, Color(1.0, 0.60, 0.22), true, -1, true)

	# Clouds: three soft bands drifting at different speeds (parallax).
	for layer in 3:
		var speed := 12.0 + float(layer) * 10.0
		var y := size_vec.y * (0.18 + 0.10 * float(layer))
		var cloud_h := size_vec.y * (0.045 + 0.015 * float(layer))
		var offset := fmod(time * speed * (0.35 + 0.25 * float(layer)), size_vec.x * 2.0) - size_vec.x * 0.5
		for k in 5:
			var cx := fmod(offset + float(k) * size_vec.x * 0.42, size_vec.x * 2.0) - size_vec.x * 0.25
			var alpha := 0.05 + 0.03 * float(layer)
			var cloud_col := Color(0.9, 0.55, 0.4, alpha)
			# Filled ellipse via scaled circle (filled, antialiased edge off
			# for crisp art direction).
			draw_set_transform(Vector2(cx, y), 0.0, Vector2(2.4, 0.5))
			draw_circle(Vector2.ZERO, cloud_h, cloud_col, true)
			draw_set_transform(Vector2.ZERO)

	# Skyline: far row (darker, slower), near row (blacker, faster parallax
	# sway). Windows lit deterministically; a slow "wave" lights sweep.
	for row in 2:
		var far := row == 0
		var sway := sin(time * (0.05 if far else 0.09) + float(row)) * (2.0 if far else 5.0)
		var base_y := size_vec.y * (0.86 if far else 0.92)
		var max_h := size_vec.y * (0.52 if far else 0.40)
		for b in BUILDINGS:
			var x_n: float = b[0]
			var w_n: float = b[1]
			var h_n: float = b[2]
			var seed_n: int = b[3]
			var parity_shift := 0.5 if far else 0.0  # near row staggered
			var bx := (x_n * size_vec.x) + sway + (parity_shift * size_vec.x * 0.05)
			var bw := w_n * size_vec.x * (1.0 if far else 0.85)
			var bh := h_n * max_h * (1.0 if far else 1.18)
			var rect := Rect2(Vector2(bx, base_y - bh), Vector2(bw, bh))
			var block_col := Color(0.045, 0.045, 0.075) if far else Color(0.02, 0.02, 0.04)
			draw_rect(rect, block_col, true)
			# Lit windows: deterministic grid, wave sweep via time.
			var cols := maxi(2, int(bw / 26.0))
			var rows := maxi(2, int(bh / 34.0))
			for wy in rows:
				for wx in cols:
					var hsh := float((seed_n * 73 + wy * 31 + wx * 17) % 97) / 97.0
					var wave := sin(time * 0.5 + hsh * TAU) * 0.5 + 0.5
					if hsh > 0.62 and wave > 0.25:
						var wcol := Color(1.0, 0.72, 0.32, 0.55 if far else 0.75)
						var wrect := Rect2(
							Vector2(bx + 6.0 + float(wx) * (bw - 12.0) / float(cols), base_y - bh + 8.0 + float(wy) * (bh - 16.0) / float(rows)),
							Vector2(maxf(4.0, (bw - 12.0) / float(cols) * 0.4), maxf(5.0, (bh - 16.0) / float(rows) * 0.42)))
						draw_rect(wrect, wcol, true)

	# Foreground street glow line at the very bottom.
	draw_rect(Rect2(Vector2(0, size_vec.y - 4.0), Vector2(size_vec.x, 4.0)), Color(1.0, 0.60, 0.22, 0.35), true)
