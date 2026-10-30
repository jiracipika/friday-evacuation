extends SceneTree
var session: Node
var game: Node
var role := "host"
var clock := 0.0
var moved := false
var checked := false
var largest_error := 0.0
var frames := 0
var rejected := false
var starts: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	session = root.get_node("OfficeSession")
	session.configuration.bots = 6
	if args.size() > 1: session.configuration.mode = args[1]
	session.start_requested.connect(func():
		if role == "incompatible": return
		game = load("res://scenes/overhaul/OfficeGame.tscn").instantiate()
		root.add_child(game)
		current_scene = game)
	session.message.connect(func(words):
		if "versions do not match" in words: rejected = true)
	if role == "host":
		if not session.host(): quit(1); return
		if session.configuration.mode != "seek": session.start()
		print("HOST_READY")
	else:
		session.join("127.0.0.1")
	while clock < (18.0 if role == "host" else 9.0):
		await physics_frame
		clock += 1.0 / 60
		if role == "host" and not game and session.configuration.mode == "seek" and session.roster.size() >= 2:
			var all_ready := true
			for identity in session.roster.values(): all_ready = all_ready and identity.ready
			if all_ready: session.start()
		if role == "client" and not game and not checked and session.roster.has(multiplayer_id()):
			session.set_ready(true)
			checked = true
		if role == "incompatible":
			if not checked and session.roster.size() >= 2:
				session.hello.rpc_id(1, -99, {})
				checked = true
			if rejected:
				print("PROTOCOL_REFUSAL_PASS")
				session.close()
				quit(0)
				return
		elif game:
			if role == "client" and game.rules.state.phase == "running" and clock < (2 if session.configuration.mode == "pizza" else 6):
				game.input.touch_move = Vector2.UP
			else:
				game.input.touch_move = Vector2.ZERO
			if role == "client" and not game.interpolation.is_empty():
				frames += 1
				var latest: Dictionary = game.interpolation.back().actors.get(game.local_id, {})
				if not latest.is_empty():
					if not starts.has(game.local_id): starts[game.local_id] = latest.p
					moved = moved or latest.p.distance_to(starts[game.local_id]) > 3
					if clock > 7:
						largest_error = maxf(largest_error, game.actors[game.local_id].position.distance_to(latest.p))
			if role == "host" and clock > 5 and game.actors.size() > 1:
				for id in game.actors:
					if id > 1:
						if not starts.has(id): starts[id] = game.actors[id].position
						if game.actors[id].last_seq > 50 and game.actors[id].position.distance_to(starts[id]) > 3:
							moved = true
	if role == "client":
		print("CLIENT_PREDICTION_PASS frames=%d settled_error=%.4f moved=%s" % [frames, largest_error, moved])
		session.close()
		quit(0 if moved and frames > 60 and largest_error < 0.3 else 1)
	elif role == "host":
		print("HOST_AUTHORITY_PASS moved=", moved)
		session.close()
		quit(0 if moved else 1)
	else:
		quit(1)

func multiplayer_id() -> int:
	return root.multiplayer.get_unique_id()
