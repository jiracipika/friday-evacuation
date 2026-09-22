extends SceneTree

# MenuBackdropPropsTest.gd — S-A verification.
# Covers: _draw survives 3 queue_redraw cycles without script errors,
# _office_props() returns >=3 prop rects inside the control bounds, and
# _exit_sign_rect() sits fully inside the control rect.

const Backdrop = preload("res://scripts/MenuBackdrop.gd")

var backdrop: Control
var frames := 0
var checks := 0
var failures := PackedStringArray()

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

	if failures.is_empty() and checks > 0:
		print("[PASS] MenuBackdropPropsTest: %d checks — draw cycles, prop rects, exit sign bounds" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("[FAIL] " + failure)
		printerr("[FAIL] %d/%d checks failed" % [failures.size(), checks])
		quit(1)
	return false
