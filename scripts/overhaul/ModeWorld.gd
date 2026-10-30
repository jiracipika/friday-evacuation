extends RefCounted
const Kit = preload("res://scripts/overhaul/OfficeKit.gd")

static func build(game: Node3D, mode: String) -> void:
	Kit.environment(game)
	if mode == "pizza":
		var body := StaticBody3D.new()
		game.add_child(body)
		var shape := CylinderShape3D.new()
		shape.radius = 18
		shape.height = 0.7
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position.y = -0.35
		body.add_child(col)
		Kit.prop(game, "pizza", Vector3.ZERO, 0, false)
		Kit.text(game, "PIZZA COLONY", Vector3(0, 3, -19), 130, Kit.INK)
		return
	var room := Kit.room(game, Vector3.ZERO, 2)
	# Low end walls contain the shared arena, with a readable delivery zone.
	for z in [-22, 22]:
		Kit.solid(room, Vector3(48, 1, 0.35), Vector3(0, 0.5, z), Kit.IVORY)
	if mode == "hauled":
		Kit.text(room, "LOADING BAY / HANDLE WITH COLLEAGUES", Vector3(0, 3, -21), 95, Kit.INK)
		for x in [-7, 6]:
			Kit.solid(room, Vector3(1, 1.7, 19), Vector3(x, 0.85, -7 if x == -7 else 8), Kit.TEAL)
		for i in 6:
			Kit.prop(room, "cabinet", Vector3(-21 + i * 3, 0, 18))
		Kit.decor_box(room, Vector3(5, 0.02, 5), Vector3(13, 0.02, 14), Color("64b79e"))
		Kit.text(room, "DELIVERY", Vector3(13, 1.8, 17), 70, Kit.INK)
		var cargo := RigidBody3D.new()
		cargo.name = "TeamCargo"
		cargo.position = Vector3(-12, 0.8, -10)
		cargo.mass = 4
		cargo.linear_damp = 1.5
		cargo.contact_monitor = true
		cargo.max_contacts_reported = 4
		cargo.collision_layer = 4
		cargo.collision_mask = 1
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6, 1.5, 1.2)
		col.shape = shape
		cargo.add_child(col)
		game.add_child(cargo)
		var fridge := Node3D.new()
		fridge.name = "Fridge"
		cargo.add_child(fridge)
		Kit.decor_box(fridge, Vector3(1.2, 1.5, 1.2), Vector3.ZERO, Kit.IVORY)
		Kit.decor_box(fridge, Vector3(1.23, 0.08, 1.23), Vector3(0, 0.32, 0), Kit.INK)
		Kit.decor_box(fridge, Vector3(0.09, 0.45, 0.09), Vector3(0.4, -0.15, 0.65), Kit.INK)
		Kit.text(fridge, "LIVE BEES", Vector3(0, 0.2, 0.61), 28, Kit.INK)
		var sofa := Kit.prop(cargo, "sofa", Vector3(0, -0.7, 0), 0, false)
		sofa.name = "HauntedSofa"
		sofa.scale = Vector3.ONE * 0.6
		var box := Node3D.new()
		box.name = "WetCardboard"
		cargo.add_child(box)
		Kit.decor_box(box, Vector3(1.3, 1.3, 1.1), Vector3.ZERO, Color("a87848"))
		Kit.decor_box(box, Vector3(0.2, 1.32, 1.12), Vector3.ZERO, Color("d4b789"))
		Kit.text(box, "THIS SIDE UP", Vector3(0.25, 0.2, 0.56), 20, Kit.INK)
		game.cargo = cargo
	else:
		Kit.text(room, "SHOP & SEEK / OFFICE SUPPLY SUPERSTORE", Vector3(0, 3, -21), 90, Kit.INK)
		var kinds := ["plant", "printer", "water", "cabinet", "vending"]
		for row in 4:
			for column in 5:
				var obj := Kit.prop(room, kinds[(row * 5 + column) % 5], Vector3(-16 + column * 8, 0, -13 + row * 8))
				game.seek_props.append(obj)
		for x in [-20, 20]:
			for z in [-15, -5, 5, 15]:
				Kit.prop(room, "shelf", Vector3(x, 0, z), PI / 2)
