class_name FridayOfficeCharacterVisual
extends RefCounted
## One flat-shaded model builder shared by the race, LAN avatars and designer.
## All detail is cosmetic; no colliders, lights, textures or gameplay modifiers.

const Design = preload("res://scripts/CharacterDesign.gd")
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

static func build(character: Dictionary, overrides: Dictionary = {}) -> Node3D:
	var d := Design.resolve(character, overrides)
	var root := Node3D.new()
	root.name = "Rider_" + str(character.id)
	root.set_meta("design", d)
	var skin := Color(d.skin_tone)
	var cloth := Color(d.shirt_color)
	var accent := Color(d.accent_color)
	var hair := Color(d.hair_color)
	var ink := Color("252b3e")
	var width := 0.66 if d.build == "stocky" else (0.44 if d.build == "lanky" else 0.55)
	var height := 0.65 if d.build == "lanky" else 0.54
	var head_y := 1.48 + height - 0.54
	# Seated anatomy: bent trousers, chunky shoes, sleeves and visible hands.
	for side in [-1.0, 1.0]:
		box(root, "Thigh", Vector3(0.19, 0.19, 0.43), Vector3(side * 0.16, 0.54, -0.23), ink)
		box(root, "Shin", Vector3(0.16, 0.3, 0.16), Vector3(side * 0.16, 0.35, -0.4), ink)
		box(root, "Shoe", Vector3(0.2, 0.14, 0.31), Vector3(side * 0.16, 0.18, -0.49), ink.darkened(0.3))
		var sleeve := box(root, "Sleeve", Vector3(0.18, 0.36, 0.2), Vector3(side * (width / 2.0 + 0.04), 0.99, -0.12), cloth.darkened(0.1))
		sleeve.rotation.x = -0.52
		box(root, "Hand", Vector3(0.14, 0.15, 0.17), Vector3(side * (width / 2.0 + 0.04), 0.83, -0.22), skin)
	box(root, "Torso", Vector3(width, height, 0.35), Vector3(0, 0.97, 0), cloth, 0.065)
	box(root, "Neck", Vector3(0.15, 0.15, 0.16), Vector3(0, head_y - 0.3, -0.02), skin.darkened(0.1))
	# Tailoring gives outfits distinct silhouettes and readable office details.
	match d.outfit:
		"blazer":
			box(root, "ShirtFront", Vector3(0.2, height * 0.78, 0.03), Vector3(0, 0.99, -0.183), Color("f7f6f2"), 0)
			for side in [-1.0, 1.0]:
				var lapel := box(root, "Lapel", Vector3(0.1, 0.29, 0.055), Vector3(side * 0.13, 1.09, -0.21), cloth.darkened(0.23), 0.01)
				lapel.rotation.z = side * -0.28
			box(root, "Tie", Vector3(0.06, 0.26, 0.035), Vector3(0, 1.0, -0.218), accent, 0.015)
		"hoodie":
			box(root, "Hood", Vector3(width * 0.8, 0.26, 0.23), Vector3(0, 1.21, 0.15), cloth.darkened(0.22), 0.07)
			box(root, "Pocket", Vector3(width * 0.55, 0.13, 0.04), Vector3(0, 0.86, -0.19), cloth.darkened(0.15))
			for side in [-1.0, 1.0]:
				box(root, "Drawstring", Vector3(0.018, 0.21, 0.024), Vector3(side * 0.08, 1.1, -0.19), Color("f7f6f2"), 0)
		"cardigan":
			box(root, "Blouse", Vector3(0.21, height * 0.85, 0.03), Vector3(0, 0.98, -0.19), Color("f7f6f2"))
			for y in [0.84, 0.94, 1.04]:
				box(root, "Button", Vector3(0.035, 0.035, 0.035), Vector3(0.14, y, -0.198), accent, 0.008)
		"hi_vis":
			box(root, "VestZip", Vector3(0.035, height, 0.035), Vector3(0, 0.97, -0.19), ink, 0)
			for side in [-1.0, 1.0]:
				box(root, "Reflector", Vector3(0.065, height * 0.95, 0.035), Vector3(side * width * 0.3, 0.97, -0.195), Color("f7f6f2"), 0)
			box(root, "ToolBelt", Vector3(width + 0.03, 0.1, 0.39), Vector3(0, 0.74, 0), ink)
			box(root, "ToolPouch", Vector3(0.16, 0.2, 0.13), Vector3(width / 2, 0.68, -0.12), Color("805b40"))
	# A real hanging badge, visible on every outfit.
	for side in [-1.0, 1.0]:
		var cord := box(root, "Lanyard", Vector3(0.016, 0.19, 0.015), Vector3(side * 0.04, 1.13, -0.22), accent, 0)
		cord.rotation.z = side * 0.35
	box(root, "Badge", Vector3(0.1, 0.13, 0.035), Vector3(0, 0.98, -0.24), Color("f7f6f2"), 0.008)
	box(root, "BadgePhoto", Vector3(0.042, 0.05, 0.012), Vector3(0, 1.0, -0.263), accent, 0)
	# Head pivot permits a gentle inertial tilt without deforming the body.
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, head_y, -0.025)
	root.add_child(head)
	box(head, "HeadMesh", Vector3(0.48, 0.51, 0.43), Vector3.ZERO, skin, 0.065)
	for side in [-1.0, 1.0]:
		box(head, "Ear", Vector3(0.09, 0.13, 0.1), Vector3(side * 0.25, -0.01, 0), skin)
	box(head, "Nose", Vector3(0.085, 0.105, 0.105), Vector3(0, -0.03, -0.254), skin.darkened(0.07))
	build_hair(head, str(d.hair), hair)
	build_face(head, str(d.expression), ink)
	if character.id in ["it_iggy", "remote_ron"]:
		box(head, "HeadsetBand", Vector3(0.58, 0.065, 0.15), Vector3(0, 0.27, 0), ink)
		for side in [-1.0, 1.0]:
			box(head, "Headphones", Vector3(0.1, 0.21, 0.2), Vector3(side * 0.29, 0.01, 0), accent)
	elif character.id in ["finance_fiona", "legal_lee", "spreadsheet_stu"]:
		for side in [-1.0, 1.0]:
			box(head, "GlassesTop", Vector3(0.2, 0.022, 0.026), Vector3(side * 0.12, 0.12, -0.302), ink, 0)
			box(head, "GlassesBottom", Vector3(0.2, 0.02, 0.026), Vector3(side * 0.12, -0.005, -0.302), ink, 0)
			for edge in [-1.0, 1.0]:
				box(head, "GlassesSide", Vector3(0.02, 0.14, 0.026), Vector3(side * 0.12 + edge * 0.09, 0.06, -0.302), ink, 0)
		box(head, "GlassesBridge", Vector3(0.055, 0.02, 0.03), Vector3(0, 0.07, -0.305), ink, 0)
	build_accessory(root, str(d.accessory), accent)
	return root

