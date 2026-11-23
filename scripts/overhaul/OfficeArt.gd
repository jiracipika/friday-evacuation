extends RefCounted
## Partitions, signs and floor markings are presentation only.
const Kit = preload("res://scripts/overhaul/OfficeKit.gd")
const FLOOR_FINISH = preload("res://assets/floor_finish.gdshader")
const FLOORS := [Color("557b72"), Color("ae8966"), Color("b66d55"), Color("707d8c")]
const DEPARTMENTS := [Color("296b64"), Color("8c522e"), Color("9d483d"), Color("344c67")]
const GOLD := Color("ffcd68")
const DARK := Color("182631")
const LIGHT := Color("f6deb2")

static func stage(parent: Node3D) -> void:
	var art := Node3D.new()
	parent.add_child(art)
	Kit.decor_box(art, Vector3(28, 0.4, 20), Vector3(0, -0.22, 0), Color("798a81"))
	for x in range(-12, 14, 2):
		Kit.decor_box(art, Vector3(0.018, 0.008, 20), Vector3(x, 0, 0), Color("5e7469"))
	Kit.decor_box(art, Vector3(28, 5.5, 0.3), Vector3(0, 2.7, -4.5), Color("cfc6ad"))
	Kit.decor_box(art, Vector3(28, 0.94, 0.34), Vector3(0, 0.47, -4.28), Kit.TEAL)
	for x in [-5.0, -1.7, 1.6]:
		_window(art, Vector3(x, 2.85, -4.28))
	Kit.decor_box(art, Vector3(2.05, 3.1, 0.18), Vector3(4.4, 1.55, -4.12), Kit.INK)
	Kit.decor_box(art, Vector3(1.82, 2.88, 0.18), Vector3(4.4, 1.45, -3.99), Color("b35c38"))
	Kit.decor_box(art, Vector3(1.6, 0.065, 0.08), Vector3(4.4, 1.07, -3.87), Kit.IVORY)
	Kit.sign(art, "EXIT  →", Vector3(4.4, 3.55, -3.96), Vector2(1.7, 0.48))
	Kit.decor_box(art, Vector3(3.1, 0.012, 2.5), Vector3(0.8, 0.01, 0.1), Color("afa68d"))
	for i in 6:
		var sheet := Kit.decor_box(art, Vector3(0.22, 0.008, 0.31), Vector3(1.1 + i * 0.35, 0.02, 1.9 - i * 0.3), Kit.IVORY)
		sheet.rotation.y = i * 0.9
	Kit.batch_decor(art)
	Kit.prop(parent, "desk", Vector3(-0.8, 0, -2.6), 0.2, false)
	Kit.prop(parent, "plant", Vector3(3.1, 0, -3.35), 0, false)
	Kit.prop(parent, "cabinet", Vector3(6.2, 0, -2.8), 0, false)

static func _window(parent: Node3D, position: Vector3) -> void:
	Kit.decor_box(parent, Vector3(2.84, 2.67, 0.09), position, Kit.INK)
	Kit.decor_box(parent, Vector3(2.71, 2.54, 0.07), position + Vector3(0, 0, 0.05), Color("96b7b2"))
	for i in 7:
		var height := 0.22 + fmod(i * 0.37, 0.83)
		Kit.decor_box(parent, Vector3(0.36, height, 0.01), position + Vector3(-1.16 + i * 0.38, -1.27 + height * 0.5, 0.091), Color("63847d"))
	for side in [-1, 1]:
		Kit.decor_box(parent, Vector3(0.052, 2.55, 0.08), position + Vector3(side * 0.45, 0, 0.1), Kit.INK)
	for i in 5:
		Kit.decor_box(parent, Vector3(2.75, 0.07, 0.13), position + Vector3(0, 1.18 - i * 0.11, 0.13), Kit.IVORY)

