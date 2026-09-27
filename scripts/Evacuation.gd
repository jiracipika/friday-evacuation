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
var skin_unlock_names: Array[String] = []  # Phase 8A: unlocks earned this race
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
	_style_results_panel()
	# UI SLICE: portrait in-match hint (rotate your phone / tap to continue).
	# Desktop-wide viewports never see it; headless tests never render it.
	load("res://scripts/PortraitHint.gd").mount(self)
	# Debug virtual pad: direct-scene launches bypass Main.gd's mount, so
	# ensure the node exists here too (deduped by name on the root).
	if "virtual-pad" in OS.get_cmdline_user_args() or OS.get_environment("FE_VIRTUAL_PAD") == "1":
		if not get_tree().root.has_node("VirtualPad"):
			var vpad = load("res://scripts/VirtualPad.gd")
			if vpad:
				var vpad_node: Node = vpad.new()
				vpad_node.name = "VirtualPad"
				get_tree().root.add_child.call_deferred(vpad_node)
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
	# Phase 8B: single-player game-speed knob (no-op in test mode; get_time_scale
	# itself returns 1.0 whenever a network peer is active).
	load("res://scripts/Accessibility.gd").apply_time_scale()
	# Blocking pre-game briefing: tree PAUSED until the player agrees.
	# Countdown starts after dismissal (timer frozen while paused).
	load("res://scripts/PreMatchModal.gd").mount(self, "EVACUATION", [
		"DRIVE — stick/WASD steers the chair, coffee = BOOST.",
		"CLIMB — ride the glowing blue elevators up every floor.",
		"ESCAPE — reach the green FINISH beam in the parking lot.",
	])
	_start_countdown()
	_setup_hud()
	camera_base_fov = camera.fov if camera else 70.0
	if local_player and local_player.has_signal("shake_requested"):
		local_player.shake_requested.connect(_request_camera_shake)
	if local_player and local_player.has_signal("stunned"):
		local_player.stunned.connect(func(): _announcer().say("trap", _const_lines("TRAP_HIT_LINES")))
		# Results-panel stat was always 0: the counter existed but nothing
		# incremented it. The stun signal IS the trap/roomba/debris hit.
		local_player.stunned.connect(func(): traps_hit += 1)
	_connect_race_triggers()
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

## Wire race-level triggers: ExitZone finish + results-panel buttons.
## NOTE: this code lives AFTER _on_host_lost by necessity — in the shipped
## code it was orphaned TOP-LEVEL statements after a blank line (never
## executed), so the finish line never fired for real chairs in real races
## and Rematch/Menu buttons stayed unwired. The checkpoint bot test caught
## it: the only finish_order writers were the ghost and _end_race.
func _connect_race_triggers() -> void:
	var exit_zone = get_node_or_null("Arena/ExitZone")
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
	# Full LAN avatar identity must be pinned BEFORE add_child: PlayerChair
	# builds its procedural chassis + rider in _ready(). Remote chairs must
	# not read this machine's GameManager selection.
	remote.use_global_character = false
	remote.use_global_skin = false
	if network_node and network_node.has_method("get_player_character"):
		remote.character_id = network_node.get_player_character(peer_id)
	if network_node and network_node.has_method("get_player_skin"):
		remote.skin_id = network_node.get_player_skin(peer_id)
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
	# GRAPHICS PASS: structural columns at ±10 — real collision, placed on
	# lane boundaries verified against gates/landings (see OfficeDressing).
	_spawn_columns()
	# Shared non-colliding architectural features follow existing floor culling.
	var architecture = load("res://scripts/OfficeArchitecture.gd")
	for story in range(4):
		var landmark: Node3D = architecture.build(story)
		landmark.position.y = story * 6.0
		add_child(landmark)
		_register_floor_node(story, landmark)

	# Elevator pads connect floors. Each pad is an Area3D trigger zone that
	# smoothly lifts the player to the next floor when entered.
	# This avoids Godot 4 CharacterBody3D slope/stair physics issues entirely.
	_build_elevator(Vector3(12, 0.5, 14), Vector3(12, 6.5, -2), 1)   # Floor 1 → 2
	_build_elevator(Vector3(-12, 6.5, -2), Vector3(-12, 12.5, 14), 2) # Floor 2 → 3
	_build_elevator(Vector3(12, 12.5, 14), Vector3(12, 18.5, -2), 3)  # Floor 3 → 4

	_spawn_obstacles()
	_spawn_powerups()
	_add_exit_marker()
	# GRAPHICS PASS: soft contact shadows under grounded props — must run
	# AFTER obstacles/dressing exist so it reads real footprints (GL
	# Compatibility has no SSAO; discs are cheap unshaded quads).
	_spawn_floor_blob_shadows()

# --- PHASE 4A THEMED FLOORS ---

