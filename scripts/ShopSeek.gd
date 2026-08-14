# ShopSeek.gd — SECONDARY mode: Supermarket hide & seek
# Half disguise as groceries, half are shoppers with a list
extends Node3D

var seeker_time := 60.0
var found_count := 0
var target_count := 6
var player: CharacterBody3D
var mode_hud: CanvasLayer
var failed := false
var time_limit := 60.0

func _ready() -> void:
	_build_supermarket()
	_spawn_player()
	_spawn_grocery_targets()
	mode_hud = _make_mode_hud("SHOP & SEEK", "FIND THE FAKE GROCERIES  •  60 SEC")

func _process(delta: float) -> void:
	if failed:
		return
	seeker_time = maxf(seeker_time - delta, 0.0)
	var progress = float(found_count) / float(target_count)
	if mode_hud and mode_hud.has_method("update_state"):
		mode_hud.update_state(seeker_time, progress, "FOUND ALL" if found_count >= target_count else ("TIME UP" if seeker_time <= 0.0 else "SEARCHING"), Color("a8ffbd") if found_count >= target_count else Color("ffcf55"))
	if found_count >= target_count:
		set_process(false)
	elif seeker_time <= 0.0:
		failed = true
		mode_hud.update_state(0.0, progress, "FAILED — %d/%d FOUND" % [found_count, target_count], Color("ff7070"))

func _spawn_grocery_targets() -> void:
	for i in range(target_count):
		var target = Area3D.new()
		target.name = "FakeGrocery_%d" % i
		target.position = Vector3(-18.0 + float(i) * 6.0, 1.2, 10.0 + sin(float(i)) * 8.0)
		var col = CollisionShape3D.new()
		var shape = SphereShape3D.new()
		shape.radius = 1.0
		col.shape = shape
		target.add_child(col)
		target.body_entered.connect(_on_grocery_found.bind(target))
		add_child(target)

func _on_grocery_found(body: Node3D, target: Area3D) -> void:
	if body == player and is_instance_valid(target):
		found_count += 1
		target.queue_free()
		print("[SHOP&SEEK] Found %d/%d" % [found_count, target_count])

func _make_mode_hud(title: String, objective: String) -> CanvasLayer:
	var hud_script = load("res://scripts/ModeHUD.gd")
	var hud = CanvasLayer.new()
	if hud_script:
		hud.set_script(hud_script)
		add_child(hud)
		hud.configure(title, objective, time_limit)
	return hud

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
		player = player_scene.instantiate()
		player.position = Vector3(0, 1.5, 0)
		player.player_display_name = "Shopper"
		add_child(player)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var pause_menu = load("res://scripts/PauseMenu.gd")
		pause_menu.create(self, Callable())
		get_viewport().set_input_as_handled()
