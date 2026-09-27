# PowerUpVisual.gd — Phase 4B pickup with six kinds.
# Self-contained: builds its own mesh/glow/ring/label, handles pickup
# detection, sound, burst FX, and applies its effect in _on_body_entered.
# Modes only position and add_child it (and may pin `kind` before adding).
extends Area3D

enum Kind { COFFEE, ENERGY_DRINK, STAPLER, SPILL, PRINTER, EXTINGUISHER }

## Weighted spawn distribution (roadmap 4B): 60/15/10/8/4/3.
const WEIGHTS := {
	Kind.COFFEE: 60,
	Kind.ENERGY_DRINK: 15,
	Kind.STAPLER: 10,
	Kind.SPILL: 8,
	Kind.PRINTER: 4,
	Kind.EXTINGUISHER: 3,
}

const KIND_NAMES := {
	Kind.COFFEE: "COFFEE",
	Kind.ENERGY_DRINK: "ENERGY DRINK",
	Kind.STAPLER: "STAPLER ×3",
	Kind.SPILL: "SPILL ×2",
	Kind.PRINTER: "PRINTER",
	Kind.EXTINGUISHER: "EXTINGUISHER",
}

const KIND_COLORS := {
	Kind.COFFEE: Color(1.0, 0.55, 0.08),
	Kind.ENERGY_DRINK: Color(0.3, 1.0, 0.45),
	Kind.STAPLER: Color(1.0, 0.3, 0.3),
	Kind.SPILL: Color(1.0, 0.85, 0.15),
	Kind.PRINTER: Color(0.35, 0.6, 1.0),
	Kind.EXTINGUISHER: Color(0.95, 0.95, 1.0),
}

const EXTINGUISHER_RADIUS := 8.0
const EXTINGUISHER_STUN := 2.0
const PRINTER_BLIND_RADIUS := 8.0

var kind: Kind = Kind.COFFEE
## Unique per-match name used for cross-peer despawn sync ("PU_3_5" style).
var sync_name: String = ""
var base_y: float = 0.0
var time_offset: float = 0.0
var glow_radius: float = 0.0
var glow_light: OmniLight3D
# PICKUP PROMPT: when a player is inside the trigger, show a floating
# "E — GRAB" key cap; collect on E (action) rather than touch. Touch
# devices grab by driving over (no keyboard — auto-collect for them).
var _prompt: Label3D
var _body_in_range: Node3D = null

static func pick_weighted(rng: RandomNumberGenerator) -> int:
	var total := 0
	for w in WEIGHTS.values():
		total += w
	var roll := rng.randi_range(1, total)
	for key in WEIGHTS:
		roll -= WEIGHTS[key]
		if roll <= 0:
			return key
	return Kind.COFFEE

func _ready() -> void:
	if sync_name.is_empty():
		sync_name = "PU_%d" % get_instance_id()
	base_y = position.y
	time_offset = float(get_instance_id() % 1000) * 0.01

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	col.shape = shape
	add_child(col)

	glow_light = OmniLight3D.new()
	glow_light.light_color = KIND_COLORS[kind]
	glow_light.light_energy = 0.8
	glow_light.omni_range = 3.5
	glow_light.shadow_enabled = false
	add_child(glow_light)

	_build_body()
	_build_ring()
	_build_label()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_exit_prompt_check)
	tree_exiting.connect(_hide_prompt)

## Factory: create a pickup of the given kind, ready to position and add_child.
static func create(kind_value: int) -> Area3D:
	var pu := Area3D.new()
	pu.set_script(load("res://scripts/PowerUpVisual.gd"))
	pu.kind = kind_value
	return pu

func _build_body() -> void:
	match kind:
		Kind.COFFEE:
			_build_coffee()
		Kind.ENERGY_DRINK:
			_build_energy_drink()
		Kind.STAPLER:
			_build_stapler()
		Kind.SPILL:
			_build_spill()
		Kind.PRINTER:
			_build_printer()
		Kind.EXTINGUISHER:
			_build_extinguisher()

