# CheckpointBotTest.gd — automated checkpoint-traversal bot for Evacuation.
#
# PASS = every checkpoint reached in order, respawn_point advanced with
# each floor, and finish_order non-empty (real exit signal), within budget.
#
# The traversal harness lives in CheckpointBot.gd (shared with
# SkinBotSanityTest.gd so per-skin runs drive the identical logic).
#
# Run: godot --headless --path . --script scripts/CheckpointBotTest.gd
extends SceneTree

var bot = null

func _init() -> void:
	_run.call_deferred()

func check(cond: bool, label: String) -> void:
	if bot:
		bot.check(cond, label)

func _run() -> void:
	# Deterministic arena regardless of the machine's saved map preference
	# (process state only — never touches the saved cfg).
	var layouts = load("res://scripts/LevelLayouts.gd")
	if layouts:
		layouts.set_current("open_plan")
	# Skip the pre-match modal (single-shot suppress, like all harnesses).
	load("res://scripts/PreMatchModal.gd").suppress_next()

	bot = load("res://scripts/CheckpointBot.gd").new()
	var evac = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(evac)

	var stats: Dictionary = await bot.run(evac, self)

	if evac.is_inside_tree():
		evac.free()
	print("")
	if bot.fails.is_empty():
		print("=== CHECKPOINT BOT: ALL PASS (%d checks) ===" % bot.checks)
		quit(0)
	else:
		for f in bot.fails:
			printerr("[BOT FAILED] " + f)
		print("=== CHECKPOINT BOT: FAILED (%d/%d) ===" % [bot.fails.size(), bot.checks])
		quit(1)
