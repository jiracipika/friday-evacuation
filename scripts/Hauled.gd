# Hauled.gd — SECONDARY mode 6A: Co-op physics delivery (full implementation)
# Deliver absurd HOSTILE cargo through impossible terrain.
# 3 rounds; each round one random cargo type crosses one random terrain
# gauntlet to the delivery zone. Score = base value x gentleness/speed/
# co-op multipliers, prorated by surviving cargo value. Highest total wins.
extends Node3D

const CARGO_TYPES := {
	"fridge_of_bees": {"label": "Fridge of Bees", "color": Color(0.9, 0.85, 0.3), "mass": 3.0, "behavior": "bees", "size": Vector3(1.6, 2.2, 1.4), "value": 300},
	"haunted_sofa": {"label": "Haunted Sofa", "color": Color(0.5, 0.3, 0.4), "mass": 2.5, "behavior": "haunted", "size": Vector3(2.4, 1.0, 1.0), "value": 250},
	"angry_vending_machine": {"label": "Angry Vending Machine", "color": Color(0.8, 0.2, 0.2), "mass": 4.0, "behavior": "vending", "size": Vector3(1.4, 2.2, 1.2), "value": 500},
	"wet_cardboard": {"label": "Wet Cardboard Box", "color": Color(0.6, 0.5, 0.3), "mass": 1.0, "behavior": "normal", "size": Vector3(1.4, 1.4, 1.4), "value": 100},
	"exploding_cake": {"label": "Exploding Cake", "color": Color(0.9, 0.7, 0.5), "mass": 1.5, "behavior": "explode", "size": Vector3(1.2, 1.0, 1.2), "value": 400},
	"sentient_plant": {"label": "Sentient Plant", "color": Color(0.2, 0.6, 0.2), "mass": 2.0, "behavior": "plant", "size": Vector3(1.2, 1.8, 1.2), "value": 200},
}

const TERRAIN_KINDS := ["pendulum_gates", "conveyor_belt", "wrong_way_escalator", "flat_gauntlet"]
const TOTAL_ROUNDS := 3
const ROUND_TIME := 100.0
const GRAB_RANGE := 2.2
const THROW_FORCE := 10.0
const COOP_RADIUS := 3.0
const DELIVERY_Z := 25.0
const CARGO_SPAWN_Z := -20.0
const PUSH_FORCE := 16.0        # wrong-way push on rigid cargo (Newtons)
const PLAYER_PUSH_ACCEL := 7.0  # wrong-way deceleration on chairs (m/s^2)

# --- state ---
var rng := RandomNumberGenerator.new()
var round_index := 0
var total_score := 0
var round_scores: Array[int] = []
var remaining_time := ROUND_TIME
var round_active := false
var match_over := false

var cargo: RigidBody3D
var cargo_type_key := ""
var cargo_value := 1.0
var cargo_damage_events := 0
var carry_cumulative := 0.0
var exploded := false
var delivered_this_round := false
var held_by: Node3D = null
var player: Node3D

var terrain_nodes: Array[Node3D] = []
var push_zone_bodies: Array[Node3D] = []   # bodies currently inside a wrong-way zone
var pendulums: Array[Dictionary] = []      # {pivot, speed, phase, amp}
var delivery_zone: Area3D
var mode_hud: CanvasLayer
var round_banner: Label
var _next_round_timer := -1.0
var _bee_timer := 4.0
var _vend_timer := 6.0
var _elapsed := 0.0

# swarm/stun visual nodes
var bee_swarm: GPUParticles3D
var can_projectiles: Array[RigidBody3D] = []

func _ready() -> void:
	rng.seed = int(Time.get_unix_time_from_system()) % 100000
	_build_static_level()
	_spawn_player()
	player = _find_player()
	_make_mode_hud()
	_start_round(0)

func _exit_tree() -> void:
	_release_carried_cargo()

# ============================ match flow ============================

