# PizzaColony.gd — SECONDARY mode 6C: survival on a giant pizza.
# Zones: crust ring, cheese plain, sauce sea (slow), pepperoni pads.
# Stand on a pepperoni to claim it; owned pads generate resources; cheese is
# harvested by standing still; E builds a crust-wall fort. The Chef patrols
# the rim, sweeping a pizza-cutter line and lobbing olive bombs; touch either
# and you are launched off the pizza (eliminated). Win by claiming all pads
# or surviving the timer.
extends Node3D

const PIZZA_R := 25.0
const CRUST_W := 3.0
const SAUCE_R := 7.0
const ROUND_TIME := 120.0
const CLAIM_TIME := 3.0
const STEAL_TIME := 5.0
const RESOURCE_INTERVAL := 5.0
const SAUCE_SLOW := 0.55
const HARVEST_TIME := 3.0
const HARVEST_RANGE := 1.0
const FORT_COST_CHEESE := 5
const FORT_COST_TOPPING := 3
const FORT_SIZE := Vector3(2.0, 1.0, 0.5)
const CHEF_SPEED := 4.0
const CHEF_ACCEL := 0.045
const CUTTER_PERIOD := 9.0
const CUTTER_SPEED := 0.9
const CUTTER_WIDTH := 0.5
const OLIVE_INTERVAL := 6.0
const OLIVE_FUSE := 2.0
const OLIVE_STUN := 2.0
const OLIVE_RADIUS := 4.0
const LAUNCH_FORCE := 30.0
const PLAYER_COLOR := Color(0.4, 0.85, 0.95)
const PEPPERONI_COUNT := 10

# --- zones: pepperoni pads ---
var pepperonis: Array[Dictionary] = []
# { "node": MeshInstance3D, "pos": Vector3, "owner": StringName, "progress": float }

# --- round state ---
var remaining_time := ROUND_TIME
var match_over := false
var won := false
var eliminated := false
var resource_timer := 0.0

# --- player economy ---
var cheese := 0
var toppings := 0
var harvest_progress := 0.0
var claiming: MeshInstance3D = null

# --- chef threats ---
var chef: Node3D
var chef_pos := Vector3(PIZZA_R - 1.5, 0.8, 0.0)
var chef_speed := CHEF_SPEED
var cutter_angle := 0.0
var cutter_active := false
var cutter_timer := 0.0
var cutter_mesh: MeshInstance3D
var olive_timer := OLIVE_INTERVAL
var olives: Array[Dictionary] = []

var player: CharacterBody3D
var mode_hud: CanvasLayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	# Mouse-look: capture cursor for the match; PauseMenu re-shows it.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rng.seed = 630
	_build_pizza()
	_spawn_pepperonis()
	_spawn_player()
	_spawn_chef()
	mode_hud = _make_mode_hud("PIZZA COLONY", "CLAIM PEPPERONI  •  BUILD FORTS  •  SURVIVE THE CHEF", ROUND_TIME)
	# Controls recap at round start.
	var controls_overlay = load("res://scripts/ControlsOverlay.gd").mount(self)
	if controls_overlay:
		controls_overlay.show_for(7.0)
	_caption("STAND ON PEPPERONI TO CLAIM — E BUILDS A FORT")

func _process(delta: float) -> void:
	if match_over:
		# Round over: stop simulating threats so a freed/ended scene can not
		# reach into other live instances (also saves battery on clients).
		return
	remaining_time = maxf(remaining_time - delta, 0.0)
	load("res://scripts/FollowCamera.gd").update(get_node_or_null("Camera3D") as Camera3D, player, delta)
	_update_zone_speed()
	_update_claims(delta)
	_update_resources(delta)
	_update_harvest(delta)
	_update_chef(delta)
	_update_olives(delta)
	_check_cutter_hit()
	_check_fell_off()
	_update_hud()
	if eliminated:
		return
	if pepperonis.all(func(p): return p["owner"] == &"player"):
		_end(true, "ALL PEPPERONI CLAIMED")
	elif remaining_time <= 0.0:
		_end(true, "SURVIVED THE SERVICE")

# ============================ zones ============================

func _zone_at(pos: Vector3) -> StringName:
	var d := Vector2(pos.x, pos.z).length()
	if d > PIZZA_R - CRUST_W:
		return &"crust"
	if d < SAUCE_R:
		return &"sauce"
	for p in pepperonis:
		if (p["pos"] as Vector3).distance_to(Vector3(pos.x, p["pos"].y, pos.z)) <= 2.0:
			return &"pepperoni"
	return &"cheese"

func _update_zone_speed() -> void:
	if not player or not is_instance_valid(player):
		return
	if _zone_at(player.global_position) == &"sauce":
		player.carry_slowdown = SAUCE_SLOW
	else:
		player.carry_slowdown = 1.0

