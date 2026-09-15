# LoadingScreen.gd — truthful loading interstitial (Phase 1B, UI-LAYOUTS §4)
# Root-owned overlay that loads the target resource with
# ResourceLoader threaded requests, shows only REAL load progress,
# swaps to the loaded PackedScene, and dismisses once the target scene
# exists and reports ready. No minimum dwell, NO fade (Astra decision:
# dismissed immediately on success so the usable UI is never hidden by
# an opaque overlay or a stale duplicate lock).
# While active the overlay CONSUMES ALL INPUT (mouse, keyboard, gamepad)
# except ui_cancel in the error state, which returns BACK.
extends CanvasLayer

# UI-LAYOUTS §2 token map (BG/ORANGE match FridayUITheme; IVORY and SLATE
# are the spec's new values — IVORY aliases TEXT per §2).
const INK := "0a0a0f"
const IVORY := "f3e7d3"
const ORANGE := "ff9a1a"
const SLATE := "263445"
const TEXT_MUTED := "b8b5ae"
const MENU_SCENE := "res://scenes/Main.tscn"
const GROUP := "loading_overlay"
# Safety bound for target-scene readiness so a misbehaving scene can never
# hang the overlay forever (see _swap_scene).
const READINESS_TIMEOUT_S := 10.0
## Test/edge-case override for the readiness safety bound (static so the
## pre-instance show_loading() path can adjust it). <=0 falls back to the const.
static var _readiness_timeout_override := 0.0
static func set_readiness_timeout(seconds: float) -> void:
	_readiness_timeout_override = seconds
static func _readiness_timeout() -> float:
	return _readiness_timeout_override if _readiness_timeout_override > 0.0 else READINESS_TIMEOUT_S

enum Stage { IDLE, LOADING, PREPARING, READY, ERROR }

var _stage: int = Stage.IDLE
var _scene_path := ""
var _packed: PackedScene = null
var _failed := false
var _swapped := false  # set once change_scene_to_packed() succeeded
var _backed := false
# Instance ID of the scene that was current before the swap: safe to compare
# after change_scene_to_packed() frees it (never holds the Node itself).
var _old_scene_id: int = 0
# GUI focus owner before the overlay took input; restored on dismissal/BACK.
var _prev_focus: Control = null

var _root_control: Control
var _status_label: Label
var _detail_label: Label
var _bar: ProgressBar
var _back_button: Button


## Compatible with all existing callers (Main.gd _on_play).
## Mounts ONE root-owned loader; duplicate requests are ignored while a
## load (or an error awaiting BACK) is active.
static func show_loading(next_scene_path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	for child in tree.root.get_children():
		if child.is_in_group(GROUP):
			return  # a loader is already active: block duplicate requests
	var layer: CanvasLayer = load("res://scripts/LoadingScreen.gd").new()
	layer._scene_path = next_scene_path
	layer.add_to_group(GROUP)
	tree.root.add_child(layer)


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prev_focus = get_viewport().gui_get_focus_owner()
	_build_ui()
	_begin_load()


func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "LoadingRoot"
	_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)

	# Opaque INK background (UI-LAYOUTS §4).
	var bg := ColorRect.new()
	bg.color = Color(INK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_control.add_child(bg)

	# Centered, constrained container: fits inside a 640x360 viewport.
	var box := VBoxContainer.new()
	box.name = "Content"
	box.custom_minimum_size = Vector2(320, 0)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -160
	box.offset_right = 160
	box.offset_top = -54
	box.offset_bottom = 54
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(box)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "LOADING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(IVORY))
	box.add_child(title)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "LOADING RESOURCES"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(TEXT_MUTED))
	box.add_child(_status_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 44)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)

	# Orange 320x12 progress bar on a SLATE track (§2/§4). The value is
	# ONLY ever the actual ResourceLoader progress fraction.
	_bar = ProgressBar.new()
	_bar.name = "LoadBar"
	_bar.custom_minimum_size = Vector2(320, 12)
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(ORANGE)
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(SLATE)
	track.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", track)
	box.add_child(_bar)

	_detail_label = Label.new()
	_detail_label.name = "DetailLabel"
	_detail_label.visible = false
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(320, 0)
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", Color(IVORY))
	box.add_child(_detail_label)

	var button_gap := Control.new()
	button_gap.custom_minimum_size = Vector2(0, 12)
	button_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(button_gap)

	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "BACK"
	_back_button.visible = false
	_back_button.custom_minimum_size = Vector2(160, 52)
	_back_button.pressed.connect(_go_back)
	var UITheme = load("res://scripts/UITheme.gd")
	if UITheme:
		UITheme.apply_secondary(_back_button, UITheme.color(UITheme.ORANGE))
	box.add_child(_back_button)


func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


## Await one ACTUAL rendered frame of the overlay.
## Graphical: RenderingServer.frame_post_draw (fires after a real draw, so a
## plain process_frame — which precedes drawing — is never enough).
## Headless: no draws happen, fall back to process_frame so tests never hang.
func _wait_drawn_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw


