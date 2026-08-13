# Evacuation.gd — PRIMARY game mode
# It's 4:59 PM Friday. Race office chairs through a multi-story office building
# to the parking lot. First to the exit wins. Last one buys beers.
extends Node3D

## Match config
@export var countdown_seconds: float = 3.0
@export var time_limit: float = 120.0

## State
var match_state: StringName = &"waiting"  # waiting, countdown, racing, finished
var timer: float = 0.0
var finish_order: Array[Dictionary] = []  # {player_id, name, time}
var players: Array = []
var local_player: CharacterBody3D = null

## Nodes
@onready var countdown_label: Label3D = $Arena/CountdownLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var results_panel: Panel = $UI/ResultsPanel
@onready var camera: Camera3D = $Camera3D

# --- LIFECYCLE ---

func _ready() -> void:
	_setup_arena()
	_spawn_player()
	_start_countdown()
	
	# Connect exit zone
	var exit_zone = $Arena/ExitZone
	if exit_zone:
		exit_zone.body_entered.connect(_on_player_reached_exit)

func _process(delta: float) -> void:
	match match_state:
		&"countdown":
			timer -= delta
			_update_countdown_display()
			if timer <= 0:
				_start_race()
		&"racing":
			timer += delta
			_update_timer_display()
			# Check if everyone finished or time ran out
			if finish_order.size() >= players.size() or timer >= time_limit:
				_end_race()
		&"finished":
			pass

# --- SETUP ---

func _setup_arena() -> void:
	# Build the office building procedurally
	_build_floor(Vector3(0, 0, 0), Color(0.15, 0.15, 0.22))    # Floor 1 (start)
	_build_floor(Vector3(0, 6, 0), Color(0.18, 0.15, 0.20))    # Floor 2
	_build_floor(Vector3(0, 12, 0), Color(0.13, 0.16, 0.20))   # Floor 3
	_build_floor(Vector3(0, 18, 0), Color(0.10, 0.18, 0.15))   # Floor 4 (parking lot exit)
	
	# Add ramps connecting floors
	_build_ramp(Vector3(8, 0, 20), Vector3(8, 6, 20))
	_build_ramp(Vector3(-8, 6, 20), Vector3(-8, 12, 20))
	_build_ramp(Vector3(8, 12, 20), Vector3(8, 18, 20))
	
	# Add obstacles
	_spawn_obstacles()
	
	# Add power-ups
	_spawn_powerups()

func _build_floor(pos: Vector3, color: Color) -> void:
	var floor_node = StaticBody3D.new()
	floor_node.position = pos
	add_child(floor_node)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(40, 0.2, 40)
	col.shape = shape
	floor_node.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(40, 0.2, 40)
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh_inst.material_override = mat
	floor_node.add_child(mesh_inst)
	
	# Walls
	for i in range(4):
		var wall = StaticBody3D.new()
		var angles = [0, 90, 180, 270]
		wall.rotation.y = deg_to_rad(angles[i])
		wall.position = pos + Vector3(
			[0, 20, 0, -20][i], 1, [20, 0, -20, 0][i]
		)
		add_child(wall)
		
		var wall_col = CollisionShape3D.new()
		var wall_shape = BoxShape3D.new()
		wall_shape.size = Vector3(40, 3, 0.3)
		wall_col.shape = wall_shape
		wall.add_child(wall_col)
		
		var wall_mesh = MeshInstance3D.new()
		var wall_m = BoxMesh.new()
		wall_m.size = Vector3(40, 3, 0.3)
		wall_mesh.mesh = wall_m
		var wall_mat = StandardMaterial3D.new()
		wall_mat.albedo_color = color.darkened(0.3)
		wall_mat.roughness = 0.9
		wall_mesh.material_override = wall_mat
		wall.add_child(wall_mesh)

func _build_ramp(from_pos: Vector3, to_pos: Vector3) -> void:
	var ramp = StaticBody3D.new()
	var mid = (from_pos + to_pos) / 2.0
	ramp.position = mid
	var direction = to_pos - from_pos
	var length = direction.length()
	var angle = atan2(direction.y, sqrt(direction.x ** 2 + direction.z ** 2))
	ramp.rotation.x = -angle
	add_child(ramp)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(6, 0.2, length)
	col.shape = shape
	ramp.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(6, 0.2, length)
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.25)
	mat.roughness = 0.7
	mesh_inst.material_override = mat
	ramp.add_child(mesh_inst)