# ============================ claims ============================

func _update_claims(delta: float) -> void:
	if eliminated or not player or not is_instance_valid(player):
		return
	var pad := _pad_under(player.global_position)
	if pad == null:
		_reset_claim()
		return
	var entry: Dictionary = _entry_for(pad)
	if entry["owner"] == &"player":
		_reset_claim()
		return
	if claiming != pad:
		_reset_claim()
		claiming = pad
		entry["progress"] = 0.0
	entry["progress"] = float(entry["progress"]) + delta
	var need := CLAIM_TIME if entry["owner"] == &"none" else STEAL_TIME
	if float(entry["progress"]) >= need:
		entry["owner"] = &"player"
		entry["progress"] = 0.0
		_paint_pad(pad, PLAYER_COLOR)
		_caption("PEPPERONI CLAIMED!")
	else:
		_caption("CLAIMING %d%%" % int(float(entry["progress"]) / need * 100.0))

func _pad_under(pos: Vector3) -> MeshInstance3D:
	for p in pepperonis:
		if (p["pos"] as Vector3).distance_to(Vector3(pos.x, p["pos"].y, pos.z)) <= 2.0:
			return p["node"]
	return null

func _entry_for(pad: MeshInstance3D) -> Dictionary:
	for p in pepperonis:
		if p["node"] == pad:
			return p
	return {}

func _reset_claim() -> void:
	# Roadmap: claims need CONTINUOUS presence; leaving a pad forfeits progress.
	if claiming != null:
		var entry := _entry_for(claiming)
		if not entry.is_empty() and entry["owner"] != &"player":
			entry["progress"] = 0.0
		claiming = null

func _paint_pad(pad: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.4
	pad.material_override = mat

# ============================ resources ============================

func _update_resources(delta: float) -> void:
	resource_timer += delta
	if resource_timer < RESOURCE_INTERVAL:
		return
	resource_timer = 0.0
	var owned := 0
	for p in pepperonis:
		if p["owner"] == &"player":
			owned += 1
			cheese += 1
			if rng.randf() < 0.5:
				toppings += 1
	if owned > 0:
		_caption("+%d CHEESE" % owned)

func _update_harvest(delta: float) -> void:
	if eliminated or not player or not is_instance_valid(player):
		return
	# Standing (nearly) still on the cheese plain slowly harvests cheese.
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if _zone_at(player.global_position) == &"cheese" and speed < HARVEST_RANGE:
		harvest_progress += delta
		if harvest_progress >= HARVEST_TIME:
			harvest_progress = 0.0
			cheese += 2
			_caption("HARVESTED +2 CHEESE")
	else:
		harvest_progress = 0.0

# ============================ forts ============================

func try_build_fort() -> bool:
	if cheese < FORT_COST_CHEESE or toppings < FORT_COST_TOPPING:
		_caption("NEED %d CHEESE + %d TOPPINGS" % [FORT_COST_CHEESE, FORT_COST_TOPPING])
		return false
	cheese -= FORT_COST_CHEESE
	toppings -= FORT_COST_TOPPING
	var fort := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = FORT_SIZE
	col.shape = shape
	fort.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = FORT_SIZE
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.62, 0.28)
	mi.material_override = mat
	fort.add_child(mi)
	add_child(fort)
	# Place 2.5m ahead of the player's facing, snapped to the pizza plane.
	var facing: Vector3 = player.get_facing_direction() if player.has_method("get_facing_direction") else Vector3.FORWARD
	var pos := player.global_position + facing * 2.5
	fort.global_position = Vector3(pos.x, 0.75, pos.z)
	_caption("CRUST WALL BUILT")
	return true

# ============================ chef ============================

func _spawn_chef() -> void:
	chef = Node3D.new()
	chef.name = "Chef"
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.0, 4.5, 3.0)
	body.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.95, 0.95, 0.97)
	body.material_override = bmat
	chef.add_child(body)
	var hat := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 1.1
	hm.bottom_radius = 1.1
	hm.height = 1.2
	hat.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color.WHITE
	hat.material_override = hmat
	hat.position = Vector3(0, 2.9, 0)
	chef.add_child(hat)
	add_child(chef)
	chef.global_position = chef_pos
	# Cutter: a thin long box rotating like a clock hand.
	cutter_mesh = MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.5, 0.6, PIZZA_R * 2.0)
	cutter_mesh.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.15, 0.1)
	cmat.emission_enabled = true
	cmat.emission = Color(1.0, 0.1, 0.05)
	cutter_mesh.material_override = cmat
	cutter_mesh.visible = false
	add_child(cutter_mesh)