## Floor 1 — Cubicle Farm: partition grid with a central corridor, plants.
## PHASE 4: CUBICLE_MAZE layout narrows the corridor (gap=1 skips one
## extra column, making lanes tight); OPEN_PLAN keeps the shipped gap.
func _theme_floor1_cubicles() -> void:
	var LevelLayouts = load("res://scripts/LevelLayouts.gd")
	var corridor_gap := 0
	if LevelLayouts:
		corridor_gap = int(LevelLayouts.current_layout()["f1_corridor_gap"])
	var partition_mat := StandardMaterial3D.new()
	partition_mat.albedo_color = Color(0.23, 0.29, 0.35)  # gray-blue #3a4a5a-ish
	partition_mat.roughness = 0.9
	for gx in range(-2, 3):
		for gz in range(-2, 3):
			if gx >= -corridor_gap and gx <= corridor_gap and gz >= -1 and gz <= 1:
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

	# Dusk + toybox: Blender-authored potted plant replaces the sphere-blob
	# stand-in (collision above is untouched — model is dressing only).
	var BlenderProps: GDScript = load("res://scripts/BlenderProps.gd")
	if BlenderProps and BlenderProps.spawn(plant, BlenderProps.potted_plant(), Vector3.ZERO, 0.0) != null:
		return plant

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
	# PHASE 4: layout decides table count/placement (CUBICLE_MAZE: none).
	var LevelLayouts = load("res://scripts/LevelLayouts.gd")
	var table_x: Array = [-6.0, 6.0]
	if LevelLayouts:
		table_x = LevelLayouts.current_layout()["f2_tables"]
	for tx in table_x:
		var table := _make_conference_table()
		table.position = Vector3(tx, y, 0)
		add_child(table)
	# Water coolers — permanent stun fixtures (roadmap 4A)
	for cooler_pos in [Vector3(-12, y, 10), Vector3(12, y, 10), Vector3(0, y, -12)]:
		var cooler := _make_stun_fixture(0)  # WATER_COOLER
		cooler.position = cooler_pos
		add_child(cooler)
	# Dusk + toybox: Blender vending machines as warm-glow landmarks in the
	# open-plan corners (decorative, non-colliding — chairs pass freely).
	var BlenderProps: GDScript = load("res://scripts/BlenderProps.gd")
	for vm_pos in [Vector3(-17, y, -17), Vector3(17, y, 17)]:
		BlenderProps.spawn(self, BlenderProps.vending_machine(), vm_pos, PI * 0.25)
	# World-density pass: potted plants flank the opposite corners, reading
	# against the dusk window bands (non-colliding — chairs pass freely).
	for plant_pos in [Vector3(-17, y, 17), Vector3(17, y, -17)]:
		BlenderProps.spawn(self, BlenderProps.potted_plant(), plant_pos, PI * 0.25)
	# Wall clock pinned at 5:00 on the north wall — the whole game's reason
	# to race, readable from the conference tables.
	BlenderProps.spawn(self, BlenderProps.wall_clock(), Vector3(0, y + 3.6, -19.7), 0.0)
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
	# World-density pass: cardboard stacks on the perimeter walkways, kept
	# inside the landing rects (x within 40x5 strips => |z| in [15.5,19.5])
	# and clear of the stripe/elevator sightlines. Non-colliding dressing.
	var BlenderProps: GDScript = load("res://scripts/BlenderProps.gd")
	if BlenderProps:
		for stack_spec in [
			{"pos": Vector3(-14, y, 17.6), "rot": 0.3},
			{"pos": Vector3(10, y, -17.6), "rot": -0.25},
			{"pos": Vector3(17.6, y, -8), "rot": 1.35},
		]:
			BlenderProps.spawn(self, BlenderProps.box_stack(), stack_spec["pos"], stack_spec["rot"])
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
	mesh_node.position = Vector3(0, 0.7, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.34, 0.2)
	mat.roughness = 0.9
	mesh_node.material_override = mat
	# Dusk + toybox: prefer the Blender crate (lid/strap/tape silhouette);
	# the collision body above is untouched either way.
	var BlenderProps: GDScript = load("res://scripts/BlenderProps.gd")
	if not (BlenderProps and BlenderProps.spawn(crate, BlenderProps.crate(), Vector3.ZERO, 0.0) != null):
		mesh_node.mesh = mesh
		crate.add_child(mesh_node)
	return crate

## Floor 4 — Cafeteria + Parking Lot: ice-slick floor, round tables, spill
## stun puddles, then concrete lot behind the exit with painted lines and
## parked-car obstacles.
func _theme_floor4_cafeteria_and_lot() -> void:
	var y := 18.0
	# PHASE 4: layout decides ice coverage (EXECUTIVE: nearly whole floor).
	var LevelLayouts = load("res://scripts/LevelLayouts.gd")
	var ice_size := 26.0
	if LevelLayouts:
		ice_size = float(LevelLayouts.current_layout()["f4_ice_size"])
	# Ice-slick cafeteria floor (big slip zone)
	var ice := _make_surface_zone(0.16, Vector3(ice_size, 2.0, ice_size), Color(0.7, 0.9, 1.0, 0.08))
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
	# World-density pass (dressing parity with floor 1): corner plants
	# against the dusk bands, printers as cafeteria sideboard clutter,
	# and cardboard stacks flanking the lot entrance. All non-colliding.
	var blender: GDScript = load("res://scripts/BlenderProps.gd")
	if blender:
		for plant_pos in [Vector3(-13.5, y, -13.5), Vector3(13.5, y, -13.5)]:
			blender.spawn(self, blender.potted_plant(), plant_pos, PI * 0.25)
		for printer_pos in [Vector3(-9, y, -9.4), Vector3(9, y, 9.4)]:
			blender.spawn(self, blender.desk_printer(), printer_pos, PI)
		for stack_spec in [
			{"pos": Vector3(-6, y, 12), "rot": 0.15},
			{"pos": Vector3(6, y, 12), "rot": -0.2},
		]:
			blender.spawn(self, blender.box_stack(), stack_spec["pos"], stack_spec["rot"])

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
	# Phase 2: brushed-metal break-room table (shared prop material).
	var prop_mats = load("res://scripts/PropMaterials.gd")
	var tmat: StandardMaterial3D = null
	if prop_mats and prop_mats.has_method("brushed_metal"):
		tmat = prop_mats.brushed_metal()
	if tmat == null:
		tmat = StandardMaterial3D.new()
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
	# GRAPHICS PASS: stylized car paint — rich clearcoat-style red with a
	# long shared highlight (roughness 0.18, faint metalness). Wheels get
	# their own rubber material instead of inheriting body paint.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.11, 0.10)
	mat.roughness = 0.18
	mat.metallic = 0.25
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
	cmat.albedo_color = Color(0.08, 0.09, 0.12)
	cmat.roughness = 0.12
	cmat.metallic = 0.7
	cabin.material_override = cmat
	car.add_child(cabin)
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.05, 0.05, 0.06)
	wheel_mat.roughness = 0.9
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
		wheel.material_override = wheel_mat
		car.add_child(wheel)
	return car

# --- GRAPHICS PASS: columns / dressing / contact shadows -------------------

## Structural columns. Solid floors get them at (±10, ±10) — outside the
## center corridor (|x|<5), clear of elevator pads (12,±14 / -12,±14), and
## clear of every checkpoint waypoint. Floor 3 (gapped stairwell) only has
## landing at the perimeter ring + cross arms, so its columns sit at the
## ring corners (±17.5, ±17.5), which are solid in every landing rect.
func _spawn_columns() -> void:
	var Dressing = load("res://scripts/OfficeDressing.gd")
	if not Dressing:
		return
	for floor_index in 4:
		var y := float(floor_index) * 6.0
		var spots: Array[Vector3] = []
		if floor_index == 2:
			# Floor 3 (stairwell): only the perimeter ring + cross arms are
			# solid — columns live at the ring corners where landing is
			# guaranteed ({x:±17.5,z:0,w:5,d:40} and {x:0,z:±17.5,w:40,d:5}).
			spots = [
				Vector3(17.5, y, -17.5), Vector3(-17.5, y, -17.5),
				Vector3(17.5, y, 17.5), Vector3(-17.5, y, 17.5),
			]
		else:
			spots = [
				Vector3(10, y, 10), Vector3(-10, y, 10),
				Vector3(10, y, -10), Vector3(-10, y, -10),
			]
		for spot in spots:
			var col: StaticBody3D = Dressing.column()
			col.position = spot
			# Register with the floor group so culling hides it wholesale.
			_register_floor_node(floor_index, col)
			add_child(col)