func _begin_load() -> void:
	_set_status("LOADING RESOURCES")
	# The FIRST resource request follows an actual overlay draw, not just
	# a process tick.
	await _wait_drawn_frame()
	if _failed or not is_inside_tree():
		return
	if _scene_path.is_empty() or not ResourceLoader.exists(_scene_path):
		_fail("Scene file not found:\n%s" % _scene_path)
		return
	var req_err := ResourceLoader.load_threaded_request(_scene_path)
	if req_err != OK:
		_fail("Could not start loading:\n%s" % _scene_path)
		return
	_stage = Stage.LOADING


func _process(_delta: float) -> void:
	if _stage != Stage.LOADING:
		return
	var progress: Array = []
	match ResourceLoader.load_threaded_get_status(_scene_path, progress):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress.size() > 0:
				_bar.value = clampf(float(progress[0]), 0.0, 1.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			# Only call load_threaded_get once the status is LOADED.
			var res := ResourceLoader.load_threaded_get(_scene_path)
			if res is PackedScene:
				_packed = res
				_stage = Stage.PREPARING
				_bar.visible = false  # no fake percentage past resource load
				_set_status("PREPARING OFFICE")
				_swap_scene()
			else:
				_fail("Target is not a playable scene:\n%s" % _scene_path)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("Could not load:\n%s" % _scene_path)
		_:
			pass


func _swap_scene() -> void:
	# Let the PREPARING OFFICE label actually render before the
	# (frame-costly) scene instantiation: never swap in the same frame the
	# label was mutated.
	await _wait_drawn_frame()
	if _failed or not is_inside_tree():
		return
	var cs_now := get_tree().current_scene
	_old_scene_id = cs_now.get_instance_id() if cs_now != null else 0
	var err := get_tree().change_scene_to_packed(_packed)
	if err != OK:
		_fail("Could not open the office scene")
		return
	_swapped = true
	_stage = Stage.READY
	# Dismiss only once the target scene exists and reports ready.
	# change_scene_to_packed() freed the old scene, so we compare instance
	# IDs — never the (now invalid) Node variable.
	var waited := 0.0
	while is_inside_tree():
		var tree := get_tree()
		if tree == null:
			return
		# NOTE: a paused tree must NOT shortcut this loop. process_frame
		# still fires while paused and PROCESS_MODE_ALWAYS targets keep
		# processing, so we poll until real readiness or the safety
		# timeout — never dismiss merely because the tree is paused.
		if waited >= _readiness_timeout():
			_fail("The office did not finish opening.\nPress BACK, then try again.")
			return
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
		var cs := tree.current_scene
		if cs == null or cs.get_instance_id() == _old_scene_id:
			continue  # swap not applied (or scene vanished) yet
		if cs.has_method("is_loading_complete"):
			# Future async/incremental setup support: wait for the scene to
			# declare itself complete.
			if cs.is_loading_complete():
				break
		elif cs.is_node_ready():
			break
	if not is_inside_tree() or _failed:
		return
	_dismiss()


## Immediate dismissal: remove the group lock first so duplicate requests
## unblock the same frame, then free. No fade, no opaque overlay lingering.
func _dismiss() -> void:
	if _failed:
		return
	remove_from_group(GROUP)
	_restore_focus()
	queue_free()


func _restore_focus() -> void:
	if _prev_focus != null and is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree():
		_prev_focus.grab_focus()


func _fail(reason: String) -> void:
	if _failed:
		return
	_failed = true
	_stage = Stage.ERROR
	_bar.visible = false
	_set_status("LOAD FAILED")
	_detail_label.text = reason
	_detail_label.visible = true
	_back_button.visible = true
	_back_button.grab_focus()


## BACK (error state only): return to the menu. The current scene was never
## replaced on pre-swap failure paths, so the menu is still there
## underneath; only repair the tree if no current scene exists at all.
## The lock is released immediately so a valid retry can start.
func _go_back() -> void:
	if _backed:
		return  # prevent duplicate keyboard activations
	_backed = true
	_restore_focus()
	var tree := get_tree()
	if tree != null and ResourceLoader.exists(MENU_SCENE):
		var cs := tree.current_scene
		# Restore the menu whenever the underlying scene is NOT the menu:
		# either nothing is current (pre-swap crash) or a broken/incomplete
		# scene was already swapped in (post-swap readiness timeout). BACK
		# must never leave the player staring at a dead scene.
		var underlying_broken := cs == null or cs.scene_file_path != MENU_SCENE
		if (_swapped and underlying_broken) or cs == null:
			tree.change_scene_to_file(MENU_SCENE)
	remove_from_group(GROUP)
	queue_free()


func _input(event: InputEvent) -> void:
	# While loading, EVERY event is consumed so nothing leaks to the
	# menu/game/pre-match modal underneath. In the ERROR state the visible
	# BACK button must stay interactive: mouse events pass through to GUI
	# (Button click), and ui_accept / ui_cancel trigger BACK directly.
	if _failed and not _backed:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_go_back()
		return  # mouse/key events reach the BACK button's GUI handling
	get_viewport().set_input_as_handled()
