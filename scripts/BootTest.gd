extends SceneTree

func _init() -> void:
	print("=== FRIDAY 5PM: FULL BOOT TEST ===")
	
	# In SceneTree mode, autoloads are NOT initialized.
	# So we test scripts that DON'T reference autoloads directly.
	
	# Verify all .gd scripts compile (syntax-only)
	var scripts = [
		"res://scripts/PlayerChair.gd",
		"res://scripts/SabotageTrap.gd",
		"res://scripts/Hauled.gd",
		"res://scripts/ShopSeek.gd",
		"res://scripts/PizzaColony.gd",
	]
	
	var all_pass = true
	for script_path in scripts:
		var script = load(script_path)
		if script:
			print("[PASS] %s compiles" % script_path)
		else:
			print("[FAIL] %s failed to compile" % script_path)
			all_pass = false
	
	# Verify all .tscn scenes load
	var scenes = [
		"res://scenes/Main.tscn",
		"res://scenes/Evacuation.tscn",
		"res://scenes/PlayerChair.tscn",
		"res://scenes/Hauled.tscn",
		"res://scenes/ShopSeek.tscn",
		"res://scenes/PizzaColony.tscn",
		"res://scenes/objects/SabotageTrap.tscn",
	]
	
	for scene_path in scenes:
		var scene = load(scene_path)
		if scene:
			print("[PASS] %s loads" % scene_path)
		else:
			print("[FAIL] %s failed to load" % scene_path)
			all_pass = false
	
	if all_pass:
		print("")
		print("=== ALL CHECKS PASSED ===")
	else:
		print("")
		print("=== SOME CHECKS FAILED ===")
	
	quit(0)
