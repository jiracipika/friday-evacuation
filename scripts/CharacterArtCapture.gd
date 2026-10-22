extends SceneTree
## Real renderer captures. No image editing or external assets.
## DISPLAY=:20 godot --path . --rendering-method gl_compatibility
##   --resolution 1440x900 --script scripts/CharacterArtCapture.gd -- --lineup

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var lineup := OS.get_cmdline_user_args().has("--lineup")
	root.content_scale_size = Vector2i(1440, 900)
	root.size = Vector2i(1440, 900)
	if lineup:
		_lineup()
	elif OS.get_cmdline_user_args().has("--race"):
		_race()
	else:
		var menu = load("res://scenes/Main.tscn").instantiate()
		root.add_child(menu)
		menu._open_customize_subview()
		if OS.get_cmdline_user_args().has("--mobile"):
			root.content_scale_size = Vector2i(390, 844)
			root.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://docs/characters/office-lineup.png" if lineup else "res://docs/characters/designer.png"
	if OS.get_cmdline_user_args().has("--mobile"):
		output = "res://docs/characters/designer-mobile.png"
	if OS.get_cmdline_user_args().has("--race"):
		output = "res://docs/characters/in-game.png"
	DirAccess.make_dir_recursive_absolute("res://docs/characters")
	root.get_texture().get_image().save_png(output)
	print("CAPTURE: " + output)
	quit(0)

func _race() -> void:
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var scene = load("res://scenes/Evacuation.tscn").instantiate()
	root.add_child(scene)
	var chair: Node3D = scene.local_player
	chair.position = Vector3(0, 0.6, -2)
	chair.set_physics_process(false)
	scene.set_process(false)
	scene.set_physics_process(false)
	var controls := scene.get_node_or_null("ControlsOverlay") as CanvasLayer
	if controls:
		controls.visible = false
	var countdown := scene.get_node_or_null("CountdownOverlay") as CanvasLayer
	if countdown:
		countdown.visible = false
	scene.countdown_label.visible = false
	if is_instance_valid(scene.ghost_racer):
		scene.ghost_racer.visible = false
	scene._update_floor_culling()
	scene._update_hud()
	var camera := root.get_camera_3d()
	camera.position = chair.position + Vector3(3.4, 2.1, -3.5)
	camera.look_at(chair.position + Vector3(0, 0.75, 0))

func _lineup() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0e1520")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title := Label.new()
	title.text = "FRIDAY 5PM / MEET YOUR COWORKERS"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("ffd65c"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "11 low-poly office characters. Mix outfits, hair, expressions and props in YOUR RIDE."
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("b4c4de"))
	column.add_child(subtitle)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	for character in FridayCharacterRoster.all():
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 215
		grid.add_child(card)
		var preview = load("res://scripts/MenuHero.gd").new()
		preview.custom_minimum_size = Vector2(215, 285)
		preview.preview_character_id = character.id
		preview.spin = 0.0
		card.add_child(preview)
		var label := Label.new()
		label.text = character.name
		label.add_theme_font_size_override("font_size", 17)
		var color := Color(character.body)
		label.add_theme_color_override("font_color", color.lightened(0.4) if color.v < 0.55 else color)
		card.add_child(label)
		var role := Label.new()
		role.text = character.role
		role.add_theme_font_size_override("font_size", 11)
		card.add_child(role)
