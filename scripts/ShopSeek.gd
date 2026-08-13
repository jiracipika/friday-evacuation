# ShopSeek.gd — SECONDARY mode: Supermarket hide & seek
# Half disguise as groceries, half are shoppers with a list
extends Node3D

func _ready() -> void:
	print("[SHOP&SEEK] Mode loaded — secondary mode (stub)")
	_build_supermarket()
	_spawn_player()

func _build_supermarket() -> void:
	# Floor
	var floor_node = StaticBody3D.new()
	add_child(floor_node)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(50, 0.2, 50)
	col.shape = shape
	floor_node.add_child(col)
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(50, 0.2, 50)
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.2)
	mat.roughness = 0.9
	mesh_inst.material_override = mat
	floor_node.add_child(mesh_inst)
	
	# Shelves
	for i in range(6):
		var shelf = StaticBody3D.new()
		shelf.position = Vector3(randf_range(-18, 18), 1, randf_range(-18, 18))
		shelf.rotation.y = randf_range(0, TAU)
		add_child(shelf)
		
		var scol = CollisionShape3D.new()
		var sshape = BoxShape3D.new()
		sshape.size = Vector3(6, 2.5, 1)
		scol.shape = sshape
		shelf.add_child(scol)
		
		var smesh = MeshInstance3D.new()
		var sm = BoxMesh.new()
		sm.size = Vector3(6, 2.5, 1)
		smesh.mesh = sm
		var smat = StandardMaterial3D.new()
		smat.albedo_color = Color(0.3, 0.25, 0.2)
		smesh.material_override = smat
		shelf.add_child(smesh)
	
	print("[SHOP&SEEK] Supermarket built")

func _spawn_player() -> void:
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if player_scene:
		var p = player_scene.instantiate()
		p.position = Vector3(0, 1.5, 0)
		p.player_display_name = "Shopper"
		add_child(p)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