static func course_rooms(course: Resource, rooms: Array[Node3D]) -> void:
	for zone in rooms.size():
		var room := rooms[zone]
		if room.has_node("DepartureArt"):
			continue
		var art := Node3D.new()
		art.name = "DepartureArt"
		room.add_child(art)
		var accent: Color = DEPARTMENTS[zone % DEPARTMENTS.size()]
		_floor(art, FLOORS[zone], 1.5 if zone == 2 else 3.0, 0.16 if zone == 2 else 0.08)
		_office_landmarks(art, zone, accent)
		for side in [-1, 1]:
			Kit.decor_box(art, Vector3(0.09, 0.75, 43), Vector3(side * 23.69, 0.375, 0), accent)
			Kit.decor_box(art, Vector3(0.13, 0.014, 43), Vector3(side * 22.9, 0.03, 0), Kit.IVORY)
		Kit.sign(art, "%02d  /  %s" % [4 - zone, course.zone_names[zone].to_upper()], Vector3(-16, 2.5, -20.9), Vector2(9, 1), accent)
		if zone < 3:
			var x := 13.0 if zone % 2 == 0 else -13.0
			Kit.sign(art, "EXIT  ↓  %02d" % (3 - zone), Vector3(x, 3.1, 21.1), Vector2(5.6, 0.85)).rotation.y = PI
			_hazard_stripe(art, x, 20.4, 11)
		for node in room.find_children("*", "MeshInstance3D", true, false):
			var dimensions: Vector3 = node.get_aabb().size
			if dimensions.is_equal_approx(Vector3(0.6, 4.3, 0.6)) or dimensions.is_equal_approx(Vector3(0.8, 0.14, 3)):
				node.visibility_range_begin = 7.0
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.batch_decor(art)

static func arena(room: Node3D, mode: String) -> void:
	var art := Node3D.new()
	room.add_child(art)
	if mode == "hauled":
		_floor(art, Color("687783"), 6.0, 0.035)
		_loading_bay(art)
	else:
		_floor(art, Color("e0cdaa"), 1.8, 0.13)
		_supply_shop(art)
	Kit.batch_decor(art)

static func _floor(parent: Node3D, color: Color, tile_size: float, checker: float, size := Vector2(47.5, 43.5), height := 0.016) -> void:
	# One surface draw replaces the decorative floor grid.
	var finish := ShaderMaterial.new()
	finish.shader = FLOOR_FINISH
	finish.set_shader_parameter("base_color", color)
	finish.set_shader_parameter("tile_size", tile_size)
	finish.set_shader_parameter("checker_amount", checker)
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	floor.mesh = mesh
	floor.position.y = height
	floor.material_override = finish
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(floor)

static func _office_landmarks(art: Node3D, zone: int, accent: Color) -> void:
	var names := ["OPERATIONS", "CONFERENCE CENTER", "CANTEEN", "PARKING ACCESS"]
	Kit.decor_box(art, Vector3(46, 1.05, 0.22), Vector3(0, 0.525, -21.6), accent)
	Kit.sign(art, names[zone], Vector3(0, 2.55, -21.3), Vector2(11, 0.88), DARK)
	for side in [-1, 1]:
		for z in [-16, -8, 0, 8, 16]:
			var bay := Node3D.new()
			bay.position = Vector3(23.74 * side, 1.95, z)
			bay.rotation.y = -side * PI / 2
			art.add_child(bay)
			Kit.decor_box(bay, Vector3(6.8, 2.35, 0.09), Vector3.ZERO, DARK)
			Kit.decor_box(bay, Vector3(6.54, 2.12, 0.08), Vector3(0, 0, 0.065), accent.lightened(0.44))
			for x in [-2.2, 0.0, 2.2]:
				Kit.decor_box(bay, Vector3(0.085, 2.15, 0.07), Vector3(x, 0, 0.12), DARK)
			Kit.decor_box(bay, Vector3(6.7, 0.09, 0.22), Vector3(0, -0.39, 0.13), Kit.IVORY)
	match zone:
		0:
			for x in [-18, -12, -6, 6, 12, 18]:
				Kit.decor_box(art, Vector3(3.5, 0.045, 0.09), Vector3(x, 0.023, -18.7), GOLD)
		1:
			for i in 5:
				var height := 0.35 + float(i) * 0.24
				Kit.decor_box(art, Vector3(0.55, height, 0.07), Vector3(-3 + i * 1.5, 0.7 + height / 2, -21.44), LIGHT)
		2:
			for i in 12:
				Kit.decor_box(art, Vector3(2.3, 0.48, 0.21), Vector3(-20 + i * 3.6, 1.28, -21.5), Kit.IVORY if i % 2 else accent)
		3:
			_hazard_stripe(art, -13, 18.8, 13)
			Kit.sign(art, "GATE 01  /  CAR PARK", Vector3(-13, 2.95, 21.5), Vector2(7, 0.75), DARK).rotation.y = PI