## Contact-shadow discs under grounded props, grouped by floor for culling.
## Reads live StaticBody3D footprints (desks/tables/crates/plants/cars/
## coolers) — dressing and future props stay in sync automatically.
func _spawn_floor_blob_shadows() -> void:
	var Dressing = load("res://scripts/OfficeDressing.gd")
	if not Dressing:
		return
	var floors: Dictionary = {}  # floor_index -> Array[Transform3D footprint]
	for sb in get_children():
		if not (sb is StaticBody3D):
			continue
		var col: CollisionShape3D = null
		for child in (sb as StaticBody3D).get_children():
			if child is CollisionShape3D:
				col = child
				break
		if col == null or col.shape == null:
			continue
		var shape := col.shape
		var radius := 0.0
		if shape is BoxShape3D:
			var b := shape as BoxShape3D
			# REVIEW FIX: skip cubicle partitions (5.4m long) — their blob
			# would be a 6.7m dark streak across the floor. Only props with
			# a compact footprint get contact shadows.
			if b.size.x > 4.0:
				continue
			radius = max(b.size.x, b.size.z) * 0.62
		elif shape is CylinderShape3D:
			radius = (shape as CylinderShape3D).radius * 1.25
		elif shape is SphereShape3D:
			radius = (shape as SphereShape3D).radius * 1.25
		elif shape is CapsuleShape3D:
			radius = (shape as CapsuleShape3D).radius * 1.3
		else:
			continue
		if radius < 0.4 or radius > 3.6:
			continue  # skip floors/walls themselves
		var pos: Vector3 = sb.global_position + col.position
		var floor_index := clampi(int(round(pos.y / 6.0)), 0, 3)
		if not floors.has(floor_index):
			floors[floor_index] = [] as Array[Node3D]
		var blob: MeshInstance3D = Dressing.blob_shadow(radius * 2.0, 0.45)
		# REVIEW FIX: discs were at +0.025 — INSIDE the 0.2-thick floor slab
		# (top at +0.1), i.e. never rendered. +0.115 clears the slab and
		# stays under the surface-zone tint sheets.
		blob.position = Vector3(pos.x, float(floor_index) * 6.0 + 0.115, pos.z)
		(floors[floor_index] as Array).append(blob)
	for floor_index in floors.keys():
		var group := Node3D.new()
		group.name = "BlobShadows_F%d" % int(floor_index)
		add_child(group)
		for blob in floors[floor_index]:
			group.add_child(blob)
		_register_floor_node(int(floor_index), group)

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
	# GRAPHICS PASS: walls now span the FULL 6m floor gap (3.0->5.98m tall,
	# capped just under the next slab to avoid z-fighting). The old 3m walls
	# left a 3m open band around every floor showing the void — the single
	# biggest "prototype" tell in the old look. The darkened lower band
	# (collider 0..3.0m, albedo band baked in the texture) keeps the existing
	# wainscot/baseboard texture readable at the new height.
	for i in range(4):
		var wall = StaticBody3D.new()
		wall.position = pos + Vector3([0, 20, 0, -20][i], 2.99, [20, 0, -20, 0][i])
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
		wall_m.size = Vector3(40, 5.98, 0.3)
		wall_mesh.mesh = wall_m
		var wall_mat = _make_wall_material(color, floor_index)
		wall_mesh.material_override = wall_mat
		wall.add_child(wall_mesh)

	# GRAPHICS PASS (REVIEW-FIXED): dusk-sky window band along N/S exterior
	# walls (i=0 south z+20, i=2 north z-20). The glass is a CHILD of the
	# wall body (positioned at floor+2.99 spanning 0..5.98 world), so its
	# local Y is wall-relative: the first cut used +1.7 (world 4.7..8.1,
	# poking 2m ABOVE the wall into the ceiling). Local −0.39 lands the
	# 3.4m band at world 0.9..4.3 — inside the wall, 0.9m sill, 1.7m head.
		if i == 0 or i == 2:
			var glass = MeshInstance3D.new()
			var glass_mesh = PlaneMesh.new()
			glass_mesh.size = Vector2(36, 3.4)
			glass.mesh = glass_mesh
			glass.material_override = _dusk_window_material()
			# PlaneMesh lies in XZ facing +Y; stand it upright against the
			# wall. South wall (i=0, z+20): face -Z (into the room, rot.x
			# = +90). North wall (i=2, z-20): face +Z (rot.x = -90).
			glass.rotation.x = -PI / 2.0 if i == 2 else PI / 2.0
			# Inner face of the wall (0.3 thick): offset toward the room.
			var inward_z := -0.17 if i == 0 else 0.17
			glass.position = Vector3(0, -0.39, inward_z)
			wall.add_child(glass)

	# GRAPHICS PASS: real drop-ceiling slab closing the top of every floor
	# (mesh only, no collision — nothing walks on ceilings). Floor 4 keeps a
	# 20-wide opening above the parking-lot strip so the exit skyline reads.
	# cast_shadow OFF: the tilted key light would smear slab/grid shadows in
	# long stripes across the whole floor (caught in movie-frame QA).
	if floor_index == 3:
		for half in [-1.0, 1.0]:
			var half_mesh := MeshInstance3D.new()
			var half_box := BoxMesh.new()
			half_box.size = Vector3(40.0, 0.12, 10.0)
			half_mesh.mesh = half_box
			half_mesh.material_override = _ceiling_material(floor_index)
			half_mesh.position = pos + Vector3(0, 5.94, half * 15.0)
			half_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(half_mesh)
	else:
		var ceiling := StaticBody3D.new()
		ceiling.name = "Ceiling_F%d" % floor_index
		var ceil_mesh := MeshInstance3D.new()
		var ceil_box := BoxMesh.new()
		ceil_box.size = Vector3(40, 0.12, 40)
		ceil_mesh.mesh = ceil_box
		ceil_mesh.material_override = _ceiling_material(floor_index)
		ceil_mesh.position = pos + Vector3(0, 5.94, 0)
		ceil_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ceiling.add_child(ceil_mesh)
		add_child(ceiling)

## Cached ceiling-tile material: off-white with a subtle panel grid so the
## fifth face of every floor reads as finished office ceiling.
var _ceil_mats: Dictionary = {}
func _ceiling_material(floor_index: int) -> StandardMaterial3D:
	if _ceil_mats.has(floor_index):
		return _ceil_mats[floor_index] as StandardMaterial3D
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var base := Color(0.82, 0.82, 0.80)
	for y in 256:
		for x in 256:
			var col := base
			if x % 64 < 2 or y % 64 < 2:
				col = Color(0.42, 0.42, 0.44)  # T-bar grid
			elif x % 64 < 4 or y % 64 < 4:
				col = Color(0.66, 0.66, 0.66)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_scale = Vector3(8, 8, 1)
	mat.roughness = 0.95
	_ceil_mats[floor_index] = mat
	return mat

var _dusk_window_mat: StandardMaterial3D = null

