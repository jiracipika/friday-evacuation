# StunFixture.gd — Phase 4A permanent stun hazard (water coolers, spills).
# A StaticBody3D with a soft Area3D stun bubble: bumping it stuns the player
# briefly with knockback, so obstacles gain tactile danger without new
# entity types. Visuals are procedural: caller sets style before add_child.
extends StaticBody3D

enum Style { WATER_COOLER, SPILL }

@export var style: Style = Style.WATER_COOLER
@export var stun_duration: float = 1.2
@export var knockback: float = 9.0

var _zone: Area3D

func _ready() -> void:
	# Solid core so players physically bump the fixture (coolers only —
	# spills are roll-through puddles with just the stun bubble)
	if style == Style.WATER_COOLER:
		var col := CollisionShape3D.new()
		var core := CylinderShape3D.new()
		core.radius = 0.45
		core.height = 1.7
		col.shape = core
		col.position = Vector3(0, 0.85, 0)
		add_child(col)

	_zone = Area3D.new()
	var zone_col := CollisionShape3D.new()
	var bubble := CylinderShape3D.new()
	bubble.radius = 0.85
	bubble.height = 1.9
	zone_col.shape = bubble
	zone_col.position = Vector3(0, 0.95, 0)
	_zone.add_child(zone_col)
	add_child(_zone)
	_zone.body_entered.connect(_on_bumped)

	_build_visual()

func _build_visual() -> void:
	match style:
		Style.WATER_COOLER:
			_build_cooler()
		Style.SPILL:
			_build_spill()

func _build_cooler() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.88, 0.92, 0.96)
	body_mat.roughness = 0.35

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.38
	body_mesh.bottom_radius = 0.42
	body_mesh.height = 1.1
	body.mesh = body_mesh
	body.position = Vector3(0, 0.55, 0)
	body.material_override = body_mat
	add_child(body)

	var jug := MeshInstance3D.new()
	var jug_mesh := CylinderMesh.new()
	jug_mesh.top_radius = 0.30
	jug_mesh.bottom_radius = 0.30
	jug_mesh.height = 0.5
	jug.mesh = jug_mesh
	jug.position = Vector3(0, 1.35, 0)
	var jug_mat := StandardMaterial3D.new()
	jug_mat.albedo_color = Color(0.35, 0.65, 1.0, 0.75)
	jug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jug_mat.emission_enabled = true
	jug_mat.emission = Color(0.2, 0.5, 1.0)
	jug_mat.emission_energy_multiplier = 0.5
	jug.material_override = jug_mat
	add_child(jug)

func _build_spill() -> void:
	var puddle := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.75
	mesh.bottom_radius = 0.8
	mesh.height = 0.06
	puddle.mesh = mesh
	puddle.position = Vector3(0, 0.04, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.75, 0.1, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.6, 0.05)
	mat.emission_energy_multiplier = 0.4
	puddle.material_override = mat
	add_child(puddle)

func _on_bumped(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	if body.has_method("stun"):
		body.stun(stun_duration)
	if "velocity" in body:
		var away: Vector3 = body.global_position - global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		body.velocity += away * knockback
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("trap", 1.2)
	var fx := load("res://scripts/ImpactFX.gd")
	if fx:
		var color := Color(0.4, 0.7, 1.0) if style == Style.WATER_COOLER else Color(0.95, 0.8, 0.2)
		fx.burst(get_parent(), global_position + Vector3.UP * 0.6, color, 18)
	var a11y := load("res://scripts/Accessibility.gd")
	if a11y:
		a11y.caption("WATER COOLER BUMP!" if style == Style.WATER_COOLER else "SPILL!", 1.0)
