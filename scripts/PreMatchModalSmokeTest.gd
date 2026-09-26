# PreMatchModalSmokeTest.gd — blocking pre-game briefing verification.
#   1. mount() pauses the tree; modal exists; suppress_next skips.
#   2. Agree (button press simulation) unpauses and frees the modal.
#   3. Hotspot sweep queue: builds, prefers own subnet, bounded size.
#   4. Boot each mode scene headlessly: tree ends up paused with modal
#      mounted, then unpaused after agreement, and the mode resumes.
# Run: godot --headless --path . --script scripts/PreMatchModalSmokeTest.gd
extends SceneTree

var checks_total := 0
var checks_passed := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks_total += 1
	if cond:
		checks_passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _agree_and_settle(scene: Node) -> void:
	var modal: Node = scene.get_node_or_null("PreMatchModal")
	if modal:
		modal._agree()
	for i in 3:
		await process_frame

func _run() -> void:
	var PM = load("res://scripts/PreMatchModal.gd")
	check(PM != null, "PreMatchModal.gd compiles")

	# --- 1. Mount pauses the tree -----------------------------------------
	var EvacScene = load("res://scenes/Evacuation.tscn")
	var evc = EvacScene.instantiate()
	root.add_child(evc)
	await process_frame
	await process_frame
	check(paused, "tree paused while modal is up")
	var modal: Node = evc.get_node_or_null("PreMatchModal")
	check(modal != null, "modal mounted in Evacuation")
	var legacy_hud: CanvasLayer = null
	if modal:
		check(modal.agree_button != null and modal.agree_button.text.begins_with("CLOCK OUT"),
			"agree button present with CLOCK OUT text")
		# --- S-E structure (FINAL-SPEC section 6 / board f4-howto) ---------
		check(modal.find_child("TapeStrip", true, false) != null,
			"hazard-tape strip present")
		check(modal.find_child("Scrim", true, false) != null
			and absf(modal.find_child("Scrim", true, false).color.a - 0.8) < 0.01,
			"scrim at spec alpha 0.8")
		var meta: Label = modal.find_child("StepsMeta", true, false)
		check(meta != null and meta.text == "3 STEPS",
			"step-count meta derived from objective lines (got %s)"
				% (meta.text if meta else "<none>"))
		var cards := modal.find_children("StepCard*", "PanelContainer", true, false)
		check(cards.size() == 3, "three step cards (got %d)" % cards.size())
		var parsed_titles := []
		for c in cards:
			var labels: Array = c.find_children("*", "Label", true, false)
			for l in labels:
				if l.text == "DRIVE" or l.text == "CLIMB" or l.text == "ESCAPE":
					parsed_titles.append(l.text)
		check(parsed_titles == ["DRIVE", "CLIMB", "ESCAPE"],
			"'TITLE — copy' lines parsed into card titles %s" % [parsed_titles])
		var pictos := modal.find_children("Picto", "Control", true, false)
		check(pictos.size() == 3, "drawn pictograms present (got %d)" % pictos.size())
		var keycaps := modal.find_children("Keycap*", "PanelContainer", true, false)
		var pad_chips := modal.find_children("PadChip*", "PanelContainer", true, false)
		check(keycaps.size() >= 10, "keyboard keycap chips present (%d)" % keycaps.size())
		check(pad_chips.size() == 7, "controller pad circles present (%d)" % pad_chips.size())
		var hint: Label = modal.find_child("CtaHint", true, false)
		check(hint != null and "SPACE" in hint.text, "CTA carries the SPACE / A hint")
		# Spec: HUD timer hidden while the modal is up, restored on agree.
		legacy_hud = evc.get_node_or_null("UI")
		check(legacy_hud != null and not legacy_hud.visible,
			"legacy HUD layer hidden while modal is up")
		check(evc.hud_ext != null and not evc.hud_ext.visible,
			"extended HUD layer hidden while modal is up")
	# Countdown must NOT have started ticking (timer frozen while paused).
	var ev_script: Node = evc
	var timer_before: float = ev_script.timer
	for i in 20:
		await process_frame
	var timer_after: float = ev_script.timer
	check(absf(timer_after - timer_before) < 0.0001,
		"timer frozen while paused (%.3f -> %.3f)" % [timer_before, timer_after])
	check(ev_script.match_state == &"countdown",
		"match_state is countdown (waiting for agreement)")

	# --- 2. Agree unpauses -------------------------------------------------
	await _agree_and_settle(evc)
	check(not paused, "tree unpaused after I AGREE")
	check(evc.get_node_or_null("PreMatchModal") == null, "modal freed after agree")
	check(legacy_hud != null and legacy_hud.visible and evc.hud_ext.visible,
		"HUD layers restored after agreement")
	var timer_running_before: float = ev_script.timer
	await create_timer(0.4).timeout
	var timer_running_after: float = ev_script.timer
	check(timer_running_after < timer_running_before,
		"countdown ticks after agreement (%.2f -> %.2f)" % [timer_running_before, timer_running_after])
	evc.queue_free()
	await process_frame
	paused = false

	# --- 3. Second mount does NOT pause again (suppress path) -------------
	PM.suppress_next()
	var evc2 = EvacScene.instantiate()
	root.add_child(evc2)
	await process_frame
	await process_frame
	check(not paused, "suppress_next skips the modal entirely")
	check(evc2.get_node_or_null("PreMatchModal") == null, "no modal node when suppressed")
	evc2.queue_free()
	await process_frame

	# --- 4. Hotspot sweep queue --------------------------------------------
	var NET = load("res://scripts/Network.gd")
	var net = root.get_node_or_null("/root/Network")
	if net == null:
		# Standalone script run: instantiate a bare Network for the sweep API.
		net = NET.new()
		root.add_child(net)
	net._build_hotspot_queue()
	check(net._hotspot_queue.size() > 0 and net._hotspot_queue.size() < 60,
		"hotspot queue bounded (%d entries)" % net._hotspot_queue.size())
	var own: String = NET.local_ip()
	if own != "":
		var own_prefix := "%s.%s.%s." % [own.split(".")[0], own.split(".")[1], own.split(".")[2]]
		check(net._hotspot_queue[0].begins_with(own_prefix),
			"own subnet queued first (%s...)" % net._hotspot_queue[0])
	var has_ios := false
	for ip in net._hotspot_queue:
		if str(ip).begins_with("172.20.10."):
			has_ios = true
	check(has_ios, "iPhone hotspot range covered")
	net.queue_free()
	await process_frame

	check(failures.is_empty(), "no failures")
	print("PreMatchModalSmokeTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
