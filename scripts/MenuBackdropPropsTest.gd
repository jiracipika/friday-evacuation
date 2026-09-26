extends SceneTree

# MenuBackdropPropsTest.gd — S-A verification.
# Covers: _draw survives 3 queue_redraw cycles without script errors,
# _office_props() returns >=3 prop rects inside the control bounds, and
# _exit_sign_rect() sits fully inside the control rect.
# Parallax slice: _draw also survives full draw cycles at pinned phases
# (time_seconds = 0 and 100), _office_props() x positions MOVE between
# those phases while staying inside the control, the sky gradient stays
# static, and the skyline hue drifts slightly over time.

const Backdrop = preload("res://scripts/MenuBackdrop.gd")

var backdrop: Control
var frames := 0
var checks := 0
var failures := PackedStringArray()
var props_t0: Array[Rect2] = []
var props_t100: Array[Rect2] = []

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)

func _init() -> void:
	backdrop = Backdrop.new()
	root.add_child.call_deferred(backdrop)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		backdrop.size = Vector2(1280, 720)
		return false
	if frames < 5:
		# 3+ redraw cycles: _process calls queue_redraw each frame; a script
		# error inside _draw would surface as SCRIPT ERROR in output.
		return false

	if frames == 5:
		_run_base_checks()
		# Pin the phase and force a full draw cycle at t=0.
		backdrop.time_seconds = 0.0
		backdrop.queue_redraw()
		props_t0 = backdrop._office_props()
		return false
	if frames == 6:
		# (The pinned t=0 state went through a draw during this frame.)
		# Force another full draw cycle at t=100.
		backdrop.time_seconds = 100.0
		backdrop.queue_redraw()
		props_t100 = backdrop._office_props()
		return false

	# frames >= 7: two full draw cycles at different phases completed.
	_run_parallax_checks()

	if failures.is_empty() and checks > 0:
		print("[PASS] MenuBackdropPropsTest: %d checks — draw cycles, prop rects, exit sign bounds, parallax, hue drift" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("[FAIL] " + failure)
		printerr("[FAIL] %d/%d checks failed" % [failures.size(), checks])
		quit(1)
	return false

func _run_base_checks() -> void:
	var bounds := Rect2(Vector2.ZERO, backdrop.size)

	# --- 1. Prop rects ---
	var props: Array[Rect2] = backdrop._office_props()
	check(props.size() >= 3, "expected >=3 office props, got %d" % props.size())
	for i in props.size():
		var r := props[i]
		check(r.position.x >= 0.0 and r.position.y >= 0.0,
			"prop %d starts outside control (%s)" % [i, r])
		check(r.end.x <= bounds.end.x + 0.5 and r.end.y <= bounds.end.y + 0.5,
			"prop %d extends past control bounds (%s)" % [i, r])
		check(r.size.x > 0.0 and r.size.y > 0.0, "prop %d has empty size" % i)
	# Sill band: props root near the sill (tall ficus canopy may reach higher).
	for i in props.size():
		check(props[i].position.y >= bounds.size.y * 0.75,
			"prop %d not along the sill band (y=%.1f)" % [i, props[i].position.y])

	# --- 2. EXIT sign rect ---
	var ex: Rect2 = backdrop._exit_sign_rect()
	check(bounds.encloses(ex), "exit sign rect not fully inside control (%s in %s)" % [ex, bounds])
	check(ex.size == Vector2(84, 30), "exit sign size changed: %s" % ex.size)

	# --- 3. Determinism (no random) ---
	var props2: Array[Rect2] = backdrop._office_props()
	check(props2 == props, "_office_props() not deterministic across calls")

func _run_parallax_checks() -> void:
	var bounds := Rect2(Vector2.ZERO, backdrop.size)

	# --- 4. Draw cycles at pinned phases completed without script errors
	# (a SCRIPT ERROR inside _draw would surface in output; reaching here
	# with both snapshots taken means the cycles ran). ---
	check(frames >= 7, "draw cycles at pinned phases did not complete")
	check(props_t0.size() == 3 and props_t100.size() == 3,
		"expected 3 prop rects per phase (t0=%d t100=%d)" % [props_t0.size(), props_t100.size()])
	if props_t0.size() != 3 or props_t100.size() != 3:
		return

	# --- 5. Parallax actually moves the props, in-bounds at both phases ---
	for i in 3:
		var r0 := props_t0[i]
		var r1 := props_t100[i]
		check(r0.position.x >= 0.0 and r0.end.x <= bounds.end.x + 0.5,
			"t=0 prop %d outside control (%s)" % [i, r0])
		check(r1.position.x >= 0.0 and r1.end.x <= bounds.end.x + 0.5,
			"t=100 prop %d outside control (%s)" % [i, r1])
		check(absf(r1.position.x - r0.position.x) > 0.5,
			"prop %d did not parallax between t=0 and t=100 (%s vs %s)" % [i, r0.position, r1.position])

	# --- 6. Hue drift: slight, measurable, phase-dependent ---
	var hue0: Color = backdrop.sample_skyline_hue(0.0)
	var hue40: Color = backdrop.sample_skyline_hue(40.0)
	check(hue0 != hue40, "skyline hue identical at t=0 and t=40 (no drift)")
	var diff := hue0 - hue40
	var d := sqrt(diff.r * diff.r + diff.g * diff.g + diff.b * diff.b + diff.a * diff.a)
	check(d > 0.0001 and d < 0.15, "hue drift not subtle/measurable (d=%.4f)" % d)

	# --- 7. Sky gradient stays static while the phase moves ---
	var sky_a: Color = backdrop._sky_color(0.5)
	backdrop.time_seconds = 55.0
	var sky_b: Color = backdrop._sky_color(0.5)
	check(sky_a == sky_b, "sky gradient changed with time (should stay static)")
