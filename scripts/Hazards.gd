# Hazards.gd — Phase 4C dynamic hazards controller + entities.
# Spawned by Evacuation during a race: Rogue Roombas (wander AI, contact
# stun + knockback), swinging doors (sin-wave rotation), fire-drill alarm
# (red strobe + panic friction), falling ceiling debris (floor 3 only,
# spawned above landings, never over gaps).
# Self-contained Node3D: mode adds it as a child and it drives itself from
# _physics_process. Respects reduced_motion (no shake) and flash_effects.
extends Node3D

signal fire_drill_started
signal fire_drill_ended

const ROOMBA_SPEED := 4.0
const ROOMBA_STUN := 1.5
const ROOMBA_KNOCKBACK := 10.0
const DOOR_STUN := 0.5
const DOOR_KNOCKBACK := 8.0
const DEBRIS_WARN_TIME := 1.0
const DEBRIS_STUN := 1.0
const DEBRIS_KNOCKBACK := 7.0
const FIRE_DRILL_INTERVAL := 30.0
const FIRE_DRILL_DURATION := 5.0
const PANIC_FRICTION_MULT := 1.5

## Landings (x, z, w, d) — floor 3 solid ground; keep synced with
## Evacuation._floor3_landing_layout() / LevelClearTest.FLOOR3_LANDINGS.
const FLOOR3_LANDINGS: Array[Dictionary] = [
	{"x": 0.0, "z": 17.5, "w": 40.0, "d": 5.0},
	{"x": 0.0, "z": -17.5, "w": 40.0, "d": 5.0},
	{"x": 17.5, "z": 0.0, "w": 5.0, "d": 40.0},
	{"x": -17.5, "z": 0.0, "w": 5.0, "d": 40.0},
	{"x": 12.0, "z": 14.0, "w": 8.0, "d": 8.0},
	{"x": -12.0, "z": 14.0, "w": 8.0, "d": 8.0},
	{"x": 0.0, "z": 14.0, "w": 16.0, "d": 3.0},
	{"x": 0.0, "z": 6.0, "w": 8.0, "d": 30.0},
]

var race_time: float = 0.0
var active := false
var fire_drill_timer: float = FIRE_DRILL_INTERVAL
var fire_drill_active := false
var fire_drill_elapsed: float = 0.0
var _strobe_lights: Array[OmniLight3D] = []
var _door_pivots: Array[Node3D] = []
var _panic_chairs: Array[Node] = []
var _roomba_parent: Node3D
var _debris_timer: float = 5.0

## Flat spots per floor where doors can hinge (x, z) on the given floor y.
const DOOR_SPOTS: Array[Dictionary] = [
	{"pos": Vector3(-8, 0, -14), "rot": 0.0},
	{"pos": Vector3(8, 0, -14), "rot": 0.0},
	{"pos": Vector3(0, 18, -10), "rot": PI / 2.0},
	{"pos": Vector3(0, 18, 10), "rot": PI / 2.0},
]

func _ready() -> void:
	_roomba_parent = Node3D.new()
	_roomba_parent.name = "Roombas"
	add_child(_roomba_parent)
	_build_doors()
	_build_strobes()

func start_race() -> void:
	active = true
	race_time = 0.0
	fire_drill_timer = FIRE_DRILL_INTERVAL
	_build_roombas()

func stop() -> void:
	active = false
	_end_fire_drill()

## Gate: hazards only tick while racing and not paused.
func _physics_process(delta: float) -> void:
	if not active:
		return
	race_time += delta
	_update_doors()
	_update_fire_drill(delta)
	_update_debris(delta)

# ---------------- Roombas ----------------

func _build_roombas() -> void:
	for child in _roomba_parent.get_children():
		child.queue_free()
	# 2 per floor (floors 1, 2, 4 solid; floor 3 sampled from landings)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for floor_y in [0.0, 6.0, 18.0]:
		for i in range(2):
			var pos := Vector3(rng.randf_range(-14, 14), floor_y + 0.15, rng.randf_range(-14, 14))
			_spawn_roomba(pos)
	# Floor 3: land on landings only
	for i in range(2):
		var spot := _random_landing_point(rng)
		spot.y = 12.15
		_spawn_roomba(spot)

func _random_landing_point(rng: RandomNumberGenerator) -> Vector3:
	var slab: Dictionary = FLOOR3_LANDINGS[rng.randi_range(0, FLOOR3_LANDINGS.size() - 1)]
	return Vector3(
		slab["x"] + rng.randf_range(-slab["w"] / 2.0 + 1.0, slab["w"] / 2.0 - 1.0),
		0.0,
		slab["z"] + rng.randf_range(-slab["d"] / 2.0 + 1.0, slab["d"] / 2.0 - 1.0)
	)