func _update_chef(delta: float) -> void:
	# Chef walks the rim, accelerating over the round.
	chef_speed += CHEF_ACCEL * delta
	var angle := atan2(chef.global_position.z, chef.global_position.x) + chef_speed * delta / (PIZZA_R - 1.5)
	chef.global_position = Vector3(cos(angle) * (PIZZA_R - 1.5), 0.8, sin(angle) * (PIZZA_R - 1.5))
	chef.look_at(Vector3.ZERO, Vector3.UP)
	# Cutter sweep cycle
	cutter_timer += delta
	if not cutter_active and cutter_timer >= CUTTER_PERIOD:
		cutter_active = true
		cutter_timer = 0.0
		_caption("PIZZA CUTTER INCOMING")
	if cutter_active:
		cutter_angle += CUTTER_SPEED * delta
		cutter_mesh.visible = true
		cutter_mesh.rotation.y = cutter_angle
		if cutter_angle >= TAU:
			cutter_angle = 0.0
			cutter_active = false
			cutter_mesh.visible = false

func _check_cutter_hit() -> void:
	if eliminated or not cutter_active or not player or not is_instance_valid(player):
		return
	# The cutter is a diameter line through the center at cutter_angle.
	var p := player.global_position
	var line_dir := Vector3(cos(cutter_angle), 0.0, -sin(cutter_angle))
	var rel := Vector3(p.x, 0.0, p.z)
	var dist := absf(rel.cross(line_dir).y)
	if dist <= CUTTER_WIDTH and rel.length() <= PIZZA_R:
		_eliminate("SLICED BY THE PIZZA CUTTER")

# ============================ olives ============================

func _update_olives(delta: float) -> void:
	if eliminated:
		return
	olive_timer -= delta
	if olive_timer <= 0.0:
		olive_timer = OLIVE_INTERVAL
		_throw_olive()
	for o in olives:
		if not o["node"].is_queued_for_deletion():
			o["fuse"] = float(o["fuse"]) - delta
			if float(o["fuse"]) <= 0.0:
				_pop_olive(o)
	# Remove popped entries.
	olives = olives.filter(func(o): return not o["node"].is_queued_for_deletion())

func _throw_olive() -> void:
	if not player or not is_instance_valid(player):
		return
	var olive := MeshInstance3D.new()
	var om := SphereMesh.new()
	om.radius = 0.45
	om.height = 0.9
	olive.mesh = om
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(0.1, 0.12, 0.08)
	olive.material_override = omat
	add_child(olive)
	var target := player.global_position
	olive.global_position = Vector3(target.x + rng.randf_range(-3, 3), 1.2, target.z + rng.randf_range(-3, 3))
	olives.append({"node": olive, "fuse": OLIVE_FUSE})

func _pop_olive(o: Dictionary) -> void:
	var center: Vector3 = o["node"].global_position
	o["node"].queue_free()
	_caption("OLIVE BOMB!")
	# Stun zone: everyone within OLIVE_RADIUS is stunned (not eliminated).
	if player and is_instance_valid(player):
		if player.global_position.distance_to(center) <= OLIVE_RADIUS:
			player.stun(OLIVE_STUN)

# ============================ elimination / end ============================

func _check_fell_off() -> void:
	if eliminated or not player or not is_instance_valid(player):
		return
	var d := Vector2(player.global_position.x, player.global_position.z).length()
	if d > PIZZA_R + 2.0 or player.global_position.y < -6.0:
		_eliminate("LAUNCHED OFF THE PIZZA")

func _eliminate(reason: String) -> void:
	eliminated = true
	match_over = true
	var dir := Vector3(player.global_position.x, 0.0, player.global_position.z).normalized()
	if dir.length() < 0.1:
		dir = Vector3.RIGHT
	player.set_can_move(false)
	# set_can_move(false) zeroes velocity — apply the launch AFTER freezing
	# so the comedy send-off actually flies.
	player.velocity = dir * LAUNCH_FORCE + Vector3.UP * 14.0
	_end(false, reason)

func _end(victory: bool, reason: String) -> void:
	match_over = true
	won = victory
	mode_hud.update_state(remaining_time if victory else 0.0, _progress(), reason, Color("a8ffbd") if victory else Color("ff7070"))
	_caption(reason)
	print("[PIZZA COLONY] %s" % reason)

func _progress() -> float:
	var owned := 0
	for p in pepperonis:
		if p["owner"] == &"player":
			owned += 1
	return float(owned) / float(pepperonis.size())

# ============================ hud / input ============================

