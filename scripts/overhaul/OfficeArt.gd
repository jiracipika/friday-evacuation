extends RefCounted
## Partitions, signs and floor markings are presentation only.
const Kit = preload("res://scripts/overhaul/OfficeKit.gd")
const FLOORS := [Color("8e9b89"), Color("a19a83"), Color("a69b8f"), Color("82958f")]
const DEPARTMENTS := [Color("356e64"), Color("8c672f"), Color("985748"), Color("466275")]

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
		_floor(art, FLOORS[zone % FLOORS.size()])
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
	_floor(art, Color("82949a") if mode == "hauled" else Color("b4a98d"))
	if mode == "hauled":
		_hazard_stripe(art, 13, 10.7, 11)
		Kit.sign(art, "LOADING BAY  /  HANDLE WITH CARE", Vector3(0, 2.1, -21.4), Vector2(14, 0.95), Kit.INK)
	else:
		for row in 4:
			var z := -13.0 + row * 8.0
			Kit.decor_box(art, Vector3(38, 0.012, 0.085), Vector3(0, 0.03, z - 2.5), Kit.IVORY)
			var aisle := Kit.sign(art, "AISLE %02d" % (row + 1), Vector3(-23.5, 2.5, z), Vector2(2.6, 0.8))
			aisle.rotation.y = PI / 2
	Kit.batch_decor(art)

static func _floor(parent: Node3D, color: Color) -> void:
	Kit.decor_box(parent, Vector3(47.5, 0.008, 43.5), Vector3(0, 0.016, 0), color)
	for z in range(-20, 22, 4):
		Kit.decor_box(parent, Vector3(47.5, 0.005, 0.025), Vector3(0, 0.023, z), color.darkened(0.13))
	for x in range(-20, 22, 4):
		Kit.decor_box(parent, Vector3(0.025, 0.005, 43.5), Vector3(x, 0.023, 0), color.darkened(0.13))

static func _hazard_stripe(parent: Node3D, x: float, z: float, count: int) -> void:
	for i in count:
		var stripe := Kit.decor_box(parent, Vector3(0.25, 0.008, 0.7), Vector3(x + (i - count / 2.0) * 0.48, 0.039, z), Kit.ORANGE if i % 2 else Kit.INK)
		stripe.rotation.y = -0.38