## Shared dusk-sky gradient material for the window bands (orange horizon
## rising into deep blue — matches the game's accent palette).
func _dusk_window_material() -> StandardMaterial3D:
	if _dusk_window_mat:
		return _dusk_window_mat
	var img := Image.create(4, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		var t := float(y) / 63.0
		# Image y=0 is the TOP of the texture (UV v=0 samples row 0 in
		# Godot's ImageTexture). Top = warm horizon glow, fading into deep
		# dusk blue below — windows read as sunset at their brightest up
		# high. REVIEW: gentler pow (1.4 -> 0.9) + warmer start so the
		# orange band stays readable across the 3.4m band instead of
		# collapsing to flat navy at gameplay distance.
		var col := Color(1.0, 0.52, 0.16).lerp(Color(0.09, 0.11, 0.22), pow(t, 0.9))
		for x in 4:
			img.set_pixel(x, y, col)
	var grad_tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = grad_tex
	mat.albedo_color = Color(1, 1, 1)
	mat.emission_enabled = true
	mat.emission_texture = grad_tex
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 0.9  # brighter: the band is now 3.4m tall and must read as dusk
	mat.roughness = 0.2
	mat.metallic = 0.1
	# Mullion stripes: vertical window-frame bars baked into transparency.
	# (Kept opaque — a real transparency pass costs more on mobile.)
	_dusk_window_mat = mat
	return mat

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

	# FINISH VISIBILITY: checkered finish columns + vertical light beam +
	# strong green light so the exit reads from any corner of floor 4.
	var beam = MeshInstance3D.new()
	var beam_mesh = CylinderMesh.new()
	beam_mesh.top_radius = 1.4
	beam_mesh.bottom_radius = 2.6
	beam_mesh.height = 9.0
	beam.mesh = beam_mesh
	beam.position = Vector3(0, 22.6, 15.0)
	var beam_mat = StandardMaterial3D.new()
	beam_mat.albedo_color = Color(0.1, 0.95, 0.3, 0.28)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(0.1, 0.95, 0.3)
	beam_mat.emission_energy_multiplier = 1.4
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = beam_mat
	add_child(beam)

	var beacon = OmniLight3D.new()
	beacon.position = Vector3(0, 21.5, 15.0)
	beacon.light_color = Color(0.15, 1.0, 0.35)
	beacon.light_energy = 3.0
	beacon.omni_range = 16.0
	beacon.shadow_enabled = false
	add_child(beacon)

	var checkers := StandardMaterial3D.new()
	checkers.albedo_color = Color(1, 1, 1)
	for cx in [-3.4, 3.4]:
		var col := MeshInstance3D.new()
		var col_mesh := BoxMesh.new()
		col_mesh.size = Vector3(0.5, 5.0, 0.5)
		col.mesh = col_mesh
		col.position = Vector3(cx, 20.8, 15.0)
		var col_mat := StandardMaterial3D.new()
		col_mat.albedo_color = Color(1, 1, 1)
		col_mat.emission_enabled = true
		col_mat.emission = Color(0.9, 1.0, 0.9)
		col_mat.emission_energy_multiplier = 1.1
		col.material_override = col_mat
		add_child(col)

	var exit_label := Label3D.new()
	exit_label.text = "FINISH — PARKING LOT"
	exit_label.font_size = 96
	exit_label.outline_size = 22
	exit_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	exit_label.modulate = Color(0.2, 1.0, 0.4)
	exit_label.outline_modulate = Color(0, 0, 0, 0.9)
	exit_label.no_depth_test = true
	exit_label.position = Vector3(0, 24.4, 15.0)
	add_child(exit_label)

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
	_build_ceiling_grid(floor_pos, light_group, floor_index)
	var Dressing = load("res://scripts/OfficeDressing.gd")
	# Guide-lighting: each playable floor's elevator portal gets a warm POOL —
	# the nearest grid fixture re-anchors beside the portal with a tighter
	# range, so the traversal goal reads warm from anywhere on the floor.
	# Floor 3 keeps its grid (its exit already carries the green beacon).
	# Reuses an existing light: the nine-per-floor budget (ArtLightingTest)
	# and floor culling groups are untouched.
	const PORTAL_XZ := {0: Vector2(12.0, 14.0), 1: Vector2(-12.0, -2.0), 2: Vector2(12.0, 14.0)}
	# NOTE: `portal` must be function-scoped — an `if`-body var is invisible
	# to the loops below (GDScript block scoping; parse error otherwise).
	var portal: Vector2 = PORTAL_XZ.get(floor_index, Vector2(-999.0, -999.0))
	var pool_xz := Vector2(-999.0, -999.0)
	if portal.x > -500.0:
		var nx: float = clampf(roundf(portal.x / 12.0) * 12.0, -12.0, 12.0)
		var nz: float = clampf(roundf(portal.y / 12.0) * 12.0, -12.0, 12.0)
		pool_xz = Vector2(nx, nz)
	for x in [-12.0, 0.0, 12.0]:
		for z in [-12.0, 0.0, 12.0]:
			var light = OmniLight3D.new()
			# GRAPHICS PASS: lighting plane raised to sit just under the new
			# 5.94m ceiling (was 3.0m, floating mid-room in the tall band).
			light.position = floor_pos + Vector3(x, 5.6, z)
			# Dusk: warm perimeter pools against a softer, cooler circulation
			# lane. Reuse the existing nine lights, but stop every fixture
			# washing almost the entire 40m floor with its 22m range.
			var is_lane: bool = x == 0.0
			light.light_color = Color(0.72, 0.84, 1.0) if is_lane else Color(1.0, 0.78, 0.55)
			light.light_energy = 0.58 if is_lane else 1.25
			light.omni_range = 12.0 if is_lane else 15.0
			light.shadow_enabled = false
			light.light_bake_mode = OmniLight3D.BAKE_STATIC
			if Vector2(x, z) == pool_xz:
				# Portal pool: nudge 1.5m toward the floor centre so the pool
				# spills onto the approach, tighten the throw, warm it up.
				var inward := (Vector2(-portal.x, -portal.y)).normalized() * 1.5
				light.position = floor_pos + Vector3(portal.x + inward.x, 4.4, portal.y + inward.y)
				light.light_color = Color(1.0, 0.72, 0.45)
				light.light_energy = 1.6
				light.omni_range = 9.0
			light_group.add_child(light)

			# GRAPHICS PASS: recessed troffer panels (frame + emissive lens)
			# replace the old floating 3x0.06x0.22 bars — panels are the
			# size of real 2x4 fixtures and visually anchor the light grid.
			if Dressing:
				var panel: MeshInstance3D = Dressing.ceiling_panel()
				panel.position = floor_pos + Vector3(x, 5.86, z)
				light_group.add_child(panel)
				# Flicker: a few fixtures buzz irregularly (Lethal Company vibe).
				if (x + z) == 0.0 or (x == 12.0 and z == -12.0):
					panel.set_meta("flicker", true)

var _flicker_t := 0.0
var _flicker_fixtures: Array = []
func _process_flicker(delta: float) -> void:
	pass

## Irregular fluorescent buzz on flagged fixtures — cheap dread.
## Flicker targets CLONE the lens material first: panels share one cached
## material, so dimming it directly would brown out every fixture on the
## floor (shared-material side-effect, caught before shipping).
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
	var lens: MeshInstance3D = target.get_child(0)
	var mat: StandardMaterial3D = lens.material_override.duplicate()
	lens.material_override = mat
	# Matched light pulse: the troffer's own grid OmniLight sits at the
	# same (x,z) one row below the panel — dim it with the same rhythm.
	# Reuses an existing light, so the nine-light floor budget holds
	# (ArtLightingTest) and floor culling keeps everything grouped.
	var sibling_light: OmniLight3D = null
	var group: Node = target.get_parent()
	if group:
		var panel_xz := Vector2(target.position.x, target.position.z)
		for candidate in group.find_children("*", "OmniLight3D", true, false):
			var light_pos := Vector2(candidate.position.x, candidate.position.z)
			if light_pos.distance_to(panel_xz) < 0.5:
				sibling_light = candidate
				break
	var base_energy := 1.25
	if sibling_light:
		base_energy = sibling_light.light_energy
	var tw := create_tween()
	tw.tween_callback(func(): mat.emission_energy_multiplier = 0.15)
	tw.tween_callback(func():
		if sibling_light and is_instance_valid(sibling_light):
			sibling_light.light_energy = 0.1)
	tw.tween_interval(randf_range(0.04, 0.12))
	tw.tween_callback(func(): mat.emission_energy_multiplier = 1.4)
	tw.tween_callback(func():
		if sibling_light and is_instance_valid(sibling_light):
			sibling_light.light_energy = base_energy)
	tw.tween_interval(randf_range(0.03, 0.09))
	tw.tween_callback(func(): mat.emission_energy_multiplier = 0.3)
	tw.tween_callback(func():
		if sibling_light and is_instance_valid(sibling_light):
			sibling_light.light_energy = 0.2)
	tw.tween_interval(0.05)
	tw.tween_callback(func(): mat.emission_energy_multiplier = 1.4)
	tw.tween_callback(func():
		if sibling_light and is_instance_valid(sibling_light):
			sibling_light.light_energy = base_energy)

## Drop-ceiling grid: dark T-bar panels between light fixtures.
## Bars cast NO shadows — thin geometry at ceiling height smears long
## stripes across the floor under the tilted key light.
func _build_ceiling_grid(floor_pos: Vector3, parent: Node3D, floor_index: int = -1) -> void:
	var grid_mat = StandardMaterial3D.new()
	# Dusk pass: near-black bars read as trenches from the chase camera;
	# lifted to a painted-T-bar tone that still separates the panels.
	grid_mat.albedo_color = Color(0.16, 0.16, 0.19)
	grid_mat.roughness = 0.95
	# REVIEW FIX: floor 4's ceiling is OPEN over the parking lot (the two
	# slabs only cover |z| >= 10) — the z=±8 bars hung in open sky. On
	# floor 4, keep only the bars that sit over solid ceiling.
	var zs: Array = [-20.0, -8.0, 8.0, 20.0]
	var xs: Array = [-20.0, -8.0, 8.0, 20.0]
	if floor_index == 3:
		zs = [-20.0, 20.0]
	for x in xs:
		var bar_x = MeshInstance3D.new()
		var bm_x = BoxMesh.new()
		bm_x.size = Vector3(0.25, 0.08, 40)
		bar_x.mesh = bm_x
		bar_x.material_override = grid_mat
		bar_x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar_x.position = floor_pos + Vector3(x, 5.91, 0)
		parent.add_child(bar_x)
	for z in zs:
		var bar_z = MeshInstance3D.new()
		var bm_z = BoxMesh.new()
		bm_z.size = Vector3(40, 0.08, 0.25)
		bar_z.mesh = bm_z
		bar_z.material_override = grid_mat
		bar_z.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bar_z.position = floor_pos + Vector3(0, 5.91, z)
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
	# A2 preset remap (PRESETS.md §3): procedural ambient fallback is
	# #B8CDD2 @ 0.45; key is #F2C66D @ 1.0 for Evacuation/Hauled/Pizza.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("B8CDD2")
	env.ambient_light_energy = 0.45
	var key_light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if key_light:
		key_light.light_energy = 1.0
		key_light.light_color = Color("F2C66D")
		# Key geometry per §3: elevation 30°, travel (+0.75,-0.50,-0.43).
		var dir := Vector3(0.75, -0.50, -0.43).normalized()
		key_light.look_at_from_position(key_light.global_position, key_light.global_position + dir)
		# Shadow numbers per §4 (Standard): 2048, 2 cascades, 28 m, blend,
		# fade 0.80; bias 0.05 / normal 1.0. Enhanced sharpness overrides in
		# Settings._apply_graphics_quality (blur 1.0 vs 2.0, 4096 map).
		key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		key_light.directional_shadow_max_distance = 28.0
		key_light.directional_shadow_blend_splits = true
		key_light.directional_shadow_fade_start = 0.80
		key_light.shadow_blur = 2.0
		key_light.shadow_bias = 0.05
		key_light.shadow_normal_bias = 1.0
	# Fog+glow are OFF on every preset (PRESETS.md §2 matrix — "off means
	# disabled, not hidden behind a quality heuristic").
	env.fog_enabled = false
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 18.0
	env.fog_depth_end = 60.0
	env.fog_light_color = Color(0.16, 0.17, 0.24)
	env.fog_density = 0.35
	env.glow_enabled = false
	env.glow_strength = 0.9
	env.glow_hdr_threshold = 1.1
	# Tonemap LINEAR, exposure 1.0 fixed on every preset (PRESETS.md §2);
	# the old filmic "office at night" grade is retired by the redesign.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# Vignette OFF on every preset (PRESETS.md §2).
	_spawn_dust_motes()

## Dust motes are a fixed desktop decorative pool (PRESETS.md §8),
## not a quality gate — present on Standard and Enhanced alike.
func _motes_pool_capped() -> bool:
	# Decorative motes are desktop-only in the §8 pool table (Android 0).
	return OS.has_feature("android")

## Ambient dust motes drifting through light pools — two cheap quads-per-
## particle emitters per floor group area are skipped at LOW quality.
func _spawn_dust_motes() -> void:
	if _motes_pool_capped():
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

	# PORTAL VISIBILITY: floor label on the pad + destination ring so the
	# teleport reads as "this goes UP to floor N" from across the room.
	var pad_label = Label3D.new()
	pad_label.text = "ELEVATOR → FLOOR %d" % (target_floor + 1)
	pad_label.font_size = 64
	pad_label.outline_size = 16
	pad_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pad_label.modulate = Color(0.45, 0.8, 1.0)
	pad_label.outline_modulate = Color(0, 0, 0, 0.9)
	pad_label.no_depth_test = true
	pad_label.position = from_pos + Vector3(0, 3.1, 0)
	add_child(pad_label)

	var dest_ring = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 1.9
	ring_mesh.outer_radius = 2.3
	dest_ring.mesh = ring_mesh
	dest_ring.position = to_pos + Vector3(0, 0.3, 0)
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.2, 0.7, 1.0)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.1, 0.5, 1.0)
	ring_mat.emission_energy_multiplier = 1.5
	dest_ring.material_override = ring_mat
	add_child(dest_ring)

	# Destination marker (visual)
	var dest_marker = MeshInstance3D.new()
	var dest_mesh = BoxMesh.new()
	dest_mesh.size = Vector3(4, 0.15, 4)
	dest_marker.mesh = dest_mesh
	dest_marker.position = to_pos + Vector3(0, 0.1, 0)
	dest_marker.material_override = pad_mat
	add_child(dest_marker)

	# GRAPHICS PASS: elevator portal housing behind the pad (door frame +
	# metal double doors + blue seam glow + EXIT sign). The portal faces the
	# room center so the doors read from anywhere on the floor; approach
	# traffic comes over the pad from the center side, so the housing never
	# blocks the trigger. Registered with the floor group for culling.
	var Dressing = load("res://scripts/OfficeDressing.gd")
	if Dressing:
		var floor_index := clampi(int(round((from_pos.y - 0.5) / 6.0)), 0, 3)
		var outward := Vector2(from_pos.x, from_pos.z).normalized()
		# Face the ROOM: portal local +Z must point at the floor center, so
		# the yaw uses the negated outward direction.
		var portal: Node3D = Dressing.elevator_portal(
			from_pos + Vector3(outward.x * 2.3, -0.5, outward.y * 2.3),
			atan2(-outward.x, -outward.y))
		add_child(portal)
		var sign_node: Node3D = Dressing.exit_sign(Vector3(0, 3.62, 0.1))
		portal.add_child(sign_node)
		_register_floor_node(floor_index, portal)

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
	# PHASE 4: layout-driven obstacle placement. Desks never spawn on
	# floor 3 (y=12.5) — the gapped stairwell would float them over holes.
	var LevelLayouts = load("res://scripts/LevelLayouts.gd")
	var layout: Dictionary = LevelLayouts.current_layout() if LevelLayouts \
		else {"desk_counts": [5, 5, 5], "desk_range": 15.0, "obstacle_seed": 1337}
	var rng = RandomNumberGenerator.new()
	rng.seed = int(layout["obstacle_seed"])

	var floor_choices := [0.0, 6.0, 18.0]
	var counts: Array = layout["desk_counts"]
	var desk_range: float = layout["desk_range"]
	var total := 0
	for ci in range(counts.size()):
		total += int(counts[ci])
		for i in range(int(counts[ci])):
			var desk = _make_desk()
			var floor_y: float = floor_choices[ci]
			desk.position = Vector3(
				rng.randf_range(-desk_range, desk_range),
				floor_y + 0.5,
				rng.randf_range(-desk_range, desk_range)
			)
			desk.rotation.y = rng.randf_range(0, TAU)
			add_child(desk)
	# Layout-placed crates (floor 4 lot dressing).
	for crate_pos in layout["f4_crates"]:
		var crate = _make_crate()
		crate.position = crate_pos
		add_child(crate)