func _glow_material(base: Color, emission: Color, energy := 1.2) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.roughness = 0.45
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat

func _add_mesh(mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot_x := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.rotation.x = rot_x
	node.material_override = mat
	add_child(node)
	return node

func _build_coffee() -> void:
	var cup_mat := _glow_material(Color(0.92, 0.52, 0.12), Color(1.0, 0.34, 0.04))
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.34
	cup_mesh.bottom_radius = 0.27
	cup_mesh.height = 0.52
	_add_mesh(cup_mesh, cup_mat, Vector3.ZERO)

	var coffee_mesh := CylinderMesh.new()
	coffee_mesh.top_radius = 0.27
	coffee_mesh.bottom_radius = 0.27
	coffee_mesh.height = 0.035
	var coffee_mat := StandardMaterial3D.new()
	coffee_mat.albedo_color = Color(0.12, 0.045, 0.015)
	coffee_mat.roughness = 0.3
	_add_mesh(coffee_mesh, coffee_mat, Vector3(0, 0.27, 0))

	var handle_mesh := TorusMesh.new()
	handle_mesh.inner_radius = 0.11
	handle_mesh.outer_radius = 0.18
	_add_mesh(handle_mesh, cup_mat, Vector3(0.34, 0, 0), PI / 2.0)

func _build_energy_drink() -> void:
	var can_mat := _glow_material(Color(0.2, 0.75, 0.35), Color(0.15, 1.0, 0.35), 1.4)
	var can_mesh := CylinderMesh.new()
	can_mesh.top_radius = 0.16
	can_mesh.bottom_radius = 0.16
	can_mesh.height = 0.8
	_add_mesh(can_mesh, can_mat, Vector3(0, 0.1, 0))

	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 0.16
	top_mesh.bottom_radius = 0.16
	top_mesh.height = 0.03
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.85, 0.9, 0.85)
	top_mat.metallic = 0.8
	_add_mesh(top_mesh, top_mat, Vector3(0, 0.52, 0))

func _build_stapler() -> void:
	var mat := _glow_material(Color(0.75, 0.2, 0.2), Color(1.0, 0.2, 0.2), 1.1)
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.25, 0.32)
	_add_mesh(box, mat, Vector3(0, 0.05, 0))

	var nose := BoxMesh.new()
	nose.size = Vector3(0.5, 0.1, 0.14)
	_add_mesh(nose, mat, Vector3(0, 0.16, 0.12))

