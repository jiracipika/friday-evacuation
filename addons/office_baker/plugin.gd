@tool
extends EditorPlugin
var wait := 0.0
var phase := 0
var target := ""

func _enter_tree() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args[0] != "--bake-office":
		set_process(false)
		return
	target = "res://scenes/overhaul/baked/%s.scn" % args[1]

func _process(delta: float) -> void:
	wait += delta
	if wait < 4:
		return
	wait = 0
	if phase == 0:
		EditorInterface.open_scene_from_path(target)
		phase = 1
	elif phase == 1:
		var scene := EditorInterface.get_edited_scene_root()
		if not scene or scene.scene_file_path != target: return
		EditorInterface.edit_node(scene.get_node("BakedIndirect"))
		phase = 2
	elif phase == 2:
		for button in EditorInterface.get_base_control().find_children("*", "Button", true, false):
			if button.text.contains("Bake Lightmaps") and button.is_visible_in_tree():
				print("OFFICE_BAKE_BEGIN ", target)
				phase = 3
				button.pressed.emit()
				return
		print("BAKE_BUTTON_WAIT")
	elif phase >= 3:
		var scene := EditorInterface.get_edited_scene_root()
		var lightmap := scene.get_node("BakedIndirect") as LightmapGI
		if phase == 3 and not lightmap.light_data:
			for dialog in EditorInterface.get_base_control().find_children("*", "EditorFileDialog", true, false):
				if dialog.visible:
					phase = 4
					dialog.file_selected.emit(target.get_basename() + ".lmbake")
					dialog.hide()
		if lightmap.light_data:
			EditorInterface.save_scene()
			print("OFFICE_BAKE_COMPLETE ", target)
			get_tree().quit()