func _make_desk() -> StaticBody3D:
	var desk = StaticBody3D.new()

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 1.2, 1)
	col.shape = shape
	desk.add_child(col)

	# GRAPHICS PASS (REVIEW-FIXED): solid 2x1.2x1 block becomes a real desk —
	# top slab + two leg panels. The original collision box is CENTERED on
	# the body (local top +0.6, world top floor+1.1); the first cut placed
	# the slab at local 1.2, floating 0.6m ABOVE the collision top so chairs
	# sank through the desktop. Visuals now match the original collision
	# exactly — gameplay footprint byte-identical.
	var top_mesh_inst = MeshInstance3D.new()
	var top_mesh = BoxMesh.new()
	top_mesh.size = Vector3(2, 0.07, 1)
	top_mesh_inst.mesh = top_mesh
	var prop_mats = load("res://scripts/PropMaterials.gd")
	var mat: StandardMaterial3D = null
	if prop_mats and prop_mats.has_method("wood_planks"):
		mat = prop_mats.wood_planks()
	if mat == null:
		mat = _make_wood_material()
	top_mesh_inst.material_override = mat
	top_mesh_inst.position = Vector3(0, 0.565, 0)
	desk.add_child(top_mesh_inst)
	var leg_mat := mat if mat == null else mat.duplicate()
	if leg_mat:
		leg_mat.uv1_scale = Vector3(0.5, 1, 1)
	for side in [-1.0, 1.0]:
		var panel = MeshInstance3D.new()
		var panel_mesh = BoxMesh.new()
		panel_mesh.size = Vector3(0.08, 0.56, 0.9)
		panel.mesh = panel_mesh
		panel.position = Vector3(side * 0.9, 0.28, 0)
		panel.material_override = leg_mat
		desk.add_child(panel)

	# GRAPHICS PASS: monitor + keyboard + mug + papers on top (all
	# non-colliding dressing; footprint unchanged).
	var Dressing = load("res://scripts/OfficeDressing.gd")
	if Dressing and Dressing.has_method("desk_dressing"):
		Dressing.desk_dressing(desk, 0.6)

	return desk

