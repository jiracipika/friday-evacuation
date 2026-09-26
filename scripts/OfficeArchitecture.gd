# Visual-only wall installations: shared beveled meshes, no lights or physics.
extends RefCounted

const Dressing = preload("res://scripts/OfficeDressing.gd")
const TITLES := ["OPERATIONS", "COLLABORATION", "FACILITIES", "PARKING DECK"]
const ACCENTS := [Color("2C8C91"), Color("8674B8"), Color("929CA2"), Color("2C8C91")]
static var materials: Dictionary = {}

static func material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.78
		materials[color] = mat
	return materials[color]

static func block(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = Dressing.beveled_box(size, 0.018)
	mesh.material_override = material(color)
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

static func label(parent: Node3D, text: String, pos: Vector3, scale_px: float, color: Color) -> void:
	var text_node := Label3D.new()
	text_node.text = text
	text_node.font_size = 64
	text_node.pixel_size = scale_px
	text_node.modulate = color
	text_node.outline_size = 0
	text_node.position = pos
	text_node.no_depth_test = false
	parent.add_child(text_node)

static func build(floor_index: int) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = "OfficeArchitecture%d" % floor_index
	assembly.add_to_group("office_architecture")
	var slate := Color("263445")
	var ivory := Color("F3E7D3")
	var accent: Color = ACCENTS[floor_index]
	# North-wall inset, front faces toward the playable room (+Z).
	block(assembly, Vector3(17.0, 3.5, 0.12), Vector3(0, 3.05, -19.72), slate)
	# Repeated vertical acoustic battens give real silhouette/depth, not noise.
	for i in range(15):
		block(assembly, Vector3(0.12, 3.18, 0.12), Vector3(-8.0 + i * 0.26, 3.05, -19.6), Color("C99454"))
	block(assembly, Vector3(17.35, 0.14, 0.32), Vector3(0, 4.86, -19.62), ivory)
	block(assembly, Vector3(17.35, 0.16, 0.26), Vector3(0, 1.26, -19.62), ivory)
	block(assembly, Vector3(0.12, 2.55, 0.08), Vector3(-2.9, 3.05, -19.6), accent)
	label(assembly, "%02d" % (floor_index + 1), Vector3(-1.7, 3.26, -19.5), 0.022, accent)
	label(assembly, TITLES[floor_index], Vector3(3.15, 3.5, -19.5), 0.0065, ivory)
	label(assembly, "FRIDAY / WORKPLACE SERVICES", Vector3(3.15, 2.73, -19.5), 0.0027, Color("B8B5AE"))
	# Oversized clock fixed at five o'clock: the game's visual punchline.
	var clock := Node3D.new()
	clock.name = "FivePMClock"
	clock.position = Vector3(-6.2, 3.1, -19.39)
	assembly.add_child(clock)
	for spec in [[1.02, 0.14, slate], [0.90, 0.18, ivory]]:
		var disc := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = spec[0]
		cylinder.bottom_radius = spec[0]
		cylinder.height = spec[1]
		cylinder.radial_segments = 32
		disc.mesh = cylinder
		disc.rotation.x = PI / 2.0
		disc.material_override = material(spec[2])
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clock.add_child(disc)
	for hour in range(12):
		var angle := hour * TAU / 12.0
		var tick := block(clock, Vector3(0.04, 0.12, 0.025), Vector3(sin(angle) * 0.75, cos(angle) * 0.75, 0.11), slate)
		tick.rotation.z = -angle
	block(clock, Vector3(0.055, 0.67, 0.03), Vector3(0, 0.30, 0.14), slate)
	var hand := block(clock, Vector3(0.07, 0.46, 0.03), Vector3(0.10, -0.18, 0.15), accent)
	hand.rotation.z = -5.0 * TAU / 12.0
	block(clock, Vector3(0.13, 0.13, 0.05), Vector3(0, 0, 0.17), slate)
	# Wall-base rails tie the feature into both side walls. Above floor obstacles.
	for side in [-1.0, 1.0]:
		block(assembly, Vector3(0.13, 0.20, 38.0), Vector3(side * 19.75, 1.22, 0), slate)
		block(assembly, Vector3(0.16, 0.07, 38.0), Vector3(side * 19.72, 1.36, 0), ivory)
	return assembly
