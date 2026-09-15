# Graphical entry acceptance: actual mouse/key events, captures, real scene swap.
# Run without --headless; --test-mode isolates saved player preferences.
extends SceneTree

var failures := 0
var checks := 0
var main: Control
const OUTPUT := "/tmp/fe-entry-evidence"

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print("[%s] %s" % ["PASS" if value else "FAIL", label])

func frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func screenshot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png"))
	check(result == OK, "capture " + label)

func click(button: Control) -> void:
	if not is_instance_valid(button):
		check(false, "click target exists")
		return
	var pos := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pos
		event.global_position = pos
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await frames()

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await frames()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await frames(10)
	check(not main.has_node("SplashLayer"), "home opens without splash")
	await screenshot("home-1280")
	for target in ["other_modes_button", "customize_button", "office_button"]:
		await click(main.get(target))
		check(is_instance_valid(main.get("open_subview")), "mouse opens " + target)
		await screenshot(target + "-1280")
		await key(KEY_ESCAPE)
		check(main.get("open_subview") == null, "Escape closes " + target)
		check(root.gui_get_focus_owner() == main.get(target), "focus restored " + target)
	for size in [Vector2i(960, 540), Vector2i(640, 360), Vector2i(390, 844)]:
		root.size = size
		root.content_scale_size = size
		await frames(10)
		await screenshot("home-%d" % size.x)
		var primary: Control = main.get("play_button")
		primary.grab_focus()
		await frames()
		check(primary.get_global_rect().end.x <= size.x + 1, "primary fits width %d" % size.x)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await frames(8)
	main.get("play_button").grab_focus()
	await key(KEY_ENTER)
	var arrived := false
	for i in 900:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/Evacuation.tscn" and get_nodes_in_group("loading_overlay").is_empty():
			arrived = true
			break
	check(arrived, "Enter actually loads Evacuation and removes overlay")
	if arrived:
		check(current_scene.get("local_player") != null, "real player spawned")
		await screenshot("evacuation-arrival")
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await frames(3)
	print("EntryAcceptanceTest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