func _spawn_powerups() -> void:
	var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
	if sp_modifiers and RaceModifiersScript.is_active(RaceModifiersScript.Modifier.NO_COFFEE):
		return  # No coffee run: skip all power-up spawns
	var rng = RandomNumberGenerator.new()
	rng.seed = 999
	var PowerUp = load("res://scripts/PowerUpVisual.gd")

	# PHASE 4: layout decides pickup pacing.
	var LevelLayouts = load("res://scripts/LevelLayouts.gd")
	var pu_count := 8
	if LevelLayouts:
		pu_count = int(LevelLayouts.current_layout()["powerup_count"])
	for i in range(pu_count):
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
	# D4: big 2D countdown moment (3-2-1-GO) for readability.
	var overlay_script = load("res://scripts/CountdownOverlay.gd")
	if overlay_script:
		var overlay = overlay_script.mount(self)
		var seq: Array = []
		var n := int(countdown_seconds)
		while n > 0:
			seq.append(str(n))
			n -= 1
		seq.append("GO!")
		overlay.play_sequence(seq)

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
		hud_ext.set_timer_text(timer_text, remaining)

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

## D1 restyle (UI-LAYOUTS §7): UITheme panel + responsive shrink-to-fit.
## Base 560x480; caps at 92% of viewport so 390px portrait never clips;
## buttons REMATCH (primary orange) / MAIN MENU (secondary).
func _style_results_panel() -> void:
	if not results_panel:
		return
	var UIT = load("res://scripts/UITheme.gd")
	if UIT:
		results_panel.add_theme_stylebox_override("panel", UIT.panel_style(UIT.color(UIT.ORANGE), true))
	var vbox = results_panel.get_node_or_null("VBox")
	if vbox:
		vbox.add_theme_constant_override("separation", 10)
		# S-F tape strip + header row (spec section 7: tape header, stamp).
		if UIT and not vbox.has_node("TapeStrip"):
			var tape: Control = UIT.TapeStrip.new()
			tape.name = "TapeStrip"
			tape.custom_minimum_size = Vector2(0, 10)
			vbox.add_child(tape)
			vbox.move_child(tape, 0)
		if not vbox.has_node("HeaderRow"):
			var header := HBoxContainer.new()
			header.name = "HeaderRow"
			vbox.add_child(header)
			vbox.move_child(header, 1)
			var head_label := Label.new()
			head_label.text = "RESULTS"
			head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head_label.add_theme_font_size_override("font_size", 22)
			head_label.add_theme_color_override("font_color", UIT.color(UIT.TEXT))
			header.add_child(head_label)
			# FORM EX-02 stamp: red border chip, tilted (R1: red = stamps).
			var stamp := PanelContainer.new()
			stamp.name = "FormStamp"
			var stamp_style := StyleBoxFlat.new()
			stamp_style.bg_color = Color(0, 0, 0, 0)
			stamp_style.set_border_width_all(2)
			stamp_style.border_color = UIT.color(UIT.RED)
			stamp_style.set_corner_radius_all(4)
			stamp_style.content_margin_left = 6.0
			stamp_style.content_margin_right = 6.0
			stamp_style.content_margin_top = 2.0
			stamp_style.content_margin_bottom = 2.0
			stamp.add_theme_stylebox_override("panel", stamp_style)
			stamp.rotation_degrees = -6.0
			var stamp_label := Label.new()
			stamp_label.text = "FORM EX-02"
			stamp_label.add_theme_font_size_override("font_size", 10)
			stamp_label.add_theme_color_override("font_color", UIT.color(UIT.RED))
			stamp.add_child(stamp_label)
			header.add_child(stamp)
		# S-F honest stats grid (spec R5: meter + reference tick).
		if not vbox.has_node("StatsGrid"):
			var grid := GridContainer.new()
			grid.name = "StatsGrid"
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 14)
			grid.add_theme_constant_override("v_separation", 8)
			vbox.add_child(grid)
			vbox.move_child(grid, vbox.get_node_or_null("WinnerLabel").get_index() + 1)
			for spec in [["TOP SPEED", "TopSpeed"], ["TRAPS HIT", "Traps"], ["TIME", "Time"]]:
				var name_label := Label.new()
				name_label.text = spec[0]
				name_label.add_theme_font_size_override("font_size", 13)
				name_label.add_theme_color_override("font_color", UIT.color(UIT.TEXT_FAIR))
				grid.add_child(name_label)
				var row := HBoxContainer.new()
				row.name = "%sRow" % spec[1]
				row.add_theme_constant_override("separation", 8)
				grid.add_child(row)
				if spec[1] == "TopSpeed":
					var meter: Control = UIT.MeterBar.new()
					meter.name = "TopSpeedMeter"
					meter.custom_minimum_size = Vector2(170, 8)
					meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					meter.maximum = 15.0
					row.add_child(meter)
				var value := Label.new()
				value.name = "%sValue" % spec[1]
				value.text = "—"
				# D5: stat values read at 24px; TOP SPEED carries the orange.
				value.add_theme_font_size_override("font_size", 24)
				value.add_theme_color_override("font_color",
					UIT.color(UIT.ORANGE) if spec[1] == "TopSpeed" else UIT.color(UIT.TEXT))
				row.add_child(value)
		# S-F record pills (LIME per spec).
		if not vbox.has_node("PillRow"):
			var pills := HBoxContainer.new()
			pills.name = "PillRow"
			pills.alignment = BoxContainer.ALIGNMENT_CENTER
			pills.add_theme_constant_override("separation", 8)
			vbox.add_child(pills)
			vbox.move_child(pills, vbox.get_node_or_null("StatsGrid").get_index() + 1)
		var winner = vbox.get_node_or_null("WinnerLabel")
		if winner:
			# D5: 32px warm-orange banner with a dark outline for contrast.
			winner.add_theme_color_override("font_color", Color(1.0, 0.65, 0.1))
			winner.add_theme_font_size_override("font_size", 32)
			winner.add_theme_color_override("font_outline_color", Color("0a0a0f"))
			winner.add_theme_constant_override("outline_size", 4)
		var rematch = vbox.get_node_or_null("RematchButton")
		if rematch and UIT:
			UIT.apply_primary(rematch)
			rematch.custom_minimum_size.y = 52.0
		var menu = vbox.get_node_or_null("MenuButton")
		if menu and UIT:
			UIT.apply_secondary(menu, UIT.color(UIT.VIOLET))
			menu.custom_minimum_size.y = 52.0
		var stats = vbox.get_node_or_null("StatsLabel")
		if stats:
			# StatsLabel survives as the muted modifiers caption only.
			stats.add_theme_color_override("font_color", UIT.color(UIT.TEXT_FAIR))
			stats.add_theme_font_size_override("font_size", 11)
	# Responsive: clamp panel to 92% of the visible rect every resize.
	_clamp_results_panel()
	results_panel.resized.connect(_clamp_results_panel)

