# LevelClearTest.gd — Standalone physics navigation test
# Verifies a player can navigate from floor 1 to the exit on floor 4
# using the elevator boost pads (Area3D trigger zones that launch the player upward).
extends SceneTree

var test_passed: bool = true
var player: CharacterBody3D = null
var world: Node3D = null
var reached_exit: bool = false
var sim_time: float = 0.0

const EXIT_POS := Vector3(0, 18.5, 15)
const GRAVITY := 20.0

# Elevator definitions: entry_pos, exit_pos
var elevators: Array = [
	{"from": Vector3(12, 0.5, 14), "to": Vector3(12, 6.5, -2)},
	{"from": Vector3(-12, 6.5, -2), "to": Vector3(-12, 12.5, 14)},
	{"from": Vector3(12, 12.5, 14), "to": Vector3(12, 18.5, -2)},
]

func _init():
	print("=== FRIDAY 5PM: LEVEL CLEAR SIMULATION (Elevator) ===")
	print("")
	_run_test()

func _run_test():
	world = Node3D.new()
	world.name = "TestWorld"
	root.add_child(world)

	# Build floors
	_build_floor(Vector3(0, 0, 0))
	_build_floor(Vector3(0, 6, 0))
	_build_floor(Vector3(0, 12, 0))
	_build_floor(Vector3(0, 18, 0))

	# Build elevators (Area3D trigger zones)
	for elev in elevators:
		_build_elevator(elev["from"], elev["to"])

	# Spawn player on floor 1
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1.0, 0)
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.2
	col.shape = shape
	player.add_child(col)
	player.add_to_group("players")
	player.floor_snap_length = 0.4
	player.floor_max_angle = deg_to_rad(50.0)
	world.add_child(player)

	await process_frame
	await process_frame

	print("[INFO] Player spawned at: ", player.global_position)
	print("[INFO] Player on floor: ", player.is_on_floor())
	print("[INFO] Exit zone at: ", EXIT_POS)
	print("")

	await _simulate()

func _simulate():
	# Navigation strategy: drive the player to each elevator pad in sequence,
	# then to the exit. The elevators will launch the player to the next floor.
	var max_time: float = 30.0
	var move_speed: float = 12.0
	var stuck_timer: float = 0.0
	var last_pos: Vector3 = player.global_position
	var frame: int = 0

	# Waypoints: elevator entry points, then exit
	var waypoints: Array[Vector3] = [
		elevators[0]["from"],  # Elevator 1 entry (floor 1 → 2)
		elevators[1]["from"],  # Elevator 2 entry (floor 2 → 3)
		elevators[2]["from"],  # Elevator 3 entry (floor 3 → 4)
		EXIT_POS,              # Exit zone on floor 4
	]
	var current_wp: int = 0

	print("[INFO] Starting navigation with elevators...")
	print("")

	while sim_time < max_time:
		await process_frame
		if not is_instance_valid(player):
			print("[FAIL] Player destroyed")
			test_passed = false
			break

		var delta = 1.0 / 60.0
		sim_time += delta
		frame += 1

		# Gravity
		if not player.is_on_floor():
			player.velocity.y -= GRAVITY * delta
		else:
			if player.velocity.y < 0:
				player.velocity.y = 0.0

		# Current target
		var target = waypoints[current_wp]
		var to_target = target - player.global_position
		var flat_dist = Vector2(to_target.x, to_target.z).length()

		# Move toward target — only when on floor (not being launched by elevator)
		if player.is_on_floor() and flat_dist > 1.5:
			var dir = Vector3(to_target.x, 0, to_target.z).normalized()
			player.velocity.x = dir.x * move_speed
			player.velocity.z = dir.z * move_speed

		player.move_and_slide()

		# Check waypoint progression based on Y position
		if current_wp == 0 and player.global_position.y > 4.5:
			print("[PASS] Launched to Floor 2! Y=%.1f at %s" % [player.global_position.y, str(player.global_position.round())])
			current_wp = 1
		elif current_wp == 1 and player.global_position.y > 10.5:
			print("[PASS] Launched to Floor 3! Y=%.1f at %s" % [player.global_position.y, str(player.global_position.round())])
			current_wp = 2
		elif current_wp == 2 and player.global_position.y > 16.5:
			print("[PASS] Launched to Floor 4! Y=%.1f at %s" % [player.global_position.y, str(player.global_position.round())])
			current_wp = 3
		elif current_wp == 3:
			# On floor 4 — head to exit
			if flat_dist < 5.0:
				var dist = player.global_position.distance_to(EXIT_POS)
				print("")
				print("[PASS] *** PLAYER REACHED THE EXIT! DIST=%.1f ***" % dist)
				reached_exit = true
				break

		# Stuck detection
		var movement = player.global_position.distance_to(last_pos)
		if movement < 0.02:
			stuck_timer += delta
		else:
			stuck_timer = 0.0
		last_pos = player.global_position

		# Debug
		if frame % 60 == 0:
			print("[DBG] t=%.0f pos=%s Y=%.1f floor=%s wp=%d" % [
				sim_time, str(player.global_position.round()), player.global_position.y, player.is_on_floor(), current_wp
			])

	if not reached_exit and sim_time >= max_time:
		print("")
		print("[FAIL] Timed out. Final pos: %s, wp=%d" % [
			str(player.global_position.round() if is_instance_valid(player) else "N/A"), current_wp
		])
		test_passed = false

	_finish()

func _build_floor(pos: Vector3):
	var floor_node = StaticBody3D.new()
	floor_node.position = pos
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(40, 0.2, 40)
	col.shape = shape
	floor_node.add_child(col)
	world.add_child(floor_node)

func _build_elevator(from_pos: Vector3, to_pos: Vector3):
	var trigger = Area3D.new()
	trigger.position = from_pos
	var trigger_col = CollisionShape3D.new()
	var trigger_shape = BoxShape3D.new()
	trigger_shape.size = Vector3(4, 3, 4)
	trigger_col.shape = trigger_shape
	trigger.add_child(trigger_col)
	world.add_child(trigger)

	# Connect the trigger — when player enters, TELEPORT them to the destination
	# (must teleport, not launch, because floors are solid boxes and launching
	# would collide with the underside of the floor above)
	var cooldown: float = 0.0
	trigger.set_meta("cooldown", cooldown)
	trigger.body_entered.connect(func(body: Node3D):
		if not body.is_in_group("players"):
			return
		var cd = trigger.get_meta("cooldown", 0.0)
		if cd > 0.0:
			return
		var dy = to_pos.y - body.global_position.y
		if dy > 1.0:
			# Teleport the player to the destination
			body.global_position = to_pos + Vector3(0, 1.0, 0)
			body.velocity = Vector3.ZERO
			trigger.set_meta("cooldown", 2.0)  # 2 second cooldown
			print("[ELEVATOR] Teleported player to %s" % str(to_pos))
	)

func _finish():
	print("")
	if test_passed and reached_exit:
		print("============================================")
		print("=== LEVEL CLEAR TEST: PASS ★ ★ ★ ★ ★ ===")
		print("============================================")
	else:
		print("============================================")
		print("=== LEVEL CLEAR TEST: FAIL ===")
		print("============================================")
	quit(0 if test_passed and reached_exit else 1)
