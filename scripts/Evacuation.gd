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
var hud_ext: CanvasLayer = null  # scripts/HUD.gd instance (speed/boost/item/minimap)
var mobile_controls: Control = null
var remote_players: Dictionary = {}
var top_speed: float = 0.0
var traps_hit: int = 0
var traps_placed: int = 0
var sp_modifiers: bool = false
var new_personal_best: bool = false
var ghost_racer: Node3D
var announcer: Node = null
var hazards: Node3D  # Phase 4C Hazards controller

## Smooth camera state
var cam_follow_pos: Vector3 = Vector3.ZERO
var cam_look_target: Vector3 = Vector3.ZERO
var camera_base_fov: float = 70.0
var camera_shake: float = 0.0
var camera_shake_time: float = 0.0
var camera_roll: float = 0.0  # corner-roll feel (radians, small)
var camera_initialized := false
var camera_tracked_player_y := 0.0
# Shared-material caches (perf: one noise build / one leaf material set
# per scene instance instead of one per desk blob / plant blob).
var _wood_mat: StandardMaterial3D = null
var _leaf_mats: Dictionary = {}
const CAMERA_DISTANCE := 7.5
const CAMERA_HEIGHT := 4.2
const CAMERA_LOOK_HEIGHT := 1.0
const CAMERA_COLLISION_MARGIN := 0.35
## Distance-based visibility culling for stacked-floor content (Phase 7C).
## Whole floors 2+ floors away hide entirely; the adjacent floor keeps
## emissive fixtures but drops its 9 OmniLights and non-emissive clutter.
## The player's own floor always renders fully.
var _floor_groups: Dictionary = {}  # floor_index -> Array[Node]
var _culled_floors: Dictionary = {}  # floor_index -> bool (currently hidden)
const CULL_HIDE_DISTANCE_FLOORS := 2
const CULL_LIGHT_DISTANCE_FLOORS := 1

## Nodes
@onready var countdown_label: Label3D = $Arena/CountdownLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var results_panel: Panel = $UI/ResultsPanel
@onready var camera: Camera3D = $Camera3D

# --- LIFECYCLE ---

func _ready() -> void:
	_setup_arena()
	# Mouse-look: capture the cursor for the whole match (released in
	# _end_race/_on_back_to_menu/_exit_tree). Visible while paused so the
	# pause menu stays mouse-usable.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var input_prefs = load("res://scripts/InputPrefs.gd")
	if input_prefs:
		input_prefs.refresh_cache()
	_spawn_player()
	_apply_player_modifiers()
	_maybe_spawn_ghost()
	_start_countdown()
	_setup_hud()
	camera_base_fov = camera.fov if camera else 70.0
	if local_player and local_player.has_signal("shake_requested"):
		local_player.shake_requested.connect(_request_camera_shake)
	if local_player and local_player.has_signal("stunned"):
		local_player.stunned.connect(func(): _announcer().say("trap", _const_lines("TRAP_HIT_LINES")))
	# Panic-cam: PiP of the rider's own face while boosting/stunned.
	# Mounted onto the HUD CanvasLayer so it inherits HUD layering (above
	# the 3D view) instead of fighting scene-space UI.
	var PanicCamScript = load("res://scripts/PanicCam.gd")
	if PanicCamScript and hud:
		PanicCamScript.mount(hud, local_player)
	var network = get_node_or_null("/root/Network")
	if network:
		network.remote_player_state.connect(_on_remote_player_state)
		network.player_connected.connect(_on_network_player_connected)
		network.player_disconnected.connect(_on_network_player_disconnected)
		if not multiplayer.is_server():
			multiplayer.server_disconnected.connect(_on_host_lost)
		if network.has_signal("world_trap_dropped"):
			network.world_trap_dropped.connect(_on_world_trap_dropped)
		if network.has_signal("world_pickup_taken"):
			network.world_pickup_taken.connect(_on_world_pickup_taken)
		if network.has_signal("player_stunned"):
			network.player_stunned.connect(_on_remote_stun)
		for peer_id in network.connected_players:
			if int(peer_id) != multiplayer.get_unique_id():
				_on_network_player_connected(int(peer_id), network.connected_players[peer_id])

## Host vanished mid-race: don't strand the client in a dead simulation —
## caption what happened and bounce back to the main menu after a beat.
func _on_host_lost() -> void:
	_remote_event_caption("HOST DISCONNECTED — returning to menu")
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if is_inside_tree():
			_on_back_to_menu())

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
	_tick_light_flicker(delta)
	match match_state:
		&"countdown":
			timer -= delta
			_update_countdown_display()
			if timer <= 0:
				_start_race()
		&"racing":
			timer += delta
			_update_timer_display()
			_respawn_if_fell()
			if local_player and is_instance_valid(local_player):
				top_speed = max(top_speed, Vector2(local_player.velocity.x, local_player.velocity.z).length())
				_update_hud()
				var network = get_node_or_null("/root/Network")
				if network and network.peer:
					var sync_rot: float = local_player.model_parent.rotation.y if "model_parent" in local_player and local_player.model_parent else 0.0
					network.broadcast_player_state(local_player.global_position, local_player.velocity, sync_rot)
			if finish_order.size() >= players.size() or timer >= time_limit:
				if timer >= time_limit and finish_order.size() < players.size():
					# Timed out before finishing: sassy loss line.
					_announcer().say("misc", _const_lines("LOSE_LINES"), true)
				_end_race()
		&"finished":
			pass

	_update_camera(delta)
	_update_floor_culling()

## Phase 4A: if a player falls through a floor-3 gap (or off any floor),
## respawn them at their last checkpoint. Watched during racing only.
func _respawn_if_fell() -> void:
	for body in get_tree().get_nodes_in_group("players"):
		if not (body is CharacterBody3D and is_instance_valid(body)):
			continue
		if not "respawn_point" in body:
			continue
		var floor_y: float = body.respawn_point.y
		# Falling more than 5 units below the checkpoint floor = fell
		if body.global_position.y < floor_y - 5.0:
			if body.has_method("respawn"):
				body.respawn()
				var a11y = load("res://scripts/Accessibility.gd")
				if a11y:
					a11y.caption("FELL! RESPAWNED AT CHECKPOINT", 1.4)