static func parking(parent: Node3D) -> void:
	if parent.has_node("ParkingArt"):
		return
	var art := Node3D.new()
	art.name = "ParkingArt"
	parent.add_child(art)
	Kit.decor_box(art, Vector3(47.9, 0.008, 23.8), Vector3(0, 0.018, 238), Color("3b4955"))
	for row in 2:
		for column in 4:
			var x := -3.0 + column * 6.5
			var z := 237.0 + row * 8.0
			Kit.decor_box(art, Vector3(0.075, 0.016, 6), Vector3(x - 2.35, 0.025, z), Kit.IVORY)
			if (row + column) % 3 == 2:
				continue
			var paint: Color = [Color("b96b4c"), Color("538278"), Color("b2a28a"), Color("687991")][column]
			Kit.decor_box(art, Vector3(2.1, 0.7, 4.6), Vector3(x, 0.62, z), paint)
			Kit.decor_box(art, Vector3(1.75, 0.65, 2.55), Vector3(x, 1.19, z), DARK)
			Kit.decor_box(art, Vector3(1.82, 0.09, 2.43), Vector3(x, 1.56, z), paint)
			for side in [-1, 1]:
				for axle in [-1, 1]:
					Kit.decor_box(art, Vector3(0.32, 0.58, 0.65), Vector3(x + side * 0.94, 0.31, z + axle * 1.42), DARK)
				Kit.decor_box(art, Vector3(0.45, 0.16, 0.045), Vector3(x + side * 0.67, 0.73, z - 2.31), LIGHT)
	Kit.decor_box(art, Vector3(9, 0.6, 0.42), Vector3(-13, 3.18, 229), DARK)
	Kit.sign(art, "CLOCKED OUT", Vector3(-13, 3.18, 228.76), Vector2(6, 0.53), DARK, GOLD).rotation.y = PI
	for side in [-1, 1]:
		Kit.decor_box(art, Vector3(0.08, 0.06, 8), Vector3(-13 + side * 4.35, 0.06, 226), GOLD)
	Kit.batch_decor(art)

static func _loading_bay(art: Node3D) -> void:
	for bay in 3:
		var x := -15.0 + bay * 15
		Kit.decor_box(art, Vector3(10.5, 5, 0.22), Vector3(x, 2.5, 21.6), DARK)
		Kit.decor_box(art, Vector3(9.9, 3.7, 0.08), Vector3(x, 1.9, 21.45), Color("78909a"))
		for i in 11:
			Kit.decor_box(art, Vector3(9.8, 0.036, 0.08), Vector3(x, 0.15 + i * 0.35, 21.36), DARK)
		for side in [-1, 1]:
			Kit.decor_box(art, Vector3(0.2, 3.95, 0.22), Vector3(x + side * 5.1, 1.98, 21.34), GOLD)
		Kit.decor_box(art, Vector3(5.3, 0.08, 0.18), Vector3(x, 3.95, 21.31), LIGHT)
		Kit.sign(art, "BAY %02d" % (bay + 1), Vector3(x, 4.28, 21.38), Vector2(4.8, 0.65), DARK, GOLD).rotation.y = PI
		_hazard_stripe(art, x, 19.8, 20)
	for x in [-19, -13, -7, -1, 5, 11, 17]:
		for z in [-21.52, 21.52]:
			Kit.decor_box(art, Vector3(1.03, 2.8, 0.2), Vector3(x + 3, 1.4, z), Color("566773"))
			Kit.decor_box(art, Vector3(0.33, 0.45, 0.26), Vector3(x + 3, 2.72, z), GOLD)
	Kit.sign(art, "FREIGHT  /  RECEIVING", Vector3(-9, 3.1, -21.4), Vector2(9, 0.75), DARK, GOLD)
	for z in range(-9, 15, 3):
		Kit.decor_box(art, Vector3(0.11, 0.015, 1.3), Vector3(-12, 0.033, z), GOLD)
	_hazard_stripe(art, 13, 11, 11)
	for x in [10.5, 15.5]:
		Kit.decor_box(art, Vector3(0.12, 0.015, 5.0), Vector3(x, 0.057, 14), GOLD)

