# PlayerChair.gd — Office chair physics character controller
# Smooth, juicy movement tuned for game feel
extends CharacterBody3D

signal shake_requested(amount: float)
signal interaction_requested
signal sabotage_requested

# Visual
@export var player_color: Color = Color(0.4, 0.8, 1.0)
@export var player_display_name: String = "Player"
@export var character_id: String = "deadline_dana"
@export var use_global_character := true

# Movement tuning — lower accel = smoother starts/stops
@export var acceleration: float = 34.0
@export var max_speed: float = 12.0
@export var friction: float = 16.0
@export var boost_steering: float = 0.28
@export var rotation_speed: float = 16.0
@export var boost_force: float = 28.0
@export var boost_cooldown: float = 2.5
@export var boost_duration: float = 0.8
@export var jump_force: float = 8.0

# Mode hooks (secondary modes repurpose keys or apply carry penalties;
# Evacuation leaves all three at defaults)
var suppress_action_jump := false
var suppress_sabotage := false
var boost_locked := false
var carry_slowdown := 1.0

# Internal state
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var boost_timer: float = 0.0
var boost_cd_timer: float = 0.0
var is_boosting: bool = false
var can_move: bool = true
var is_stunned: float = 0.0  # seconds remaining
var smooth_facing: float = 0.0  # smoothed Y rotation for model
var chair_wheels: Array[MeshInstance3D] = []
var chair_seat: MeshInstance3D
var chair_backrest: MeshInstance3D
var dust_particles: GPUParticles3D
var rider_root: Node3D
var squash_amount: float = 1.0
var target_squash: float = 1.0
var landing_velocity: float = 0.0
var boost_visual_timer: float = 0.0
var mobile_input := Vector2.ZERO

# Held item charges (Phase 4B power-up variety)
var item_kind: StringName = &"none"  # none, stapler, spill
var item_charges: int = 0
var item_ready: bool = true  # fire-rate gate so Q spam cannot stack zips
var item_cooldown: float = 0.0

# Phase 4A themed-floor support
var respawn_point: Vector3 = Vector3.ZERO
var respawn_facing: float = 0.0
var _surface_friction_mult: float = 1.0  # grip multiplier from surface zones
var _on_special_surface: bool = false

# Nodes
@onready var mesh: MeshInstance3D = $ModelParent/ChairMesh
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var nametag: Label3D = $Nametag
@onready var boost_particles: GPUParticles3D = $BoostParticles
@onready var camera_anchor: Node3D = $CameraAnchor
@onready var model_parent: Node3D = $ModelParent

func _ready() -> void:
	add_to_group("players")
	var gm := get_node_or_null("/root/GameManager")
	if use_global_character and gm and "selected_character_id" in gm:
		character_id = gm.selected_character_id
	_apply_character_palette()

	# Floor snap so the chair sticks to slopes and handles ramp-to-floor steps
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)

	# Apply color to chair mesh
	if mesh:
		mesh.visible = false
	_build_chair_model()

	# Set nametag
	if nametag:
		nametag.text = player_display_name
		nametag.modulate = player_color

	# Boost particles off by default
	_setup_boost_particles()
	_setup_dust_particles()

func _setup_boost_particles() -> void:
	if not boost_particles:
		return
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 1)
	material.spread = 18.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, -1.5, 0)
	material.scale_min = 0.08
	material.scale_max = 0.22
	material.color = Color(1.0, 0.55, 0.08, 0.85)
	boost_particles.process_material = material
	boost_particles.amount = 16
	boost_particles.lifetime = 0.3

func _setup_dust_particles() -> void:
	dust_particles = GPUParticles3D.new()
	dust_particles.name = "RollingDust"
	dust_particles.amount = 10
	dust_particles.lifetime = 0.35
	dust_particles.emitting = false
	var process_material = ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, 1, 0)
	process_material.spread = 35.0
	process_material.initial_velocity_min = 0.4
	process_material.initial_velocity_max = 1.4
	process_material.gravity = Vector3(0, 0.8, 0)
	process_material.scale_min = 0.04
	process_material.scale_max = 0.14
	process_material.color = Color(0.72, 0.62, 0.45, 0.28)
	dust_particles.process_material = process_material
	var dust_mesh = SphereMesh.new()
	dust_mesh.radius = 0.08
	dust_mesh.height = 0.16
	dust_particles.draw_pass_1 = dust_mesh
	dust_particles.position = Vector3(0, -0.22, 0.28)
	add_child(dust_particles)