func _update_hud() -> void:
	var owned := 0
	for p in pepperonis:
		if p["owner"] == &"player":
			owned += 1
	var status := "PEPPERONI %d/%d  •  CHEESE %d  •  TOPPINGS %d" % [owned, pepperonis.size(), cheese, toppings]
	if cutter_active:
		status = "DODGE THE CUTTER!  " + status
	mode_hud.update_state(remaining_time, _progress(), status, Color("ffcf55") if not cutter_active else Color("ff7070"))

func _unhandled_input(event: InputEvent) -> void:
	var FollowCameraScript = load("res://scripts/FollowCamera.gd")
	if FollowCameraScript and FollowCameraScript.handle_mouse_input(event):
		get_viewport().set_input_as_handled()
		return
	# Y/Triangle (or R) re-centers the chase camera.
	if event.is_action_pressed("recenter_camera"):
		var input_prefs = load("res://scripts/InputPrefs.gd")
		if input_prefs:
			input_prefs.reset_yaw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		var pause_menu = load("res://scripts/PauseMenu.gd")
		pause_menu.create(self, Callable())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action") and not match_over:
		try_build_fort()
		get_viewport().set_input_as_handled()

# ============================ level ============================

func _build_pizza() -> void:
	# Cheese-colored base disc (whole pizza).
	var pizza := StaticBody3D.new()
	pizza.name = "PizzaBase"
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = PIZZA_R
	shape.height = 0.5
	col.shape = shape
	pizza.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = PIZZA_R - CRUST_W
	mesh.bottom_radius = PIZZA_R - CRUST_W
	mesh.height = 0.5
	mi.mesh = mesh
	# Melted-cheese texture via SurfaceLibrary; flat fallback for tests.
	var slib = load("res://scripts/SurfaceLibrary.gd")
	var mat: StandardMaterial3D
	if slib != null and slib.has_method("make_cheese_surface"):
		mat = slib.make_cheese_surface()
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.78, 0.35)
		mat.roughness = 0.9
	mi.material_override = mat
	pizza.add_child(mi)
	add_child(pizza)
	# Crust ring (torus-ish: shallow cylinder ring around the rim).
	var crust := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = PIZZA_R
	ring.bottom_radius = PIZZA_R
	ring.height = 0.7
	crust.mesh = ring
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.78, 0.55, 0.25)
	crust.material_override = cmat
	crust.position = Vector3(0, 0.1, 0)
	add_child(crust)
	# Sauce sea (inner red disc, slightly raised visual).
	var sauce := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = SAUCE_R
	sm.bottom_radius = SAUCE_R
	sm.height = 0.56
	sauce.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.72, 0.18, 0.12)
	sauce.material_override = smat
	sauce.position = Vector3(0, 0.04, 0)
	add_child(sauce)
	print("[PIZZA COLONY] Pizza baked — radius %.0fm" % PIZZA_R)

func _spawn_pepperonis() -> void:
	pepperonis.clear()
	var placed := 0
	var tries := 0
	while placed < PEPPERONI_COUNT and tries < 200:
		tries += 1
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(SAUCE_R + 2.5, PIZZA_R - CRUST_W - 2.0)
		var pos := Vector3(cos(angle) * dist, 0.32, sin(angle) * dist)
		# Keep pads from overlapping each other.
		var ok := true
		for p in pepperonis:
			if (p["pos"] as Vector3).distance_to(pos) < 5.0:
				ok = false
				break
		if not ok:
			continue
		var pad := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 2.0
		pm.bottom_radius = 2.0
		pm.height = 0.18
		pad.mesh = pm
		_paint_pad(pad, Color(0.7, 0.15, 0.1))
		pad.position = pos
		add_child(pad)
		pepperonis.append({"node": pad, "pos": pos, "owner": &"none", "progress": 0.0})
		placed += 1
	print("[PIZZA COLONY] %d pepperoni pads placed" % pepperonis.size())

# ============================ player ============================

func _spawn_player() -> void:
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if player_scene:
		player = player_scene.instantiate()
		player.player_display_name = "Topping"
		add_child(player)
		# PackedScene resources are cached across repeated scene instances in one
		# tree. A prior eliminated chair can otherwise leak its launched transform
		# or velocity into a fresh survival round once disabled bodies simulate
		# physics correctly. Canonicalize after add_child so the live transform wins.
		player.global_position = Vector3(0, 1.5, 12)
		player.velocity = Vector3.ZERO
		player.set_can_move(true)
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
	var overlay_script = load("res://scripts/SubtitleOverlay.gd")
	if overlay_script and overlay_script.has_method("mount"):
		overlay_script.mount(hud)
	return hud

func _caption(text: String) -> void:
	var cap = get_tree().get_first_node_in_group("subtitle_captions")
	if cap and cap.has_method("show_caption"):
		cap.show_caption(text)
