extends SceneTree
const Motor = preload("res://scripts/overhaul/ChairMotor.gd")
const Command = preload("res://scripts/overhaul/DrivingCommand.gd")
const Kit = preload("res://scripts/overhaul/OfficeKit.gd")
var failures: Array = []
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, words: String) -> void:
	if not condition: failures.append(words)
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	Kit.solid(world, Vector3(500, 0.3, 500), Vector3(0, -0.15, 0), Color.GRAY)
	var motors: Array = []
	for profile in ["balanced", "agile", "heavy"]:
		var actor := Motor.new()
		actor.profile_id = profile
		actor.position = Vector3(0, 0.7, motors.size() * 3)
		world.add_child(actor)
		motors.append(actor)
	for i in 210:
		await physics_frame
		for actor in motors:
			actor.step(Command.make(Vector2.RIGHT, true), 1.0 / 60)
	for actor in motors:
		check(actor.boost_charge == 0, "Boost is bounded and drains for " + actor.profile_id)
		check(actor.position.x > 20 and actor.position.x < 40, "Handling speed bounded for " + actor.profile_id)
		actor.velocity = Vector3(6, 0, 0)
	for i in 60:
		await physics_frame
		for actor in motors:
			actor.step(Command.make(Vector2.DOWN, false, true), 1.0 / 60)
	for actor in motors:
		check(actor.boost_charge > 5 and actor.boost_charge <= 23, "Skilled drift recharges for " + actor.profile_id)
		check(actor.apply_hit(Vector3(100, 0, 0), 5), "First impact lands")
		check(not actor.apply_hit(Vector3(100, 0, 0), 5), "Impact grace prevents stun locks")
		check(actor.stun <= 0.75, "Stun duration is bounded")
		actor.stun = 0
		actor.immunity = 0
	for i in 45:
		await physics_frame
		for actor in motors:
			actor.step(Command.make(), 1.0 / 60)
	for actor in motors:
		actor.step(Command.make(Vector2.ZERO, false, false, true), 1.0 / 60)
		check(actor.velocity.y > 6, "Grounded hop launches")
		var state: Dictionary = actor.snapshot()
		actor.position += Vector3.ONE * 20
		actor.restore(state)
		check(actor.position == state.p and actor.coyote == state.coyote, "Reconciliation restores motor state")
	print("OFFICE_MOTOR_CHECK failures=", failures)
	world.free()
	quit(0 if failures.is_empty() else 1)