func _start_round(index: int) -> void:
	round_index = index
	remaining_time = ROUND_TIME
	round_active = true
	delivered_this_round = false
	exploded = false
	cargo_damage_events = 0
	carry_cumulative = 0.0
	cargo_value = 1.0
	var ckeys := CARGO_TYPES.keys()
	cargo_type_key = ckeys[rng.randi_range(0, ckeys.size() - 1)]
	var terrain_kind: String = TERRAIN_KINDS[rng.randi_range(0, TERRAIN_KINDS.size() - 1)]
	_clear_round_nodes()
	_build_terrain(terrain_kind)
	_spawn_cargo(cargo_type_key)
	if player and is_instance_valid(player):
		player.global_position = Vector3(0, 1.5, CARGO_SPAWN_Z - 2.0)
	_show_banner("ROUND %d/%d — %s\n%s" % [
		index + 1, TOTAL_ROUNDS,
		CARGO_TYPES[cargo_type_key]["label"],
		_terrain_label(terrain_kind)])
	if mode_hud and mode_hud.has_method("update_state"):
		mode_hud.update_state(remaining_time, 0.0, "HAULING", Color("ffcf55"))

func _finish_round(score: int, label: String, color: Color) -> void:
	round_active = false
	total_score += score
	round_scores.append(score)
	_show_banner("%s\n+%d" % [label, score], color)
	if mode_hud and mode_hud.has_method("update_state"):
		mode_hud.update_state(0.0, 1.0 if score > 0 else 0.0, "%s  |  TOTAL %d" % [label, total_score], color)
	if round_index + 1 >= TOTAL_ROUNDS:
		match_over = true
		_show_end_panel()
	else:
		_next_round_timer = 3.0

func _show_end_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "EndPanel"
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.42
	panel.anchor_bottom = 0.42
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -90
	panel.offset_bottom = 90
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.96)
	style.border_color = Color("ff9a1a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	var title := Label.new()
	title.text = "SHIFT COMPLETE"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("ff9a1a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var score_lbl := Label.new()
	var per_round := "  ·  ".join(round_scores.map(func(s): return "+%d" % s))
	score_lbl.text = "TOTAL SCORE  %d\n%s" % [total_score, per_round]
	score_lbl.add_theme_font_size_override("font_size", 18)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_lbl)
	var hint := Label.new()
	hint.text = "Esc — menu"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)
	panel.add_child(vbox)
	layer.add_child(panel)
	add_child(layer)

# ============================ per-frame ============================

func _process(delta: float) -> void:
	# Scene changes can leave one final process tick while children are queued
	# for deletion. Never read transforms from an off-tree cargo body.
	if is_queued_for_deletion() or not is_inside_tree():
		return
	_elapsed += delta
	# Pendulum gate swing
	for p in pendulums:
		var pivot: AnimatableBody3D = p["pivot"]
		if is_instance_valid(pivot):
			pivot.rotation.z = sin(_elapsed * p["speed"] + p["phase"]) * p["amp"]
	# Plant growth: mass 2.0 -> 5.0 over 30s from spawn
	if cargo and is_instance_valid(cargo) and _behavior() == "plant" and not cargo.freeze:
		cargo.mass = minf(cargo.mass + 0.1 * delta, 5.0)
	# Round flow
	if not round_active:
		if _next_round_timer > 0.0:
			_next_round_timer -= delta
			if _next_round_timer <= 0.0:
				_start_round(round_index + 1)
		return
	remaining_time = maxf(remaining_time - delta, 0.0)
	_update_carry()
	_update_push_zones(delta)
	_update_cargo_events(delta)
	_update_projectiles(delta)
	# Cargo might have been destroyed/queued during its behavior update.
	if cargo == null or not is_instance_valid(cargo) or cargo.is_queued_for_deletion():
		return
	# Carried cargo can't trip the delivery Area3D (collisions off while
	# frozen) — check the zone bounds manually.
	if held_by and cargo and is_instance_valid(cargo):
		var dz: float = cargo.global_position.z
		if dz > DELIVERY_Z - 4.0 and absf(cargo.global_position.x) < 4.0:
			_score_delivery()
			return
	var progress := _round_progress()
	if mode_hud and mode_hud.has_method("update_state"):
		var status := "HAULING"
		if held_by:
			status = "CARRYING — E TO THROW"
		elif cargo and is_instance_valid(cargo):
			status = "GO GRAB THE %s" % CARGO_TYPES[cargo_type_key]["label"].to_upper()
		mode_hud.update_state(remaining_time, progress, status, Color("ffcf55"))
	if remaining_time <= 0.0 and not delivered_this_round:
		_finish_round(0, "TIME UP — CARGO ABANDONED", Color("ff7070"))

