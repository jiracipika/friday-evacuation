# PlayerChair.gd — Office chair physics character controller
# Smooth, juicy movement tuned for game feel
extends CharacterBody3D

signal shake_requested(amount: float)
signal stunned  # emitted on any stun (trap/roomba/debris) for announcer hooks
signal interaction_requested
signal sabotage_requested

# Visual
@export var player_color: Color = Color(0.4, 0.8, 1.0)
@export var player_display_name: String = "Player"
@export var character_id: String = "deadline_dana"
@export var use_global_character := true
@export var character_design: Dictionary = {}
@export var skin_id: String = "office_standard"
@export var use_global_skin := true
var skin: Dictionary = {}  # resolved ChairSkins entry (Phase 8A)

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
var boost_held_sustain := false  # hold-boost: timer refills while held, cooldown grows
var smoothed_input := Vector2.ZERO  # input ramp state (movement smoothing)
const INPUT_RAMP_IN := 14.0   # press ramp rate (1/s) — ~80ms to ~full
const INPUT_RAMP_OUT := 20.0  # release decay rate — ~120ms to zero, snappier
var _trigger_boost_engaged := false  # RT/R2 pressure-boost arming latch
var _hum_timer := 0.0  # boost hum re-arm timer (rumble vocabulary)
const BOOST_SUSTAIN_CAP := 1.4   # max seconds hold-boost can stretch to
const BOOST_SUSTAIN_CD := 1.5    # extra cooldown seconds per held second
var stun_mash_bonus := 0.0       # mash-to-recover: input presses reduce stun
var smooth_facing: float = 0.0  # smoothed Y rotation for model
var chair_wheels: Array[MeshInstance3D] = []
var chair_seat: MeshInstance3D
var chair_backrest: MeshInstance3D
var dust_particles: GPUParticles3D
var rider_root: Node3D
var rider_y_offset: float = 0.0  # Phase 8A seat_rise (visual only)
var squash_amount: float = 1.0
var target_squash: float = 1.0
var landing_velocity: float = 0.0
var boost_visual_timer: float = 0.0
var mobile_input := Vector2.ZERO
# Forgiving platforming shared by keyboard, controller and touch.
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.14
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _jump_consumed := false
# GRAPHICS PASS: contact shadow + landing puff (set up in _ready).
var chair_blob_shadow: MeshInstance3D = null
var landing_puff: GPUParticles3D = null

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
		character_design = gm.get_character_design()
	if use_global_skin and gm and "selected_skin_id" in gm:
		skin_id = gm.selected_skin_id
	# Phase 8A: resolve skin and apply stat personality BEFORE physics.
	var skins_script: GDScript = load("res://scripts/ChairSkins.gd")
	if skins_script:
		skin = skins_script.get_skin(skin_id)
		skin_id = String(skin["id"])
		jump_force *= float(skin.get("jump_mult", 1.0))
		friction *= float(skin.get("friction_mult", 1.0))
		boost_force *= float(skin.get("boost_mult", 1.0))

	_apply_character_palette()

	# Floor snap so the chair sticks to slopes and handles ramp-to-floor steps
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)

	# Apply color to chair mesh
	if mesh:
		mesh.visible = false
	_build_chair_model()
	_ground_visual_model()

	# Set nametag
	if nametag:
		nametag.text = player_display_name
		nametag.modulate = player_color

	# Boost particles off by default
	_setup_boost_particles()
	_setup_dust_particles()

	# GRAPHICS PASS: soft contact shadow riding under the chair — grounds
	# the chair visually at all times (renderer has no SSAO; the disc is
	# one unshaded textured quad). NOT a child of ModelParent: the squash
	# and wheelie animations must not distort the shadow.
	var Dressing = load("res://scripts/OfficeDressing.gd")
	if Dressing:
		var blob: MeshInstance3D = Dressing.blob_shadow(1.7, 0.42)
		blob.name = "ChairBlobShadow"
		add_child(blob)
		chair_blob_shadow = blob

	# GRAPHICS PASS: one-shot landing puff, armed on hard landings.
	landing_puff = GPUParticles3D.new()
	landing_puff.name = "LandingPuff"
	landing_puff.emitting = false
	landing_puff.amount = 14
	landing_puff.lifetime = 0.4
	landing_puff.one_shot = true
	landing_puff.explosiveness = 0.95
	var puff_mat := ParticleProcessMaterial.new()
	puff_mat.direction = Vector3.UP
	puff_mat.spread = 70.0
	puff_mat.initial_velocity_min = 1.0
	puff_mat.initial_velocity_max = 2.6
	puff_mat.gravity = Vector3(0, -2.5, 0)
	puff_mat.scale_min = 0.05
	puff_mat.scale_max = 0.14
	puff_mat.color = Color(0.78, 0.72, 0.6, 0.5)
	landing_puff.process_material = puff_mat
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 0.06
	puff_mesh.height = 0.12
	landing_puff.draw_pass_1 = puff_mesh
	landing_puff.position = Vector3(0, 0.05, 0)
	add_child(landing_puff)
	landing_puff.finished.connect(func(): landing_puff.emitting = false)

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

	# Phase 8A: variant chassis per skin, shared rider on top.
	var kind := String(skin.get("id", "office_standard"))
	match kind:
		"exercise_ball":
			_build_ball_chair(chair_root)
		"bean_bag":
			_build_beanbag_chair(chair_root)
		"toilet":
			_build_toilet_chair(chair_root)
		_:
			_build_office_chair(chair_root)

	_build_rider_model(chair_root)
	_mount_hero_assembly(chair_root)
	# seat_rise lifts the rider relative to the chassis (bean bag sinks
	# in, ball perches up, throne raises). Visual only.
	rider_y_offset = float(skin.get("seat_rise", 0.0))
	if rider_root and rider_y_offset != 0.0:
		rider_root.position.y = rider_y_offset

