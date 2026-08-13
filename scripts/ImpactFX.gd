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
