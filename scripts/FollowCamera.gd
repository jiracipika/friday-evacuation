# FollowCamera.gd — shared chase camera for secondary modes (Hauled,
# Shop & Seek, Pizza Colony). Fixes the "unwinnable" feel caused by the old
# static camera at (0,8,15): camera-relative input meant W drove the player
# away from objectives, and carried cargo trailed toward -Z.
#
# Usage from a mode's _process(delta):
#   FollowCamera.update(camera, target_node, delta)
# It follows the visible chair facing (matches Evacuation's feel), stays
# below ceiling height, and snaps on large teleports.
class_name FollowCamera
extends RefCounted

const DISTANCE := 8.0
const HEIGHT := 4.5
const LOOK_HEIGHT := 1.0
const SNAP_DISTANCE := 6.0

static var _last_target_pos: Dictionary = {}  # camera instance id -> Vector3

static func update(camera: Camera3D, target: Node3D, delta: float) -> void:
	if camera == null or target == null or not is_instance_valid(target):
		return
	var pos: Vector3 = target.global_position
	# Facing: PlayerChair exposes get_facing_direction(); fall back to -Z basis.
	var fwd := Vector3(0, 0, -1)
	if target.has_method("get_facing_direction"):
		fwd = target.get_facing_direction()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)

	# Camera orbit (mouse look + right stick), driven by InputPrefs. The
	# yaw offset is global match state; Evacuation resets it on race start.
	var yaw := 0.0
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs:
		if InputMap.has_action("camera_right") and InputMap.has_action("camera_left"):
			var strength: float = Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
			if absf(strength) > 0.01:
				prefs.apply_stick(strength, delta)
		yaw = prefs.wrapped_yaw()

	var cam_dir := fwd.rotated(Vector3.UP, yaw)
	var desired := pos - cam_dir * DISTANCE + Vector3.UP * HEIGHT
	var look := pos + Vector3.UP * LOOK_HEIGHT
	if absf(yaw) > 0.0001:
		look = pos + (look - pos).rotated(Vector3.UP, yaw)

	# Snap on teleports/large jumps instead of sweeping across the arena.
	var key := camera.get_instance_id()
	var last: Vector3 = _last_target_pos.get(key, pos)
	if last.distance_to(pos) > SNAP_DISTANCE:
		camera.global_position = desired
		camera.look_at(look)
		_last_target_pos[key] = pos
		return
	_last_target_pos[key] = pos

	var lerp_w := 1.0 - exp(-8.0 * delta)
	camera.global_position = camera.global_position.lerp(desired, lerp_w)
	if not camera.global_position.is_equal_approx(look):
		camera.look_at(look)

## Mouse-look event hook for modes using FollowCamera. Call from the
## mode's _unhandled_input FIRST: FollowCamera.handle_mouse_input(event),
## and keep handling only when it returns false (i.e. not consumed).
static func handle_mouse_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var prefs = load("res://scripts/InputPrefs.gd")
		if prefs:
			prefs.apply_mouse_motion(event)
			return true
	return false