## B2 hero assembly adapter (MODEL-SHEETS §1): authored GLB replaces the
## primitive office-chair visuals for office_standard; the live rider and halo
## stay. The authored base replaces the duplicate procedural wheels.
## Other skins keep full
## primitive builds until each variant gets its authored chassis.
func _mount_hero_assembly(chair_root: Node3D) -> void:
	var kind := String(skin.get("id", "office_standard"))
	if kind != "office_standard":
		return
	var packed: PackedScene = load("res://models/hero_assembly.glb")
	if packed == null:
		return
	var hero: Node3D = packed.instantiate()
	hero.name = "HeroAssembly"
	# GLB ground = wheel contact (chair base plane). The procedural build
	# centers its base at chair_root origin: shift hero so its wheels land
	# at the same ground line (procedural casters sit at y ~ -0.28+0.105).
	# This GLB stores vertical height along -Z. Stand it upright before
	# aligning its wheel contact to the procedural chair's ground plane.
	hero.rotation.x = PI / 2.0
	hero.position = Vector3(0, -0.135, 0)
	# Player-color accents on the authored cushions (shared atlas policy:
	# per-instance tint until the 2K atlas + vertex-color pipeline lands).
	var cushion_mat := StandardMaterial3D.new()
	cushion_mat.albedo_color = player_color
	cushion_mat.roughness = 0.9
	for mi in hero.find_children("*", "MeshInstance3D", true, false):
		# The import joins cushions into Chair surfaces, so node-name tinting
		# misses them. Override the cushion surface without recoloring metal.
		var instance := mi as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface)
			if material and material.resource_name == "chair_cushion":
				instance.set_surface_override_material(surface, cushion_mat)
		# Repo law: no new real-time shadow casters (tilted key light stripes).
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Keep the authored chair, but replace its baked worker with the live
	# customizable rider. Otherwise office_standard hides every rider choice.
	var worker := hero.find_child("Worker", true, false) as Node3D
	if worker:
		worker.visible = false
	for child in chair_root.get_children():
		if child == hero or child == rider_root:
			continue
		var cname := String(child.name)
		if cname == "BackrestHalo":
			continue
		child.visible = false
	chair_root.add_child(hero)

func _ground_visual_model() -> void:
	# The physics origin is the capsule center. Align visible wheels/base to
	# its bottom so every chassis rests on the floor instead of hovering.
	var minimum := _visual_min_y(model_parent, Transform3D.IDENTITY)
	if collision.shape is CapsuleShape3D and is_finite(minimum):
		model_parent.position.y = -collision.shape.height * 0.5 - minimum
		if nametag:
			nametag.position.y += model_parent.position.y

