# Menu screen capture: boots FE_UI_SCENE, runs scripted actions, saves PNG snapshots.
# Usage: godot --path . --script scripts/MenuSnap.gd -- --FE_SHOTS=/tmp/dir --FE_WAIT=60
# Env FE_UI_SCENE = scene path (default Main.tscn)
# Env FE_SCRIPT = "25:label:click=TEXT;60:label2:action" (frames RELATIVE to boot_wait)
# Actions: click=TEXT, pause, real_pause, finish_race, hide_controls, none
extends SceneTree

var shots_dir := "/tmp/fe-ui"
var script_items: Array = []
var fired := {}
var frame_num := 0
var scene: Node
var boot_wait := 40
var done_count := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() == 2:
			var key := kv[0].lstrip("-")
			if key == "FE_SHOTS":
				shots_dir = kv[1]
			elif key == "FE_WAIT":
				boot_wait = int(kv[1])
	var s := OS.get_environment("FE_SCRIPT")
	if s != "":
		for part in s.split(";"):
			var seg := part.split(":")
			if seg.size() == 3:
				script_items.append({"frame": boot_wait + int(seg[0]), "label": seg[1], "action": seg[2]})
	var scene_path := OS.get_environment("FE_UI_SCENE")
	if scene_path == "":
		scene_path = "res://scenes/Main.tscn"
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("cannot load " + scene_path)
		quit(1)
		return
	scene = packed.instantiate()
	root.size = Vector2i(1280, 720)
	root.add_child(scene)
	current_scene = scene
	DirAccess.make_dir_recursive_absolute(shots_dir)

func _press_text(txt: String) -> void:
	for b in _find_buttons(scene):
		if txt.to_lower() in b.text.to_lower():
			b.pressed.emit()
			print("SNAP clicked ", b.text)
			return
	print("SNAP no button matching '", txt, "'")

func _find_buttons(node: Node) -> Array:
	var out: Array = []
	if node is BaseButton:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_buttons(c))
	return out

func _do(action: String) -> void:
	if action == "none" or action == "":
		return
	if action.begins_with("click="):
		_press_text(action.substr(6))
	elif action == "real_pause":
		for pressed in [true, false]:
			var ev := InputEventAction.new()
			ev.action = "pause"
			ev.pressed = pressed
			Input.parse_input_event(ev)
	elif action == "pause":
		var pm := scene.get_node_or_null("PauseMenu")
		if pm and pm.has_method("open"):
			pm.call("open")
		elif pm:
			pm.visible = true
	elif action == "finish_race":
		for m in ["_finish_race", "finish_race", "_end_race"]:
			if scene.has_method(m):
				scene.call(m)
				return
	elif action == "hide_controls":
		var c := scene.get_node_or_null("ControlsOverlay")
		if c:
			c.visible = false

func _process(_delta: float) -> bool:
	frame_num += 1
	for item in script_items:
		if item.frame == frame_num and not fired.has(item.label):
			fired[item.label] = true
			_do(item.action)
		elif item.frame + 2 == frame_num and fired.has(item.label) and not item.has("saved"):
			item["saved"] = true
			_save(item.label)
	if not script_items.is_empty() and done_count >= script_items.size():
		quit(0)
		return true
	return false

func _save(label: String) -> void:
	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		push_error("empty capture " + label)
		done_count += 1
		return
	var err := img.save_png(shots_dir + "/" + label + ".png")
	print("SAVED ", label, " err=", err, " ", img.get_size())
	done_count += 1
