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
var hud: CanvasLayer = null
var top_speed: float = 0.0
var traps_hit: int = 0
var traps_placed: int = 0

## Smooth camera state
var cam_follow_pos: Vector3 = Vector3.ZERO
var cam_look_target: Vector3 = Vector3.ZERO
var camera_base_fov: float = 70.0
var camera_shake: float = 0.0
var camera_shake_time: float = 0.0

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
	_setup_hud()
	camera_base_fov = camera.fov if camera else 70.0
	if local_player and local_player.has_signal("shake_requested"):
		local_player.shake_requested.connect(_request_camera_shake)
	
	var exit_zone = $Arena/ExitZone
	if exit_zone:
		exit_zone.body_entered.connect(_on_player_reached_exit)
	
	if results_panel:
		var rematch = results_panel.get_node_or_null("VBox/RematchButton")
		if rematch:
			rematch.pressed.connect(_on_rematch)
		var menu = results_panel.get_node_or_null("VBox/MenuButton")
		if menu:
			menu.pressed.connect(_on_back_to_menu)

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
			if local_player and is_instance_valid(local_player):
				top_speed = max(top_speed, Vector2(local_player.velocity.x, local_player.velocity.z).length())
				_update_hud()
			if finish_order.size() >= players.size() or timer >= time_limit:
				_end_race()
		&"finished":
			pass
	
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	if not local_player or not is_instance_valid(local_player):
		return
	if not camera:
		return
	
	var player_pos = local_player.global_position
	var player_vel = local_player.velocity
	var move_dir = Vector3(player_vel.x, 0, player_vel.z)
	var cam_offset: Vector3
	
	if move_dir.length() > 2.0:
		var dir_norm = move_dir.normalized()
		cam_offset = Vector3(-dir_norm.x * 3.0, 6.0, -dir_norm.z * 3.0)
	else:
		var fwd = -local_player.global_transform.basis.z
		cam_offset = Vector3(fwd.x * 3.0, 6.0, fwd.z * 3.0)
	
	var look_ahead = move_dir * 0.3
	var target_cam_pos = player_pos + cam_offset
	var target_look = player_pos + look_ahead
	
	var cam_lerp = 1.0 - exp(-8.0 * delta)
	var look_lerp = 1.0 - exp(-6.0 * delta)
	
	cam_follow_pos = cam_follow_pos.lerp(target_cam_pos, cam_lerp)
	cam_look_target = cam_look_target.lerp(target_look, look_lerp)
	
	camera.global_position = cam_follow_pos
	camera.look_at(cam_look_target)
	camera_shake = maxf(camera_shake - delta * 0.9, 0.0)
	camera_shake_time += delta * 34.0
	var speed_ratio = clampf(move_dir.length() / 12.0, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, camera_base_fov + speed_ratio * 5.0, 1.0 - exp(-7.0 * delta))
	if camera_shake > 0.0:
		var shake_offset = Vector3(
			sin(camera_shake_time * 1.13) * camera_shake,
			cos(camera_shake_time * 0.91) * camera_shake * 0.6,
			sin(camera_shake_time * 1.47) * camera_shake
		)
		camera.global_position += shake_offset

func _request_camera_shake(amount: float) -> void:
	camera_shake = maxf(camera_shake, amount)

# --- SETUP ---

func _setup_arena() -> void:
	_build_floor(Vector3(0, 0, 0), Color(0.15, 0.15, 0.22))
	_build_floor(Vector3(0, 6, 0), Color(0.18, 0.15, 0.20))
	_build_floor(Vector3(0, 12, 0), Color(0.13, 0.16, 0.20))
	_build_floor(Vector3(0, 18, 0), Color(0.10, 0.18, 0.15))
	_setup_environment()
	
	_build_ramp(Vector3(8, 0, 20), Vector3(8, 6, 20))
	_build_ramp(Vector3(-8, 6, 20), Vector3(-8, 12, 20))
	_build_ramp(Vector3(8, 12, 20), Vector3(8, 18, 20))
	
	_spawn_obstacles()
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
	var mat = _make_carpet_material(color)
	mesh_inst.material_override = mat
	floor_node.add_child(mesh_inst)
	_spawn_ceiling_lights(pos)
	
	for i in range(4):
		var wall = StaticBody3D.new()
		wall.position = pos + Vector3([0, 20, 0, -20][i], 1.5, [20, 0, -20, 0][i])
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
		var wall_mat = _make_wall_material(color)
		wall_mesh.material_override = wall_mat
		wall.add_child(wall_mesh)