func _update_camera(delta: float) -> void:
	if not local_player or not is_instance_valid(local_player):
		return
	if not camera:
		return

	# Right-stick camera orbit + keyboard nudge (camera_left/right).
	# Scaled by delta so the orbit rate is framerate-independent.
	var stick_strength := Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
	if absf(stick_strength) > 0.01:
		var input_prefs = load("res://scripts/InputPrefs.gd")
		if input_prefs:
			input_prefs.apply_stick(stick_strength, delta)
	var player_pos: Vector3 = local_player.global_position
	var player_vel: Vector3 = local_player.velocity
	var move_dir := Vector3(player_vel.x, 0.0, player_vel.z)
	var fwd: Vector3 = local_player.get_facing_direction() if local_player.has_method("get_facing_direction") else -local_player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()

	# Follow the visible chair facing, not raw velocity. Velocity-facing cameras
	# whip 180 degrees during a reverse and make camera-relative steering fight
	# itself. The lower height also stays safely below the next floor (the old
	# +6 offset placed the camera directly inside the floor slab, blacking out
	# the entire gameplay view).
	var yaw_offset := 0.0
	var input_prefs = load("res://scripts/InputPrefs.gd")
	if input_prefs:
		yaw_offset = input_prefs.wrapped_yaw()
	var cam_dir := fwd.rotated(Vector3.UP, yaw_offset)
	var target_cam_pos := player_pos - cam_dir * CAMERA_DISTANCE + Vector3.UP * CAMERA_HEIGHT
	var speed := move_dir.length()
	var look_ahead := move_dir.normalized() * minf(speed * 0.22, 2.0) if speed > 0.1 else Vector3.ZERO
	var target_look := player_pos + Vector3.UP * CAMERA_LOOK_HEIGHT + look_ahead
	if absf(yaw_offset) > 0.0001:
		target_look = player_pos + (target_look - player_pos).rotated(Vector3.UP, yaw_offset)
	target_cam_pos = _resolve_camera_occlusion(target_look, target_cam_pos)

	# Elevator teleports cross a floor slab. Snap camera state to the new floor
	# rather than interpolating the camera through solid geometry.
	if camera_initialized and absf(player_pos.y - camera_tracked_player_y) > 3.0:
		camera_initialized = false
	camera_tracked_player_y = player_pos.y
	if not camera_initialized:
		cam_follow_pos = target_cam_pos
		cam_look_target = target_look
		camera_initialized = true

	var cam_lerp = 1.0 - exp(-8.0 * delta)
	var look_lerp = 1.0 - exp(-6.0 * delta)

	cam_follow_pos = cam_follow_pos.lerp(target_cam_pos, cam_lerp)
	cam_look_target = cam_look_target.lerp(target_look, look_lerp)

	camera.global_position = cam_follow_pos
	if not cam_follow_pos.is_equal_approx(cam_look_target):
		camera.look_at(cam_look_target)
	# CAMERA FEEL: roll into corners + height drop at speed. The drift
	# angle (facing vs velocity divergence) tilts the camera a couple of
	# degrees toward the inside of the turn — sells the slide. Everything
	# is small and reduced-motion aware.
	var a11y_check = load("res://scripts/Accessibility.gd")
	var motion_ok: bool = a11y_check == null or not a11y_check.reduced_motion_enabled()
	if motion_ok and local_player.has_method("get_facing_direction"):
		var vel_flat := Vector3(player_vel.x, 0.0, player_vel.z)
		if vel_flat.length() > 4.0 and fwd.length() > 0.1:
			var cross_y := fwd.cross(vel_flat.normalized()).y
			var roll_target := clampf(cross_y * 0.06, -0.035, 0.035)  # ±2 degrees
			camera_roll = lerpf(camera_roll, roll_target, 1.0 - exp(-5.0 * delta))
		else:
			camera_roll = lerpf(camera_roll, 0.0, 1.0 - exp(-5.0 * delta))
		camera.rotate_object_local(Vector3.BACK, camera_roll)
	camera_shake = maxf(camera_shake - delta * 0.9, 0.0)
	camera_shake_time += delta * 34.0
	var speed_ratio = clampf(speed / 12.0, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, camera_base_fov + speed_ratio * 5.0, 1.0 - exp(-7.0 * delta))
	if camera_shake > 0.0:
		var shake_offset = Vector3(
			sin(camera_shake_time * 1.13) * camera_shake,
			cos(camera_shake_time * 0.91) * camera_shake * 0.6,
			sin(camera_shake_time * 1.47) * camera_shake
		)
		camera.global_position += shake_offset

func _resolve_camera_occlusion(origin: Vector3, desired: Vector3) -> Vector3:
	var world := get_world_3d()
	if world == null:
		return desired
	var exclude: Array[RID] = []
	if local_player and is_instance_valid(local_player):
		exclude.append(local_player.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, desired, 0xFFFFFFFF, exclude)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	return (hit["position"] as Vector3) + (hit["normal"] as Vector3) * CAMERA_COLLISION_MARGIN

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
	var network_node = get_node_or_null("/root/Network")
	if network_node and network_node.has_method("get_player_color"):
		remote.player_color = network_node.get_player_color(peer_id)
	remote.set_can_move(false)
	remote.position = _slot_for_peer(int(peer_id))
	remote.name = "Remote_%d" % peer_id
	add_child(remote)
	remote_players[peer_id] = remote

func _own_peer_id() -> int:
	var network = get_node_or_null("/root/Network")
	if network and network.peer:
		return network.multiplayer.get_unique_id()
	return 1

func _on_network_player_disconnected(peer_id: int) -> void:
	var remote = remote_players.get(peer_id)
	if remote and is_instance_valid(remote):
		remote.queue_free()
	remote_players.erase(peer_id)

func _on_remote_player_state(peer_id: int, position: Vector3, remote_velocity: Vector3, rot_y: float = 0.0) -> void:
	var remote = remote_players.get(peer_id)
	if remote and is_instance_valid(remote):
		remote.global_position = remote.global_position.lerp(position, 0.45)
		remote.velocity = remote_velocity
		# Rotation: lerp model toward the reported facing (Phase 5 sync)
		if "model_parent" in remote and remote.model_parent:
			var current_rot: float = remote.model_parent.rotation.y
			var diff := angle_difference(current_rot, rot_y)
			remote.model_parent.rotation.y = current_rot + diff * 0.5

## Phase 5: remote player dropped a trap — spawn it locally (skip if it's
## our own drop echoing back).
func _on_world_trap_dropped(peer_id: int, position: Vector3, trap_type: String, forced: bool) -> void:
	var network = get_node_or_null("/root/Network")
	if network and peer_id == network.multiplayer.get_unique_id():
		return  # already spawned locally at drop time
	var trap_scene = load("res://scenes/objects/SabotageTrap.tscn")
	if not trap_scene:
		return
	var trap = trap_scene.instantiate()
	if forced and trap.has_method("_set_forced_type"):
		trap._set_forced_type(trap_type)
	trap.world_spawned = true
	add_child(trap)
	trap.global_position = position
	_remote_event_caption("%s dropped a trap!" % _peer_display_name(peer_id))

## Phase 5: remote player took a pickup — despawn the same pickup locally.
func _on_world_pickup_taken(peer_id: int, pickup_name: String) -> void:
	var network = get_node_or_null("/root/Network")
	if network and peer_id == network.multiplayer.get_unique_id():
		return
	for child in get_children():
		if "sync_name" in child and child.sync_name == pickup_name:
			child.queue_free()
			break
	_remote_event_caption("%s grabbed %s" % [_peer_display_name(peer_id), pickup_name])

## Phase 5: a stun fired on another peer's machine applies to our chair if
## we're the victim.
func _on_remote_stun(peer_id: int, duration: float) -> void:
	var network = get_node_or_null("/root/Network")
	if network == null:
		return
	var own_id: int = network.multiplayer.get_unique_id()
	if peer_id != own_id:
		return
	if local_player and is_instance_valid(local_player) and local_player.has_method("stun"):
		local_player.stun(duration)