func _visual_min_y(node: Node3D, relative: Transform3D) -> float:
	var minimum := INF
	if not node.visible:
		return minimum
	if node is MeshInstance3D and node.mesh:
		var bounds: AABB = node.get_aabb()
		for corner in 8:
			minimum = minf(minimum, (relative * bounds.get_endpoint(corner)).y)
	for child in node.get_children():
		if child is Node3D:
			minimum = minf(minimum, _visual_min_y(child, relative * child.transform))
	return minimum

func _chair_material(color: Color, rough: float, metal: float) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	return mat

## Default plus cart/racing variants — office base with bolt-on decor.
func _build_office_chair(chair_root: Node3D) -> void:
	var kind := String(skin.get("id", "office_standard"))
	var chair_mat = _chair_material(player_color, 0.55, 0.05)
	var dark_mat = _chair_material(Color(0.035, 0.04, 0.055), 0.4, 0.65)

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
	# GRAPHICS PASS: rounded backrest slab (cylinder laid on its side) — a
	# real office-chair silhouette instead of a hard box. Same coverage.
	var back_cyl := CylinderMesh.new()
	back_cyl.top_radius = 0.46
	back_cyl.bottom_radius = 0.46
	back_cyl.height = 0.14
	chair_backrest.mesh = back_cyl
	chair_backrest.rotation.x = PI / 2.0
	chair_backrest.position = Vector3(0, 0.75, 0.3)
	chair_backrest.material_override = chair_mat
	chair_root.add_child(chair_backrest)

	# GRAPHICS PASS: emissive player-color halo ring on the backrest edge —
	# strong silhouette + team identification from any camera angle.
	var halo := MeshInstance3D.new()
	halo.name = "BackrestHalo"
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.42
	halo_mesh.outer_radius = 0.5
	halo.mesh = halo_mesh
	halo.rotation.x = PI / 2.0
	halo.position = Vector3(0, 0.75, 0.3)
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = player_color * 1.2
	halo_mat.emission_enabled = true
	halo_mat.emission = player_color
	halo_mat.emission_energy_multiplier = 0.9
	halo_mat.roughness = 0.4
	halo.material_override = halo_mat
	chair_root.add_child(halo)

	# GRAPHICS PASS: armrests — two small loops that finish the chair read.
	var armrest_mat = dark_mat
	for arm_side in [-1.0, 1.0]:
		var rest := MeshInstance3D.new()
		var rest_mesh := BoxMesh.new()
		rest_mesh.size = Vector3(0.12, 0.05, 0.42)
		rest.mesh = rest_mesh
		rest.position = Vector3(arm_side * 0.5, 0.6, 0.02)
		rest.material_override = armrest_mat
		chair_root.add_child(rest)
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.06, 0.28, 0.06)
		post.mesh = post_mesh
		post.position = Vector3(arm_side * 0.5, 0.45, 0.1)
		post.material_override = armrest_mat
		chair_root.add_child(post)

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

	# Shopping Cart: wire basket up front + push handle.
	if kind == "shopping_cart":
		var basket_mat = _chair_material(Color(0.55, 0.58, 0.62), 0.35, 0.85)
		var basket = MeshInstance3D.new()
		var basket_mesh = BoxMesh.new()
		basket_mesh.size = Vector3(0.55, 0.3, 0.4)
		basket.mesh = basket_mesh
		basket.position = Vector3(0, 0.5, -0.6)
		basket.material_override = basket_mat
		chair_root.add_child(basket)
		var handle = MeshInstance3D.new()
		var handle_mesh = BoxMesh.new()
		handle_mesh.size = Vector3(0.7, 0.06, 0.06)
		handle.mesh = handle_mesh
		handle.position = Vector3(0, 0.95, 0.5)
		handle.material_override = basket_mat
		chair_root.add_child(handle)

	# Racing Seat: side bolsters + wider backrest wing.
	if kind == "racing_seat":
		var bolster_mat = _chair_material(player_color.darkened(0.45), 0.5, 0.1)
		for side in [-1.0, 1.0]:
			var bolster = MeshInstance3D.new()
			var bolster_mesh = BoxMesh.new()
			bolster_mesh.size = Vector3(0.14, 0.18, 0.72)
			bolster.mesh = bolster_mesh
			bolster.position = Vector3(side * 0.43, 0.42, 0.02)
			bolster.material_override = bolster_mat
			chair_root.add_child(bolster)

