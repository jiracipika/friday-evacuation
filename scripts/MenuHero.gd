# MenuHero.gd — rotating chair preview for the main menu.
#
# Real launch: miniature 3D turntable from the REAL chair prefab with the
# player's current rider/skin pick, rendered into a SubViewport.
# Headless (CI/movie QA): the dummy renderer cannot rasterize SubViewports
# (texture_2d_get crashes), so a 2D procedural chair silhouette is drawn
# instead — the panel still renders for vision QA.
extends SubViewportContainer

const UI_THEME = preload("res://scripts/UITheme.gd")

var viewport: SubViewport
var turntable: Node3D
var chair_instance: Node3D
var spin: float = 0.4
var headless := false
var time: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(240, 200)
	stretch = true

func _ready() -> void:
	headless = OS.get_cmdline_args().has("--headless") \
		or DisplayServer.get_name() == "headless"
	if headless:
		# 2D fallback: animated silhouette, no GPU rasterization needed.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	_build_3d()

func _build_3d() -> void:
	viewport = SubViewport.new()
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(240, 200)
	add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)

	# Camera: slightly above, looking down at the chair.
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.35, 2.6)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.35, 0))
	cam.current = true

	# Turntable pedestal: opaque disc + glowing rim. StaticBody collision so
	# the REAL chair prefab (a CharacterBody3D) doesn't fall through — its
	# own physics would otherwise drop it out of view (caught in vision QA).
	turntable = Node3D.new()
	world.add_child(turntable)
	var pedestal := StaticBody3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9
	disc.bottom_radius = 1.0
	disc.height = 0.08
	var pedestal_mesh := MeshInstance3D.new()
	pedestal_mesh.mesh = disc
	pedestal_mesh.position = Vector3(0, -0.04, 0)
	pedestal.add_child(pedestal_mesh)
	var ped_col := CollisionShape3D.new()
	var ped_shape := CylinderShape3D.new()
	ped_shape.radius = 1.0
	ped_shape.height = 0.08
	ped_col.shape = ped_shape
	ped_col.position = Vector3(0, -0.04, 0)
	pedestal.add_child(ped_col)
	turntable.add_child(pedestal)
	var ped_mat := StandardMaterial3D.new()
	ped_mat.albedo_color = Color(0.10, 0.10, 0.16)
	ped_mat.roughness = 0.6
	pedestal_mesh.material_override = ped_mat
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.92
	rim_mesh.outer_radius = 1.02
	rim.mesh = rim_mesh
	rim.position = Vector3(0, 0.01, 0)
	turntable.add_child(rim)
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(1.0, 0.60, 0.22)
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(1.0, 0.60, 0.22)
	rim_mat.emission_energy_multiplier = 1.6
	rim.material_override = rim_mat

	# Key light (warm), fill (cool), rim (orange accent).
	var key := OmniLight3D.new()
	key.position = Vector3(1.8, 2.4, 1.6)
	key.light_color = Color(1.0, 0.9, 0.8)
	key.omni_range = 6.0
	key.light_energy = 1.4
	world.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.2, 1.4, -1.2)
	fill.light_color = Color(0.55, 0.65, 0.9)
	fill.omni_range = 6.0
	fill.light_energy = 0.7
	world.add_child(fill)
	var rimlight := DirectionalLight3D.new()
	rimlight.rotation_degrees = Vector3(-30, 200, 0)
	rimlight.light_color = Color(1.0, 0.6, 0.2)
	rimlight.light_energy = 0.9
	world.add_child(rimlight)

	spawn_chair()

func spawn_chair() -> void:
	if headless:
		return
	if chair_instance:
		chair_instance.queue_free()
	var gm := get_node_or_null("/root/GameManager")
	var scene = load("res://scenes/PlayerChair.tscn")
	if scene:
		chair_instance = scene.instantiate()
		# Identity follows the menu pick (globals are the default anyway).
		if gm and "selected_skin_id" in gm:
			chair_instance.set("skin_id", String(gm.selected_skin_id))
		if gm and "selected_character_id" in gm:
			chair_instance.set("character_id", String(gm.selected_character_id))
		turntable.add_child(chair_instance)
		chair_instance.position = Vector3(0, 0.04, 0)
		if "can_move" in chair_instance:
			chair_instance.set("can_move", false)
		if "player_display_name" in chair_instance:
			chair_instance.set("player_display_name", "")
	# Hide the nametag if present.
	if chair_instance and chair_instance.has_node("Nametag"):
		var nt = chair_instance.get_node("Nametag")
		if nt:
			nt.visible = false

func refresh_for_pick() -> void:
	spawn_chair()
	if headless:
		queue_redraw()

func _process(delta: float) -> void:
	time += delta
	if turntable:
		turntable.rotation.y += spin * delta
	elif headless:
		queue_redraw()

# --- 2D headless fallback art -------------------------------------------
func _draw() -> void:
	if not headless:
		return
	var c := size / 2.0
	var s := minf(size.x, size.y) / 200.0
	var accent := Color(1.0, 0.60, 0.22)
	var body := Color(0.16, 0.17, 0.24)
	# Pedestal disc.
	draw_circle(Vector2(c.x, c.y + 58 * s), 62 * s, Color(0.08, 0.08, 0.13), true)
	draw_arc(Vector2(c.x, c.y + 58 * s), 62 * s, 0, TAU, 48, accent, 2.0, true)
	# Chair silhouette (bobbing gently): backrest, seat, column, star base.
	var bob := sin(time * 1.6) * 3.0 * s
	var sway := sin(time * 0.8) * 4.0 * s
	var seat := Vector2(c.x + sway, c.y - 8 * s + bob)
	draw_rect(Rect2(seat + Vector2(-26 * s, -44 * s), Vector2(14 * s, 46 * s)), body, true)  # backrest
	draw_rect(Rect2(seat + Vector2(-28 * s, -2 * s), Vector2(58 * s, 12 * s)), body, true)   # seat
	draw_rect(Rect2(seat + Vector2(-3 * s, 8 * s), Vector2(6 * s, 34 * s)), body, true)      # column
	# Star base: five spokes + casters.
	for i in 5:
		var ang := -PI / 2.0 + float(i) * TAU / 5.0 + sin(time * 0.8) * 0.08
		var spoke_end := seat + Vector2(cos(ang), 10 * s + sin(ang) * 26 * s) + Vector2(0, 34 * s)
		draw_line(seat + Vector2(0, 40 * s), spoke_end, body, 5 * s, true)
		draw_circle(spoke_end, 4.5 * s, accent.darkened(0.4), true)
	draw_circle(seat + Vector2(0, -46 * s), 5 * s, accent, true)  # headrest dot