func _peer_display_name(peer_id: int) -> String:
	var network = get_node_or_null("/root/Network")
	if network and network.connected_players.has(peer_id):
		return String(network.connected_players[peer_id])
	return "Player %d" % peer_id

func _remote_event_caption(text: String) -> void:
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption(text, 1.2)

# --- SETUP ---

var exit_marker: MeshInstance3D

func _setup_arena() -> void:
	# Race modifiers (single-player only — any active peer disables them)
	var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
	var network_mod := get_node_or_null("/root/Network")
	sp_modifiers = RaceModifiersScript != null and not (network_mod and network_mod.peer)
	if sp_modifiers and RaceModifiersScript.is_active(RaceModifiersScript.Modifier.TIME_ATTACK_90):
		time_limit = 90.0
	_build_floor(Vector3(0, 0, 0), Color(0.15, 0.15, 0.22), 0)
	_build_floor(Vector3(0, 6, 0), Color(0.18, 0.15, 0.20), 1)
	_build_floor(Vector3(0, 12, 0), Color(0.13, 0.16, 0.20), 2)
	_build_floor(Vector3(0, 18, 0), Color(0.10, 0.18, 0.15), 3)
	_setup_environment()

	# Phase 4A themed dressing per floor (kept out of _build_floor so the
	# base geometry stays reusable and LevelClearTest-syncable)
	_theme_floor1_cubicles()
	_theme_floor2_open_office()
	_theme_floor3_stairwell()
	_theme_floor4_cafeteria_and_lot()
	# Phase 4C dynamic hazards (doors + strobes now; roombas/debris/fire drill
	# activate at race start)
	var hazards_script = load("res://scripts/Hazards.gd")
	if hazards_script:
		hazards = Node3D.new()
		hazards.set_script(hazards_script)
		hazards.name = "Hazards"
		add_child(hazards)

	# Elevator pads connect floors. Each pad is an Area3D trigger zone that
	# smoothly lifts the player to the next floor when entered.
	# This avoids Godot 4 CharacterBody3D slope/stair physics issues entirely.
	_build_elevator(Vector3(12, 0.5, 14), Vector3(12, 6.5, -2), 1)   # Floor 1 → 2
	_build_elevator(Vector3(-12, 6.5, -2), Vector3(-12, 12.5, 14), 2) # Floor 2 → 3
	_build_elevator(Vector3(12, 12.5, 14), Vector3(12, 18.5, -2), 3)  # Floor 3 → 4

	_spawn_obstacles()
	_spawn_powerups()
	_add_exit_marker()

# --- PHASE 4A THEMED FLOORS ---

## Floor 1 — Cubicle Farm: partition grid with a central corridor, plants.
func _theme_floor1_cubicles() -> void:
	var partition_mat := StandardMaterial3D.new()
	partition_mat.albedo_color = Color(0.23, 0.29, 0.35)  # gray-blue #3a4a5a-ish
	partition_mat.roughness = 0.9
	for gx in range(-2, 3):
		for gz in range(-2, 3):
			if gx == 0 and gz >= -1 and gz <= 1:
				continue  # main corridor down the center
			if absf(gx * 8.0) > 15.0 or absf(gz * 8.0) > 15.0:
				continue
			var cub := _make_cubicle_partition()
			cub.position = Vector3(gx * 8.0, 0.4, gz * 8.0)
			add_child(cub)
	# Office plants as soft obstacles at corridor mouths
	for plant_pos in [Vector3(-4, 0, -14), Vector3(4, 0, -14), Vector3(-4, 0, 14), Vector3(4, 0, 14)]:
		var plant := _make_plant()
		plant.position = plant_pos
		add_child(plant)

func _make_cubicle_partition() -> StaticBody3D:
	var part := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.4, 0.8, 0.25)
	col.shape = shape
	col.position = Vector3(0, 0.4, 0)
	part.add_child(col)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(5.4, 0.8, 0.25)
	mesh_node.mesh = mesh
	mesh_node.position = Vector3(0, 0.4, 0)
	# Textured cubicle fabric (was dead flat color + unused inline material).
	var helper = load("res://scripts/WallMaterials.gd")
	if helper != null and helper.has_method("make_partition"):
		mesh_node.material_override = helper.make_partition(randi() % 3)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.23, 0.29, 0.35)
		mat.roughness = 0.9
		mesh_node.material_override = mat
	part.add_child(mesh_node)
	return part

func _make_plant() -> StaticBody3D:
	var plant := StaticBody3D.new()
	var pot_col := CollisionShape3D.new()
	var pot_shape := CylinderShape3D.new()
	pot_shape.radius = 0.4
	pot_shape.height = 1.2
	pot_col.shape = pot_shape
	pot_col.position = Vector3(0, 0.6, 0)
	plant.add_child(pot_col)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.09
	trunk_mesh.bottom_radius = 0.12
	trunk_mesh.height = 0.7
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0, 0.35, 0)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.24, 0.14)
	trunk.material_override = trunk_mat
	plant.add_child(trunk)

	for i in range(3):
		var blob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.42 + 0.08 * i
		sphere.height = 0.84 + 0.16 * i
		blob.mesh = sphere
		blob.position = Vector3((i - 1) * 0.18, 0.95 + i * 0.22, (1 - i) * 0.12)
		# Shared leaf material per lightness step (was one new material per
		# blob per plant — pure batching loss, zero visual difference).
		var leaf_key := i
		if _leaf_mats.has(leaf_key):
			blob.material_override = _leaf_mats[leaf_key]
		else:
			var leaf_mat := StandardMaterial3D.new()
			leaf_mat.albedo_color = Color(0.16, 0.38, 0.2).lightened(0.05 * i)
			leaf_mat.roughness = 0.95
			_leaf_mats[leaf_key] = leaf_mat
			blob.material_override = leaf_mat
		plant.add_child(blob)
	return plant

## Floor 2 — Open Office: conference tables, water-cooler stun fixtures,
## tile (fast) vs carpet (grippy) speed zones.
func _theme_floor2_open_office() -> void:
	var y := 6.0
	# Two conference tables flanking the center
	for tx in [-6.0, 6.0]:
		var table := _make_conference_table()
		table.position = Vector3(tx, y, 0)
		add_child(table)
	# Water coolers — permanent stun fixtures (roadmap 4A)
	for cooler_pos in [Vector3(-12, y, 10), Vector3(12, y, 10), Vector3(0, y, -12)]:
		var cooler := _make_stun_fixture(0)  # WATER_COOLER
		cooler.position = cooler_pos
		add_child(cooler)
	# Speed zones: tile strip (fast, slick) vs carpet patch (grippy)
	var tile := _make_surface_zone(0.55, Vector3(10, 2.0, 6), Color(0.55, 0.75, 1.0, 0.10))
	tile.position = Vector3(0, y + 0.15, 8)
	add_child(tile)
	var carpet := _make_surface_zone(1.8, Vector3(8, 2.0, 8), Color(0.35, 0.6, 0.4, 0.12))
	carpet.position = Vector3(-10, y + 0.15, -8)
	add_child(carpet)