## Exercise Ball — big squashed sphere, no wheels, perch cup on top.
func _build_ball_chair(chair_root: Node3D) -> void:
	var ball_mat = _chair_material(player_color.lightened(0.15), 0.35, 0.0)
	var ball = MeshInstance3D.new()
	ball.name = "Ball"
	var ball_mesh = SphereMesh.new()
	ball_mesh.radius = 0.55
	ball_mesh.height = 1.0
	ball.mesh = ball_mesh
	ball.position = Vector3(0, 0.3, 0)
	ball.scale = Vector3(1.0, 0.9, 1.0)
	ball.material_override = ball_mat
	chair_root.add_child(ball)
	# Highlight patch so it reads as glossy, not flat.
	var gloss = MeshInstance3D.new()
	var gloss_mesh = SphereMesh.new()
	gloss_mesh.radius = 0.1
	gloss_mesh.height = 0.2
	gloss.mesh = gloss_mesh
	gloss.position = Vector3(-0.25, 0.72, -0.25)
	var gloss_mat = _chair_material(Color(1, 1, 1, 0.5), 0.1, 0.0)
	gloss.material_override = gloss_mat
	chair_root.add_child(gloss)
	# Perch cup so the rider has somewhere to sit.
	var cup = MeshInstance3D.new()
	var cup_mesh = CylinderMesh.new()
	cup_mesh.top_radius = 0.3
	cup_mesh.bottom_radius = 0.24
	cup_mesh.height = 0.08
	cup.mesh = cup_mesh
	cup.position = Vector3(0, 0.78, 0)
	cup.material_override = _chair_material(Color(0.1, 0.1, 0.12), 0.5, 0.3)
	chair_root.add_child(cup)

## Bean Bag — flattened blob + backrest lump, sits low.
func _build_beanbag_chair(chair_root: Node3D) -> void:
	var bag_mat = _chair_material(player_color.darkened(0.1), 0.9, 0.0)
	var base = MeshInstance3D.new()
	base.name = "BeanBase"
	var base_mesh = SphereMesh.new()
	base_mesh.radius = 0.6
	base_mesh.height = 1.2
	base.mesh = base_mesh
	base.position = Vector3(0, 0.12, 0)
	base.scale = Vector3(1.0, 0.45, 1.0)
	base.material_override = bag_mat
	chair_root.add_child(base)
	var lump = MeshInstance3D.new()
	lump.name = "BeanBack"
	var lump_mesh = SphereMesh.new()
	lump_mesh.radius = 0.42
	lump_mesh.height = 0.84
	lump.mesh = lump_mesh
	lump.position = Vector3(0, 0.35, 0.42)
	lump.scale = Vector3(1.0, 0.8, 0.55)
	lump.material_override = bag_mat
	chair_root.add_child(lump)

## The Throne — porcelain toilet; boost sfx is a flush (AudioManager).
func _build_toilet_chair(chair_root: Node3D) -> void:
	var porcelain = _chair_material(Color(0.93, 0.94, 0.96), 0.12, 0.05)
	var tank_mat = _chair_material(Color(0.88, 0.9, 0.93), 0.2, 0.05)
	# Pedestal.
	var pedestal = MeshInstance3D.new()
	var pedestal_mesh = CylinderMesh.new()
	pedestal_mesh.top_radius = 0.22
	pedestal_mesh.bottom_radius = 0.3
	pedestal_mesh.height = 0.32
	pedestal.mesh = pedestal_mesh
	pedestal.position = Vector3(0, 0.16, 0.05)
	pedestal.material_override = porcelain
	chair_root.add_child(pedestal)
	# Bowl rim.
	var bowl = MeshInstance3D.new()
	var bowl_mesh = CylinderMesh.new()
	bowl_mesh.top_radius = 0.4
	bowl_mesh.bottom_radius = 0.3
	bowl_mesh.height = 0.14
	bowl.mesh = bowl_mesh
	bowl.position = Vector3(0, 0.39, 0)
	bowl.material_override = porcelain
	chair_root.add_child(bowl)
	# Seat ring (slightly warmer white).
	var ring = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.28
	ring_mesh.outer_radius = 0.42
	ring.mesh = ring_mesh
	ring.position = Vector3(0, 0.47, 0)
	ring.material_override = _chair_material(Color(0.97, 0.97, 0.99), 0.3, 0.0)
	chair_root.add_child(ring)
	# Tank + flush button at the back.
	var tank = MeshInstance3D.new()
	var tank_mesh = BoxMesh.new()
	tank_mesh.size = Vector3(0.55, 0.55, 0.22)
	tank.mesh = tank_mesh
	tank.position = Vector3(0, 0.62, 0.42)
	tank.material_override = tank_mat
	chair_root.add_child(tank)
	var button = MeshInstance3D.new()
	var button_mesh = CylinderMesh.new()
	button_mesh.top_radius = 0.05
	button_mesh.bottom_radius = 0.05
	button_mesh.height = 0.03
	button.mesh = button_mesh
	button.position = Vector3(0, 0.92, 0.42)
	button.material_override = _chair_material(Color(0.75, 0.78, 0.8), 0.25, 0.8)
	chair_root.add_child(button)
	chair_seat = ring

