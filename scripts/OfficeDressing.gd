# OfficeDressing.gd — shared visual dressing library for the graphics pass.
#
# One static home for the reusable prop/architecture builders introduced in
# the 2026-09 graphics+polish pass:
#   - blob_shadow(): soft contact-shadow discs (GL Compatibility has no SSAO,
#     so grounded props get a cheap unshaded dark disc under them)
#   - ceiling_panel(): recessed troffer light panel (frame + emissive lens)
#   - column(): structural concrete column (real collision, corridor-safe)
#   - monitor()/desk_dressing(): desks gain screens, keyboards, mugs, papers
#     — all NON-colliding dressing so gameplay footprints never change
#   - elevator_portal(): door frame + metal doors + EXIT sign behind each pad
#   - exit_sign(): green emissive EXIT signage box
#
# Everything is procedural (no assets), static-cached where shared, and
# mobile-friendly (<=6 tiny meshes per prop, shared materials).
class_name OfficeDressing
extends RefCounted

# Shared material cache: key -> material. Instance-safe because materials
# hold ImageTextures that live for the whole session (no per-scene freeing).
static var _mats: Dictionary = {}

const GROUP_PANELS := "ceiling_panels"
const GROUP_COLUMNS := "office_columns"
const GROUP_PORTALS := "elevator_portals"
const GROUP_EXIT_SIGNS := "exit_signs"


static func _mat(key: String, builder: Callable) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D
	var mat: StandardMaterial3D = builder.call()
	_mats[key] = mat
	return mat


static func clear_cache() -> void:
	_mats.clear()


# ---------------------------------------------------------------- shadows --

static var _blob_tex: ImageTexture = null

## Soft radial dark blob used as a contact shadow (renderer has no SSAO).
## size = world-space diameter, opacity 0..1. Returns a MeshInstance3D the
## caller positions (y should sit ~0.02 above the floor).
static func blob_shadow(size: float, opacity: float = 0.38) -> MeshInstance3D:
	if _blob_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var dx := (float(x) - 31.5) / 31.5
				var dy := (float(y) - 31.5) / 31.5
				var d := sqrt(dx * dx + dy * dy)
				var a := clampf(1.0 - pow(d, 2.2), 0.0, 1.0)
				# Soften the rim so the disc never reads as a hard circle.
				a = pow(a, 1.5)
				img.set_pixel(x, y, Color(0.02, 0.02, 0.04, a))
		_blob_tex = ImageTexture.create_from_image(img)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _blob_tex
	mat.albedo_color = Color(1, 1, 1, opacity)
	# No depth write: overlapping blobs must not z-fight or occlude.
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	mat.no_depth_test = false
	var mi := MeshInstance3D.new()
	mi.name = "BlobShadow"
	mi.mesh = mesh
	mi.material_override = mat
	# Blobs ARE the shadow — they must never receive/cast real ones.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Tiny y offsets stack safely; caller fine-tunes per prop.
	return mi


# ------------------------------------------------------------- architecture --

## Recessed ceiling troffer panel: dark frame + warm emissive lens.
## Panel faces DOWN (lens at bottom). Registering node is the caller's job.
static func ceiling_panel() -> MeshInstance3D:
	var root := MeshInstance3D.new()
	root.name = "CeilingPanel"

	var lens := MeshInstance3D.new()
	var lens_mesh := BoxMesh.new()
	lens_mesh.size = Vector3(2.6, 0.07, 1.1)
	lens.mesh = lens_mesh
	lens.position = Vector3(0, -0.035, 0)
	var lens_mat := _mat("panel_lens", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.98, 0.95, 0.86)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.84, 0.58)
		m.emission_energy_multiplier = 1.45
		m.roughness = 0.35
		return m)
	lens.material_override = lens_mat
	root.add_child(lens)

	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(2.8, 0.09, 1.3)
	frame.mesh = frame_mesh
	var frame_mat := _mat("panel_frame", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.73, 0.76)
		m.metallic = 0.5
		m.roughness = 0.45
		return m)
	frame.material_override = frame_mat
	root.add_child(frame)

	# Thin ceiling geometry: never a shadow caster (long-stripe smearing).
	root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	root.add_to_group(GROUP_PANELS)
	return root


