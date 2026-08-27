# ShopSeek.gd — SECONDARY mode 6B: Supermarket hide & seek.
# Aisles, produce, freezers, checkout; 20+ disguise objects; E disguises the
# chair as a nearby prop (2s freeze then half speed, wobble tell); a security
# guard patrols for a shopper-list fallback round. Multiplayer role fields
# exist on the mode for future seeker/hider replication.
extends Node3D

const ROUND_TIME := 90.0
const DISGUISE_FREEZE := 2.0
const DISGUISE_SPEED := 0.5
const INTERACT_RANGE := 2.4
const SCAN_COOLDOWN := 5.0
const GUARD_SPEED := 3.2
const GUARD_STUN := 1.0
const AISLES := 7
const SHELF_LEN := 14.0
const SHELF_H := 2.2
const AISLE_GAP := 5.0

const DISGUISE_KINDS := [
	{"label": "Avocado", "color": Color(0.36, 0.62, 0.22), "size": Vector3(0.9, 0.7, 0.9)},
	{"label": "Cereal Box", "color": Color(0.92, 0.62, 0.15), "size": Vector3(1.0, 1.4, 0.5)},
	{"label": "Milk Carton", "color": Color(0.94, 0.95, 0.98), "size": Vector3(0.7, 1.2, 0.7)},
	{"label": "Watermelon", "color": Color(0.24, 0.5, 0.2), "size": Vector3(1.2, 1.0, 1.2)},
	{"label": "Pineapple", "color": Color(0.9, 0.78, 0.2), "size": Vector3(0.8, 1.3, 0.8)},
	{"label": "Ketchup", "color": Color(0.85, 0.15, 0.12), "size": Vector3(0.5, 1.0, 0.5)},
	{"label": "Mustard", "color": Color(0.92, 0.8, 0.1), "size": Vector3(0.5, 1.0, 0.5)},
	{"label": "Baguette", "color": Color(0.85, 0.68, 0.4), "size": Vector3(0.5, 0.5, 1.8)},
	{"label": "Cheese Wheel", "color": Color(0.95, 0.78, 0.16), "size": Vector3(1.1, 0.6, 1.1)},
	{"label": "Toilet Paper", "color": Color(0.92, 0.92, 0.94), "size": Vector3(0.8, 0.9, 0.8)},
	{"label": "Soup Can", "color": Color(0.55, 0.2, 0.15), "size": Vector3(0.6, 0.8, 0.6)},
	{"label": "Honey Jar", "color": Color(0.9, 0.65, 0.1), "size": Vector3(0.7, 0.7, 0.7)},
	{"label": "Bleach", "color": Color(0.2, 0.35, 0.75), "size": Vector3(0.5, 1.0, 0.4)},
	{"label": "Ice Cream", "color": Color(0.95, 0.88, 0.85), "size": Vector3(0.6, 1.1, 0.6)},
	{"label": "Dog Food", "color": Color(0.55, 0.4, 0.2), "size": Vector3(1.0, 0.7, 0.6)},
	{"label": "Detergent", "color": Color(0.25, 0.7, 0.65), "size": Vector3(0.7, 1.2, 0.5)},
	{"label": "Pickles", "color": Color(0.4, 0.55, 0.18), "size": Vector3(0.5, 0.9, 0.5)},
	{"label": "Cake Mix", "color": Color(0.88, 0.5, 0.6), "size": Vector3(0.8, 0.7, 0.5)},
	{"label": "Hot Sauce", "color": Color(0.9, 0.35, 0.08), "size": Vector3(0.5, 0.9, 0.5)},
	{"label": "Orange Juice", "color": Color(0.98, 0.6, 0.1), "size": Vector3(0.6, 1.2, 0.6)},
	{"label": "Trash Bag", "color": Color(0.16, 0.16, 0.18), "size": Vector3(0.9, 1.0, 0.7)},
	{"label": "Baking Soda", "color": Color(0.85, 0.85, 0.8), "size": Vector3(0.7, 0.8, 0.5)},
]

