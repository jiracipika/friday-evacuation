# SkinBotSanityTest.gd — Phase 8B per-skin traversal sanity (the optional
# slice from the handoff doc, now automated).
#
# Drives the CheckpointBot harness ONCE PER CHAIR SKIN through the real
# Evacuation scene, with GameManager.selected_skin_id pinned per run (the
# exact player-pick path — PlayerChair._ready resolves it when
# use_global_skin is true). Proves no chassis breaks traversal:
# Bean Bag's low jump, Exercise Ball's low friction, the Throne's boost...
# all must still reach every floor and the real ExitZone signal.
#
# Also asserts the per-skin floor timing spread stays sane — a skin that
# finishes but takes >2.5x the median time is a traversal regression even
# if it limps home.
#
# Run: godot --headless --path . --script scripts/SkinBotSanityTest.gd
extends SceneTree

var checks: int = 0
var fails: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("[PASS] " + label)
	else:
		fails.append(label)
		printerr("[FAIL] " + label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var layouts = load("res://scripts/LevelLayouts.gd")
	if layouts:
		layouts.set_current("open_plan")
	load("res://scripts/PreMatchModal.gd").suppress_next()

	# Real-script GameManager stub on /root (what the engine autoload would
	# mount in --script mode). PlayerChair reads selected_skin_id from it.
	var gm = load("res://scripts/GameManager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)

	var skins = load("res://scripts/ChairSkins.gd")
	var bot = load("res://scripts/CheckpointBot.gd").new()

	var timings := {}
	for skin in skins.SKINS:
		var id: String = skin["id"]
		gm.selected_skin_id = id
		print("")
		print("=== SKIN: %s (%s) ===" % [skin["name"], id])

		# suppress_next is SINGLE-SHOT — one call per instantiation, or the
		# pre-match modal mounts on run 2+ and pauses the whole tree (chair
		# freezes at spawn; every gate times out).
		load("res://scripts/PreMatchModal.gd").suppress_next()
		var evac = load("res://scenes/Evacuation.tscn").instantiate()
		root.add_child(evac)
		var stats: Dictionary = await bot.run(evac, self)
		if evac.is_inside_tree():
			evac.free()
		await process_frame

		timings[id] = float(stats["sim"])
		check(bool(stats["finished"]), "%s: full traversal finished" % id)
		var label := "%s: gates climbed (%d)" % [id, int(stats["gates"])]
		check(int(stats["gates"]) == 3, label)

	# No copy drift between per-skin runs and the base test: same harness.
	print("")
	for id in timings:
		print("[skin] %-16s sim %.1fs" % [id, timings[id]])
	var sorted := timings.values()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2]
	var spread_ok := true
	var worst := ""
	for id in timings:
		if timings[id] > median * 2.5:
			spread_ok = false
			worst = id
	check(spread_ok, "per-skin timing spread sane (median %.1fs, worst offender: %s)" % [median, worst if worst != "" else "none"])

	print("")
	if fails.is_empty():
		print("=== SKIN BOT SANITY PASSED (%d checks) ===" % checks)
		quit(0)
	else:
		for f in fails:
			printerr("[FAILED] " + f)
		print("=== SKIN BOT SANITY FAILED (%d/%d) ===" % [fails.size(), checks])
		quit(1)
