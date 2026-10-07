# SabotageTrap.gd — Water puddle / banana peel that stuns players
extends Area3D

@export var stun_duration: float = 1.5
@export var lifetime: float = 12.0

var age: float = 0.0
var trap_type: String = "water"  # "water", "banana", "stapler", "spill"
var triggered := false
var owner_id: int = 0  # instance id of the player who placed this trap
var forced_type: String = ""  # set before add_child to skip random selection
var world_spawned: bool = false  # true = deterministic arena trap, not player-dropped

## Colorblind shape cues (Phase 8B, FINAL-day upgrade): every trap gets a
## short-word Label3D + a floating procedural SHAPE icon so the type never
## rides on color alone — banana and spill are BOTH yellow, so their icons
## differ in GEOMETRY (arc curve vs filled disc), not tint. Icons use
## PrimitiveMesh/ArrayMesh silhouettes (waves / arc / L-block / puddle disc);
## face counts differ per type and TrapAccessibilitySmokeTest pins that.
## Colors come from UITheme tokens only (HUD pattern) — no local literals.
const TYPE_NAMES := {
	"water": "WATER",
	"banana": "BANANA",
	"stapler": "STAPLER",
	"spill": "SPILL",
}

var _uit  # UITheme.gd, lazy-loaded (label/icon tints — HUD.gd pattern)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Randomly assign type unless a forced type was requested (spill item)
	if forced_type != "":
		trap_type = forced_type
	else:
		var types = ["water", "banana", "stapler"]
		trap_type = types.pick_random()
	_apply_visual()

## Test/creator seam: pin the trap type before the node enters the tree.
func _set_forced_type(kind: String) -> void:
	forced_type = kind
	if trap_type != kind and not is_inside_tree():
		trap_type = kind
		_apply_visual()

## Phase 5: report this player-dropped trap to other peers (no-op offline).
func report_drop() -> void:
	if world_spawned or not is_inside_tree():
		return
	var network = get_node_or_null("/root/Network")
	if network and network.has_method("report_trap_drop"):
		var sender_id := owner_id
		network.report_trap_drop(global_position, trap_type, forced_type != "")

func _apply_visual() -> void:
	var mat = StandardMaterial3D.new()
	match trap_type:
		"water":
			mat.albedo_color = Color(0.3, 0.6, 1.0, 0.7)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"banana":
			mat.albedo_color = Color(1.0, 0.9, 0.2)
		"stapler":
			mat.albedo_color = Color(0.8, 0.8, 0.85)
		"spill":
			mat.albedo_color = Color(0.95, 0.85, 0.1, 0.75)
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.65, 0.05)
			mat.emission_energy_multiplier = 0.5
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_:
			mat.albedo_color = Color(1, 0, 1)
	
	var mesh_node = get_node_or_null("Mesh")
	if mesh_node:
		mesh_node.material_override = mat
	# Spill item drops a wide puddle (roadmap: 3x3 stun zone)
	if trap_type == "spill":
		if mesh_node:
			mesh_node.scale = Vector3(1.6, 1.0, 1.6)
		var col_node = get_node_or_null("CollisionShape3D")
		if col_node:
			# Swap in a bigger shape rather than scaling the node (physics-safe)
			var wide := CylinderShape3D.new()
			wide.radius = 1.6
			wide.height = 0.2
			col_node.shape = wide
	_build_shape_cue()

## Shape cue: short-word name label + silhouette icon floating above the
## trap. Both ship unconditionally (colorblind support = legible for
## everyone). The icon billboards to the camera in _process so its PRIMARY
## SILHOUETTE — waves / banana arc / L-block / puddle disc — reads at
## driving speed from any approach. Idempotent — _apply_visual may run
## twice (forced type pre-tree, then _ready).
func _build_shape_cue() -> void:
	if _uit == null:
		_uit = load("res://scripts/UITheme.gd")
	for old in get_children():
		if old is Label3D or old.name == &"ShapeIcon":
			# Deterministic cleanup (remove+free, not queue_free): tests read
			# children same-frame, and _apply_visual can run twice pre-tree.
			remove_child(old)
			old.free()
	# Name label — short UITheme word, ~0.6m cap height (readable at speed).
	var label := Label3D.new()
	label.text = String(TYPE_NAMES.get(trap_type, trap_type.to_upper()))
	label.font_size = 48
	label.pixel_size = 0.012
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = _c(_uit.TEXT, 0.95)
	label.outline_modulate = _c(_uit.BG, 0.9)
	label.no_depth_test = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.position = Vector3(0, 1.45, 0)
	add_child(label)
	# Shape icon (glance-distance silhouette read).
	var icon := MeshInstance3D.new()
	icon.name = &"ShapeIcon"
	icon.mesh = _build_icon_mesh()
	icon.position = Vector3(0, 0.85, 0)
	# Thin floating geometry paints light stripes — never cast (NEXT-SLICE
	# traps list). No collision here: pure MeshInstance3D dressing.
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var imat := StandardMaterial3D.new()
	imat.albedo_color = _type_tint()
	imat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	imat.cull_mode = BaseMaterial3D.CULL_DISABLED
	icon.material_override = imat
	add_child(icon)

## HUD.gd pattern: callers pass the UITheme token CONSTANT (its hex string,
## e.g. _uit.TEXT) — color() does Color(hex), which cannot parse token NAMES.
func _c(hex: String, alpha: float = 1.0) -> Color:
	if _uit:
		return _uit.color(hex, alpha)
	return Color.WHITE if alpha >= 0.5 else Color.BLACK

