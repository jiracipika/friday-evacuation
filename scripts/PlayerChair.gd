# PlayerChair.gd — Office chair physics character controller
# Smooth, juicy movement tuned for game feel
extends CharacterBody3D

signal shake_requested(amount: float)

# Visual
@export var player_color: Color = Color(0.4, 0.8, 1.0)
@export var player_display_name: String = "Player"

# Movement tuning — lower accel = smoother starts/stops
@export var acceleration: float = 18.0
@export var max_speed: float = 12.0
@export var friction: float = 12.0
@export var rotation_speed: float = 12.0
@export var boost_force: float = 24.0
@export var boost_cooldown: float = 3.0
@export var boost_duration: float = 0.6
@export var jump_force: float = 7.0

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
var squash_amount: float = 1.0
var target_squash: float = 1.0
var landing_velocity: float = 0.0
var boost_visual_timer: float = 0.0
var mobile_input := Vector2.ZERO

# Nodes
@onready var mesh: MeshInstance3D = $ChairMesh
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var nametag: Label3D = $Nametag
@onready var boost_particles: GPUParticles3D = $BoostParticles
@onready var camera_anchor: Node3D = $CameraAnchor
@onready var model_parent: Node3D = $ModelParent

func _ready() -> void:
	add_to_group("players")
	
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
	boost_particles.amount = 28
	boost_particles.lifetime = 0.45

func _setup_dust_particles() -> void:
	dust_particles = GPUParticles3D.new()
	dust_particles.name = "RollingDust"
	dust_particles.amount = 18
	dust_particles.lifetime = 0.55
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
	
	# Clamp speed smoothly (only when not boosting)
	if not is_boosting:
		var hori = Vector2(velocity.x, velocity.z)
		if hori.length() > max_speed:
			hori = hori.normalized() * max_speed
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
	var input_dir = Vector3.ZERO
	
	# Get camera-relative input
	var cam = get_viewport().get_camera_3d()
	if cam:
		var forward = -cam.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		var right = cam.global_transform.basis.x
		right.y = 0
		right = right.normalized()
		if mobile_input.length() > 0.1:
			input_dir += forward * -mobile_input.y + right * mobile_input.x
		if Input.is_action_pressed("move_forward"):
			input_dir -= forward
		if Input.is_action_pressed("move_back"):
			input_dir += forward
		if Input.is_action_pressed("move_left"):
			input_dir -= right
		if Input.is_action_pressed("move_right"):
			input_dir += right
	
	input_dir = input_dir.normalized()
	
	if input_dir.length() > 0.1:
		# Smooth acceleration
		velocity.x += input_dir.x * acceleration * delta
		velocity.z += input_dir.z * acceleration * delta
		
		# Update target facing angle
		smooth_facing = atan2(-input_dir.x, -input_dir.z)
	else:
		# Apply friction when no input
		_apply_friction(delta)
	
	# Boost
	if Input.is_action_just_pressed("boost") and boost_cd_timer <= 0:
		_start_boost()
	
	# Jump
	if Input.is_action_just_pressed("action") and is_on_floor():
		velocity.y = jump_force
		target_squash = 1.18
		_play_sfx("jump")
	
	# Sabotage (drop a trap behind you)
	if Input.is_action_just_pressed("sabotage"):
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
	# Horizontal friction only — frame-rate independent
	var hori = Vector2(velocity.x, velocity.z)
	var friction_factor = 1.0 - exp(-friction * delta)
	hori = hori.lerp(Vector2.ZERO, friction_factor)
	velocity.x = hori.x
	velocity.z = hori.y

func _start_boost() -> void:
	if is_boosting:
		return
	is_boosting = true
	boost_timer = boost_duration
	boost_cd_timer = boost_cooldown
	var dir = Vector2(velocity.x, velocity.z).normalized()
	if dir.length() < 0.1:
		# Boost in facing direction if stationary
		var fwd = -global_transform.basis.z
		dir = Vector2(fwd.x, fwd.z).normalized()
	velocity.x += dir.x * boost_force
	velocity.z += dir.y * boost_force
	if boost_particles:
		boost_particles.emitting = true
	target_squash = 1.08
	shake_requested.emit(0.04)
	_play_sfx("boost")

func _drop_trap() -> void:
	var trap_scene = load("res://scenes/objects/SabotageTrap.tscn")
	if not trap_scene:
		return
	var trap = trap_scene.instantiate()
	get_parent().add_child(trap)
	var behind_dir = -velocity.normalized() if velocity.length() > 1.0 else -global_transform.basis.z
	trap.global_position = global_position + Vector3(behind_dir.x, 0, behind_dir.z) * 2.0
	trap.global_position.y = 0.1

func stun(duration: float) -> void:
	is_stunned = max(is_stunned, duration)
	velocity = velocity * 0.3
	target_squash = 0.82
	shake_requested.emit(0.1)
	_play_sfx("trap")

func _play_sfx(effect_name: String, intensity: float = 1.0) -> void:
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_sfx"):
		audio_manager.play_sfx(effect_name, intensity)

func set_mobile_input(value: Vector2) -> void:
	mobile_input = value

func trigger_mobile_action(action_name: StringName) -> void:
	if action_name == &"boost" and boost_cd_timer <= 0.0:
		_start_boost()
	elif action_name == &"action" and is_on_floor():
		velocity.y = jump_force
		target_squash = 1.18
		_play_sfx("jump")

func set_can_move(value: bool) -> void:
	can_move = value
	if not value:
		velocity = Vector3.ZERO
