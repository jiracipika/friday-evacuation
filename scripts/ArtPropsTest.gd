# ArtPropsTest.gd — art-props slice invariants for the toybox monitor and
# the portal LIFT plaque. Verifies REAL built geometry, not source greps:
#   1. beveled_box(): cached low-poly chamfered ArrayMesh — nonempty
#      surfaces, finite bounds matching requested dimensions, one shared
#      mesh per dimensions.
#   2. monitor(): beveled ArrayMesh casing inside the old silhouette
#      footprint, bounded MeshInstance budget, minimal doc rows on lit
#      variants only, shared cached shell material, no CollisionObject3D
#      or Light3D anywhere under the monitor.
#   3. elevator_portal(): 'LIFT / NEXT FLOOR' plaque — Label3D AABB fits
#      the plaque backing AABB after mounting for a few frames, no digits
#      in the text (never a wrong destination number), no CollisionObject3D
#      or Light3D (portal stays decorative), bounded node count, groups
#      and exit_sign() semantics untouched.
# Run:
#   godot --headless --path . --script scripts/ArtPropsTest.gd --quit-after 10
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

	# --- 1. beveled_box helper ------------------------------------------
	var dims := Vector3(0.66, 0.42, 0.042)
	var bb: ArrayMesh = OD.beveled_box(dims, 0.016)
	check(bb != null and bb is ArrayMesh, "beveled_box returns ArrayMesh")
	if bb != null:
		var aabb := bb.get_aabb()
		check(aabb.position.is_finite() and aabb.end.is_finite(),
			"beveled bounds finite")
		check(absf(aabb.size.x - dims.x) < 0.01 and absf(aabb.size.y - dims.y) < 0.01 \
				and absf(aabb.size.z - dims.z) < 0.01,
			"beveled bounds match requested dims (%s vs %s)" % [aabb.size, dims])
		check(bb.get_surface_count() >= 1,
			"beveled mesh has nonempty surfaces (%d)" % bb.get_surface_count())
		var bb2: ArrayMesh = OD.beveled_box(dims, 0.016)
		check(bb2 == bb, "beveled mesh cached per dimensions")

	# --- 2. monitor ------------------------------------------------------
	var mon: Node3D = OD.monitor(0)
	check(mon != null and String(mon.name).begins_with("Monitor"),
		"monitor() root still named Monitor")
	var casing: MeshInstance3D = mon.get_node_or_null("Casing") as MeshInstance3D
	check(casing != null, "monitor has named Casing")
	if casing != null and casing.mesh != null:
		check(casing.mesh is ArrayMesh,
			"casing uses beveled ArrayMesh (got %s)" % casing.mesh.get_class())
	var mi_count := 0
	var box := AABB()
	var has_box := false
	var bad_nodes := 0
	var rows := 0
	for node in _walk(mon):
		if node is CollisionObject3D or node is Light3D:
			bad_nodes += 1
		if String(node.name).begins_with("DocRow"):
			rows += 1
		if node is MeshInstance3D:
			var mmi := node as MeshInstance3D
			mi_count += 1
			if mmi.mesh != null:
				var wa: AABB = mmi.transform * mmi.mesh.get_aabb()
				if has_box:
					box = box.merge(wa)
				else:
					box = wa
					has_box = true
	check(bad_nodes == 0, "monitor adds no CollisionObject3D/Light3D")
	check(mi_count >= 4 and mi_count <= 8,
		"monitor MeshInstance count bounded [4,8] (got %d)" % mi_count)
	check(rows >= 1 and rows <= 4,
		"lit monitor has minimal doc rows [1,4] (got %d)" % rows)
	if has_box:
		print("  monitor union AABB pos %s size %s" % [box.position, box.size])
		check(box.position.x >= -0.35 and box.end.x <= 0.35,
			"monitor within old X footprint")
		check(box.position.y >= -0.01 and box.end.y <= 0.70,
			"monitor within old Y envelope")
		check(box.position.z >= -0.105 and box.end.z <= 0.105,
			"monitor within Z tolerance of old footprint (old base 0.2 deep)")
	var mon_standby: Node3D = OD.monitor(2)
	var rows2 := 0
	for node in _walk(mon_standby):
		if String(node.name).begins_with("DocRow"):
			rows2 += 1
	check(rows2 == 0, "standby monitor has no doc rows (got %d)" % rows2)
	var mon_b: Node3D = OD.monitor(1)
	var c1: MeshInstance3D = mon.get_node_or_null("Casing") as MeshInstance3D
	var c2: MeshInstance3D = mon_b.get_node_or_null("Casing") as MeshInstance3D
	check(c1 != null and c2 != null and c1.material_override == c2.material_override,
		"monitor shells share one cached material")

	# --- 3. elevator portal plaque --------------------------------------
	var portal: Node3D = OD.elevator_portal(Vector3.ZERO, 0.0)
	check(portal != null and portal.is_in_group("elevator_portals"),
		"portal builds and group intact")
	root.add_child(portal)
	await process_frame
	await process_frame
	await process_frame
	var plaque: MeshInstance3D = portal.get_node_or_null("Plaque") as MeshInstance3D
	check(plaque != null, "portal has Plaque on the header front")
	var label: Label3D = portal.get_node_or_null("PlaqueLabel") as Label3D
	check(label != null, "portal has PlaqueLabel")
	if plaque != null and label != null:
		check(plaque.mesh is ArrayMesh,
			"plaque backing is beveled ArrayMesh")
		var back_aabb: AABB = plaque.global_transform * plaque.get_aabb()
		var text_aabb: AABB = label.global_transform * label.get_aabb()
		print("  plaque backing AABB %s" % back_aabb)
		print("  label text AABB %s" % text_aabb)
		var marg := 0.012
		check(text_aabb.position.x >= back_aabb.position.x - marg \
				and text_aabb.end.x <= back_aabb.end.x + marg \
				and text_aabb.position.y >= back_aabb.position.y - marg \
				and text_aabb.end.y <= back_aabb.end.y + marg,
			"label AABB fits inside plaque backing")
		check(label.text.find("LIFT") >= 0, "label says LIFT")
		var has_digit := false
		for dg in "0123456789":
			if label.text.find(dg) >= 0:
				has_digit = true
		check(not has_digit, "label has no destination digits")
	var p_bad := 0
	for node in _walk(portal):
		if node is CollisionObject3D or node is Light3D:
			p_bad += 1
	check(p_bad == 0, "portal adds no CollisionObject3D/Light3D (decorative)")
	check(portal.get_child_count() >= 7 and portal.get_child_count() <= 12,
		"portal child count bounded [7,12] (got %d)" % portal.get_child_count())

	# EXIT sign semantics untouched.
	var es: Node3D = OD.exit_sign(Vector3(5.0, 3.0, 5.0))
	var exit_label := false
	for node in _walk(es):
		if node is Label3D and (node as Label3D).text == "EXIT":
			exit_label = true
	check(exit_label and es.is_in_group("exit_signs"),
		"exit_sign() semantics unchanged")

	portal.queue_free()
	mon.queue_free()
	mon_standby.queue_free()
	mon_b.queue_free()
	es.queue_free()
	await process_frame

	check(checks_total > 0, "checks ran")
	print("ArtPropsTest: %d/%d checks passed" % [checks_passed, checks_total])
	if failures.is_empty() and checks_total > 0:
		quit(0)
	else:
		for f in failures:
			print("  - %s" % f)
		quit(1)

func _walk(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_walk(child))
	return out
