# SurfaceZone.gd — Phase 4A floor-area grip modifier (tile / ice / carpet).
# An invisible (or faintly tinted) Area3D slab lying on the floor. Players
# inside get their friction scaled: >1 grippier (carpet), <1 slippier (ice,
# polished tile). Self-contained; modes position + add_child it.
extends Area3D

## Friction multiplier handed to PlayerChair.set_surface().
## tile ≈ 0.55, ice ≈ 0.16, carpet ≈ 1.8 (design tuning values).
@export var friction_mult: float = 1.0

## Footprint of the zone (collision + tint quad). Set before add_child.
@export var zone_size: Vector3 = Vector3(4, 2.0, 4)

## Optional faint tint so fast patches read visually (set before add_child).
@export var tint: Color = Color(0.6, 0.8, 1.0, 0.10)

var _tint_mesh: MeshInstance3D

func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = zone_size
	col.shape = shape
	col.position = Vector3(0, zone_size.y * 0.5, 0)
	add_child(col)

	if tint.a > 0.01:
		_tint_mesh = MeshInstance3D.new()
		var quad := BoxMesh.new()
		quad.size = Vector3(zone_size.x, 0.02, zone_size.z)
		_tint_mesh.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(tint.r, tint.g, tint.b, 1.0)
		mat.emission_energy_multiplier = 0.25
		_tint_mesh.material_override = mat
		_tint_mesh.position = Vector3(0, -zone_size.y * 0.5 + 0.05, 0)
		add_child(_tint_mesh)

func _on_entered(body: Node3D) -> void:
	if body.is_in_group("players") and body.has_method("set_surface"):
		body.set_surface(friction_mult)

func _on_exited(body: Node3D) -> void:
	if body.is_in_group("players") and body.has_method("clear_surface"):
		body.clear_surface()
