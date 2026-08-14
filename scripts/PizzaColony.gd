# PizzaColony.gd — SECONDARY mode: Co-op survival on a giant pizza
# You're toppings, dodge the chef's slicer, claim territory
extends Node3D

var territory_score := 0.0
var survival_time := 90.0
var chef_angle := 0.0
var player: CharacterBody3D
var mode_hud: CanvasLayer
var failed := false

func _ready() -> void:
	_build_pizza()
	_spawn_player()
	mode_hud = _make_mode_hud("PIZZA COLONY", "CLAIM PEPPERONI  •  SURVIVE THE CHEF")

func _process(delta: float) -> void:
	if failed:
		return
	survival_time = maxf(survival_time - delta, 0.0)
	chef_angle += delta * 0.8
	if player and is_instance_valid(player):
		territory_score = clampf(territory_score + delta * (1.0 if player.global_position.length() < 12.0 else 0.25), 0.0, 100.0)
	var progress = territory_score / 100.0
	if mode_hud and mode_hud.has_method("update_state"):
		mode_hud.update_state(survival_time, progress, "SURVIVED" if survival_time <= 0.0 else "CLAIMING TERRITORY", Color("a8ffbd") if survival_time <= 0.0 else Color("ffcf55"))
	if survival_time <= 0.0:
		print("[PIZZA COLONY] Survival complete — territory %.0f%%" % territory_score)
		set_process(false)

func _make_mode_hud(title: String, objective: String) -> CanvasLayer:
	var hud_script = load("res://scripts/ModeHUD.gd")
	var hud = CanvasLayer.new()
	if hud_script:
		hud.set_script(hud_script)
		add_child(hud)
		hud.configure(title, objective, survival_time)
	return hud

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
		player = player_scene.instantiate()
		player.position = Vector3(0, 1.5, 0)
		player.player_display_name = "Topping"
		add_child(player)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var pause_menu = load("res://scripts/PauseMenu.gd")
		pause_menu.create(self, Callable())
		get_viewport().set_input_as_handled()
