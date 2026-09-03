# LanAvatarSyncTest.gd — Phase 8C LAN avatar identity verification.
# Proves the full network roster path carries name/color/character/skin,
# validates stale cosmetic ids, re-keys RPC-style float peer ids, and — most
# importantly — builds a REAL remote PlayerChair with the guest's selected
# rider + chassis before _ready constructs the procedural model.
# Run: godot --headless --path . --script scripts/LanAvatarSyncTest.gd
extends SceneTree

var checks := 0
var failures: Array[String] = []
var mounted_network := false
var mounted_manager := false

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] " + label)
	else:
		failures.append(label)
		printerr("[FAIL] " + label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Raw SceneTree scripts do not consistently receive project autoloads.
	# Mount the REAL scripts when absent so Evacuation still exercises its
	# exact /root/Network and /root/GameManager production lookup paths.
	var network = root.get_node_or_null("Network")
	if network == null:
		network = load("res://scripts/Network.gd").new()
		network.name = "Network"
		root.add_child(network)
		mounted_network = true
	var manager = root.get_node_or_null("GameManager")
	if manager == null:
		manager = load("res://scripts/GameManager.gd").new()
		manager.name = "GameManager"
		root.add_child(manager)
		mounted_manager = true

	# Snapshot shared autoload state; this suite must not leak identity into
	# another test/editor instance.
	var saved := {
		"names": network.connected_players.duplicate(true),
		"colors": network.player_colors.duplicate(true),
		"characters": network.player_characters.duplicate(true),
		"skins": network.player_skins.duplicate(true),
		"ready": network.ready_players.duplicate(true),
	}
	var announced_ids: Array[int] = []
	network.player_connected.connect(func(peer_id: int, _name: String): announced_ids.append(peer_id))
	# Socket-first lifecycle: placeholders are visible to the host's lobby
	# count but MUST NOT announce/spawn until full identity is available.
	network._register_peer_placeholder(41)
	check(not announced_ids.has(41), "socket placeholder is not announced as spawn-ready")
	network._store_player_identity(41, "Iggy", "57d7ff", "it_iggy", "exercise_ball", true)
	check(announced_ids.has(41), "complete identity announces peer as spawn-ready")
	check(network.get_player_character(41) == "it_iggy", "atomic identity store keeps character")
	check(network.get_player_skin(41) == "exercise_ball", "atomic identity store keeps skin")

	# RPC Dictionaries commonly arrive with float keys. send_roster must
	# normalize every identity map to int keys and validate cosmetic ids.
	network.send_roster(
		{42.0: "Remote Ron"},
		{42.0: true},
		{42.0: "45d9ca"},
		{42.0: "remote_ron"},
		{42.0: "toilet"}
	)
	check(network.connected_players.has(42), "RPC roster name key normalized float -> int")
	check(network.player_characters.has(42), "RPC character key normalized float -> int")
	check(network.player_skins.has(42), "RPC skin key normalized float -> int")
	check(network.get_player_character(42) == "remote_ron", "guest character survives roster round trip")
	check(network.get_player_skin(42) == "toilet", "guest chair skin survives roster round trip")
	check(network.get_player_color(42).is_equal_approx(Color("45d9ca")), "guest color survives roster round trip")
	var lobby = load("res://scripts/Lobby.gd").new()
	lobby.network = network
	var lobby_avatar: String = lobby._avatar_label(42)
	check("Remote Ron" in lobby_avatar and "The Throne" in lobby_avatar,
		"lobby visibly names synced rider + chair (%s)" % lobby_avatar)
	lobby.free()

	# Corrupt/stale ids must fall back deterministically, never poison remote
	# procedural-model construction.
	network.player_characters[77] = "deleted_character"
	network.player_skins[77] = "modded_chair_that_does_not_exist"
	check(network.get_player_character(77) == "deadline_dana", "invalid character id falls back safely")
	check(network.get_player_skin(77) == "office_standard", "invalid skin id falls back safely")

	# Keep only the target guest before scene construction; peer 41 already
	# proved lifecycle ordering and would otherwise create a second remote.
	network.connected_players.erase(41)
	network.player_colors.erase(41)
	network.player_characters.erase(41)
	network.player_skins.erase(41)
	network.ready_players.erase(41)

	# The production integration: instantiate the REAL Evacuation scene. Its
	# _ready iterates connected_players and calls _on_network_player_connected.
	# The remote PlayerChair must have both use_global flags false BEFORE its
	# own _ready, otherwise it silently copies this machine's local selections.
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var evac = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(evac)
	await process_frame
	await process_frame

	var remote = evac.remote_players.get(42)
	check(remote != null and is_instance_valid(remote), "real Evacuation spawns roster guest chair")
	if remote and is_instance_valid(remote):
		check(remote.use_global_character == false, "remote chair ignores local GameManager character")
		check(remote.use_global_skin == false, "remote chair ignores local GameManager skin")
		check(remote.character_id == "remote_ron", "remote chair built selected rider character")
		check(remote.skin_id == "toilet", "remote chair built selected chassis skin")
		check(String(remote.skin.get("id", "")) == "toilet", "remote skin stat profile resolved before physics")
		var chair_root = remote.model_parent.get_node_or_null("ProceduralChair")
		check(chair_root != null, "remote procedural chair model exists")
		if chair_root:
			check(chair_root.get_node_or_null("Rider_remote_ron") != null,
				"remote procedural rider model matches synced character")

	if is_instance_valid(evac):
		evac.free()

	# Restore or remove mounted state.
	network.connected_players = saved.names
	network.player_colors = saved.colors
	network.player_characters = saved.characters
	network.player_skins = saved.skins
	network.ready_players = saved.ready
	if mounted_network and is_instance_valid(network):
		network.free()
	if mounted_manager and is_instance_valid(manager):
		manager.free()

	print("")
	if failures.is_empty() and checks > 0:
		print("=== LAN AVATAR SYNC TEST PASSED (%d checks) ===" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("[FAILED] " + failure)
		print("=== LAN AVATAR SYNC TEST FAILED (%d/%d) ===" % [failures.size(), checks])
		quit(1)
