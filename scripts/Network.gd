# Network.gd — Autoload singleton for multiplayer
# Uses Godot's built-in ENetMultiplayerPeer for LAN/direct connect
extends Node

const DEFAULT_PORT: int = 5005
const MAX_CLIENTS: int = 8

var peer: ENetMultiplayerPeer = null
var connected_players: Dictionary = {}  # peer_id -> player_name

signal player_connected(peer_id: int, player_name: String)
signal player_disconnected(peer_id: int)
signal server_started(port: int)
signal connection_failed()
signal connection_succeeded()

func host_game(port: int = DEFAULT_PORT) -> bool:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Failed to create server: %s" % err)
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	server_started.emit(port)
	print("[NET] Server started on port %d" % port)
	return true

func join_game(ip: String, port: int = DEFAULT_PORT) -> bool:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("Failed to create client: %s" % err)
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	print("[NET] Connecting to %s:%d..." % [ip, port])
	return true

func close_connection() -> void:
	if peer:
		peer.close()
		peer = null
	connected_players.clear()

func _on_peer_connected(peer_id: int) -> void:
	print("[NET] Peer connected: %d" % peer_id)
	player_connected.emit(peer_id, "Player_%d" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("[NET] Peer disconnected: %d" % peer_id)
	connected_players.erase(peer_id)
	player_disconnected.emit(peer_id)

func _on_connected_to_server() -> void:
	print("[NET] Connected to server!")
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("[NET] Connection failed!")
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NET] Server disconnected!")
	close_connection()

func get_player_count() -> int:
	return connected_players.size() + 1  # +1 for host

func is_server() -> bool:
	return multiplayer.is_server()
