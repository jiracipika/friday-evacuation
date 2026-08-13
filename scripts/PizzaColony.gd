# PizzaColony.gd — SECONDARY mode: Co-op survival on a giant pizza
# You're toppings, dodge the chef's slicer, claim territory
extends Node3D

func _ready() -> void:
	print("[PIZZA COLONY] Mode loaded — secondary mode (stub)")
	_build_pizza()
	_spawn_player()

func _build_pizza() -> void:
	# Giant circular pizza base
	var pizza = StaticBody3D.new()
	pizza.position = Vector3(0, 0, 0)
	add_child(pizza)
	
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 25.0
	shape.height = 0.5
	col.shape = shape
	pizza.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 25.0
	mesh.bottom_radius = 25.0
	mesh.height = 0.5
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.3)  # Golden crust/cheese
	mat.roughness = 0.9
	mesh_inst.material_override = mat
	pizza.add_child(mesh_inst)
	
	# Scatter pepperoni (territory markers)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(20):
		var angle = rng.randf_range(0, TAU)
		var dist = rng.randf_range(3, 22)
		var pep = MeshInstance3D.new()
		pep.position = Vector3(cos(angle) * dist, 0.4, sin(angle) * dist)
		var pmesh = CylinderMesh.new()
		pmesh.top_radius = 1.5
		pmesh.bottom_radius = 1.5
		pmesh.height = 0.2
		pep.mesh = pmesh
		var pmat = StandardMaterial3D.new()
		pmat.albedo_color = Color(0.7, 0.15, 0.1)
		pep.material_override = pmat
		add_child(pep)
	
	print("[PIZZA COLONY] Pizza baked — radius 25m")

func _spawn_player() -> void:
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if player_scene:
		var p = player_scene.instantiate()
		p.position = Vector3(0, 1.5, 0)
		p.player_display_name = "Topping"
		add_child(p)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