# --- round state ---
var remaining_time := ROUND_TIME
var failed := false
var won := false
var match_over := false

# --- shopper-list fallback state ---
var list_items: Array[String] = []
var list_collected: Array[String] = []
var list_target := 5

# --- disguise state ---
var disguised := false
var disguise_freeze_timer := 0.0
var disguise_node: MeshInstance3D
var nearest_prop: Node3D
var wobble_phase := 0.0

# --- multiplayer role scaffolding (single-player keeps fallback loop) ---
var role := &"shopper"  # shopper | hider | seeker
var scan_ready := true
var scan_cd_timer := 0.0

var player: CharacterBody3D
var guard: CharacterBody3D
var guard_path: Array[Vector3] = []
var guard_index := 0
var mode_hud: CanvasLayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 62026
	_build_supermarket()
	_spawn_player()
	_spawn_disguise_props()
	_pick_shopper_list()
	_spawn_guard()
	mode_hud = _make_mode_hud("SHOP & SEEK", "SHOPPER ROUND — GRAB YOUR LIST  •  E: DISGUISE", ROUND_TIME)
	_caption("GRAB %d ITEMS — GUARD ON PATROL" % list_target)

func _process(delta: float) -> void:
	if match_over:
		return
	remaining_time = maxf(remaining_time - delta, 0.0)
	load("res://scripts/FollowCamera.gd").update(get_node_or_null("Camera3D") as Camera3D, player, delta)
	_update_disguise(delta)
	_update_guard(delta)
	_update_scan_timer(delta)
	_check_item_pickups()
	var progress := float(list_collected.size()) / float(list_target)
	var status := "SHOPPING %d/%d" % [list_collected.size(), list_target]
	if disguised:
		status = "DISGUISED — WOBBLE GIVES YOU AWAY"
	if list_collected.size() >= list_target:
		won = true
		match_over = true
		mode_hud.update_state(0.0, 1.0, "LIST COMPLETE — ESCAPED", Color("a8ffbd"))
		_caption("LIST COMPLETE!")
		return
	if remaining_time <= 0.0:
		failed = true
		match_over = true
		mode_hud.update_state(0.0, progress, "TIME UP — %d/%d GRABBED" % [list_collected.size(), list_target], Color("ff7070"))
		return
	mode_hud.update_state(remaining_time, progress, status, Color("ffcf55") if not disguised else Color("7fd8ff"))

# ============================ input ============================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var pause_menu = load("res://scripts/PauseMenu.gd")
		pause_menu.create(self, Callable())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("action"):
		_try_interact()
		get_viewport().set_input_as_handled()

func _try_interact() -> void:
	if not player or not is_instance_valid(player):
		return
	if disguised:
		_undisguise()
		return
	nearest_prop = _nearest_prop()
	if nearest_prop and player.global_position.distance_to(nearest_prop.global_position) <= INTERACT_RANGE:
		_disguise_as(nearest_prop)

# ============================ disguise ============================

func _nearest_prop() -> Node3D:
	var best: Node3D = null
	var best_d := INTERACT_RANGE + 0.001
	for prop in get_tree().get_nodes_in_group("disguise_props"):
		if prop is Node3D and is_instance_valid(prop):
			var d := player.global_position.distance_to(prop.global_position)
			if d < best_d:
				best_d = d
				best = prop
	return best

