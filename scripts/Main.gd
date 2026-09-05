# Main.gd — Main menu / mode select screen
extends Control

const UI_THEME = preload("res://scripts/UITheme.gd")

const MODE_INFO = [
	{
		"title": "Friday 5PM: Evacuation",
		"subtitle": "PRIMARY MODE",
		"desc": "It's 4:59 PM. Race your office chair through the building to the parking lot. Coffee boosts, water traps, stapler sabotage. Last one buys beers.",
		"mode": GameManager.GameMode.EVACUATION,
		"color": Color(1.0, 0.65, 0.1),
	},
	{
		"title": "HAULED",
		"subtitle": "CO-OP PHYSICS DELIVERY",
		"desc": "Delivery of absurd HOSTILE cargo — a fridge full of bees, a haunted sofa — through impossible terrain. Drop it, you owe money.",
		"mode": GameManager.GameMode.HAULED,
		"color": Color(1.0, 0.35, 0.3),
	},
	{
		"title": "SHOP & SEEK",
		"subtitle": "HIDE & SEEK",
		"desc": "Half of you disguise as groceries in a supermarket. The other half are frantic shoppers with a list and 60 seconds. Spot the fake avocado.",
		"mode": GameManager.GameMode.SHOP_SEEK,
		"color": Color(0.3, 0.85, 0.4),
	},
	{
		"title": "PIZZA COLONY",
		"subtitle": "CO-OP SURVIVAL",
		"desc": "You're toppings on a GIANT living pizza. Claim pepperoni territory, dodge the chef's slice-cutter, harvest cheese.",
		"mode": GameManager.GameMode.PIZZA_COLONY,
		"color": Color(1.0, 0.8, 0.2),
	},
]

const MODE_STATUS := ["PLAYABLE", "DELIVERY PLAYABLE", "SHOPPER PLAYABLE", "SURVIVAL PLAYABLE"]

var selected_index: int = 0
var buttons: Array[Button] = []
var settings_overlay: Control
var lobby_overlay: Control
var settings_button: Button
var layout_option: OptionButton
var touch_button: Button
var credits_button: Button
var utility_row: Container
var modifier_menu: Control
var character_row: HBoxContainer
var character_select: OptionButton
var character_detail: Label
var skin_row: HBoxContainer
var skin_select: OptionButton
var skin_detail: Label
var stats_label: Label
var menu_time: float = 0.0
var hero_panel: Control
var hero: Control
var backdrop: Control

# UI nodes
@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var desc_label: Label = $VBox/Description
@onready var mode_list: VBoxContainer = $VBox/ModeListScroll/ModeList
@onready var play_button: Button = $VBox/PlayButton
@onready var host_button: Button = $VBox/HostButton
@onready var join_button: Button = $VBox/JoinButton
@onready var back_button: Button = $VBox/BackButton

