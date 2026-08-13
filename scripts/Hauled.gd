# Hauled.gd — SECONDARY mode: Co-op physics delivery
# Deliver absurd HOSTILE cargo through impossible terrain
extends Node3D

func _ready() -> void:
	print("[HAULED] Mode loaded — secondary mode (stub)")
	_build_level()
	_spawn_player()

func _build_level() -> void:
	# Single floor for now
	var floor_node = StaticBody3D.new()
	add_child(floor_node)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(60, 0.2, 60)
	col.shape = shape
	floor_node.add_child(col)
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(60, 0.2, 60)
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.15, 0.12)
	mat.roughness = 0.9
	mesh_inst.material_override = mat
	floor_node.add_child(mesh_inst)
	
	# Spawn cargo
	_spawn_cargo()
	
	# Spawn delivery zone
	var zone = Area3D.new()
	zone.position = Vector3(0, 1, 25)
	add_child(zone)
	var zcol = CollisionShape3D.new()
	var zshape = BoxShape3D.new()
	zshape.size = Vector3(8, 4, 8)
	zcol.shape = zshape
	zone.add_child(zcol)

func _spawn_cargo() -> void:
	var cargo_types = [
		{"name": "Fridge of Bees", "color": Color(0.9, 0.85, 0.3), "weight": 3.0},
		{"name": "Haunted Sofa", "color": Color(0.5, 0.3, 0.4), "weight": 2.5},
		{"name": "Angry Vending Machine", "color": Color(0.8, 0.2, 0.2), "weight": 4.0},
		{"name": "Wet Cardboard Box", "color": Color(0.6, 0.5, 0.3), "weight": 1.0},
	]
	for info in cargo_types:
		var cargo = RigidBody3D.new()
		cargo.position = Vector3(randf_range(-10, 10), 1.5, randf_range(-10, 0))
		cargo.mass = info.weight
		add_child(cargo)
		
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(2, 2, 2)
		col.shape = shape
		cargo.add_child(col)
		
		var mesh_inst = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(2, 2, 2)
		mesh_inst.mesh = mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = info.color
		mesh_inst.material_override = mat
		cargo.add_child(mesh_inst)
		
		print("[HAULED] Spawned: %s" % info.name)

func _spawn_player() -> void:
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if player_scene:
		var p = player_scene.instantiate()
		p.position = Vector3(0, 1.5, -20)
		p.player_display_name = "Hauler"
		add_child(p)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
