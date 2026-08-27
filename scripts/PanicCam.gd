# PanicCam.gd — picture-in-picture of YOUR rider's face during boosts/stuns.
#
# Lethal-company-style comedy payoff for the chase-cam problem: the default
# camera sees the rider's back, so the googly eyes and face decals only land
# in replays/overtakes. This mounts a small SubViewport inset (top-right by
# default) with a dedicated Camera3D staring at the local rider's head, and
# raises its intensity while the chair is boosting or stunned.
#
# Mount (one line, from the mode script after local_player exists):
#   PanicCam.mount(self, local_player)
#
# Quality-aware: skips mounting entirely on LOW graphics (mobile perf).
extends Control

const INSET_SIZE := Vector2(150, 150)
const MARGIN := 14.0

var target_rider: Node3D = null
var viewport_container: SubViewportContainer
var sub_viewport: SubViewport
var face_camera: Camera3D
var _pulse_t := 0.0

static func mount(parent: Node, rider: Node3D) -> Node:
	if parent == null or rider == null:
		return null
	# Quality gate: LOW preset never pays for the extra viewport. Read the
	# persisted setting directly (Settings.gd exposes no static getter).
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	var quality: int = int(cfg.get_value("graphics", "quality", 1))
	if quality == 0:
		return null
	for child in parent.get_children():
		if child is Control and child.get_script() == load("res://scripts/PanicCam.gd"):
			child.target_rider = rider
			return child
	var cam: Control = new()
	cam.target_rider = rider
	cam.name = "PanicCam"
	parent.add_child(cam)
	return cam

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = INSET_SIZE
	position = Vector2(-INSET_SIZE.x - MARGIN, MARGIN)

	viewport_container = SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)

	sub_viewport = SubViewport.new()
	sub_viewport.size = INSET_SIZE
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(sub_viewport)

	face_camera = Camera3D.new()
	face_camera.fov = 42.0
	sub_viewport.add_child(face_camera)

	# Own ambient light so the face reads even in dark corridors.
	var lamp := DirectionalLight3D.new()
	lamp.light_energy = 0.7
	lamp.rotation_degrees = Vector3(-35, 25, 0)
	sub_viewport.add_child(lamp)

func _process(delta: float) -> void:
	if target_rider == null or not is_instance_valid(target_rider):
		visible = false
		return
	var head_pos: Vector3 = target_rider.global_position + Vector3.UP * 1.5
	if face_camera == null:
		return
	# Camera floats slightly ahead-left of the head, always aimed at it,
	# inheriting the rider's yaw so the face stays centered while spinning.
	var yaw: float = 0.0
	if "model_parent" in target_rider and target_rider.model_parent:
		yaw = target_rider.model_parent.rotation.y
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	face_camera.global_position = head_pos + back * 0.85 + Vector3(0.12, 0.08, 0)
	face_camera.look_at(head_pos)

	# Intensity pulse while boosting/stunned: mild scale bob on the inset.
	_pulse_t += delta
	var boosting: bool = "is_boosting" in target_rider and target_rider.is_boosting
	var stunned: bool = "is_stunned" in target_rider and target_rider.is_stunned > 0.0
	var excitement := 1.0 + (0.06 * sin(_pulse_t * 9.0) if (boosting or stunned) else 0.0)
	scale = Vector2(excitement, excitement)
	modulate.a = 0.92