func _disguise_as(prop: Node3D) -> void:
	disguised = true
	disguise_freeze_timer = DISGUISE_FREEZE
	var kind: Dictionary = prop.get_meta("kind", {})
	var mesh := BoxMesh.new()
	mesh.size = kind.get("size", Vector3.ONE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = kind.get("color", Color.GRAY)
	disguise_node = MeshInstance3D.new()
	disguise_node.mesh = mesh
	disguise_node.material_override = mat
	player.add_child(disguise_node)
	disguise_node.position = Vector3(0, 1.0, 0)
	if "model_parent" in player and player.model_parent:
		player.model_parent.visible = false
	if "carry_slowdown" in player:
		player.carry_slowdown = DISGUISE_SPEED
	player.set_can_move(false)
	_caption("DISGUISED AS %s — HOLD STILL" % kind.get("label", "PROP"))

func _undisguise() -> void:
	disguised = false
	if disguise_node and is_instance_valid(disguise_node):
		disguise_node.queue_free()
	disguise_node = null
	if "model_parent" in player and player.model_parent:
		player.model_parent.visible = true
	if "carry_slowdown" in player:
		player.carry_slowdown = 1.0
	player.set_can_move(true)
	_caption("BACK TO SHOPPING")

func _update_disguise(delta: float) -> void:
	if not disguised:
		return
	wobble_phase += delta * 4.0
	if disguise_node and is_instance_valid(disguise_node):
		# The tell: subtle scale wobble a seeker can spot.
		var w := 1.0 + sin(wobble_phase) * 0.06
		disguise_node.scale = Vector3(w, 2.0 - w, w)
	if disguise_freeze_timer > 0.0:
		disguise_freeze_timer = maxf(disguise_freeze_timer - delta, 0.0)
		if disguise_freeze_timer <= 0.0 and player:
			player.set_can_move(true)

# ============================ shopper list ============================

func _pick_shopper_list() -> void:
	var pool: Array[String] = []
	for k in DISGUISE_KINDS:
		pool.append(k["label"])
	# Deterministic shuffle via our seeded rng (global shuffle made every
	# session's list different -> unstable difficulty + unauditable runs).
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for i in range(list_target):
		list_items.append(pool[i])

func _check_item_pickups() -> void:
	if disguised or not player:
		return
	for prop in get_tree().get_nodes_in_group("disguise_props"):
		if prop is Node3D and is_instance_valid(prop) and not prop.get_meta("taken", false):
			if player.global_position.distance_to(prop.global_position) <= 1.4:
				var label: String = prop.get_meta("kind", {}).get("label", "")
				if label in list_items and not list_collected.has(label):
					list_collected.append(label)
					prop.set_meta("taken", true)
					prop.queue_free()
					_caption("GOT %s (%d/%d)" % [label, list_collected.size(), list_target])

# ============================ guard ============================

func _spawn_guard() -> void:
	guard = CharacterBody3D.new()
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.9
	col.shape = capsule
	guard.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.9
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.2)
	mi.material_override = mat
	guard.add_child(mi)
	# red vest for the guard NPC (seeker visual language)
	var vest := MeshInstance3D.new()
	var vmesh := BoxMesh.new()
	vmesh.size = Vector3(1.1, 0.8, 0.7)
	vest.mesh = vmesh
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.85, 0.12, 0.12)
	vest.material_override = vmat
	vest.position = Vector3(0, 0.35, 0)
	guard.add_child(vest)
	add_child(guard)
	guard.global_position = Vector3(-20, 1.2, -20)
	# patrol loop through aisles
	guard_path = [
		Vector3(-20, 1.2, -20), Vector3(20, 1.2, -20),
		Vector3(20, 1.2, 20), Vector3(-20, 1.2, 20),
	]

func _update_guard(delta: float) -> void:
	if not guard or not is_instance_valid(guard) or guard_path.is_empty():
		return
	var target := guard_path[guard_index % guard_path.size()]
	var to_target := target - guard.global_position
	to_target.y = 0.0
	if to_target.length() < 0.5:
		guard_index += 1
		return
	var move := to_target.normalized() * GUARD_SPEED
	guard.velocity = Vector3(move.x, -9.8 * delta, move.z)
	guard.move_and_slide()
	# touching the guard stuns the player (caught flavor)
	if player and is_instance_valid(player):
		if guard.global_position.distance_to(player.global_position) <= 1.6 and player.is_stunned <= 0.0:
			player.stun(GUARD_STUN)
			# Stun outranks the disguise freeze; never strand a frozen chair.
			if disguised and disguise_freeze_timer > 0.0:
				disguise_freeze_timer = 0.0
			_caption("SECURITY! STUNNED")

