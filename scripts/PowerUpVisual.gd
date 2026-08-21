# PowerUpVisual.gd — Phase 4B pickup with six kinds.
# Self-contained: builds its own mesh/glow/ring/label, handles pickup
# detection, sound, burst FX, and applies its effect in _on_body_entered.
# Modes only position and add_child it (and may pin `kind` before adding).
extends Area3D

enum Kind { COFFEE, ENERGY_DRINK, STAPLER, SPILL, PRINTER, EXTINGUISHER }

## Weighted spawn distribution (roadmap 4B): 60/15/10/8/4/3.
const WEIGHTS := {
	Kind.COFFEE: 60,
	Kind.ENERGY_DRINK: 15,
	Kind.STAPLER: 10,
	Kind.SPILL: 8,
	Kind.PRINTER: 4,
	Kind.EXTINGUISHER: 3,
}

const KIND_NAMES := {
	Kind.COFFEE: "COFFEE",
	Kind.ENERGY_DRINK: "ENERGY DRINK",
	Kind.STAPLER: "STAPLER ×3",
	Kind.SPILL: "SPILL ×2",
	Kind.PRINTER: "PRINTER",
	Kind.EXTINGUISHER: "EXTINGUISHER",
}

const KIND_COLORS := {
	Kind.COFFEE: Color(1.0, 0.55, 0.08),
	Kind.ENERGY_DRINK: Color(0.3, 1.0, 0.45),
	Kind.STAPLER: Color(1.0, 0.3, 0.3),
	Kind.SPILL: Color(1.0, 0.85, 0.15),
	Kind.PRINTER: Color(0.35, 0.6, 1.0),
	Kind.EXTINGUISHER: Color(0.95, 0.95, 1.0),
}

const EXTINGUISHER_RADIUS := 8.0
const EXTINGUISHER_STUN := 2.0
const PRINTER_BLIND_RADIUS := 8.0

var kind: Kind = Kind.COFFEE
var base_y: float = 0.0
var time_offset: float = 0.0
var glow_radius: float = 0.0
var glow_light: OmniLight3D

static func pick_weighted(rng: RandomNumberGenerator) -> int:
	var total := 0
	for w in WEIGHTS.values():
		total += w
	var roll := rng.randi_range(1, total)
	for key in WEIGHTS:
		roll -= WEIGHTS[key]
		if roll <= 0:
			return key
	return Kind.COFFEE

func _ready() -> void:
	base_y = position.y
	time_offset = float(get_instance_id() % 1000) * 0.01

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	col.shape = shape
	add_child(col)

	glow_light = OmniLight3D.new()
	glow_light.light_color = KIND_COLORS[kind]
	glow_light.light_energy = 0.8
	glow_light.omni_range = 3.5
	glow_light.shadow_enabled = false
	add_child(glow_light)

	_build_body()
	_build_ring()
	_build_label()

	body_entered.connect(_on_body_entered)

## Factory: create a pickup of the given kind, ready to position and add_child.
static func create(kind_value: int) -> Area3D:
	var pu := Area3D.new()
	pu.set_script(load("res://scripts/PowerUpVisual.gd"))
	pu.kind = kind_value
	return pu

func _build_body() -> void:
	match kind:
		Kind.COFFEE:
			_build_coffee()
		Kind.ENERGY_DRINK:
			_build_energy_drink()
		Kind.STAPLER:
			_build_stapler()
		Kind.SPILL:
			_build_spill()
		Kind.PRINTER:
			_build_printer()
		Kind.EXTINGUISHER:
			_build_extinguisher()

func _glow_material(base: Color, emission: Color, energy := 1.2) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.roughness = 0.45
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat

func _add_mesh(mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot_x := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.rotation.x = rot_x
	node.material_override = mat
	add_child(node)
	return node

func _build_coffee() -> void:
	var cup_mat := _glow_material(Color(0.92, 0.52, 0.12), Color(1.0, 0.34, 0.04))
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.34
	cup_mesh.bottom_radius = 0.27
	cup_mesh.height = 0.52
	_add_mesh(cup_mesh, cup_mat, Vector3.ZERO)

	var coffee_mesh := CylinderMesh.new()
	coffee_mesh.top_radius = 0.27
	coffee_mesh.bottom_radius = 0.27
	coffee_mesh.height = 0.035
	var coffee_mat := StandardMaterial3D.new()
	coffee_mat.albedo_color = Color(0.12, 0.045, 0.015)
	coffee_mat.roughness = 0.3
	_add_mesh(coffee_mesh, coffee_mat, Vector3(0, 0.27, 0))

	var handle_mesh := TorusMesh.new()
	handle_mesh.inner_radius = 0.11
	handle_mesh.outer_radius = 0.18
	_add_mesh(handle_mesh, cup_mat, Vector3(0.34, 0, 0), PI / 2.0)

func _build_energy_drink() -> void:
	var can_mat := _glow_material(Color(0.2, 0.75, 0.35), Color(0.15, 1.0, 0.35), 1.4)
	var can_mesh := CylinderMesh.new()
	can_mesh.top_radius = 0.16
	can_mesh.bottom_radius = 0.16
	can_mesh.height = 0.8
	_add_mesh(can_mesh, can_mat, Vector3(0, 0.1, 0))

	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 0.16
	top_mesh.bottom_radius = 0.16
	top_mesh.height = 0.03
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.85, 0.9, 0.85)
	top_mat.metallic = 0.8
	_add_mesh(top_mesh, top_mat, Vector3(0, 0.52, 0))

func _build_stapler() -> void:
	var mat := _glow_material(Color(0.75, 0.2, 0.2), Color(1.0, 0.2, 0.2), 1.1)
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.25, 0.32)
	_add_mesh(box, mat, Vector3(0, 0.05, 0))

	var nose := BoxMesh.new()
	nose.size = Vector3(0.5, 0.1, 0.14)
	_add_mesh(nose, mat, Vector3(0, 0.16, 0.12))