func _build_chair_model() -> void:
	if not model_parent:
		return
	var chair_root = Node3D.new()
	chair_root.name = "ProceduralChair"
	model_parent.add_child(chair_root)

	var chair_mat = StandardMaterial3D.new()
	chair_mat.albedo_color = player_color
	chair_mat.roughness = 0.55
	chair_mat.metallic = 0.05
	var dark_mat = StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.035, 0.04, 0.055)
	dark_mat.roughness = 0.4
	dark_mat.metallic = 0.65

	chair_seat = MeshInstance3D.new()
	chair_seat.name = "Seat"
	var seat_mesh = BoxMesh.new()
	seat_mesh.size = Vector3(0.9, 0.16, 0.82)
	chair_seat.mesh = seat_mesh
	chair_seat.position = Vector3(0, 0.28, 0)
	chair_seat.material_override = chair_mat
	chair_root.add_child(chair_seat)

	chair_backrest = MeshInstance3D.new()
	chair_backrest.name = "Backrest"
	var back_mesh = BoxMesh.new()
	back_mesh.size = Vector3(0.9, 0.95, 0.14)
	chair_backrest.mesh = back_mesh
	chair_backrest.position = Vector3(0, 0.75, 0.28)
	chair_backrest.material_override = chair_mat
	chair_root.add_child(chair_backrest)

	var stem = MeshInstance3D.new()
	var stem_mesh = CylinderMesh.new()
	stem_mesh.top_radius = 0.07
	stem_mesh.bottom_radius = 0.09
	stem_mesh.height = 0.48
	stem.mesh = stem_mesh
	stem.position = Vector3(0, 0.02, 0)
	stem.material_override = dark_mat
	chair_root.add_child(stem)

	for i in range(5):
		var angle = float(i) * TAU / 5.0
		var arm = MeshInstance3D.new()
		var arm_mesh = BoxMesh.new()
		arm_mesh.size = Vector3(0.1, 0.07, 0.62)
		arm.mesh = arm_mesh
		arm.position = Vector3(sin(angle) * 0.25, -0.22, cos(angle) * 0.25)
		arm.rotation.y = angle
		arm.material_override = dark_mat
		chair_root.add_child(arm)

		var wheel = MeshInstance3D.new()
		wheel.name = "Wheel_%d" % i
		var wheel_mesh = SphereMesh.new()
		wheel_mesh.radius = 0.105
		wheel_mesh.height = 0.21
		wheel.mesh = wheel_mesh
		wheel.position = Vector3(sin(angle) * 0.58, -0.28, cos(angle) * 0.58)
		wheel.material_override = dark_mat
		wheel.add_to_group("chair_wheels")
		chair_root.add_child(wheel)
		chair_wheels.append(wheel)

	_build_rider_model(chair_root)

func _apply_character_palette() -> void:
	var roster = load("res://scripts/CharacterRoster.gd")
	if not roster:
		return
	var character: Dictionary = roster.get_character(character_id)
	character_id = character["id"]

func _build_rider_model(chair_root: Node3D) -> void:
	var roster = load("res://scripts/CharacterRoster.gd")
	if not roster:
		return
	var character: Dictionary = roster.get_character(character_id)
	var body_color := Color.from_string(character["body"], player_color)
	var accent_color := Color.from_string(character["accent"], Color.WHITE)
	rider_root = Node3D.new()
	rider_root.name = "Rider_%s" % character_id
	chair_root.add_child(rider_root)

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.28
	torso_mesh.height = 0.72
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 0.92, 0.04)
	torso.material_override = _character_material(body_color, 0.7)
	rider_root.add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.position = Vector3(0, 1.48, -0.03)
	head.material_override = _character_material(Color("f0b58f"), 0.8)
	rider_root.add_child(head)

	# Two high-contrast eyes keep faces readable at gameplay distance.
	for eye_x in [-0.085, 0.085]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.07
		eye.mesh = eye_mesh
		eye.position = Vector3(eye_x, 1.51, -0.235)
		eye.material_override = _character_material(Color("15151d"), 0.4)
		rider_root.add_child(eye)

	var badge := MeshInstance3D.new()
	var badge_mesh := BoxMesh.new()
	badge_mesh.size = Vector3(0.18, 0.12, 0.035)
	badge.mesh = badge_mesh
	badge.position = Vector3(0.16, 1.02, -0.27)
	badge.material_override = _character_material(accent_color, 0.35, true)
	rider_root.add_child(badge)
	_build_character_accessory(rider_root, String(character["accessory"]), accent_color)