func _clamp_results_panel() -> void:
	if not results_panel:
		return
	var vp := results_panel.get_viewport_rect().size
	var max_size := vp * 0.92
	var w := minf(560.0, max_size.x)
	var h := minf(480.0, max_size.y)
	results_panel.offset_left = -w / 2.0
	results_panel.offset_right = w / 2.0
	results_panel.offset_top = -h / 2.0
	results_panel.offset_bottom = h / 2.0

func _end_race() -> void:
	if match_state == &"finished":
		return
	match_state = &"finished"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if hazards and hazards.has_method("stop"):
		hazards.stop()
	if local_player:
		local_player.set_can_move(false)

	# S-F: hoisted so the results populate block can use them even when
	# StatsManager is absent (meter tick hidden, no pills from records).
	var prev_top_speed := -1.0
	var prev_races_valid := false
	var won := false
	if finish_order.size() > 0 and is_instance_valid(local_player):
		won = finish_order[0].player_id == local_player.get_instance_id()
	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		var prev_best: float = stats.top_speed_ever
		var prev_races: int = stats.total_races
		var prev_wins: int = stats.races_won
		prev_top_speed = prev_best
		prev_races_valid = prev_races > 0
		stats.record_race(won, top_speed, 0)
		new_personal_best = top_speed > prev_best and prev_races > 0
		# Phase 8A: celebrate skins that this win count just unlocked.
		var skins = load("res://scripts/ChairSkins.gd")
		if skins:
			skin_unlock_names = skins.newly_unlocked(prev_wins, stats.races_won)

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
			# S-F honest stats grid + record pills.
			var meter = vbox.get_node_or_null("StatsGrid/TopSpeedRow/TopSpeedMeter")
			var speed_value = vbox.get_node_or_null("StatsGrid/TopSpeedRow/TopSpeedValue")
			if meter:
				meter.value = top_speed
				# Reference tick: previous personal best (hidden on the
				# very first race — nothing to compare against yet).
				meter.tick = prev_top_speed if prev_races_valid else -1.0
			if speed_value:
				speed_value.text = "%d km/h" % int(top_speed)
			var traps_value = vbox.get_node_or_null("StatsGrid/TrapsRow/TrapsValue")
			if traps_value:
				traps_value.text = str(traps_hit)
			var time_value = vbox.get_node_or_null("StatsGrid/TimeRow/TimeValue")
			if time_value:
				if finish_order.size() > 0 and finish_order[0].has("time"):
					time_value.text = "%.1fs" % float(finish_order[0].time)
				else:
					time_value.text = "—"
			var pill_row = vbox.get_node_or_null("PillRow")
			if pill_row:
				for child in pill_row.get_children():
					child.queue_free()
				var UIT = load("res://scripts/UITheme.gd")
				if new_personal_best:
					pill_row.add_child(_record_pill("★ NEW TOP-SPEED RECORD", UIT))
				if skin_unlock_names.size() > 0:
					pill_row.add_child(_record_pill("◆ NEW CHAIR: %s" % ", ".join(skin_unlock_names),
						UIT, UIT.color(UIT.VIOLET)))
				# D5: entrance celebration — animate in, dim the match HUD.
				_present_results_panel(won)
			# Show active modifiers on the results screen for clarity
			if sp_modifiers:
				var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
				var names: Array[String] = []
				for mod in RaceModifiersScript.selected:
					names.append(RaceModifiersScript.LABELS[mod].split(" — ")[0])
				if names.size() > 0 and stats_label:
					stats_label.text = "MODIFIERS: " + ", ".join(names)
				elif stats_label:
					stats_label.text = ""

	# REVIEW FIX: was has_method("confetti_burst") — the function is
	# `confetti(parent, pos)`, so finish-line confetti never fired.
	# D5: confetti is a WIN reward — world burst at the winner + a 2D burst
	# over the results panel. Losses end quiet.
	if won:
		var impact = load("res://scripts/ImpactFX.gd")
		if impact and impact.has_method("confetti") and is_instance_valid(local_player):
			impact.confetti(self, local_player.global_position)
		if impact and impact.has_method("confetti_2d") and results_panel:
			var a11y_win = load("res://scripts/Accessibility.gd")
			if a11y_win == null or not a11y_win.reduced_motion_enabled():
				impact.confetti_2d(results_panel.get_parent(), _results_top_center())
	if new_personal_best:
		var audio_pb = get_node_or_null("/root/AudioManager")
		if audio_pb:
			audio_pb.play_sfx("victory", 1.0)
		var pb_a11y = load("res://scripts/Accessibility.gd")
		if pb_a11y:
			pb_a11y.caption("NEW TOP-SPEED RECORD!", 1.5)
	if skin_unlock_names.size() > 0:
		_announce_skin_unlocks(skin_unlock_names)