func _round_progress() -> float:
	if delivered_this_round:
		return 1.0
	if cargo and is_instance_valid(cargo):
		return clampf((cargo.global_position.z - CARGO_SPAWN_Z) / (DELIVERY_Z - CARGO_SPAWN_Z), 0.0, 1.0)
	return 0.0

# ============================ wrong-way zones ============================

func _update_push_zones(delta: float) -> void:
	if push_zone_bodies.is_empty():
		return
	for body in push_zone_bodies:
		if not is_instance_valid(body):
			continue
		if body == cargo and cargo.freeze:
			continue  # carried cargo is kinematic; forces ignored anyway
		if body is RigidBody3D:
			(body as RigidBody3D).apply_central_force(Vector3(0, 0, -PUSH_FORCE))
		elif body is CharacterBody3D:
			(body as CharacterBody3D).velocity.z -= PLAYER_PUSH_ACCEL * delta

func _register_push_zone(sensor: Area3D) -> void:
	sensor.body_entered.connect(func(b: Node3D):
		if b is PhysicsBody3D and not push_zone_bodies.has(b):
			push_zone_bodies.append(b))
	sensor.body_exited.connect(func(b: Node3D):
		push_zone_bodies.erase(b))

# ============================ cargo behaviors ============================

func _update_cargo_events(delta: float) -> void:
	if not cargo or not is_instance_valid(cargo):
		return
	var b := _behavior()
	if b == "bees":
		_bee_timer -= delta
		if _bee_timer <= 0.0:
			_bee_timer = randf_range(3.0, 5.0)
			_bee_burst()
	elif b == "haunted":
		if randf() < 0.6 * delta:
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 0.2), rng.randf_range(-1, 1)).normalized()
			cargo.apply_central_impulse(dir * 2.5)
	elif b == "vending":
		_vend_timer -= delta
		if _vend_timer <= 0.0:
			_vend_timer = randf_range(5.0, 8.0)
			_launch_can()
	elif b == "explode":
		if held_by and not exploded:
			carry_cumulative += delta
			if carry_cumulative >= 5.0:
				_explode_cargo()
	# Hard-landing damage on FREE cargo (sudden deceleration from a fast fall)
	if not cargo.freeze:
		var prev_vy: float = cargo.get_meta("prev_vy", 0.0)
		var cur_vy := cargo.linear_velocity.y
		if prev_vy < -8.0 and cur_vy > -1.0 and cargo.global_position.y < 4.0:
			cargo_value = maxf(cargo_value - 0.25, 0.0)
			cargo_damage_events += 1
			_caption("CARGO DAMAGED — VALUE %d%%" % int(cargo_value * 100))
		cargo.set_meta("prev_vy", cur_vy)
	# Destroyed when value hits 0 or falls off the map
	if cargo and is_instance_valid(cargo):
		if cargo.global_position.y < -8.0 or cargo_value <= 0.0:
			_destroy_cargo()

func _behavior() -> String:
	return CARGO_TYPES[cargo_type_key]["behavior"]

