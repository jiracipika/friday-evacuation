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
#   - whiteboard(): freestanding marker board (conference/menu dressing)
#   - cable_tray(): hung ceiling cable run (floors 2/4 dressing parity)
#   - desk_plant(): tiny desktop plant for monitor desks
#   - elevator_portal(): door frame + metal doors + EXIT sign behind each pad
#   - exit_sign(): green emissive EXIT signage box
#
# Everything is procedural (no assets), static-cached where shared, and
# mobile-friendly (<=9 tiny meshes per prop, shared materials; PropMaterials
# textured surfaces where they earn their keep). New dressing casts NO
# real-time shadows — GL Compatibility blob discs are the shadow language.
class_name OfficeDressing
extends RefCounted

# Shared material cache: key -> material. Instance-safe because materials
# hold ImageTextures that live for the whole session (no per-scene freeing).
static var _mats: Dictionary = {}

# Beveled-box mesh cache: "w,h,h,bevel" -> ArrayMesh. One mesh per distinct
# dimensions so repeated monitors/plaques share a single resource.
static var _bevel_meshes: Dictionary = {}

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
	_bevel_meshes.clear()


# ---------------------------------------------------------------- geometry --

## Reusable low-poly chamfered box (flat-shaded) built as an ArrayMesh.
## Cheap cached silhouette upgrade over raw BoxMesh for hero props: broad
## planar faces + 12 chamfer strips read as chunky toy plastic, no textures.
## One shared mesh per (dimensions, bevel) pair — no per-frame work.
static func beveled_box(extents: Vector3, bevel := 0.016) -> ArrayMesh:
	var key := "%.4f,%.4f,%.4f,%.4f" % [extents.x, extents.y, extents.z, bevel]
	if _bevel_meshes.has(key):
		return _bevel_meshes[key] as ArrayMesh
	var half := extents * 0.5
	var b := clampf(bevel, 0.001, minf(half.x, minf(half.y, half.z)) * 0.9)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 6 broad faces, each inset by the bevel along its two tangent axes.
	for f in [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.DOWN],
	]:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var fn := n.abs().dot(half)
		var fu := u.abs().dot(half) - b
		var fv := v.abs().dot(half) - b
		_add_quad(st,
			n * fn + u * fu + v * fv,
			n * fn + u * fu - v * fv,
			n * fn - u * fu - v * fv,
			n * fn - u * fu + v * fv,
			n)
	# 12 chamfer strips exactly bridging adjacent broad-face edges.
	for pair in [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	]:
		var a1: Vector3 = pair[0]
		var a2: Vector3 = pair[1]
		var run: Vector3 = pair[2]
		var h1 := a1.abs().dot(half)
		var h2 := a2.abs().dot(half)
		var hr := run.abs().dot(half)
		for s1: float in [-1.0, 1.0]:
			for s2: float in [-1.0, 1.0]:
				var d1: Vector3 = a1 * s1
				var d2: Vector3 = a2 * s2
				var nrm: Vector3 = (d1 + d2).normalized()
				var pa0: Vector3 = d1 * h1 + d2 * (h2 - b) - run * (hr - b)
				var pa1: Vector3 = d1 * h1 + d2 * (h2 - b) + run * (hr - b)
				var pb0: Vector3 = d1 * (h1 - b) + d2 * h2 - run * (hr - b)
				var pb1: Vector3 = d1 * (h1 - b) + d2 * h2 + run * (hr - b)
				_add_quad(st, pa0, pa1, pb1, pb0, nrm)
	var mesh := st.commit()
	_bevel_meshes[key] = mesh
	return mesh