func _ready() -> void:
	get_window().title = "Friday 5PM: Evacuation"
	# Apply saved input prefs once at menu boot: re-arms the persisted
	# bindings remap, refreshes sensitivity caches, and syncs scheme
	# memory. Modes used to do this per-_ready, so launching Hauled/Shop
	# & Seek/Pizza Colony paths that skip Evacuation still need it HERE.
	var prefs_boot = load("res://scripts/InputPrefs.gd")
	if prefs_boot and prefs_boot.has_method("refresh_cache"):
		prefs_boot.refresh_cache()
	# Debug virtual gamepad (--virtual-pad or FE_VIRTUAL_PAD=1): pumps real
	# joypad events for pad-play QA without hardware. Lives on the root so
	# it survives scene changes into the race.
	if "virtual-pad" in OS.get_cmdline_user_args() or OS.get_environment("FE_VIRTUAL_PAD") == "1":
		var vpad = load("res://scripts/VirtualPad.gd")
		if vpad:
			var vpad_node: Node = vpad.new()
			vpad_node.name = "VirtualPad"
			get_tree().root.add_child.call_deferred(vpad_node)
	_build_mode_buttons()
	_select_mode(0)
	_build_hero_panel()
	_build_character_selector()
	_build_skin_selector()
	
	play_button.pressed.connect(_on_play)
	play_button.pressed.connect(_play_click_sound)
	_build_modifier_row()
	# UI SLICE: utility row becomes a wrapping flow at narrow widths — four
	# side-by-side buttons had a 449px combined minimum (sum of text widths,
	# the last thing keeping the menu column wider than a phone viewport).
	# A flow row wraps to 2x2 with a minimum of just the widest button.
	if _is_narrow():
		utility_row = HFlowContainer.new()
	else:
		utility_row = HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 8)
	$VBox.add_child(utility_row)
	settings_button = Button.new()
	settings_button.text = "SETTINGS"
	settings_button.custom_minimum_size = Vector2(0, 28)
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.add_theme_font_size_override("font_size", 12)
	utility_row.add_child(settings_button)
	settings_button.pressed.connect(_open_settings)
	credits_button = Button.new()
	credits_button.text = "CREDITS"
	credits_button.custom_minimum_size = Vector2(0, 28)
	credits_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_button.add_theme_font_size_override("font_size", 12)
	utility_row.add_child(credits_button)
	credits_button.pressed.connect(_open_credits)
	# PHASE 4: map layout picker (single-player + host authority).
	layout_option = OptionButton.new()
	# UI SLICE: short map names at narrow widths (the utility row's 520px
	# combined minimum was the last floor above the 390px viewport).
	var narrow := _is_narrow()
	layout_option.add_item("MAP: OPEN PLAN" if not narrow else "OPEN PLAN", 0)
	layout_option.add_item("MAP: CUBICLE MAZE" if not narrow else "CUBICLES", 1)
	layout_option.add_item("MAP: EXECUTIVE" if not narrow else "EXECUTIVE", 2)
	layout_option.custom_minimum_size = Vector2(0, 28)
	layout_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_option.add_theme_font_size_override("font_size", 12)
	utility_row.add_child(layout_option)
	var saved_layout := str(_load_saved_layout())
	layout_option.select({"open_plan": 0, "cubicle_maze": 1, "executive": 2}.get(saved_layout, 0))
	layout_option.item_selected.connect(_on_layout_selected)
	# Apply the persisted pick so a menu-skip (LAN auto-start) still gets it.
	var LayoutsScript = load("res://scripts/LevelLayouts.gd")
	if LayoutsScript:
		LayoutsScript.set_current(saved_layout)
	# PHASE WEB: touch controls cycle button — AUTO (web+touchscreen
	# auto-on) / ON / OFF. Persisted; lets desktop players preview and
	# web players force the overlay regardless of detection.
	touch_button = Button.new()
	touch_button.custom_minimum_size = Vector2(0, 28)
	touch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	touch_button.add_theme_font_size_override("font_size", 12)
	utility_row.add_child(touch_button)
	var prefs_touch = load("res://scripts/InputPrefs.gd")
	var touch_pref := "auto"
	if prefs_touch and prefs_touch.has_method("touch_mode"):
		touch_pref = prefs_touch.touch_mode()
	touch_button.text = _touch_button_label(touch_pref)
	touch_button.pressed.connect(_on_touch_button)
	stats_label = Label.new()
	stats_label.text = ""
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	$VBox.add_child(stats_label)
	_register_small_label(stats_label)
	var stats = get_node_or_null("/root/StatsManager")
	if stats:
		stats_label.text = stats.get_summary_line()
		stats.stats_updated.connect(func(): stats_label.text = stats.get_summary_line())
	_build_menu_theme()
	host_button.visible = true
	host_button.text = "MULTIPLAYER"
	host_button.pressed.connect(_open_lobby)
	join_button.visible = false
	back_button.visible = false

func _build_mode_buttons() -> void:
	for i in range(MODE_INFO.size()):
		var info = MODE_INFO[i]
		var btn = Button.new()
		var card_script = load("res://scripts/ModeCard.gd")
		btn.set_script(card_script)
		btn.configure(info.title, info.subtitle, MODE_STATUS[i], info.color)
		btn.custom_minimum_size = Vector2(0, 34)
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(_select_mode.bind(i))
		mode_list.add_child(btn)
		buttons.append(btn)