func _build_spill() -> void:
	var mat := _glow_material(Color(0.95, 0.85, 0.1, 0.8), Color(0.85, 0.7, 0.05), 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var puddle := CylinderMesh.new()
	puddle.top_radius = 0.5
	puddle.bottom_radius = 0.55
	puddle.height = 0.07
	_add_mesh(puddle, mat, Vector3(0, -0.15, 0))

func _build_printer() -> void:
	var mat := _glow_material(Color(0.55, 0.62, 0.85), Color(0.25, 0.5, 1.0), 1.0)
	var body := BoxMesh.new()
	body.size = Vector3(0.7, 0.28, 0.5)
	_add_mesh(body, mat, Vector3(0, 0.05, 0))

	var tray := BoxMesh.new()
	tray.size = Vector3(0.55, 0.05, 0.35)
	var tray_mat := StandardMaterial3D.new()
	tray_mat.albedo_color = Color(0.9, 0.92, 0.95)
	_add_mesh(tray, tray_mat, Vector3(0, 0.22, 0))

func _build_extinguisher() -> void:
	var mat := _glow_material(Color(0.85, 0.15, 0.15), Color(1.0, 0.95, 0.9), 1.3)
	var tank := CylinderMesh.new()
	tank.top_radius = 0.18
	tank.bottom_radius = 0.18
	tank.height = 0.6
	_add_mesh(tank, mat, Vector3(0, 0.05, 0))

	var nozzle := BoxMesh.new()
	nozzle.size = Vector3(0.08, 0.22, 0.08)
	var nozzle_mat := StandardMaterial3D.new()
	nozzle_mat.albedo_color = Color(0.2, 0.2, 0.22)
	_add_mesh(nozzle, nozzle_mat, Vector3(0.12, 0.42, 0))

func _build_ring() -> void:
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.6
	ring_mesh.outer_radius = 0.65
	ring.mesh = ring_mesh
	ring.rotation.x = PI / 2.0
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = KIND_COLORS[kind]
	ring_mat.emission_enabled = true
	ring_mat.emission = KIND_COLORS[kind]
	ring_mat.emission_energy_multiplier = 0.6
	ring.material_override = ring_mat
	ring.position.y = -0.1
	add_child(ring)

func _build_label() -> void:
	# Colorblind-safe: name the pickup, never rely on color alone.
	var label := Label3D.new()
	label.text = KIND_NAMES[kind]
	label.font_size = 40
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = KIND_COLORS[kind]
	label.no_depth_test = true
	label.position = Vector3(0, 1.0, 0)
	add_child(label)

func _process(delta: float) -> void:
	rotation.y += delta * 1.8
	position.y = base_y + sin(Time.get_ticks_msec() * 0.003 + time_offset) * 0.22

	glow_radius = (sin(Time.get_ticks_msec() * 0.004 + time_offset) * 0.5 + 0.5) * 0.4
	if glow_light:
		glow_light.omni_range = 3.0 + glow_radius
		glow_light.light_energy = 0.7 + glow_radius * 0.4

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("powerup", 1.2)
	var a11y = load("res://scripts/Accessibility.gd")

	var fx = load("res://scripts/ImpactFX.gd")
	if fx:
		fx.burst(get_parent(), global_position + Vector3.UP * 0.2, KIND_COLORS[kind], 16)

	match kind:
		Kind.COFFEE:
			if a11y:
				a11y.caption("COFFEE COLLECTED — BOOST READY", 1.2)
			if body.has_method("_start_boost"):
				body._start_boost()
		Kind.ENERGY_DRINK:
			if a11y:
				a11y.caption("ENERGY DRINK — SUPER BOOST!", 1.2)
			if body.has_method("_start_boost"):
				body._start_boost(1.5, 2.0)
		Kind.STAPLER:
			if body.has_method("give_item"):
				body.give_item(&"stapler", 3)
		Kind.SPILL:
			if body.has_method("give_item"):
				body.give_item(&"spill", 2)
		Kind.PRINTER:
			if a11y:
				a11y.caption("PRINTER JAM — PAPER EVERYWHERE", 1.4)
			_spawn_paper_planes()
			_blind_nearby(body)
		Kind.EXTINGUISHER:
			if a11y:
				a11y.caption("EXTINGUISHER — EVERYONE FREEZES", 1.4)
			_extinguish_nearby()
		_:
			pass

	queue_free()

func _spawn_paper_planes() -> void:
	# Cheap visual: six white slips flung outward, self-cleaning.
	for i in range(6):
		var slip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.02, 0.12)
		slip.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.96, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.85, 1.0)
		mat.emission_energy_multiplier = 0.7
		slip.material_override = mat
		get_parent().add_child(slip)
		slip.global_position = global_position + Vector3.UP * 0.3
		var angle := TAU * i / 6.0
		var dir := Vector3(cos(angle), 0.5, sin(angle)).normalized()
		var tween := slip.create_tween()
		tween.tween_property(slip, "global_position", slip.global_position + dir * 3.0, 0.8)
		tween.parallel().tween_property(slip, "rotation:y", angle * 3.0, 0.8)
		tween.tween_callback(slip.queue_free)

func _blind_nearby(collector: Node3D) -> void:
	# White screen flash for the local player when caught in the paper blast.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var flash_allowed := true
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y and not a11y.flash_effects_enabled():
		flash_allowed = false
	for node in tree.get_nodes_in_group("players"):
		if not (node and is_instance_valid(node)):
			continue
		if node.global_position.distance_to(global_position) > PRINTER_BLIND_RADIUS:
			continue
		if node != collector and node.has_method("stun"):
			node.stun(0.6)
		if node == collector:
			continue
		if flash_allowed and node.is_multiplayer_authority():
			_screen_flash(tree)
			if a11y:
				a11y.caption("BLINDED BY PAPER!", 1.0)

func _screen_flash(tree: SceneTree) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	tree.root.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.95, 0.97, 1.0, 0.85)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tween := rect.create_tween()
	tween.tween_property(rect, "color:a", 0.0, 1.0)
	tween.tween_callback(layer.queue_free)

func _extinguish_nearby() -> void:
	# Freeze everyone within radius — including the collector if they stand
	# in the blast (roadmap intent: area denial you can misuse).
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var fx = load("res://scripts/ImpactFX.gd")
	for node in tree.get_nodes_in_group("players"):
		if not (node and is_instance_valid(node)):
			continue
		if node.global_position.distance_to(global_position) > EXTINGUISHER_RADIUS:
			continue
		if node.has_method("stun"):
			node.stun(EXTINGUISHER_STUN)
		if fx:
			fx.burst(get_parent(), node.global_position + Vector3.UP * 0.4, Color(0.9, 0.95, 1.0), 10)
