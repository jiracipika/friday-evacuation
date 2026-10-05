# MultiplayerSyncHost.gd — Phase 5 two-process sync test, HOST side.
# Launched by the driver via `godot --headless --path . --script
# scripts/MultiplayerSyncHost.gd -- --port 15005`. Hosts a game, waits for
# the client, then steps through the verification handshake, printing
# [PASS]/[FAIL] lines. Exits non-zero on any failure.
extends SceneTree

const PORT_DEFAULT := 15005
var checks_total := 0
var checks_passed := 0
var failures: Array[String] = []
var port := PORT_DEFAULT
var client_id := 0
var client_gone := false
# Lambda-visible flags: GDScript lambdas capture locals BY VALUE, so these
# MUST be instance members or listener writes are invisible to wait loops.
var saw_state := false
var saw_rot := false
var trap_fired := false
var trap_payload_ok := false
var pickup_fired := false
var pickup_name_ok := false
var chat_ok := false
var client_layout_report := ""   # PHASE 5: client's reported applied layout


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

func check(cond: bool, label: String) -> void:
	checks_total += 1
	if cond:
		checks_passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		print("[FAIL] %s" % label)

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.split("=")[1])
	_run.call_deferred()

func _run() -> void:
	var gm = root.get_node("/root/GameManager")  # real autoload (project mode loads it)
	await process_frame
	gm.player_name = "TestHost"
	gm.selected_character_id = "deadline_dana"
	gm.character_designs["deadline_dana"] = {"hair": "bob", "expression": "panic"}
	gm.player_color = Color(1.0, 0.6, 0.1)

	var net = root.get_node("/root/Network")  # real autoload
	await process_frame

	if OS.get_environment("MP_TEST_SKIP_DETERMINISM") != "1":
		await _check_deterministic_world(net)

	check(net.host_game(port), "host starts on UDP %d" % port)
	net._stop_discovery()  # tests: LAN broadcast discovery off (loopback only)
	print("HOST_READY")

	# Wait for the client to connect (timeout ~10s)
	var connected := await _wait_until(func(): return net.get_player_count() >= 2, 45.0)
	check(connected, "client connected (players=%d)" % net.get_player_count())
	for peer_id in net.connected_players:
		if int(peer_id) != 1:
			client_id = int(peer_id)
	check(client_id != 0, "client peer id assigned (%d)" % client_id)

	# Wait for the client's identity to arrive (name + color)
	await _wait_until(func(): return String(net.connected_players.get(client_id, "")) != "Player_%d" % client_id, 45.0)
	check(String(net.connected_players.get(client_id, "")) == "TestClient", "client name on host roster (%s)" % net.connected_players.get(client_id, "?"))
	# NOTE: colors travel as 6-hex-digit HTML; Color(0.72,...) becomes
	# 0.7216 after the round-trip, so compare with a tolerance that
	# accepts the 1/255 quantization instead of is_equal_approx default.
	var got_color: Color = net.get_player_color(client_id)
	var want_color := Color(0.72, 0.4, 1.0)
	var color_ok: bool = absf(got_color.r - want_color.r) < 0.004 and absf(got_color.g - want_color.g) < 0.004 and absf(got_color.b - want_color.b) < 0.004
	check(color_ok, "client color on host roster")
	check(net.get_player_character(client_id) == "coffee_carl", "new coworker preset received over ENet")
	check(net.get_player_design(client_id) == {"outfit": "hoodie", "hair": "bun", "expression": "derpy", "shirt_color": "ff73b5"}, "custom design received over ENet")

	# Ready flow: client readies first, then host
	net.set_ready(true)
	await _wait_until(func(): return net.all_players_ready(), 45.0)
	check(net.all_players_ready(), "all players ready (incl. client)")

	# Attach ALL event listeners BEFORE starting the match — the client
	# performs its protocol burst right after match_started arrives.
	net.remote_player_state.connect(func(pid: int, pos: Vector3, vel: Vector3, rot: float):
		if pid == client_id:
			saw_state = true
			if absf(rot - 0.75) < 0.01:
				saw_rot = true
	)
	net.world_trap_dropped.connect(func(pid: int, pos: Vector3, ttype: String, forced: bool):
		if pid == client_id:
			trap_fired = true
			trap_payload_ok = ttype == "spill" and forced
	)
	net.world_pickup_taken.connect(func(pid: int, pickup_name: String):
		if pid == client_id:
			pickup_fired = true
			pickup_name_ok = pickup_name == "PU_3"
	)
	net.chat_message.connect(func(pid: int, sender: String, text: String):
		if pid == client_id and text == "hello from client":
			chat_ok = true
		if pid == client_id and text.begins_with("LAYOUT_APPLIED="):
			client_layout_report = text.substr("LAYOUT_APPLIED=".length())
	)

	# PHASE 5 layout sync: host picks a NON-default layout right before
	# start so begin_match carries something distinguishable.
	var layout_script = load("res://scripts/LevelLayouts.gd")
	layout_script.set_current("executive")

	check(net.start_match(), "host starts match")
	check(String(net.match_layout) == "executive", "host captured layout in payload (executive)")

	await _wait_until(func(): return saw_state, 45.0)
	check(saw_state, "host received client state")
	check(saw_rot, "rotation carried in state sync (rot=0.75)")

	# World events from client
	await _wait_until(func(): return trap_fired and pickup_fired, 45.0)
	check(trap_fired, "host saw client trap drop")
	check(trap_payload_ok, "trap drop payload intact (spill/forced)")
	check(pickup_fired, "host saw client pickup taken")
	check(pickup_name_ok, "pickup name intact (PU_3)")

	# Chat relay from client
	await _wait_until(func(): return chat_ok, 45.0)
	check(chat_ok, "chat relayed client->host")

	# PHASE 5 layout sync: the client reports its applied layout via the
	# chat channel after match_started fires on its side.
	await _wait_until(func(): return client_layout_report != "", 10.0)
	check(client_layout_report == "executive", "client applied host layout (reported '%s')" % client_layout_report)

	net.close_connection()
	print("")
	if failures.is_empty():
		print("=== MULTIPLAYER SYNC HOST: ALL PASS (%d checks) ===" % checks_passed)
		quit(0)
	else:
		for f in failures:
			printerr("[HOST FAILED] %s" % f)
		print("=== MULTIPLAYER SYNC HOST: FAILED (%d/%d) ===" % [failures.size(), checks_total])
		quit(1)

func _collect_trap_types(node: Node, out: Array[String]) -> void:
	if node is Area3D and "trap_type" in node:
		out.append(String(node.trap_type))
	for child in node.get_children():
		_collect_trap_types(child, out)

func _check_deterministic_world(_net) -> void:
	var evac = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(evac)
	await _wait(0.2)
	evac._start_race()  # traps spawn at race start, not arena setup
	await _wait(0.2)
	var types_a: Array[String] = []
	_collect_trap_types(evac, types_a)
	var evac2 = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(evac2)
	await _wait(0.2)
	evac2._start_race()
	await _wait(0.2)
	var types_b: Array[String] = []
	_collect_trap_types(evac2, types_b)
	check(types_a.size() >= 4, "world traps spawned deterministically (%d)" % types_a.size())
	check(types_a == types_b, "two instantiations identical trap layouts")
	evac.queue_free()
	evac2.queue_free()