## HERO PANEL: rotating chair preview + identity pickers, docked right.
## Two-column layout at >= 1080px wide; collapses (hides hero) below that
## so small viewports keep the single-column scroll.
func _build_hero_panel() -> void:
	# Animated skyline backdrop behind everything (child of BG so it stays
	# behind the VBox contents; Control draw order follows tree order).
	backdrop = Control.new()
	backdrop.set_script(load("res://scripts/MenuBackdrop.gd"))
	backdrop.name = "MenuBackdrop"
	get_node("BG").add_child(backdrop)

	hero_panel = PanelContainer.new()
	hero_panel.name = "HeroPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.055, 0.09, 0.92)
	style.border_color = Color(1.0, 0.60, 0.22, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	hero_panel.add_theme_stylebox_override("panel", style)
	# Dock right: full-height column at 28% width on wide screens.
	hero_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	hero_panel.anchor_left = 0.70
	hero_panel.offset_left = 12
	hero_panel.offset_top = 10
	hero_panel.offset_right = -12
	hero_panel.offset_bottom = -10
	var hero_vb := VBoxContainer.new()
	hero_vb.add_theme_constant_override("separation", 10)
	hero_panel.add_child(hero_vb)
	var hero_title := Label.new()
	hero_title.text = "YOUR RIDE"
	hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_title.add_theme_font_size_override("font_size", 15)
	hero_title.add_theme_color_override("font_color", Color(1.0, 0.60, 0.22))
	hero_vb.add_child(hero_title)
	var hero_script = load("res://scripts/MenuHero.gd")
	if hero_script:
		hero = hero_script.new()
		hero_vb.add_child(hero)
	var hero_hint := Label.new()
	hero_hint.text = "Rider & chair update live"
	hero_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_hint.add_theme_font_size_override("font_size", 11)
	hero_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	hero_vb.add_child(hero_hint)
	add_child(hero_panel)

func _refresh_hero() -> void:
	if hero and hero.has_method("refresh_for_pick"):
		hero.refresh_for_pick()

func _build_modifier_row() -> void:
	# Race-modifier picker panel — single-player Evacuation only.
	# Sits ABOVE the play button (rules are chosen before you launch, like a
	# real game's pre-match options), not below it like a debug row.
	var RaceModifiersScript = load("res://scripts/RaceModifiers.gd")
	if not RaceModifiersScript:
		return
	RaceModifiersScript.load_from_cfg()
	# load()-based mount (file convention): keeps Main.gd parse-safe even when
	# the global class_name cache is stale (fresh checkout before --import).
	var menu_script = load("res://scripts/ModifierMenu.gd")
	if not menu_script:
		return
	modifier_menu = menu_script.mount($VBox, play_button)
	modifier_menu.visible = selected_index == 0

func _build_character_selector() -> void:
	var roster = load("res://scripts/CharacterRoster.gd")
	if not roster:
		return
	character_row = HBoxContainer.new()
	character_row.name = "CharacterSelector"
	character_row.custom_minimum_size = Vector2(0, 30)
	character_row.add_theme_constant_override("separation", 10)
	$VBox.add_child(character_row)
	$VBox.move_child(character_row, play_button.get_index())
	var label := Label.new()
	label.text = "RIDER"
	label.custom_minimum_size.x = 62
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	character_row.add_child(label)
	character_select = OptionButton.new()
	character_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_select.add_theme_font_size_override("font_size", 14)
	character_row.add_child(character_select)
	character_detail = Label.new()
	# UI SLICE: clip (ellipsis) instead of forcing a 250px+ minimum width —
	# the unwrapped tagline was the single biggest contributor to the menu
	# column's 700px minimum width (probe-measured), which made the whole
	# VBox refuse to shrink below 700px in portrait windows.
	character_detail.custom_minimum_size.x = 0
	character_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_detail.clip_text = true
	character_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	character_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	character_detail.add_theme_font_size_override("font_size", 11)
	character_detail.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	character_row.add_child(character_detail)
	_register_detail_label(character_detail)
	var selected := 0
	var characters: Array[Dictionary] = roster.all()
	# UI SLICE: drop the role suffix in narrow windows — the full
	# "Name — ROLE" strings forced a 361px dropdown minimum width.
	var short_items := _is_narrow()
	for i in range(characters.size()):
		var character: Dictionary = characters[i]
		if short_items:
			character_select.add_item(String(character["name"]))
		else:
			character_select.add_item("%s — %s" % [character["name"], character["role"]])
		character_select.set_item_metadata(i, character["id"])
		if character["id"] == GameManager.selected_character_id:
			selected = i
	character_select.select(selected)
	character_select.item_selected.connect(_on_character_selected)
	_on_character_selected(selected)

func _on_character_selected(index: int) -> void:
	var roster = load("res://scripts/CharacterRoster.gd")
	if not roster or not character_select:
		return
	var character_id := String(character_select.get_item_metadata(index))
	var character: Dictionary = roster.get_character(character_id)
	GameManager.selected_character_id = character_id
	GameManager.player_color = Color.from_string(character["body"], GameManager.player_color)
	GameManager.save_identity()
	_refresh_hero()
	if character_detail:
		character_detail.text = character["tagline"]
		character_detail.tooltip_text = "%s • %s" % [character["silhouette"], character["accessory"]]

func _build_skin_selector() -> void:
	var skins = load("res://scripts/ChairSkins.gd")
	if not skins:
		return
	var stats = get_node_or_null("/root/StatsManager")
	var wins: int = stats.races_won if stats else 0

	skin_row = HBoxContainer.new()
	skin_row.name = "SkinSelector"
	skin_row.custom_minimum_size = Vector2(0, 28)
	skin_row.add_theme_constant_override("separation", 10)
	$VBox.add_child(skin_row)
	# Park it right under the character row so the two pickers read as one
	# identity block.
	$VBox.move_child(skin_row, character_row.get_index() + 1)

	var label := Label.new()
	label.text = "CHAIR"
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	skin_row.add_child(label)

	skin_select = OptionButton.new()
	skin_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_select.add_theme_font_size_override("font_size", 14)
	skin_row.add_child(skin_select)

	skin_detail = Label.new()
	# UI SLICE: same ellipsis treatment as the rider tagline (probe: this
	# label alone carried a 341px minimum into the column's min width).
	skin_detail.custom_minimum_size.x = 0
	skin_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_detail.clip_text = true
	skin_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	skin_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skin_detail.add_theme_font_size_override("font_size", 11)
	skin_detail.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	skin_row.add_child(skin_detail)
	_register_detail_label(skin_detail)

	var all_skins: Array[Dictionary] = skins.all()
	var selected := 0
	var locked_count := 0
	for i in range(all_skins.size()):
		var skin: Dictionary = all_skins[i]
		var id := String(skin["id"])
		var unlocked: bool = skins.is_unlocked(id, wins)
		if unlocked:
			skin_select.add_item(String(skin["name"]))
			skin_select.set_item_metadata(skin_select.item_count - 1, id)
			if id == GameManager.selected_skin_id:
				selected = skin_select.item_count - 1
		else:
			locked_count += 1
			var need := int(skin["unlock_wins"])
			# UI SLICE: compact lock tag at narrow widths (the long form
			# forced a 300px dropdown minimum; the unlock progress already
			# lives in the detail line beside it).
			if _is_narrow():
				skin_select.add_item("%s 🔒%d" % [skin["name"], need])
			else:
				skin_select.add_item("%s  —  LOCKED (win %d)" % [skin["name"], need])
			skin_select.set_item_metadata(skin_select.item_count - 1, "")
			skin_select.set_item_disabled(skin_select.item_count - 1, true)
			if id == GameManager.selected_skin_id:
				# Saved pick got locked?? Can't happen (unlocks never re-lock)
				# but stay honest and fall back to default.
				selected = 0
	var _next = skins.next_unlock(wins)
	if _next.is_empty():
		skin_detail.text = "ALL CHAIRS UNLOCKED — flex accordingly."
	else:
		skin_detail.text = "%d/%d WINS → %s" % [_next["progress"], _next["unlock_wins"], _next["name"]]
	if skin_select.item_count > 0:
		skin_select.select(selected)
	skin_select.item_selected.connect(_on_skin_selected)
	_on_skin_selected(selected)

func _on_skin_selected(index: int) -> void:
	var skins = load("res://scripts/ChairSkins.gd")
	if not skins or not skin_select:
		return
	var id := String(skin_select.get_item_metadata(index))
	if id == "":
		return  # locked placeholder row
	var skin: Dictionary = skins.get_skin(id)
	GameManager.selected_skin_id = id
	GameManager.save_identity()
	_refresh_hero()
	if skin_detail:
		var stats = get_node_or_null("/root/StatsManager")
		var wins: int = stats.races_won if stats else 0
		var mods := "JUMP x%.2f  GRIP x%.2f  BOOST x%.2f" % [
			float(skin["jump_mult"]), float(skin["friction_mult"]), float(skin["boost_mult"])
		]
		skin_detail.text = "%s — %s" % [skin["tagline"], mods]
		var _next = skins.next_unlock(wins)
		if not _next.is_empty():
			skin_detail.tooltip_text = "next unlock: %s at %d wins (you have %d)" % [
				_next["name"], _next["unlock_wins"], wins
			]
		else:
			skin_detail.tooltip_text = "everything unlocked"

func _select_mode(idx: int) -> void:
	selected_index = idx
	var info = MODE_INFO[idx]
	title_label.text = info.title
	subtitle_label.text = info.subtitle
	subtitle_label.modulate = info.color
	desc_label.text = info.desc
	if modifier_menu:
		modifier_menu.visible = idx == 0

	for i in range(buttons.size()):
		if buttons[i].has_method("set_selected"):
			buttons[i].set_selected(i == idx)
			# Card label: title + subtitle for secondary modes (honest status
			# tags); the primary card is title-only — the page header above it
			# already says what it is, so repeating it reads as duplication.
			if i == 0:
				buttons[i].text = MODE_INFO[i].title
			else:
				buttons[i].text = "%s\n%s  •  %s" % [MODE_INFO[i].title, MODE_INFO[i].subtitle, MODE_STATUS[i]]

func _play_click_sound() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("powerup", 0.9)

func _on_play() -> void:
	GameManager.select_mode(MODE_INFO[selected_index].mode)
	var scene_path = GameManager.get_mode_scene(MODE_INFO[selected_index].mode)
	var loading = load("res://scripts/LoadingScreen.gd")
	if loading:
		loading.show_loading(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)

## PHASE 4: layout selection — persisted to the game cfg, applied via
## LevelLayouts.set_current so the next match builds the picked variant.
const LAYOUT_CFG_PATH := "user://settings.cfg"

func _load_saved_layout() -> String:
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_CFG_PATH)
	return str(cfg.get_value("game", "map_layout", "open_plan"))