# ============================ scan (seeker ability) ============================

func _update_scan_timer(delta: float) -> void:
	if not scan_ready:
		scan_cd_timer -= delta
		if scan_cd_timer <= 0.0:
			scan_ready = true

func try_scan() -> bool:
	"""Seeker ability placeholder for multiplayer: highlights movers.
	Returns false while on cooldown."""
	if not scan_ready or role != &"seeker":
		return false
	scan_ready = false
	scan_cd_timer = SCAN_COOLDOWN
	return true

# ============================ level ============================

func _build_supermarket() -> void:
	# Floor
	var floor_node := StaticBody3D.new()
	floor_node.name = "Floor"
	add_child(floor_node)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(56, 0.2, 56)
	col.shape = shape
	floor_node.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(56, 0.2, 56)
	mesh_inst.mesh = mesh
	# Retail lino via SurfaceLibrary; flat fallback keeps standalone tests ok.
	var slib = load("res://scripts/SurfaceLibrary.gd")
	var mat: StandardMaterial3D
	if slib != null and slib.has_method("make_market_floor"):
		mat = slib.make_market_floor()
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.18, 0.2)
		mat.roughness = 0.9
	mesh_inst.material_override = mat
	floor_node.add_child(mesh_inst)
	# Perimeter walls
	for w in [
		{"pos": Vector3(0, 1.5, -28), "size": Vector3(56, 3, 1)},
		{"pos": Vector3(0, 1.5, 28), "size": Vector3(56, 3, 1)},
		{"pos": Vector3(-28, 1.5, 0), "size": Vector3(1, 3, 56)},
		{"pos": Vector3(28, 1.5, 0), "size": Vector3(1, 3, 56)},
	]:
		var wall := StaticBody3D.new()
		var wc := CollisionShape3D.new()
		var ws := BoxShape3D.new()
		ws.size = w["size"]
		wc.shape = ws
		wall.add_child(wc)
		var wm := MeshInstance3D.new()
		var wmesh := BoxMesh.new()
		wmesh.size = w["size"]
		wm.mesh = wmesh
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.16, 0.16, 0.2)
		wm.material_override = wmat
		wall.add_child(wm)
		wall.position = w["pos"]
		add_child(wall)
	# Aisles: parallel shelves
	for i in range(AISLES):
		var z := -18.0 + float(i) * AISLE_GAP
		_make_shelf(Vector3(-10, SHELF_H * 0.5, z), 0.0)
		_make_shelf(Vector3(10, SHELF_H * 0.5, z), 0.0)
	# Produce section: round tables
	for pos in [Vector3(-20, 0, -24), Vector3(-14, 0, -24), Vector3(-20, 0, -18)]:
		_make_table(pos, Color(0.35, 0.55, 0.3))
	# Frozen section: upright freezers with blue glow
	for i in range(4):
		_make_freezer(Vector3(20, 0, -24.0 + float(i) * 4.0))
	# Checkout counters at front
	for i in range(3):
		_make_counter(Vector3(-8.0 + float(i) * 8.0, 0, 22))
	print("[SHOP&SEEK] Supermarket built")

func _make_shelf(pos: Vector3, rot_y: float) -> void:
	var shelf := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(SHELF_LEN, SHELF_H, 1.2)
	col.shape = shape
	shelf.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(SHELF_LEN, SHELF_H, 1.2)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.25, 0.2)
	mi.material_override = mat
	shelf.add_child(mi)
	shelf.position = pos
	shelf.rotation.y = rot_y
	add_child(shelf)