## Structural column with REAL collision (corridor-safe: callers place at
## ±10,±10 which never intersects the center lanes or elevator pads).
static func column() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Column"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 5.7, 0.7)
	col.shape = shape
	col.position = Vector3(0, 2.85, 0)
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 5.7, 0.7)
	mesh.mesh = box
	mesh.position = Vector3(0, 2.85, 0)
	var mat := _mat("column", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.46, 0.45, 0.44)
		m.roughness = 0.85
		m.metallic = 0.05
		return m)
	mesh.material_override = mat
	body.add_child(mesh)
	# Base + cap trims give the column a finished silhouette.
	for trim_y in [0.06, 5.64]:
		var trim := MeshInstance3D.new()
		var trim_mesh := BoxMesh.new()
		trim_mesh.size = Vector3(0.9, 0.12, 0.9)
		trim.mesh = trim_mesh
		trim.position = Vector3(0, trim_y, 0)
		var trim_mat := _mat("column_trim", func() -> StandardMaterial3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.33, 0.32, 0.33)
			m.roughness = 0.6
			return m)
		trim.material_override = trim_mat
		body.add_child(trim)
	body.add_to_group(GROUP_COLUMNS)
	return body


## Elevator portal: door frame + metal double doors + green EXIT sign.
## yaw_to_center: the portal faces the supplied yaw (caller computes the
## direction toward the room center so the doors read from the floor).
static func elevator_portal(base_pos: Vector3, yaw: float) -> Node3D:
	var portal := Node3D.new()
	portal.name = "ElevatorPortal"
	portal.position = base_pos
	portal.rotation.y = yaw

	var frame_mat := _mat("portal_frame", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.28, 0.30, 0.34)
		m.metallic = 0.55
		m.roughness = 0.4
		return m)
	var door_mat := _mat("portal_door", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.58, 0.62, 0.66)
		m.metallic = 0.75
		m.roughness = 0.3
		return m)

	for spec in [
		{"dx": -2.2, "y": 1.55, "w": 0.28, "h": 3.1},   # left post
		{"dx": 2.2, "y": 1.55, "w": 0.28, "h": 3.1},    # right post
		{"dx": 0.0, "y": 3.15, "w": 4.7, "h": 0.4},     # header
	]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(spec["w"], spec["h"], 0.34)
		post.mesh = post_mesh
		post.position = Vector3(spec["dx"], spec["y"], 0.0)
		post.material_override = frame_mat
		portal.add_child(post)

	for side in [-1.0, 1.0]:
		var door := MeshInstance3D.new()
		var door_mesh := BoxMesh.new()
		door_mesh.size = Vector3(1.95, 2.9, 0.14)
		door.mesh = door_mesh
		door.position = Vector3(side * 1.0, 1.45, 0.05)
		door.material_override = door_mat
		portal.add_child(door)

	# Center seam indicator strips so the doors read as ELEVATOR doors.
	var seam_mat := _mat("portal_seam", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.7, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.15, 0.55, 1.0)
		m.emission_energy_multiplier = 1.2
		return m)
	for side in [-1.0, 1.0]:
		var strip := MeshInstance3D.new()
		var strip_mesh := BoxMesh.new()
		strip_mesh.size = Vector3(0.05, 2.6, 0.02)
		strip.mesh = strip_mesh
		strip.position = Vector3(side * 0.06, 1.45, 0.14)
		strip.material_override = seam_mat
		portal.add_child(strip)

	portal.add_to_group(GROUP_PORTALS)
	return portal


## Green emissive EXIT sign box + label.
static func exit_sign(pos: Vector3) -> Node3D:
	var sign_root := Node3D.new()
	sign_root.name = "ExitSign"
	sign_root.position = pos
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.1, 0.36, 0.12)
	box.mesh = box_mesh
	var mat := _mat("exit_sign", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.06, 0.5, 0.16)
		m.emission_enabled = true
		m.emission = Color(0.1, 0.9, 0.3)
		m.emission_energy_multiplier = 1.5
		return m)
	box.material_override = mat
	sign_root.add_child(box)
	var label := Label3D.new()
	label.text = "EXIT"
	label.font_size = 72
	label.outline_size = 0
	label.modulate = Color(0.85, 1.0, 0.88)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.position = Vector3(0, 0, 0.08)
	sign_root.add_child(label)
	sign_root.add_to_group(GROUP_EXIT_SIGNS)
	return sign_root


# ------------------------------------------------------------- desk props --

