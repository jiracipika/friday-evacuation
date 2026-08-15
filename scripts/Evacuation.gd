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
var mobile_controls: Control = null
var remote_players: Dictionary = {}
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
	var network = get_node_or_null("/root/Network")
	if network:
		network.remote_player_state.connect(_on_remote_player_state)
		network.player_connected.connect(_on_network_player_connected)
		network.player_disconnected.connect(_on_network_player_disconnected)
		for peer_id in network.connected_players:
			if int(peer_id) != multiplayer.get_unique_id():
				_on_network_player_connected(int(peer_id), network.connected_players[peer_id])

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
				var network = get_node_or_null("/root/Network")
				if network and network.peer:
					network.broadcast_player_state(local_player.global_position, local_player.velocity)
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
	var a11y_shake = load("res://scripts/Accessibility.gd")
	if a11y_shake and not a11y_shake.screen_shake_enabled():
		return
	camera_shake = maxf(camera_shake, amount)

func _on_network_player_connected(peer_id: int, player_name: String) -> void:
	if remote_players.has(peer_id):
		return
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if not player_scene:
		return
	var remote = player_scene.instantiate()
	remote.player_display_name = player_name
	remote.set_can_move(false)
	remote.name = "Remote_%d" % peer_id
	add_child(remote)
	remote_players[peer_id] = remote

func _on_network_player_disconnected(peer_id: int) -> void:
	var remote = remote_players.get(peer_id)
	if remote and is_instance_valid(remote):
		remote.queue_free()
	remote_players.erase(peer_id)

func _on_remote_player_state(peer_id: int, position: Vector3, remote_velocity: Vector3) -> void:
	var remote = remote_players.get(peer_id)
	if remote and is_instance_valid(remote):
		remote.global_position = remote.global_position.lerp(position, 0.45)
		remote.velocity = remote_velocity

# --- SETUP ---

var exit_marker: MeshInstance3D

func _setup_arena() -> void:
	_build_floor(Vector3(0, 0, 0), Color(0.15, 0.15, 0.22), 0)
	_build_floor(Vector3(0, 6, 0), Color(0.18, 0.15, 0.20), 1)
	_build_floor(Vector3(0, 12, 0), Color(0.13, 0.16, 0.20), 2)
	_build_floor(Vector3(0, 18, 0), Color(0.10, 0.18, 0.15), 3)
	_setup_environment()

	# Elevator pads connect floors. Each pad is an Area3D trigger zone that
	# smoothly lifts the player to the next floor when entered.
	# This avoids Godot 4 CharacterBody3D slope/stair physics issues entirely.
	_build_elevator(Vector3(12, 0.5, 14), Vector3(12, 6.5, -2), 1)   # Floor 1 → 2
	_build_elevator(Vector3(-12, 6.5, -2), Vector3(-12, 12.5, 14), 2) # Floor 2 → 3
	_build_elevator(Vector3(12, 12.5, 14), Vector3(12, 18.5, -2), 3)  # Floor 3 → 4

	_spawn_obstacles()
	_spawn_powerups()
	_add_exit_marker()

# --- FLOOR/RAMP GUIDANCE ---
func _build_floor(pos: Vector3, color: Color, floor_index: int = 0) -> void:
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
	var mat = _make_carpet_material(color, floor_index)
	mesh_inst.material_override = mat
	floor_node.add_child(mesh_inst)

	# Add floor number on floor
	_add_floor_number(pos, floor_index)
	# Add exit direction indicators on floor 4
	if floor_index == 3:
		_add_exit_indicators(pos)

	_spawn_ceiling_lights(pos, floor_index)

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
		var wall_mat = _make_wall_material(color, floor_index)
		wall_mesh.material_override = wall_mat
		wall.add_child(wall_mesh)