func _on_layout_selected(index: int) -> void:
	var names := ["open_plan", "cubicle_maze", "executive"]
	var picked: String = names[clampi(index, 0, 2)]
	var LevelLayouts = load("res://scripts/LevelLayouts.gd")
	if LevelLayouts:
		LevelLayouts.set_current(picked)
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_CFG_PATH)
	cfg.set_value("game", "map_layout", picked)
	cfg.save(LAYOUT_CFG_PATH)
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("ui_click", 1.0)

## WEB TOUCH: label shows the resolved state so "AUTO" reads honestly —
## e.g. "TOUCH: AUTO (ON)" on a phone, "TOUCH: AUTO (OFF)" on desktop.
func _touch_button_label(mode: String) -> String:
	var prefs = load("res://scripts/InputPrefs.gd")
	# UI SLICE: compact labels at narrow widths (utility-row min width).
	var short := _is_narrow()
	match mode:
		"on":
			return "TOUCH ON" if short else "TOUCH: ON"
		"off":
			return "TOUCH OFF" if short else "TOUCH: OFF"
		_:
			var resolved := false
			if prefs and prefs.has_method("touch_enabled"):
				resolved = prefs.touch_enabled()
			if short:
				return "TOUCH AUTO (%s)" % ("ON" if resolved else "OFF")
			return "TOUCH: AUTO (%s)" % ("ON" if resolved else "OFF")