func _bee_burst() -> void:
	if bee_swarm and is_instance_valid(bee_swarm):
		bee_swarm.emitting = true
		get_tree().create_timer(1.2).timeout.connect(func():
			if bee_swarm and is_instance_valid(bee_swarm):
				bee_swarm.emitting = false)
	for pl in get_tree().get_nodes_in_group("players"):
		if pl is Node3D and is_instance_valid(pl):
			if (pl as Node3D).global_position.distance_to(cargo.global_position) <= 3.0 and pl.has_method("stun"):
				pl.stun(1.0)
	_caption("THE BEES ARE ANGRY")

func _launch_can() -> void:
	var can := RigidBody3D.new()
	can.mass = 0.3
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	col.shape = shape
	can.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.5
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.3, 0.2)
	mat.metallic = 0.6
	mi.material_override = mat
	can.add_child(mi)
	add_child(can)
	can.global_position = cargo.global_position + Vector3(0, 1.6, 0)
	var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.5, 1.2), rng.randf_range(-1, 1)).normalized()
	can.apply_central_impulse(dir * 6.0)
	can.set_meta("lifetime", 8.0)
	var area := Area3D.new()
	var acol := CollisionShape3D.new()
	var ashape := SphereShape3D.new()
	ashape.radius = 0.55
	acol.shape = ashape
	area.add_child(acol)
	can.add_child(area)
	area.body_entered.connect(func(body: Node3D):
		if body != can and body.is_in_group("players") and body.has_method("stun"):
			body.stun(0.5)
			can.queue_free())
	can_projectiles.append(can)
	_caption("VENDING MACHINE RAGE — INCOMING CAN")

func _update_projectiles(delta: float) -> void:
	for i in range(can_projectiles.size() - 1, -1, -1):
		var c := can_projectiles[i]
		if not is_instance_valid(c) or c.global_position.y < -8.0:
			can_projectiles.remove_at(i)
			continue
		var life: float = c.get_meta("lifetime", 8.0) - delta
		if life <= 0.0:
			c.queue_free()
			can_projectiles.remove_at(i)
		else:
			c.set_meta("lifetime", life)

func _explode_cargo() -> void:
	exploded = true
	_caption("THE CAKE EXPLODED")
	for pl in get_tree().get_nodes_in_group("players"):
		if pl is Node3D and (pl as Node3D).global_position.distance_to(cargo.global_position) <= 5.0 and pl.has_method("stun"):
			pl.stun(1.5)
	if cargo and is_instance_valid(cargo):
		cargo.apply_central_impulse(Vector3(0, 12, 0))
		cargo_value = maxf(cargo_value - 0.4, 0.0)

func _destroy_cargo() -> void:
	_finish_round(0, "CARGO DESTROYED", Color("ff7070"))
	if cargo and is_instance_valid(cargo):
		cargo.queue_free()
	cargo = null

# ============================ grab / throw ============================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var pause_menu = load("res://scripts/PauseMenu.gd")
		pause_menu.create(self, Callable())
		get_viewport().set_input_as_handled()
		return
	if round_active and event.is_action_pressed("action"):
		_try_grab_or_throw()
		get_viewport().set_input_as_handled()

func _try_grab_or_throw() -> void:
	if not player or not is_instance_valid(player):
		return
	if held_by:
		_throw_cargo()
		return
	if not cargo or not is_instance_valid(cargo):
		return
	if player.global_position.distance_to(cargo.global_position) <= GRAB_RANGE:
		_grab_cargo()

func _grab_cargo() -> void:
	held_by = player
	cargo.freeze = true
	cargo.set_collision_layer_value(1, false)
	cargo.set_collision_mask_value(1, false)
	if "carry_slowdown" in player:
		player.carry_slowdown = 0.7
	if "boost_locked" in player:
		player.boost_locked = true
	_caption("CARRYING %s — E TO THROW" % CARGO_TYPES[cargo_type_key]["label"].to_upper())

func _throw_cargo() -> void:
	var forward := Vector3(0, 0, 1)
	var cam := get_viewport().get_camera_3d()
	if cam:
		forward = -cam.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
	_release_carried_cargo()
	cargo.apply_central_impulse(forward * THROW_FORCE + Vector3(0, 2.5, 0))
	cargo.set_meta("prev_vy", 0.0)
	_caption("THROWN!")