func _apply_character_palette() -> void:
	var roster = load("res://scripts/CharacterRoster.gd")
	if not roster:
		return
	var character: Dictionary = roster.get_character(character_id)
	character_id = character["id"]

func _build_rider_model(chair_root: Node3D) -> void:
	var roster = load("res://scripts/CharacterRoster.gd")
	var visual = load("res://scripts/OfficeCharacterVisual.gd")
	rider_root = visual.build(roster.get_character(character_id), character_design)
	chair_root.add_child(rider_root)

# Transform-only pupil wobble; mesh/material resources stay shared.
var _googly_velocity := Vector2.ZERO
var _googly_offsets := Vector2.ZERO
var _prev_velocity := Vector3.ZERO

func _update_googly_eyes(delta: float) -> void:
	if not is_instance_valid(rider_root):
		return
	var accel := (velocity - _prev_velocity) / maxf(delta, 0.001)
	_prev_velocity = velocity
	var target := Vector2(
		clampf(-accel.dot(global_transform.basis.x) * 0.0006, -0.012, 0.012),
		clampf(-accel.y * 0.00015, -0.009, 0.009))
	_googly_velocity += (target - _googly_offsets) * 90.0 * delta
	_googly_velocity *= maxf(1.0 - 12.0 * delta, 0.0)
	_googly_offsets += _googly_velocity * delta
	for path in ["Head/PupilL", "Head/PupilR"]:
		var pupil := rider_root.get_node_or_null(path) as Node3D
		if pupil:
			var rest: Vector3 = pupil.get_meta("rest_position")
			pupil.position = rest + Vector3(_googly_offsets.x, _googly_offsets.y, 0)
	var head := rider_root.get_node_or_null("Head") as Node3D
	if head:
		head.rotation.z = lerpf(head.rotation.z, clampf(-velocity.dot(global_transform.basis.x) * 0.008, -0.12, 0.12), 1.0 - exp(-8.0 * delta))

