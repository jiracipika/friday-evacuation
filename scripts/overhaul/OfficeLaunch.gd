extends Node3D
const Kit = preload("res://scripts/overhaul/OfficeKit.gd")
const UI = preload("res://scripts/overhaul/OfficeUI.gd")
const Rig = preload("res://scripts/overhaul/VisualRig.gd")
const Design = preload("res://scripts/CharacterDesign.gd")
const Roster = preload("res://scripts/CharacterRoster.gd")
const Profiles = preload("res://scripts/overhaul/HandlingProfiles.gd")
const Skins = preload("res://scripts/ChairSkins.gd")
const Save = preload("res://scripts/overhaul/OverhaulSave.gd")
const MODES := ["evacuation", "hauled", "seek", "pizza"]
const NAMES := ["Evacuation", "Hauled", "Shop & Seek", "Pizza Colony"]
const DESCRIPTIONS := ["Four floors. One weekend. Race four AI coworkers to the parking lot, or chase your ghost.", "Grab the cargo, mind the corners. Deliver three very questionable office appliances together.", "Shop the supply list while avoiding security. In a LAN party, become a prop and hide from the scanner.", "Claim slices, build cheese forts and dodge the pizza cutter. Also: the chef has had enough."]
var session: Node
var panel: VBoxContainer
var message_label: Label
var status_label: Label
var preview: Node3D
var preview_parent: Node3D
var camera: Camera3D
var page := "play"
var selected_mode := 0
var wardrobe := false
var rotation_time := 0.0
var root: Control
var lobby_status: Label

func _ready() -> void:
	session = get_node("/root/OfficeSession")
	session.game = null
	session.start_requested.connect(_start_game)
	session.message.connect(_message)
	session.changed.connect(_refresh_lobby)
	session.identity_profile = Save.setting("profile", "balanced")
	var audio := ConfigFile.new()
	audio.load("user://settings.cfg")
	AudioManager.set_music_volume(float(audio.get_value("audio", "music", 0.5)))
	AudioManager.set_sfx_volume(float(audio.get_value("audio", "sfx", 0.8)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(0.0001, float(audio.get_value("audio", "master", 1.0)))))
	AudioManager.start_music("menu")
	selected_mode = maxi(0, MODES.find(session.configuration.mode))
	_build_stage()
	_build_ui()
	_show_play()
	if session.last_notice != "":
		_message(session.last_notice)

func _build_stage() -> void:
	Kit.environment(self)
	Kit.solid(self, Vector3(16, 0.4, 12), Vector3(0, -0.2, 0), Color("8da4a1"))
	Kit.solid(self, Vector3(16, 4, 0.3), Vector3(0, 2, -5), Kit.IVORY)
	for x in [-5, -1, 3]:
		Kit.decor_box(self, Vector3(2.8, 2.1, 0.06), Vector3(x, 2.4, -4.81), Color("c4d9d5"))
		Kit.decor_box(self, Vector3(3, 0.08, 0.14), Vector3(x, 1.3, -4.7), Kit.INK)
	Kit.prop(self, "desk", Vector3(-1.5, 0, -2.8))
	Kit.prop(self, "plant", Vector3(4.5, 0, -3.3))
	Kit.prop(self, "printer", Vector3(3.5, 0, 1))
	Kit.prop(self, "cabinet", Vector3(1.8, 0, -4))
	Kit.prop(self, "water", Vector3(5.5, 0, -2))
	Kit.text(self, "FRIDAY / 16:59", Vector3(1.5, 3.3, -4.75), 48, Kit.INK)
	preview_parent = Node3D.new()
	preview_parent.position = Vector3(0.6, 0, 0.3)
	add_child(preview_parent)
	_refresh_preview()
	camera = Camera3D.new()
	camera.position = Vector3(5.3, 3.1, 6.5)
	camera.fov = 38
	add_child(camera)
	camera.look_at(Vector3(-1.3, 1.1, -0.8))

