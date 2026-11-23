extends RefCounted
## Shared manufactured materials and collision proxies. Props are authored GLBs.
static var materials: Dictionary = {}
static var scenes: Dictionary = {}
const IVORY := Color("e3dfd3")
const TEAL := Color("377f80")
const INK := Color("293743")
const ORANGE := Color("ea873b")

static func material(color: Color, roughness := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [color, roughness, metal]
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = metal
		materials[key] = mat
	return materials[key]

static func decor_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material(color)
	parent.add_child(mesh)
	return mesh

static func solid(parent: Node3D, size: Vector3, pos: Vector3, color: Color, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	parent.add_child(body)
	decor_box(body, size, Vector3.ZERO, color)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	return body

static func prop(parent: Node3D, id: String, pos: Vector3, yaw := 0.0, collision := true) -> Node3D:
	var path := "res://models/overhaul/%s.glb" % id
	if not scenes.has(id):
		scenes[id] = load(path)
	var obj: Node3D = scenes[id].instantiate()
	obj.position = pos
	obj.rotation.y = yaw
	parent.add_child(obj)
	if collision:
		var sizes := {"desk": Vector3(2.3, 0.9, 1.0), "sofa": Vector3(2.6, 1.3, 0.95), "cabinet": Vector3(1, 1, 0.55), "plant": Vector3(0.45, 1.0, 0.45), "printer": Vector3(1.1, 1.1, 0.8), "vending": Vector3(1.2, 2.2, 0.8), "water": Vector3(0.55, 1.4, 0.5), "meeting": Vector3(5, 0.9, 1.8), "shelf": Vector3(2.3, 2.1, 0.65)}
		if sizes.has(id):
			var body := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = sizes[id]
			col.shape = box
			col.position.y = box.size.y * 0.5
			body.add_child(col)
			obj.add_child(body)
	return obj

static func text(parent: Node3D, words: String, pos: Vector3, size := 40, color := IVORY) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font_size = size
	label.font = preload("res://assets/fonts/Display.ttf")
	label.pixel_size = 0.006
	label.outline_size = 0
	label.modulate = color
	label.position = pos
	parent.add_child(label)
	return label

static func room(parent: Node3D, origin: Vector3, variant := 0) -> Node3D:
	var room_root := Node3D.new()
	room_root.position = origin
	parent.add_child(room_root)
	solid(room_root, Vector3(48, 0.3, 44), Vector3(0, -0.15, 0), Color("929d99") if variant == 3 else Color("697f80"))
	# Floor inlays establish scale without noisy procedural normal maps.
	for x in range(-22, 24, 4):
		decor_box(room_root, Vector3(0.025, 0.006, 44), Vector3(x, 0.005, 0), Color("647779"))
	for z in range(-20, 22, 4):
		decor_box(room_root, Vector3(48, 0.006, 0.025), Vector3(0, 0.006, z), Color("647779"))
	for side in [-1, 1]:
		solid(room_root, Vector3(0.35, 3.2, 44), Vector3(side * 24, 1.6, 0), IVORY)
		for z in range(-20, 22, 8):
			decor_box(room_root, Vector3(0.38, 2.2, 5.7), Vector3(side * 23.99, 2.0, z), Color("a7c3c5"))
			decor_box(room_root, Vector3(0.4, 0.08, 5.9), Vector3(side * 23.98, 0.85, z), INK)
		for z in [-20, 0, 20]:
			decor_box(room_root, Vector3(0.6, 4.3, 0.6), Vector3(side * 22, 2.15, z), IVORY)
	# Baffles preserve a cutaway view, even with a high chase camera.
	for z in range(-18, 22, 8):
		for side in [-1, 1]:
			decor_box(room_root, Vector3(0.8, 0.14, 3), Vector3(side * 21.7, 3.6, z), Color("fff1c9"))
	return room_root

static func environment(parent: Node3D, mode := "evacuation") -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = {
		"evacuation": Color("687c87"), "hauled": Color("4f6378"),
		"seek": Color("98a9ab"), "pizza": Color("774b47")
	}[mode]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c5d0da")
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	parent.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "OfficeSun"
	sun.rotation_degrees = Vector3(-56, -32, 0)
	sun.light_color = Color("e4efff") if mode == "hauled" else Color("ffdfb7")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 42
	parent.add_child(sun)

static func sign(parent: Node3D, words: String, pos: Vector3, size: Vector2, background := TEAL, foreground := IVORY) -> Node3D:
	var board := Node3D.new()
	board.position = pos
	parent.add_child(board)
	decor_box(board, Vector3(size.x, size.y, 0.07), Vector3.ZERO, background)
	var lettering := text(board, words, Vector3(0, 0, 0.047), 48, foreground)
	var longest := 1
	for line in words.split("\n"):
		longest = maxi(longest, line.length())
	lettering.pixel_size = minf(size.x / (longest * 25.0), size.y / (58.0 * words.split("\n").size())) * 0.88
	return board

static func batch_decor(art: Node3D) -> void:
	# These box meshes are decoration. Group them by material before drawing.
	var groups: Dictionary = {}
	for node in art.find_children("*", "MeshInstance3D", true, false):
		if node.mesh is BoxMesh and node.material_override:
			var key: Material = node.material_override
			if not groups.has(key):
				groups[key] = []
			groups[key].append(node)
	for acrylic in groups:
		var pieces: Array = groups[acrylic]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = BoxMesh.new()
		multi.instance_count = pieces.size()
		for index in pieces.size():
			var node: MeshInstance3D = pieces[index]
			var transform := art.global_transform.affine_inverse() * node.global_transform
			transform.basis = transform.basis.scaled_local(node.mesh.size)
			multi.set_instance_transform(index, transform)
			node.free()
		var draw := MultiMeshInstance3D.new()
		draw.multimesh = multi
		draw.material_override = acrylic
		art.add_child(draw)
