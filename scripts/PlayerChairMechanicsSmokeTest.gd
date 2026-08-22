extends SceneTree

var test_root: Node3D
var chair: CharacterBody3D
var camera: Camera3D
var phase := 0
var elapsed := 0.0
var interaction_count := 0
var failures := PackedStringArray()
var disabled_launch_start := Vector3.ZERO

func _init() -> void:
	_setup.call_deferred()

func _setup() -> void:
	test_root = Node3D.new()
	root.add_child(test_root)
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.2, 30)
	floor_shape.shape = box
	floor.add_child(floor_shape)
	test_root.add_child(floor)

	camera = Camera3D.new()
	camera.position = Vector3(0, 7, 10)
	test_root.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true

	chair = load("res://scenes/PlayerChair.tscn").instantiate()
	chair.position = Vector3(0, 0.8, 0)
	test_root.add_child(chair)
	chair.interaction_requested.connect(func(): interaction_count += 1)
	Input.action_press("move_forward")

func _process(delta: float) -> bool:
	if not chair or not is_instance_valid(chair):
		return false
	elapsed += delta
	match phase:
		0:
			if elapsed >= 0.35:
				Input.action_release("move_forward")
				var expected_forward := -camera.global_transform.basis.z
				expected_forward.y = 0.0
				expected_forward = expected_forward.normalized()
				var horizontal := Vector3(chair.velocity.x, 0, chair.velocity.z)
				_check(horizontal.dot(expected_forward) > 2.0, "W accelerates along camera forward")
				_check(chair.get_facing_direction().dot(expected_forward) > 0.9, "chair facing matches travel direction")
				chair.velocity = Vector3.ZERO
				chair.smooth_facing = PI * 0.5
				chair._start_boost()
				_check(chair.velocity.x < -20.0 and absf(chair.velocity.z) < 1.0, "stationary boost follows visual facing")
				chair.global_position.y = 6.8
				chair._drop_trap()
				var dropped_trap: Area3D
				for child in test_root.get_children():
					if child is Area3D and "owner_id" in child:
						dropped_trap = child
				_check(dropped_trap != null and dropped_trap.global_position.y > 6.0, "trap drops on the current floor instead of floor one")
				chair.suppress_action_jump = true
				chair.velocity.y = 0.0
				chair.trigger_mobile_action(&"action")
				_check(interaction_count == 1, "mobile action emits interaction when jump is repurposed")
				_check(is_zero_approx(chair.velocity.y), "repurposed mobile action does not jump")
				disabled_launch_start = chair.global_position
				chair.set_can_move(false)
				chair.velocity = Vector3(10.0, 8.0, 0.0)
				phase = 1
				elapsed = 0.0
		1:
			if elapsed >= 0.25:
				_check(chair.global_position.x > disabled_launch_start.x + 1.0, "disabled controls still simulate explicit launch impulses")
				_report()
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] " + label)
	else:
		failures.append(label)
		printerr("[FAIL] " + label)

func _report() -> void:
	Input.action_release("move_forward")
	if test_root and is_instance_valid(test_root):
		test_root.free()
	if failures.is_empty():
		print("=== PLAYER CHAIR MECHANICS SMOKE TEST PASSED ===")
		quit(0)
	else:
		printerr("=== PLAYER CHAIR MECHANICS SMOKE TEST FAILED (%d) ===" % failures.size())
		quit(1)