static func _supply_shop(art: Node3D) -> void:
	for row in 4:
		var z := -13.0 + row * 8.0
		var accent: Color = [Color("217c7b"), Color("ca5a38"), Color("a07720"), Color("5c5784")][row]
		Kit.decor_box(art, Vector3(38, 0.012, 0.11), Vector3(0, 0.031, z - 2.5), accent)
		for x in [-21.9, 21.9]:
			var aisle := Kit.sign(art, "AISLE %02d" % (row + 1), Vector3(x, 2.8, z), Vector2(3.6, 0.8), accent)
			aisle.rotation.y = PI / 2 if x < 0 else -PI / 2
		# Exterior rack backs and boxes frame the driving area.
		for side in [-1, 1]:
			Kit.decor_box(art, Vector3(0.28, 2.1, 5.8), Vector3(side * 23.2, 1.05, z), DARK)
			for shelf in 3:
				var y := 0.23 + shelf * 0.62
				Kit.decor_box(art, Vector3(0.9, 0.12, 5.9), Vector3(side * 22.88, y, z), accent)
				for box in 5:
					var height := 0.27 + 0.06 * ((row + shelf + box) % 3)
					Kit.decor_box(art, Vector3(0.48, height, 0.7), Vector3(side * 22.8, y + 0.07 + height / 2, z - 2 + box), Kit.IVORY if box % 2 else accent)
	Kit.decor_box(art, Vector3(47, 4.0, 0.26), Vector3(0, 2.0, -21.66), Kit.IVORY)
	for x in [-16, -8, 8, 16]:
		_window(art, Vector3(x, 2.17, -21.48))
	Kit.sign(art, "OFFICE SUPPLY OUTLET", Vector3(-9, 3.62, -21.3), Vector2(14, 0.75), Color("217c7b"))
	Kit.decor_box(art, Vector3(46, 0.47, 0.19), Vector3(0, 0.67, -21.46), Color("217c7b"))

static func pizzeria(parent: Node3D) -> void:
	var art := Node3D.new()
	parent.add_child(art)
	_floor(art, Color("af6c59"), 3, 0.23, Vector2(76, 76), -0.92)
	for side in [-1, 1]:
		Kit.decor_box(art, Vector3(68, 0.22, 0.4), Vector3(0, -0.8, side * 27), LIGHT)
		Kit.decor_box(art, Vector3(0.4, 0.22, 54), Vector3(side * 34, -0.8, 0), LIGHT)
	Kit.decor_box(art, Vector3(64, 5.0, 0.35), Vector3(0, 1.58, -27.06), Color("864c42"))
	Kit.decor_box(art, Vector3(63, 0.8, 0.37), Vector3(0, -0.4, -27.0), DARK)
	for x in [-21, -14, -7, 0, 7, 14, 21]:
		Kit.decor_box(art, Vector3(0.25, 5.0, 0.35), Vector3(x - 3.5, 1.58, -26.91), Color("633934"))
		Kit.decor_box(art, Vector3(0.9, 0.34, 0.36), Vector3(x, 3.32, -26.78), GOLD)
		_window(art, Vector3(x, 2.6, -26.7))
	for row in [-22, 22]:
		for x in [-14, 14]:
			Kit.decor_box(art, Vector3(6, 0.25, 5.5), Vector3(x, -0.49, row), Color("a23d36"))
			Kit.decor_box(art, Vector3(3, 0.2, 1.8), Vector3(x, 0.42, row), LIGHT)
			for z in [-2, 2]:
				Kit.decor_box(art, Vector3(5.4, 1.0, 0.8), Vector3(x, -0.08, row + z), Color("aa493d"))
	Kit.sign(art, "PIZZA COLONY", Vector3(0, 3.2, -24.8), Vector2(10, 1.4), Color("843d31"), LIGHT)
	Kit.batch_decor(art)

static func _hazard_stripe(parent: Node3D, x: float, z: float, count: int) -> void:
	for i in count:
		var stripe := Kit.decor_box(parent, Vector3(0.25, 0.008, 0.7), Vector3(x + (i - count / 2.0) * 0.48, 0.039, z), Kit.ORANGE if i % 2 else Kit.INK)
		stripe.rotation.y = -0.38