static func build_hair(head: Node3D, style: String, color: Color) -> void:
	if style == "bald":
		for side in [-1.0, 1.0]:
			box(head, "Sideburn", Vector3(0.035, 0.1, 0.15), Vector3(side * 0.24, 0.06, 0.06), color)
		return
	box(head, "HairCap", Vector3(0.5, 0.14, 0.45), Vector3(0, 0.23, 0.015), color, 0.05)
	match style:
		"side_part":
			var fringe := box(head, "SweptFringe", Vector3(0.35, 0.14, 0.09), Vector3(-0.07, 0.19, -0.21), color)
			fringe.rotation.z = -0.16
		"bob":
			box(head, "BobBack", Vector3(0.5, 0.39, 0.11), Vector3(0, 0.015, 0.22), color)
			for side in [-1.0, 1.0]:
				box(head, "BobSide", Vector3(0.09, 0.4, 0.4), Vector3(side * 0.25, 0.015, 0.01), color)
		"bun":
			sphere(head, "HairBun", 0.15, Vector3(0, 0.32, 0.17), color)
		"bedhead":
			for i in 4:
				var tuft := box(head, "HairTuft", Vector3(0.12, 0.16 + (i % 2) * 0.05, 0.2), Vector3(-0.2 + i * 0.13, 0.33, -0.06), color)
				tuft.rotation.z = -0.4 + i * 0.27