func _physics_process(delta: float) -> void:
	if not can_move:
		# Disabling control must not disable physics. Modes use this for
		# countdowns, disguises, remote chairs, and comedy elimination launches.
		# set_can_move(false) clears existing momentum; an explicit impulse set
		# afterward still needs to move the body.
		_apply_gravity(delta)
		move_and_slide()
		_apply_visual_feedback(delta)
		_update_googly_eyes(delta)
		_smooth_facing(delta)
		return

	# Stun timer
	if is_stunned > 0:
		is_stunned -= delta
		# MASH-TO-RECOVER: any gameplay input press shortens the stun.
		# Wiggling out of a trap is player agency, and the faster wheel
		# spin below is the visible tell that mashing works.
		var mashed := Input.is_action_just_pressed("move_forward") \
			or Input.is_action_just_pressed("move_back") \
			or Input.is_action_just_pressed("move_left") \
			or Input.is_action_just_pressed("move_right") \
			or Input.is_action_just_pressed("boost")
		if mashed:
			is_stunned = maxf(is_stunned - 0.15, 0.0)
			if model_parent and not chair_wheels.is_empty():
				for wheel in chair_wheels:
					if is_instance_valid(wheel):
						wheel.rotation.x += 0.6  # frantic wheel spin tell
		# Core-event audio: stun-recover chirp the moment the stun timer
		# expires (mash-expiry included) — distinct from the trap-hit thud.
		if is_stunned <= 0.0:
			_play_sfx("recover")
		if model_parent:
			model_parent.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.15
			model_parent.rotation.y += delta * 12.0
		_apply_gravity(delta)
		_apply_friction(delta)
		move_and_slide()
		_apply_visual_feedback(delta)
		_update_googly_eyes(delta)
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
		# HOLD-BOOST: while the button stays held, keep the burn alive up
		# to the sustain cap; every held second adds cooldown debt.
		if boost_held_sustain and Input.is_action_pressed("boost") \
				and boost_timer < BOOST_SUSTAIN_CAP:
			boost_timer = minf(boost_timer + delta, BOOST_SUSTAIN_CAP)
			boost_cd_timer += BOOST_SUSTAIN_CD * delta
		if Input.is_action_pressed("boost") == false:
			boost_held_sustain = false
		# Rumble vocabulary: boost = continuous low HUM (re-armed each
		# second; the envelope gate lets a thump interrupt it).
		_hum_timer -= delta
		if _hum_timer <= 0.0:
			_hum_timer = 1.0
			var prefs_hum = load("res://scripts/InputPrefs.gd")
			if prefs_hum and prefs_hum.has_method("rumble_hum"):
				prefs_hum.rumble_hum(0.9)
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
	_update_googly_eyes(delta)
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
		# Rumble vocabulary: hard landings = low SPUTTER (scrape/grumble).
		if impact > 4.0:
			var prefs_land = load("res://scripts/InputPrefs.gd")
			if prefs_land and prefs_land.has_method("rumble_sputter"):
				prefs_land.rumble_sputter()

	if not is_on_floor():
		landing_velocity = min(landing_velocity, velocity.y)

	# GRAPHICS PASS: contact shadow grounds the chair; it hides while
	# airborne, fades back in on the ground, and keeps a small margin above
	# the carpet so it never z-fights or intersects floor slabs.
	# GRAPHICS PASS REVIEW: contact shadow must sit ON THE GROUND, not at
	# local +0.03 (the chair origin is the capsule CENTER — +0.03 parked
	# the disc at seat height ~0.77m above the carpet; it only looked
	# grounded from the default high camera). Raycast down each frame and
	# place the disc just above whatever is actually beneath: floor slabs,
	# ramps, ice sheets, elevator pads. Width/opacity fall with height so
	# jumps read as the shadow detaching.
	if chair_blob_shadow and is_instance_valid(chair_blob_shadow):
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0, 0.2, 0),
			global_position + Vector3(0, -4.0, 0))
		query.exclude = [self]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			chair_blob_shadow.visible = false
		else:
			var ground_y: float = hit.position.y
			chair_blob_shadow.visible = true
			chair_blob_shadow.global_position = Vector3(
				global_position.x, ground_y + 0.03, global_position.z)
			var height_above: float = global_position.y - ground_y
			var k: float = clampf(1.0 - height_above / 2.0, 0.0, 1.0)
			chair_blob_shadow.scale = Vector3(0.6 + 0.4 * k, 1.0, 0.6 + 0.4 * k)

	# GRAPHICS PASS: one-shot dust puff on hard landings (visual only).
	if landed and landing_puff and is_instance_valid(landing_puff):
		landing_puff.restart()
		landing_puff.emitting = true

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
	# SMOOTHING (input ramp): exponential approach from the previous
	# frame's smoothed vector. Keyboard taps ramp in over ~80ms and ramp
	# out over ~120ms (release decays faster than press — snappier stops),
	# so digital keys feel analog. Analog sticks barely change (their raw
	# input is already continuous; the ramp just low-passes jitter).
	if raw_input.length() > 0.01 or smoothed_input.length() > 0.01:
		var rate := INPUT_RAMP_IN if raw_input.length() > smoothed_input.length() \
			else INPUT_RAMP_OUT
		var w: float = 1.0 - exp(-rate * delta)
		smoothed_input = smoothed_input.lerp(raw_input, w)
		if smoothed_input.length() < 0.01 and raw_input.length() < 0.01:
			smoothed_input = Vector2.ZERO
	raw_input = smoothed_input
	# PHASE 3: stick response curve (expo default). Reshapes the analog
	# magnitude — gentle center for precision lines, full throw at the
	# edge for racing. Keyboard input is already digital so the curve
	# only meaningfully affects pads; applying it to both is harmless
	# (|digital| is 1.0 -> curve(1.0) == 1.0 for all three modes).
	var stick_mag := raw_input.length()
	if stick_mag > 0.01:
		var prefs_curve = load("res://scripts/InputPrefs.gd")
		if prefs_curve and prefs_curve.has_method("apply_stick_curve"):
			var reshaped: float = prefs_curve.apply_stick_curve(stick_mag)
			raw_input = raw_input.normalized() * reshaped
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

	# --- Phase 1: reverse + brake + drift ------------------------------
	# "Back" is one coherent mode: brake hard while rolling forward, then
	# become a slow reverse foot-shove once (nearly) stopped. Never flaps
	# between the two — the branch depends only on the velocity sign
	# relative to input, not on speed thresholds.
	var horiz_now := Vector2(velocity.x, velocity.z)
	var fwd_speed: float = 0.0
	if input_dir.length() > 0.1:
		fwd_speed = horiz_now.dot(Vector2(input_dir.x, input_dir.z))
	# BRAKE-vs-REVERSE gate: brake when the held input OPPOSES the current
	# motion while still rolling (dot < 0), regardless of which world
	# direction that is. The old gate (fwd_speed > 1.0 against the INPUT
	# direction) was a dead branch for back-input: input_dir IS the back
	# direction, so v.dot(input) was always negative while rolling forward
	# and the code routed to REVERSE (0.9x decel through zero) instead of
	# BRAKE (2.5x). It only looked right at sens 0.55; the 0.35 turn-in
	# scale exposed it as a >1.1s "brake".
	var opposes_motion := horiz_now.length() > 1.0 and fwd_speed < -0.5

	if input_dir.length() > 0.1:
		# Target-velocity steering is responsive while retaining weaker control
		# during a boost, so the chair still has readable momentum.
		# InputPrefs.active_keyboard_scale() eases turn-in for keyboard play
		# (default 0.35) without touching top speed; controller play runs
		# FULL acceleration — the analog stick is the finesse control.
		# Only ever reached for controllable chairs — remote chairs
		# early-return via can_move.
		var prefs = load("res://scripts/InputPrefs.gd")
		var steer_accel := acceleration
		if prefs:
			steer_accel = acceleration * prefs.active_keyboard_scale()
		var effective_max := max_speed * carry_slowdown
		var target := Vector2(input_dir.x, input_dir.z) * effective_max
		var control := boost_steering if is_boosting else 1.0
		if raw_input.y > 0.5:
			if opposes_motion:
				# BRAKE: back input while rolling forward stops the chair
				# much faster than coasting (2.5x accel toward zero).
				horiz_now = horiz_now.move_toward(Vector2.ZERO, steer_accel * 2.5 * delta)
				velocity.x = horiz_now.x
				velocity.z = horiz_now.y
			else:
				# REVERSE: slow foot-shove backwards once stopped. Accel
				# 0.9x so it reaches the 25% cap cleanly (0.5x left a
				# visible 5-tick speed moiré — the shove kept restarting).
				var rev_target := Vector2(input_dir.x, input_dir.z) * max_speed * 0.25
				horiz_now = horiz_now.move_toward(rev_target, steer_accel * 0.9 * delta)
				velocity.x = horiz_now.x
				velocity.z = horiz_now.y
		else:
			# DRIFT-STEER: above 8 m/s, steering authority falls off (down
			# to 45% at top speed). The chair cannot fully redirect its
			# velocity in one tick, so travel direction lags behind facing
			# — the shopping-cart slide. Facing still snaps to input, so
			# the nose points into the corner while momentum carries out.
			var speed_now := horiz_now.length()
			var steer_auth := 1.0
			if speed_now > 8.0:
				steer_auth = 1.0 - clampf((speed_now - 8.0) / 4.0, 0.0, 1.0) * 0.55
			horiz_now = horiz_now.move_toward(target, steer_accel * steer_auth * control * delta)
			velocity.x = horiz_now.x
			velocity.z = horiz_now.y
		# Facing: pure input direction (the visual slide comes from the
		# steering-authority falloff, not from blending facing).
		smooth_facing = atan2(-input_dir.x, -input_dir.z)
	else:
		_apply_friction(delta)

	if Input.is_action_just_pressed("boost") and boost_cd_timer <= 0 and not boost_locked:
		_start_boost()
	# PHASE 3: ANALOG TRIGGER BOOST — RT/R2 (joy axis 5, TRIGGER_RIGHT).
	# Pressure scales boost force: light press = gentle burst, full pull
	# = full boost. Digital A/Cross stays as the always-available fallback
	# (full strength). Only local, un-stunned chairs; one trigger tick
	# per press (crossed 0.3 threshold this frame).
	_trigger_boost_engaged = _trigger_boost_engaged \
		or (boost_cd_timer <= 0 and not boost_locked and Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.3)
	if _trigger_boost_engaged and boost_cd_timer <= 0 and not boost_locked:
		var trigger := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
		if trigger > 0.3:
			_start_boost(0.6 + 0.4 * trigger)  # pressure-scaled force
			_trigger_boost_engaged = false
		elif Input.is_action_pressed("boost") == false:
			_trigger_boost_engaged = false  # released without committing

	if Input.is_action_just_pressed("action"):
		if suppress_action_jump:
			interaction_requested.emit()
		else:
			# BUFFERED JUMP: remember the press for a short window so a
			# press just before landing still jumps on the landing tick.
			_jump_buffer_left = JUMP_BUFFER_TIME

	# --- Forgiving jump resolution (coyote + buffer) ---------------------
	# Coyote: keep granting ground for COYOTE_TIME after leaving the floor
	# so late jumps off ledges still fire (input feels fair at speed).
	# Buffer: a press inside JUMP_BUFFER_TIME before touching down fires
	# on the landing tick instead of eating the input.
	if is_on_floor():
		_coyote_left = COYOTE_TIME
		_jump_consumed = false
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)
	if _jump_buffer_left > 0.0:
		_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
		if _coyote_left > 0.0 and not _jump_consumed:
			_execute_jump()

	# Held item (stapler/spill charges) — Q uses the item first; without an
	# item Q falls back to dropping a sabotage trap (existing behavior).
	if Input.is_action_just_pressed("sabotage"):
		if suppress_sabotage:
			sabotage_requested.emit()
		elif item_charges > 0:
			_use_item()
		else:
			_drop_trap()

