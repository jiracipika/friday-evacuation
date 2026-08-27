# AnnouncerSmokeTest.gd — verifies the race announcer end-to-end.
extends SceneTree

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("[PASS] " + label)
	else:
		fails += 1
		printerr("[FAIL] " + label)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var AnnouncerScript = load("res://scripts/Announcer.gd")
	check(AnnouncerScript != null, "Announcer.gd loads")

	var root_node := Node3D.new()
	get_root().add_child(root_node)

	# Mount + dedupe
	var a = AnnouncerScript.mount(root_node)
	check(a != null, "mount returns an announcer")
	var b = AnnouncerScript.mount(root_node)
	check(a == b, "mount dedupes (second call returns same node)")

	# Every line bank exists and is non-empty with all-String entries
	for bank in ["BOOST_LINES", "TRAP_HIT_LINES", "TRAP_DROP_LINES", "HAZARD_LINES",
			"PICKUP_LINES", "FINAL_STRETCH_LINES", "WIN_LINES", "LOSE_LINES", "START_LINES"]:
		var lines: Array = AnnouncerScript.get(bank)
		var ok: bool = lines != null and lines.size() >= 3
		if ok:
			for l in lines:
				if not (l is String and l.length() > 0):
					ok = false
		check(ok, "line bank %s populated (>=3 non-empty strings)" % bank)

	# say() returns a line and respects forced
	var line: String = a.say("misc", AnnouncerScript.get("START_LINES"), true)
	check(line != "", "forced say() returns a line")
	# Cooldown suppresses the same category immediately
	var suppressed: String = a.say("misc", AnnouncerScript.get("START_LINES"))
	check(suppressed == "", "category cooldown suppresses immediate repeat")

	# Simulate clock advance past the misc cooldown (3s)
	a._clock += 3.5
	var again: String = a.say("misc", AnnouncerScript.get("START_LINES"))
	check(again != "", "cooldown expiry allows repeat")

	# Unknown bank -> say still works with caller-supplied array
	var custom: String = a.say("misc", ["custom line"], true)
	check(custom == "custom line", "custom arrays pass through")

	# Captions: force at least one and confirm no crash with a11y absent
	var hit: String = a.say("trap", AnnouncerScript.get("TRAP_HIT_LINES"), true)
	check(hit != "", "trap line announces")

	if fails == 0:
		print("=== ANNOUNCER SMOKE TEST PASSED ===")
		quit(0)
	else:
		printerr("=== ANNOUNCER SMOKE TEST FAILED (%d) ===" % fails)
		quit(1)