## Flat planar quad with duplicated vertices (hard edges). Winding is
## corrected against the intended outward normal, so callers can list the
## four corners in any consistent loop order.
static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3,
		p3: Vector3, n: Vector3) -> void:
	if (p2 - p0).cross(p3 - p0).dot(n) < 0.0:
		var tmp := p1
		p1 = p3
		p3 = tmp
	for p in [p0, p1, p2, p0, p2, p3]:
		st.set_normal(n)
		st.add_vertex(p)


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

	# Corporate Emergency plaque on the header front (+Z, same face as the
	# seam strips): orange beveled backing + bone 'LIFT / NEXT FLOOR' text.
	# No digits — never states a destination floor number.
	var plaque := MeshInstance3D.new()
	plaque.name = "Plaque"
	plaque.mesh = beveled_box(Vector3(3.4, 0.26, 0.1), 0.018)
	plaque.position = Vector3(0.0, 3.15, 0.20)
	var plaque_mat := _mat("portal_plaque", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.34, 0.08)
		m.roughness = 0.55
		m.metallic = 0.0
		return m)
	plaque.material_override = plaque_mat
	portal.add_child(plaque)

	var plaque_label := Label3D.new()
	plaque_label.name = "PlaqueLabel"
	plaque_label.text = "LIFT / NEXT FLOOR"
	plaque_label.font_size = 96
	plaque_label.pixel_size = 0.0016
	plaque_label.modulate = Color(0.96, 0.93, 0.85)
	plaque_label.outline_size = 0
	plaque_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plaque_label.no_depth_test = false
	plaque_label.double_sided = false
	plaque_label.position = Vector3(0.0, 3.15, 0.26)
	portal.add_child(plaque_label)

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


# ------------------------------------------------------- conference props --

## Flat cached color material (scribbles, pen trays, cables, foliage...).
static func _flat_mat(key: String, color: Color, rough: float) -> StandardMaterial3D:
	return _mat(key, func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		return m)


## PropMaterials bridge with a flat-color fallback so the dressing builders
## stay boot-safe on any checkout (same defensive pattern as Evacuation).
static func _prop_mat(kind: String, tint: Color) -> StandardMaterial3D:
	var PropMats: GDScript = load("res://scripts/PropMaterials.gd")
	if PropMats:
		if kind == "metal" and PropMats.has_method("brushed_metal"):
			return PropMats.brushed_metal()
		if kind == "plastic" and PropMats.has_method("plastic"):
			return PropMats.plastic(tint)
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.55 if kind == "plastic" else 0.35
	if kind == "metal":
		m.metallic = 0.8
	return m


