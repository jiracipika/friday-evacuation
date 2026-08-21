# StaplerBolt.gd — Phase 4B projectile fired by the stapler item.
# A hail of staples launched forward; knocks back and briefly stuns any
# player it hits (excluding the firer for the first moments after launch).
# Self-cleans on impact, expiry, or leaving the arena bounds.
extends CharacterBody3D

const SPEED := 26.0
const LIFETIME := 1.6
const HIT_STUN := 0.7
const KNOCKBACK := 12.0

var owner_id: int = 0
var age: float = 0.0
var _dir := Vector3.FORWARD
var _mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("stapler_bolts")

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	col.shape = sphere
	col.position = Vector3.ZERO
	add_child(col)

	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.5)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.88, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.75, 1.0)
	mat.emission_energy_multiplier = 1.4
	_mesh.material_override = mat
	add_child(_mesh)

func launch(dir: Vector3, firer_velocity: Vector3) -> void:
	_dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	# Inherit some of the firer's speed so it always outruns them
	velocity = _dir * SPEED + _dir * clampf(firer_velocity.length() * 0.4, 0.0, 8.0)

func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		_explode(false)
		return

	# Slight gravity droop for a lobbed staple feel
	velocity.y -= 4.0 * delta
	var collision := move_and_collide(velocity * delta)
	if collision:
		var collider := collision.get_collider()
		if collider and collider.is_in_group("players"):
			if int(collider.get_instance_id()) == int(owner_id):
				# Never hit the firer — slide out of their collision
				velocity = velocity.slide(collision.get_normal())
				return
			_hit_player(collider)
			return
		# Wall/floor/obstacle: sparks and despawn
		_explode(true)
		return

	# Hitbox sweep for players we fly through (cheap Area-free check)
	for body in _nearby_players():
		if body.get_instance_id() == owner_id:
			continue
		var to_body: Vector3 = body.global_position - global_position
		if to_body.length() < 0.9 and absf(to_body.dot(_dir)) < to_body.length() * 0.8:
			_hit_player(body)
			return

func _nearby_players() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return []
	var result: Array = []
	for node in tree.get_nodes_in_group("players"):
		if node and is_instance_valid(node):
			result.append(node)
	return result

func _hit_player(body: Node3D) -> void:
	if body.has_method("stun"):
		body.stun(HIT_STUN)
	if "velocity" in body:
		var away: Vector3 = (body.global_position - global_position)
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else _dir
		body.velocity += away * KNOCKBACK
	var stats := get_node_or_null("/root/StatsManager")
	if stats and int(owner_id) != int(body.get_instance_id()):
		stats.record_trap_landed()
	var fx := load("res://scripts/ImpactFX.gd")
	if fx:
		fx.burst(get_parent(), global_position, Color(0.7, 0.8, 1.0), 14)
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("trap", 1.1)
	var a11y := load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("STAPLED!", 1.0)
	queue_free()

func _explode(hit_wall: bool) -> void:
	if hit_wall:
		var fx := load("res://scripts/ImpactFX.gd")
		if fx:
			fx.burst(get_parent(), global_position, Color(0.8, 0.85, 1.0), 10)
	queue_free()
