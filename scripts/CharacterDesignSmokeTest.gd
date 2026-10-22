extends SceneTree

const Design = preload("res://scripts/CharacterDesign.gd")
const Roster = preload("res://scripts/CharacterRoster.gd")
const Visual = preload("res://scripts/OfficeCharacterVisual.gd")
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[FAIL] " + label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	check(Design.sanitize({"hair": "bun", "build": 4, "shirt_color": "BAD", "unknown": "x"}) == {"hair": "bun"}, "untrusted save/RPC choices are bounded")
	check(Design.sanitize("not a dictionary").is_empty(), "malformed saved design ignored")
	for character in Roster.all():
		var rider := Visual.build(character)
		var triangles := 0
		for node in rider.find_children("*", "MeshInstance3D", true, false):
			triangles += node.mesh.get_faces().size() / 3
		check(triangles < 6000, "%s rider triangle budget: %d" % [character.id, triangles])
		var head := rider.get_node("Head/HeadMesh") as MeshInstance3D
		var arrays := head.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var outward := true
		for i in range(0, verts.size(), 3):
			var center := (verts[i] + verts[i + 1] + verts[i + 2]) / 3
			if center.dot(normals[i]) <= 0:
				outward = false
		check(outward, "beveled head faces point outward")
		rider.free()
	# Save/load edits for two characters; reset must only affect the active one.
	var gm = root.get_node("GameManager")
	var old_id: String = gm.selected_character_id
	var old_color: Color = gm.player_color
	var old_designs: Dictionary = gm.character_designs.duplicate(true)
	var identity_path := "user://identity.cfg"
	var had_save := FileAccess.file_exists(identity_path)
	var bytes := FileAccess.get_file_as_bytes(identity_path) if had_save else PackedByteArray()
	gm.selected_character_id = "deadline_dana"
	gm.set_character_design({"outfit": "hoodie", "hair": "bun", "shirt_color": "57d7ff"})
	gm.selected_character_id = "coffee_carl"
	gm.set_character_design({"expression": "panic"})
	gm.character_designs.clear()
	gm._load_identity()
	check(gm.get_character_design() == {"expression": "panic"}, "active design survives disk round trip")
	gm.selected_character_id = "deadline_dana"
	check(gm.get_character_design().hair == "bun", "each coworker retains its own edits")
	# Exercise actual UI controls and the same scene used by gameplay.
	var menu = load("res://scenes/Main.tscn").instantiate()
	root.add_child(menu)
	menu._open_customize_subview()
	await process_frame
	var designer = menu.character_designer
	check(designer != null and designer.selectors.size() == Design.OPTIONS.size(), "designer mounts all cosmetic controls")
	designer.selectors.expression.item_selected.emit(Design.OPTIONS.expression.find("derpy"))
	check(gm.get_character_design().expression == "derpy", "UI choice updates saved identity")
	var chair = load("res://scenes/PlayerChair.tscn").instantiate()
	root.add_child(chair)
	chair.set_physics_process(false)
	check(chair.rider_root.visible, "default chair displays the customizable rider")
	check(chair.rider_root.get_meta("design").expression == "derpy", "gameplay resolves saved custom face")
	var worker := chair.find_child("Worker", true, false) as Node3D
	check(worker != null and not worker.visible, "baked worker no longer masks customization")
	var hero := chair.find_child("HeroAssembly", true, false) as Node3D
	check(hero != null and is_equal_approx(hero.rotation.x, PI / 2), "authored chair stands upright under seated rider")
	var minimum: float = chair._visual_min_y(chair.model_parent, Transform3D.IDENTITY)
	check(is_equal_approx(minimum + chair.model_parent.position.y, -0.6), "visual wheel contact matches physics capsule bottom")
	for wheel in chair.chair_wheels:
		check(not wheel.visible, "default authored chair hides duplicate procedural wheels")
	chair.free()
	var reset := designer.find_child("ResetDesign", true, false) as Button
	reset.pressed.emit()
	check(gm.get_character_design().is_empty(), "reset restores active preset")
	check(gm.character_designs.coffee_carl.expression == "panic", "reset preserves other coworkers")
	menu.free()
	gm.selected_character_id = old_id
	gm.player_color = old_color
	gm.character_designs = old_designs
	if had_save:
		var file := FileAccess.open(identity_path, FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	else:
		DirAccess.remove_absolute(identity_path)
	print("CharacterDesignSmokeTest: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