## Freestanding mobile whiteboard: brushed-metal frame on two legs, off-white
## melamine board, flat marker-stroke bars and a pen tray. Faces +Z.
## variant 0 "sprint board", 1 "agenda list", 2 "TODAY'S MENU" (Label3D).
## Non-colliding dressing; every mesh casts NO shadow (tall thin panel — the
## tilted key light would stripe the floor, repo law).
static func whiteboard(variant: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Whiteboard"
	var v := clampi(variant, 0, 2)
	var metal := _prop_mat("metal", Color(0.6, 0.64, 0.68))
	var board_mat := _flat_mat("board_surface", Color(0.93, 0.94, 0.92), 0.22)
	var tray_mat := _prop_mat("plastic", Color(0.24, 0.26, 0.3))

	var leg_sides := {"Leg_L": -1.0, "Leg_R": 1.0}
	for leg_name in leg_sides:
		var leg := MeshInstance3D.new()
		leg.name = leg_name
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.06, 1.72, 0.06)
		leg.mesh = leg_mesh
		leg.position = Vector3(leg_sides[leg_name] * 0.62, 0.86, -0.05)
		leg.material_override = metal
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(leg)

	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = beveled_box(Vector3(1.76, 1.28, 0.055), 0.014)
	frame.position = Vector3(0, 1.32, 0)
	frame.material_override = metal
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(frame)

	var board := MeshInstance3D.new()
	board.name = "Board"
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.64, 1.16, 0.02)
	board.mesh = board_mesh
	board.position = Vector3(0, 1.32, 0.02)
	board.material_override = board_mat
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(board)

	var tray := MeshInstance3D.new()
	tray.name = "PenTray"
	var tray_mesh := BoxMesh.new()
	tray_mesh.size = Vector3(1.5, 0.045, 0.1)
	tray.mesh = tray_mesh
	tray.position = Vector3(0, 0.66, 0.085)
	tray.material_override = tray_mat
	tray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tray)

	# Marker strokes: broad soft bars only — flat tints, no emission, no
	# high-frequency texture (moiré law). One cached material per color.
	var layouts := [
		# sprint board: three row bars + orange underline accent
		[Vector3(-0.18, 1.62, 0.90), Vector3(0.0, 1.44, 1.10),
			Vector3(0.10, 1.26, 0.70), Vector3(-0.05, 1.02, 1.25)],
		# agenda: short left-aligned lines, one red "overdue"
		[Vector3(-0.42, 1.66, 0.62), Vector3(-0.42, 1.50, 0.52),
			Vector3(-0.42, 1.34, 0.58), Vector3(-0.42, 1.18, 0.40)],
		# menu board: three centered warm rows under the Label3D header
		[Vector3(0.0, 1.48, 0.95), Vector3(0.05, 1.28, 0.75),
			Vector3(-0.05, 1.08, 0.85)],
	]
	var palettes := [
		["marker_blue", "marker_red", "marker_green", "marker_amber"],
		["marker_navy", "marker_navy", "marker_navy", "marker_red"],
		["marker_amber", "marker_amber", "marker_blue"],
	]
	var palette_colors := {
		"marker_blue": Color(0.16, 0.45, 0.85),
		"marker_red": Color(0.85, 0.25, 0.2),
		"marker_green": Color(0.15, 0.6, 0.3),
		"marker_amber": Color(0.9, 0.55, 0.1),
		"marker_navy": Color(0.2, 0.3, 0.6),
	}
	var bars: Array = layouts[v]
	var names: Array = palettes[v]
	for i in bars.size():
		var spec: Vector3 = bars[i]
		var stroke := MeshInstance3D.new()
		stroke.name = "Stroke%d" % i
		var stroke_mesh := BoxMesh.new()
		stroke_mesh.size = Vector3(spec.z, 0.035, 0.008)
		stroke.mesh = stroke_mesh
		stroke.position = Vector3(spec.x, spec.y, 0.036)
		var cname: String = names[i]
		stroke.material_override = _flat_mat(cname, palette_colors[cname], 0.6)
		stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(stroke)

	if v == 2:
		var header := Label3D.new()
		header.name = "MenuHeader"
		header.text = "TODAY'S MENU"
		header.font_size = 44
		header.pixel_size = 0.0032
		header.modulate = Color(0.2, 0.25, 0.33)
		header.outline_size = 0
		header.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		header.no_depth_test = false
		header.position = Vector3(0, 1.74, 0.033)
		root.add_child(header)
	return root


## Hung ceiling cable tray: perforated base + side rails + cable bundles and
## two drop rods (caller places the root so the rods meet the ceiling slab).
## THIN CEILING GEOMETRY — every mesh casts NO shadow (long-stripe law).
static func cable_tray(length: float) -> Node3D:
	var root := Node3D.new()
	root.name = "CableTray"
	var l := clampf(length, 4.0, 40.0)
	var metal := _prop_mat("metal", Color(0.6, 0.64, 0.68))
	var cable_a := _flat_mat("cable_dark", Color(0.13, 0.13, 0.15), 0.7)
	var cable_b := _flat_mat("cable_blue", Color(0.2, 0.3, 0.5), 0.65)

	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(l, 0.045, 0.4)
	base.mesh = base_mesh
	base.material_override = metal
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(base)

	var rail_sides := {"Rail_L": -1.0, "Rail_R": 1.0}
	for rail_name in rail_sides:
		var rail := MeshInstance3D.new()
		rail.name = rail_name
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(l, 0.1, 0.028)
		rail.mesh = rail_mesh
		rail.position = Vector3(0, 0.065, rail_sides[rail_name] * 0.186)
		rail.material_override = metal
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(rail)

	# Cable bundles laid in the tray (slightly varied z so the silhouette
	# never reads as one perfect bar). Two materials, both cached.
	var cable_z := [-0.1, 0.02, 0.12]
	for i in cable_z.size():
		var cable := MeshInstance3D.new()
		cable.name = "Cable%d" % i
		var cable_mesh := BoxMesh.new()
		cable_mesh.size = Vector3(l * 0.985, 0.04, 0.05)
		cable.mesh = cable_mesh
		cable.position = Vector3(0.015 * i, 0.035, cable_z[i])
		cable.material_override = cable_b if i == 1 else cable_a
		cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(cable)

	var rod_sides := {"DropRod_L": -1.0, "DropRod_R": 1.0}
	for rod_name in rod_sides:
		var rod := MeshInstance3D.new()
		rod.name = rod_name
		var rod_mesh := CylinderMesh.new()
		rod_mesh.top_radius = 0.024
		rod_mesh.bottom_radius = 0.024
		rod_mesh.height = 0.32
		rod_mesh.radial_segments = 6
		rod.mesh = rod_mesh
		rod.position = Vector3(rod_sides[rod_name] * (l * 0.5 - 0.9), 0.3, 0)
		rod.material_override = metal
		rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(rod)
	return root


