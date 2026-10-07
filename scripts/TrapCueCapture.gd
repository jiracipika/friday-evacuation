# TrapCueCapture.gd — movie-frame visual QA for the Phase 8B trap shape cues
# (name label + silhouette icon per SabotageTrap type). Spawns one trap of
# EACH type in a row on floor 1 of the real Evacuation scene and frames them
# from a chase-camera-like distance; no race is started, no career writes.
#   FE_TRAP_CUE=close godot --path . --script scripts/TrapCueCapture.gd \
#     --write-movie /tmp/fe-trap-cue/f.png --fixed-fps 10 --quit-after 6
extends SceneTree

func _init() -> void:
	_mount.call_deferred()

func _mount() -> void:
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var scene: Node = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.set_physics_process(false)
	var controls: CanvasLayer = scene.get_node_or_null("ControlsOverlay")
	if controls:
		controls.visible = false
	# One trap of each type in a row on the open floor (z=2 aisle — the z=0
	# row intersects a desk and the ghost spawn, whose translucent capsule
	# blends OVER the cue and fakes a readability failure).
	var trap_scene: PackedScene = load("res://scenes/objects/SabotageTrap.tscn")
	var types := ["water", "banana", "stapler", "spill"]
	var x := -3.9
	for t in types:
		var trap = trap_scene.instantiate()
		trap._set_forced_type(t)
		trap.lifetime = 600.0  # outlive the capture
		scene.add_child(trap)
		trap.position = Vector3(x, 0.05, 2.0)
		x += 2.6
	var camera: Camera3D = root.get_camera_3d()
	if camera:
		var focus := Vector3(-1.3, 0.9, 2.0)
		if OS.get_environment("FE_TRAP_CUE") == "close":
			camera.position = focus + Vector3(1.2, 0.9, 3.0)
		else:
			# ~7m out, 2.6m up — how a trailing chase camera meets a trap.
			camera.position = focus + Vector3(2.2, 2.6, 6.6)
		camera.look_at(focus)