static func build_face(head: Node3D, expression: String, ink: Color) -> void:
	for side in [-1.0, 1.0]:
		var derpy := expression == "derpy"
		var eye_y: float = 0.065 + (side * 0.025 if derpy else 0.0)
		var radius := (0.085 if side < 0 else 0.06) if derpy else (0.082 if expression == "panic" else 0.065)
		var eye := sphere(head, "EyeWhite", radius, Vector3(side * 0.112, eye_y, -0.225), Color.WHITE)
		eye.scale.z = 0.5
		var pupil := sphere(head, "PupilL" if side < 0 else "PupilR", 0.026 if expression != "panic" else 0.018, Vector3(side * 0.112 + (side * -0.024 if derpy else 0), eye_y - (0.018 if derpy else 0), -0.27), ink)
		pupil.scale.z = 0.35
		pupil.set_meta("rest_position", pupil.position)
		if expression == "sleepy":
			box(head, "SleepyLid", Vector3(0.14, 0.055, 0.028), Vector3(side * 0.112, 0.105, -0.27), Color("947566"), 0.01)
		else:
			var brow := box(head, "Brow", Vector3(0.13, 0.025, 0.025), Vector3(side * 0.11, 0.16, -0.249), ink, 0)
			brow.rotation.z = side * (0.3 if expression == "focused" else -0.22)
	if expression == "panic":
		var mouth := sphere(head, "Gasp", 0.058, Vector3(0, -0.145, -0.223), ink)
		mouth.scale = Vector3(0.8, 1.2, 0.25)
	else:
		var grin := box(head, "Mouth", Vector3(0.17, 0.047 if expression == "derpy" else 0.025, 0.023), Vector3(0.015, -0.142, -0.223), ink, 0.006)
		grin.rotation.z = -0.18 if expression == "derpy" else 0.0
		if expression == "derpy":
			box(head, "SingleTooth", Vector3(0.037, 0.039, 0.014), Vector3(-0.025, -0.147, -0.24), Color.WHITE, 0)

static func build_accessory(root: Node3D, kind: String, color: Color) -> void:
	var prop := Node3D.new()
	prop.name = "Accessory_" + kind
	root.add_child(prop)
	var paper := Color("f7f6f2")
	var ink := Color("252b3e")
	match kind:
		"clipboard_shield", "policy_binder", "waiver_scroll":
			prop.position = Vector3(0.44, 0.99, -0.32)
			prop.rotation.z = -0.14
			box(prop, "Cover", Vector3(0.3, 0.4, 0.065), Vector3.ZERO, color)
			box(prop, "Paper", Vector3(0.25, 0.32, 0.025), Vector3(0, -0.01, -0.045), paper, 0.008)
			for y in [-0.07, 0, 0.07]:
				box(prop, "TextLine", Vector3(0.15, 0.014, 0.008), Vector3(0, y, -0.064), ink, 0)
			if kind == "clipboard_shield":
				box(prop, "Clip", Vector3(0.14, 0.07, 0.035), Vector3(0, 0.16, -0.047), ink)
			elif kind == "policy_binder":
				box(prop, "Spine", Vector3(0.06, 0.4, 0.1), Vector3(-0.14, 0, 0), ink)
			else:
				box(prop, "TrailingWaiver", Vector3(0.25, 0.32, 0.025), Vector3(0, -0.31, 0.025), paper)
		"coffee_tower":
			prop.position = Vector3(0.43, 1.0, -0.2)
			box(prop, "Tray", Vector3(0.34, 0.045, 0.27), Vector3(0, -0.12, 0), ink)
			for i in 3:
				var cup := cylinder(prop, "CoffeeCup", 0.072, 0.16, Vector3((i % 2) * 0.018, i * 0.17, 0), paper)
				cup.rotation.z = (i - 1) * 0.1
				cylinder(prop, "CoffeeLid", 0.08, 0.025, Vector3((i % 2) * 0.018, i * 0.17 + 0.087, 0), ink)
				cylinder(prop, "CupSleeve", 0.074, 0.06, Vector3((i % 2) * 0.018, i * 0.17, 0), color)
		"keyboard_booster", "calculator_dash":
			prop.position = Vector3(0, 0.78, 0.35) if kind == "keyboard_booster" else Vector3(0.43, 0.94, -0.3)
			var keyboard := kind == "keyboard_booster"
			box(prop, "Housing", Vector3(0.58 if keyboard else 0.22, 0.25, 0.07), Vector3.ZERO, ink)
			for x in (6 if keyboard else 3):
				for y in 2:
					box(prop, "Key", Vector3(0.055, 0.045, 0.023), Vector3(-0.23 + x * 0.09 if keyboard else -0.066 + x * 0.066, -0.045 + y * 0.065, -0.05), paper if x % 2 == 0 else color, 0.005)
			if not keyboard:
				box(prop, "Display", Vector3(0.17, 0.04, 0.02), Vector3(0, 0.085, -0.05), color)
		"mop_lance":
			prop.position = Vector3(0.47, 1.1, 0)
			prop.rotation.z = -0.19
			cylinder(prop, "Handle", 0.025, 1.0, Vector3.ZERO, Color("b88a57"))
			box(prop, "MopHead", Vector3(0.27, 0.16, 0.18), Vector3(0, 0.55, 0), paper)
			for x in [-0.09, 0, 0.09]:
				box(prop, "MopStrand", Vector3(0.035, 0.16, 0.035), Vector3(x, 0.43, -0.1), color)
		"webcam_drone":
			prop.position = Vector3(0.48, 1.58, 0.1)
			box(prop, "CameraBody", Vector3(0.25, 0.16, 0.16), Vector3.ZERO, color)
			var lens := cylinder(prop, "Lens", 0.047, 0.04, Vector3(0, 0, -0.1), ink)
			lens.rotation.x = PI / 2
			box(prop, "Rotor", Vector3(0.38, 0.018, 0.04), Vector3(0, 0.12, 0), ink, 0)

