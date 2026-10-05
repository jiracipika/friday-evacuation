# OfficeDressingParityTest.gd — dressing-parity slice invariants (whiteboard,
# cable tray, desk plant + their floor 2/4 placement). Verifies REAL built
# geometry and the REAL Evacuation scene:
#   1. whiteboard(): three variants build named, decorative, shadowless
#      geometry — no CollisionObject3D/Light3D, every MeshInstance3D casts NO
#      shadow (repo law), bounded mesh budget, strokes on the board face,
#      menu variant carries a digit-free Label3D header.
#   2. cable_tray(): thin CEILING geometry — all meshes shadow-off, two drop
#      rods, length respected, shared cached materials across instances.
#   3. desk_plant(): tiny (<= 0.45m), 3 meshes, shadowless.
#   4. Scene: DressingParity_F1/F3 groups exist, are registered for floor
#      culling, hold the expected prop mix (boards, trays, window plants),
#      add ZERO colliders, stay within a modest mesh budget, and desk-plant
#      variety never removes a screen/printer from any desk.
#   5. Culling: with the player on floor 4, the floor 2 parity group hides
#      (registration actually rides the existing culling system).
# Run:
#   godot --headless --path . --script scripts/OfficeDressingParityTest.gd
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
	var OD: GDScript = load("res://scripts/OfficeDressing.gd")
	check(OD != null, "OfficeDressing script loads")

	# --- 1. whiteboard builder -------------------------------------------
	var board_mat_by_variant: Array = []
	var built: Array = []
	for v in 3:
		var wb: Node3D = OD.whiteboard(v)
		built.append(wb)
		check(wb != null and String(wb.name).begins_with("Whiteboard"),
			"whiteboard(%d) builds named root" % v)
		var audit := _audit(wb)
		check(audit["bad"] == 0, "whiteboard(%d) adds no CollisionObject3D/Light3D" % v)
		check(audit["casters"] == 0,
			"whiteboard(%d) has zero shadow casters (repo law)" % v)
		var mi_count: int = audit["mi"]
		check(mi_count >= 7 and mi_count <= 11,
			"whiteboard(%d) mesh budget [7,11] (got %d)" % [v, mi_count])
		if has_box(audit):
			var box: AABB = audit["box"]
			check(box.position.x >= -0.95 and box.end.x <= 0.95
					and box.position.y >= -0.01 and box.end.y <= 2.05
					and box.position.z >= -0.12 and box.end.z <= 0.15,
				"whiteboard(%d) inside board envelope (%s)" % [v, box])
		check(audit["strokes"] >= 3 and audit["strokes"] <= 5,
			"whiteboard(%d) marker strokes [3,5] (got %d)" % [v, audit["strokes"]])
		if v == 2:
			var header: Label3D = wb.get_node_or_null("MenuHeader") as Label3D
			check(header != null, "menu whiteboard has Label3D header")
			if header != null:
				check(header.text.find("MENU") >= 0, "menu header says MENU")
				var has_digit := false
				for dg in "0123456789":
					if header.text.find(dg) >= 0:
						has_digit = true
				check(not has_digit, "menu header never states a destination digit")
		board_mat_by_variant.append(_board_mat(wb))
	# Variants share one cached board surface (batching).
	var shared := true
	for m in board_mat_by_variant:
		shared = shared and m == board_mat_by_variant[0] and m != null
	check(shared and board_mat_by_variant.size() == 3,
		"whiteboard variants share one cached board material")
	for wb in built:
		(wb as Node3D).free()

	# --- 2. cable tray builder -------------------------------------------
	var tray_a: Node3D = OD.cable_tray(38.0)
	var ta := _audit(tray_a)
	check(ta["bad"] == 0, "cable_tray adds no CollisionObject3D/Light3D")
	check(ta["casters"] == 0, "cable_tray has zero shadow casters (ceiling law)")
	check(ta["mi"] >= 6 and ta["mi"] <= 12,
		"cable_tray mesh budget [6,12] (got %d)" % ta["mi"])
	check(ta["rods"] >= 2, "cable_tray hangs from >=2 drop rods")
	if has_box(ta):
		var tbox: AABB = ta["box"]
		check(absf(tbox.size.x - 38.0) < 0.6,
			"tray length respected (span %.2f)" % tbox.size.x)
	var tray_b: Node3D = OD.cable_tray(38.0)
	var base_a: MeshInstance3D = tray_a.get_node_or_null("Base") as MeshInstance3D
	var base_b: MeshInstance3D = tray_b.get_node_or_null("Base") as MeshInstance3D
	check(base_a != null and base_b != null
			and base_a.material_override == base_b.material_override,
		"tray instances share one cached metal material")

	# --- 3. desk plant builder -------------------------------------------
	var plant: Node3D = OD.desk_plant()
	var pa := _audit(plant)
	check(pa["bad"] == 0 and pa["casters"] == 0 and pa["mi"] == 3,
		"desk_plant: 3 shadowless meshes, no collision/light")
	if has_box(pa):
		check(pa["box"].size.length() < 0.6,
			"desk_plant stays tiny (%s)" % pa["box"].size)
	tray_a.free()
	tray_b.free()
	plant.free()

	# --- 4. real-scene integration ---------------------------------------
	var packed := load("res://scenes/Evacuation.tscn")
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var evac = packed.instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame
	await process_frame

	var f1 := evac.get_node_or_null("DressingParity_F1") as Node3D
	var f3 := evac.get_node_or_null("DressingParity_F3") as Node3D
	check(f1 != null, "floor 2 parity group exists")
	check(f3 != null, "floor 4 parity group exists")
	check(_registered(evac, 1, f1), "floor 2 parity group registered for culling")
	check(_registered(evac, 3, f3), "floor 4 parity group registered for culling")

	if f1 != null:
		var f1a := _audit(f1)
		check(f1a["bad"] == 0 and f1a["casters"] == 0,
			"floor 2 parity adds no colliders and no shadow casters")
		var f1_boards := _count_named(f1, "Whiteboard")
		var f1_trays := _count_named(f1, "CableTray")
		var f1_plants := _count_models(f1)
		check(f1_boards == 2, "floor 2 has 2 whiteboards (got %d)" % f1_boards)
		check(f1_trays == 2, "floor 2 has 2 cable trays (got %d)" % f1_trays)
		check(f1_plants == 2, "floor 2 has 2 window plants in the group (got %d)" % f1_plants)
		check(_all_at_y(f1, 6.0, 12.0), "floor 2 parity props sit within the floor band (boards y=6, trays y=11.42)")
		check(f1a["mi"] <= 60, "floor 2 parity mesh budget <= 60 (got %d)" % f1a["mi"])
	if f3 != null:
		var f3a := _audit(f3)
		check(f3a["bad"] == 0 and f3a["casters"] == 0,
			"floor 4 parity adds no colliders and no shadow casters")
		check(_count_named(f3, "Whiteboard") == 1, "floor 4 has 1 menu board")
		check(_count_named(f3, "CableTray") == 2, "floor 4 has 2 cable trays")
		check(_all_at_y(f3, 18.0, 24.0), "floor 4 parity props sit within the floor band (board y=18, trays y=23.42)")
		check(f3a["mi"] <= 60, "floor 4 parity mesh budget <= 60 (got %d)" % f3a["mi"])

	# Desk-plant variety never starves a desk of its screen/printer.
	# (int params are pass-by-value in GDScript — Array accumulator.)
	var desk_stats: Array = [0, 0, 0]  # [desks, screens, desk_plants]
	_count_desk_stuff(evac, desk_stats)
	check(desk_stats[0] > 0 and desk_stats[1] >= desk_stats[0],
		"every desk still carries a screen or printer (%d desks, %d screens)" % [desk_stats[0], desk_stats[1]])
	check(desk_stats[2] >= 1, "desk-plant variety present (%d)" % desk_stats[2])

	# --- 5. registration actually rides floor culling ---------------------
	evac.local_player.global_position = Vector3(0, 19.0, 0)
	await process_frame
	await process_frame
	if f1 != null and f3 != null:
		check(not f1.visible, "floor 2 parity group hidden on floor 4")
		check(f3.visible, "floor 4 parity group visible on floor 4")

	evac.queue_free()
	await process_frame

	check(checks_total > 0, "checks ran")
	print("OfficeDressingParityTest: %d/%d checks passed" % [checks_passed, checks_total])
	if failures.is_empty() and checks_total > 0:
		print("=== OFFICE DRESSING PARITY TEST PASSED (%d checks) ===" % checks_total)
		quit(0)
	else:
		for f in failures:
			print("  - %s" % f)
		print("=== OFFICE DRESSING PARITY TEST FAILED (%d/%d) ===" % [checks_passed, checks_total])
		quit(1)


