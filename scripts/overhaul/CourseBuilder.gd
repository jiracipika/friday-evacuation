extends RefCounted
const Kit = preload("res://scripts/overhaul/OfficeKit.gd")
var rooms: Array[Node3D] = []
var pickups: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var route_markers: Array[Node3D] = []

func build(parent: Node3D, course: Resource, trial := false, use_baked := true) -> void:
	var baked_path := "res://scenes/overhaul/baked/%s.scn" % course.id
	if use_baked and ResourceLoader.exists(baked_path) and ResourceLoader.exists(baked_path.replace(".scn", ".lmbake")):
		var stage: Node3D = load(baked_path).instantiate()
		parent.add_child(stage)
		for child in stage.get_children():
			if str(child.name).begins_with("OfficeZone_"):
				rooms.append(child)
		for node in stage.find_children("*", "Node3D", true, false):
			if node.has_meta("pickup"):
				var pickup: Dictionary = node.get_meta("pickup").duplicate(true)
				if trial and pickup.kind == "item":
					node.queue_free()
					continue
				pickup.node = node
				pickups.append(pickup)
			if node.has_meta("hazard"):
				var hazard: Dictionary = node.get_meta("hazard").duplicate(true)
				hazard.node = node
				hazards.append(hazard)
		return
	Kit.environment(parent)
	for zone in 4:
		var y := 18.0 - zone * 6.0
		var z := zone * 68.0
		var side := 1.0 if zone % 2 == 0 else -1.0
		var room := Kit.room(parent, Vector3(0, y, z), zone)
		room.name = "OfficeZone_%d" % zone
		rooms.append(room)
		Kit.text(room, "%02d / %s" % [4 - zone, course.zone_names[zone]], Vector3(0, 3.4, 21.5), 115, Kit.INK)
		# Manufactured desk runs and cubicle spines define the racing line.
		for row in 2:
			var barrier_z := -9.5 + row * 13.0
			var gap_side := side if row == 0 else -side
			var barrier := Kit.solid(room, Vector3(35, 1.05, 0.2), Vector3(-gap_side * 6.5, 0.525, barrier_z), Color("628d8c"))
			barrier.name = "CubicleSpine"
			Kit.decor_box(room, Vector3(35, 0.07, 0.27), Vector3(-gap_side * 6.5, 1.09, barrier_z), Kit.IVORY)
			for x in range(-18, 19, 6):
				if absf(float(x) - gap_side * 18) < 6:
					continue
				Kit.prop(room, "desk" if zone != 3 else "cabinet", Vector3(x, 0, barrier_z + 1.1), 0, true)
				if course.id == "cubicle_maze":
					Kit.solid(room, Vector3(0.16, 1.05, 2.6), Vector3(x + 2.6, 0.525, barrier_z + 1.2), Color("628d8c"))
		for x in [-20.0, 20.0]:
			for pz in [-17.0, 0.0, 17.0]:
				Kit.prop(room, "plant", Vector3(x, 0, pz))
		Kit.prop(room, "printer" if zone < 2 else "vending", Vector3(-21 * side, 0, 14))
		Kit.prop(room, "water", Vector3(-21 * side, 0, 11))
		Kit.prop(room, "sofa", Vector3(20 * side, 0, 16), -PI / 2)
		if zone == 1 or course.id == "executive":
			Kit.prop(room, "meeting", Vector3(0, 0, 17))
		# Physical, low-profile arrows guide the line; no wall of billboards.
		for index in range(zone * 8, mini(zone * 8 + 7, course.points.size())):
			var p: Vector3 = course.points[index]
			var next: Vector3 = course.points[mini(index + 1, course.points.size() - 1)]
			var arrow := _arrow(room, p - room.position + Vector3(0, 0.025, 0), next - p)
			route_markers.append(arrow)
		for point_index in [zone * 8 + 1, zone * 8 + 4]:
			var p: Vector3 = course.points[point_index] + Vector3(0, 0.95, 0)
			var obj := _coffee(room, p - room.position)
			pickups.append({"node": obj, "position": p, "active": true, "timer": 0.0, "kind": "coffee"})
		if not trial:
			var p := Vector3(8 * side, y + 0.3, z - 3)
			var marker := Kit.decor_box(room, Vector3(0.7, 0.5, 0.7), p - room.position, Kit.ORANGE)
			pickups.append({"node": marker, "position": p, "active": true, "timer": 0.0, "kind": "item"})
		# Hazards are deterministic; time-trial timing never depends on RNG.
		var hp := Vector3(-6 * side, y, z + 10)
		var warning := Kit.decor_box(room, Vector3(3.0, 0.016, 1.4), hp - room.position + Vector3(0, 0.025, 0), Color("c79454"))
		var roomba := _roomba(room, hp - room.position + Vector3(0, 0.14, 0))
		hazards.append({"node": roomba, "base": hp + Vector3(0, 0.14, 0), "warning": warning, "phase": float(zone) * 1.7, "kind": "roomba"})
		if zone < 3:
			var a := Vector3(13 * side, y, z + 21)
			var b := Vector3(13 * side, y - 6, z + 46)
			var center := (a + b) * 0.5
			var ramp := Kit.solid(parent, Vector3(6.2, 0.3, a.distance_to(b) + 0.3), center - Vector3(0, 0.15, 0), Color("bcb6a0"))
			ramp.name = "DescendingRamp_%d" % zone
			ramp.rotation.x = atan2(6, 25)
			for rail in [-1.0, 1.0]:
				var wall := Kit.solid(parent, Vector3(0.16, 1.05, a.distance_to(b)), center + Vector3(rail * 3, 0.5, 0), Kit.IVORY)
				wall.rotation.x = ramp.rotation.x
			Kit.text(room, "↓ EXIT / %02d" % (3 - zone), Vector3(13 * side, 2.8, 20), 70, Kit.TEAL).rotation.y = PI
		# A visible desk-hop shortcut crosses the two cubicle spines.
		var shortcut := Kit.text(room, "SHORTCUT ↗ / HOP THE PARTITION", Vector3(0, 1.5, -8.5), 35, Kit.ORANGE)
		shortcut.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	Kit.solid(parent, Vector3(48, 0.3, 24), Vector3(0, -0.15, 238), Color("7c8989"))
	for x in range(-22, 24, 8):
		Kit.decor_box(parent, Vector3(0.12, 0.01, 9), Vector3(x, 0.015, 240), Kit.IVORY)
	Kit.text(parent, "YOU'RE OFF THE CLOCK.", Vector3(-13, 3.6, 234), 110, Kit.INK).rotation.y = PI
	for side in [-1, 1]:
		Kit.solid(parent, Vector3(0.25, 3.2, 0.3), Vector3(-13 + side * 4, 1.6, 229), Kit.TEAL)
	for i in 16:
		Kit.decor_box(parent, Vector3(0.5, 0.018, 0.6), Vector3(-17 + i * 0.5, 0.025, 228.7 + (i % 2) * 0.6), Kit.INK if i % 2 else Kit.IVORY)
	for pickup in pickups:
		var metadata := pickup.duplicate()
		metadata.erase("node")
		pickup.node.set_meta("pickup", metadata)
	for hazard in hazards:
		var metadata := hazard.duplicate()
		metadata.erase("node")
		metadata.erase("warning")
		hazard.node.set_meta("hazard", metadata)

