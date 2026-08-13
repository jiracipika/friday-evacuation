# PlayerChair.gd — Office chair physics character controller
# Smooth, juicy movement tuned for game feel
extends CharacterBody3D

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
		var mat = StandardMaterial3D.new()
		mat.albedo_color = player_color
		mat.roughness = 0.6
		mesh.material_override = mat
	
	# Set nametag
	if nametag:
		nametag.text = player_display_name
		nametag.modulate = player_color
	
	# Boost particles off by default
	if boost_particles:
		boost_particles.emitting = false

func _physics_process(delta: float) -> void:
	if not can_move:
		return
	
	# Stun timer
	if is_stunned > 0:
		is_stunned -= delta
		# Wobble visual
		if model_parent:
			model_parent.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.15
		_apply_gravity(delta)
		_apply_friction(delta)
		move_and_slide()
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
	
	# Smooth model rotation toward facing direction
	_smooth_facing(delta)

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

func _drop_trap() -> void:
	# Spawn a water puddle / banana peel behind the player
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

func set_can_move(value: bool) -> void:
	can_move = value
	if not value:
		velocity = Vector3.ZERO
