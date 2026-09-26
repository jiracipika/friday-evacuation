# MenuBackdrop.gd — animated hero backdrop for the main menu.
#
# OVERHAUL: replaces the 3 hard sky bands with a smooth 11-stop dusk
# gradient, adds an interior-office foreground (floor line + window
# mullions + a warm ceiling light band) so the menu backdrop matches the
# in-game after-hours office instead of a generic skyline, keeps the
# parallax skyline + sun. Design language: fully opaque fills, dramatic
# multi-axis motion, no alpha-blended landmasses.
#
# PARALLAX SLICE: the two skyline rows scroll horizontally at different
# speeds (far 3 px/s, near 7 px/s, each offset wrapped to the control
# width and drawn twice for a seamless loop), and the skyline/prop
# silhouettes drift subtly toward deep violet over time. The dusk
# gradient itself stays static. Menu-only: the phase lives in
# time_seconds, a settable member, so tests can pin it deterministically.
extends Control

const UI_THEME = preload("res://scripts/UITheme.gd")

var time_seconds: float = 0.0

# Deterministic skyline: [x_norm, width_norm, height_norm, window_seed]
const BUILDINGS := [
	[0.02, 0.10, 0.30, 1], [0.13, 0.07, 0.44, 2], [0.21, 0.12, 0.24, 3],
	[0.35, 0.08, 0.52, 4], [0.44, 0.14, 0.36, 5], [0.60, 0.07, 0.58, 6],
	[0.68, 0.12, 0.30, 7], [0.82, 0.09, 0.48, 8], [0.92, 0.07, 0.26, 9],
]