func _make_carpet_material(base_color: Color, floor_index: int = 0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.95
	mat.metallic = 0.0
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = 900 + floor_index  # Different noise per floor
	noise.frequency = 0.08
	var texture = NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	mat.albedo_texture = texture
	return mat

func _make_wall_material(base_color: Color, floor_index: int = 0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color.darkened(0.3)
	mat.roughness = 0.88
	return mat

func _add_floor_number(floor_pos: Vector3, floor_index: int) -> void:
	var number = Label3D.new()
	number.text = "%d" % (floor_index + 1)
	number.pixel_size = 0.04
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	number.set_material_override(mat)
	number.position = floor_pos + Vector3(-16, 0.15, -16)
	add_child(number)

	var number2 = number.duplicate()
	number2.position = floor_pos + Vector3(16, 0.15, 16)
	add_child(number2)

func _add_exit_indicators(floor_pos: Vector3) -> void:
	for x in [-10, 0, 10]:
		var arrow = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.4
		cone.bottom_radius = 0.8
		cone.height = 0.15
		arrow.mesh = cone
		arrow.rotation.x = PI / 2.0
		# Point toward exit zone at z=15 (relative to floor 4 at y=18)
		arrow.position = floor_pos + Vector3(x, 0.15, 13)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 1.0, 0.4, 0.12)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		arrow.material_override = mat
		add_child(arrow)

func _add_exit_marker() -> void:
	exit_marker = MeshInstance3D.new()
	var ring = TorusMesh.new()
	ring.inner_radius = 2.8
	ring.outer_radius = 3.2
	exit_marker.mesh = ring
	# Position on floor 4 (y=18), near the exit zone at z=15
	exit_marker.position = Vector3(0, 19.3, 15.0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.95, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.95, 0.3)
	mat.emission_energy_multiplier = 1.8
	exit_marker.material_override = mat
	add_child(exit_marker)

	var arrow = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 2.0
	arrow.mesh = cone
	arrow.position = Vector3(0, 21.0, 15.0)
	arrow.rotation.x = PI
	arrow.material_override = mat
	add_child(arrow)

	animate_exit_marker()

func animate_exit_marker() -> void:
	if not exit_marker:
		return
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(exit_marker, "scale", Vector3(1.2, 1.2, 1.2), 0.8)
	tween.tween_property(exit_marker, "scale", Vector3(1.0, 1.0, 1.0), 0.8)

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

func _spawn_ceiling_lights(floor_pos: Vector3, floor_index: int = 0) -> void:
	var light_group = Node3D.new()
	light_group.name = "CeilingLights_%s" % str(int(floor_pos.y))
	add_child(light_group)
	for x in [-12.0, 0.0, 12.0]:
		for z in [-12.0, 0.0, 12.0]:
			var light = OmniLight3D.new()
			light.position = floor_pos + Vector3(x, 3.0, z)
			light.light_color = Color(1.0, 0.92, 0.78)
			light.light_energy = 0.75
			light.omni_range = 22.0
			light.shadow_enabled = false
			light.light_bake_mode = OmniLight3D.BAKE_STATIC
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
	env.ambient_light_energy = 0.42
	env.fog_enabled = false
	env.glow_enabled = false
	env.glow_strength = 0.8

func _build_elevator(from_pos: Vector3, to_pos: Vector3, target_floor: int) -> void:
	# Visual platform at the entry point
	var pad = MeshInstance3D.new()
	var pad_mesh = BoxMesh.new()
	pad_mesh.size = Vector3(4, 0.15, 4)
	pad.mesh = pad_mesh
	pad.position = from_pos + Vector3(0, 0.1, 0)
	var pad_mat = StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.15, 0.5, 1.0, 0.7)
	pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad_mat.emission_enabled = true
	pad_mat.emission = Color(0.1, 0.4, 1.0)
	pad_mat.emission_energy_multiplier = 0.8
	pad.material_override = pad_mat
	add_child(pad)

	# Pulsing light above the pad
	var pad_light = OmniLight3D.new()
	pad_light.position = from_pos + Vector3(0, 2.0, 0)
	pad_light.light_color = Color(0.2, 0.6, 1.0)
	pad_light.light_energy = 1.0
	pad_light.omni_range = 8.0
	pad_light.shadow_enabled = false
	add_child(pad_light)

	# Arrow pointing up
	var arrow = MeshInstance3D.new()
	var arrow_mesh = CylinderMesh.new()
	arrow_mesh.top_radius = 0.0
	arrow_mesh.bottom_radius = 0.8
	arrow_mesh.height = 1.5
	arrow.mesh = arrow_mesh
	arrow.position = from_pos + Vector3(0, 1.5, 0)
	var arrow_mat = StandardMaterial3D.new()
	arrow_mat.albedo_color = Color(0.2, 0.7, 1.0)
	arrow_mat.emission_enabled = true
	arrow_mat.emission = Color(0.1, 0.5, 1.0)
	arrow_mat.emission_energy_multiplier = 1.2
	arrow.material_override = arrow_mat
	add_child(arrow)

	# Trigger zone — detects when player enters
	var trigger = Area3D.new()
	trigger.position = from_pos
	var trigger_col = CollisionShape3D.new()
	var trigger_shape = BoxShape3D.new()
	trigger_shape.size = Vector3(4, 3, 4)
	trigger_col.shape = trigger_shape
	trigger.add_child(trigger_col)
	add_child(trigger)

	# Destination marker (visual)
	var dest_marker = MeshInstance3D.new()
	var dest_mesh = BoxMesh.new()
	dest_mesh.size = Vector3(4, 0.15, 4)
	dest_marker.mesh = dest_mesh
	dest_marker.position = to_pos + Vector3(0, 0.1, 0)
	dest_marker.material_override = pad_mat
	add_child(dest_marker)

	# Connect the trigger — when player enters, teleport them to the destination
	# (must teleport because floors are solid boxes; launching would hit the underside)
	trigger.body_entered.connect(func(body: Node3D):
		if not body.is_in_group("players"):
			return
		var dy = to_pos.y - body.global_position.y
		if dy > 1.0:
			# Teleport to destination
			body.global_position = to_pos + Vector3(0, 1.0, 0)
			body.velocity = Vector3.ZERO
			# Play boost sound
			var audio = get_node_or_null("/root/AudioManager")
			if audio and audio.has_method("play_sfx"):
				audio.play_sfx("boost", 1.5)
			var a11y = load("res://scripts/Accessibility.gd")
			if a11y:
				a11y.caption("ELEVATOR", 1.0)
			# Visual feedback
			var impact_fx = load("res://scripts/ImpactFX.gd")
			if impact_fx and impact_fx.has_method("boost_burst"):
				impact_fx.boost_burst(body.global_position)
	)

