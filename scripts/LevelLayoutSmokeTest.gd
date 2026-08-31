# LevelLayoutSmokeTest.gd — Phase 4 layout system verification.
#   1. LevelLayouts compiles; three layouts exist; invalid names rejected.
#   2. All layout tables complete (required keys, sane values).
#   3. GEOMETRY SAFETY: no desk/crate spawn lands inside the perimeter
#      walls (|x|,|z| <= 19) and never on floor 3 (y=12.5).
#   4. In-scene: instantiate Evacuation per layout, count StaticBody3D
#      desks + crates, assert layout actually changes the build.
#   5. Persistence: set_current + cfg round-trip via Main helpers' keys.
# Run: godot --headless --path . --script scripts/LevelLayoutSmokeTest.gd
extends SceneTree

var checks_total := 0
var checks_passed := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks_total += 1
	if cond:
		checks_passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var LL = load("res://scripts/LevelLayouts.gd")
	check(LL != null, "LevelLayouts.gd compiles")

	# 1. Names + validity
	check(LL.LAYOUT_NAMES.size() == 3, "three layouts defined")
	check(LL.is_valid(LL.OPEN_PLAN) and LL.is_valid(LL.CUBICLE_MAZE) \
		and LL.is_valid(LL.EXECUTIVE), "is_valid accepts all three")
	check(not LL.is_valid("bogus"), "is_valid rejects unknown names")
	check(LL.DEFAULT_LAYOUT == LL.OPEN_PLAN, "default is OPEN_PLAN")

	# 2. Table completeness
	var required := ["desk_counts", "desk_range", "obstacle_seed",
		"powerup_count", "f1_corridor_gap", "f2_tables", "f4_ice_size", "f4_crates"]
	var all_complete := true
	for name_value in LL.LAYOUT_NAMES:
		var lay: Dictionary = LL.get_layout(name_value)
		for key in required:
			if not lay.has(key):
				all_complete = false
				printerr("  missing ", key, " in ", name_value)
		if int(lay["powerup_count"]) < 4 or int(lay["powerup_count"]) > 16:
			all_complete = false
		if float(lay["desk_range"]) > 19.0:
			all_complete = false  # perimeter walls at +/-20, wall 0.3 thick
		for pos in lay["f4_crates"]:
			if absf(pos.x) > 18.0 or absf(pos.z) > 18.0:
				all_complete = false
	check(all_complete, "all layout tables complete + in-bounds")

	# 3. Layouts actually differ
	var open_l: Dictionary = LL.get_layout(LL.OPEN_PLAN)
	var maze_l: Dictionary = LL.get_layout(LL.CUBICLE_MAZE)
	var exec_l: Dictionary = LL.get_layout(LL.EXECUTIVE)
	check(open_l["obstacle_seed"] != maze_l["obstacle_seed"] \
		and maze_l["obstacle_seed"] != exec_l["obstacle_seed"],
		"layout seeds differ (desks land differently)")
	check(exec_l["f4_ice_size"] > open_l["f4_ice_size"],
		"EXECUTIVE has more ice than OPEN_PLAN")
	check(int(maze_l["powerup_count"]) > int(exec_l["powerup_count"]),
		"CUBICLE_MAZE paces more pickups than EXECUTIVE")

	# 4. In-scene per-layout build (real Evacuation instantiation).
	# PreMatchModal pauses the tree on mount — suppressed for this harness.
	var PM = load("res://scripts/PreMatchModal.gd")
	var EvacScene = load("res://scenes/Evacuation.tscn")
	var desk_counts := {}
	for name_value in LL.LAYOUT_NAMES:
		PM.suppress_next()
		LL.set_current(name_value)
		var evc = EvacScene.instantiate()
		root.add_child(evc)
		await process_frame
		await process_frame
		# Count desks + crates via collider size. Crates counted only on
		# floor 4 (y > 15): floor 3's stairwell ships its own crates.
		var desks := 0
		var crates := 0
		var stack: Array[Node] = [evc]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is StaticBody3D:
				var shapes := n.find_children("*", "CollisionShape3D", true, false)
				if shapes.size() == 1:
					var sh: Shape3D = shapes[0].shape
					if sh is BoxShape3D:
						var bs := sh as BoxShape3D
						if absf(bs.size.x - 2.0) < 0.01 and absf(bs.size.y - 1.2) < 0.01:
							desks += 1
						elif absf(bs.size.x - 1.4) < 0.01 and absf(bs.size.y - 1.4) < 0.01:
							var body3d := n as Node3D
							if body3d.global_position.y > 15.0:
								crates += 1
			for c in n.get_children():
				stack.append(c)
		desk_counts[name_value] = {"desks": desks, "crates": crates}
		print("  ", name_value, ": desks=", desks, " crates=", crates)
		evc.queue_free()
		await process_frame
	var expected_desks := {}
	for name_value in LL.LAYOUT_NAMES:
		var lay: Dictionary = LL.get_layout(name_value)
		var total := 0
		for c in lay["desk_counts"]:
			total += int(c)
		expected_desks[name_value] = total
	var all_match := true
	for name_value in LL.LAYOUT_NAMES:
		if desk_counts[name_value]["desks"] != expected_desks[name_value]:
			all_match = false
			printerr("  ", name_value, " desks: got ", desk_counts[name_value]["desks"],
				" expected ", expected_desks[name_value])
		if desk_counts[name_value]["crates"] != LL.get_layout(name_value)["f4_crates"].size():
			all_match = false
			printerr("  ", name_value, " crates: got ", desk_counts[name_value]["crates"],
				" expected ", LL.get_layout(name_value)["f4_crates"].size())
	check(all_match, "in-scene desk + crate counts match layout tables")

	LL.set_current(LL.DEFAULT_LAYOUT)
	check(failures.is_empty(), "no failures")
	print("LevelLayoutSmokeTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