## S-F: record pill (spec section 7 "record pills"); D5: top-speed record is
## LIME, chair unlocks are VIOLET — pass `accent` to override.
func _record_pill(text: String, UIT, accent: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var col: Color = accent if accent.a > 0.0 else UIT.color(UIT.LIME)
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(col, 0.16)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	pill.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", col)
	pill.add_child(label)
	return pill

## D5: results entrance — fade+scale-in 0.4s ease-out, and the in-match HUD
## cards dim to 0.35 behind the panel (results panel itself exempt).
## Reduced motion: both land instantly.
func _present_results_panel(won: bool) -> void:
	_clamp_results_panel()
	results_panel.pivot_offset = results_panel.size / 2.0
	var a11y = load("res://scripts/Accessibility.gd")
	var instant: bool = a11y != null and a11y.reduced_motion_enabled()
	if instant:
		results_panel.modulate = Color(1, 1, 1, 1)
		results_panel.scale = Vector2.ONE
		_dim_hud_behind_results(0.0, true)
		return
	results_panel.modulate = Color(1, 1, 1, 0)
	results_panel.scale = Vector2(0.9, 0.9)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(results_panel, "modulate:a", 1.0, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(results_panel, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dim_hud_behind_results(0.3, false)

func _dim_hud_behind_results(duration: float, instant: bool) -> void:
	# The real race HUD (speed/boost/minimap/objective cards) lives on hud_ext,
	# its own CanvasLayer at layer 10 above $UI. CanvasLayer has no modulate
	# (it is not a CanvasItem) — dim its top-level card groups instead, which
	# covers every card no matter how HUD.gd regroups its internals.
	if hud_ext:
		for child in hud_ext.get_children():
			if child is CanvasItem:
				if instant:
					(child as CanvasItem).modulate.a = 0.35
				else:
					var tw := create_tween()
					tw.tween_property(child, "modulate:a", 0.35, duration)
	var parent := results_panel.get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == results_panel or not (child is CanvasItem):
			continue
		if child is CPUParticles2D or String(child.name).begins_with("PanicCam"):
			continue
		if String(child.name) == "SubtitleOverlay":
			continue
		if instant:
			(child as CanvasItem).modulate.a = 0.35
		else:
			var tw := create_tween()
			tw.tween_property(child, "modulate:a", 0.35, duration)

## D5: top-center of the results panel, in the $UI canvas layer's space.
func _results_top_center() -> Vector2:
	return Vector2(results_panel.global_position.x + results_panel.size.x / 2.0,
		results_panel.global_position.y + 8.0)

## Phase 8A: caption + announcer hype for fresh chair unlocks.
func _announce_skin_unlocks(names: Array[String]) -> void:
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("NEW CHAIR: %s" % ", ".join(names), 2.5)
	var audio_u = get_node_or_null("/root/AudioManager")
	if audio_u:
		audio_u.play_sfx("powerup", 1.2)
	var announce = load("res://scripts/Announcer.gd")
	if announce and announcer and announcer.has_method("say"):
		announcer.say("misc", ["NEW CHAIR UNLOCKED: %s" % " + ".join(names)], true)

func _on_rematch() -> void:
	get_tree().reload_current_scene()

func _on_back_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _exit_tree() -> void:
	# Safety net: rematch reloads the scene without _on_back_to_menu.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	load("res://scripts/Accessibility.gd").reset_time_scale()

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