func _build_ramp(from_pos: Vector3, to_pos: Vector3) -> void:
	# Legacy function kept for compatibility — now delegates to elevator
	_build_elevator(from_pos, to_pos, 0)

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
	shape.radius = 0.7
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

	# Add ring underneath to make it more visible
	var ring = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.6
	ring_mesh.outer_radius = 0.65
	ring.mesh = ring_mesh
	ring.rotation.x = PI / 2.0
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.65, 0.12)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.45, 0.08)
	ring_mat.emission_energy_multiplier = 0.6
	ring.material_override = ring_mat
	ring.position.y = -0.1
	pu.add_child(ring)

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
		return
	local_player = player_scene.instantiate()
	local_player.position = Vector3(0, 1.0, 0)
	add_child(local_player)
	players.append({"id": 1, "name": local_player.player_display_name})

# --- GAME FLOW ---

func _start_countdown() -> void:
	match_state = &"countdown"
	timer = countdown_seconds
	if countdown_label:
		countdown_label.text = str(int(countdown_seconds))
		countdown_label.visible = true

func _update_countdown_display() -> void:
	if countdown_label:
		var seconds = int(ceilf(timer))
		countdown_label.text = str(seconds)
		if seconds <= 0:
			countdown_label.visible = false

func _start_race() -> void:
	match_state = &"racing"
	timer = 0.0
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("GO!", 1.0)
	if local_player:
		local_player.set_can_move(true)
	_spawn_traps()

