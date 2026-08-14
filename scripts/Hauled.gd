# Hauled.gd — SECONDARY mode: Co-op physics delivery
# Deliver absurd HOSTILE cargo through impossible terrain
extends Node3D

var cargo_nodes: Array[Node3D] = []
var delivery_progress: float = 0.0
var delivery_done := false
var delivery_zone: Area3D
var mode_hud: CanvasLayer
var time_limit := 180.0
var remaining_time := 180.0
var failed := false

func _ready() -> void:
	_build_level()
	_spawn_player()
	var hud = _make_mode_hud("HAULED", "GET THE CARGO TO THE GREEN ZONE")
	mode_hud = hud
	if delivery_zone:
		delivery_zone.body_entered.connect(_on_delivery_body_entered)

func _process(delta: float) -> void:
	if delivery_done or failed:
		return
	remaining_time = maxf(remaining_time - delta, 0.0)
	var cargo_distance = 0.0
	for cargo in cargo_nodes:
		if is_instance_valid(cargo):
			cargo_distance += cargo.global_position.distance_to(Vector3(0, 1, 25))
	if not cargo_nodes.is_empty():
		delivery_progress = clampf(1.0 - cargo_distance / (cargo_nodes.size() * 45.0), 0.0, 1.0)
	if mode_hud and mode_hud.has_method("update_state"):
		mode_hud.update_state(remaining_time, delivery_progress, "DELIVERED" if delivery_done else ("TIME UP" if remaining_time <= 0.0 else "HAULING"), Color("a8ffbd") if delivery_done else Color("ffcf55"))
	if delivery_progress >= 0.98:
		_on_delivery_complete()
	elif remaining_time <= 0.0:
		failed = true
		mode_hud.update_state(0.0, delivery_progress, "FAILED — CARGO NOT DELIVERED", Color("ff7070"))

func _on_delivery_body_entered(body: Node3D) -> void:
	if cargo_nodes.has(body):
		_on_delivery_complete()

func _on_delivery_complete() -> void:
	if delivery_done:
		return
	delivery_done = true
	print("[HAULED] Delivery complete — cargo survived")

func _make_mode_hud(title: String, objective: String) -> CanvasLayer:
	var hud_script = load("res://scripts/ModeHUD.gd")
	var hud = CanvasLayer.new()
	if hud_script:
		hud.set_script(hud_script)
		add_child(hud)
		hud.configure(title, objective, time_limit)
	return hud

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
	delivery_zone = zone
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
		cargo_nodes.append(cargo)
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
		var pause_menu = load("res://scripts/PauseMenu.gd")
		pause_menu.create(self, Callable())
		get_viewport().set_input_as_handled()
