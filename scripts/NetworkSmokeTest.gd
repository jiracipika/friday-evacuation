extends SceneTree

var network
var started := false
var passed := true

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	network = get_root().get_node_or_null("Network")
	if not network:
		printerr("[FAIL] Network autoload missing")
		quit(1)
		return
	if not network.host_game(5515):
		printerr("[FAIL] Could not create local ENet host")
		quit(1)
		return
	print("[PASS] local ENet host created")
	network.set_ready(true)
	if not network.all_players_ready():
		printerr("[FAIL] host ready state not accepted")
		passed = false
	else:
		print("[PASS] authoritative host ready state")
	network.match_started.connect(func(): started = true)
	if not network.start_match():
		printerr("[FAIL] host could not start all-ready match")
		passed = false
	else:
		print("[PASS] authoritative match start")
	await process_frame
	network.close_connection()
	if passed and started:
		print("=== NETWORK SMOKE TEST PASSED ===")
		quit(0)
	else:
		printerr("=== NETWORK SMOKE TEST FAILED ===")
		quit(1)