# ------------------------------------------------------------- desk props --

## A toy-like retro office monitor on a sturdy stand: beveled cream/mint
## shell casing, dark inset bezel + screen with minimal document rows on lit
## variants. Non-colliding dressing only. screen_variant 0..2 picks display.
static func monitor(screen_variant: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Monitor"

	var shell_mat := _mat("monitor_shell_cream", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.82, 0.72)   # cream plastic
		m.roughness = 0.6
		m.metallic = 0.0
		return m)
	var inset_mat := _mat("monitor_inset_dark", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.09, 0.09, 0.11)
		m.roughness = 0.5
		m.metallic = 0.1
		return m)

	# Short sturdy stand: wide oval-ish base + chunky column, shell material.
	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.10
	base_mesh.bottom_radius = 0.10
	base_mesh.height = 0.03
	base_mesh.radial_segments = 12
	base.mesh = base_mesh
	base.position = Vector3(0, 0.015, 0)
	base.material_override = shell_mat
	root.add_child(base)

	var stand := MeshInstance3D.new()
	stand.name = "Stand"
	var stand_mesh := CylinderMesh.new()
	stand_mesh.top_radius = 0.045
	stand_mesh.bottom_radius = 0.055
	stand_mesh.height = 0.16
	stand_mesh.radial_segments = 12
	stand.mesh = stand_mesh
	stand.position = Vector3(0, 0.11, 0)
	stand.material_override = shell_mat
	root.add_child(stand)

	# Beveled shell casing: broad flat faces, chamfered toy silhouette.
	# Stays inside the old bezel footprint (0.66 x 0.44 x 0.05).
	var casing := MeshInstance3D.new()
	casing.name = "Casing"
	casing.mesh = beveled_box(Vector3(0.66, 0.42, 0.042), 0.016)
	casing.position = Vector3(0, 0.42, 0)
	casing.material_override = shell_mat
	root.add_child(casing)

	# Dark inset bezel plate, recessed behind the shell front rim.
	var bezel := MeshInstance3D.new()
	bezel.name = "Bezel"
	var bezel_mesh := BoxMesh.new()
	bezel_mesh.size = Vector3(0.54, 0.32, 0.02)
	bezel.mesh = bezel_mesh
	bezel.position = Vector3(0, 0.42, 0.017)
	bezel.material_override = inset_mat
	root.add_child(bezel)

	# Emissive screen inside the bezel inset.
	var screens: Array[Color] = [
		Color(0.75, 0.85, 1.0),   # spreadsheet blue-white
		Color(1.0, 0.93, 0.78),   # warm document
		Color(0.16, 0.19, 0.26),  # standby dark
	]
	var energies: Array[float] = [0.85, 0.8, 0.15]
	var idx := clampi(screen_variant, 0, 2)
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.5, 0.28, 0.02)
	screen.mesh = screen_mesh
	screen.position = Vector3(0, 0.42, 0.028)
	var screen_mat: StandardMaterial3D = _mat("monitor_screen_%d" % idx, func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = screens[idx]
		m.emission_enabled = true
		m.emission = screens[idx]
		m.emission_energy_multiplier = energies[idx]
		return m)
	screen.material_override = screen_mat
	root.add_child(screen)

	# Minimal document rows on lit variants only: 3 soft bars, no busy
	# pixel-frequency patterns. Plain slightly-dark tints over the glow.
	if idx < 2:
		for i in 3:
			var row := MeshInstance3D.new()
			row.name = "DocRow%d" % i
			var row_mesh := BoxMesh.new()
			row_mesh.size = Vector3(0.30 - i * 0.06, 0.03, 0.006)
			row.mesh = row_mesh
			row.position = Vector3(-0.04 + i * 0.02, 0.475 - i * 0.055, 0.0385)
			row.material_override = inset_mat
			root.add_child(row)
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


