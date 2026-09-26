# PauseMenuSmokeTest.gd — Exercises PauseMenu open/pause/resume/settings/quit
# in each mode scene. Frame-driven state machine (ModeSmokeTest pattern).
# Run: godot --headless --path . --script scripts/PauseMenuSmokeTest.gd
extends SceneTree

const MODE_SCENES := [
	"res://scenes/Hauled.tscn",
	"res://scenes/ShopSeek.tscn",
	"res://scenes/PizzaColony.tscn",
]

var failures: Array[String] = []
var index := 0
var frames := 0
var stage := 0
var current: Node
var menu: CanvasLayer

func _init() -> void:
	print("=== PAUSE MENU SMOKE TEST ===")
	_test_next.call_deferred()

func _fail(msg: String) -> void:
	failures.append(msg)
	printerr("[FAIL] %s" % msg)

func _check(condition: bool, msg: String) -> void:
	if condition:
		print("[PASS] %s" % msg)
	else:
		_fail(msg)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 2:
		return false
	frames = 0
	match stage:
		0: # menu just created — verify paused state and panel
			_check(current.get_node_or_null("PauseMenu") is CanvasLayer, "%s: pause menu added" % current.name)
			_check(paused, "%s: tree paused while menu open" % current.name)
			# S-F: panel now lives under PauseRoot/PauseCenter/PausePanel
			# (CenterContainer centering; CanvasLayer children have no
			# sized parent, PRESET_CENTER drifts).
			var panel: Control = menu.get_node_or_null("PauseRoot/PauseCenter/PausePanel")
			_check(panel is Control, "%s: pause panel exists" % current.name)
			if panel is Control:
				_check(panel.find_child("TapeStrip*", true, false) != null,
					"%s: hazard-tape header present" % current.name)
			menu._open_settings()
			stage = 1
		1: # settings overlay open
			var settings = menu.get_node_or_null("PauseRoot/SettingsOverlay")
			_check(settings is Control, "%s: settings overlay opens from pause" % current.name)
			if settings is Control:
				settings._close()
			stage = 2
		2: # settings closed, back to pause panel — resume via REAL Esc input event
			_check(not menu._settings_open, "%s: settings overlay closes back to pause" % current.name)
			var ev := InputEventAction.new()
			ev.action = "pause"
			ev.pressed = true
			Input.parse_input_event(ev)
			stage = 3
		3: # resumed via Esc input
			_check(not paused, "%s: tree unpaused after Esc resume" % current.name)
			_check(not is_instance_valid(menu), "%s: pause menu freed after Esc resume" % current.name)
			menu = load("res://scripts/PauseMenu.gd").create(current, Callable(self, "_noop_quit"))
			stage = 4
		4: # second menu open — quit path
			menu._quit()
			stage = 5
		5: # quit done
			_check(not paused, "%s: tree unpaused after quit" % current.name)
			current.queue_free()
			stage = 6
		6: # freed — next scene
			index += 1
			if index >= MODE_SCENES.size():
				_report()
			else:
				_test_next()
	return false

func _test_next() -> void:
	stage = 0
	frames = 0
	# PreMatchModal pauses the tree on mount — suppressed per instance.
	load("res://scripts/PreMatchModal.gd").suppress_next()
	current = load(MODE_SCENES[index]).instantiate()
	root.add_child(current)
	menu = load("res://scripts/PauseMenu.gd").create(current, Callable(self, "_noop_quit"))
	print("-- testing pause flow: %s" % MODE_SCENES[index])

func _noop_quit() -> void:
	pass

func _report() -> void:
	print("")
	if failures.is_empty():
		print("=== PAUSE MENU SMOKE TEST: ALL PASS ===")
		quit(0)
	else:
		print("=== PAUSE MENU SMOKE TEST: %d FAILURES ===" % failures.size())
		for f in failures:
			printerr("  FAIL: %s" % f)
		quit(1)