func _release_carried_cargo() -> void:
	if held_by and is_instance_valid(held_by):
		if "carry_slowdown" in held_by:
			held_by.carry_slowdown = 1.0
		if "boost_locked" in held_by:
			held_by.boost_locked = false
	held_by = null
	if cargo and is_instance_valid(cargo):
		cargo.freeze = false
		cargo.set_collision_layer_value(1, true)
		cargo.set_collision_mask_value(1, true)

# ============================ carry ============================

func _update_carry() -> void:
	if not held_by:
		return
	if not cargo or not is_instance_valid(cargo) or not is_instance_valid(held_by):
		_release_carried_cargo()
		return
	var cam := get_viewport().get_camera_3d()
	var forward := Vector3(0, 0, 1)
	if cam:
		forward = -cam.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()
	var target: Vector3 = held_by.global_position + forward * 1.4 + Vector3(0, 1.2, 0)
	cargo.global_position = cargo.global_position.lerp(target, 0.35)

# ============================ delivery + scoring ============================

func _on_delivery_body_entered(body: Node3D) -> void:
	if not round_active or delivered_this_round:
		return
	if cargo and is_instance_valid(cargo) and body == cargo:
		_score_delivery()

func _score_delivery() -> void:
	if delivered_this_round:
		return
	delivered_this_round = true
	var info: Dictionary = CARGO_TYPES[cargo_type_key]
	var score: int = info["value"]
	var notes: Array[String] = []
	if cargo_damage_events == 0 and not exploded:
		score = int(score * 1.5)
		notes.append("GENTLE +50%")
	if ROUND_TIME - remaining_time < 30.0:
		score = int(score * 1.25)
		notes.append("SPEED +25%")
	var helpers := 0
	for pl in get_tree().get_nodes_in_group("players"):
		if pl is Node3D and (pl as Node3D).global_position.distance_to(cargo.global_position) <= COOP_RADIUS:
			helpers += 1
	if helpers >= 2:
		score = int(score * 2.0)
		notes.append("CO-OP x2")
	if notes.is_empty():
		notes.append("NO BONUS")
	score = int(score * cargo_value)
	_release_carried_cargo()
	if cargo and is_instance_valid(cargo):
		cargo.freeze = true  # park delivered cargo in the zone
	_finish_round(score, "DELIVERED  %s" % "  ".join(notes), Color("a8ffbd"))

# ============================ level building ============================

