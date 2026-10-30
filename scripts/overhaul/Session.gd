extends Node
## Native LAN only. All gameplay authority resides on peer 1.
const PROTOCOL := 2
const PORT := 5007
const Command = preload("res://scripts/overhaul/DrivingCommand.gd")
const Design = preload("res://scripts/CharacterDesign.gd")
const Roster = preload("res://scripts/CharacterRoster.gd")
signal changed
signal start_requested
signal message(text: String)
var peer: ENetMultiplayerPeer
var roster: Dictionary = {}
var active := false
var running := false
var game: Node
var configuration := {"mode": "evacuation", "layout": "open_plan", "trial": false, "difficulty": 1, "bots": 4}
var discovery := PacketPeerUDP.new()
var hosts: Dictionary = {}
var discover_timer := 0.0
var scanning := false
var announced := false
var identity_profile := "balanced"
var _join_timeout := 0.0
var last_notice := ""

func _ready() -> void:
	message.connect(func(words): last_notice = words)
	multiplayer.peer_disconnected.connect(_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func():
		if active:
			close()
			message.emit("Could not connect. Check the address and use the same game build."))
	multiplayer.server_disconnected.connect(func():
		if active:
			close()
			message.emit("The host left the office. Your saved progress is safe."))

func local_identity() -> Dictionary:
	var gm := get_node_or_null("/root/GameManager")
	return {"name": gm.player_name if gm else "Coworker", "character": gm.selected_character_id if gm else "deadline_dana", "design": gm.get_character_design() if gm else {}, "skin": gm.selected_skin_id if gm else "office_standard", "profile": identity_profile, "ready": false}

func host() -> bool:
	if OS.has_feature("web"):
		message.emit("LAN parties run in the desktop app. Browser play includes AI races and time trials.")
		return false
	close()
	peer = ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 7) != OK:
		message.emit("This office is already hosting. Close the other game or choose another host.")
		return false
	active = true
	multiplayer.multiplayer_peer = peer
	roster[1] = local_identity()
	roster[1].ready = true
	_open_discovery()
	changed.emit()
	return true

func join(address: String) -> bool:
	close()
	if OS.has_feature("web"):
		return false
	peer = ENetMultiplayerPeer.new()
	if peer.create_client(address.strip_edges(), PORT) != OK:
		message.emit("Enter the host's local address, for example 192.168.1.12.")
		return false
	active = true
	multiplayer.multiplayer_peer = peer
	_join_timeout = 8
	return true

func _connected() -> void:
	if active:
		hello.rpc_id(1, PROTOCOL, local_identity())

@rpc("any_peer", "call_remote", "reliable")
func hello(version: int, raw: Dictionary) -> void:
	if not active or not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if version != PROTOCOL or (roster.size() >= 8 and not roster.has(id)):
		refused.rpc_id(id, "The office versions do not match. Update both games before joining.")
		return
	var character := Roster.get_character(str(raw.get("character", "")))
	var profiles := ["balanced", "agile", "heavy"]
	var skins = load("res://scripts/ChairSkins.gd")
	roster[id] = {"name": str(raw.get("name", "Coworker")).strip_edges().left(24), "character": character.id, "design": Design.sanitize(raw.get("design", {})), "skin": str(raw.get("skin", "office_standard")) if skins.ids().has(raw.get("skin")) else "office_standard", "profile": str(raw.get("profile", "balanced")) if profiles.has(raw.get("profile")) else "balanced", "ready": false}
	_send_roster()
	if running:
		if is_instance_valid(game):
			game.add_human(id)
		begin.rpc_id(id, configuration)

func refresh_identity() -> void:
	if not active or running:
		return
	if multiplayer.is_server():
		roster[1] = local_identity()
		roster[1].ready = true
		_send_roster()
	elif multiplayer.get_peers().has(1):
		hello.rpc_id(1, PROTOCOL, local_identity())

@rpc("authority", "call_remote", "reliable")
func refused(reason: String) -> void:
	close()
	message.emit(reason)

func _send_roster() -> void:
	changed.emit()
	if active and multiplayer.is_server():
		receive_roster.rpc(roster, configuration)

@rpc("authority", "call_remote", "reliable")
func receive_roster(players: Dictionary, settings: Dictionary) -> void:
	roster = players
	configuration = settings
	_join_timeout = 0
	changed.emit()

func set_ready(value: bool) -> void:
	if not active:
		return
	if multiplayer.is_server():
		roster[1].ready = value
		_send_roster()
	else:
		ready_up.rpc_id(1, value)