## Walk a subtree collecting: MeshInstance3D count, shadow casters, forbidden
## nodes, marker strokes, drop rods, union mesh AABB, model instances.
func _audit(node: Node) -> Dictionary:
	var out := {
		"mi": 0, "casters": 0, "bad": 0, "strokes": 0, "rods": 0,
		"box": AABB(), "has_box": false,
	}
	_walk_audit(node, out)
	return out

func _walk_audit(node: Node, out: Dictionary) -> void:
	for child in node.get_children():
		if child is CollisionObject3D or child is Light3D:
			out["bad"] += 1
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			out["mi"] += 1
			if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				out["casters"] += 1
			if String(mi.name).begins_with("Stroke"):
				out["strokes"] += 1
			if String(mi.name).begins_with("DropRod"):
				out["rods"] += 1
			if mi.mesh != null:
				var wa: AABB = mi.transform * mi.mesh.get_aabb()
				if out["has_box"]:
					out["box"] = (out["box"] as AABB).merge(wa)
				else:
					out["box"] = wa
					out["has_box"] = true
		_walk_audit(child, out)

func has_box(audit: Dictionary) -> bool:
	return audit["has_box"]

func _board_mat(wb: Node3D) -> Material:
	var board: MeshInstance3D = wb.get_node_or_null("Board") as MeshInstance3D
	return board.material_override if board else null