func _on_touch_button() -> void:
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs == null or not prefs.has_method("touch_mode"):
		return
	var order := ["auto", "on", "off"]
	var current: String = prefs.touch_mode()
	var next: String = order[(order.find(current) + 1) % order.size()]
	prefs.set_touch_mode(next)
	touch_button.text = _touch_button_label(next)
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx("ui_click", 1.0)

func _open_credits() -> void:
	var overlay = CanvasLayer.new()
	overlay.set_script(load("res://scripts/CreditsScreen.gd"))
	add_child(overlay)

func _process(delta: float) -> void:
	menu_time += delta
	if title_label:
		title_label.modulate.a = 0.96 + sin(menu_time * 2.0) * 0.04
	_update_layout()

## UI SLICE: single deterministic responsive layout for the main menu.
## Runs every frame (cheap — a compare + occasional assignment). Handles:
##   - hero column: visible + reserved 420px margin only at >= 1080px
##   - margins: fixed desktop 80px shrinks progressively down to 12px so
##     portrait windows never get a negative content rect (the old
##     "title clipped off the left edge" bug)
##   - header rows: left-aligned edge-to-edge on narrow screens, centered
##     inside the margins on wide screens (centered text in a shrunken
##     rect is what sliced the title in half in portrait)
##   - utility/stats rows: one-liners get a 10px minimum font at 390px
##     where the fixed 12px wraps; full size >= 560px
func _update_layout() -> void:
	var w := get_viewport_rect().size.x
	var wide := w >= 1080.0
	if hero_panel:
		hero_panel.visible = wide
	var vbox := get_node_or_null("VBox") as Control
	if vbox == null:
		return
	var margin: float
	if wide:
		margin = 80.0
	elif w >= 700.0:
		margin = 40.0
	elif w >= 500.0:
		margin = 20.0
	else:
		margin = 12.0
	vbox.offset_left = margin
	vbox.offset_right = -420.0 if wide else -margin
	var center_header := w >= 700.0
	var small := w < 560.0
	if utility_row and utility_row is HBoxContainer:
		(utility_row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER if center_header \
			else BoxContainer.ALIGNMENT_BEGIN
	if stats_label:
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center_header \
			else HORIZONTAL_ALIGNMENT_LEFT
	for child in [title_label, subtitle_label, desc_label]:
		if child:
			child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center_header \
				else HORIZONTAL_ALIGNMENT_LEFT
	for label in _small_labels:
		if is_instance_valid(label):
			label.add_theme_font_size_override("font_size", 10 if small else 12)

var _small_labels: Array[Label] = []

## UI SLICE: narrow-window test used at build time; the menu builds ONCE,
## so this reads the boot-time window size (a resize after boot re-runs
## _update_layout for margins/fonts, but dropdown item text stays as built).
func _is_narrow() -> bool:
	return get_viewport_rect().size.x < 560.0

## Detail labels keep their desktop minimum width on wide screens but get
## out of the container's way below 560px so the VBox can shrink with the
## window (combined minimum width of the menu column is what makes or
## breaks portrait; measured 700px -> must fall under ~400px).
func _register_detail_label(label: Label) -> void:
	_small_labels.append(label)
	if get_viewport_rect().size.x < 560.0:
		label.custom_minimum_size.x = 0

func _register_small_label(label: Label) -> void:
	_small_labels.append(label)
	label.add_theme_font_size_override("font_size", 12)

func _build_menu_theme() -> void:
	title_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.ORANGE))
	title_label.add_theme_font_size_override("font_size", 22)
	subtitle_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", UI_THEME.color(UI_THEME.TEXT_MUTED))
	desc_label.add_theme_font_size_override("font_size", 13)
	UI_THEME.apply_primary(play_button)
	# Controller-friendly menu: focus PLAY so dpad/left-stick + A navigates
	# the main menu out of the box (mouse still works as before).
	play_button.grab_focus()
	UI_THEME.apply_secondary(host_button, UI_THEME.color(UI_THEME.CYAN))
	UI_THEME.apply_secondary(join_button, UI_THEME.color(UI_THEME.LIME))
	UI_THEME.apply_secondary(back_button, UI_THEME.color(UI_THEME.CORAL))
	if settings_button:
		UI_THEME.apply_secondary(settings_button, UI_THEME.color(UI_THEME.CYAN))
	if credits_button:
		UI_THEME.apply_secondary(credits_button, UI_THEME.color(UI_THEME.VIOLET))

func _open_lobby() -> void:
	if lobby_overlay:
		return
	var script = load("res://scripts/Lobby.gd")
	if not script:
		return
	lobby_overlay = Control.new()
	lobby_overlay.set_script(script)
	add_child(lobby_overlay)
	lobby_overlay.close_requested.connect(func():
		lobby_overlay.queue_free()
		lobby_overlay = null
	)

func _open_settings() -> void:
	if settings_overlay:
		return
	var script = load("res://scripts/Settings.gd")
	settings_overlay = Control.new()
	settings_overlay.set_script(script)
	add_child(settings_overlay)
	settings_overlay.closed.connect(func(): settings_overlay = null)