func _make_conference_table() -> StaticBody3D:
	var table := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 0.75, 1.2)
	col.shape = shape
	col.position = Vector3(0, 0.375, 0)
	table.add_child(col)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4, 0.75, 1.2)
	mesh_node.mesh = mesh
	mesh_node.position = Vector3(0, 0.375, 0)
	mesh_node.material_override = _make_wood_material()
	table.add_child(mesh_node)
	return table

func _make_stun_fixture(style_value: int) -> StaticBody3D:
	var fixture_script = load("res://scripts/StunFixture.gd")
	var node := StaticBody3D.new()
	node.set_script(fixture_script)
	node.style = style_value
	return node

func _make_surface_zone(friction_mult: float, zone_size: Vector3, tint_color: Color) -> Area3D:
	var zone_script = load("res://scripts/SurfaceZone.gd")
	var zone := Area3D.new()
	zone.set_script(zone_script)
	zone.friction_mult = friction_mult
	zone.zone_size = zone_size
	zone.tint = tint_color
	return zone

## Floor 3 — Stairwell Chaos: no desks, dexterity floor with fall-through
## gaps between concrete landings, warning stripes, and stacked crates.
## Floor 3 — Stairwell Chaos: dexterity floor with fall-through gaps between
## concrete landings, warning stripes, and crates as obstacles.
func _theme_floor3_stairwell() -> void:
	var y := 12.0
	for slab in _floor3_landing_layout():
		var landing := StaticBody3D.new()
		landing.position = Vector3(slab["x"], y, slab["z"])
		add_child(landing)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(slab["w"], 0.2, slab["d"])
		col.shape = shape
		landing.add_child(col)
		var mesh_node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(slab["w"], 0.2, slab["d"])
		mesh_node.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.33, 0.36)
		mat.roughness = 0.85
		mesh_node.material_override = mat
		landing.add_child(mesh_node)
	# Warning stripes at the gap edges (visual only)
	for stripe_pos in _floor3_stripe_positions():
		var stripe := MeshInstance3D.new()
		var quad := BoxMesh.new()
		quad.size = Vector3(2.4, 0.02, 0.5)
		stripe.mesh = quad
		stripe.position = stripe_pos
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(1.0, 0.75, 0.1, 0.85)
		smat.emission_enabled = true
		smat.emission = Color(0.9, 0.6, 0.05)
		smat.emission_energy_multiplier = 0.5
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		stripe.material_override = smat
		add_child(stripe)
	# Crates as dexterity obstacles on the landings
	for crate_spec in [
		{"pos": Vector3(-10, y, 6), "rot": 0.3},
		{"pos": Vector3(9, y, -6), "rot": -0.5},
		{"pos": Vector3(0, y, -14), "rot": 0.2},
	]:
		var crate := _make_crate()
		crate.position = crate_spec["pos"]
		crate.rotation.y = crate_spec["rot"]
		add_child(crate)

func _floor3_landing_layout() -> Array[Dictionary]:
	# Perimeter ring walkway + cross-strips between elevator pads; the center
	# pockets are open holes — fall through and respawn at the floor 3 start.
	return [
		{"x": 0.0, "z": 17.5, "w": 40.0, "d": 5.0},
		{"x": 0.0, "z": -17.5, "w": 40.0, "d": 5.0},
		{"x": 17.5, "z": 0.0, "w": 5.0, "d": 40.0},
		{"x": -17.5, "z": 0.0, "w": 5.0, "d": 40.0},
		{"x": 12.0, "z": 14.0, "w": 8.0, "d": 8.0},
		{"x": -12.0, "z": 14.0, "w": 8.0, "d": 8.0},
		{"x": 0.0, "z": 14.0, "w": 16.0, "d": 3.0},
		{"x": 0.0, "z": 6.0, "w": 8.0, "d": 30.0},
	]

func _floor3_stripe_positions() -> Array[Vector3]:
	return [
		Vector3(0, 12.1, 15.0), Vector3(0, 12.1, -15.0),
		Vector3(15.0, 12.1, 0), Vector3(-15.0, 12.1, 0),
	]

func _make_crate() -> StaticBody3D:
	var crate := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 1.4, 1.4)
	col.shape = shape
	col.position = Vector3(0, 0.7, 0)
	crate.add_child(col)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 1.4, 1.4)
	mesh_node.mesh = mesh
	mesh_node.position = Vector3(0, 0.7, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.34, 0.2)
	mat.roughness = 0.9
	mesh_node.material_override = mat
	crate.add_child(mesh_node)
	return crate

## Floor 4 — Cafeteria + Parking Lot: ice-slick floor, round tables, spill
## stun puddles, then concrete lot behind the exit with painted lines and
## parked-car obstacles.
func _theme_floor4_cafeteria_and_lot() -> void:
	var y := 18.0
	# Ice-slick cafeteria floor (big slip zone)
	var ice := _make_surface_zone(0.16, Vector3(26, 2.0, 26), Color(0.7, 0.9, 1.0, 0.08))
	ice.position = Vector3(0, y + 0.15, 0)
	add_child(ice)
	# Round tables
	for table_pos in [Vector3(-9, y, -7), Vector3(9, y, -7), Vector3(-9, y, 7), Vector3(9, y, 7)]:
		var table := _make_round_table()
		table.position = table_pos
		add_child(table)
	# Spill puddles — stun fixtures
	for spill_pos in [Vector3(-4, y, 0), Vector3(4, y, 3), Vector3(0, y, -4)]:
		var spill := _make_stun_fixture(1)
		spill.position = spill_pos
		add_child(spill)
	# Parking lot grip zone behind the exit
	var lot := _make_surface_zone(1.4, Vector3(36, 2.0, 10), Color(0.5, 0.5, 0.55, 0.10))
	lot.position = Vector3(0, y + 0.15, 16)
	add_child(lot)
	# Painted parking lines (visual)
	for lx in [-16, -8, 0, 8, 16]:
		var line := MeshInstance3D.new()
		var line_mesh := BoxMesh.new()
		line_mesh.size = Vector3(0.25, 0.02, 6)
		line.mesh = line_mesh
		line.position = Vector3(lx, y + 0.12, 16)
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.9, 0.9, 0.85, 0.7)
		lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lmat.emission_enabled = true
		lmat.emission = Color(0.8, 0.8, 0.75)
		lmat.emission_energy_multiplier = 0.2
		line.material_override = lmat
		add_child(line)
	# Parked cars as obstacles
	for car_spec in [
		{"pos": Vector3(-12, y, 18), "rot": 0.0},
		{"pos": Vector3(4, y, 18), "rot": 0.0},
	]:
		var car := _make_parked_car()
		car.position = car_spec["pos"]
		car.rotation.y = car_spec["rot"]
		add_child(car)

func _make_round_table() -> StaticBody3D:
	var table := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.1
	shape.height = 0.75
	col.shape = shape
	col.position = Vector3(0, 0.375, 0)
	table.add_child(col)
	var top := MeshInstance3D.new()
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 1.15
	top_mesh.bottom_radius = 1.15
	top_mesh.height = 0.08
	top.mesh = top_mesh
	top.position = Vector3(0, 0.75, 0)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.55, 0.57, 0.6)
	tmat.roughness = 0.4
	top.material_override = tmat
	table.add_child(top)
	var leg := MeshInstance3D.new()
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.12
	leg_mesh.bottom_radius = 0.18
	leg_mesh.height = 0.72
	leg.mesh = leg_mesh
	leg.position = Vector3(0, 0.36, 0)
	leg.material_override = tmat
	table.add_child(leg)
	return table

