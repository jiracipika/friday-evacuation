# Capture real engine views without a desktop screenshot or gameplay save.
# FE_ART_FLOOR=0..3 godot --path . --script scripts/ArtDirectionCapture.gd
#   --write-movie /tmp/fe-art/f.png --fixed-fps 10 --quit-after 4
extends SceneTree

func _init() -> void:
	_mount.call_deferred()

func _mount() -> void:
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var scene: Node = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var floor_index: int = clampi(int(OS.get_environment("FE_ART_FLOOR")), 0, 3)
	var chair: Node3D = scene.local_player
	chair.position = Vector3(0, float(floor_index) * 6.0 + 0.8, 10.0 if floor_index == 2 else 0.0)
	chair.set_physics_process(false)
	scene.set_process(false)
	scene.set_physics_process(false)
	var controls: CanvasLayer = scene.get_node_or_null("ControlsOverlay")
	if controls:
		controls.visible = false
	scene._update_floor_culling()
	scene._update_hud()
	var camera: Camera3D = root.get_camera_3d()
	if camera:
		camera.position = chair.position + Vector3(4.8, 3.6, 7.2)
		camera.look_at(chair.position + Vector3(0, 0.9, -2.0))
	# No race is started or ended; the harness never writes career outcomes.