func _build_spill() -> void:
	var mat := _glow_material(Color(0.95, 0.85, 0.1, 0.8), Color(0.85, 0.7, 0.05), 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var puddle := CylinderMesh.new()
	puddle.top_radius = 0.5
	puddle.bottom_radius = 0.55
	puddle.height = 0.07
	_add_mesh(puddle, mat, Vector3(0, -0.15, 0))

func _build_printer() -> void:
	var mat := _glow_material(Color(0.55, 0.62, 0.85), Color(0.25, 0.5, 1.0), 1.0)
	var body := BoxMesh.new()
	body.size = Vector3(0.7, 0.28, 0.5)
	_add_mesh(body, mat, Vector3(0, 0.05, 0))

	var tray := BoxMesh.new()
	tray.size = Vector3(0.55, 0.05, 0.35)
	var tray_mat := StandardMaterial3D.new()
	tray_mat.albedo_color = Color(0.9, 0.92, 0.95)
	_add_mesh(tray, tray_mat, Vector3(0, 0.22, 0))

func _build_extinguisher() -> void:
	var mat := _glow_material(Color(0.85, 0.15, 0.15), Color(1.0, 0.95, 0.9), 1.3)
	var tank := CylinderMesh.new()
	tank.top_radius = 0.18
	tank.bottom_radius = 0.18
	tank.height = 0.6
	_add_mesh(tank, mat, Vector3(0, 0.05, 0))

	var nozzle := BoxMesh.new()
	nozzle.size = Vector3(0.08, 0.22, 0.08)
	var nozzle_mat := StandardMaterial3D.new()
	nozzle_mat.albedo_color = Color(0.2, 0.2, 0.22)
	_add_mesh(nozzle, nozzle_mat, Vector3(0.12, 0.42, 0))

func _build_ring() -> void:
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.6
	ring_mesh.outer_radius = 0.65
	ring.mesh = ring_mesh
	ring.rotation.x = PI / 2.0
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = KIND_COLORS[kind]
	ring_mat.emission_enabled = true
	ring_mat.emission = KIND_COLORS[kind]
	ring_mat.emission_energy_multiplier = 0.6
	ring.material_override = ring_mat
	ring.position.y = -0.1
	add_child(ring)

func _build_label() -> void:
	# Colorblind-safe: name the pickup, never rely on color alone.
	var label := Label3D.new()
	label.text = KIND_NAMES[kind]
	label.font_size = 40
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = KIND_COLORS[kind]
	label.no_depth_test = true
	label.position = Vector3(0, 1.0, 0)
	add_child(label)
	_build_icon_sprite()

## Icon billboard: a chunky procedural glyph above the pickup (cup/can/
## stapler/droplet/printer/extinguisher silhouette on a rounded tile).
## Reads at race distance where the small 3D bodies blur into glow.
func _build_icon_sprite() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var accent: Color = KIND_COLORS[kind]
	for y in 64:
		for x in 64:
			# Rounded dark tile background (radius corners + border ring).
			var cx := absf(float(x) - 32.0)
			var cy := absf(float(y) - 32.0)
			var corner := maxf(cx - 24.0, cy - 24.0)
			if corner > 6.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var col := Color(0.06, 0.07, 0.10, 0.88)
			# Border ring in the kind's accent color.
			if corner > 4.0:
				col = Color(accent.r, accent.g, accent.b, 0.95)
			# Central glyph mask per kind.
			if _glyph_contains(kind, x, y):
				col = Color(accent.r, accent.g, accent.b, 1.0)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.02          # ~1.28m tall sign — readable far away
	sprite.no_depth_test = true
	sprite.render_priority = 10
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.position = Vector3(0, 1.55, 0)
	add_child(sprite)

## Silhouette masks for each pickup glyph (64x64 space).
func _glyph_contains(k: int, x: int, y: int) -> bool:
	match k:
		Kind.COFFEE:
			# Cup with handle: trapezoid body + arc.
			if x >= 20 and x <= 44 and y >= 22 and y <= 46:
				return true
			if x >= 24 and x <= 30 and y >= 16 and y <= 22:
				return true   # steam plume left
			if x >= 34 and x <= 40 and y >= 16 and y <= 22:
				return true   # steam plume right
			return false
		Kind.ENERGY_DRINK:
			# Can with lightning bolt cutout is overkill at 64px; use can
			# plus bolt notch.
			if x >= 26 and x <= 38 and y >= 18 and y <= 48:
				return not (x >= 31 and x <= 35 and y >= 26 and y <= 40 \
					and absi((x - 33) + ((y - 26) / 3)) < 4)
			return false
		Kind.STAPLER:
			# Open stapler V-shape.
			return (y >= 36 and y <= 42 and x >= 16 and x <= 48) \
				or (x >= int(16 + (y - 20) * 0.6) and x <= int(24 + (y - 20) * 0.6) \
					and y >= 20 and y <= 36)
		Kind.SPILL:
			# Droplet.
			var dx := float(x) - 32.0
			var dy := float(y) - 34.0
			return dy > 0.0 and (dx * dx) / 196.0 + (dy * dy) / 256.0 <= 1.0
		Kind.PRINTER:
			# Printer box with paper slot + sheet.
			if y >= 38 and y <= 50 and x >= 14 and x <= 50:
				return true
			if y >= 26 and y <= 37 and x >= 20 and x <= 44:
				return y <= 30 or x <= 24 or x >= 40   # sheet outline
			return false
		Kind.EXTINGUISHER:
			# Tank + nozzle arm.
			var edx := float(x) - 32.0
			var edy := float(y) - 36.0
			if (edx * edx) / 144.0 + (edy * edy) / 196.0 <= 1.0:
				return true
			return y >= 18 and y <= 24 and x >= 30 and x <= 52
		_:
			return false

func _process(delta: float) -> void:
	rotation.y += delta * 1.8
	position.y = base_y + sin(Time.get_ticks_msec() * 0.003 + time_offset) * 0.22

	glow_radius = (sin(Time.get_ticks_msec() * 0.004 + time_offset) * 0.5 + 0.5) * 0.4
	if glow_light:
		glow_light.omni_range = 3.0 + glow_radius
		glow_light.light_energy = 0.7 + glow_radius * 0.4

	# Key-press grab: while a player hovers, poll the action key. Uses the
	# same "action" binding as jump/grab (E / MMB / A / Cross). The prompt
	# already tells the player which key.
	if _body_in_range != null and is_instance_valid(_body_in_range):
		if Input.is_action_just_pressed("action"):
			_collect(_body_in_range)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("players"):
		return
	# PICKUP RULES: coffee is the core boost economy — walking over it
	# grabs it (reverting the feel-pass experiment; races were being lost
	# to fumble-fingering a cup). Ammo (stapler/spill) stays a deliberate
	# E/A grab so wasting a slot stays a choice. Touch players have no
	# spare key at all — auto-collect everything (thumbs are steering).
	var auto_kind: bool = kind == Kind.COFFEE
	var prefs = load("res://scripts/InputPrefs.gd")
	var touch_player := false
	if prefs and prefs.has_method("touch_enabled") and prefs.touch_enabled() \
			and prefs.which_scheme() != prefs.SCHEME_CONTROLLER:
		touch_player = true
	if touch_player or auto_kind:
		_collect(body)
	else:
		_body_in_range = body
		_show_prompt()

## E — GRAB (or A/Cross for pads, JUMP button on touch): floating key cap.
func _show_prompt() -> void:
	if _prompt:
		return
	_prompt = Label3D.new()
	_prompt.text = "E — GRAB  (A / JUMP)"
	_prompt.font_size = 52
	_prompt.outline_size = 14
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(1, 1, 1, 0.95)
	_prompt.outline_modulate = Color(0, 0, 0, 0.9)
	_prompt.no_depth_test = true
	_prompt.position = Vector3(0, 1.9, 0)
	add_child(_prompt)

func _hide_prompt() -> void:
	if _prompt:
		_prompt.queue_free()
		_prompt = null

func _exit_prompt_check(body: Node3D) -> void:
	if body == _body_in_range:
		_body_in_range = null
		_hide_prompt()

## Shared collect path (auto for touch, key-press for keyboard/pad).
func _collect(body: Node3D) -> void:
	_hide_prompt()
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx("powerup", 1.2)
	var a11y = load("res://scripts/Accessibility.gd")

	var fx = load("res://scripts/ImpactFX.gd")
	if fx:
		fx.burst(get_parent(), global_position + Vector3.UP * 0.2, KIND_COLORS[kind], 16)

	_report_pickup()

	match kind:
		Kind.COFFEE:
			if a11y:
				a11y.caption("COFFEE COLLECTED — BOOST READY", 1.2)
			if body.has_method("_start_boost"):
				body._start_boost()
		Kind.ENERGY_DRINK:
			if a11y:
				a11y.caption("ENERGY DRINK — SUPER BOOST!", 1.2)
			if body.has_method("_start_boost"):
				body._start_boost(1.5, 2.0)
		Kind.STAPLER:
			if body.has_method("give_item"):
				body.give_item(&"stapler", 3)
		Kind.SPILL:
			if body.has_method("give_item"):
				body.give_item(&"spill", 2)
		Kind.PRINTER:
			if a11y:
				a11y.caption("PRINTER JAM — PAPER EVERYWHERE", 1.4)
			_spawn_paper_planes()
			_blind_nearby(body)
		Kind.EXTINGUISHER:
			if a11y:
				a11y.caption("EXTINGUISHER — EVERYONE FREEZES", 1.4)
			_extinguish_nearby()
			_report_area_stuns([Kind.EXTINGUISHER, 2.0])
		_:
			pass

	queue_free()

func _spawn_paper_planes() -> void:
	# Cheap visual: six white slips flung outward, self-cleaning.
	for i in range(6):
		var slip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.02, 0.12)
		slip.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.96, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.85, 1.0)
		mat.emission_energy_multiplier = 0.7
		slip.material_override = mat
		get_parent().add_child(slip)
		slip.global_position = global_position + Vector3.UP * 0.3
		var angle := TAU * i / 6.0
		var dir := Vector3(cos(angle), 0.5, sin(angle)).normalized()
		var tween := slip.create_tween()
		tween.tween_property(slip, "global_position", slip.global_position + dir * 3.0, 0.8)
		tween.parallel().tween_property(slip, "rotation:y", angle * 3.0, 0.8)
		tween.tween_callback(slip.queue_free)

