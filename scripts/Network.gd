# Network.gd — LAN discovery, lobby authority, and ENet replication.
extends Node

const DEFAULT_PORT := 5005
const DISCOVERY_PORT := 5006
const MAX_CLIENTS := 8
const DISCOVERY_INTERVAL := 0.8

var peer: ENetMultiplayerPeer = null
var discovery_socket := PacketPeerUDP.new()
var discovery_active := false
var discovery_is_host := false
var discovery_timer := 0.0
var host_name := "Friday 5PM Host"
var host_address := ""
var connected_players: Dictionary = {} # peer_id -> player name
var ready_players: Dictionary = {} # peer_id -> bool
var player_states: Dictionary = {} # peer_id -> {position, velocity}

signal player_connected(peer_id: int, player_name: String)
signal player_disconnected(peer_id: int)
signal server_started(port: int)
signal connection_failed()
signal connection_succeeded()
signal lan_host_found(address: String, name: String, player_count: int)
signal remote_player_state(peer_id: int, position: Vector3, velocity: Vector3)
signal player_ready_changed(peer_id: int, is_ready: bool)
signal match_started()

func _process(delta: float) -> void:
	if not discovery_active:
		return
	discovery_timer -= delta
	if discovery_is_host and discovery_timer <= 0.0:
		discovery_timer = DISCOVERY_INTERVAL
		_advertise_host()
	elif not discovery_is_host and discovery_timer <= 0.0:
		discovery_timer = DISCOVERY_INTERVAL
		_request_host_discovery()
	_poll_discovery()

func host_game(port: int = DEFAULT_PORT) -> bool:
	close_connection()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Failed to create LAN server: %s" % err)
		return false
	multiplayer.multiplayer_peer = peer
	_ensure_multiplayer_signals()
	var manager = get_node_or_null("/root/GameManager")
	connected_players[1] = manager.player_name if manager else "Host"
	ready_players[1] = false
	_start_discovery(true)
	server_started.emit(port)
	print("[NET] LAN host started on UDP %d; discovery UDP %d" % [port, DISCOVERY_PORT])
	return true

func join_game(ip: String, port: int = DEFAULT_PORT) -> bool:
	close_connection()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("Failed to create LAN client: %s" % err)
		return false
	multiplayer.multiplayer_peer = peer
	_ensure_multiplayer_signals()
	host_address = ip
	print("[NET] Connecting to LAN host %s:%d" % [ip, port])
	return true

