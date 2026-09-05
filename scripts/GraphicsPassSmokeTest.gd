# GraphicsPassSmokeTest.gd — verifies the 2026-09 graphics+polish pass.
# Checks (all dead-wiring style: presence/structure, not aesthetics):
#   1. OfficeDressing builders return real nodes with expected children.
#   2. Real Evacuation scene: tall walls (5.98m), ceiling slabs, troffer
#      panels, columns, elevator portals, blob-shadow groups.
#   3. Desk dressing: monitors/keyboards/mugs exist as non-colliding decor.
#   4. PlayerChair: blob shadow + landing puff mounted; backrest halo.
#   5. ImpactFX.boost_burst exists (was a dead call site before the pass).
# Run:
#   godot --headless --path . --script scripts/GraphicsPassSmokeTest.gd
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
		print("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://scenes/Evacuation.tscn")
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var evac = packed.instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame

	# --- 1. Tall walls close every floor band ---------------------------
	var tall_walls := 0
	var total_walls := 0
	for mi in _find_meshes(evac):
		var mesh: Mesh = mi.mesh
		if mesh is BoxMesh and is_equal_approx((mesh as BoxMesh).size.x, 40.0) \
				and absf((mesh as BoxMesh).size.z - 0.3) < 0.01:
			total_walls += 1
			if absf((mesh as BoxMesh).size.y - 5.98) < 0.01:
				tall_walls += 1
	check(total_walls >= 12, "wall meshes present (%d)" % total_walls)
	check(tall_walls == total_walls, "ALL walls full-height 5.98m (%d/%d)" % [tall_walls, total_walls])

	# --- 2. Ceiling slabs exist on every floor --------------------------
	var ceil_count := 0
	for mi in _find_meshes(evac):
		var mesh: Mesh = mi.mesh
		if mesh is BoxMesh:
			var bm := mesh as BoxMesh
			if is_equal_approx(bm.size.y, 0.12) and bm.size.x >= 39.0 and bm.size.z >= 9.0:
				ceil_count += 1
	check(ceil_count >= 5, "ceiling slabs present (3 full + 2 halves = 5, got %d)" % ceil_count)

	# --- 3. Troffer panels: 9 per floor x 4 floors, lens child present ---
	var panels := get_nodes_in_group("ceiling_panels")
	check(panels.size() >= 36, "36 ceiling panels across 4 floors (got %d)" % panels.size())
	var lens_ok := true
	for p in panels:
		if (p as MeshInstance3D).get_child_count() < 2:
			lens_ok = false
			break
	check(lens_ok, "every panel has frame+lens children")

	# --- 4. Columns with real collision ----------------------------------
	var columns := get_nodes_in_group("office_columns")
	check(columns.size() >= 16, "16 columns (4 per floor, got %d)" % columns.size())
	var col_has_collision := true
	for c in columns:
		var found := false
		for child in (c as StaticBody3D).get_children():
			if child is CollisionShape3D:
				found = true
		if not found:
			col_has_collision = false
	check(col_has_collision, "columns carry CollisionShape3D")

	# --- 5. Elevator portals + exit signs -------------------------------
	var portals := get_nodes_in_group("elevator_portals")
	check(portals.size() == 3, "3 elevator portals (got %d)" % portals.size())
	var signs := get_nodes_in_group("exit_signs")
	check(signs.size() == 3, "3 EXIT signs on portals (got %d)" % signs.size())

	# --- 6. Contact-shadow groups registered for culling ----------------
	var blob_groups := 0
	for child in evac.get_children():
		if String(child.name).begins_with("BlobShadows_F"):
			blob_groups += 1
	check(blob_groups >= 4, "blob shadow groups on all 4 floors (got %d)" % blob_groups)
	var blob_total := 0
	for child in evac.get_children():
		if String(child.name).begins_with("BlobShadows_F"):
			blob_total += (child as Node).get_child_count()
	check(blob_total >= 20, "blob shadows under props (got %d)" % blob_total)

	# --- 7. Desk dressing: monitors etc. on desks ------------------------
	var dressing: Array = [0, 0]  # [monitors, keyboards] — array = by-ref
	_count_dressing(evac, dressing)
	var monitors: int = dressing[0]
	var keyboards: int = dressing[1]
	var desk_count := _count_desks(evac)
	check(monitors >= desk_count, "a monitor per desk (%d desks, %d monitors)" % [desk_count, monitors])
	check(keyboards >= desk_count, "a keyboard per desk (%d got %d)" % [desk_count, keyboards])

	# --- 8. PlayerChair extras -------------------------------------------
	var chair_scene := load("res://scenes/PlayerChair.tscn")
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var chair = chair_scene.instantiate()
	chair.set_physics_process(false)
	root.add_child(chair)
	await process_frame
	var blob: Node = chair.get_node_or_null("ChairBlobShadow")
	check(blob != null, "chair blob shadow mounted")
	var puff: Node = chair.get_node_or_null("LandingPuff")
	check(puff != null and puff is GPUParticles3D, "landing puff mounted")
	var halo: Node = chair.get_node_or_null("ModelParent/ProceduralChair/BackrestHalo")
	check(halo != null, "backrest halo present (team ID)")
	# Rider child names are auto-generated for plain meshes; just count parts.
	var rider: Node = null
	for child in chair.get_node_or_null("ModelParent/ProceduralChair").get_children():
		if String(child.name).begins_with("Rider_"):
			rider = child
	check(rider != null and rider.get_child_count() >= 8,
		"rider has upgraded part count (got %s)" % (str(rider.get_child_count()) if rider else "none"))
	chair.queue_free()

	# --- 9. ImpactFX.boost_burst wired (was dead call site) --------------
	var fx = load("res://scripts/ImpactFX.gd")
	check(fx != null and fx.has_method("boost_burst"), "ImpactFX.boost_burst exists")

	# --- 10. OfficeDressing direct builders ------------------------------
	var Dressing = load("res://scripts/OfficeDressing.gd")
	var panel: MeshInstance3D = Dressing.ceiling_panel()
	check(panel != null and panel.is_in_group("ceiling_panels"), "ceiling_panel() builder")
	var portal: Node3D = Dressing.elevator_portal(Vector3.ZERO, 0.0)
	check(portal.get_child_count() >= 7, "portal has posts+doors+seams (got %d)" % portal.get_child_count())
	var blob2: MeshInstance3D = Dressing.blob_shadow(1.5, 0.4)
	check(blob2 != null and blob2.mesh is PlaneMesh, "blob_shadow() builder")

	evac.queue_free()
	await process_frame

	if failures.is_empty() and checks_total > 0:
		print("=== GRAPHICS PASS SMOKE TEST PASS (%d/%d) ===" % [checks_passed, checks_total])
		quit(0)
	else:
		print("=== GRAPHICS PASS SMOKE TEST FAILED (%d/%d) ===" % [checks_passed, checks_total])
		for f in failures:
			print("  - %s" % f)
		quit(1)

func _find_meshes(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child)
		out.append_array(_find_meshes(child))
	return out

func _count_dressing(node: Node, acc: Array) -> void:
	for child in node.get_children():
		if String(child.name).begins_with("Monitor"):
			acc[0] += 1
		elif String(child.name) == "Keyboard":
			acc[1] += 1
		_count_dressing(child, acc)

func _count_desks(node: Node) -> int:
	var desks := 0
	for child in node.get_children():
		if child is StaticBody3D:
			for sub in (child as StaticBody3D).get_children():
				if sub is CollisionShape3D and sub.shape is BoxShape3D:
					var b: BoxShape3D = sub.shape
					if is_equal_approx(b.size.x, 2.0) and is_equal_approx(b.size.y, 1.2) \
							and is_equal_approx(b.size.z, 1.0):
						desks += 1
					break
	return desks