func _make_carpet_material(base_color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.95
	mat.metallic = 0.0
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.08
	var texture = NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	mat.albedo_texture = texture
	return mat

func _make_wall_material(base_color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color.darkened(0.3)
	mat.roughness = 0.88
	return mat

func _make_wood_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.24, 0.14)
	mat.roughness = 0.72
	mat.metallic = 0.0
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.045
	var texture = NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	mat.albedo_texture = texture
	return mat

func _spawn_ceiling_lights(floor_pos: Vector3) -> void:
	var light_group = Node3D.new()
	light_group.name = "CeilingLights_%s" % str(int(floor_pos.y))
	add_child(light_group)
	
	for x in [-12.0, 0.0, 12.0]:
		for z in [-12.0, 0.0, 12.0]:
			var light = OmniLight3D.new()
			light.position = floor_pos + Vector3(x, 3.0, z)
			light.light_color = Color(1.0, 0.88, 0.68)
			light.light_energy = 0.35
			light.omni_range = 16.0
			light.shadow_enabled = false
			light_group.add_child(light)
			
			var fixture = MeshInstance3D.new()
			fixture.position = floor_pos + Vector3(x, 2.92, z)
			var fixture_mesh = BoxMesh.new()
			fixture_mesh.size = Vector3(3.0, 0.06, 0.22)
			fixture.mesh = fixture_mesh
			var fixture_mat = StandardMaterial3D.new()
			fixture_mat.albedo_color = Color(0.95, 0.9, 0.72)
			fixture_mat.emission_enabled = true
			fixture_mat.emission = Color(1.0, 0.72, 0.35)
			fixture_mat.emission_energy_multiplier = 1.4
			fixture.material_override = fixture_mat
			light_group.add_child(fixture)

func _setup_environment() -> void:
	var world = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not world or not world.environment:
		return
	var env = world.environment
	env.ambient_light_energy = 0.32
	env.fog_enabled = true
	env.fog_density = 0.008
	env.fog_aerial_perspective = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 0.8

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
	var rng = RandomNumberGenerator.new()
	rng.seed = 1337  # Fixed seed for consistent layout
	
	for i in range(15):
		var desk = _make_desk()
		var floor_y = [0, 6, 12, 18][rng.randi() % 4]
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
	var mat = _make_wood_material()
	mesh_inst.material_override = mat
	desk.add_child(mesh_inst)
	
	return desk

func _spawn_powerups() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 999
	
	for i in range(8):
		var pu = _make_powerup()
		var floor_y = [0.5, 6.5, 12.5, 18.5][rng.randi() % 4]
		pu.position = Vector3(
			rng.randf_range(-12, 12),
			floor_y,
			rng.randf_range(-12, 12)
		)
		add_child(pu)

func _make_powerup() -> Area3D:
	var pu = Area3D.new()
	pu.set_script(load("res://scripts/PowerUpVisual.gd"))
	
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.6
	col.shape = shape
	pu.add_child(col)
	
	var cup_mat = StandardMaterial3D.new()
	cup_mat.albedo_color = Color(0.92, 0.52, 0.12)
	cup_mat.roughness = 0.45
	cup_mat.emission_enabled = true
	cup_mat.emission = Color(1.0, 0.34, 0.04)
	cup_mat.emission_energy_multiplier = 1.2
	
	var cup = MeshInstance3D.new()
	var cup_mesh = CylinderMesh.new()
	cup_mesh.top_radius = 0.34
	cup_mesh.bottom_radius = 0.27
	cup_mesh.height = 0.52
	cup.mesh = cup_mesh
	cup.position.y = 0.0
	cup.material_override = cup_mat
	pu.add_child(cup)
	
	var coffee = MeshInstance3D.new()
	var coffee_mesh = CylinderMesh.new()
	coffee_mesh.top_radius = 0.27
	coffee_mesh.bottom_radius = 0.27
	coffee_mesh.height = 0.035
	coffee.mesh = coffee_mesh
	coffee.position.y = 0.27
	var coffee_mat = StandardMaterial3D.new()
	coffee_mat.albedo_color = Color(0.12, 0.045, 0.015)
	coffee_mat.roughness = 0.3
	coffee.material_override = coffee_mat
	pu.add_child(coffee)
	
	var handle = MeshInstance3D.new()
	var handle_mesh = TorusMesh.new()
	handle_mesh.inner_radius = 0.11
	handle_mesh.outer_radius = 0.18
	handle.mesh = handle_mesh
	handle.position = Vector3(0.34, 0.0, 0.0)
	handle.rotation.x = PI / 2.0
	handle.material_override = cup_mat
	pu.add_child(handle)
	
	var glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.08)
	glow.light_energy = 0.65
	glow.omni_range = 4.0
	pu.add_child(glow)
	
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
	local_player.set_can_move(false)
	add_child(local_player)
	local_player.position = Vector3(0, 1.5, -10)
	players.append(local_player)
	
	# Initialize camera position at player so first frame isn't a wild fly-in
	if camera:
		cam_follow_pos = local_player.global_position + Vector3(0, 6, 10)
		cam_look_target = local_player.global_position
		camera.global_position = cam_follow_pos

