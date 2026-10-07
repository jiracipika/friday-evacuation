# TrapAccessibilitySmokeTest.gd — FINAL-day bar for the Phase 8B trap shape
# cues (upgrades what Phase8BAccessTest pins). Spawns one trap of EACH type
# and asserts, per type:
#   1. a Label3D exists with the exact short-word name (WATER/BANANA/...),
#      billboarded and scaled to read at driving speed;
#   2. a shape-icon MESH exists whose class/face-count signature is DISTINCT
#      per type — this is what makes banana vs spill (both yellow) tellable
#      by SHAPE alone (spill is even a different mesh class: CylinderMesh);
#   3. cast_shadow == OFF on every new visual (thin floating geometry paints
#     light stripes — docs/GLM-NEXT-SLICE.md traps list);
#   4. the cue adds ZERO collision shapes to the trap body.
# Run: godot --headless --path . --script scripts/TrapAccessibilitySmokeTest.gd
extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("[PASS] " + label)
	else:
		failures.append(label)
		printerr("[FAIL] " + label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var trap_scene = load("res://scenes/objects/SabotageTrap.tscn")
	check(trap_scene != null, "SabotageTrap scene loads")
	if trap_scene == null:
		_finish()
		return

	var expected := {
		"water": "WATER",
		"banana": "BANANA",
		"stapler": "STAPLER",
		"spill": "SPILL",
	}
	# "mesh class : total face verts" — a structural shape signature. Two
	# types may only share it if their geometry is identical, which would
	# break the squint test.
	var signatures := {}
	for trap_type in expected.keys():
		var trap = trap_scene.instantiate()
		# Script-compile gate: if SabotageTrap.gd has a parse error the scene
		# instantiates as a bare Area3D and calling _set_forced_type aborts
		# _run — which would skip quit() and hang the suite. Fail cleanly.
		check(trap.has_method("_set_forced_type"), "SabotageTrap.gd compiles + attaches")
		if not trap.has_method("_set_forced_type"):
			trap.free()
			_finish()
			return
		trap._set_forced_type(trap_type)
		root.add_child(trap)
		trap.position = Vector3(1000, 0, 1000)  # boonies: no physics contact
		await process_frame
		await process_frame

		var label: Label3D = null
		var icon: MeshInstance3D = null
		for child in trap.get_children():
			if child is Label3D and label == null:
				label = child
			elif child is MeshInstance3D and child.name == "ShapeIcon" and icon == null:
				icon = child

		# (1) name label, exact text, readable at speed
		check(label != null, "%s trap has a name label" % trap_type)
		check(label != null and label.text == expected[trap_type],
			"%s label reads exactly '%s'" % [trap_type, expected[trap_type]])
		check(label != null and label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
			"%s label billboards (readable from any approach)" % trap_type)
		check(label != null and label.font_size * label.pixel_size >= 0.4,
			"%s label cap height >= 0.4m (got %.2fm)" % [
				trap_type, label.font_size * label.pixel_size if label else -1.0])
		check(label != null and label.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"%s label cast_shadow OFF" % trap_type)

		# (2) shape icon mesh — the silhouette cue
		check(icon != null and icon.mesh != null, "%s trap has a shape icon mesh" % trap_type)
		if icon and icon.mesh:
			var faces: int = icon.mesh.get_faces().size()
			check(faces > 0, "%s icon mesh has geometry (%d face verts)" % [trap_type, faces])
			signatures[trap_type] = "%s:%d" % [icon.mesh.get_class(), faces]
		else:
			signatures[trap_type] = "MISSING"

		# (3) shadow discipline on the new mesh
		check(icon != null and icon.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"%s icon cast_shadow OFF" % trap_type)

		# (4) zero new collision — cue is pure dressing
		var col_count := 0
		for col in trap.find_children("*", "CollisionShape3D", true, false):
			col_count += 1
		check(col_count == 1, "%s trap body keeps exactly 1 collision (found %d)" % [trap_type, col_count])

		trap.queue_free()
		await process_frame

	# Shape distinctness — pairwise, the actual colorblind requirement.
	var types := signatures.keys()
	for i in types.size():
		for j in range(i + 1, types.size()):
			var a: String = signatures[types[i]]
			var b: String = signatures[types[j]]
			check(a != b, "%s icon shape differs from %s (%s vs %s)" % [types[i], types[j], a, b])

	# The yellow pair must not even share a mesh CLASS (belt and braces:
	# banana is a crescent ArrayMesh, spill a CylinderMesh disc).
	check(signatures.get("banana", "").begins_with("ArrayMesh") \
			and signatures.get("spill", "").begins_with("CylinderMesh"),
		"banana vs spill differ by mesh class (Arc ArrayMesh vs disc CylinderMesh)")

	_finish()

func _finish() -> void:
	print("")
	if failures.is_empty():
		print("=== TRAP ACCESSIBILITY SMOKE TEST PASSED (%d checks) ===" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("[FAILED] " + f)
		print("=== TRAP ACCESSIBILITY SMOKE TEST FAILED (%d/%d) ===" % [failures.size(), checks])
		quit(1)