func _spawn_roomba(pos: Vector3) -> void:
	var roomba := CharacterBody3D.new()
	roomba.set_script(load("res://scripts/Roomba.gd"))
	roomba.position = pos
	_roomba_parent.add_child(roomba)

# ---------------- Swinging doors ----------------

func _build_doors() -> void:
	for spot in DOOR_SPOTS:
		var pivot := Node3D.new()
		pivot.position = spot["pos"]
		pivot.rotation.y = spot["rot"]
		add_child(pivot)

		var door := AnimatableBody3D.new()
		door.name = "DoorLeaf"
		pivot.add_child(door)

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.2, 2.2, 0.18)
		col.shape = shape
		col.position = Vector3(1.1, 1.1, 0)
		door.add_child(col)

		var leaf := MeshInstance3D.new()
		var leaf_mesh := BoxMesh.new()
		leaf_mesh.size = Vector3(2.2, 2.2, 0.15)
		leaf.mesh = leaf_mesh
		leaf.position = Vector3(1.1, 1.1, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.3, 0.2)
		mat.roughness = 0.7
		leaf.material_override = mat
		door.add_child(leaf)

		# Push zone slightly larger than the leaf for reliable hits
		var zone := Area3D.new()
		var zcol := CollisionShape3D.new()
		var zshape := BoxShape3D.new()
		zshape.size = Vector3(2.3, 2.3, 0.55)
		zcol.shape = zshape
		zcol.position = Vector3(1.1, 1.1, 0)
		zone.add_child(zcol)
		door.add_child(zone)
		zone.body_entered.connect(_on_door_hit.bind(zone))

		_door_pivots.append(pivot)

func _update_doors() -> void:
	# Swing each door on a 2s period; phase offset per pivot
	var t := Time.get_ticks_msec() / 1000.0
	for i in range(_door_pivots.size()):
		var pivot := _door_pivots[i]
		var swing := sin(t * PI + i * 0.9) * deg_to_rad(60.0)
		pivot.get_node("DoorLeaf").rotation.y = swing

func _on_door_hit(body: Node3D, zone: Area3D) -> void:
	if not body.is_in_group("players"):
		return
	# Knock along the door's facing so players get shoved aside
	if body.has_method("stun"):
		body.stun(DOOR_STUN)
	if "velocity" in body:
		var leaf: Node3D = zone.get_parent()
		var push: Vector3 = -leaf.global_transform.basis.z
		body.velocity += push * DOOR_KNOCKBACK
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("bonk", 1.0)
	var a11y := load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("DOOR!", 0.8)

# ---------------- Fire drill ----------------

func _build_strobes() -> void:
	# One red strobe per floor near the ceiling
	for floor_y in [0.0, 6.0, 12.0, 18.0]:
		var strobe := OmniLight3D.new()
		strobe.light_color = Color(1.0, 0.1, 0.05)
		strobe.light_energy = 0.0
		strobe.omni_range = 26.0
		strobe.shadow_enabled = false
		strobe.position = Vector3(0, floor_y + 3.4, 0)
		add_child(strobe)
		_strobe_lights.append(strobe)

func _update_fire_drill(delta: float) -> void:
	if fire_drill_active:
		fire_drill_elapsed += delta
		# 5 Hz strobe: energy toggles between 0 and 3
		var on := fmod(Time.get_ticks_msec() / 1000.0, 0.2) < 0.1
		for strobe in _strobe_lights:
			strobe.light_energy = 3.0 if on else 0.0
		if fire_drill_elapsed >= FIRE_DRILL_DURATION:
			_end_fire_drill()
	else:
		fire_drill_timer -= delta
		if fire_drill_timer <= 0.0:
			_start_fire_drill()

func _start_fire_drill() -> void:
	fire_drill_active = true
	fire_drill_elapsed = 0.0
	# Panic: +50% friction on every chair (temporary surface override)
	_panic_chairs.clear()
	for node in get_tree().get_nodes_in_group("players"):
		if node and is_instance_valid(node) and "friction" in node:
			node.set_meta("panic_mult", node.friction)
			node.friction = float(node.friction) * PANIC_FRICTION_MULT
			_panic_chairs.append(node)
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("boost", 0.7)
	var a11y := load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("FIRE DRILL! EVERYBODY PANIC!", 2.5)
	fire_drill_started.emit()