func _make_parked_car() -> StaticBody3D:
	var car := StaticBody3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.12, 0.12)
	mat.roughness = 0.35
	mat.metallic = 0.4
	var body_col := CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(1.9, 0.9, 4.2)
	body_col.shape = body_shape
	body_col.position = Vector3(0, 0.55, 0)
	car.add_child(body_col)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.9, 0.9, 4.2)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.55, 0)
	body.material_override = mat
	car.add_child(body)
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.7, 0.7, 2.2)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 1.25, -0.2)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.15, 0.17, 0.2, 0.9)
	cmat.roughness = 0.2
	cmat.metallic = 0.6
	cabin.material_override = cmat
	car.add_child(cabin)
	for wheel_spec in [
		Vector3(-0.95, 0.35, 1.4), Vector3(0.95, 0.35, 1.4),
		Vector3(-0.95, 0.35, -1.4), Vector3(0.95, 0.35, -1.4),
	]:
		var wheel := MeshInstance3D.new()
		var wmesh := CylinderMesh.new()
		wmesh.top_radius = 0.35
		wmesh.bottom_radius = 0.35
		wmesh.height = 0.25
		wheel.mesh = wmesh
		wheel.rotation.z = PI / 2.0
		wheel.position = wheel_spec
		wheel.material_override = mat
		car.add_child(wheel)
	return car

# --- FLOOR/RAMP GUIDANCE ---
func _apply_player_modifiers() -> void:
	if not sp_modifiers or not local_player:
		return
	var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
	if RaceModifiersScript.is_active(RaceModifiersScript.Modifier.LOW_GRAVITY):
		local_player.gravity *= 0.6
	if RaceModifiersScript.is_active(RaceModifiersScript.Modifier.SLIPPERY):
		local_player.friction *= 0.3

# --- GHOST PACER (single-player) ---
func _maybe_spawn_ghost() -> void:
	# No ghost in multiplayer; respect the user's race/ghost setting (default on).
	var network_mod := get_node_or_null("/root/Network")
	if network_mod and network_mod.peer:
		return
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	if not config.get_value("race", "ghost_enabled", true):
		return
	var ghost_script = load("res://scripts/GhostRacer.gd")
	if ghost_script == null:
		return
	ghost_racer = Node3D.new()
	ghost_racer.set_script(ghost_script)
	# Course: start → each floor's far side → exit ring on floor 4
	var course: Array[Vector3] = [
		# Start in a neighboring lane so the translucent ghost does not occupy
		# the player's chair/camera focal point during the opening countdown.
		Vector3(-1.8, 1.0, 0),
		Vector3(10, 0.5, 8),
		Vector3(-8, 6.5, -6),
		Vector3(2, 12.5, 9),
		Vector3(-6, 18.5, 6),
		Vector3(0, 19.0, 14.5),
	]
	ghost_racer.setup(course, "GHOST", 75.0)
	add_child(ghost_racer)
	ghost_racer.ghost_finished.connect(_on_ghost_finished)

func _on_ghost_finished(ghost_name: String, ghost_time: float) -> void:
	if match_state == &"finished":
		return
	finish_order.append({
		"player_id": ghost_racer.get_instance_id(),
		"name": ghost_name,
		"time": ghost_time
	})
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("GHOST FINISHED — " + str(snappedf(ghost_time, 0.1)) + "s", 2.0)

func _build_floor(pos: Vector3, color: Color, floor_index: int = 0) -> void:
	# Floor 3 (index 2) is the Stairwell Chaos floor: its base slab is
	# REPLACED by concrete landings with real fall-through gaps, so the
	# uniform slab (mesh + collision) is skipped for that floor only.
	if floor_index == 2:
		_add_floor_number(pos, floor_index)
		_spawn_ceiling_lights(pos, floor_index)
		_build_floor_walls(pos, color, floor_index)
		return
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
	_build_floor_walls(pos, color, floor_index)

func _build_floor_walls(pos: Vector3, color: Color, floor_index: int) -> void:
	for i in range(4):
		var wall = StaticBody3D.new()
		wall.position = pos + Vector3([0, 20, 0, -20][i], 1.5, [20, 0, -20, 0][i])
		# CRITICAL: the E/W walls must be rotated 90° — the BoxShape/Mesh are
		# authored long-in-X (40x3x0.3); leaving E/W walls unrotated laid two
		# phantom 40m slabs ACROSS each floor's interior at z~0 (players and
		# the winnability probe wedged on them; found via collision dump).
		if i == 1 or i == 3:
			wall.rotation.y = PI / 2.0
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
	# Phase: textured carpet tiles (structural grid + per-tile wear) via
	# FloorMaterials; falls back to old noise-carpet if helper unavailable
	# (keeps standalone tests compiling).
	var helper = load("res://scripts/FloorMaterials.gd")
	if helper != null and helper.has_method("make"):
		return helper.make(base_color, floor_index)
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
	# Phase: textured office walls (grain + sheen bands + wainscot), cached
	# per floor in WallMaterials. Falls back to the old flat color if the
	# helper is unavailable (keeps standalone tests compiling).
	var helper = load("res://scripts/WallMaterials.gd")
	if helper != null and helper.has_method("make"):
		return helper.make(base_color, floor_index)
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

## Wood desks/tables share ONE cached material: building the 128px noise
## texture per desk cost ~25 noise generations per match and broke
## draw-call batching (unique material per mesh). Instance-scoped cache,
## so repeated scene instantiations never share freed textures.
func _make_wood_material() -> StandardMaterial3D:
	if _wood_mat and is_instance_valid(_wood_mat):
		return _wood_mat
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
	_wood_mat = mat
	return mat

func _spawn_ceiling_lights(floor_pos: Vector3, floor_index: int = 0) -> void:
	var light_group = Node3D.new()
	light_group.name = "CeilingLights_%s" % str(int(floor_pos.y))
	add_child(light_group)
	_register_floor_node(floor_index, light_group)
	_build_ceiling_grid(floor_pos, light_group)
	for x in [-12.0, 0.0, 12.0]:
		for z in [-12.0, 0.0, 12.0]:
			var light = OmniLight3D.new()
			light.position = floor_pos + Vector3(x, 3.0, z)
			light.light_color = Color(1.0, 0.92, 0.78)
			light.light_energy = 1.05
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
			# Flicker: a few fixtures buzz irregularly (Lethal Company vibe).
			if (x + z) == 0.0 or (x == 12.0 and z == -12.0):
				fixture.set_meta("flicker", true)

var _flicker_t := 0.0
var _flicker_fixtures: Array = []
func _process_flicker(delta: float) -> void:
	pass