func _spawn_obstacles() -> void:
	# Spawn desks, plants, water coolers scattered around
	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	
	for i in range(15):
		var desk = _make_desk()
		var floor_y = [0, 6, 12, 18].pick_random()
		desk.position = Vector3(
			rng.randf_range(-15, 15),
			floor_y + 0.5,
			rng.randf_range(-15, 15)
		)
		desk.rotation.y = rng.randf_range(0, TAU)
		add_child(desk)

func _make_desk() -> StaticBody3D:
	var desk = StaticBody3D.new()
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 1.2, 1)
	col.shape = shape
	desk.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(2, 1.2, 1)
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.3, 0.25)
	mat.roughness = 0.7
	mesh_inst.material_override = mat
	desk.add_child(mesh_inst)
	
	return desk

func _spawn_powerups() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec() + 42
	
	for i in range(8):
		var pu = _make_powerup()
		var floor_y = [0.5, 6.5, 12.5, 18.5].pick_random()
		pu.position = Vector3(
			rng.randf_range(-12, 12),
			floor_y,
			rng.randf_range(-12, 12)
		)
		add_child(pu)

func _make_powerup() -> Area3D:
	var pu = Area3D.new()
	
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.6
	col.shape = shape
	pu.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.5, 0.2)
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 1.5
	mesh_inst.material_override = mat
	pu.add_child(mesh_inst)
	
	# Coffee boost on pickup
	pu.body_entered.connect(func(body):
		if body.is_in_group("players"):
			if body.has_method("_start_boost"):
				body._start_boost()
			pu.queue_free()
	)
	
	return pu

# --- PLAYER SPAWN ---

func _spawn_player() -> void:
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if not player_scene:
		push_error("Could not load PlayerChair.tscn!")
		return
	local_player = player_scene.instantiate()
	local_player.player_display_name = GameManager.player_name
	local_player.player_color = Color(0.4, 0.8, 1.0)
	local_player.set_can_move(false)  # Locked during countdown
	add_child(local_player)
	local_player.position = Vector3(0, 1.5, -10)
	players.append(local_player)
	
	# Attach camera to follow player
	if camera:
		camera.global_position = local_player.global_position + Vector3(0, 5, 10)
	
	# Set camera to follow
	_setup_follow_camera()

func _setup_follow_camera() -> void:
	# We'll use a simple follow camera
	set_process(true)

# --- MATCH FLOW ---

func _start_countdown() -> void:
	match_state = &"countdown"
	timer = countdown_seconds

func _update_countdown_display() -> void:
	if countdown_label:
		var secs = ceili(timer)
		countdown_label.text = str(secs) if secs > 0 else "GO!"
		countdown_label.visible = true

func _start_race() -> void:
	match_state = &"racing"
	timer = 0.0
	if countdown_label:
		countdown_label.text = "GO!"
		countdown_label.visible = false
	for p in players:
		if p and is_instance_valid(p):
			p.set_can_move(true)

func _update_timer_display() -> void:
	if timer_label:
		var remaining = max(0, time_limit - timer)
		var mins = int(remaining) / 60
		var secs = int(remaining) % 60
		timer_label.text = "%d:%02d" % [mins, secs]

func _on_player_reached_exit(body: CharacterBody3D) -> void:
	if not body.is_in_group("players"):
		return
	if match_state != &"racing":
		return
	
	var pname = body.player_display_name if "player_display_name" in body else "Player"
	var entry = {"name": pname, "time": timer}
	finish_order.append(entry)
	print("[RACE] %s reached the exit at %.1fs!" % [pname, timer])
	
	# Lock the finished player
	body.set_can_move(false)
	
	if finish_order.size() == 1:
		# Winner!
		_show_results()

func _end_race() -> void:
	match_state = &"finished"
	_show_results()

func _show_results() -> void:
	if results_panel:
		results_panel.visible = true
		var label = results_panel.get_node_or_null("VBox/WinnerLabel")
		if label and finish_order.size() > 0:
			label.text = "%s WINS!\nLast one buys beers!" % finish_order[0].name

# --- CAMERA FOLLOW ---

func _physics_process(delta: float) -> void:
	if local_player and is_instance_valid(local_player) and match_state == &"racing":
		var target_pos = local_player.global_position
		var cam_target = target_pos + Vector3(0, 6, 10)
		camera.global_position = camera.global_position.lerp(cam_target, delta * 5.0)
		camera.look_at(target_pos)

# --- INPUT ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
