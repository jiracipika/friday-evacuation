extends SceneTree

func _init() -> void:
	print("=== FRIDAY 5PM: FULL BOOT TEST ===")
	
	# In SceneTree mode, autoloads are NOT initialized.
	# So we test scripts that DON'T reference autoloads directly.
	
	# Verify all .gd scripts compile (syntax-only)
	var scripts = [
		"res://scripts/PlayerChair.gd",
		"res://scripts/SabotageTrap.gd",
		"res://scripts/PowerUpVisual.gd",
		"res://scripts/ImpactFX.gd",
		"res://scripts/MobileControls.gd",
		"res://scripts/AudioManager.gd",
		"res://scripts/ModeHUD.gd",
		"res://scripts/ModeCard.gd",
		"res://scripts/Lobby.gd",
		"res://scripts/Network.gd",
		"res://scripts/NetworkSmokeTest.gd",
		"res://scripts/Hauled.gd",
		"res://scripts/ShopSeek.gd",
		"res://scripts/PizzaColony.gd",
		"res://scripts/PauseMenu.gd",
		"res://scripts/StatsManager.gd",
		"res://scripts/LoadingScreen.gd",
		"res://scripts/CreditsScreen.gd",
		"res://scripts/Accessibility.gd",
		"res://scripts/SubtitleOverlay.gd",
		"res://scripts/RaceModifiers.gd",
	]
	
	var all_pass = true
	for script_path in scripts:
		var script = load(script_path)
		if script:
			print("[PASS] %s compiles" % script_path)
		else:
			print("[FAIL] %s failed to compile" % script_path)
			all_pass = false
	
	# Main.tscn and Evacuation.tscn reference autoload identifiers, so their
	# scripts are verified by the project runtime boot command instead.
	var scenes = [
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