func _refresh_preview() -> void:
	if preview:
		preview.free()
	preview = Rig.new()
	preview_parent.add_child(preview)
	preview.configure(GameManager.selected_character_id, GameManager.get_character_design(), GameManager.selected_skin_id)
	preview_parent.rotation.y = PI + 0.3
	session.refresh_identity()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	root = Control.new()
	root.theme = UI.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	root.add_child(margin)
	var body := VBoxContainer.new()
	margin.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := UI.label(header, "FRIDAY 5PM", 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(header, "EVACUATION  /  AFTER HOURS EDITION", 16)
	var row := HBoxContainer.new()
	body.add_child(row)
	for tab in ["Play", "Party", "Coworker", "Settings"]:
		UI.button(row, tab, func():
			if tab == "Settings":
				_show_settings()
			else:
				page = tab.to_lower()
				wardrobe = page == "coworker"
				_refresh_page())
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 435
	content.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(space)
	status_label = UI.label(body, "11 coworkers. A very avoidable incident.", 17)
	message_label = UI.label(body, "Desktop LAN · Browser solo · Cosmetics never change handling", 15)
	UI.button(header, "Credits", _credits)

func _clear() -> void:
	lobby_status = null
	for child in panel.get_children():
		child.free()

func _refresh_page() -> void:
	match page:
		"play": _show_play()
		"party": _show_party()
		"coworker": _show_wardrobe()

func _show_play() -> void:
	_clear()
	UI.label(panel, "YOUR WEEKEND STARTS HERE.", 24)
	UI.option(panel, NAMES, selected_mode, func(index): selected_mode = index; session.configuration.mode = MODES[index]; _show_play())
	var description := UI.label(panel, DESCRIPTIONS[selected_mode], 17)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 380
	UI.button(panel, "CLOCK OUT  →", func():
		session.close()
		session.configuration.mode = MODES[selected_mode]
		session.start())
	if selected_mode == 0:
		UI.label(panel, "THE ROUTE", 14)
		var layouts := ["open_plan", "cubicle_maze", "executive"]
		UI.option(panel, ["Open Plan", "Cubicle Maze", "Executive Suite"], maxi(0, layouts.find(session.configuration.layout)), func(i): session.configuration.layout = layouts[i])
		var trial_toggle := CheckButton.new()
		trial_toggle.text = "Time trial · your personal best ghost"
		trial_toggle.button_pressed = session.configuration.trial
		trial_toggle.toggled.connect(func(value): session.configuration.trial = value)
		panel.add_child(trial_toggle)
	if selected_mode in [0, 1, 3]:
		UI.label(panel, "COWORKERS", 14)
		UI.option(panel, ["Easy · finding their feet", "Normal · Friday regulars", "Hard · already clocked out"], session.configuration.difficulty, func(i): session.configuration.difficulty = i)
		UI.option(panel, ["4 AI coworkers", "3 AI coworkers", "2 AI coworkers", "1 AI coworker", "Solo"], 4 - int(session.configuration.bots), func(i): session.configuration.bots = 4 - i)
	_profile()
	UI.label(panel, "WASD / stick steer · SPACE / A boost\nSHIFT / LT drift · E / X hop · Q / B item", 14)
	status_label.text = Roster.get_character(GameManager.selected_character_id).name + " is ready for absolutely none of this."

func _profile() -> void:
	UI.label(panel, "HANDLING · ALL AVAILABLE", 14)
	UI.option(panel, ["Balanced", "Agile", "Heavy"], maxi(0, Profiles.IDS.find(session.identity_profile)), func(i): session.identity_profile = Profiles.IDS[i]; Save.set_setting("profile", session.identity_profile); _refresh_page())
	var text := UI.label(panel, Profiles.get_profile(session.identity_profile).description, 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _show_wardrobe() -> void:
	_clear()
	UI.label(panel, "MEET YOUR OFFICE SELF.", 24)
	var player_name := LineEdit.new()
	player_name.text = GameManager.player_name
	player_name.placeholder_text = "Your name in the office"
	player_name.max_length = 24
	player_name.text_changed.connect(func(value):
		GameManager.player_name = value.strip_edges().left(24)
		GameManager.save_identity()
		session.refresh_identity())
	panel.add_child(player_name)
	var names: Array = []
	var ids: Array = []
	for character in Roster.CHARACTERS:
		names.append(character.name)
		ids.append(character.id)
	UI.option(panel, names, maxi(0, ids.find(GameManager.selected_character_id)), func(i):
		GameManager.selected_character_id = ids[i]
		GameManager.save_identity()
		_refresh_preview()
		_show_wardrobe())
	var character: Dictionary = Roster.get_character(GameManager.selected_character_id)
	UI.label(panel, character.role, 14)
	var tagline := UI.label(panel, character.tagline, 16)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var design: Dictionary = Design.resolve(character, GameManager.get_character_design())
	for key in Design.OPTIONS:
		var row := HBoxContainer.new()
		panel.add_child(row)
		var label := UI.label(row, Design.LABELS[key], 13)
		label.custom_minimum_size.x = 125
		var options: Array = Design.OPTIONS[key]
		var words: Array = []
		for option in options:
			words.append(Design.display_name(option))
		var select := UI.option(row, words, maxi(0, options.find(design[key])), func(i):
			var overrides: Dictionary = GameManager.get_character_design()
			overrides[key] = options[i]
			GameManager.set_character_design(overrides)
			_refresh_preview())
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(panel, "CHAIR · COSMETIC CAREER REWARDS", 14)
	var skins: Array = []
	var unlocked: Array = []
	for skin in Skins.SKINS:
		if StatsManager.races_won >= skin.unlock_wins:
			skins.append(skin.name)
			unlocked.append(skin.id)
	UI.option(panel, skins, maxi(0, unlocked.find(GameManager.selected_skin_id)), func(i):
		GameManager.selected_skin_id = unlocked[i]
		GameManager.save_identity()
		_refresh_preview())
	UI.button(panel, "Reset to coworker preset", func(): GameManager.set_character_design({}); _refresh_preview(); _show_wardrobe())
	status_label.text = "Drag the coworker to rotate · Appearance is independent of handling."

func _show_party() -> void:
	_clear()
	UI.label(panel, "CLOCK OUT TOGETHER.", 24)
	if OS.has_feature("web"):
		var text := UI.label(panel, "LAN parties need the desktop app. Browser play has all four solo modes, AI and time trials.", 18)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	if session.active:
		lobby_status = UI.label(panel, "", 18)
		_refresh_lobby()
		if multiplayer.is_server():
			UI.label(panel, "MODE / ROUTE / AI use your Play settings.", 15)
			UI.button(panel, "START THE SHIFT", func(): session.start())
		else:
			UI.button(panel, "READY / NOT READY", func(): session.set_ready(not session.roster.get(multiplayer.get_unique_id(), {}).get("ready", false)))
		UI.button(panel, "Leave party", func(): session.close(); _show_party())
		return
	UI.label(panel, "Up to 8 coworkers on the same network.\nThe host simulates the whole shift.", 17)
	UI.button(panel, "Host an office", func():
		session.configuration.mode = MODES[selected_mode]
		if session.host(): _show_party())
	var address := LineEdit.new()
	address.placeholder_text = "Host address · e.g. 192.168.1.12"
	address.custom_minimum_size.y = 44
	panel.add_child(address)
	UI.button(panel, "Join by address", func():
		if session.join(address.text): _show_party())
	UI.button(panel, "Find offices on this network", func(): session.scan(); _message("Looking for local offices…"))
	lobby_status = UI.label(panel, "", 16)
	_refresh_lobby()

func _refresh_lobby() -> void:
	if not is_instance_valid(lobby_status):
		return
	var text := ""
	for id in session.roster:
		var player: Dictionary = session.roster[id]
		text += "%s  ·  %s\n" % [player.name, "READY" if player.ready else "clocking in…"]
	if session.active and session.roster.is_empty():
		text = "Connecting to the host…"
	for address in session.hosts:
		text += "%s · %s\n" % [session.hosts[address], address]
	lobby_status.text = text

func _show_settings() -> void:
	var settings = load("res://scripts/Settings.gd").new()
	root.add_child(settings)

func _credits() -> void:
	_clear()
	UI.label(panel, "OFFICE SUPPLIES & CREDIT", 24)
	var text := UI.label(panel, "Coworkers and office kit authored for Friday 5PM.\n\nOffice chair adapted from NVIDIA SimReady, chair_office_fabric_manager_a01. Licensed CC BY 4.0. Simplified geometry, rebuilt materials and LODs.\n\nNVIDIA / Hugging Face:\nhuggingface.co/datasets/nvidia/simready-assets\n\ncreativecommons.org/licenses/by/4.0/", 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(panel, "Back", _refresh_page)

func _message(words: String) -> void:
	message_label.text = words
	if page == "party" and not session.active:
		_show_party()

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/overhaul/OfficeGame.tscn")

func _process(delta: float) -> void:
	rotation_time += delta
	if preview:
		preview.animate(delta, 0, false, false, false, 0)
		if not wardrobe:
			preview_parent.rotation.y = PI + 0.3 + sin(rotation_time * 0.35) * 0.15

func _unhandled_input(event: InputEvent) -> void:
	if wardrobe and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and event.position.x > 500:
		preview_parent.rotation.y += event.relative.x * 0.01
