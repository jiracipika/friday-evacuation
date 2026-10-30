extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var target := args[0] if not args.is_empty() else "menu"
	var session := root.get_node("OfficeSession")
	if target != "menu" and target != "wardrobe":
		session.configuration.mode = target
	var path := "res://scenes/overhaul/OfficeLaunch.tscn" if target in ["menu", "wardrobe"] else "res://scenes/overhaul/OfficeGame.tscn"
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	if target == "wardrobe":
		scene.page = "coworker"
		scene.wardrobe = true
		scene._show_wardrobe()
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	print("FRAME_PRIMITIVES ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("FRAME_DRAW_CALLS ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	root.get_texture().get_image().save_png("/tmp/friday-%s.png" % target)
	print("CAPTURED /tmp/friday-%s.png" % target)
	quit()