@rpc("any_peer", "call_remote", "reliable")
func ready_up(value: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and roster.has(id):
		roster[id].ready = value
		_send_roster()

func start() -> bool:
	if active and not multiplayer.is_server():
		return false
	if active and configuration.mode == "seek" and roster.size() < 2:
		message.emit("Shop & Seek parties need a seeker and a hider. Invite a coworker or choose Play for solo shopping.")
		return false
	for player in roster.values():
		if not player.ready:
			message.emit("Everyone needs to clock in as READY first.")
			return false
	if active:
		configuration.trial = false
	running = true
	if active:
		begin.rpc(configuration)
	else:
		start_requested.emit()
	return true

@rpc("authority", "call_local", "reliable")
func begin(settings: Dictionary) -> void:
	configuration = settings
	running = true
	start_requested.emit()

func submit(cmd: Dictionary) -> void:
	if active and not multiplayer.is_server():
		input_command.rpc_id(1, cmd)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func input_command(raw: Dictionary) -> void:
	if not multiplayer.is_server() or not is_instance_valid(game):
		return
	var id := multiplayer.get_remote_sender_id()
	if roster.has(id):
		game.accept_command(id, Command.clean(raw))

func publish(state: Dictionary) -> void:
	if active and multiplayer.is_server():
		var payload := var_to_bytes(state).compress(FileAccess.COMPRESSION_DEFLATE)
		if payload.size() < 1100:
			state_frame.rpc(payload)
		else:
			# Large end-of-round/fort states may fragment; use a separate reliable
			# channel without blocking input or routine actor snapshots.
			state_frame_reliable.rpc(payload)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func state_frame(payload: PackedByteArray) -> void:
	if payload.size() > 32768:
		return
	var bytes := payload.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE)
	var state: Variant = bytes_to_var(bytes)
	if not state is Dictionary:
		return
	if is_instance_valid(game):
		game.pending_states.append(state)
		if game.pending_states.size() > 4:
			game.pending_states.pop_front()

@rpc("authority", "call_remote", "reliable", 3)
func state_frame_reliable(payload: PackedByteArray) -> void:
	state_frame(payload)

func ready_in_game() -> void:
	if active and not multiplayer.is_server():
		loaded.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func loaded() -> void:
	if multiplayer.is_server() and is_instance_valid(game):
		var id := multiplayer.get_remote_sender_id()
		if roster.has(id):
			game.add_human(id)
			state_frame_reliable.rpc_id(id, var_to_bytes(game.snapshot()).compress(FileAccess.COMPRESSION_DEFLATE))

func _left(id: int) -> void:
	if not active:
		return
	roster.erase(id)
	if is_instance_valid(game) and multiplayer.is_server():
		game.remove_human(id)
	if multiplayer.is_server():
		_send_roster()

func close() -> void:
	if active:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if peer:
		peer.close()
	peer = null
	active = false
	running = false
	game = null
	roster.clear()
	_join_timeout = 0
	discovery.close()
	scanning = false

func scan() -> void:
	if OS.has_feature("web"):
		return
	discovery.close()
	discovery.bind(5008)
	discovery.set_broadcast_enabled(true)
	scanning = true
	hosts.clear()
	discover_timer = 0

func _open_discovery() -> void:
	discovery.close()
	# Hosts and scan clients use distinct sockets; scans can coexist locally.
	discovery.bind(5009)
	discovery.set_broadcast_enabled(true)
	discover_timer = 0

func _process(delta: float) -> void:
	if _join_timeout > 0:
		_join_timeout -= delta
		if _join_timeout <= 0 and roster.is_empty():
			close()
			message.emit("No compatible host replied. Check the address, firewall and game version.")
	if not discovery.is_bound():
		return
	discover_timer -= delta
	if discover_timer <= 0:
		discover_timer = 1.0
		discovery.set_dest_address("255.255.255.255", 5008 if active and multiplayer.is_server() else 5009)
		var text := "FRIDAY_V2|%d|%s|%d" % [PROTOCOL, str(roster.get(1, {}).get("name", "Office")), roster.size()] if active and multiplayer.is_server() else "FRIDAY_V2_SCAN"
		discovery.put_packet(text.to_utf8_buffer())
	while discovery.get_available_packet_count() > 0:
		var packet := discovery.get_packet().get_string_from_utf8()
		var address := discovery.get_packet_ip()
		if packet == "FRIDAY_V2_SCAN" and active and multiplayer.is_server():
			discovery.set_dest_address(address, 5008)
			discovery.put_packet(("FRIDAY_V2|%d|%s|%d" % [PROTOCOL, roster[1].name, roster.size()]).to_utf8_buffer())
		var fields := packet.split("|")
		if scanning and fields.size() == 4 and fields[0] == "FRIDAY_V2" and fields[1].is_valid_int() and int(fields[1]) == PROTOCOL:
			hosts[address] = fields[2]
			changed.emit()