## Irregular fluorescent buzz on flagged fixtures — cheap dread.
func _tick_light_flicker(delta: float) -> void:
	_flicker_t -= delta
	if _flicker_t > 0.0:
		return
	if _flicker_fixtures.is_empty():
		for f in find_children("*", "MeshInstance3D", true, false):
			if f.has_meta("flicker"):
				_flicker_fixtures.append(f)
		if _flicker_fixtures.is_empty():
			return
	_flicker_t = randf_range(1.2, 4.0)
	var target = _flicker_fixtures[randi() % _flicker_fixtures.size()]
	if not is_instance_valid(target):
		return
	var mat: StandardMaterial3D = target.material_override
	var tw := create_tween()
	tw.tween_callback(func(): mat.emission_energy_multiplier = 0.15)
	tw.tween_interval(randf_range(0.04, 0.12))
	tw.tween_callback(func(): mat.emission_energy_multiplier = 1.4)
	tw.tween_interval(randf_range(0.03, 0.09))
	tw.tween_callback(func(): mat.emission_energy_multiplier = 0.3)
	tw.tween_interval(0.05)
	tw.tween_callback(func(): mat.emission_energy_multiplier = 1.4)

## Drop-ceiling grid: dark T-bar panels between light fixtures.
func _build_ceiling_grid(floor_pos: Vector3, parent: Node3D) -> void:
	var grid_mat = StandardMaterial3D.new()
	grid_mat.albedo_color = Color(0.09, 0.09, 0.11)
	grid_mat.roughness = 0.95
	for x in [-20.0, -8.0, 8.0, 20.0]:
		var bar_x = MeshInstance3D.new()
		var bm_x = BoxMesh.new()
		bm_x.size = Vector3(0.25, 0.08, 40)
		bar_x.mesh = bm_x
		bar_x.material_override = grid_mat
		bar_x.position = floor_pos + Vector3(x, 2.97, 0)
		parent.add_child(bar_x)
	for z in [-20.0, -8.0, 8.0, 20.0]:
		var bar_z = MeshInstance3D.new()
		var bm_z = BoxMesh.new()
		bm_z.size = Vector3(40, 0.08, 0.25)
		bar_z.mesh = bm_z
		bar_z.material_override = grid_mat
		bar_z.position = floor_pos + Vector3(0, 2.97, z)
		parent.add_child(bar_z)

## Phase 7C: track per-floor visual nodes for distance culling. StaticBody3D
## collision is NEVER hidden — hidden bodies keep colliding in Godot, but we
## register only visual/decor groups so gameplay is untouched either way.
func _register_floor_node(floor_index: int, node: Node) -> void:
	if not _floor_groups.has(floor_index):
		_floor_groups[floor_index] = [] as Array[Node]
	(_floor_groups[floor_index] as Array[Node]).append(node)

func _update_floor_culling() -> void:
	if local_player == null or not is_instance_valid(local_player):
		return
	var current := _current_floor_index()
	for floor_index in _floor_groups.keys():
		var distance := absi(floor_index - current)
		# Far floors: hide whole visual groups (fixtures included).
		var should_hide := distance >= CULL_HIDE_DISTANCE_FLOORS
		if should_hide != bool(_culled_floors.get(floor_index, false)):
			_culled_floors[floor_index] = should_hide
			for node in _floor_groups[floor_index]:
				if is_instance_valid(node):
					(node as Node).visible = not should_hide
		# Adjacent floor: drop its OmniLights but keep emissive fixtures.
		var should_drop_lights := distance >= CULL_LIGHT_DISTANCE_FLOORS and not should_hide
		if should_drop_lights:
			_set_floor_lights_enabled(floor_index, false)
		else:
			_set_floor_lights_enabled(floor_index, true)

func _set_floor_lights_enabled(floor_index: int, enabled: bool) -> void:
	if not _floor_groups.has(floor_index):
		return
	for node in _floor_groups[floor_index]:
		if not is_instance_valid(node):
			continue
		for light in (node as Node).find_children("*", "OmniLight3D", true, false):
			if (light as OmniLight3D).visible == enabled:
				continue
			(light as OmniLight3D).visible = enabled

func _setup_environment() -> void:
	var world = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not world or not world.environment:
		return
	var env = world.environment
	# Moody-but-readable office night: slightly cooler and dimmer than the
	# old flat-bright wash so emissive fixtures and warm pools of light pop,
	# while ambient stays high enough that GL Compatibility keeps chairs,
	# hazards and routes readable.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.9)
	env.ambient_light_energy = 0.82
	var key_light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if key_light:
		key_light.light_energy = 1.05
		key_light.light_color = Color(1.0, 0.93, 0.82)
	# Fog+glow default OFF here (Settings quality gate decides at runtime;
	# LOW profile never pays for them), but configured when enabled.
	env.fog_enabled = false
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 18.0
	env.fog_depth_end = 60.0
	env.fog_light_color = Color(0.16, 0.17, 0.24)
	env.fog_density = 0.35
	env.glow_enabled = false
	env.glow_strength = 0.9
	env.glow_hdr_threshold = 1.1
	# Filmic tonemap: free contrast/rollover improvement that keeps emissive
	# fixtures from clipping while deepening shadows — the "office at night"
	# grade without any post-process pass cost.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	# Vignette: cheap post-process edge darkening that focuses the read on
	# the arena center; gated by quality (LOW keeps it off for mobile GPUs).
	# NOTE: `vignette_enabled` doesn't exist on Environment in GL Compatibility
	# (movie-maker/compat renderer) — guard the property's existence.
	var vignette := GradientTexture1D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(0.42, 0.44, 0.52, 1))
	vignette.gradient = grad
	if _quality_allows_post() and "vignette_enabled" in env:
		env.vignette_enabled = true
		env.vignette = vignette
	_spawn_dust_motes()

func _quality_allows_post() -> bool:
	var cfg := ConfigFile.new()
	var q := 1
	if cfg.load("user://settings.cfg") == OK:
		q = int(cfg.get_value("graphics", "quality", 1))
	return q > 0

