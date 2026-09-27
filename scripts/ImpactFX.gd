extends Node

static func burst(parent: Node, world_position: Vector3, color: Color, amount: int = 20) -> void:
	var particles = GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.position = world_position
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 180.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -8, 0)
	material.scale_min = 0.06
	material.scale_max = 0.16
	material.color = color
	particles.process_material = material
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

## GRAPHICS PASS: jet burst used by elevator rides / boost pickups — a
## short upward cone of warm sparks. Self-cleaning like the others.
static func boost_burst(world_position: Vector3) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	burst(tree.root, world_position, Color(1.0, 0.6, 0.15), 26)

static func confetti(parent: Node, world_position: Vector3) -> void:
	var particles = GPUParticles3D.new()
	particles.amount = 64
	particles.lifetime = 1.8
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.position = world_position
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 180.0
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 7.0
	material.gravity = Vector3(0, -5, 0)
	material.scale_min = 0.06
	material.scale_max = 0.14
	material.color = Color(1.0, 0.65, 0.1)
	particles.process_material = material
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.12, 0.04, 0.04)
	particles.draw_pass_1 = mesh
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

## D5 results celebration: screen-space confetti burst over the results panel
## (CPUParticles2D, top-center, ORANGE/LIME/CYAN mix, ~1.2s, self-cleaning).
## `parent` may be any CanvasItem-bearing node (a CanvasLayer works).
static func confetti_2d(parent: Node, top_center: Vector2) -> void:
	if parent == null:
		return
	var particles := CPUParticles2D.new()
	particles.position = top_center
	particles.amount = 90
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.direction = Vector2(0, 1)
	particles.spread = 75.0
	particles.gravity = Vector2(0, 620)
	particles.initial_velocity_min = 300.0
	particles.initial_velocity_max = 620.0
	particles.angular_velocity_min = -240.0
	particles.angular_velocity_max = 240.0
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.604, 0.102))
	ramp.set_color(1, Color(0.62, 0.92, 0.23))
	ramp.add_point(0.5, Color(0.30, 0.85, 0.95))
	particles.color_ramp = ramp
	var img := Image.create(5, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	particles.texture = ImageTexture.create_from_image(img)
	parent.add_child(particles)
	particles.emitting = true
	var tree := parent.get_tree()
	if tree:
		tree.create_timer(1.7).timeout.connect(particles.queue_free)
