extends SceneTree
var game: Node
var failures: Array[String] = []
const Save = preload("res://scripts/overhaul/OverhaulSave.gd")
const Command = preload("res://scripts/overhaul/DrivingCommand.gd")

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func open_mode(mode: String) -> void:
	var session: Node = root.get_node("OfficeSession")
	session.close()
	session.configuration.mode = mode
	session.configuration.bots = 0
	game = load("res://scenes/overhaul/OfficeGame.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.rules.countdown = 0
	game.rules.state.phase = "running"
	for i in 3: await physics_frame

func drive_to(target: Vector3, limit := 1500) -> bool:
	for i in limit:
		var actor = game.actors[1]
		var difference: Vector3 = target - actor.position
		difference.y = 0
		if difference.length() < 0.8:
			game.input.touch_move = Vector2.ZERO
			for settle in 15: await physics_frame
			return true
		if game.rules.finished: return false
		var direction := difference.normalized()
		var forward: Vector3 = -game.camera.global_basis.z
		forward.y = 0
		forward = forward.normalized()
		var right: Vector3 = game.camera.global_basis.x
		right.y = 0
		right = right.normalized()
		game.input.touch_move = Vector2(direction.dot(right), -direction.dot(forward))
		await physics_frame
	return false

func close_mode() -> void:
	game.queue_free()
	await process_frame
	game = null

func run() -> void:
	var clean := Command.clean({"move": "bad", "seq": Vector3.ZERO})
	check(clean.move == Vector2.ZERO and clean.seq == 0, "Malformed network inputs are neutral")
	check(Command.clean({"move": Vector2(INF, NAN)}).move == Vector2.ZERO, "Non-finite input rejected")
	check(Command.clean({"move": Vector2(9, 9)}).move.length() < 1.001, "Movement normalized")
	Save.PATH = "user://overhaul_test_records.cfg"
	DirAccess.remove_absolute(Save.PATH)
	check(Save.record("test:r2:p2", 10.0, [{"p": Vector3.ONE, "t": 0.1, "f": 0.0}]), "First best saved")
	check(not Save.record("test:r2:p2", 12, []), "Slower run preserves ghost")
	check(Save.ghost("test:r2:p2").size() == 1, "Ghost round trip")
	check(Save.ghost("test:r3:p2").is_empty(), "Course revisions isolate ghosts")
	DirAccess.remove_absolute(Save.PATH)
	Save.PATH = "user://friday_v2.cfg"
	var args := OS.get_cmdline_user_args()
	if "hauled" in args:
		await open_mode("hauled")
		var out := [Vector3(-12, 0, 5), Vector3(1, 0, 5), Vector3(1, 0, -4), Vector3(12, 0, -4), Vector3(13, 0, 14)]
		for delivery in 3:
			if delivery > 0:
				for index in range(out.size() - 2, -1, -1):
					check(await drive_to(out[index]), "Return path %d" % index)
			check(await drive_to(Vector3(-12, 0, -12 if delivery == 0 else -8)), "Reach loading bay")
			game.input.touch_hop = true
			for i in 4: await physics_frame
			check(game.rules.state.holders.has(1), "Player grabbed actual rigid cargo")
			for point in out:
				if game.rules.finished: break
				var reached := await drive_to(point)
				check(reached or (game.rules.finished and game.rules.state.delivered == 3), "Carry path %s" % point)
			print("CARGO_DELIVERY ", game.rules.state.delivered, " HP ", game.rules.state.cargo_health)
		check(game.rules.state.delivered == 3 and game.rules.finished, "Three physical deliveries finish Hauled")
		await close_mode()
	elif "seek" in args:
		await open_mode("seek")
		for index in 5:
			var position: Vector3 = game.seek_props[index].position + Vector3(0, 0, -1.3)
			check(await drive_to(position), "Reach supply %d" % index)
			game.input.touch_hop = true
			for i in 4: await physics_frame
			check(game.rules.state.collected[1].size() == index + 1, "Collect supply %d" % index)
		check(game.rules.finished and game.rules.state.headline == "CHECKOUT COMPLETE", "Shopping list is winnable through movement and interactions")
		await close_mode()
	else:
		await open_mode("pizza")
		check(await drive_to(game.rules.state.pads[0].p), "Reach pizza territory")
		var pad: Dictionary = game.rules.state.pads[0]
		var actor = game.actors[1]
		var at_pad: Vector3 = actor.position
		game.rules._claim_territory(1.0)
		check(pad.progress > 0 and pad.owner == 0, "Partial claim shows progress")
		actor.position = Vector3(6, 0.6, 0)
		game.rules._claim_territory(0.1)
		check(pad.progress == 0 and pad.claimant == 0, "Leaving a pad resets the claim")
		actor.position = at_pad
		for i in 190: await physics_frame
		check(pad.owner == 1, "Territory claimed after dwell")
		game.input.touch_item = true
		for i in 4: await physics_frame
		check(game.rules.state.forts.size() == 1 and game.rules.state.cheese[1] < 3, "Fort spends authoritative cheese")
		for i in 8000:
			if game.rules.finished: break
			await physics_frame
		check(game.rules.finished, "Pizza round has a bounded end")
		await close_mode()
	print("OVERHAUL_MODE_CHECK ", args, " failures=", failures)
	quit(0 if failures.is_empty() else 1)