## Ambient dust motes drifting through light pools — two cheap quads-per-
## particle emitters per floor group area are skipped at LOW quality.
func _spawn_dust_motes() -> void:
	if not _quality_allows_post():
		return
	for floor_index in range(4):
		var motes := GPUParticles3D.new()
		motes.name = "DustMotes_F%d" % floor_index
		var mat_res := ParticleProcessMaterial.new()
		motes.amount = 40
		motes.lifetime = 7.0
		motes.preprocess = 6.0     # start already-spread, no visible burst-in
		motes.position = Vector3(0, float(floor_index) * 6.0 + 2.2, 0)
		var mesh_mat := StandardMaterial3D.new()
		mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_mat.albedo_color = Color(1.0, 0.98, 0.9, 0.45)
		mesh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat_res.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat_res.emission_box_extents = Vector3(17, 1.4, 17)
		mat_res.direction = Vector3(0.15, -1, 0)
		mat_res.spread = 30.0
		mat_res.gravity = Vector3.ZERO
		mat_res.initial_velocity_min = 0.05
		mat_res.initial_velocity_max = 0.22
		mat_res.scale_min = 0.02
		mat_res.scale_max = 0.06
		# GL Compatibility quirk: QuadMesh particles ignore process-material
		# scale unless the mesh itself is tiny — a 1m quad renders as a
		# window-sized billboard (the "floating gray cards" bug).
		var mote_mesh := QuadMesh.new()
		mote_mesh.size = Vector2(0.04, 0.04)
		mote_mesh.material = mesh_mat
		motes.draw_pass_1 = mote_mesh
		motes.process_material = mat_res
		add_child(motes)

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
			# PERFECT-LANDING BONUS: enter the pad within 1m of its center
			# and you keep your momentum with a 15% speed kick for 1s —
			# rewards skilled elevator approaches. Wide entries just go up.
			var lateral := Vector2(
				body.global_position.x - from_pos.x,
				body.global_position.z - from_pos.z).length()
			# Teleport to destination
			body.global_position = to_pos + Vector3(0, 1.0, 0)
			body.velocity = Vector3.ZERO
			# Advance the respawn checkpoint to this floor's entry point
			if "respawn_point" in body:
				body.respawn_point = to_pos + Vector3(0, 1.0, 0)
				if body.has_method("_update_respawn_facing"):
					body._update_respawn_facing()
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
			# Landing bonus (after teleport so the launch carries it)
			if lateral <= 1.0 and body.has_method("_start_boost"):
				body._start_boost(0.55, 1.25)  # gentle 1s kick, not a full boost
				if a11y:
					a11y.caption("PERFECT LANDING — SPEED BOOST!", 1.2)
				if impact_fx and impact_fx.has_method("confetti"):
					impact_fx.confetti(self, body.global_position)
	)

func _build_ramp(from_pos: Vector3, to_pos: Vector3) -> void:
	# Legacy function kept for compatibility — now delegates to elevator
	_build_elevator(from_pos, to_pos, 0)

func _spawn_obstacles() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 1337  # Fixed seed for consistent layout

	# Floor 3 (y=12) is the gapped stairwell — desks would float over holes
	var floor_choices := [0, 6, 18]
	for i in range(15):
		var desk = _make_desk()
		var floor_y = floor_choices[rng.randi() % floor_choices.size()]
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
	var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
	if sp_modifiers and RaceModifiersScript.is_active(RaceModifiersScript.Modifier.NO_COFFEE):
		return  # No coffee run: skip all power-up spawns
	var rng = RandomNumberGenerator.new()
	rng.seed = 999
	var PowerUp = load("res://scripts/PowerUpVisual.gd")

	for i in range(8):
		var pu = PowerUp.create(PowerUp.pick_weighted(rng))
		pu.sync_name = "PU_%d" % i
		var floor_y = [0.5, 6.5, 12.5, 18.5][rng.randi() % 4]
		pu.position = Vector3(
			rng.randf_range(-12, 12),
			floor_y,
			rng.randf_range(-12, 12)
		)
		add_child(pu)

# --- PLAYER SPAWN ---

## Deterministic start slots: two staggered rows behind the origin line.
## Slot index derives from peer id ordering, so every machine assigns the
## SAME slot to the same peer without extra syncing.
const START_SLOTS := [
	Vector3(0, 1.0, 0), Vector3(-2.5, 1.0, 2.0), Vector3(2.5, 1.0, 2.0),
	Vector3(-5.0, 1.0, 4.0), Vector3(0.0, 1.0, 4.0), Vector3(5.0, 1.0, 4.0),
	Vector3(-7.5, 1.0, 6.0), Vector3(7.5, 1.0, 6.0),
]

func _slot_for_peer(peer_id: int) -> Vector3:
	var network = get_node_or_null("/root/Network")
	var ids: Array = []
	if network and not network.connected_players.is_empty():
		ids = network.connected_players.keys()
	else:
		ids = [1]
	ids.sort_custom(func(a, b): return int(a) < int(b))
	var idx := ids.find(peer_id)
	if idx < 0:
		idx = 0
	return START_SLOTS[idx % START_SLOTS.size()]

func _spawn_player() -> void:
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if not player_scene:
		return
	local_player = player_scene.instantiate()
	local_player.position = _slot_for_peer(_own_peer_id())
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		local_player.player_display_name = gm.player_name
		local_player.player_color = gm.player_color
	add_child(local_player)
	# Phase 7A: bind touch controls to the now-existing local chair so the
	# BOOST ring can mirror its cooldown state
	if mobile_controls and mobile_controls.has_method("bind_local_chair"):
		mobile_controls.bind_local_chair(local_player)
	# Phase 4A: floor 1 spawn is the initial respawn checkpoint
	if "respawn_point" in local_player:
		local_player.respawn_point = local_player.position
	players.append({"id": 1, "name": local_player.player_display_name})

# --- GAME FLOW ---

func _start_countdown() -> void:
	match_state = &"countdown"
	timer = countdown_seconds
	if local_player:
		local_player.set_can_move(false)
	# Controls recap at the start of EVERY round (fresh match, rematch,
	# or late-join). Mirrored to captions via Accessibility.
	var controls_overlay = _controls_overlay()
	if controls_overlay:
		controls_overlay.show_for(7.0)
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
	var input_prefs = load("res://scripts/InputPrefs.gd")
	if input_prefs:
		input_prefs.reset_yaw()
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("GO!", 1.0)
	_announcer().say("misc", _const_lines("START_LINES"), true)
	if local_player:
		local_player.set_can_move(true)
	_spawn_traps()
	if hazards and hazards.has_method("start_race"):
		hazards.start_race()

## Lazily mount the controls overlay (deduped, session-lifetime).
func _controls_overlay() -> Node:
	var script = load("res://scripts/ControlsOverlay.gd")
	if script:
		return script.mount(self)
	return null

## Lazily mount the race announcer (a11y caption hype).
func _announcer() -> Node:
	if announcer == null or not is_instance_valid(announcer):
		var AnnouncerScript = load("res://scripts/Announcer.gd")
		announcer = AnnouncerScript.mount(self)
	return announcer

## Fetch a String array constant off Announcer.gd by name (avoids needing
## the class_name global at parse time in this standalone-checked file).
func _const_lines(const_name: String) -> Array:
	var AnnouncerScript = load("res://scripts/Announcer.gd")
	return AnnouncerScript.get(const_name)

func _spawn_traps() -> void:
	var manager = get_node_or_null("/root/GameManager")
	var network = get_node_or_null("/root/Network")

	var trap_scene = load("res://scenes/objects/SabotageTrap.tscn")
	if not trap_scene:
		return

	var trap_count := 4
	var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
	if sp_modifiers and RaceModifiersScript.is_active(RaceModifiersScript.Modifier.DOUBLE_TRAPS):
		trap_count = 8

	# Floor 3 traps would float over stairwell gaps — use floors 1/2/4 only.
	# Deterministic across peers: seeded RNG, type derived from position so
	# every machine spawns the identical world (Phase 5 determinism).
	var trap_floors := [0.5, 6.5, 18.5]
	var trap_rng := RandomNumberGenerator.new()
	trap_rng.seed = 4242
	for i in range(trap_count):
		var trap = trap_scene.instantiate()
		var floor_y = trap_floors[i % trap_floors.size()]
		trap.position = Vector3(
			trap_rng.randf_range(-15, 15),
			floor_y,
			trap_rng.randf_range(-15, 15)
		)
		# Position-derived type keeps all peers in sync without an RPC
		if trap.has_method("_set_forced_type"):
			var type_roll: int = absi(int(trap.position.x * 13.0 + trap.position.z * 7.0)) % 3
			trap._set_forced_type(["water", "banana", "stapler"][type_roll])
		if trap.has_method("_set_owner"):
			trap._set_owner(network.multiplayer_peer.get_unique_id() if network and network.multiplayer_peer else 1)
		traps_placed += 1
		add_child(trap)

