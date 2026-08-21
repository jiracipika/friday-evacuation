# Roomba.gd — Phase 4C Rogue Roomba hazard entity.
# Flat dark cylinder with a glowing red indicator strip. Wanders (random
# heading every 3-5s, 4 u/s), bounces off walls, stuns + knocks back
# players on contact. Spawned by Hazards.gd.
extends CharacterBody3D

const SPEED := 4.0
const TURN_EVERY_MIN := 3.0
const TURN_EVERY_MAX := 5.0
const STUN := 1.5
const KNOCKBACK := 10.0

var heading: Vector2 = Vector2(1, 0)
var turn_countdown: float = 2.0

func _ready() -> void:
	add_to_group("roombas")
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 0.3
	col.shape = shape
	col.position = Vector3(0, 0.15, 0)
	add_child(col)

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.4
	body_mesh.bottom_radius = 0.4
	body_mesh.height = 0.2
	body.mesh = body_mesh
	body.position = Vector3(0, 0.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14)
	mat.roughness = 0.5
	body.material_override = mat
	add_child(body)

	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.7, 0.03, 0.06)
	strip.mesh = strip_mesh
	strip.position = Vector3(0, 0.21, 0.28)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(1.0, 0.1, 0.1)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.05, 0.05)
	smat.emission_energy_multiplier = 1.6
	strip.material_override = smat
	add_child(strip)

	var zone := Area3D.new()
	var zcol := CollisionShape3D.new()
	var zshape := CylinderShape3D.new()
	zshape.radius = 0.75
	zshape.height = 0.6
	zcol.shape = zshape
	zcol.position = Vector3(0, 0.3, 0)
	zone.add_child(zcol)
	add_child(zone)
	zone.body_entered.connect(_on_bumped)

func _physics_process(delta: float) -> void:
	turn_countdown -= delta
	if turn_countdown <= 0.0:
		var angle := randf_range(0.0, TAU)
		heading = Vector2(cos(angle), sin(angle))
		turn_countdown = randf_range(TURN_EVERY_MIN, TURN_EVERY_MAX)
	velocity = Vector3(heading.x * SPEED, velocity.y - 20.0 * delta, heading.y * SPEED)
	move_and_slide()
	# Deflect off obstacles by reflecting the heading on the collision
	# normal (a plain 180° reversal ping-pongs inside cluttered floors).
	if get_slide_collision_count() > 0:
		var collision := get_slide_collision(0)
		var normal := collision.get_normal()
		var dir := Vector3(heading.x, 0, heading.y)
		var reflected := dir.bounce(normal)
		if reflected.length() > 0.01:
			heading = Vector2(reflected.x, reflected.z).normalized()
		else:
			heading = -heading

func _on_bumped(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	if body.has_method("stun"):
		body.stun(STUN)
	if "velocity" in body:
		var away: Vector3 = body.global_position - global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		body.velocity += away * KNOCKBACK
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("trap", 1.4)
	var fx := load("res://scripts/ImpactFX.gd")
	if fx:
		fx.burst(get_parent(), global_position + Vector3.UP * 0.2, Color(1.0, 0.15, 0.15), 14)
	var a11y := load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("ROOMBA HIT!", 1.0)