func _execute_jump() -> void:
	velocity.y = jump_force
	_jump_consumed = true
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	target_squash = 1.18
	_play_sfx("jump")
	_rumble(0.25)
	# BOOST-CANCEL: jumping during the first 0.2s of a boost ends
	# the boost early but clears HALF its remaining cooldown —
	# a tech for skilled players (boost into a jump-ledge line).
	if is_boosting and (boost_duration - boost_visual_timer) < 0.2:
		is_boosting = false
		if boost_particles:
			boost_particles.emitting = false
		boost_cd_timer *= 0.5

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
	# HOLD-BOOST: as long as boost stays held, the timer refills (capped)
	# but the cooldown grows — burn now, pay later.
	if Input.is_action_pressed("boost"):
		boost_held_sustain = true
	else:
		boost_held_sustain = false
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
	# Phase 8A: The Throne boosts with a flush instead of the whoosh.
	if String(skin.get("sfx", "")) == "flush":
		_play_sfx("flush")
	else:
		_play_sfx("boost")
	_rumble(0.7)
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
	stunned.emit()
	# Platform-safe no-op on desktop; tactile feedback on Android/iOS.
	Input.vibrate_handheld(60)
	_rumble(1.0)
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("STUNNED — TRAP HIT", 1.2)

## Controller rumble through InputPrefs (respects the settings toggle,
## no-ops without a pad). Kept as a one-liner helper so call sites stay
## readable and the prefs script stays standalone-compilable.
func _rumble(strength: float) -> void:
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs and prefs.has_method("rumble"):
		prefs.rumble(strength)

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
		else:
			_jump_buffer_left = JUMP_BUFFER_TIME  # touch gets buffering too
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