func _end_fire_drill() -> void:
	if not fire_drill_active:
		return
	fire_drill_active = false
	for strobe in _strobe_lights:
		strobe.light_energy = 0.0
	for chair in _panic_chairs:
		if chair and is_instance_valid(chair) and "friction" in chair:
			chair.friction = chair.get_meta("panic_mult", chair.friction)
			chair.remove_meta("panic_mult")
	_panic_chairs.clear()
	fire_drill_timer = FIRE_DRILL_INTERVAL
	fire_drill_ended.emit()

# ---------------- Falling debris (floor 3) ----------------

func _update_debris(delta: float) -> void:
	_debris_timer -= delta
	if _debris_timer > 0.0:
		return
	_debris_timer = randf_range(5.0, 8.0)
	var rng := RandomNumberGenerator.new()
	var spot := _random_landing_point(rng)
	spot.y = 15.2  # above the floor-3 landings, below floor 4's slab
	_spawn_debris(spot)

func _spawn_debris(pos: Vector3) -> void:
	var tile := AnimatableBody3D.new()
	tile.position = pos
	add_child(tile)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.12, 1.0)
	col.shape = shape
	tile.add_child(col)

	var mesh := MeshInstance3D.new()
	var mesh_shape := BoxMesh.new()
	mesh_shape.size = Vector3(1.0, 0.12, 1.0)
	mesh.mesh = mesh_shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.82, 0.75)
	mesh.material_override = mat
	tile.add_child(mesh)

	var warn := MeshInstance3D.new()
	var warn_mesh := BoxMesh.new()
	warn_mesh.size = Vector3(1.3, 0.02, 1.3)
	warn.mesh = warn_mesh
	warn.position = Vector3(0, -2.9, 0)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(1.0, 0.2, 0.1, 0.5)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.emission_enabled = true
	wmat.emission = Color(1.0, 0.15, 0.05)
	wmat.emission_energy_multiplier = 0.6
	warn.material_override = wmat
	tile.add_child(warn)

	# Warn (shake) then fall; shake respects reduced_motion
	var a11y := load("res://scripts/Accessibility.gd")
	var reduced: bool = a11y != null and a11y.reduced_motion_enabled()
	var tween := tile.create_tween()
	if reduced:
		pass
	else:
		tween.tween_method(
			func(v: float): tile.position.x = pos.x + sin(v * 40.0) * 0.05,
			0.0, DEBRIS_WARN_TIME, DEBRIS_WARN_TIME
		)
	tween.tween_callback(func():
		warn.queue_free()
		_begin_debris_fall(tile)
	)

func _begin_debris_fall(tile: AnimatableBody3D) -> void:
	var fall_speed := 9.0
	var hit_zone := Area3D.new()
	var zcol := CollisionShape3D.new()
	var zshape := BoxShape3D.new()
	zshape.size = Vector3(1.4, 1.0, 1.4)
	zcol.shape = zshape
	hit_zone.add_child(zcol)
	hit_zone.body_entered.connect(_on_debris_hit.bind(hit_zone))
	tile.add_child(hit_zone)
	tile.set_meta("zone", hit_zone)
	tile.set_meta("fall_speed", fall_speed)
	tile.set_meta("falling", true)

func _on_debris_hit(body: Node3D, zone: Area3D) -> void:
	if not body.is_in_group("players"):
		return
	var tile: AnimatableBody3D = zone.get_parent()
	if tile.get_meta("landed", false):
		return
	if body.has_method("stun"):
		body.stun(DEBRIS_STUN)
	if "velocity" in body:
		var away: Vector3 = body.global_position - tile.global_position
		away.y = 2.0
		body.velocity += away.normalized() * DEBRIS_KNOCKBACK
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("trap", 1.1)
	var fx := load("res://scripts/ImpactFX.gd")
	if fx:
		fx.burst(get_parent(), tile.global_position, Color(0.85, 0.8, 0.7), 12)
	var a11y := load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("DEBRIS!", 0.8)

func _process(delta: float) -> void:
	# Drive falling debris manually (metas set by _begin_debris_fall)
	for child in get_children():
		if child is AnimatableBody3D and child.get_meta("falling", false):
			var speed: float = child.get_meta("fall_speed", 9.0)
			child.position.y -= speed * delta
			# Land on the landing top (y ≈ 12.1); stop and fade out
			if child.position.y <= 12.12:
				child.position.y = 12.12
				child.set_meta("falling", false)
				child.set_meta("landed", true)
				var zone: Area3D = child.get_meta("zone", null)
				if zone and is_instance_valid(zone):
					zone.queue_free()
				var t := child.create_tween()
				t.tween_interval(2.0)
				t.tween_callback(child.queue_free)
