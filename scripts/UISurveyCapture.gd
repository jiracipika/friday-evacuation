# UI survey captures v2: boots a scene, applies timed scripted inputs, movie-mode writes every frame.
# Usage: godot --path . --script scripts/UISurveyCapture.gd --write-movie DIR/f.png --fixed-fps 10 --quit-after N
# Env:
#   FE_UI_SCENE  = res:// scene path (default Main.tscn)
#   FE_UI_SCRIPT = "frame:action,frame:action" actions:
#                  accept (ui_accept event), click=TEXT (press button whose text contains TEXT),
#                  start_race, pause, finish_race, hide_controls, set_quality=low
extends SceneTree

var script_items: Array = []  # [{frame:int, action:String}]
var scene: Node
var fired: Dictionary = {}
var frame_num: int = 0

func _init() -> void:
	var s := OS.get_environment("FE_UI_SCRIPT")
	if s != "":
		for part in s.split(","):
			var kv := part.split(":")
			if kv.size() == 2:
				script_items.append({"frame": int(kv[0]), "action": kv[1]})

func _initialize() -> void:
	var scene_path := OS.get_environment("FE_UI_SCENE")
	if scene_path == "":
		scene_path = "res://scenes/Main.tscn"
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("cannot load " + scene_path)
		quit(1)
		return
	scene = packed.instantiate()
	root.add_child(scene)
	current_scene = scene

func _find_buttons(node: Node) -> Array:
	var out: Array = []
	if node is BaseButton:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_buttons(c))
	return out

func _press_text(txt: String) -> void:
	var needle := txt.to_lower()
	for b in _find_buttons(scene):
		if needle in b.text.to_lower():
			print("UISURVEY press: ", b.text)
			b.pressed.emit()
			return
	print("UISURVEY no button matching: ", txt)

func _send_accept() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventAction.new()
	ev2.action = "ui_accept"
	ev2.pressed = false
	Input.parse_input_event(ev2)
	print("UISURVEY ui_accept sent")

func _do(action: String) -> void:
	if action.begins_with("click="):
		_press_text(action.substr(6))
	elif action == "accept":
		_send_accept()
	elif action == "start_race":
		if scene.has_method("start_race"):
			scene.call("start_race")
			print("UISURVEY start_race called")
	elif action == "real_pause":
		var ev := InputEventAction.new()
		ev.action = "pause"
		ev.pressed = true
		Input.parse_input_event(ev)
		var ev2 := InputEventAction.new()
		ev2.action = "pause"
		ev2.pressed = false
		Input.parse_input_event(ev2)
		print("UISURVEY real pause event sent")
	elif action == "pause":
		var pm := scene.get_node_or_null("PauseMenu")
		if pm and pm.has_method("open"):
			pm.call("open")
		elif pm:
			pm.visible = true
		print("UISURVEY pause attempted")
	elif action == "finish_race":
		for m in ["_finish_race", "finish_race", "_end_race", "_on_race_finished"]:
			if scene.has_method(m):
				scene.call(m)
				print("UISURVEY finish via ", m)
				return
	elif action == "hide_controls":
		var c := scene.get_node_or_null("ControlsOverlay")
		if c:
			c.visible = false
	elif action.begins_with("wait="):
		pass

func _process(_delta: float) -> bool:
	frame_num += 1
	for item in script_items:
		if item.frame == frame_num and not fired.has(frame_num):
			fired[frame_num] = true
			_do(item.action)
	return false