func _registered(evac: Node, floor_index: int, node: Node) -> bool:
	var groups: Dictionary = evac._floor_groups
	if not groups.has(floor_index):
		return false
	for n in groups[floor_index]:
		if n == node:
			return true
	return false

func _count_named(node: Node, fragment: String) -> int:
	var n := 0
	for child in node.get_children():
		if String(child.name).contains(fragment):
			n += 1
	return n

func _count_models(node: Node) -> int:
	var n := 0
	for child in node.get_children():
		if child.scene_file_path != null and str(child.scene_file_path).begins_with("res://models/"):
			n += 1
	return n

## All direct children sit within [y_lo, y_hi] in world space.
func _all_at_y(node: Node3D, y_lo: float, y_hi: float) -> bool:
	if node.get_child_count() == 0:
		return false
	for child in node.get_children():
		if child is Node3D and not ((child as Node3D).global_position.y >= y_lo \
				and (child as Node3D).global_position.y <= y_hi):
			return false
	return true

func _count_desk_stuff(node: Node, acc: Array) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			for sub in (child as StaticBody3D).get_children():
				if sub is CollisionShape3D and sub.shape is BoxShape3D:
					var b: BoxShape3D = sub.shape
					if is_equal_approx(b.size.x, 2.0) and is_equal_approx(b.size.y, 1.2) \
							and is_equal_approx(b.size.z, 1.0):
						acc[0] += 1
						for decor in (child as StaticBody3D).get_children():
							if String(decor.name).begins_with("Monitor") \
									or String(decor.name).contains("desk_printer"):
								acc[1] += 1
							elif String(decor.name).begins_with("DeskPlant"):
								acc[2] += 1
					break
		_count_desk_stuff(child, acc)
