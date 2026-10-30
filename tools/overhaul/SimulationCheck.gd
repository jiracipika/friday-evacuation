extends SceneTree
const Rival = preload("res://scripts/overhaul/RivalDriver.gd")
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session: Node = root.get_node("OfficeSession")
	var args := OS.get_cmdline_user_args()
	var layout := args[0] if not args.is_empty() else "open_plan"
	session.configuration.trial = "trial" in args
	session.configuration.layout = layout
	session.configuration.difficulty = 2 if "hard" in args else 0 if "easy" in args else 1
	var scene: Node = load("res://scenes/overhaul/OfficeGame.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.test_bot_local = true
	scene.brains[1] = Rival.new()
	scene.brains[1].difficulty = session.configuration.difficulty
	for i in 11000:
		await physics_frame
		if i % 1800 == 0:
			var positions := {}
			for id in scene.actors:
				positions[id] = [scene.actors[id].checkpoint, scene.actors[id].position]
			print("SIM ", i, " ", positions)
		if scene.results_shown:
			break
	var finishes := 0
	for id in scene.actors:
		if scene.actors[id].finish_time > 0:
			finishes += 1
	if "trial" in args:
		if scene.actors.size() != 1 or scene.ghost_frames.size() < 500:
			print("TRIAL_GHOST_FAILED");quit(1);return
		print("TRIAL_GHOST_PASS frames=", scene.ghost_frames.size())
	print("RACE_CHECK ", layout, " FINISHES ", finishes, " / ", scene.actors.size())
	quit(0 if finishes == scene.actors.size() else 1)
