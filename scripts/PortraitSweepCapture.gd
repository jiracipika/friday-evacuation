# PortraitSweepCapture.gd — 390px portrait in-match UI sweep capture driver
# (FINAL-day UI sweep, all four modes). Boots a mode scene into its in-match
# state at whatever the project window resolution is (the --write-movie dance:
# temporarily set project.godot viewport to 390x844, capture, RESTORE), then
# optionally fires a caption or the results screen so every surface has frames.
# No race is joined, no career writes beyond what _end_race already guards.
#
#   FE_SWEEP=evac|hauled|shopseek|pizza \
#   FE_SWEEP_CAPTION=6          (frame to fire a long a11y caption; optional)
#   FE_SWEEP_RESULTS=5          (frame to fire the mode's results flow; optional)
#   godot --path . --script scripts/PortraitSweepCapture.gd \
#     --rendering-method gl_compatibility \
#     --write-movie DIR/f.png --fixed-fps 10 --quit-after 12
extends SceneTree

var scene: Node
var frame_num := 0

func _init() -> void:
	_mount.call_deferred()

func _scene_path(mode: String) -> String:
	match mode:
		"evac":
			return "res://scenes/Evacuation.tscn"
		"hauled":
			return "res://scenes/Hauled.tscn"
		"shopseek":
			return "res://scenes/ShopSeek.tscn"
		"pizza":
			return "res://scenes/PizzaColony.tscn"
	return ""

func _mount() -> void:
	var path := _scene_path(OS.get_environment("FE_SWEEP"))
	if path == "":
		push_error("FE_SWEEP must be evac|hauled|shopseek|pizza")
		quit(1)
		return
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var packed: PackedScene = load(path)
	scene = packed.instantiate()
	root.add_child(scene)
	current_scene = scene

func _fire_results(mode: String) -> void:
	match mode:
		"evac":
			scene.call("_end_race")
		"hauled":
			scene.call("_finish_round", 1234, "DELIVERED  SOFA  PIANO", Color("a8ffbd"))
		"shopseek":
			scene.call("_show_results", true, "SHIFT COMPLETE")
		"pizza":
			scene.call("_end", true, "SURVIVED THE SERVICE")
	print("PORTRAITSWEEP results fired for ", mode)

func _process(_delta: float) -> bool:
	frame_num += 1
	if frame_num == 3 and scene != null:
		# PortraitHint gate ("rotate your phone") must be played-through —
		# the sweep audits the in-match UI UNDER the gate.
		var hint_script: GDScript = load("res://scripts/PortraitHint.gd")
		for child in scene.get_children():
			if child.get_script() == hint_script:
				child.call("_dismiss")
	if frame_num == 4 and scene != null:
		# Keyboard/mouse cheat sheet hides on real input; force it away so the
		# HUD itself is what the frames audit.
		var c: Node = scene.get_node_or_null("ControlsOverlay")
		if c:
			c.visible = false
	var caption_at := int(OS.get_environment("FE_SWEEP_CAPTION"))
	if caption_at > 0 and frame_num == caption_at:
		# Geometry audit: drive the overlay directly (Accessibility.caption
		# gates on the subtitles setting, default off; the routing itself is
		# AccessibilitySmokeTest's job, the 390px fit is ours).
		for node in get_nodes_in_group("caption_overlays"):
			if node and is_instance_valid(node) and node.has_method("show_caption"):
				node.show_caption("GHOST FINISHED — 61.4s. BEAT IT FOR THE OFFICE RECORD", 3.0)
				break
		print("PORTRAITSWEEP caption fired")
	var results_at := int(OS.get_environment("FE_SWEEP_RESULTS"))
	if results_at > 0 and frame_num == results_at:
		_fire_results(OS.get_environment("FE_SWEEP"))
	return false
