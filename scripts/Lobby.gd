extends Control

signal host_requested
signal join_requested(address: String)
signal close_requested

var status_label: Label
var address_edit: LineEdit
var name_edit: LineEdit
var color_row: HBoxContainer
var swatch_buttons: Array[Button] = []
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

	# --- Identity: name + color (Phase 5) ---
	var gm = get_node_or_null("/root/GameManager")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Your name"
	name_edit.text = gm.player_name if gm else "Player1"
	name_edit.max_length = 16
	name_edit.text_changed.connect(_on_name_changed)
	box.add_child(name_edit)
	color_row = HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 6)
	box.add_child(color_row)
	if gm and "PLAYER_COLORS" in gm:
		for color in gm.PLAYER_COLORS:
			var swatch := Button.new()
			swatch.custom_minimum_size = Vector2(36, 30)
			swatch.focus_mode = Control.FOCUS_NONE
			var style := StyleBoxFlat.new()
			style.bg_color = color
			style.set_corner_radius_all(8)
			swatch.add_theme_stylebox_override("normal", style)
			var hover_style := style.duplicate()
			hover_style.border_color = Color.WHITE
			hover_style.set_border_width_all(2)
			swatch.add_theme_stylebox_override("hover", hover_style)
			var pressed_style := style.duplicate()
			pressed_style.border_color = Color(1, 1, 1, 0.6)
			pressed_style.set_border_width_all(3)
			swatch.add_theme_stylebox_override("pressed", pressed_style)
			swatch.pressed.connect(_on_color_picked.bind(color))
			color_row.add_child(swatch)
			swatch_buttons.append(swatch)
	_mark_selected_swatch()
	address_edit = LineEdit.new()
	address_edit.placeholder_text = "LAN address (default: 127.0.0.1)"
	address_edit.text = "127.0.0.1"
	box.add_child(address_edit)
	# HOTSPOT MODE: play over a phone hotspot when no Wi-Fi exists. The
	# host shows its address to read out; joiners get one-tap fills for
	# the common hotspot gateway addresses.
	var hotspot_row := HBoxContainer.new()
	hotspot_row.add_theme_constant_override("separation", 6)
	box.add_child(hotspot_row)
	var hot_43 := Button.new()
	hot_43.text = "192.168.43.1"
	hot_43.tooltip_text = "Android hotspot gateway"
	hot_43.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hot_43.focus_mode = Control.FOCUS_NONE
	hot_43.pressed.connect(func(): address_edit.text = "192.168.43.1")
	hotspot_row.add_child(hot_43)
	var hot_49 := Button.new()
	hot_49.text = "192.168.49.1"
	hot_49.tooltip_text = "Android hotspot gateway (newer)"
	hot_49.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hot_49.focus_mode = Control.FOCUS_NONE
	hot_49.pressed.connect(func(): address_edit.text = "192.168.49.1")
	hotspot_row.add_child(hot_49)
	var hot_ios := Button.new()
	hot_ios.text = "172.20.10.1"
	hot_ios.tooltip_text = "iPhone personal hotspot gateway"
	hot_ios.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hot_ios.focus_mode = Control.FOCUS_NONE
	hot_ios.pressed.connect(func(): address_edit.text = "172.20.10.1")
	hotspot_row.add_child(hot_ios)
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
		if not multiplayer.is_server():
			multiplayer.server_disconnected.connect(_on_host_lost)
		network.player_ready_changed.connect(_on_ready_changed)
		network.lan_host_found.connect(_on_lan_host_found)
		network.match_started.connect(_on_match_started)
		network.discover_lan_hosts()
	_refresh_players()

func _on_name_changed(new_text: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.player_name = new_text.strip_edges().substr(0, 16) if new_text.strip_edges() != "" else "Player1"
		gm.save_identity()

func _on_color_picked(color: Color) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.player_color = color
		gm.save_identity()
	_mark_selected_swatch()

func _mark_selected_swatch() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	for i in range(swatch_buttons.size()):
		var selected: bool = i < gm.PLAYER_COLORS.size() and gm.PLAYER_COLORS[i].is_equal_approx(gm.player_color)
		swatch_buttons[i].modulate = Color.WHITE if selected else Color(1, 1, 1, 0.45)

func _host() -> void:
	if network and network.host_game():
		host_requested.emit()
		ready_button.disabled = false
		start_button.disabled = true
		# HOTSPOT MODE: show the host's address prominently — this is the
		# IP friends type when the SCAN can't find them (AP isolation).
		var hint: String = network.hotspot_host_hint()
		if hint == "":
			hint = "?"
		var map_note: String = _map_note()
		status_label.text = "HOSTING on UDP 5005 — your address: %s  (friends: JOIN -> type this)%s" % [hint, map_note]
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
	status_label.text = "CONNECTED — ready when you are%s" % _map_note()
	_refresh_players()

func _on_failed() -> void:
	status_label.text = "CONNECTION FAILED — check address and firewall"

func _on_player_changed(_peer_id: int, _name: String) -> void:
	_refresh_players()

func _on_player_disconnected(_peer_id: int) -> void:
	_refresh_players()

func _on_host_lost() -> void:
	status_label.text = "HOST DISCONNECTED"
	network.close_connection()
	_refresh_players()

## PHASE 5 layout sync UX: one honest line about whose map pick counts.
## Host: your menu MAP pick is what everyone races. Joiner: you'll get the
## host's map at START — your own pick stays saved for when YOU host.
func _map_note() -> String:
	var layouts = load("res://scripts/LevelLayouts.gd")
	if layouts == null:
		return ""
	var label: String = layouts.display_name(String(layouts.current))
	if network and network.is_server():
		return "\nMAP: %s (yours — guests sync to this)" % label
	return "\nMAP: %s (yours locally — host's map is used at START)" % label

func _refresh_players() -> void:
	if not player_list:
		return
	player_list.clear()
	var own_id: int = network.multiplayer.get_unique_id() if network else 1
	if network:
		for peer_id in network.connected_players:
			var peer_ready: bool = network.ready_players.get(peer_id, false)
			var display_name: String = String(network.connected_players[peer_id])
			if int(peer_id) == own_id:
				display_name += "  (you)"
			player_list.add_item("%s  •  %s  •  %s" % [
				display_name,
				_avatar_label(int(peer_id)),
				"READY" if peer_ready else "NOT READY",
			])
			if network.has_method("get_player_color"):
				player_list.set_item_custom_fg_color(player_list.item_count - 1, network.get_player_color(int(peer_id)))

## Player-visible proof that LAN cosmetic identity arrived before match start.
## Keep this compact: ItemList has a fixed 130px budget at 720p.
func _avatar_label(peer_id: int) -> String:
	if network == null:
		return "DEFAULT RIDER / OFFICE STANDARD"
	var character_id: String = String(network.get_player_character(peer_id)) if network.has_method("get_player_character") else "deadline_dana"
	var skin_id: String = String(network.get_player_skin(peer_id)) if network.has_method("get_player_skin") else "office_standard"
	var roster: GDScript = load("res://scripts/CharacterRoster.gd")
	var skins: GDScript = load("res://scripts/ChairSkins.gd")
	var character_name: String = String(roster.get_character(character_id).get("name", "Default Rider")) if roster else "Default Rider"
	var skin_name: String = String(skins.display_name(skin_id)) if skins else "Office Standard"
	return "%s / %s" % [character_name, skin_name]
