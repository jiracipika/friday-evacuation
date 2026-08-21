extends SceneTree

var mode: Node3D
var frames := 0
var failures := PackedStringArray()
var checks := 0

func _init() -> void:
	var packed := load("res://scenes/ShopSeek.tscn")
	_check(packed != null, "Shop & Seek scene loads")
	if not packed:
		_report()
		return
	mode = packed.instantiate()
	root.add_child(mode)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8:
		_run_checks()
	return false

func _run_checks() -> void:
	_check(mode.shelves_built == 7, "seven deterministic shelf aisles built")
	_check(mode.section_names.size() == 3 and mode.section_names.has("CHECKOUT") and mode.section_names.has("PRODUCE") and mode.section_names.has("FROZEN"), "checkout, produce, and frozen sections built")
	_check(mode.disguise_props.size() >= 20, "twenty-plus labeled disguise props spawned")
	var variants := {}
	for prop in mode.disguise_props:
		variants[prop.get_meta("variant_id", "")] = true
	_check(variants.size() == mode.disguise_props.size(), "every disguise prop has a unique visual variant id")
	_check(mode.shopping_list.size() == 5, "single-player shopper list contains five items")
	_check(mode.guard != null and is_instance_valid(mode.guard), "patrolling security guard spawned")
	_check(mode.mode_hud != null, "timer/objective HUD mounted")
	_check(mode.player != null and mode.player.has_signal("interaction_requested"), "real player interaction signal wired")

	var required := String(mode.shopping_list[0])
	var required_prop: Area3D
	for prop in mode.disguise_props:
		if String(prop.get_meta("kind", "")) == required:
			required_prop = prop
			break
	_check(required_prop != null, "shopping-list item exists in world")
	if required_prop:
		_check(mode._try_collect_prop(required_prop), "shopper can collect a required list item")
		_check(mode.collected_items.has(required), "shopping progress records collected item")

	mode.assign_role(mode.player, 1) # HIDER
	var disguise_prop: Area3D = mode.disguise_props[0]
	mode.player.global_position = disguise_prop.global_position
	mode._toggle_interaction()
	_check(mode.disguised, "E interaction enters disguise")
	_check(not mode.player.can_move and mode.disguise_lock_timer > 0.0, "disguise enforces two-second freeze")
	_check(mode.disguise_visual != null and not mode.player.model_parent.visible, "product mesh replaces chair visual")
	mode._update_disguise(2.1)
	_check(mode.player.can_move and is_equal_approx(mode.player.carry_slowdown, 0.5), "disguised player unlocks at half speed")
	mode._toggle_interaction()
	_check(not mode.disguised and mode.player.model_parent.visible, "second interaction exits disguise")
	_check(is_equal_approx(mode.player.carry_slowdown, 1.0), "undisguise restores full movement speed")

	mode.assign_role(mode.player, 2) # SEEKER
	_check(mode.player.get_node_or_null("SeekerVest") != null, "seeker receives red vest")
	var trap_count_before := 0
	for child in mode.get_children():
		if child is Area3D and "owner_id" in child:
			trap_count_before += 1
	mode.player.trigger_mobile_action(&"sabotage")
	_check(mode.scan_cooldown > 4.9, "keyboard/mobile sabotage route activates seeker scan")
	var trap_count_after := 0
	for child in mode.get_children():
		if child is Area3D and "owner_id" in child:
			trap_count_after += 1
	_check(trap_count_after == trap_count_before, "seeker scan does not also drop a sabotage trap")
	_check(not mode.try_scan(), "scan cannot be spammed during cooldown")
	_check(mode.role_states.has(mode.player.get_instance_id()), "multiplayer-ready role state tracks player id")
	_report()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] " + label)
	else:
		failures.append(label)
		printerr("[FAIL] " + label)

func _report() -> void:
	if failures.is_empty():
		print("=== SHOP & SEEK SMOKE TEST PASSED (%d checks) ===" % checks)
		quit(0)
	else:
		printerr("=== SHOP & SEEK SMOKE TEST FAILED (%d/%d) ===" % [failures.size(), checks])
		quit(1)