func _setup_hud() -> void:
	var hud_script = load("res://scripts/HUD.gd")
	if not hud_script:
		return
	hud = CanvasLayer.new()
	hud.set_script(hud_script)
	$UI.add_child(hud)

func _update_hud() -> void:
	if not hud or not local_player:
		return
	if hud.has_method("set_timer_text"):
		hud.set_timer_text(timer_label.text if timer_label else "")
		hud.set_speed(Vector2(local_player.velocity.x, local_player.velocity.z).length(), local_player.max_speed)
		hud.set_boost(local_player.boost_cd_timer, local_player.boost_duration, local_player.is_boosting)
		hud.set_floor(clampi(int(floor(local_player.global_position.y / 6.0)) + 1, 1, 4))
		hud.set_player_position(local_player.global_position, clampi(int(floor(local_player.global_position.y / 6.0)), 0, 3))
		hud.set_status("COUNTDOWN" if match_state == &"countdown" else "RACE", Color("ffcf55"))


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
	
	body.set_can_move(false)
	
	if finish_order.size() == 1:
		_show_results()

func _end_race() -> void:
	match_state = &"finished"
	_show_results()

func _show_results() -> void:
	match_state = &"finished"
	if results_panel:
		results_panel.visible = true
		results_panel.modulate.a = 0.0
		results_panel.scale = Vector2(0.86, 0.86)
		var label = results_panel.get_node_or_null("VBox/WinnerLabel")
		if label and finish_order.size() > 0:
			label.text = "%s WINS!\nLast one buys beers!" % finish_order[0].name
		var stats = results_panel.get_node_or_null("VBox/StatsLabel")
		if not stats:
			stats = Label.new()
			stats.name = "StatsLabel"
			stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stats.add_theme_font_size_override("font_size", 18)
			results_panel.get_node("VBox").add_child(stats)
		stats.text = "TOP SPEED  %d km/h\nTRAPS PLACED  %d" % [roundi(top_speed * 3.6), traps_placed]
		var tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(results_panel, "modulate:a", 1.0, 0.32)
		tween.tween_property(results_panel, "scale", Vector2.ONE, 0.38)


func _on_rematch() -> void:
	get_tree().reload_current_scene()

func _on_back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- INPUT ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
