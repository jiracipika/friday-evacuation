extends RefCounted
const Command = preload("res://scripts/overhaul/DrivingCommand.gd")
var personality := 0
var difficulty := 1
var stuck := 0.0
var previous_position := Vector3.ZERO
var reaction := 0.0
var elapsed := 0.0

func drive(actor: CharacterBody3D, course: Resource, delta: float) -> Dictionary:
	elapsed += delta
	var target_index := mini(actor.checkpoint + 1, course.points.size() - 1)
	var target: Vector3 = course.points[target_index]
	var shortcut := false
	var zone := mini(3, actor.checkpoint / 8)
	if difficulty == 2 and personality % 2 == zone % 2 and actor.checkpoint % 8 in [1, 2]:
		target = Vector3(0, course.points[target_index].y, zone * 68.0 - 3)
		shortcut = true
	var offset := sin(float(personality) * 2.4 + elapsed * 0.15) * 0.45
	target.z += offset
	var direction := Vector2(target.x - actor.position.x, target.z - actor.position.z)
	var distance := direction.length()
	if actor.position.distance_to(previous_position) < 0.005 and actor.enabled:
		stuck += delta
	else:
		stuck = maxf(0, stuck - delta * 2)
	previous_position = actor.position
	var straight := true
	if target_index < course.points.size() - 1:
		var next: Vector3 = course.points[target_index + 1] - target
		straight = absf(direction.angle_to(Vector2(next.x, next.z))) < 0.35
	actor.desired_speed = [0.64, 0.79, 0.94][clampi(difficulty, 0, 2)]
	if distance < 5 and not straight:
		actor.desired_speed *= 0.65
	# Rival errors affect only steering; no teleporting or extra grip.
	if difficulty == 0:
		direction += Vector2(sin(elapsed + personality), cos(elapsed * 0.7)) * 0.25
	var hop := stuck > 1.3 and actor.is_on_floor()
	if shortcut and actor.is_on_floor() and (absf(actor.position.z - (zone * 68.0 - 9.5)) < 3 or (absf(actor.position.x) < 4 and absf(actor.position.z - (zone * 68.0 - 3)) < 5)):
		hop = true
	if hop:
		stuck = 0
	return Command.make(direction.normalized(), straight and distance > 10 and actor.boost_charge > 45, not straight and distance < 6 and actor.velocity.length() > 8, hop, actor.item_kind != "" and int(elapsed + personality) % 11 == 0)
