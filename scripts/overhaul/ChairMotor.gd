extends CharacterBody3D
const Command = preload("res://scripts/overhaul/DrivingCommand.gd")
const Profiles = preload("res://scripts/overhaul/HandlingProfiles.gd")
signal motor_event(kind: String, strength: float)
var profile_id := "balanced"
var profile: Dictionary
var facing := PI
var boost_charge := 100.0
var stun := 0.0
var immunity := 0.0
var boost_active := false
var drift_active := false
var enabled := true
var last_seq := 0
var coyote := 0.0
var jump_buffer := 0.0
var previous_grounded := false
var peak_fall := 0.0
var last_command: Dictionary = {}
var visual: Node3D
var visual_heading: Node3D
var spawn_point := Vector3.ZERO
var item_kind := ""
var is_local := false
var peer_id := 0
var finish_time := -1.0
var checkpoint := 0
var checkpoint_time := 0.0
var display_name := "Coworker"
var bot := false
var desired_speed := 1.0

func _ready() -> void:
	profile = Profiles.get_profile(profile_id)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(48)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.2
	col.shape = capsule
	add_child(col)
	visual_heading = Node3D.new()
	visual_heading.name = "VisualHeading"
	visual_heading.position.y = -0.6
	add_child(visual_heading)
	set_physics_process(false) # RaceDirector owns fixed-step order on every peer.

func step(raw: Dictionary, delta: float, effects := true) -> void:
	var cmd := Command.clean(raw)
	last_seq = int(cmd.seq)
	last_command = cmd
	immunity = maxf(0, immunity - delta)
	stun = maxf(0, stun - delta)
	var grounded := is_on_floor()
	coyote = 0.12 if grounded else maxf(0, coyote - delta)
	if cmd.hop:
		jump_buffer = 0.14
	else:
		jump_buffer = maxf(0, jump_buffer - delta)
	var move: Vector2 = cmd.move if enabled and stun <= 0 and finish_time < 0 else Vector2.ZERO
	var horizontal := Vector2(velocity.x, velocity.z)
	boost_active = enabled and stun <= 0 and bool(cmd.boost) and boost_charge > 0 and move.length() > 0.05
	drift_active = grounded and bool(cmd.drift) and horizontal.length() > 2.8 and move.length() > 0.1 and not boost_active
	var target_speed: float = float(profile.speed) * desired_speed
	var accel: float = float(profile.accel)
	if move.length() > 0.05:
		var turn: float = float(profile.steer) * (3.0 if drift_active else 8.0)
		facing = lerp_angle(facing, atan2(-move.x, -move.y), 1.0 - exp(-turn * delta))
		var authority := float(profile.steer) * (0.3 if drift_active else 1.0)
		if boost_active:
			target_speed *= 1.5 * float(profile.boost)
			boost_charge = maxf(0, boost_charge - 38.0 * delta)
			authority *= 0.65
		horizontal = horizontal.move_toward(move * target_speed, accel * authority * delta)
		if drift_active and horizontal.length() > 3.5:
			var angle := absf(horizontal.angle_to(move))
			if angle > 0.18:
				boost_charge = minf(100, boost_charge + 23.0 * delta)
	else:
		horizontal = horizontal.move_toward(Vector2.ZERO, accel * 0.65 * delta)
	if bool(cmd.drift) and not drift_active:
		horizontal = horizontal.move_toward(Vector2.ZERO, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	if not grounded:
		velocity.y -= 20.0 * delta
		peak_fall = minf(peak_fall, velocity.y)
	elif velocity.y < 0:
		velocity.y = -0.5
	if enabled and stun <= 0 and jump_buffer > 0 and coyote > 0:
		velocity.y = 7.2
		coyote = 0
		jump_buffer = 0
		if effects:
			motor_event.emit("hop", 1.0)
	move_and_slide()
	if is_on_floor() and not previous_grounded and peak_fall < -4:
		if effects:
			motor_event.emit("land", absf(peak_fall))
		peak_fall = 0
	previous_grounded = is_on_floor()

func present(delta: float) -> void:
	visual_heading.rotation.y = lerp_angle(visual_heading.rotation.y, facing, 1.0 - exp(-14.0 * delta))
	if visual and visual.has_method("animate"):
		visual.animate(delta, Vector2(velocity.x, velocity.z).length(), drift_active, boost_active, not is_on_floor(), stun)

func apply_hit(impulse: Vector3, seconds := 0.55) -> bool:
	if immunity > 0 or finish_time >= 0:
		return false
	velocity += impulse.limit_length(5.0) / float(profile.mass)
	stun = minf(0.75, seconds)
	immunity = 1.5
	motor_event.emit("hit", 1.0)
	return true

func respawn() -> void:
	position = spawn_point
	velocity = Vector3.ZERO
	immunity = 1.5
	boost_charge = maxf(35, boost_charge)
	motor_event.emit("respawn", 1.0)

func snapshot() -> Dictionary:
	return {"p": position, "v": velocity, "f": facing, "b": boost_charge, "s": stun, "i": immunity, "seq": last_seq, "cp": checkpoint, "finish": finish_time, "item": item_kind, "coyote": coyote, "jump": jump_buffer, "ground": previous_grounded, "fall": peak_fall}

func restore(state: Dictionary) -> void:
	position = state.p
	velocity = state.v
	facing = float(state.f)
	boost_charge = float(state.b)
	stun = float(state.s)
	immunity = float(state.i)
	last_seq = int(state.seq)
	checkpoint = int(state.cp)
	finish_time = float(state.finish)
	item_kind = str(state.item)
	coyote = float(state.get("coyote", 0))
	jump_buffer = float(state.get("jump", 0))
	previous_grounded = bool(state.get("ground", false))
	peak_fall = float(state.get("fall", 0))
