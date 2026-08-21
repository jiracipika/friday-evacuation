# ChatOverlay.gd — Phase 5B in-race chat overlay.
# Enter opens a text input at the bottom; messages fade after 5s; sent
# messages relay through Network.send_chat so all peers see them.
# Offline (no peer) it stays dormant. Mount via Evacuation HUD setup.
extends CanvasLayer

const MAX_SHOWN := 6
const FADE_AFTER := 5.0
const MAX_WIDTH := 460.0

var _panel: PanelContainer
var _log_box: VBoxContainer
var _input: LineEdit
var _input_open: bool = false
var _network

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_network = get_node_or_null("/root/Network")
	if _network and _network.has_signal("chat_message"):
		_network.chat_message.connect(_on_chat_message)

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -44
	_panel.offset_left = 16
	_panel.offset_right = -16
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.06, 0.88)
	style.border_color = Color(1, 0.6, 0.1, 0.6)
	style.border_width_top = 2
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_input = LineEdit.new()
	_input.placeholder_text = "Say something… (Enter to send, Esc to cancel)"
	_input.max_length = 120
	_input.visible = false
	_panel.add_child(_input)
	_input.text_submitted.connect(_on_submitted)

	_log_box = VBoxContainer.new()
	_log_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_log_box.offset_top = -200
	_log_box.offset_left = 16
	_log_box.offset_right = -16
	_log_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log_box)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		return  # never fight the pause menu
	if event is InputEventKey and event.pressed:
		if _input_open:
			if event.keycode == KEY_ESCAPE:
				_close_input()
				get_viewport().set_input_as_handled()
		else:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				if _is_online():
					_open_input()
					get_viewport().set_input_as_handled()

func _is_online() -> bool:
	return _network != null and _network.peer != null

func _open_input() -> void:
	_input_open = true
	_panel.visible = true
	_input.visible = true
	_input.grab_focus()

func _close_input() -> void:
	_input_open = false
	_input.text = ""
	_panel.visible = false
	_input.visible = false
	_input.release_focus()

func _on_submitted(text: String) -> void:
	_close_input()
	if _network and _network.has_method("send_chat"):
		_network.send_chat(text)

func _on_chat_message(peer_id: int, sender_name: String, text: String) -> void:
	var line := Label.new()
	line.text = "%s: %s" % [sender_name, text]
	line.add_theme_font_size_override("font_size", 15)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := Color(1, 1, 1, 0.92)
	if _network and _network.has_method("get_player_color"):
		color = _network.get_player_color(peer_id)
	line.add_theme_color_override("font_color", color)
	_log_box.add_child(line)
	while _log_box.get_child_count() > MAX_SHOWN:
		var oldest := _log_box.get_child(0)
		oldest.queue_free()
	var tween := line.create_tween()
	tween.tween_interval(FADE_AFTER)
	tween.tween_property(line, "modulate:a", 0.0, 0.8)
	tween.tween_callback(line.queue_free)
