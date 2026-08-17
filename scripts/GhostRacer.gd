# GhostRacer.gd — translucent pace-setter for single-player Evacuation.
# Races a fixed course (start → floor waypoints → exit) over a target time.
# Purely visual + ranking pressure: it never collides with the player and
# joins finish_order so the results screen can show beat/lost vs the ghost.
class_name GhostRacer
extends Node3D

## Target seconds for the ghost to complete the course. Paced slightly
## slower than a skilled run (~70-80s) so beating it is an achievement.
@export var target_time: float = 75.0

var elapsed: float = 0.0
var finished: bool = false
var waypoints: Array[Vector3] = []
var ghost_name: String = "GHOST"
var _progress: float = 0.0
var _mesh_parent: Node3D

signal ghost_finished(name: String, time: float)

func setup(p_waypoints: Array[Vector3], display_name: String = "GHOST", pace_time: float = 75.0) -> void:
	waypoints = p_waypoints
	ghost_name = display_name
	target_time = pace_time
	_build_visual()

func _build_visual() -> void:
	# Simple translucent capsule + face plane — reads as "not a real player".
	var capsule := MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.radius = 0.45
	cap_mesh.height = 1.4
	capsule.mesh = cap_mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.75, 1.0, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.55, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.no_depth_test = false
	capsule.material_override = mat
	capsule.position = Vector3(0, 0.9, 0)
	add_child(capsule)
	_mesh_parent = capsule

	if not waypoints.is_empty():
		position = waypoints[0]

func _process(delta: float) -> void:
	if finished or waypoints.size() < 2:
		return
	elapsed += delta
	_progress = clampf(elapsed / target_time, 0.0, 1.0)
	# Ease-in-out pacing so the ghost feels like it accelerates/settles
	var eased := _progress * _progress * (3.0 - 2.0 * _progress)
	position = _sample_course(eased)
	if elapsed >= target_time:
		finished = true
		emit_signal("ghost_finished", ghost_name, elapsed)

## Map scalar progress (0..1) onto the waypoint polyline.
func _sample_course(t: float) -> Vector3:
	var total := waypoints.size() - 1
	if total <= 0:
		return waypoints[0]
	var scaled := t * total
	var idx := int(scaled)
	if idx >= total:
		return waypoints[total]
	var frac := scaled - idx
	return waypoints[idx].lerp(waypoints[idx + 1], frac)

## Where the ghost is along the course right now (0..1, eased).
func get_progress() -> float:
	return _progress * _progress * (3.0 - 2.0 * _progress)