func _arrow(parent: Node3D, pos: Vector3, direction: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = atan2(direction.x, direction.z)
	parent.add_child(node)
	Kit.decor_box(node, Vector3(0.22, 0.014, 0.9), Vector3(0, 0, -0.2), Kit.ORANGE)
	for side in [-1, 1]:
		var head := Kit.decor_box(node, Vector3(0.16, 0.014, 0.6), Vector3(side * 0.17, 0, 0.2), Kit.ORANGE)
		head.rotation.y = side * -0.7
	return node

func _coffee(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var cup := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.18
	cylinder.bottom_radius = 0.14
	cylinder.height = 0.4
	cylinder.radial_segments = 16
	cup.mesh = cylinder
	cup.material_override = Kit.material(Kit.IVORY)
	root.add_child(cup)
	Kit.decor_box(root, Vector3(0.34, 0.14, 0.31), Vector3.ZERO, Kit.ORANGE)
	var lid := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.2
	disc.bottom_radius = 0.2
	disc.height = 0.04
	lid.mesh = disc
	lid.position.y = 0.23
	lid.material_override = Kit.material(Kit.INK)
	root.add_child(lid)
	return root

func _roomba(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.48
	disc.bottom_radius = 0.48
	disc.height = 0.25
	disc.radial_segments = 20
	mesh.mesh = disc
	mesh.material_override = Kit.material(Kit.INK, 0.45)
	root.add_child(mesh)
	Kit.decor_box(root, Vector3(0.16, 0.025, 0.12), Vector3(0, 0.14, 0), Kit.ORANGE)
	return root

func tick_visuals(time: float) -> void:
	for p in pickups:
		if is_instance_valid(p.node):
			p.node.position.y = p.position.y - p.node.get_parent().position.y + sin(time * 2.4 + p.position.x) * 0.1
			p.node.rotation.y = time * 0.6
			p.node.visible = p.active
	for h in hazards:
		h.node.global_position = h.base + Vector3(sin(time * 0.7 + h.phase) * 3.0, 0, 0)