func _make_table(pos: Vector3, color: Color) -> void:
	var table := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.0
	shape.height = 0.9
	col.shape = shape
	table.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.0
	mesh.bottom_radius = 2.0
	mesh.height = 0.9
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	table.add_child(mi)
	table.position = pos + Vector3(0, 0.45, 0)
	add_child(table)

func _make_freezer(pos: Vector3) -> void:
	var freezer := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.4, 1.2)
	col.shape = shape
	freezer.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.4, 2.4, 1.2)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.75, 0.95, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.5, 0.8)
	mat.emission_energy_multiplier = 0.5
	mi.material_override = mat
	freezer.add_child(mi)
	freezer.position = pos + Vector3(0, 1.2, 0)
	add_child(freezer)

func _make_counter(pos: Vector3) -> void:
	var counter := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 1.0, 1.4)
	col.shape = shape
	counter.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.0, 1.0, 1.4)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.3, 0.28)
	mi.material_override = mat
	counter.add_child(mi)
	counter.position = pos + Vector3(0, 0.5, 0)
	add_child(counter)

func _spawn_disguise_props() -> void:
	# Deterministic spread across aisles, produce, and frozen sections.
	var spawn_points: Array[Vector3] = []
	for i in range(AISLES):
		var z := -18.0 + float(i) * AISLE_GAP
		for k in range(4):
			spawn_points.append(Vector3(-10.0 + float(k) * 6.6, 0.6, z + 2.6))
			spawn_points.append(Vector3(-10.0 + float(k) * 6.6, 0.6, z - 2.6))
	for pos in [Vector3(-20, 0.9, -22), Vector3(-14, 0.9, -22), Vector3(-20, 0.9, -16)]:
		spawn_points.append(pos)
	for i in range(4):
		spawn_points.append(Vector3(18.0, 0.9, -24.0 + float(i) * 4.0))
	for i in range(3):
		spawn_points.append(Vector3(-8.0 + float(i) * 8.0, 0.9, 20.0))
	for i in range(DISGUISE_KINDS.size()):
		var kind: Dictionary = DISGUISE_KINDS[i]
		var pos := spawn_points[i % spawn_points.size()]
		var prop := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = kind["size"]
		prop.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = kind["color"]
		prop.material_override = mat
		prop.position = pos + Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8))
		prop.add_to_group("disguise_props")
		prop.set_meta("kind", kind)
		add_child(prop)
	print("[SHOP&SEEK] %d disguise props placed" % DISGUISE_KINDS.size())

# ============================ player / hud ============================

func _spawn_player() -> void:
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if player_scene:
		player = player_scene.instantiate()
		player.position = Vector3(0, 1.5, 16)
		player.player_display_name = "Shopper"
		add_child(player)
		if "suppress_action_jump" in player:
			player.suppress_action_jump = true
	# Phase 7A: touch controls (mobile or FE_TOUCH=1 preview)
	var mc_script7 = load("res://scripts/MobileControls.gd")
	if mc_script7 and mc_script7.has_method("mount_for_mode"):
		mc_script7.mount_for_mode(self, player)

func _make_mode_hud(title: String, objective: String, time_limit: float) -> CanvasLayer:
	var hud_script = load("res://scripts/ModeHUD.gd")
	var hud = CanvasLayer.new()
	if hud_script:
		hud.set_script(hud_script)
		add_child(hud)
		hud.configure(title, objective, time_limit)
	# Caption overlay for audio-cue subtitles (no-op when disabled)
	var overlay_script = load("res://scripts/SubtitleOverlay.gd")
	if overlay_script and overlay_script.has_method("mount"):
		overlay_script.mount(hud)
	return hud

func _caption(text: String) -> void:
	var cap = get_tree().get_first_node_in_group("subtitle_captions")
	if cap and cap.has_method("show_caption"):
		cap.show_caption(text)
