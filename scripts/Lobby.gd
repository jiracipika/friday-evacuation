extends Control

signal host_requested
signal join_requested(address: String)
signal close_requested

var status_label: Label
var address_edit: LineEdit
var host_button: Button
var join_button: Button
var ready_button: Button
var start_button: Button
var player_list: ItemList
var host_list: ItemList
var lobby_ready := false
var network
var discovered_hosts: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.02, 0.04, 0.96)
	add_child(backdrop)
	var panel = PanelContainer.new()
	panel.position = Vector2(0.5 * get_viewport_rect().size.x - 270, 0.5 * get_viewport_rect().size.y - 220)
	panel.size = Vector2(540, 440)
	add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title = Label.new()
	title.text = "MULTIPLAYER LOBBY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	status_label = Label.new()
	status_label.text = "Choose HOST or enter a LAN address to JOIN."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status_label)
	address_edit = LineEdit.new()
	address_edit.placeholder_text = "LAN address (default: 127.0.0.1)"
	address_edit.text = "127.0.0.1"
	box.add_child(address_edit)
	var scan = Button.new()
	scan.text = "SCAN LOCAL WI-FI"
	scan.pressed.connect(_scan_lan)
	box.add_child(scan)
	host_list = ItemList.new()
	host_list.custom_minimum_size = Vector2(0, 70)
	host_list.item_activated.connect(_select_host)
	box.add_child(host_list)
	var row = HBoxContainer.new()
	host_button = Button.new()
	host_button.text = "HOST"
	host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_button.pressed.connect(_host)
	row.add_child(host_button)
	join_button = Button.new()
	join_button.text = "JOIN"
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_button.pressed.connect(_join)
	row.add_child(join_button)
	box.add_child(row)
	player_list = ItemList.new()
	player_list.custom_minimum_size = Vector2(0, 130)
	box.add_child(player_list)
	ready_button = Button.new()
	ready_button.text = "READY UP"
	ready_button.disabled = true
	ready_button.pressed.connect(_toggle_ready)
	box.add_child(ready_button)
	start_button = Button.new()
	start_button.text = "START MATCH (HOST)"
	start_button.disabled = true
	start_button.pressed.connect(_start_match)
	box.add_child(start_button)
	var back = Button.new()
	back.text = "BACK"
	back.pressed.connect(close_requested.emit)
	box.add_child(back)
	network = get_node_or_null("/root/Network")
	if network:
		network.server_started.connect(_on_server_started)
		network.connection_succeeded.connect(_on_connected)
		network.connection_failed.connect(_on_failed)
		network.player_connected.connect(_on_player_changed)
		network.player_disconnected.connect(_on_player_disconnected)
		network.player_ready_changed.connect(_on_ready_changed)
		network.lan_host_found.connect(_on_lan_host_found)
		network.match_started.connect(_on_match_started)
		network.discover_lan_hosts()
	_refresh_players()

func _host() -> void:
	if network and network.host_game():
		host_requested.emit()
		ready_button.disabled = false
		start_button.disabled = true
		status_label.text = "HOSTING on UDP 5005 — waiting for players"
		network.set_ready(false)
		_refresh_players()

func _join() -> void:
	var address = address_edit.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	if network and network.join_game(address):
		join_requested.emit(address)
		status_label.text = "CONNECTING to %s..." % address

func _scan_lan() -> void:
	discovered_hosts.clear()
	host_list.clear()
	status_label.text = "SCANNING LOCAL WI-FI..."
	if network:
		network.discover_lan_hosts()

func _select_host(index: int) -> void:
	var addresses = discovered_hosts.keys()
	if index >= 0 and index < addresses.size():
		address_edit.text = addresses[index]
		_join()

func _on_lan_host_found(address: String, host_name: String, player_count: int) -> void:
	if not discovered_hosts.has(address):
		discovered_hosts[address] = host_name
		host_list.add_item("%s  •  %s  •  %d/%d players" % [host_name, address, player_count, 8])
	status_label.text = "%d LAN host(s) found" % discovered_hosts.size()

func _start_match() -> void:
	if network and network.start_match():
		status_label.text = "STARTING MATCH..."

func _on_ready_changed(_peer_id: int, _is_ready: bool) -> void:
	_refresh_players()
	if network and network.is_server():
		start_button.disabled = not network.all_players_ready()

func _on_match_started() -> void:
	close_requested.emit()
	get_tree().change_scene_to_file("res://scenes/Evacuation.tscn")

func _toggle_ready() -> void:
	lobby_ready = not lobby_ready
	ready_button.text = "READY — WAITING" if lobby_ready else "READY UP"
	if network and network.has_method("set_ready"):
		network.set_ready(lobby_ready)
	_refresh_players()

func _on_server_started(port: int) -> void:
	status_label.text = "HOSTING on UDP %d" % port

func _on_connected() -> void:
	ready_button.disabled = false
	start_button.disabled = true
	status_label.text = "CONNECTED — ready when you are"
	_refresh_players()

func _on_failed() -> void:
	status_label.text = "CONNECTION FAILED — check address and firewall"

func _on_player_changed(_peer_id: int, _name: String) -> void:
	_refresh_players()

func _on_player_disconnected(_peer_id: int) -> void:
	_refresh_players()

func _refresh_players() -> void:
	if not player_list:
		return
	player_list.clear()
	player_list.add_item("You  •  %s" % ("READY" if lobby_ready else "NOT READY"))
	if network:
		for peer_id in network.connected_players:
			var peer_ready = network.ready_players.get(peer_id, false)
			player_list.add_item("Player_%d  •  %s" % [peer_id, "READY" if peer_ready else "NOT READY"])
