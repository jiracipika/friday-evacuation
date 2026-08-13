extends SceneTree

func _init() -> void:
	print("=== FRIDAY 5PM: HEADLESS TEST ===")
	print("Testing scene loading...")
	
	# Test 1: Load Main scene
	var main_scene = load("res://scenes/Main.tscn")
	if main_scene:
		print("[PASS] Main.tscn loads")
	else:
		print("[FAIL] Main.tscn failed to load")
	
	# Test 2: Load Evacuation scene
	var evac_scene = load("res://scenes/Evacuation.tscn")
	if evac_scene:
		print("[PASS] Evacuation.tscn loads")
	else:
		print("[FAIL] Evacuation.tscn failed to load")
	
	# Test 3: Load PlayerChair scene
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if player_scene:
		print("[PASS] PlayerChair.tscn loads")
	else:
		print("[FAIL] PlayerChair.tscn failed to load")
	
	# Test 4: Load secondary mode scenes
	for mode in ["Hauled", "ShopSeek", "PizzaColony"]:
		var s = load("res://scenes/%s.tscn" % mode)
		if s:
			print("[PASS] %s.tscn loads" % mode)
		else:
			print("[FAIL] %s.tscn failed to load" % mode)
	
	# Test 5: Load SabotageTrap scene
	var trap_scene = load("res://scenes/objects/SabotageTrap.tscn")
	if trap_scene:
		print("[PASS] SabotageTrap.tscn loads")
	else:
		print("[FAIL] SabotageTrap.tscn failed to load")
	
	# Test 6: Check autoloads
	if Engine.has_singleton("GameManager"):
		print("[PASS] GameManager autoload registered")
	else:
		print("[INFO] GameManager not in Engine singletons (expected — autoloads are scene-tree)")
	
	# Test 7: Instantiate Evacuation and check it starts
	if evac_scene:
		var instance = evac_scene.instantiate()
		if instance:
			print("[PASS] Evacuation.tscn instantiates")
		else:
			print("[FAIL] Evacuation.tscn instantiation failed")
	
	print("=== TEST COMPLETE ===")
	quit(0)