func _ensure_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func close_connection() -> void:
	_stop_discovery()
	if peer:
		peer.close()
	peer = null
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	connected_players.clear()
	ready_players.clear()
	player_states.clear()

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	connected_players[peer_id] = "Player_%d" % peer_id
	ready_players[peer_id] = false
	player_connected.emit(peer_id, connected_players[peer_id])
	_broadcast_roster()
	print("[NET] Peer connected: %d" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	connected_players.erase(peer_id)
	ready_players.erase(peer_id)
	player_states.erase(peer_id)
	player_disconnected.emit(peer_id)
	if multiplayer.is_server():
		_broadcast_roster()
	print("[NET] Peer disconnected: %d" % peer_id)

func _on_connected_to_server() -> void:
	connection_succeeded.emit()
	request_roster.rpc_id(1)
	print("[NET] Connected to LAN host")

func _on_connection_failed() -> void:
	connection_failed.emit()
	print("[NET] LAN connection failed")

func _on_server_disconnected() -> void:
	close_connection()
	print("[NET] LAN host disconnected")

func get_player_count() -> int:
	return connected_players.size()

func is_server() -> bool:
	return peer != null and multiplayer.is_server()

func _start_discovery(as_host: bool) -> void:
	_stop_discovery()
	discovery_is_host = as_host
	discovery_active = true
	discovery_timer = 0.0
	if not as_host:
		discovery_socket.set_broadcast_enabled(true)
		var bind_err = discovery_socket.bind(DISCOVERY_PORT)
		if bind_err != OK:
			# A second local game instance may already own the port; fall back to an ephemeral port for direct testing.
			discovery_socket.bind(0)

func _stop_discovery() -> void:
	discovery_active = false
	if discovery_socket.is_socket_connected():
		discovery_socket.close()

func _request_host_discovery() -> void:
	if not discovery_socket.is_socket_connected():
		return
	discovery_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	discovery_socket.put_packet("FRIDAY5PM_DISCOVER".to_utf8_buffer())

func _advertise_host() -> void:
	if not discovery_socket.is_socket_connected():
		var bind_err = discovery_socket.bind(DISCOVERY_PORT)
		if bind_err != OK:
			return
	var packet = ("FRIDAY5PM|%s|%d" % [host_name, connected_players.size()]).to_utf8_buffer()
	discovery_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	discovery_socket.put_packet(packet)

func discover_lan_hosts() -> void:
	_start_discovery(false)
	# A discovery scan expires naturally when the lobby closes.

func _poll_discovery() -> void:
	while discovery_socket.get_available_packet_count() > 0:
		var data = discovery_socket.get_packet().get_string_from_utf8()
		if data == "FRIDAY5PM_DISCOVER" and discovery_is_host:
			_advertise_host()
			continue
		var parts = data.split("|")
		if parts.size() != 3 or parts[0] != "FRIDAY5PM":
			continue
		var address = discovery_socket.get_packet_ip()
		lan_host_found.emit(address, parts[1], int(parts[2]))

func set_ready(is_ready: bool) -> void:
	var own_id = multiplayer.get_unique_id()
	if is_server():
		ready_players[own_id] = is_ready
		_broadcast_ready(own_id, is_ready)
	else:
		submit_ready.rpc_id(1, is_ready)

@rpc("any_peer", "reliable", "call_remote")
func submit_ready(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	ready_players[sender] = is_ready
	_broadcast_ready(sender, is_ready)

func _broadcast_ready(peer_id: int, is_ready: bool) -> void:
	ready_players[peer_id] = is_ready
	player_ready_changed.emit(peer_id, is_ready)
	if is_server():
		announce_ready.rpc(peer_id, is_ready)

@rpc("authority", "reliable", "call_remote")
func announce_ready(peer_id: int, is_ready: bool) -> void:
	ready_players[peer_id] = is_ready
	player_ready_changed.emit(peer_id, is_ready)

func all_players_ready() -> bool:
	if connected_players.is_empty():
		return false
	for peer_id in connected_players:
		if not ready_players.get(peer_id, false):
			return false
	return true

func start_match() -> bool:
	if not is_server() or not all_players_ready():
		return false
	begin_match.rpc()
	match_started.emit()
	return true

@rpc("authority", "reliable", "call_local")
func begin_match() -> void:
	match_started.emit()

@rpc("any_peer", "reliable", "call_remote")
func request_roster() -> void:
	if multiplayer.is_server():
		var sender = multiplayer.get_remote_sender_id()
		send_roster.rpc_id(sender, connected_players, ready_players)

func _broadcast_roster() -> void:
	if is_server():
		broadcast_roster.rpc(connected_players, ready_players)

@rpc("authority", "reliable", "call_remote")
func send_roster(names: Dictionary, readiness: Dictionary) -> void:
	connected_players = names
	ready_players = readiness
	for peer_id in connected_players:
		if int(peer_id) != multiplayer.get_unique_id():
			player_connected.emit(int(peer_id), connected_players[peer_id])

@rpc("authority", "reliable", "call_remote")
func broadcast_roster(names: Dictionary, readiness: Dictionary) -> void:
	send_roster(names, readiness)

func broadcast_player_state(position: Vector3, velocity: Vector3) -> void:
	if peer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if is_server():
			_relay_player_state(multiplayer.get_unique_id(), position, velocity)
		else:
			submit_player_state.rpc_id(1, position, velocity)

@rpc("any_peer", "unreliable", "call_remote")
func submit_player_state(position: Vector3, velocity: Vector3) -> void:
	if multiplayer.is_server():
		var sender = multiplayer.get_remote_sender_id()
		_relay_player_state(sender, position, velocity)

func _relay_player_state(peer_id: int, position: Vector3, velocity: Vector3) -> void:
	player_states[peer_id] = {"position": position, "velocity": velocity}
	broadcast_player_state_rpc.rpc(peer_id, position, velocity)

@rpc("authority", "unreliable", "call_remote")
func broadcast_player_state_rpc(peer_id: int, position: Vector3, velocity: Vector3) -> void:
	player_states[peer_id] = {"position": position, "velocity": velocity}
	remote_player_state.emit(peer_id, position, velocity)