# Smooth dusk sky: top deep-night -> mid plum -> horizon amber. Drawn as
# many thin opaque bands = smooth gradient without shader cost.
const SKY_STOPS := [
	[0.00, Color(0.045, 0.035, 0.085)],
	[0.16, Color(0.075, 0.055, 0.13)],
	[0.32, Color(0.14, 0.075, 0.14)],
	[0.48, Color(0.24, 0.11, 0.13)],
	[0.62, Color(0.40, 0.16, 0.12)],
	[0.74, Color(0.62, 0.26, 0.13)],
	[0.84, Color(0.82, 0.38, 0.15)],
	[1.00, Color(0.94, 0.50, 0.18)],
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(delta: float) -> void:
	# Advance/redraw only while visible: a hidden menu must not burn
	# frames on queue_redraw every tick.
	if not is_visible_in_tree():
		return
	time_seconds += delta
	queue_redraw()

## Horizontal parallax offsets — pure functions of time_seconds so tests
## can pin the phase. Far layer crawls at 3 px/s, near at 7 px/s, wrapped
## into [0, width) so the double-drawn layers loop seamlessly.
func _far_offset(w: float) -> float:
	return wrapf(time_seconds * 3.0, 0.0, w)

func _near_offset(w: float) -> float:
	return wrapf(time_seconds * 7.0, 0.0, w)

## Subtle hue drift for skyline/prop silhouettes: lerp toward deep violet
## by 0.05 + 0.05 * sin(phase * 0.35) — never more than 10%. Sky gradient
## stops are NOT passed through here.
func _drift(c: Color, phase: float) -> Color:
	var f := 0.05 + 0.05 * sin(phase * 0.35)
	return c.lerp(Color("9b82ff"), f)

## Test hook: the near-layer silhouette color at an arbitrary phase,
## without touching the live clock.
func sample_skyline_hue(t: float) -> Color:
	return _drift(Color(0.02, 0.02, 0.04), t)

func _draw() -> void:
	var size_vec := size
	if size_vec.x < 2.0 or size_vec.y < 2.0:
		return
	_draw_sky(size_vec)
	_draw_sun(size_vec)
	_draw_clouds(size_vec)
	_draw_skyline(size_vec)
	_draw_office_props(size_vec)
	_draw_office_foreground(size_vec)

func _draw_sky(sz: Vector2) -> void:
	var bands := 56
	for i in bands:
		var t0 := float(i) / float(bands)
		var t1 := float(i + 1) / float(bands)
		var c0 := _sky_color(t0)
		var c1 := _sky_color(t1)
		var c := c0.lerp(c1, 0.5)
		var y0 := floorf(t0 * sz.y * 0.92)
		var y1 := ceilf(t1 * sz.y * 0.92) + 1.0
		draw_rect(Rect2(Vector2(0, y0), Vector2(sz.x, y1 - y0)), c, true)

func _sky_color(t: float) -> Color:
	for i in range(SKY_STOPS.size() - 1):
		var a: Array = SKY_STOPS[i]
		var b: Array = SKY_STOPS[i + 1]
		var ta: float = a[0]
		var tb: float = b[0]
		if t >= ta and t <= tb:
			var f := (t - ta) / maxf(tb - ta, 0.0001)
			f = f * f * (3.0 - 2.0 * f)  # smoothstep between stops
			var ca: Color = a[1]
			var cb: Color = b[1]
			return ca.lerp(cb, f)
	return SKY_STOPS[SKY_STOPS.size() - 1][1]

func _draw_sun(sz: Vector2) -> void:
	var sun_center := Vector2(sz.x * 0.30, sz.y * 0.66)
	var sun_r := minf(sz.x, sz.y) * 0.16
	# Sun slowly SINKS as menu time passes (it's 4:59 forever, but barely).
	var sink := sin(time_seconds * 0.05) * sun_r * 0.35
	var cy := sun_center.y + sink
	draw_circle(Vector2(sun_center.x, cy + sun_r * 1.7), sun_r * 3.4, Color(0.42, 0.20, 0.11), true, -1, true)
	draw_circle(Vector2(sun_center.x, cy), sun_r * 1.35, Color(0.85, 0.38, 0.16), true, -1, true)
	draw_circle(Vector2(sun_center.x, cy), sun_r, Color(1.0, 0.60, 0.22), true, -1, true)
	draw_circle(Vector2(sun_center.x, cy), sun_r * 0.72, Color(1.0, 0.78, 0.42), true, -1, true)

func _draw_clouds(sz: Vector2) -> void:
	for layer in 3:
		var speed := 12.0 + float(layer) * 10.0
		var y := sz.y * (0.16 + 0.10 * float(layer))
		var cloud_h := sz.y * (0.045 + 0.015 * float(layer))
		var offset := fmod(time_seconds * speed * (0.35 + 0.25 * float(layer)), sz.x * 2.0) - sz.x * 0.5
		for k in 5:
			var cx := fmod(offset + float(k) * sz.x * 0.42, sz.x * 2.0) - sz.x * 0.25
			# Opaque dusk clouds (alpha against the gradient muddied the
			# sky on the first pass): darker plum silhouettes, backlit.
			var cloud_col := Color(0.16, 0.09, 0.13) if layer < 2 else Color(0.10, 0.06, 0.10)
			draw_set_transform(Vector2(cx, y), 0.0, Vector2(2.4, 0.5))
			draw_circle(Vector2.ZERO, cloud_h, cloud_col, true)
			draw_set_transform(Vector2.ZERO)

func _draw_skyline(sz: Vector2) -> void:
	var far_off := _far_offset(sz.x)
	var near_off := _near_offset(sz.x)
	for row in 2:
		var far := row == 0
		var off := far_off if far else near_off
		var base_y := sz.y * (0.86 if far else 0.92)
		var max_h := sz.y * (0.52 if far else 0.40)
		# Two copies per layer (offset and offset - width) make the
		# wrapped scroll seamless across the whole control width.
		for copy in 2:
			var x_shift := off - float(copy) * sz.x
			for b in BUILDINGS:
				var x_n: float = b[0]
				var w_n: float = b[1]
				var h_n: float = b[2]
				var seed_n: int = b[3]
				var parity_shift := 0.5 if far else 0.0
				var bx := (x_n * sz.x) + x_shift + (parity_shift * sz.x * 0.05)
				var bw := w_n * sz.x * (1.0 if far else 0.85)
				var bh := h_n * max_h * (1.0 if far else 1.18)
				if bx + bw < 0.0 or bx > sz.x:
					continue
				# Sway is vertical only now — horizontal motion is purely
				# the parallax scroll.
				var sway := sin(time_seconds * (0.05 if far else 0.09) + float(row) + float(copy)) * (2.0 if far else 5.0)
				var rect := Rect2(Vector2(bx, base_y - bh + sway), Vector2(bw, bh))
				var base_col := Color(0.045, 0.045, 0.075) if far else Color(0.02, 0.02, 0.04)
				var block_col := _drift(base_col, time_seconds)
				draw_rect(rect, block_col, true)
				var cols := maxi(2, int(bw / 26.0))
				var rows := maxi(2, int(bh / 34.0))
				for wy in rows:
					for wx in cols:
						var hsh := float((seed_n * 73 + wy * 31 + wx * 17) % 97) / 97.0
						var wave := sin(time_seconds * 0.5 + hsh * TAU) * 0.5 + 0.5
						if hsh > 0.62 and wave > 0.25:
							var base_wcol := Color(1.0, 0.72, 0.32, 0.55 if far else 0.75)
							var wcol := _drift(base_wcol, time_seconds)
							var wrect := Rect2(
								Vector2(bx + 6.0 + float(wx) * (bw - 12.0) / float(cols), base_y - bh + sway + 8.0 + float(wy) * (bh - 16.0) / float(rows)),
								Vector2(maxf(4.0, (bw - 12.0) / float(cols) * 0.4), maxf(5.0, (bh - 16.0) / float(rows) * 0.42)))
							draw_rect(wrect, wcol, true)

## S-A office set dressing: prop silhouettes along the sill + EXIT sign.
## Colors are lifted ~10-15% above the floor pool so they read as set
## dressing, not artifacts. Props ride the near parallax layer; fposmod
## wraps each x into [0, size.x - w) so every rect stays inside the
## control at any phase. Deterministic pure function of time_seconds.
func _office_props() -> Array[Rect2]:
	var sill_y := size.y * 0.90
	var unit := size.y * 0.10
	var near_off := _near_offset(size.x)
	var rects: Array[Rect2] = []
	# Water cooler: slim box with rounded top (base x 0.06 of width).
	var wc_w := unit * 0.42
	var wc_h := unit * 0.72
	var wc_x := fposmod(size.x * 0.06 + near_off, maxf(1.0, size.x - wc_w))
	var wc_rect := Rect2(Vector2(wc_x, sill_y - wc_h), Vector2(wc_w, wc_h))
	rects.append(wc_rect)
	# Copier: wider low box with a paper tray lip (base x 0.40 of width).
	var cp_w := unit * 0.85
	var cp_h := unit * 0.50
	var cp_x := fposmod(size.x * 0.40 + near_off, maxf(1.0, size.x - cp_w))
	var cp_rect := Rect2(Vector2(cp_x, sill_y - cp_h), Vector2(cp_w, cp_h))
	rects.append(cp_rect)
	# Ficus: trunk strip + round canopy approximated as a tall rect (base x 0.74).
	var tr_w := unit * 0.30
	var tr_h := unit * 0.85
	var tr_x := fposmod(size.x * 0.74 + near_off, maxf(1.0, size.x - tr_w))
	var tr_rect := Rect2(Vector2(tr_x, sill_y - tr_h), Vector2(tr_w, tr_h))
	rects.append(tr_rect)
	return rects

func _exit_sign_rect() -> Rect2:
	return Rect2(Vector2(size.x - 120.0, 36.0), Vector2(84.0, 30.0))

func _draw_office_props(sz: Vector2) -> void:
	var props := _office_props()
	var prop_col := _drift(Color(0.09, 0.09, 0.13), time_seconds)
	# Water cooler: box + rounded top + faint cyan bottle glow.
	var wc := props[0]
	var radius := wc.size.x * 0.28
	draw_rect(wc, prop_col, true)
	draw_rect(Rect2(wc.position - Vector2(0, radius), Vector2(wc.size.x, radius * 2.0)), prop_col, true)
	draw_circle(Vector2(wc.position.x + wc.size.x * 0.5, wc.position.y - radius), radius, prop_col, true)
	draw_rect(Rect2(Vector2(wc.position.x + wc.size.x * 0.18, wc.position.y - radius * 1.6),
		Vector2(wc.size.x * 0.64, radius * 1.3)), Color(0.22, 0.34, 0.38), true)
	# Copier: box + paper tray lip sticking out the front.
	var cp := props[1]
	draw_rect(cp, prop_col, true)
	draw_rect(Rect2(Vector2(cp.position.x + cp.size.x * 0.12, cp.position.y - sz.y * 0.012),
		Vector2(cp.size.x * 0.44, sz.y * 0.012)), Color(0.11, 0.11, 0.16), true)
	# Ficus: trunk + round canopy.
	var tr := props[2]
	var trunk_w := tr.size.x * 0.22
	draw_rect(Rect2(Vector2(tr.position.x + (tr.size.x - trunk_w) * 0.5, tr.position.y + tr.size.y * 0.45),
		Vector2(trunk_w, tr.size.y * 0.55)), prop_col, true)
	var canopy_c := Vector2(tr.position.x + tr.size.x * 0.5, tr.position.y + tr.size.y * 0.30)
	var canopy_r := tr.size.x * 0.62
	draw_circle(canopy_c, canopy_r, prop_col, true)
	draw_circle(canopy_c + Vector2(-canopy_r * 0.45, canopy_r * 0.40), canopy_r * 0.62, prop_col, true)
	draw_circle(canopy_c + Vector2(canopy_r * 0.45, canopy_r * 0.38), canopy_r * 0.58, prop_col, true)
	# EXIT sign: green rect + inner white-bordered rect + white arrow.
	# Signage, not a button — no glow (FINAL-SPEC R1).
	var ex := Rect2(Vector2(sz.x - 120.0, 36.0), Vector2(84.0, 30.0))
	draw_rect(ex, UI_THEME.color(UI_THEME.GREEN), true)
	var inner := ex.grow(-4.0)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 2.0)), Color.WHITE, true)
	draw_rect(Rect2(Vector2(inner.position.x, inner.position.y + inner.size.y - 2.0), Vector2(inner.size.x, 2.0)), Color.WHITE, true)
	draw_rect(Rect2(Vector2(inner.position.x, inner.position.y), Vector2(2.0, inner.size.y)), Color.WHITE, true)
	draw_rect(Rect2(Vector2(inner.position.x + inner.size.x - 2.0, inner.position.y), Vector2(2.0, inner.size.y)), Color.WHITE, true)
	# Arrow: shaft + head, pointing right.
	var ac := Vector2(ex.position.x + ex.size.x * 0.5, ex.position.y + ex.size.y * 0.5)
	draw_rect(Rect2(Vector2(ac.x - 16.0, ac.y - 2.5), Vector2(22.0, 5.0)), Color.WHITE, true)
	draw_rect(Rect2(Vector2(ac.x + 2.0, ac.y - 8.5), Vector2(10.0, 5.0)), Color.WHITE, true)
	draw_rect(Rect2(Vector2(ac.x + 2.0, ac.y + 3.5), Vector2(10.0, 5.0)), Color.WHITE, true)