func _type_tint() -> Color:
	# UITheme tokens only; tint is a redundant cue — silhouette is the real one.
	match trap_type:
		"water":
			return _c(_uit.CYAN)
		"banana":
			return _c(_uit.YELLOW)
		"stapler":
			return _c(_uit.PAPER)
		"spill":
			return _c(_uit.ORANGE)
	return _c(_uit.TEXT)

## Icon mesh per trap type. Every builder yields a DISTINCT primary
## silhouette AND a distinct face count (get_faces().size() signature pinned
## by TrapAccessibilitySmokeTest — shape-tellable, squint-proof):
##   water = two wavy ribbons, banana = crescent arc, stapler = L-block,
##   spill = flat puddle disc (CylinderMesh — also a different mesh class).
func _build_icon_mesh() -> Mesh:
	match trap_type:
		"banana":
			return _arc_mesh()
		"stapler":
			return _lblock_mesh()
		"spill":
			var disc := CylinderMesh.new()
			disc.top_radius = 0.34
			disc.bottom_radius = 0.42
			disc.height = 0.05
			disc.radial_segments = 16
			disc.rings = 0
			return disc
		_:
			return _waves_mesh()  # water (and unknown-type fallback)

func _waves_mesh() -> Mesh:
	# Two stacked sine ribbons (the "≈" water read).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line_y: float in [0.16, -0.16]:
		var segs := 12
		for i in segs:
			var x0 := -0.45 + 0.9 * float(i) / float(segs)
			var x1 := -0.45 + 0.9 * float(i + 1) / float(segs)
			var y0a: float = line_y + 0.1 * sin(x0 * 7.0)
			var y0b := y0a - 0.055
			var y1a: float = line_y + 0.1 * sin(x1 * 7.0)
			var y1b := y1a - 0.055
			_quad(st, Vector3(x0, y0a, 0), Vector3(x1, y1a, 0),
				Vector3(x1, y1b, 0), Vector3(x0, y0b, 0))
	return _finish_icon_mesh(st)

func _arc_mesh() -> Mesh:
	# Banana: crescent ribbon along a lower arc (smile), opening upward.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 12
	var r0 := 0.24
	var r1 := 0.46
	for i in segs:
		var a0 := PI + PI * float(i) / float(segs)
		var a1 := PI + PI * float(i + 1) / float(segs)
		_quad(st,
			Vector3(cos(a0) * r1, sin(a0) * r1 + 0.14, 0),
			Vector3(cos(a1) * r1, sin(a1) * r1 + 0.14, 0),
			Vector3(cos(a1) * r0, sin(a1) * r0 + 0.14, 0),
			Vector3(cos(a0) * r0, sin(a0) * r0 + 0.14, 0))
	return _finish_icon_mesh(st)

func _lblock_mesh() -> Mesh:
	# Stapler: chunky L-block (two rectangles sharing an edge — no overlap,
	# so no coplanar z-fighting).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, Vector3(-0.16, 0.44, 0), Vector3(0.14, 0.44, 0),
		Vector3(0.14, -0.42, 0), Vector3(-0.16, -0.42, 0))  # stem
	_quad(st, Vector3(0.14, -0.10, 0), Vector3(0.46, -0.10, 0),
		Vector3(0.46, -0.42, 0), Vector3(0.14, -0.42, 0))   # foot
	return _finish_icon_mesh(st)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := Vector3(0, 0, 1)
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)

func _finish_icon_mesh(st: SurfaceTool) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh

func _on_body_entered(body: Node3D) -> void:
	if triggered or not body.is_in_group("players"):
		return
	triggered = true
	if body.has_method("stun"):
		body.stun(stun_duration)
		var stats = get_node_or_null("/root/StatsManager")
		if stats and int(owner_id) != int(body.get_instance_id()):
			stats.record_trap_landed()
		var fx = load("res://scripts/ImpactFX.gd")
		if fx:
			var burst_color = Color("70b7ff") if trap_type == "water" else (Color("ffcf55") if trap_type in ["banana", "spill"] else Color("dce6ff"))
			fx.burst(get_parent(), global_position + Vector3.UP * 0.2, burst_color, 24)
		var audio = get_node_or_null("/root/AudioManager")
		if audio:
			audio.play_sfx("trap", 1.3)
		var a11y = load("res://scripts/Accessibility.gd")
		if a11y:
			a11y.caption("TRAP HIT: " + trap_type.to_upper(), 1.2)
		print("[TRAP] %s hit %s trap!" % [body.player_display_name if "player_display_name" in body else "Player", trap_type])
		queue_free()

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	# Icon billboard: keep the silhouette square to the camera (cheap —
	# traps never exceed DOUBLE_TRAPS count; skipped when no camera, e.g.
	# headless tests / CheckpointBot paths, so bot timing is untouched).
	var icon := get_node_or_null("ShapeIcon") as Node3D
	if icon:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var dir := cam.global_position - icon.global_position
			if dir.length_squared() > 0.0001:
				# look_at errors when the view direction is colinear with the
				# up vector (chase cam passes straight over a trap spot) —
				# swap to a horizontal-safe up for that frame only.
				if absf(dir.normalized().y) > 0.999:
					icon.look_at(cam.global_position, Vector3(0, 0, 1))
				else:
					icon.look_at(cam.global_position)
				if trap_type == "spill":
					# CylinderMesh's faces are on +/-Y; after look_at that lies
					# IN the view plane (disc reads edge-on as a sliver). A
					# quarter-turn about local X puts the puddle FACE to the
					# camera so the silhouette reads as the filled disc.
					icon.rotate_object_local(Vector3.RIGHT, PI / 2.0)
