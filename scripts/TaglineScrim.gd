# TaglineScrim.gd — D2 menu scrim: vertical gradient black 0.0 (top) -> 0.55 (bottom).
# Control that draws horizontal alpha bands in _draw(); no texture, GL Compatibility safe.
# Positioned by Main.gd to cover the tagline/description zone behind menu text.
extends Control

const BANDS := 24
const MAX_ALPHA := 0.55

func _draw() -> void:
	var h := size.y
	if h <= 0.0:
		return
	var band_h := h / float(BANDS)
	var col := Color(0.0, 0.0, 0.0)
	for i in range(BANDS):
		var t := float(i) / float(BANDS - 1)
		col.a = MAX_ALPHA * t
		draw_rect(Rect2(0.0, float(i) * band_h, size.x, band_h + 1.0), col)