func _blind_nearby(collector: Node3D) -> void:
	# White screen flash for the local player when caught in the paper blast.
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var flash_allowed := true
	var a11y = load("res://scripts/Accessibility.gd")
	if a11y and not a11y.flash_effects_enabled():
		flash_allowed = false
	for node in tree.get_nodes_in_group("players"):
		if not (node and is_instance_valid(node)):
			continue
		if node.global_position.distance_to(global_position) > PRINTER_BLIND_RADIUS:
			continue
		if node != collector and node.has_method("stun"):
			node.stun(0.6)
		if node == collector:
			continue
		if flash_allowed and node.is_multiplayer_authority():
			_screen_flash(tree)
			if a11y:
				a11y.caption("BLINDED BY PAPER!", 1.0)

func _screen_flash(tree: SceneTree) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	tree.root.add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.95, 0.97, 1.0, 0.85)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tween := rect.create_tween()
	tween.tween_property(rect, "color:a", 0.0, 1.0)
	tween.tween_callback(layer.queue_free)

func _extinguish_nearby() -> void:
	# Freeze everyone within radius — including the collector if they stand
	# in the blast (roadmap intent: area denial you can misuse).
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var fx = load("res://scripts/ImpactFX.gd")
	for node in tree.get_nodes_in_group("players"):
		if not (node and is_instance_valid(node)):
			continue
		if node.global_position.distance_to(global_position) > EXTINGUISHER_RADIUS:
			continue
		if node.has_method("stun"):
			node.stun(EXTINGUISHER_STUN)
		if fx:
			fx.burst(get_parent(), node.global_position + Vector3.UP * 0.4, Color(0.9, 0.95, 1.0), 10)


## Phase 5 sync: report that THIS peer took the pickup so others despawn it.
func _report_pickup() -> void:
	var network = get_node_or_null("/root/Network")
	if network and network.has_method("report_pickup_taken"):
		network.report_pickup_taken(sync_name)

## Phase 5 sync: area-effect pickups (extinguisher) stun remote players on
## their own machines. Victim peer ids come from the mode's remote map.
func _report_area_stuns(effect: Array) -> void:
	var network = get_node_or_null("/root/Network")
	if network == null or not network.has_method("report_remote_stun"):
		return
	var mode = get_parent()
	if mode == null:
		return
	# Remote players dictionary on the mode (peer_id -> chair)
	if "remote_players" in mode:
		for peer_id in mode.remote_players:
			network.report_remote_stun(int(peer_id), float(effect[1]))