## Tiny desktop plant: terracotta pot + two foliage blobs (3 meshes, shared
## materials, no collision, no shadow casting). Sits ON the desk surface.
static func desk_plant() -> Node3D:
	var root := Node3D.new()
	root.name = "DeskPlant"
	var pot := MeshInstance3D.new()
	pot.name = "Pot"
	var pot_mesh := CylinderMesh.new()
	pot_mesh.top_radius = 0.062
	pot_mesh.bottom_radius = 0.046
	pot_mesh.height = 0.115
	pot_mesh.radial_segments = 10
	pot.mesh = pot_mesh
	pot.position = Vector3(0, 0.0575, 0)
	pot.material_override = _prop_mat("plastic", Color(0.62, 0.36, 0.24))
	pot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pot)
	var leaf_specs := [
		{"pos": Vector3(-0.015, 0.19, 0.0), "r": 0.075, "key": "leaf_dark"},
		{"pos": Vector3(0.03, 0.27, 0.01), "r": 0.055, "key": "leaf_lite"},
	]
	var leaf_colors := {
		"leaf_dark": Color(0.18, 0.42, 0.22),
		"leaf_lite": Color(0.24, 0.5, 0.27),
	}
	for i in leaf_specs.size():
		var spec: Dictionary = leaf_specs[i]
		var blob := MeshInstance3D.new()
		blob.name = "Foliage%d" % i
		var sphere := SphereMesh.new()
		sphere.radius = spec["r"]
		sphere.height = (spec["r"] as float) * 2.0
		sphere.radial_segments = 10
		sphere.rings = 6
		blob.mesh = sphere
		blob.position = spec["pos"]
		var ckey: String = spec["key"]
		blob.material_override = _flat_mat(ckey, leaf_colors[ckey], 0.9)
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(blob)
	return root


## Full desk dressing: monitor + clutter placed on the desk-top surface.
## desk_top_y is LOCAL to the desk body. Deterministic per desk instance.
static var dressing_count := 0

static func desk_dressing(desk: StaticBody3D, desk_top_y: float) -> void:
	var seed_int := int(absi(desk.get_instance_id()) % 97)
	# Dusk + toybox: roughly one desk in three carries the Blender printer
	# instead of a monitor — desk variety without new collision or cost.
	# Instance ids cluster on small modulos and desk.position is not yet set
	# here (callers position after _make_desk) — rotate by creation order,
	# which is deterministic and identical on every LAN peer.
	dressing_count += 1
	var variety: int = dressing_count % 3
	if variety == 0:
		var BlenderProps: GDScript = load("res://scripts/BlenderProps.gd")
		if BlenderProps and BlenderProps.spawn(desk, BlenderProps.desk_printer(), Vector3(0, desk_top_y, -0.05), -0.4 + float(seed_int % 5) * 0.15) != null:
			var clutter0 := desk_clutter(Color(1.0, 0.6, 0.1))
			var mug0: MeshInstance3D = clutter0[1]
			mug0.position = Vector3(0.62, desk_top_y + 0.07, 0.1)
			desk.add_child(mug0)
			return
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

	# Desk-plant variety: every second monitor desk gets a tiny plant in the
	# back-left corner of the 2x1 desktop — clear of the monitor base,
	# keyboard, mug and papers footprints (still non-colliding dressing).
	if variety == 1:
		var plant := desk_plant()
		plant.position = Vector3(-0.72, desk_top_y, -0.3)
		plant.rotation.y = float(seed_int % 7) * 0.45
		desk.add_child(plant)