func _build_static_level() -> void:
	var floor_node := StaticBody3D.new()
	floor_node.name = "Floor"
	add_child(floor_node)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60, 0.2, 60)
	col.shape = shape
	floor_node.add_child(col)
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(60, 0.2, 60)
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.15, 0.12)
	mat.roughness = 0.9
	mesh_inst.material_override = mat
	floor_node.add_child(mesh_inst)
	# Perimeter walls (keep cargo on the map)
	for w in [
		{"pos": Vector3(0, 1, -30), "size": Vector3(60, 2, 1)},
		{"pos": Vector3(0, 1, 30), "size": Vector3(60, 2, 1)},
		{"pos": Vector3(-30, 1, 0), "size": Vector3(1, 2, 60)},
		{"pos": Vector3(30, 1, 0), "size": Vector3(1, 2, 60)},
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
	# Delivery zone (Area3D) at far end
	var zone := Area3D.new()
	delivery_zone = zone
	zone.position = Vector3(0, 1, DELIVERY_Z)
	add_child(zone)
	var zcol := CollisionShape3D.new()
	var zshape := BoxShape3D.new()
	zshape.size = Vector3(8, 4, 8)
	zcol.shape = zshape
	zone.add_child(zcol)
	var zmesh := MeshInstance3D.new()
	var zbox := BoxMesh.new()
	zbox.size = Vector3(8, 0.05, 8)
	zmesh.mesh = zbox
	var zmat := StandardMaterial3D.new()
	zmat.albedo_color = Color(0.16, 1.0, 0.42, 0.35)
	zmat.emission_enabled = true
	zmat.emission = Color("2aff6a")
	zmat.emission_energy_multiplier = 1.2
	zmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zmesh.material_override = zmat
	zmesh.position = Vector3(0, -0.85, 0)
	zone.add_child(zmesh)
	var zlabel := _make_billboard_label("DELIVER HERE", 30)
	zlabel.position = Vector3(0, 3.0, 0)
	zone.add_child(zlabel)
	zone.body_entered.connect(_on_delivery_body_entered)

func _clear_round_nodes() -> void:
	_release_carried_cargo()
	if cargo and is_instance_valid(cargo):
		cargo.queue_free()
	cargo = null
	bee_swarm = null
	for n in terrain_nodes:
		if is_instance_valid(n):
			n.queue_free()
	terrain_nodes.clear()
	push_zone_bodies.clear()
	pendulums.clear()
	can_projectiles.clear()

func _build_terrain(kind: String) -> void:
	match kind:
		"pendulum_gates":
			# Swinging wrecking boxes on pivots above the route
			for i in range(5):
				var pivot := AnimatableBody3D.new()
				pivot.position = Vector3(0, 3.4, -14.0 + i * 6.0)
				add_child(pivot)
				terrain_nodes.append(pivot)
				var arm := Node3D.new()
				arm.position = Vector3(0, -1.7, 0)
				pivot.add_child(arm)
				var box := _make_obstacle(Color(0.3, 0.35, 0.5), Vector3(1.6, 1.6, 1.6), Vector3.ZERO)
				arm.add_child(box)
				pendulums.append({
					"pivot": pivot, "speed": 1.6 + i * 0.25,
					"phase": i * 1.3, "amp": 1.05,
				})
			_caption("SWINGING GATES — TIME YOUR RUNS")
		"conveyor_belt":
			# Visually distinct belt strips pushing everything the WRONG way
			for i in range(6):
				var belt := _make_obstacle(Color(0.25, 0.25, 0.32), Vector3(10, 0.3, 3), Vector3(0, 0.15, -14.0 + i * 4.2))
				add_child(belt)
				terrain_nodes.append(belt)
			var sensor := _make_sensor_area(Vector3(0, 0.8, -8.0), Vector3(10, 1.6, 24.0))
			add_child(sensor)
			terrain_nodes.append(sensor)
			_register_push_zone(sensor)
			_caption("CONVEYOR — WRONG WAY!")
		"wrong_way_escalator":
			# Tilted ramp whose surface drags everything back toward spawn
			var ramp := _make_obstacle(Color(0.35, 0.3, 0.25), Vector3(10, 0.4, 14), Vector3(0, 1.2, -6.0))
			ramp.rotation.x = deg_to_rad(-8.0)
			add_child(ramp)
			terrain_nodes.append(ramp)
			var sensor := _make_sensor_area(Vector3(0, 2.4, -6.0), Vector3(10, 3.0, 14))
			add_child(sensor)
			terrain_nodes.append(sensor)
			_register_push_zone(sensor)
			_caption("WRONG-WAY ESCALATOR")
		"flat_gauntlet":
			for i in range(14):
				var px := rng.randf_range(-12, 12)
				var pz := rng.randf_range(-18, 14)
				var box := _make_obstacle(Color(0.3, 0.3, 0.35), Vector3(1.6, 2.4, 1.6), Vector3(px, 1.2, pz))
				add_child(box)
				terrain_nodes.append(box)
			_caption("GAUNTLET — DODGE THE CRATES")

func _make_sensor_area(pos: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	area.position = pos
	return area

func _make_obstacle(color: Color, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	body.add_child(mi)
	body.position = pos
	return body

func _spawn_cargo(type_key: String) -> void:
	var info: Dictionary = CARGO_TYPES[type_key]
	var c := RigidBody3D.new()
	cargo = c
	c.mass = info["mass"]
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = info["size"]
	col.shape = shape
	c.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = info["size"]
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = info["color"]
	mat.emission_enabled = true
	mat.emission = info["color"] * 0.25
	mi.material_override = mat
	c.add_child(mi)
	var label := _make_billboard_label(info["label"], 22)
	label.position = Vector3(0, info["size"].y * 0.5 + 0.7, 0)
	c.add_child(label)
	# Godot 4.7 RigidBody3D has no ccd_enabled property. The cargo is slow
	# enough for discrete collision; its fall/damage logic handles the rest.
	add_child(c)
	c.global_position = Vector3(0, 1.2, CARGO_SPAWN_Z)
	c.set_meta("prev_vy", 0.0)
	if info["behavior"] == "bees":
		bee_swarm = _make_bee_swarm()
		c.add_child(bee_swarm)

func _make_bee_swarm() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 1.0
	p.explosiveness = 0.9
	p.emitting = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	p.process_material = mat
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.12, 0.12)
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(1.0, 0.9, 0.2)
	mmat.emission_enabled = true
	mmat.emission = Color(1.0, 0.85, 0.1)
	mmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mmat
	p.draw_pass_1 = mesh
	return p

func _make_billboard_label(text: String, font_size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1, 1, 1, 0.9)
	l.no_depth_test = true
	l.outline_size = 8
	return l

# ============================ player / hud ============================

func _spawn_player() -> void:
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if player_scene:
		var p = player_scene.instantiate()
		p.position = Vector3(0, 1.5, CARGO_SPAWN_Z - 2.0)
		p.player_display_name = "Hauler"
		add_child(p)
		if "suppress_action_jump" in p:
			p.suppress_action_jump = true
		# Phase 7A: the shared mount wires joystick/actions directly to p.
		var mc_script7 = load("res://scripts/MobileControls.gd")
		if mc_script7 and mc_script7.has_method("mount_for_mode"):
			mc_script7.mount_for_mode(self, p)


func _find_player() -> Node3D:
	for n in get_children():
		if n.is_in_group("players"):
			return n
	return null

func _make_mode_hud() -> void:
	var hud_script = load("res://scripts/ModeHUD.gd")
	var hud = CanvasLayer.new()
	mode_hud = hud
	if hud_script:
		hud.set_script(hud_script)
		add_child(hud)
		hud.configure("HAULED", "HAUL THE HOSTILE CARGO TO THE GREEN ZONE — E: GRAB/THROW", ROUND_TIME)
	var overlay_script = load("res://scripts/SubtitleOverlay.gd")
	if overlay_script and overlay_script.has_method("mount"):
		overlay_script.mount(hud)
	var banner := Label.new()
	banner.name = "RoundBanner"
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.anchor_top = 0.3
	banner.anchor_bottom = 0.3
	banner.offset_left = -320
	banner.offset_right = 320
	banner.offset_top = -40
	banner.offset_bottom = 40
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 22)
	banner.add_theme_color_override("font_color", Color("ff9a1a"))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner.add_theme_constant_override("outline_size", 6)
	banner.modulate.a = 0.0
	hud.add_child(banner)
	round_banner = banner

func _show_banner(text: String, color: Color = Color("ff9a1a")) -> void:
	if not round_banner:
		return
	round_banner.text = text
	round_banner.add_theme_color_override("font_color", color)
	round_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(round_banner, "modulate:a", 0.0, 0.8)

func _caption(text: String) -> void:
	var cap = get_tree().get_first_node_in_group("subtitle_captions")
	if cap and cap.has_method("show_caption"):
		cap.show_caption(text)

func _terrain_label(kind: String) -> String:
	match kind:
		"pendulum_gates":
			return "SWINGING GATES — TIME YOUR RUNS"
		"conveyor_belt":
			return "CONVEYOR — WRONG WAY!"
		"wrong_way_escalator":
			return "WRONG-WAY ESCALATOR"
		"flat_gauntlet":
			return "GAUNTLET — DODGE THE CRATES"
	return ""
