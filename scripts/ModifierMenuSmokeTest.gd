# ModifierMenuSmokeTest.gd — verifies the chaos-picker UI against real
# RaceModifiers state: chip sync, toggling, summary text, CLEAR, persistence.
# Raw SceneTree test (no autoloads): AudioManager is optional by design.
extends SceneTree

var checks: int = 0
var failures: int = 0
var state: int = 0
var wait_time: float = 0.0
var menu: Control
var RM = null

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		failures += 1
		print("[FAIL] %s" % label)

func _process(delta: float) -> bool:
	if wait_time > 0.0:
		wait_time -= delta
		if wait_time > 0.0:
			return false
	match state:
		0:
			_run()
			state = 1
			wait_time = 0.1
		1:
			_finish()
			return true
	return false

func _summary_text() -> String:
	return menu.summary_label.text

func _run() -> void:
	RM = load("res://scripts/RaceModifiers.gd")
	RM.selected.clear()
	RM.save_to_cfg()

	menu = load("res://scripts/ModifierMenu.gd").new()
	root.add_child(menu)

	check(menu.chips.size() == 5, "five chips built")
	check(menu.title_label.text == "TODAY'S OFFICE CHAOS", "header title present")
	check(not menu.clear_button.visible, "CLEAR hidden with no rules active")
	check("Classic race" in _summary_text(), "classic summary when empty")

	# Toggle a chip through the real handler path (button -> state -> refresh).
	var chip: Button = menu.chips[RM.Modifier.LOW_GRAVITY]
	chip.button_pressed = true
	check(RM.is_active(RM.Modifier.LOW_GRAVITY), "chip toggle activates modifier")
	check(menu.clear_button.visible, "CLEAR visible when a rule is active")
	check("MOON OFFICE" in _summary_text(), "summary names the active rule")

	# Toggle-off returns to classic summary.
	chip.button_pressed = false
	check(not RM.is_active(RM.Modifier.LOW_GRAVITY), "chip untoggle deactivates")
	check("Classic race" in _summary_text(), "classic summary restored")

	# Idempotence guard: setting the same pressed state must not flip state.
	var before: int = RM.selected.size()
	chip.set_pressed_no_signal(true)
	chip.set_pressed_no_signal(false)
	check(RM.selected.size() == before, "set_pressed_no_signal does not mutate state")

	# Turn everything on: FULL CHAOS summary + all chips reflect state.
	for mod in RM.ALL:
		menu.chips[mod].button_pressed = true
	check(RM.selected.size() == 5, "all rules activated via chips")
	check("FULL CHAOS" in _summary_text(), "full-chaos summary when all on")

	# CLEAR button empties state and updates chips + summary.
	menu._on_clear_pressed()
	check(RM.selected.is_empty(), "CLEAR empties modifier state")
	var all_off := true
	for mod in RM.ALL:
		if menu.chips[mod].button_pressed:
			all_off = false
	check(all_off, "CLEAR unpresses every chip")
	check("Classic race" in _summary_text(), "classic summary after CLEAR")
	check(not menu.clear_button.visible, "CLEAR hides again after clearing")

	# Persistence: state chosen in the menu survives a save/load round-trip.
	menu.chips[RM.Modifier.SLIPPERY].button_pressed = true
	RM.save_to_cfg()
	RM.selected.clear()
	RM.load_from_cfg()
	check(RM.is_active(RM.Modifier.SLIPPERY), "menu choice persists to cfg")

	# refresh() re-syncs chips from external state changes.
	RM.selected.clear()
	menu.refresh()
	check(not menu.chips[RM.Modifier.SLIPPERY].button_pressed, "refresh() re-syncs chips")

	# Leave clean state for other tests.
	menu._on_clear_pressed()
	menu.queue_free()

func _finish() -> void:
	if failures == 0 and checks > 0:
		print("=== MODIFIER MENU SMOKE TEST PASSED (%d checks) ===" % checks)
		quit(0)
	else:
		print("=== MODIFIER MENU SMOKE TEST FAILED (%d/%d) ===" % [failures, checks])
		quit(1)
