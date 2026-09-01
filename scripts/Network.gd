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
var player_colors: Dictionary = {} # peer_id -> Color (html string over RPC)
var ready_players: Dictionary = {} # peer_id -> bool
var player_states: Dictionary = {} # peer_id -> {position, velocity, rot_y}

signal player_connected(peer_id: int, player_name: String)
signal player_disconnected(peer_id: int)
signal server_started(port: int)
signal connection_failed()
signal connection_succeeded()
signal lan_host_found(address: String, name: String, player_count: int)
signal remote_player_state(peer_id: int, position: Vector3, velocity: Vector3, rot_y: float)
signal player_ready_changed(peer_id: int, is_ready: bool)
signal match_started()
var match_running := false   # set on begin_match; late joiners skip lobby
## Host's LevelLayouts pick, captured at start_match and delivered inside
## begin_match / confirm_match_state so every peer builds the SAME map.
## "" = unset (peers keep their own local pick). Applied via
## LevelLayouts.set_current — process state ONLY, never written to the
## client's saved cfg, so a guest's own menu preference survives the match.
var match_layout := ""
signal world_trap_dropped(peer_id: int, position: Vector3, trap_type: String, forced: bool)
signal world_pickup_taken(peer_id: int, pickup_name: String)
signal player_stunned(peer_id: int, duration: float)
signal chat_message(peer_id: int, sender_name: String, text: String)

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
		if not hotspot_sweep_done:
			_hotspot_sweep_tick()
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
	player_colors[1] = manager.player_color.to_html(false) if manager else Color(0.4, 0.8, 1.0).to_html(false)
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
	player_colors[peer_id] = Color(0.4, 0.8, 1.0).to_html(false)
	ready_players[peer_id] = false
	player_connected.emit(peer_id, connected_players[peer_id])
	_broadcast_roster()
	print("[NET] Peer connected: %d" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	connected_players.erase(peer_id)
	player_colors.erase(peer_id)
	ready_players.erase(peer_id)
	player_states.erase(peer_id)
	player_disconnected.emit(peer_id)
	if multiplayer.is_server():
		_broadcast_roster()
	print("[NET] Peer disconnected: %d" % peer_id)

func _on_connected_to_server() -> void:
	connection_succeeded.emit()
	var manager = get_node_or_null("/root/GameManager")
	var cname: String = manager.player_name if manager else "Player"
	var ccolor: String = manager.player_color.to_html(false) if manager else Color(0.4, 0.8, 1.0).to_html(false)
	submit_identity.rpc_id(1, cname, ccolor)
	request_roster.rpc_id(1)
	# Late-join: ask the host whether a match is already running.
	request_match_state.rpc_id(1)
	print("[NET] Connected to LAN host")

## Clients send their chosen name/color once connected; server stores and
## rebroadcasts the roster so every peer knows every identity.
@rpc("any_peer", "reliable", "call_remote")
func submit_identity(player_name: String, color_html: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := int(multiplayer.get_remote_sender_id())
	connected_players[sender] = player_name
	player_colors[sender] = color_html
	_broadcast_roster()

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
	else:
		# Bind ONCE up front with a loud error: silent dead advertising made
		# hosts invisible on LAN while looking perfectly normal locally.
		var bind_err = discovery_socket.bind(DISCOVERY_PORT)
		if bind_err != OK:
			push_error("[NET] Cannot bind discovery UDP %d (another instance/app owns it?) — LAN SCAN WILL NOT FIND THIS HOST. Friends can still JOIN by typing this machine's IP: %s" % [DISCOVERY_PORT, local_ip()])
			host_address = local_ip()

func _stop_discovery() -> void:
	discovery_active = false
	if discovery_socket.is_bound():
		discovery_socket.close()

func _request_host_discovery() -> void:
	if not discovery_socket.is_bound():
		return
	discovery_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	discovery_socket.put_packet("FRIDAY5PM_DISCOVER".to_utf8_buffer())

## Best-effort local IPv4 (first private-range address), "" if unavailable.
static func local_ip() -> String:
	for addr in IP.get_local_addresses():
		var s := String(addr)
		if s.begins_with("192.168.") or s.begins_with("10.") \
				or s.begins_with("172.16.") or s.begins_with("172.17.") \
				or s.begins_with("172.18.") or s.begins_with("172.19.") \
				or s.begins_with("172.2") or s.begins_with("172.30.") \
				or s.begins_with("172.31."):
			return s
	return ""

# --- HOTSPOT MODE -------------------------------------------------------------
# Phone-hotspot play: friends join the phone's hotspot, but many phones
# isolate clients from each other (AP isolation), so UDP broadcasts never
# arrive and the SCAN finds nothing. Fallback: unicast the discovery ping
# to every plausible gateway address of the common hotspot subnets. The
# host answers from its discovery listener exactly as it would to a
# broadcast, so no host-side changes are needed.

signal hotspot_probe_result(address: String, found: bool)

## Common hotspot/phone-tether subnets. Each entry: [prefix, last-octet
## candidates]. Kept small — unicast pings are cheap but not free.
const HOTSPOT_PREFIXES := [
	["192.168.43.", [1, 2, 100, 101, 102]],       # Android classic
	["192.168.49.", [1, 2, 100, 101, 102]],       # Android newer
	["172.20.10.", [1, 2, 3, 14]],                # iPhone personal hotspot
	["192.168.137.", [1, 2]],                     # Windows mobile hotspot
]

var hotspot_sweep_done := true
var _hotspot_queue: Array[String] = []
var _hotspot_reply_socket := PacketPeerUDP.new()

## Called from the discovery timer until the sweep completes (a few IPs
## per tick so the lobby stays responsive).
func _hotspot_sweep_tick() -> void:
	if _hotspot_queue.is_empty():
		_build_hotspot_queue()
	var batch := 0
	while not _hotspot_queue.is_empty() and batch < 12:
		var ip: String = _hotspot_queue.pop_front()
		if ip == local_ip():
			continue  # don't ping ourselves
		discovery_socket.set_dest_address(ip, DISCOVERY_PORT)
		discovery_socket.put_packet("FRIDAY5PM_DISCOVER".to_utf8_buffer())
		batch += 1
	if _hotspot_queue.is_empty():
		hotspot_sweep_done = true
		print("[NET] hotspot sweep complete (no extra hosts found unless listed above)")

func _build_hotspot_queue() -> void:
	hotspot_sweep_done = false
	_hotspot_queue.clear()
	# Prefer the subnet we're actually ON first (its gateway + neighbors).
	var own := local_ip()
	if own != "":
		var octets := own.split(".")
		if octets.size() == 4:
			var prefix := "%s.%s.%s." % [octets[0], octets[1], octets[2]]
			for last in [1, 2, 100, 101, 102, 103, 14]:
				_hotspot_queue.append(prefix + str(last))
	for entry in HOTSPOT_PREFIXES:
		var prefix: String = entry[0]
		if own.begins_with(prefix):
			continue  # already queued
		for last in entry[1]:
			_hotspot_queue.append(prefix + str(last))

## Direct-connect helper for the "no Wi-Fi at all" case: the HOST player
## turns on their phone hotspot; everyone joins that hotspot network; the
## host reads this IP off their own screen and friends type it in.
static func hotspot_host_hint() -> String:
	return local_ip()

func _advertise_host() -> void:
	if not discovery_socket.is_bound():
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
	# PHASE 5 layout sync: capture the host's layout pick NOW so it rides
	# inside the same reliable RPC that starts the match — no ordering gap
	# between "apply layout" and "load scene" on any peer.
	var layouts = load("res://scripts/LevelLayouts.gd")
	if layouts and layouts.is_valid(layouts.current):
		match_layout = String(layouts.current)
	begin_match.rpc(match_layout)
	match_started.emit()
	return true

@rpc("authority", "reliable", "call_local")
func begin_match(layout: String) -> void:
	match_running = true
	_apply_authoritative_layout(layout)
	match_started.emit()

## Called by a client right after connecting: if the host is mid-match,
## drop the new peer straight into the race instead of the dead lobby.
@rpc("any_peer", "reliable", "call_remote")
func request_match_state() -> void:
	if multiplayer.is_server() and match_running:
		confirm_match_state.rpc_id(multiplayer.get_remote_sender_id(), match_layout)

@rpc("authority", "reliable", "call_remote")
func confirm_match_state(layout: String) -> void:
	_apply_authoritative_layout(layout)
	match_started.emit()

## PHASE 5 layout sync: a peer applies the host's layout pick as process
## state (LevelLayouts.current). On the host this is a no-op re-assert of
## its own pick; on clients it overrides their menu pick for THIS match
## only — the saved cfg preference is untouched, and Main.gd re-applies
## the saved pick when the menu reloads after the match.
func _apply_authoritative_layout(layout: String) -> void:
	if layout.is_empty():
		return
	match_layout = layout
	var layouts = load("res://scripts/LevelLayouts.gd")
	if layouts and layouts.is_valid(layout):
		layouts.set_current(layout)

@rpc("any_peer", "reliable", "call_remote")
func request_roster() -> void:
	if multiplayer.is_server():
		var sender = multiplayer.get_remote_sender_id()
		send_roster.rpc_id(sender, connected_players, ready_players, player_colors)

func _broadcast_roster() -> void:
	if is_server():
		broadcast_roster.rpc(connected_players, ready_players, player_colors)

@rpc("authority", "reliable", "call_remote")
func send_roster(names: Dictionary, readiness: Dictionary, colors: Dictionary) -> void:
	# Re-key as int: peer ids arrive as Floats inside RPC Dictionaries and
	# float keys never match int lookups (get_player_color, roster prints).
	connected_players.clear()
	ready_players = readiness
	player_colors = colors
	for key in names.keys():
		connected_players[int(key)] = names[key]
	var rkeys: Array = readiness.keys()
	for key in rkeys:
		ready_players[int(key)] = readiness[key]
	var ckeys: Array = colors.keys()
	for key in ckeys:
		player_colors[int(key)] = colors[key]
	for peer_id in connected_players:
		if int(peer_id) != multiplayer.get_unique_id():
			player_connected.emit(int(peer_id), connected_players[peer_id])

@rpc("authority", "reliable", "call_remote")
func broadcast_roster(names: Dictionary, readiness: Dictionary, colors: Dictionary) -> void:
	send_roster(names, readiness, colors)

func get_player_color(peer_id: int) -> Color:
	return Color.from_string(player_colors.get(peer_id, "66ccff"), Color(0.4, 0.8, 1.0))

func broadcast_player_state(position: Vector3, velocity: Vector3, rot_y: float = 0.0) -> void:
	if peer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if is_server():
			_relay_player_state(multiplayer.get_unique_id(), position, velocity, rot_y)
		else:
			submit_player_state.rpc_id(1, position, velocity, rot_y)

@rpc("any_peer", "unreliable", "call_remote")
func submit_player_state(position: Vector3, velocity: Vector3, rot_y: float) -> void:
	if multiplayer.is_server():
		var sender = multiplayer.get_remote_sender_id()
		_relay_player_state(sender, position, velocity, rot_y)

func _relay_player_state(peer_id: int, position: Vector3, velocity: Vector3, rot_y: float) -> void:
	player_states[peer_id] = {"position": position, "velocity": velocity, "rot_y": rot_y}
	# Emit locally too: the relaying server must drive its OWN remote chairs
	# (the announce RPC is call_remote, so it never fires back on the host).
	remote_player_state.emit(peer_id, position, velocity, rot_y)
	broadcast_player_state_rpc.rpc(peer_id, position, velocity, rot_y)

@rpc("authority", "unreliable", "call_remote")
func broadcast_player_state_rpc(peer_id: int, position: Vector3, velocity: Vector3, rot_y: float) -> void:
	player_states[peer_id] = {"position": position, "velocity": velocity, "rot_y": rot_y}
	remote_player_state.emit(peer_id, position, velocity, rot_y)


# ---------------- Phase 5 world-event replication ----------------
# Interactive objects must appear/disappear on every peer. Host relays:
# clients report, server rebroadcasts to all (including reporter via loopback).

func report_trap_drop(position: Vector3, trap_type: String, forced: bool) -> void:
	if not _world_sync_active():
		return
	if is_server():
		_relay_trap_drop(multiplayer.get_unique_id(), position, trap_type, forced)
	else:
		submit_trap_drop.rpc_id(1, position, trap_type, forced)

@rpc("any_peer", "reliable", "call_remote")
func submit_trap_drop(position: Vector3, trap_type: String, forced: bool) -> void:
	if multiplayer.is_server():
		var sender = multiplayer.get_remote_sender_id()
		_relay_trap_drop(sender, position, trap_type, forced)

func _relay_trap_drop(peer_id: int, position: Vector3, trap_type: String, forced: bool) -> void:
	world_trap_dropped.emit(peer_id, position, trap_type, forced)
	announce_trap_drop.rpc(peer_id, position, trap_type, forced)

@rpc("authority", "reliable", "call_remote")
func announce_trap_drop(peer_id: int, position: Vector3, trap_type: String, forced: bool) -> void:
	world_trap_dropped.emit(peer_id, position, trap_type, forced)

func report_pickup_taken(pickup_name: String) -> void:
	if not _world_sync_active():
		return
	if is_server():
		_relay_pickup_taken(multiplayer.get_unique_id(), pickup_name)
	else:
		submit_pickup_taken.rpc_id(1, pickup_name)

@rpc("any_peer", "reliable", "call_remote")
func submit_pickup_taken(pickup_name: String) -> void:
	if multiplayer.is_server():
		var sender = multiplayer.get_remote_sender_id()
		_relay_pickup_taken(sender, pickup_name)

func _relay_pickup_taken(peer_id: int, pickup_name: String) -> void:
	world_pickup_taken.emit(peer_id, pickup_name)
	announce_pickup_taken.rpc(peer_id, pickup_name)

@rpc("authority", "reliable", "call_remote")
func announce_pickup_taken(peer_id: int, pickup_name: String) -> void:
	world_pickup_taken.emit(peer_id, pickup_name)

## Remote stun application (stapler bolt / extinguisher / roomba hits on
## remote peers): the victim's own client applies the stun locally.
func report_remote_stun(peer_id: int, duration: float) -> void:
	if not _world_sync_active():
		return
	if is_server():
		announce_remote_stun.rpc(peer_id, duration)
	else:
		relay_remote_stun.rpc_id(1, peer_id, duration)

@rpc("any_peer", "reliable", "call_remote")
func relay_remote_stun(peer_id: int, duration: float) -> void:
	if multiplayer.is_server():
		announce_remote_stun.rpc(peer_id, duration)

@rpc("authority", "reliable", "call_remote")
func announce_remote_stun(peer_id: int, duration: float) -> void:
	player_stunned.emit(peer_id, duration)

func send_chat(text: String) -> void:
	text = text.strip_edges().substr(0, 120)
	if text.is_empty():
		return
	var sender_name := "Player"
	var manager = get_node_or_null("/root/GameManager")
	if manager:
		sender_name = manager.player_name
	if is_server():
		_relay_chat(multiplayer.get_unique_id(), sender_name, text)
	else:
		submit_chat.rpc_id(1, sender_name, text)

@rpc("any_peer", "reliable", "call_remote")
func submit_chat(sender_name: String, text: String) -> void:
	if multiplayer.is_server():
		var sender = multiplayer.get_remote_sender_id()
		_relay_chat(sender, sender_name, text)

func _relay_chat(peer_id: int, sender_name: String, text: String) -> void:
	chat_message.emit(peer_id, sender_name, text)
	announce_chat.rpc(peer_id, sender_name, text)

@rpc("authority", "reliable", "call_remote")
func announce_chat(peer_id: int, sender_name: String, text: String) -> void:
	chat_message.emit(peer_id, sender_name, text)

func _world_sync_active() -> bool:
	return peer != null and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED