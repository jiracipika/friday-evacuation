extends Node3D
const A11y = preload("res://scripts/Accessibility.gd")
const Art = preload("res://scripts/overhaul/OfficeArt.gd")
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
const DESCRIPTIONS := ["Four floors. One weekend. Race your coworkers to the parking lot, or chase your ghost.", "Grab the cargo, mind the corners. Deliver three very questionable office appliances together.", "Shop the supply list while avoiding security. In a LAN party, become a prop and hide from the scanner.", "Claim slices, build cheese forts and dodge the pizza cutter. Also: the chef has had enough."]
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
var sheet: ColorRect
var nav_bar: HBoxContainer
var card: PanelContainer
var footer: VBoxContainer
var ticket: PanelContainer
var nav_backdrop: ColorRect
var actions: VBoxContainer
var setup_open := false
var reduced_motion := false
var nav: Dictionary = {}
const MODE_DETAILS := ["CHAIR RACE", "CO-OP DELIVERY", "HIDE & SEEK", "TERRITORY"]

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
	reduced_motion = A11y.reduced_motion_enabled()
	_build_stage()
	_build_ui()
	_show_play()
	root.resized.connect(_layout)
	get_window().size_changed.connect(_fit_window)
	_fit_window()
	if session.last_notice != "":
		_message(session.last_notice)

func _build_stage() -> void:
	Kit.environment(self)
	Art.stage(self)
	preview_parent = Node3D.new()
	preview_parent.position = Vector3(1.1, 0, 0.4)
	add_child(preview_parent)
	_refresh_preview()
	camera = Camera3D.new()
	camera.position = Vector3(5.3, 3.1, 6.5)
	camera.fov = 34
	add_child(camera)
	camera.look_at(Vector3(-1.5, 1.2, -0.4))

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
	sheet = ColorRect.new()
	sheet.color = UI.PAPER
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sheet)
	var header := ColorRect.new()
	header.color = UI.PAPER
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 76
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	var brand := HBoxContainer.new()
	brand.position = Vector2(24, 14)
	root.add_child(brand)
	var mark := PanelContainer.new()
	mark.add_theme_stylebox_override("panel", UI.style(UI.ORANGE, 2, 5))
	brand.add_child(mark)
	UI.heading(mark, "↗", 28)
	UI.heading(brand, "FRIDAY 5PM", 32)
	nav_backdrop = ColorRect.new()
	nav_backdrop.color = UI.PAPER
	nav_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nav_backdrop)
	nav_bar = HBoxContainer.new()
	root.add_child(nav_bar)
	for tab in ["Play", "Party", "Coworker", "Settings", "Credits"]:
		var key: String = tab.to_lower()
		nav[key] = UI.button(nav_bar, tab, _open_page.bind(key))
		nav[key].add_theme_font_size_override("font_size", 14)
		nav[key].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.style(UI.PAPER, 0, 2))
	root.add_child(card)
	card.minimum_size_changed.connect(func(): _layout.call_deferred())
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	ticket = PanelContainer.new()
	ticket.add_theme_stylebox_override("panel", UI.style(UI.INK, 2, 16))
	root.add_child(ticket)
	var stamp := VBoxContainer.new()
	stamp.add_theme_constant_override("separation", 0)
	ticket.add_child(stamp)
	UI.label(stamp, "FRIDAY  /  LOCAL TIME", 11, UI.PAPER)
	UI.heading(stamp, "16:59", 56, UI.PAPER)
	footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation", 2)
	root.add_child(footer)
	status_label = UI.label(footer, "", 12, UI.INK)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label = UI.label(footer, "SOLO IN BROWSER  /  LOCAL MULTIPLAYER ON DESKTOP", 10, UI.MUTED)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _fit_window() -> void:
	UI.fit_window(get_window())
	_layout.call_deferred()

func _layout() -> void:
	var width := root.size.x
	var height := root.size.y
	var compact := width < 760
	var home := page == "play" and not setup_open
	var inset := 24.0 if compact else 36.0
	var column := width - 2 * inset if compact else 440.0
	var portrait_preview := compact and wardrobe
	var top := 374.0 if portrait_preview else 146.0 if compact else 100.0
	var bottom := height - 174.0 if home else height - 62.0
	sheet.position.y = top if portrait_preview else 0.0
	sheet.size = Vector2(width if compact else 512, height - sheet.position.y)
	nav_backdrop.position.y = 76
	nav_backdrop.size = Vector2(width, 58 if compact else 0)
	if portrait_preview:
		camera.look_at(Vector3(0.85, -0.92, 0.1))
		camera.fov = 47
	else:
		camera.look_at(Vector3(-1.5, 1.2, -0.4))
		camera.fov = 34
	nav_bar.position = Vector2(inset if compact else width - 476.0, 78 if compact else 14)
	nav_bar.size = Vector2(column if compact else 440, 44)
	card.position = Vector2(inset, top)
	card.size = Vector2(column, maxf(80, bottom - top))
	actions.position = Vector2(inset, height - 160)
	actions.size.x = column
	actions.visible = home
	footer.position = Vector2(inset, height - 47)
	footer.size.x = column
	ticket.position = Vector2(width - 190, 100)
	ticket.visible = not compact and not wardrobe

func _open_page(key: String) -> void:
	if key == "settings":
		_show_settings()
		return
	page = key
	wardrobe = page == "coworker"
	setup_open = false
	_refresh_page()

func _select_mode(index: int) -> void:
	selected_mode = index
	session.configuration.mode = MODES[index]
	_show_play()
	var choice := panel.find_child("Mode_" + MODES[index], true, false) as Button
	choice.grab_focus()

func _launch_solo() -> void:
	session.close()
	session.configuration.mode = MODES[selected_mode]
	session.start()

func _clear() -> void:
	lobby_status = null
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	panel.get_parent().scroll_vertical = 0
	for key in nav:
		var selected: bool = key == page
		nav[key].add_theme_stylebox_override("normal", UI.outlined(UI.INK, UI.INK) if selected else UI.outlined(UI.PAPER))
		nav[key].add_theme_color_override("font_color", UI.PAPER if selected else UI.INK)
		nav[key].add_theme_stylebox_override("hover", UI.outlined(UI.INK.lightened(0.12), UI.INK) if selected else UI.outlined(UI.PAPER.darkened(0.06)))
		nav[key].add_theme_color_override("font_hover_color", UI.PAPER if selected else UI.INK)
	_layout.call_deferred()

func _refresh_page() -> void:
	match page:
		"play": _show_play()
		"party": _show_party()
		"coworker": _show_wardrobe()
		"credits": _credits()

func _show_play() -> void:
	_clear()
	if setup_open:
		_show_setup()
		return
	UI.label(panel, "OFFICE CHAIR RACING  /  AFTER HOURS", 12, UI.MUTED)
	var title := UI.heading(panel, "THE WEEKEND\nWON'T WAIT.", 55)
	title.add_theme_constant_override("line_spacing", -15)
	UI.rule(panel)
	UI.label(panel, "CHOOSE YOUR EXIT STRATEGY", 12, UI.MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(grid)
	for index in MODES.size():
		var selected := index == selected_mode
		var mode_button := UI.button(grid, NAMES[index].to_upper() + "\n" + MODE_DETAILS[index], _select_mode.bind(index))
		mode_button.name = "Mode_" + MODES[index]
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.custom_minimum_size.y = 59
		mode_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		mode_button.tooltip_text = DESCRIPTIONS[index]
		mode_button.add_theme_font_override("font", UI.DISPLAY)
		mode_button.add_theme_font_size_override("font_size", 19)
		if selected:
			mode_button.add_theme_stylebox_override("normal", UI.outlined(UI.INK, UI.INK))
			mode_button.add_theme_stylebox_override("hover", UI.outlined(UI.INK.lightened(0.12), UI.INK))
			for state in ["font_color", "font_hover_color", "font_focus_color"]:
				mode_button.add_theme_color_override(state, UI.PAPER)
	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.text = DESCRIPTIONS[selected_mode]
	panel.add_child(description)
	var setup := UI.button(actions, _setup_summary() + "   /   SETUP →", func():
		setup_open = true
		_show_play())
	setup.add_theme_font_size_override("font_size", 13)
	UI.primary(actions, "CLOCK OUT   ↗", _launch_solo).name = "ClockOut"
	status_label.text = Roster.get_character(GameManager.selected_character_id).name + "  /  READY TO LEAVE"

func _setup_summary() -> String:
	if selected_mode == 0:
		var route := str(session.configuration.layout).replace("_", " ").capitalize()
		return route + (" · Time trial" if session.configuration.trial else " · %d AI" % session.configuration.bots)
	return NAMES[selected_mode] + (" · Solo" if selected_mode == 2 else " · %d AI" % session.configuration.bots)

func _show_setup() -> void:
	UI.button(panel, "← Back to mode selection", func(): setup_open = false; _show_play())
	UI.heading(panel, NAMES[selected_mode].to_upper(), 44)
	UI.rule(panel)
	if selected_mode == 0:
		UI.label(panel, "OFFICE ROUTE", 12, UI.MUTED)
		var layouts := ["open_plan", "cubicle_maze", "executive"]
		UI.option(panel, ["Open Plan", "Cubicle Maze", "Executive Suite"], maxi(0, layouts.find(session.configuration.layout)), func(i): session.configuration.layout = layouts[i])
		var trial_toggle := CheckButton.new()
		trial_toggle.name = "TimeTrial"
		trial_toggle.text = "Race your personal best ghost"
		trial_toggle.button_pressed = session.configuration.trial
		trial_toggle.toggled.connect(func(value): session.configuration.trial = value)
		panel.add_child(trial_toggle)
	if selected_mode in [0, 1, 3]:
		UI.label(panel, "AI COWORKERS", 12, UI.MUTED)
		UI.option(panel, ["Easy", "Normal", "Hard"], session.configuration.difficulty, func(i): session.configuration.difficulty = i)
		UI.option(panel, ["4 AI coworkers", "3 AI coworkers", "2 AI coworkers", "1 AI coworker", "Solo"], 4 - int(session.configuration.bots), func(i): session.configuration.bots = 4 - i)
	_profile()
	UI.primary(panel, "CLOCK OUT   ↗", _launch_solo)
	UI.label(panel, "WASD steer   /   SPACE boost   /   SHIFT drift", 12, UI.MUTED)

func _profile() -> void:
	UI.label(panel, "HANDLING · ALL AVAILABLE", 14)
	UI.option(panel, ["Balanced", "Agile", "Heavy"], maxi(0, Profiles.IDS.find(session.identity_profile)), func(i): session.identity_profile = Profiles.IDS[i]; Save.set_setting("profile", session.identity_profile); _show_play())
	var text := UI.label(panel, Profiles.get_profile(session.identity_profile).description, 15)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _show_wardrobe() -> void:
	_clear()
	UI.heading(panel, "YOUR OFFICE SELF.", 44)
	UI.rule(panel)
	var turn := HBoxContainer.new()
	panel.add_child(turn)
	UI.button(turn, "↶ Rotate", func(): preview_parent.rotation.y -= 0.5)
	UI.button(turn, "Rotate ↷", func(): preview_parent.rotation.y += 0.5)
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
	status_label.text = "Rotate to inspect your coworker. Appearance is cosmetic."

func _show_party() -> void:
	_clear()
	UI.heading(panel, "CLOCK OUT TOGETHER.", 44)
	UI.rule(panel)
	status_label.text = "LOCAL MULTIPLAYER  /  UP TO 8 COWORKERS"
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
	settings.office_style = true
	root.add_child(settings)
	settings.closed.connect(func(): reduced_motion = A11y.reduced_motion_enabled())

func _credits() -> void:
	_clear()
	UI.heading(panel, "CREDITS", 44)
	UI.rule(panel)
	status_label.text = "FRIDAY 5PM  /  EVACUATION"
	var text := UI.label(panel, "Coworkers and office kit authored for Friday 5PM.\n\nOffice chair adapted from NVIDIA SimReady, chair_office_fabric_manager_a01. Licensed CC BY 4.0. Simplified geometry, rebuilt materials and LODs.\n\nNVIDIA / Hugging Face:\nhuggingface.co/datasets/nvidia/simready-assets\n\ncreativecommons.org/licenses/by/4.0/", 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.button(panel, "Back to Play", _open_page.bind("play"))

func _message(words: String) -> void:
	message_label.text = words
	if page == "party" and not session.active:
		_show_party()

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/overhaul/OfficeGame.tscn")

func _process(delta: float) -> void:
	rotation_time += delta
	if preview:
		preview.reduced_motion = reduced_motion
		preview.animate(delta, 0, false, false, false, 0)
		if not wardrobe and not reduced_motion:
			preview_parent.rotation.y = PI + 0.3 + sin(rotation_time * 0.35) * 0.15

func _unhandled_input(event: InputEvent) -> void:
	if wardrobe and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and event.position.x > sheet.size.x:
		preview_parent.rotation.y += event.relative.x * 0.01