func _spawn_traps() -> void:
	var manager = get_node_or_null("/root/GameManager")
	var network = get_node_or_null("/root/Network")

	var trap_scene = load("res://scenes/objects/SabotageTrap.tscn")
	if not trap_scene:
		return

	for i in range(4):
		var trap = trap_scene.instantiate()
		var floor_y = [0.5, 6.5, 12.5, 18.5][i]
		trap.position = Vector3(
			randf_range(-15, 15),
			floor_y,
			randf_range(-15, 15)
		)
		if trap.has_method("_set_owner"):
			trap._set_owner(network.multiplayer_peer.get_unique_id() if network and network.multiplayer_peer else 1)
		traps_placed += 1
		add_child(trap)

func _update_timer_display() -> void:
	if timer_label:
		var remaining = time_limit - timer
		timer_label.text = "TIME: %d" % int(remaining)

func _update_hud() -> void:
	if not hud:
		return
	var speed_label = hud.get_node_or_null("SpeedLabel")
	if speed_label and local_player:
		var speed = int(Vector2(local_player.velocity.x, local_player.velocity.z).length())
		speed_label.text = "SPEED: %d km/h" % speed

func _on_player_reached_exit(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	var player_id = body.get_instance_id()
	for entry in finish_order:
		if entry.player_id == player_id:
			return
	finish_order.append({
		"player_id": player_id,
		"name": body.player_display_name if body.has_method("get_player_display_name") else "Unknown",
		"time": timer
	})
	if body == local_player:
		if local_player and local_player.has_method("trigger_mobile_action"):
			local_player.trigger_mobile_action("victory")
		var a11y = load("res://scripts/Accessibility.gd")
		if a11y:
			a11y.caption("FINISH!", 2.0)
	_end_race()

func _end_race() -> void:
	if match_state == &"finished":
		return
	match_state = &"finished"
	if local_player:
		local_player.set_can_move(false)

	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		var won := false
		if finish_order.size() > 0 and is_instance_valid(local_player):
			won = finish_order[0].player_id == local_player.get_instance_id()
		stats.record_race(won, top_speed, 0)

	if results_panel:
		results_panel.visible = true
		var vbox = results_panel.get_node_or_null("VBox")
		if vbox:
			var winner_label = vbox.get_node_or_null("WinnerLabel")
			var stats_label = vbox.get_node_or_null("StatsLabel")
			if winner_label:
				if finish_order.size() > 0:
					var winner = finish_order[0]
					winner_label.text = "%s WINS!" % winner.name
				else:
					winner_label.text = "NO WINNER"
			if stats_label:
				stats_label.text = "TOP SPEED: %d km/h\nTRAPS HIT: %d" % [int(top_speed), traps_hit]

	var impact = load("res://scripts/ImpactFX.gd")
	if impact and impact.has_method("confetti_burst"):
		impact.confetti_burst(local_player.global_position if local_player else Vector3.ZERO)

func _on_rematch() -> void:
	get_tree().reload_current_scene()

func _on_back_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and match_state != &"finished":
		var network = get_node_or_null("/root/Network")
		if network and network.peer:
			return
		var pause_menu = load("res://scripts/PauseMenu.gd")
		pause_menu.create(self, _on_back_to_menu)
		get_viewport().set_input_as_handled()

func _setup_hud() -> void:
	hud = $UI
	if hud:
		var speed_label = hud.get_node_or_null("SpeedLabel")
		if speed_label:
			speed_label.text = "SPEED: 0 km/h"
		# Caption overlay for audio-cue subtitles (no-op when disabled)
		var overlay_script = load("res://scripts/SubtitleOverlay.gd")
		if overlay_script:
			var overlay = Control.new()
			overlay.set_script(overlay_script)
			hud.add_child(overlay)