func _update_timer_display() -> void:
	var remaining := maxf(time_limit - timer, 0.0)
	var timer_text := "%d:%02d" % [floori(remaining / 60.0), int(remaining) % 60]
	if timer_label:
		timer_label.text = timer_text
	if hud_ext and is_instance_valid(hud_ext) and hud_ext.has_method("set_timer_text"):
		hud_ext.set_timer_text(timer_text)

func _update_hud() -> void:
	if hud_ext == null or not is_instance_valid(hud_ext):
		return
	if local_player and is_instance_valid(local_player):
		var speed = Vector2(local_player.velocity.x, local_player.velocity.z).length()
		hud_ext.set_speed(speed, local_player.max_speed)
		hud_ext.set_boost(
			local_player.boost_cd_timer,
			local_player.boost_duration,
			local_player.is_boosting,
			local_player.boost_cooldown
		)
		hud_ext.set_item(local_player.item_kind, local_player.item_charges)
		var floor_idx := _current_floor_index()
		hud_ext.set_player_position(local_player.global_position, floor_idx)
		hud_ext.set_floor(floor_idx + 1)

func _on_player_reached_exit(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	var player_id = body.get_instance_id()
	for entry in finish_order:
		if entry.player_id == player_id:
			return
	finish_order.append({
		"player_id": player_id,
		"name": body.player_display_name if "player_display_name" in body else "Unknown",
		"time": timer
	})
	if body == local_player:
		if local_player and local_player.has_method("trigger_mobile_action"):
			local_player.trigger_mobile_action("victory")
		var a11y = load("res://scripts/Accessibility.gd")
		if a11y:
			a11y.caption("FINISH!", 2.0)
		_announcer().say("misc", _const_lines("WIN_LINES"), true)
		_end_race()

func _end_race() -> void:
	if match_state == &"finished":
		return
	match_state = &"finished"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if hazards and hazards.has_method("stop"):
		hazards.stop()
	if local_player:
		local_player.set_can_move(false)

	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		var won := false
		if finish_order.size() > 0 and is_instance_valid(local_player):
			won = finish_order[0].player_id == local_player.get_instance_id()
		var prev_best: float = stats.top_speed_ever
		var prev_races: int = stats.total_races
		stats.record_race(won, top_speed, 0)
		new_personal_best = top_speed > prev_best and prev_races > 0

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
				if new_personal_best:
					stats_label.text += "\n★ NEW TOP-SPEED RECORD ★"
			# Show active modifiers on the results screen for clarity
			if sp_modifiers:
				var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
				var names: Array[String] = []
				for mod in RaceModifiersScript.selected:
					names.append(RaceModifiersScript.LABELS[mod].split(" — ")[0])
				if names.size() > 0 and stats_label:
					stats_label.text += "\nMODIFIERS: " + ", ".join(names)

	var impact = load("res://scripts/ImpactFX.gd")
	if impact and impact.has_method("confetti_burst"):
		impact.confetti_burst(local_player.global_position if local_player else Vector3.ZERO)
	if new_personal_best:
		var audio_pb = get_node_or_null("/root/AudioManager")
		if audio_pb:
			audio_pb.play_sfx("victory", 1.0)
		var pb_a11y = load("res://scripts/Accessibility.gd")
		if pb_a11y:
			pb_a11y.caption("NEW TOP-SPEED RECORD!", 1.5)

func _on_rematch() -> void:
	get_tree().reload_current_scene()

func _on_back_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _exit_tree() -> void:
	# Safety net: rematch reloads the scene without _on_back_to_menu.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	# Mouse-look camera motion (toggle+sensitivity inside InputPrefs).
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var input_prefs = load("res://scripts/InputPrefs.gd")
		if input_prefs:
			input_prefs.apply_mouse_motion(event)
			get_viewport().set_input_as_handled()
			return
	# Re-center the camera behind the chair mid-race (R on keyboard,
	# Y/Triangle on pad — the recenter_camera action, remappable).
	if event.is_action_pressed("recenter_camera") and match_state == &"racing":
		var input_prefs = load("res://scripts/InputPrefs.gd")
		if input_prefs:
			input_prefs.reset_yaw()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and match_state != &"finished":
		var network = get_node_or_null("/root/Network")
		if network and network.peer:
			return
		var pause_menu = load("res://scripts/PauseMenu.gd")
		var pause_layer = pause_menu.create(self, _on_back_to_menu)
		if pause_layer and pause_layer.has_signal("resumed"):
			# Re-capture the cursor when the player resumes into the race.
			pause_layer.resumed.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _setup_hud() -> void:
	hud = $UI
	if hud:
		# Real in-match HUD: speed bar, boost state, item charges, minimap.
		var hud_script = load("res://scripts/HUD.gd")
		if hud_script:
			hud_ext = CanvasLayer.new()
			hud_ext.set_script(hud_script)
			hud_ext.layer = 10
			add_child(hud_ext)
			# HUD.gd owns the race timer. Keeping the legacy scene label visible
			# draws two timers on top of each other.
			if timer_label:
				timer_label.visible = false
		# Caption overlay for audio-cue subtitles (no-op when disabled)
		var overlay_script = load("res://scripts/SubtitleOverlay.gd")
		if overlay_script and overlay_script.has_method("mount"):
			overlay_script.mount(hud)
	# Phase 5B: chat overlay (dormant unless a network peer exists)
	var network_chat = get_node_or_null("/root/Network")
	if network_chat and network_chat.peer:
		var chat_script = load("res://scripts/ChatOverlay.gd")
		if chat_script:
			var chat = CanvasLayer.new()
			chat.set_script(chat_script)
			chat.name = "ChatOverlay"
			add_child(chat)
	# Touch controls (mobile platforms, or desktop when FE_TOUCH=1 preview)
	var mc_script = load("res://scripts/MobileControls.gd")
	if mc_script and mc_script.has_method("mount_for_mode"):
		# mount_for_mode owns the direct chair signal routing for every mode.
		mobile_controls = mc_script.mount_for_mode(self, local_player)

func _on_mobile_move(value: Vector2) -> void:
	if local_player and is_instance_valid(local_player) and local_player.has_method("set_mobile_input"):
		local_player.set_mobile_input(value)

func _on_mobile_action(action_name: StringName) -> void:
	if local_player and is_instance_valid(local_player) and local_player.has_method("trigger_mobile_action"):
		local_player.trigger_mobile_action(action_name)

## Derive the current floor (0-based) from the local player's Y position.
func _current_floor_index() -> int:
	if local_player and is_instance_valid(local_player):
		return clampi(int(local_player.global_position.y / 6.0), 0, 3)
	return 0