static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.88
		_materials[key] = mat
	return _materials[key]

static func piece(parent: Node3D, label: String, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, color: Color, bevel: float = 0.025) -> MeshInstance3D:
	var key := "box:%s:%s" % [size, bevel]
	if not _meshes.has(key):
		_meshes[key] = bevel_box(size, bevel)
	return piece(parent, label, _meshes[key], pos, color)

static func sphere(parent: Node3D, label: String, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var key := "sphere:%s" % radius
	if not _meshes.has(key):
		var primitive := SphereMesh.new()
		primitive.radius = radius
		primitive.height = radius * 2
		primitive.radial_segments = 8
		primitive.rings = 4
		_meshes[key] = flatten(primitive)
	return piece(parent, label, _meshes[key], pos, color)

static func cylinder(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var key := "cylinder:%s:%s" % [radius, height]
	if not _meshes.has(key):
		var primitive := CylinderMesh.new()
		primitive.top_radius = radius
		primitive.bottom_radius = radius * 0.88
		primitive.height = height
		primitive.radial_segments = 8
		_meshes[key] = flatten(primitive)
	return piece(parent, label, _meshes[key], pos, color)

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot uses clockwise front faces.
	var normal := (c - a).cross(b - a).normalized()
	for vertex in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(vertex)

static func flatten(mesh: Mesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		triangle(st, vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]])
	return st.commit()

static func bevel_box(size: Vector3, requested: float) -> ArrayMesh:
	var half := size * 0.5
	var bevel := minf(requested, minf(half.x, minf(half.y, half.z)) * 0.8)
	if bevel <= 0:
		var primitive := BoxMesh.new()
		primitive.size = size
		return flatten(primitive)
	var rings: Array[PackedVector3Array] = []
	for layer in 4:
		var inset := bevel if layer in [0, 3] else 0.0
		var x := half.x - inset
		var z := half.z - inset
		var cut := minf(bevel, minf(x, z) * 0.8)
		var y: float = [-half.y, -half.y + bevel, half.y - bevel, half.y][layer]
		rings.append(PackedVector3Array([
			Vector3(-x + cut, y, -z), Vector3(x - cut, y, -z),
			Vector3(x, y, -z + cut), Vector3(x, y, z - cut),
			Vector3(x - cut, y, z), Vector3(-x + cut, y, z),
			Vector3(-x, y, z - cut), Vector3(-x, y, -z + cut),
		]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 3:
		for i in 8:
			var j := (i + 1) % 8
			triangle(st, rings[layer][i], rings[layer + 1][j], rings[layer + 1][i])
			triangle(st, rings[layer][i], rings[layer][j], rings[layer + 1][j])
	for i in 8:
		var j := (i + 1) % 8
		triangle(st, Vector3(0, -half.y, 0), rings[0][j], rings[0][i])
		triangle(st, Vector3(0, half.y, 0), rings[3][i], rings[3][j])
	return st.commit()