## A monitor on a stand: emissive screen + dark bezel + stand + base.
## Non-colliding dressing only. screen_variant 0..2 picks the display.
static func monitor(screen_variant: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Monitor"

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.3, 0.03, 0.2)
	base.mesh = base_mesh
	base.position = Vector3(0, 0.015, 0)
	base.material_override = _mat("prop_dark_plastic", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.08, 0.08, 0.1)
		m.roughness = 0.5
		m.metallic = 0.1
		return m)
	root.add_child(base)

	var stand := MeshInstance3D.new()
	var stand_mesh := CylinderMesh.new()
	stand_mesh.top_radius = 0.03
	stand_mesh.bottom_radius = 0.045
	stand_mesh.height = 0.22
	stand.mesh = stand_mesh
	stand.position = Vector3(0, 0.13, 0)
	stand.material_override = base.material_override
	root.add_child(stand)

	var bezel := MeshInstance3D.new()
	var bezel_mesh := BoxMesh.new()
	bezel_mesh.size = Vector3(0.66, 0.44, 0.05)
	bezel.mesh = bezel_mesh
	bezel.position = Vector3(0, 0.44, 0)
	bezel.material_override = base.material_override
	root.add_child(bezel)

	# Screen face: slightly in front of the bezel, emissive display content.
	var screens: Array[Color] = [
		Color(0.75, 0.85, 1.0),   # spreadsheet blue-white
		Color(1.0, 0.93, 0.78),   # warm document
		Color(0.16, 0.19, 0.26),  # standby dark
	]
	var energies: Array[float] = [0.85, 0.8, 0.15]
	var idx := clampi(screen_variant, 0, 2)
	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.6, 0.38, 0.055)
	screen.mesh = screen_mesh
	screen.position = Vector3(0, 0.44, 0.001)
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = screens[idx]
	screen_mat.emission_enabled = true
	screen_mat.emission = screens[idx]
	screen_mat.emission_energy_multiplier = energies[idx]
	screen.material_override = screen_mat
	root.add_child(screen)
	return root


## Keyboard + mug + paper stack: tiny desk props (no collision).
static func desk_clutter(accent: Color) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []

	var keyboard := MeshInstance3D.new()
	var kb_mesh := BoxMesh.new()
	kb_mesh.size = Vector3(0.46, 0.035, 0.17)
	keyboard.mesh = kb_mesh
	keyboard.name = "Keyboard"
	keyboard.material_override = _mat("prop_kb", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.14, 0.14, 0.17)
		m.roughness = 0.55
		return m)
	out.append(keyboard)

	var mug := MeshInstance3D.new()
	var mug_mesh := CylinderMesh.new()
	mug_mesh.top_radius = 0.055
	mug_mesh.bottom_radius = 0.045
	mug_mesh.height = 0.12
	mug.mesh = mug_mesh
	mug.name = "Mug"
	var mug_mat := StandardMaterial3D.new()
	mug_mat.albedo_color = accent
	mug_mat.roughness = 0.35
	mug.material_override = mug_mat
	out.append(mug)

	var paper := MeshInstance3D.new()
	var paper_mesh := BoxMesh.new()
	paper_mesh.size = Vector3(0.3, 0.012, 0.42)
	paper.mesh = paper_mesh
	paper.name = "Papers"
	var paper_mat := _mat("prop_paper", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.92, 0.88)
		m.roughness = 0.9
		return m)
	paper.material_override = paper_mat
	out.append(paper)
	return out


## Full desk dressing: monitor + clutter placed on the desk-top surface.
## desk_top_y is LOCAL to the desk body. Deterministic per desk instance.
static func desk_dressing(desk: StaticBody3D, desk_top_y: float) -> void:
	var seed_int := int(absi(desk.get_instance_id()) % 97)
	var mon := monitor(seed_int % 3)
	mon.position = Vector3(-0.45 + float(seed_int % 5) * 0.05, desk_top_y, -0.12)
	mon.rotation.y = -0.5 + float(seed_int % 7) * 0.15
	desk.add_child(mon)

	var clutter := desk_clutter(Color(1.0, 0.6, 0.1))
	var kb: MeshInstance3D = clutter[0]
	kb.position = Vector3(-0.4 + float(seed_int % 3) * 0.06, desk_top_y + 0.02, 0.22)
	kb.rotation.y = mon.rotation.y + 0.1
	desk.add_child(kb)
	var mug: MeshInstance3D = clutter[1]
	mug.position = Vector3(0.45 + float(seed_int % 3) * 0.05, desk_top_y + 0.07, 0.1)
	desk.add_child(mug)
	var papers: MeshInstance3D = clutter[2]
	papers.position = Vector3(0.55, desk_top_y + 0.01, -0.2)
	papers.rotation.y = float(seed_int % 11) * 0.3
	desk.add_child(papers)
