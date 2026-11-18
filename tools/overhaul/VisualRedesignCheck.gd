extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 5:
		await process_frame

func run() -> void:
	var session := root.get_node("OfficeSession")
	var launch = load("res://scenes/overhaul/OfficeLaunch.tscn").instantiate()
	root.add_child(launch)
	await settle()
	for mode in launch.MODES:
		var button := launch.panel.find_child("Mode_" + mode, true, false) as Button
		button.pressed.emit()
		await settle()
		check(session.configuration.mode == mode, "Mode button must select " + mode)
		check(launch.card.get_rect().end.x <= launch.sheet.size.x + 1, "Changing mode must not cover the 3D stage")
		check(launch.panel.find_child("Mode_" + mode, true, false).has_focus(), "Mode selection must retain focus")
	launch.panel.find_child("Mode_evacuation", true, false).pressed.emit()
	launch.actions.get_child(0).pressed.emit()
	await settle()
	var trial := launch.panel.get_node("TimeTrial") as CheckButton
	trial.button_pressed = true
	check(session.configuration.trial, "Time trial toggle must update configuration")
	trial.button_pressed = false
	root.size = Vector2i(480, 850)
	launch._open_page("play")
	await settle()
	check(launch.actions.get_rect().end.y < launch.root.size.y, "Portrait launch action must stay on screen")
	check(launch.nav_bar.get_rect().end.x <= launch.root.size.x, "Portrait navigation must fit")
	launch._open_page("coworker")
	await settle()
	check(launch.panel.find_children("*", "OptionButton", true, false).size() > 8, "Coworker customization must remain available")
	launch._open_page("settings")
	await settle()
	check(launch.root.find_child("SettingsSheet", true, false) != null, "Settings must open from the redesign")
	launch.queue_free()
	await settle()
	root.size = Vector2i(1280, 720)
	for mode in ["evacuation", "hauled", "seek", "pizza"]:
		session.configuration.mode = mode
		session.configuration.bots = 0
		var game = load("res://scenes/overhaul/OfficeGame.tscn").instantiate()
		game.test_mode = true
		root.add_child(game)
		await settle()
		check(game.countdown_card.visible, "Countdown must appear in " + mode)
		check(game.clock.text.contains(":"), "Timer must render in " + mode)
		game.rules.state.phase = "results"
		game.rules.state.headline = "The weekend is yours"
		await settle()
		check(game.overlay.visible and game.shade.visible, "Results must appear in " + mode)
		check(game.result_box.find_children("*", "Button", true, false).size() >= 2, "Results must offer replay and exit")
		game.queue_free()
		await settle()
	print("VISUAL_REDESIGN_CHECK failures=", failures)
	quit(1 if failures else 0)
