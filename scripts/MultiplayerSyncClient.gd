# MultiplayerSyncClient.gd — Phase 5 two-process sync test, CLIENT side.
# Launched by the driver alongside MultiplayerSyncHost.gd. Joins the host,
# submits identity, readies, then performs the client-side half of the
# handshake (state broadcast, trap/pickup reports, chat). The host process
# does the PASS/FAIL accounting; this side just executes the protocol.
extends SceneTree

var port := 15005
var match_started := false
var initial_saved_map := ""   # PHASE 5: cfg map_layout before any sync ran
var layout_fail := false      # PHASE 5: hard-fail flag (driver checks rc)


func _wait(seconds: float) -> void:
	var timer: SceneTreeTimer = create_timer(seconds)
	await timer.timeout

func _wait_until(cond: Callable, timeout: float) -> bool:
	var waited: float = 0.0
	while waited < timeout:
		if cond.call():
			return true
		await _wait(0.1)
		waited += 0.1
	return cond.call()

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.split("=")[1])
	_run.call_deferred()

func _run() -> void:
	var gm = root.get_node("/root/GameManager")  # real autoload (project mode loads it)
	await process_frame
	gm.player_name = "TestClient"
	gm.player_color = Color(0.72, 0.4, 1.0)

	var net = root.get_node("/root/Network")  # real autoload
	await process_frame

	net._stop_discovery()  # tests: discovery off
	if not net.join_game("127.0.0.1", port):
		print("CLIENT_JOIN_FAILED")
		quit(1)
		return
	print("CLIENT_READY")

	# Wait until the connection is actually established
	await _wait_until(func(): return net.peer and net.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, 12.0)
	if not (net.peer and net.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED):
		print("CLIENT_CONNECT_TIMEOUT")
		quit(1)
		return

	# Wait for roster (2 players) then ready up
	await _wait_until(func(): return net.connected_players.size() >= 2, 45.0)
	print("CLIENT: roster size ", net.connected_players.size())

	# Attach the match-start listener BEFORE readying: the host may fire
	# begin_match the instant all players read ready. Uses the INSTANCE var
	# (lambdas capture locals by value — writes to locals are invisible).
	net.match_started.connect(func(): match_started = true)

	# PHASE 5 layout sync: pick a local layout that CONFLICTS with the
	# host's (host picks executive) and snapshot the saved cfg. After
	# match start the client must be on the HOST's layout while its cfg
	# keeps its own pick.
	var layout_script = load("res://scripts/LevelLayouts.gd")
	layout_script.set_current("cubicle_maze")
	var snap := ConfigFile.new()
	snap.load("user://settings.cfg")
	initial_saved_map = str(snap.get_value("game", "map_layout", "open_plan"))

	net.set_ready(true)
	print("CLIENT: readied")
	await _wait_until(func(): return match_started, 45.0)
	print("CLIENT: match started")

	# PHASE 5: verify the authoritative layout landed on this CLIENT.
	var applied: String = String(layout_script.current)
	if applied == "executive":
		print("CLIENT_LAYOUT_PASS: client on host's executive layout")
	else:
		printerr("CLIENT_LAYOUT_FAIL: expected executive, got '%s'" % applied)
		layout_fail = true
	var check_cfg := ConfigFile.new()
	check_cfg.load("user://settings.cfg")
	var saved_now: String = str(check_cfg.get_value("game", "map_layout", "open_plan"))
	if saved_now == initial_saved_map:
		print("CLIENT_CFG_PASS: saved map_layout untouched (%s)" % saved_now)
	else:
		printerr("CLIENT_CFG_FAIL: '%s' -> '%s'" % [initial_saved_map, saved_now])
		layout_fail = true
	# Report the applied layout to the host via the chat relay so the
	# HOST-side process (which owns PASS/FAIL accounting) can assert it.
	net.send_chat("LAYOUT_APPLIED=" + applied)

	# State sync is UNRELIABLE — burst it so at least one packet lands.
	for burst in range(6):
		net.broadcast_player_state(Vector3(1, 2, 3), Vector3(1, 0, 0), 0.75)
		await _wait(0.15)
	print("CLIENT: state burst sent")
	await _wait(0.2)
	net.report_trap_drop(Vector3(2, 0.5, 2), "spill", true)
	print("CLIENT: trap drop reported")
	await _wait(0.2)
	net.report_pickup_taken("PU_3")
	print("CLIENT: pickup reported")
	await _wait(0.2)
	net.send_chat("hello from client")
	print("CLIENT: chat sent")

	# Stay alive so the host can finish its assertions
	await _wait(20.0)
	print("CLIENT: done, closing")
	net.close_connection()
	quit(1 if layout_fail else 0)