func _build_character_accessory(parent: Node3D, accessory: String, color: Color) -> void:
	var item := MeshInstance3D.new()
	item.name = "Accessory_%s" % accessory
	if accessory in ["mop_lance", "waiver_scroll", "coffee_tower"]:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.045 if accessory != "coffee_tower" else 0.11
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = 1.15 if accessory == "mop_lance" else 0.55
		item.mesh = cylinder
		item.position = Vector3(0.48, 1.0, 0.0)
		item.rotation.z = -0.28 if accessory == "mop_lance" else 0.0
	elif accessory == "webcam_drone":
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		item.mesh = sphere
		item.position = Vector3(0.55, 1.62, 0.1)
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.45, 0.3, 0.08)
		item.mesh = box
		item.position = Vector3(0.4, 0.95, -0.14)
		item.rotation.z = -0.2
	item.material_override = _character_material(color, 0.45, true)
	parent.add_child(item)

func _character_material(color: Color, roughness_value: float, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness_value
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.45
	return mat

func _physics_process(delta: float) -> void:
	if not can_move:
		return

	# Stun timer
	if is_stunned > 0:
		is_stunned -= delta
		if model_parent:
			model_parent.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.15
			model_parent.rotation.y += delta * 12.0
		_apply_gravity(delta)
		_apply_friction(delta)
		move_and_slide()
		_apply_visual_feedback(delta)
		return
	else:
		if model_parent:
			# Frame-rate independent wobble recovery
			var wobble_lerp = 1.0 - exp(-12.0 * delta)
			model_parent.rotation.z = lerp(model_parent.rotation.z, 0.0, wobble_lerp)

	# Timers
	if boost_cd_timer > 0:
		boost_cd_timer -= delta
	if item_cooldown > 0:
		item_cooldown -= delta
		if item_cooldown <= 0:
			item_ready = true
	if is_boosting:
		boost_timer -= delta
		boost_visual_timer = boost_timer
		if boost_timer <= 0:
			is_boosting = false
			if boost_particles:
				boost_particles.emitting = false

	# Input (only for local player)
	if is_multiplayer_authority():
		_handle_input(delta)

	_apply_gravity(delta)

	# Clamp speed smoothly (only when not boosting; carry penalties stack)
	if not is_boosting:
		var effective_max := max_speed * carry_slowdown
		var hori = Vector2(velocity.x, velocity.z)
		if hori.length() > effective_max:
			hori = hori.normalized() * effective_max
			velocity.x = hori.x
			velocity.z = hori.y

	move_and_slide()
	_apply_visual_feedback(delta)
	if dust_particles:
		dust_particles.emitting = is_on_floor() and Vector2(velocity.x, velocity.z).length() > 4.0 and not is_boosting

	# Smooth model rotation toward facing direction
	_smooth_facing(delta)

func _apply_visual_feedback(delta: float) -> void:
	var landed = is_on_floor() and landing_velocity < -2.0
	if landed:
		var impact = abs(landing_velocity)
		target_squash = 0.68 if impact > 6.0 else 0.82
		landing_velocity = 0.0
		target_squash = max(target_squash, 0.82)
		_play_sfx("land", impact)
		shake_requested.emit(clampf(impact * 0.018, 0.07, 0.16))

	if not is_on_floor():
		landing_velocity = min(landing_velocity, velocity.y)

	target_squash = lerpf(target_squash, 1.0, 1.0 - exp(-7.0 * delta))
	squash_amount = lerpf(squash_amount, target_squash, 1.0 - exp(-16.0 * delta))
	if model_parent:
		var width = 2.0 - squash_amount
		model_parent.scale = Vector3(width, squash_amount, width)
		var wheelie_target = 0.0
		if is_boosting:
			wheelie_target = -sin((boost_duration - boost_visual_timer) / boost_duration * PI) * 0.18
		model_parent.rotation.x = lerpf(model_parent.rotation.x, wheelie_target, 1.0 - exp(-10.0 * delta))

	for wheel in chair_wheels:
		if is_instance_valid(wheel):
			wheel.rotation.x += Vector2(velocity.x, velocity.z).length() * delta * 3.0

func _handle_input(delta: float) -> void:
	var raw_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mobile_input.length() > 0.1:
		raw_input += mobile_input
	raw_input = raw_input.limit_length(1.0)
	var input_dir := Vector3.ZERO

	# Godot's input vector uses negative Y for forward. Project that onto the
	# camera's horizontal axes so W always moves into the view, not backward.
	var cam = get_viewport().get_camera_3d()
	if cam:
		var forward = -cam.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		var right = cam.global_transform.basis.x
		right.y = 0
		right = right.normalized()
		input_dir = right * raw_input.x + forward * -raw_input.y
	else:
		input_dir = Vector3(raw_input.x, 0.0, raw_input.y)

	input_dir = input_dir.normalized()

	if input_dir.length() > 0.1:
		# Target-velocity steering is responsive while retaining weaker control
		# during a boost, so the chair still has readable momentum.
		var effective_max := max_speed * carry_slowdown
		var target := Vector2(input_dir.x, input_dir.z) * effective_max
		var horizontal := Vector2(velocity.x, velocity.z)
		var control := boost_steering if is_boosting else 1.0
		horizontal = horizontal.move_toward(target, acceleration * control * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.y
		smooth_facing = atan2(-input_dir.x, -input_dir.z)
	else:
		_apply_friction(delta)

	if Input.is_action_just_pressed("boost") and boost_cd_timer <= 0 and not boost_locked:
		_start_boost()

	if Input.is_action_just_pressed("action"):
		if suppress_action_jump:
			interaction_requested.emit()
		elif is_on_floor():
			velocity.y = jump_force
			target_squash = 1.18
			_play_sfx("jump")

	# Held item (stapler/spill charges) — Q uses the item first; without an
	# item Q falls back to dropping a sabotage trap (existing behavior).
	if Input.is_action_just_pressed("sabotage"):
		if suppress_sabotage:
			sabotage_requested.emit()
		elif item_charges > 0:
			_use_item()
		else:
			_drop_trap()

func _smooth_facing(delta: float) -> void:
	if not model_parent:
		return
	var current = model_parent.rotation.y
	var diff = angle_difference(current, smooth_facing)
	# Frame-rate independent rotation lerp
	var lerp_factor = 1.0 - exp(-rotation_speed * delta)
	model_parent.rotation.y = current + diff * lerp_factor

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _apply_friction(delta: float) -> void:
	# Horizontal friction only — frame-rate independent.
	# Surface zones (tile/ice) scale friction so grip varies per floor area.
	var hori = Vector2(velocity.x, velocity.z)
	var friction_factor = 1.0 - exp(-friction * _surface_friction_mult * delta)
	hori = hori.lerp(Vector2.ZERO, friction_factor)
	velocity.x = hori.x
	velocity.z = hori.y

func _start_boost(force_mult: float = 1.0, duration_mult: float = 1.0) -> void:
	if is_boosting:
		return
	is_boosting = true
	boost_timer = boost_duration * duration_mult
	boost_cd_timer = boost_cooldown
	var dir = Vector2(velocity.x, velocity.z).normalized()
	if dir.length() < 0.1:
		# The body root does not rotate; ModelParent does. Use controller facing.
		var facing := get_facing_direction()
		dir = Vector2(facing.x, facing.z)
	velocity.x += dir.x * boost_force * force_mult
	velocity.z += dir.y * boost_force * force_mult
	if boost_particles:
		boost_particles.emitting = true
	target_squash = 1.08
	shake_requested.emit(0.04)
	_play_sfx("boost")
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("BOOST!", 1.0)

func _drop_trap() -> void:
	var trap_scene = load("res://scenes/objects/SabotageTrap.tscn")
	if not trap_scene:
		return
	var trap = trap_scene.instantiate()
	get_parent().add_child(trap)
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var behind_dir := -horizontal_velocity.normalized() if horizontal_velocity.length() > 1.0 else -get_facing_direction()
	trap.global_position = global_position + behind_dir * 2.0
	trap.global_position.y = global_position.y + 0.1
	trap.owner_id = get_instance_id()
	# Phase 5: replicate player-dropped traps to peers (no-op offline)
	if trap.has_method("report_drop"):
		trap.report_drop()

## Phase 4B: give the player N charges of a held item, replacing any previous one.
func give_item(kind: StringName, charges: int) -> void:
	if charges <= 0:
		return
	item_kind = kind
	item_charges = charges
	item_ready = true
	item_cooldown = 0.0
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		if kind == &"stapler":
			a11y.caption("STAPLER ×%d — Q TO FIRE" % charges, 1.6)
		elif kind == &"spill":
			a11y.caption("SPILL ×%d — Q TO DROP" % charges, 1.6)

## Fire the held item (stapler bolt forward / spill puddle behind).
func _use_item() -> void:
	if item_charges <= 0 or not item_ready:
		return
	if item_kind == &"stapler":
		var bolt_script = load("res://scripts/StaplerBolt.gd")
		if bolt_script:
			var bolt = CharacterBody3D.new()
			bolt.set_script(bolt_script)
			get_parent().add_child(bolt)
			bolt.global_position = global_position + Vector3.UP * 0.6
			bolt.owner_id = get_instance_id()
			if bolt.has_method("launch"):
				bolt.launch(get_facing_direction(), velocity)
		item_cooldown = 0.5
	elif item_kind == &"spill":
		var trap_scene = load("res://scenes/objects/SabotageTrap.tscn")
		if trap_scene:
			var trap = trap_scene.instantiate()
			if trap.has_method("_set_forced_type"):
				trap._set_forced_type("spill")
			get_parent().add_child(trap)
			var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
			var behind_dir := -horizontal_velocity.normalized() if horizontal_velocity.length() > 1.0 else -get_facing_direction()
			trap.global_position = global_position + behind_dir * 2.2
			trap.global_position.y = 0.1
			trap.owner_id = get_instance_id()
			# NOTE: floor-relative Y so multi-floor traps land correctly on any floor
			trap.global_position.y = global_position.y + 0.1
			if trap.has_method("report_drop"):
				trap.report_drop()
		item_cooldown = 0.35
	else:
		return
	item_charges -= 1
	item_ready = false
	_play_sfx("powerup", 0.9)
	if item_charges <= 0:
		item_kind = &"none"

func stun(duration: float) -> void:
	is_stunned = max(is_stunned, duration)
	velocity = velocity * 0.3
	target_squash = 0.82
	shake_requested.emit(0.1)
	_play_sfx("trap")
	# Platform-safe no-op on desktop; tactile feedback on Android/iOS.
	Input.vibrate_handheld(60)
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("STUNNED — TRAP HIT", 1.2)

func _play_sfx(effect_name: String, intensity: float = 1.0) -> void:
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx(effect_name, intensity)

func set_mobile_input(value: Vector2) -> void:
	mobile_input = value

func trigger_mobile_action(action_name: StringName) -> void:
	if action_name == &"boost" and boost_cd_timer <= 0.0 and not boost_locked:
		_start_boost()
	elif action_name == &"action":
		if suppress_action_jump:
			interaction_requested.emit()
		elif is_on_floor():
			velocity.y = jump_force
			target_squash = 1.18
			_play_sfx("jump")
	elif action_name == &"sabotage":
		if suppress_sabotage:
			sabotage_requested.emit()
		elif item_charges > 0:
			_use_item()
		else:
			_drop_trap()

func set_can_move(value: bool) -> void:
	can_move = value
	if not value:
		velocity = Vector3.ZERO

## Phase 4A: surface-grip API. SurfaceZone areas call these on enter/exit so
## tile/ice patches change handling without new physics materials plumbing.
func set_surface(friction_mult: float) -> void:
	_surface_friction_mult = clampf(friction_mult, 0.05, 4.0)
	_on_special_surface = not is_equal_approx(friction_mult, 1.0)

func clear_surface() -> void:
	_surface_friction_mult = 1.0
	_on_special_surface = false

## Phase 4A: teleport to the last checkpoint with a brief stun, preserving
## the respawn point set by the mode (elevator checkpoints / floor starts).
func respawn() -> void:
	global_position = respawn_point
	velocity = Vector3.ZERO
	is_stunned = 0.8
	if model_parent:
		model_parent.rotation.y = respawn_facing
	_smooth_facing_reset()
	_play_sfx("trap")
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("RESPAWNED", 1.0)

## Called by elevators after they move the respawn point, so respawning
## faces onward along the course rather than backward.
func _update_respawn_facing() -> void:
	respawn_facing = smooth_facing

func _smooth_facing_reset() -> void:
	smooth_facing = respawn_facing
	if model_parent:
		model_parent.rotation.y = respawn_facing

## World-space forward matching the visible chair. The CharacterBody3D root is
## intentionally not rotated, so gameplay actions must never use its basis.
func get_facing_direction() -> Vector3:
	return Vector3(-sin(smooth_facing), 0.0, -cos(smooth_facing)).normalized()
