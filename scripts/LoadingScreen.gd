# LoadingScreen.gd — Brief loading interstitial with rotating tips (Phase 8C)
# Added to tree root (survives scene change), swaps the scene after a
# minimum show time, then fades itself out and frees.
extends CanvasLayer

const TIPS := [
	"SPACE gives you a coffee boost. It has a 3-second cooldown — do not waste it at the start line.",
	"Q drops a sabotage trap behind you. Water puddles, banana peels, staplers.",
	"E jumps. Useful for hopping over traps and clearing desk corners.",
	"The EXIT is on FLOOR 4. Follow the green arrows.",
	"Elevators teleport you between floors — roll onto the glowing blue pad.",
	"Coffee cups refill your boost. Grab every glowing cup you pass.",
	"Last one out buys beers. Do not be last.",
	"The glowing green EXIT ring marks the finish line on floor 4.",
	"You can jump (E) over traps — but not while boosting.",
	"Speed is capped. Boosts help you reach the cap faster, not break it.",
	"Traps expire after 12 seconds. Sometimes waiting is smarter than jumping.",
	"Screen shake, fog and shadows can be tuned in Settings.",
]

const ACCENT := Color("ff9a1a")
const MIN_SHOW_TIME := 0.8
const FADE_TIME := 0.4

var _elapsed := 0.0
var _scene_swapped := false
var _fading := false
var _next_scene_path := ""
var _tip_label: Label
var _bar: ProgressBar

static func show_loading(next_scene_path: String) -> void:
	var layer: CanvasLayer = load("res://scripts/LoadingScreen.gd").new()
	layer._next_scene_path = next_scene_path
	Engine.get_main_loop().root.add_child(layer)

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	var root = Control.new()
	root.name = "LoadingRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.position = Vector2(-300, -90)
	box.custom_minimum_size = Vector2(600, 180)
	root.add_child(box)

	var title = Label.new()
	title.text = "LOADING..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)

	_tip_label = Label.new()
	_tip_label.text = "TIP: %s" % TIPS.pick_random()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(600, 0)
	_tip_label.add_theme_font_size_override("font_size", 16)
	_tip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	box.add_child(_tip_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(600, 10)
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(5)
	_bar.add_theme_stylebox_override("fill", fill)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("1c1c2e")
	bg_style.set_corner_radius_all(5)
	_bar.add_theme_stylebox_override("background", bg_style)
	box.add_child(_bar)

func _process(delta: float) -> void:
	_elapsed += delta
	if not _scene_swapped:
		_bar.value = minf(_elapsed / MIN_SHOW_TIME, 1.0)
		if _elapsed >= MIN_SHOW_TIME:
			_scene_swapped = true
			if _next_scene_path != "":
				get_tree().change_scene_to_file(_next_scene_path)
		return
	if not _fading:
		_fading = true
	if _elapsed >= MIN_SHOW_TIME + FADE_TIME:
		queue_free()
		return
	var alpha := 1.0 - (_elapsed - MIN_SHOW_TIME) / FADE_TIME
	for child in get_children():
		child.modulate.a = clampf(alpha, 0.0, 1.0)
