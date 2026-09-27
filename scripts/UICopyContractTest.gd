# UICopyContractTest.gd — P2 microcopy contract (design spec §4).
#
# The player-facing strings the spec pins, asserted against SOURCE so a
# copy regression cannot ship. Menu tables were superseded by the S-B1
# departure redesign (P0B-audited) — those live in MenuDepartureSmokeTest.
# This file guards the sections still authoritative: HUD readouts (§4.3),
# results (§4.6), pause (§4.7), splash (§4.8).
extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		print("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _run() -> void:
	var hud := _src("res://scripts/HUD.gd")
	# §4.3 readouts — spec copy, emoji-free (fallback font may lack glyphs).
	for s in ["COFFEE BOOST READY [SPACE]", "COFFEE BOOST ACTIVE",
			"Q  SABOTAGE", "STAPLER x%d [Q]", "SPILL x%d [Q]"]:
		check(hud.contains(s), "HUD §4.3: %s" % s)
	check(not hud.contains("☕") and not hud.contains("📎") and not hud.contains("💧"),
		"HUD §4.3: no emoji-dependent copy")

	var evac := _src("res://scripts/Evacuation.gd")
	# §4.6 results.
	for s in ["%s WINS!", "NO WINNER", "NEW TOP-SPEED RECORD",
			"NEW CHAIR: %s", "MODIFIERS: ", "REMATCH", "MAIN MENU"]:
		check(evac.contains(s), "results §4.6: %s" % s)

	var pause := _src("res://scripts/PauseMenu.gd")
	for s in ["PAUSED", "RESUME", "QUIT TO MENU"]:
		check(pause.contains(s), "pause §4.7: %s" % s)

	var splash := _src("res://scripts/SplashScreen.gd")
	for s in ["4:59 PM FRIDAY", "CLICK / PRESS A TO START", "TAP / PRESS A TO START"]:
		check(splash.contains(s), "splash §4.8: %s" % s)

	var lobby := _src("res://scripts/Lobby.gd")
	for s in ["MULTIPLAYER LOBBY", "Choose HOST or enter a LAN address to JOIN.",
			"SCAN LOCAL WI-FI"]:
		check(lobby.contains(s), "lobby §4.5: %s" % s)

	if failures.is_empty() and checks > 0:
		print("=== UI COPY CONTRACT TEST PASS (%d/%d) ===" % [checks, checks])
		quit(0)
	else:
		print("=== UI COPY CONTRACT TEST FAILED (%d/%d) ===" % [checks - failures.size(), checks])
		for f in failures:
			print("  - %s" % f)
		quit(1)