## Interior-office foreground: the menu sits INSIDE the office looking out.
## Ceiling light band at top, warm floor pool at bottom, and tall window
## mullions over the skyline (ties the menu to the in-game dusk windows).
func _draw_office_foreground(sz: Vector2) -> void:
	# Window mullions: dark verticals across the skyline view, subtle sway.
	var mull_count := maxi(4, int(sz.x / 220.0))
	var mull_w := maxf(6.0, sz.x * 0.006)
	for i in mull_count:
		var mx := sz.x * (float(i) + 0.5) / float(mull_count)
		mx += sin(time_seconds * 0.11 + float(i)) * 2.0
		draw_rect(Rect2(Vector2(mx - mull_w * 0.5, sz.y * 0.10), Vector2(mull_w, sz.y * 0.78)), Color(0.03, 0.03, 0.05), true)
	# Transom bar (horizontal mullion).
	draw_rect(Rect2(Vector2(0, sz.y * 0.12), Vector2(sz.x, maxf(6.0, sz.y * 0.012))), Color(0.03, 0.03, 0.05), true)
	# Ceiling: dark band + a warm troffer light strip that gently pulses.
	draw_rect(Rect2(Vector2(0, 0), Vector2(sz.x, sz.y * 0.10)), Color(0.028, 0.028, 0.045), true)
	var pulse := 0.85 + sin(time_seconds * 1.3) * 0.15
	# Soft troffer glow: gradient feather instead of a hard-edged bar so it
	# reads as ceiling light, not a floating UI stripe.
	var strip_y := sz.y * 0.020
	var strip_h := maxf(3.0, sz.y * 0.006)
	var strip_rect := Rect2(Vector2(sz.x * 0.30, strip_y), Vector2(sz.x * 0.40, strip_h))
	draw_rect(strip_rect, Color(1.0, 0.82, 0.55, 0.34 * pulse), true)
	var feather_h := maxf(8.0, sz.y * 0.03)
	for i in 6:
		var a := 0.05 * pulse * (1.0 - float(i) / 6.0)
		draw_rect(Rect2(Vector2(sz.x * 0.30 - float(i) * 6.0, strip_y + strip_h),
			Vector2(sz.x * 0.40 + float(i) * 12.0, feather_h)), Color(1.0, 0.82, 0.55, a), true)
	# Interior floor: warm pool sweeping a desk-lamp hue across the bottom.
	draw_rect(Rect2(Vector2(0, sz.y * 0.90), Vector2(sz.x, sz.y * 0.10)), Color(0.05, 0.04, 0.06), true)
	var sweep := fmod(time_seconds * 0.03, 1.0)
	var pool_x := sz.x * (0.15 + 0.7 * sweep)
	# Two-layer soft pool: wide dim base + narrow warm core (desk-lamp hue).
	draw_rect(Rect2(Vector2(pool_x - sz.x * 0.13, sz.y * 0.90), Vector2(sz.x * 0.26, sz.y * 0.028)), Color(0.40, 0.22, 0.09, 0.55), true)
	draw_rect(Rect2(Vector2(pool_x - sz.x * 0.06, sz.y * 0.90), Vector2(sz.x * 0.12, sz.y * 0.02)), Color(0.52, 0.29, 0.12, 0.75), true)
	# Brand floor line.
	draw_rect(Rect2(Vector2(0, sz.y - 4.0), Vector2(sz.x, 4.0)), Color(1.0, 0.60, 0.22, 0.35), true)
