# ShopSeek.gd — Phase 6B supermarket hide-and-seek / shopper fallback
extends Node3D

enum Role { SHOPPER, HIDER, SEEKER }

const ROUND_TIME := 60.0
const DISGUISE_FREEZE := 2.0
const DISGUISE_SPEED := 0.5
const INTERACT_RANGE := 2.6
const SCAN_COOLDOWN := 5.0
const SHOPPING_LIST_SIZE := 5
const SHELF_COUNT := 7
const PROP_COUNT := 24

const PROP_TYPES: Array[Dictionary] = [
	{"id": "cereal", "label": "CEREAL", "shape": "box", "color": Color("ff9a1a")},
	{"id": "milk", "label": "MILK", "shape": "carton", "color": Color("e8f4ff")},
	{"id": "avocado", "label": "AVOCADO", "shape": "avocado", "color": Color("78b84b")},
	{"id": "soup", "label": "SOUP CAN", "shape": "can", "color": Color("ff5963")},
	{"id": "bread", "label": "BREAD", "shape": "bread", "color": Color("d89b59")},
	{"id": "detergent", "label": "DETERGENT", "shape": "bottle", "color": Color("57d7ff")},
	{"id": "watermelon", "label": "WATERMELON", "shape": "melon", "color": Color("3fbd69")},
	{"id": "frozen_pizza", "label": "FROZEN PIZZA", "shape": "pizza", "color": Color("ffd65c")},
]

var remaining_time := ROUND_TIME
var player: CharacterBody3D
var mode_hud: CanvasLayer
var camera: Camera3D
var guard: CharacterBody3D
var guard_waypoints: Array[Vector3] = []
var guard_waypoint_index := 0
var guard_touch_cooldown := 0.0
var disguise_props: Array[Area3D] = []
var role_states: Dictionary = {}
var shopping_list := PackedStringArray()
var collected_items := PackedStringArray()
var current_role := Role.SHOPPER
var disguised := false
var disguise_lock_timer := 0.0
var disguise_visual: Node3D
var disguise_source: Area3D
var scan_cooldown := 0.0
var scan_timer := 0.0
var round_over := false
var shelves_built := 0
var section_names := PackedStringArray()
var camera_follow := Vector3.ZERO
var banner: Label

func _ready() -> void:
	camera = get_node_or_null("Camera3D")
	_build_supermarket()
	_spawn_disguise_props()
	_spawn_player()
	_spawn_security_guard()
	_build_shopping_list()
	_make_mode_hud()
	_assign_offline_or_network_role()
	if camera:
		camera_follow = camera.global_position
	print("[SHOP&SEEK] Phase 6B ready: %d shelves, %d disguises" % [shelves_built, disguise_props.size()])

func _process(delta: float) -> void:
	if round_over:
		_update_camera(delta)
		return
	remaining_time = maxf(remaining_time - delta, 0.0)
	scan_cooldown = maxf(scan_cooldown - delta, 0.0)
	scan_timer = maxf(scan_timer - delta, 0.0)
	guard_touch_cooldown = maxf(guard_touch_cooldown - delta, 0.0)
	_update_disguise(delta)
	_update_guard(delta)
	_update_camera(delta)
	_update_hud()
	if current_role == Role.SHOPPER and collected_items.size() >= shopping_list.size():
		_finish_round(true, "LIST COMPLETE — CLOCKED OUT!")
	elif remaining_time <= 0.0:
		var won := current_role == Role.HIDER and disguised
		_finish_round(won, "LAST HIDER STANDING!" if won else "STORE CLOSED — TIME UP")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var pause_menu = load("res://scripts/PauseMenu.gd")
		pause_menu.create(self, Callable())
		get_viewport().set_input_as_handled()

func _assign_offline_or_network_role() -> void:
	var network := get_node_or_null("/root/Network")
	if network and network.peer:
		# Multiplayer-ready state only. Authority/role replication remains a real-peer task.
		assign_role(player, Role.HIDER)
	else:
		assign_role(player, Role.SHOPPER)

func assign_role(body: Node3D, role: int) -> void:
	if not body:
		return
	role_states[body.get_instance_id()] = role
	if body == player:
		current_role = role as Role
		if role != Role.HIDER and disguised:
			_exit_disguise()
		_set_seeker_vest(role == Role.SEEKER)
		if "suppress_action_jump" in player:
			player.suppress_action_jump = role != Role.SEEKER
		if "suppress_sabotage" in player:
			player.suppress_sabotage = true
		_show_banner(_role_label(role), _role_color(role))

func _role_label(role: int) -> String:
	match role:
		Role.HIDER:
			return "HIDER — E NEAR A PRODUCT TO DISGUISE"
		Role.SEEKER:
			return "SEEKER — Q SCANS MOVING PRODUCTS"
	return "SHOPPER — COLLECT THE FIVE LIST ITEMS"

func _role_color(role: int) -> Color:
	return Color("a8ffbd") if role == Role.HIDER else (Color("ff5963") if role == Role.SEEKER else Color("ffcf55"))

func _toggle_interaction() -> void:
	if round_over or not player:
		return
	if current_role == Role.HIDER:
		if disguised:
			_exit_disguise()
		else:
			var prop := _nearest_prop()
			if prop:
				_enter_disguise(prop)
			else:
				_caption("GET CLOSER TO A PRODUCT")
	elif current_role == Role.SHOPPER:
		var prop := _nearest_prop()
		if prop:
			_try_collect_prop(prop)

func _nearest_prop() -> Area3D:
	var nearest: Area3D
	var best := INTERACT_RANGE
	for prop in disguise_props:
		if not is_instance_valid(prop):
			continue
		var distance := player.global_position.distance_to(prop.global_position)
		if distance < best:
			best = distance
			nearest = prop
	return nearest

func _enter_disguise(prop: Area3D) -> void:
	disguised = true
	disguise_source = prop
	disguise_lock_timer = DISGUISE_FREEZE
	player.set_can_move(false)
	player.carry_slowdown = DISGUISE_SPEED
	if player.model_parent:
		player.model_parent.visible = false
	var source_visual := prop.get_node_or_null("Visual")
	if source_visual:
		disguise_visual = source_visual.duplicate()
		disguise_visual.name = "ActiveDisguise"
		player.add_child(disguise_visual)
		disguise_visual.position = Vector3(0, 0.15, 0)
	_caption("DISGUISED — HOLD STILL 2 SECONDS")

func _exit_disguise() -> void:
	disguised = false
	disguise_lock_timer = 0.0
	disguise_source = null
	if player:
		player.set_can_move(true)
		player.carry_slowdown = 1.0
		if player.model_parent:
			player.model_parent.visible = true
	if disguise_visual and is_instance_valid(disguise_visual):
		disguise_visual.queue_free()
	disguise_visual = null
	_caption("DISGUISE OFF — RUN!")

func _update_disguise(delta: float) -> void:
	if not disguised or not player:
		return
	if disguise_lock_timer > 0.0:
		disguise_lock_timer = maxf(disguise_lock_timer - delta, 0.0)
		if disguise_lock_timer <= 0.0:
			player.set_can_move(true)
			player.carry_slowdown = DISGUISE_SPEED
			_caption("DISGUISE MOBILE — HALF SPEED")
	if disguise_visual and is_instance_valid(disguise_visual):
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		var tell := 0.025 + clampf(speed / player.max_speed, 0.0, 1.0) * 0.09
		disguise_visual.rotation.z = sin(Time.get_ticks_msec() * 0.009) * tell
		disguise_visual.scale.y = 1.0 + sin(Time.get_ticks_msec() * 0.012) * tell

func try_scan() -> bool:
	if current_role != Role.SEEKER or scan_cooldown > 0.0:
		return false
	scan_cooldown = SCAN_COOLDOWN
	scan_timer = 1.0
	for prop in disguise_props:
		if is_instance_valid(prop):
			var visual := prop.get_node_or_null("Visual")
			if visual:
				var tween := visual.create_tween()
				tween.tween_property(visual, "scale", Vector3.ONE * 1.18, 0.12)
				tween.tween_property(visual, "scale", Vector3.ONE, 0.25)
	_caption("SCAN! MOVEMENT TELLS ON HIDERS")
	return true

func _on_mode_sabotage() -> void:
	if current_role == Role.SEEKER:
		try_scan()

func _set_seeker_vest(enabled: bool) -> void:
	if not player:
		return
	var existing := player.get_node_or_null("SeekerVest")
	if existing:
		existing.queue_free()
	if not enabled:
		return
	var vest := MeshInstance3D.new()
	vest.name = "SeekerVest"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.62
	mesh.bottom_radius = 0.68
	mesh.height = 0.7
	vest.mesh = mesh
	vest.position = Vector3(0, 0.65, 0)
	vest.material_override = _material(Color("ff3333"), 0.25, true)
	player.add_child(vest)

func _build_shopping_list() -> void:
	shopping_list.clear()
	for i in range(SHOPPING_LIST_SIZE):
		shopping_list.append(PROP_TYPES[i]["id"])

func _try_collect_prop(prop: Area3D) -> bool:
	if not is_instance_valid(prop):
		return false
	var kind := String(prop.get_meta("kind", ""))
	if not shopping_list.has(kind) or collected_items.has(kind):
		_caption("NOT ON THE LIST")
		return false
	collected_items.append(kind)
	disguise_props.erase(prop)
	prop.queue_free()
	_caption("GOT %s — %d/%d" % [_prop_label(kind), collected_items.size(), shopping_list.size()])
	return true

func _on_prop_body_entered(body: Node3D, prop: Area3D) -> void:
	if body == player and current_role == Role.SHOPPER:
		_try_collect_prop(prop)

func _prop_label(kind: String) -> String:
	for info in PROP_TYPES:
		if info["id"] == kind:
			return info["label"]
	return kind.to_upper()

func _build_supermarket() -> void:
	_make_static_box("Floor", Vector3(0, -0.1, 0), Vector3(48, 0.2, 52), Color("30323a"))
	for wall in [
		{"pos": Vector3(0, 1.5, -26), "size": Vector3(48, 3, 0.5)},
		{"pos": Vector3(0, 1.5, 26), "size": Vector3(48, 3, 0.5)},
		{"pos": Vector3(-24, 1.5, 0), "size": Vector3(0.5, 3, 52)},
		{"pos": Vector3(24, 1.5, 0), "size": Vector3(0.5, 3, 52)},
	]:
		_make_static_box("Wall", wall["pos"], wall["size"], Color("1c1c2e"))

	for i in range(SHELF_COUNT):
		var x := -15.0 + i * 5.0
		_make_shelf_aisle(i, Vector3(x, 0, -1.0))
		shelves_built += 1

	section_names = PackedStringArray(["CHECKOUT", "PRODUCE", "FROZEN"])
	for i in range(4):
		_make_static_box("Checkout_%d" % i, Vector3(-15.0 + i * 5.0, 0.55, 21), Vector3(3.5, 1.1, 1.2), Color("6d4c41"))
		_make_sign("CHECKOUT", Vector3(-7.5, 3.2, 23.5), Color("ff9a1a"))
	for i in range(4):
		var table := _make_static_box("Produce_%d" % i, Vector3(-19 + (i % 2) * 4, 0.6, -18 + int(i / 2) * 4), Vector3(3, 1.2, 3), Color("315c3b"))
		table.rotation.y = i * 0.17
	_make_sign("FRESH PRODUCE", Vector3(-18, 3.2, -23), Color("78d86b"))
	for i in range(5):
		_make_static_box("Freezer_%d" % i, Vector3(21.5, 1.4, -17 + i * 7), Vector3(1.2, 2.8, 5.5), Color("6dbce8"), 0.35)
	_make_sign("FROZEN", Vector3(21, 3.2, -23), Color("57d7ff"))

func _make_shelf_aisle(index: int, pos: Vector3) -> void:
	var shelf := _make_static_box("Shelf_%d" % index, pos + Vector3(0, 1.15, 0), Vector3(1.0, 2.3, 30), Color("594b3e"))
	for level in range(3):
		var lip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.35, 0.08, 30)
		lip.mesh = mesh
		lip.position = Vector3(0, -0.85 + level * 0.8, 0)
		lip.material_override = _material(Color("c9a66b"))
		shelf.add_child(lip)

func _spawn_disguise_props() -> void:
	for i in range(PROP_COUNT):
		var info: Dictionary = PROP_TYPES[i % PROP_TYPES.size()]
		var aisle := i % 6
		var row := int(i / 6)
		var side := -1.0 if row % 2 == 0 else 1.0
		var prop := Area3D.new()
		prop.name = "Disguise_%02d_%s" % [i, info["id"]]
		prop.add_to_group("shop_disguises")
		prop.set_meta("kind", info["id"])
		prop.set_meta("variant_id", "%s_%02d" % [info["id"], i])
		prop.position = Vector3(-12.5 + aisle * 5.0, 0.65, -18.0 + row * 10.0 + side * (i % 3))
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.75
		collision.shape = shape
		prop.add_child(collision)
		var visual := _make_prop_visual(info, i, true)
		prop.add_child(visual)
		prop.body_entered.connect(_on_prop_body_entered.bind(prop))
		add_child(prop)
		disguise_props.append(prop)

func _make_prop_visual(info: Dictionary, variant: int, with_label: bool) -> Node3D:
	var root_node := Node3D.new()
	root_node.name = "Visual"
	var mesh_node := MeshInstance3D.new()
	var shape_id := String(info["shape"])
	match shape_id:
		"can", "bottle":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.22 + (variant % 3) * 0.03
			cylinder.bottom_radius = 0.25
			cylinder.height = 0.75 + (variant % 2) * 0.15
			mesh_node.mesh = cylinder
		"avocado", "melon":
			var sphere := SphereMesh.new()
			sphere.radius = 0.38
			sphere.height = 0.75
			mesh_node.mesh = sphere
			mesh_node.scale = Vector3(0.75, 1.15, 0.9) if shape_id == "avocado" else Vector3(1.15, 0.9, 1.0)
		"pizza":
			var pizza := CylinderMesh.new()
			pizza.top_radius = 0.48
			pizza.bottom_radius = 0.48
			pizza.height = 0.13
			mesh_node.mesh = pizza
			mesh_node.rotation.x = PI * 0.5
		"bread":
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.3
			capsule.height = 0.8
			mesh_node.mesh = capsule
			mesh_node.rotation.z = PI * 0.5
		_:
			var box := BoxMesh.new()
			box.size = Vector3(0.55 + (variant % 2) * 0.12, 0.8, 0.3 + (variant % 3) * 0.05)
			mesh_node.mesh = box
	mesh_node.material_override = _material(info["color"].lightened((variant % 4) * 0.035), 0.45)
	root_node.add_child(mesh_node)
	if with_label:
		var label := Label3D.new()
		label.text = "%s %02d" % [info["label"], variant + 1]
		label.position = Vector3(0, 0.85, 0)
		label.font_size = 18
		label.outline_size = 6
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		root_node.add_child(label)
	return root_node

func _spawn_player() -> void:
	var player_scene = load("res://scenes/PlayerChair.tscn")
	if not player_scene:
		return
	player = player_scene.instantiate()
	player.position = Vector3(0, 0.8, 20)
	player.player_display_name = "Weekend Warrior"
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		player.player_display_name = gm.player_name
		player.player_color = gm.player_color
	add_child(player)
	player.suppress_action_jump = true
	player.interaction_requested.connect(_toggle_interaction)
	player.sabotage_requested.connect(_on_mode_sabotage)
	var controls = load("res://scripts/MobileControls.gd")
	if controls and controls.has_method("mount_for_mode"):
		controls.mount_for_mode(self, player)

func _spawn_security_guard() -> void:
	guard = CharacterBody3D.new()
	guard.name = "SecurityGuard"
	guard.position = Vector3(-18, 0.9, 18)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 1.8
	collision.shape = shape
	guard.add_child(collision)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.55
	mesh.height = 1.8
	body.mesh = mesh
	body.material_override = _material(Color("263238"), 0.35)
	guard.add_child(body)
	var beacon := OmniLight3D.new()
	beacon.light_color = Color("ff5963")
	beacon.light_energy = 1.2
	beacon.omni_range = 4.0
	beacon.position = Vector3(0, 1.2, 0)
	guard.add_child(beacon)
	var label := Label3D.new()
	label.text = "SECURITY"
	label.position = Vector3(0, 1.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.outline_size = 7
	guard.add_child(label)
	add_child(guard)
	guard_waypoints = [Vector3(-18, 0.9, 18), Vector3(18, 0.9, 18), Vector3(18, 0.9, -20), Vector3(-18, 0.9, -20)]

func _update_guard(_delta: float) -> void:
	if not guard or not is_instance_valid(guard):
		return
	var target := guard_waypoints[guard_waypoint_index]
	var direction := target - guard.global_position
	direction.y = 0.0
	if direction.length() < 1.0:
		guard_waypoint_index = (guard_waypoint_index + 1) % guard_waypoints.size()
	else:
		guard.velocity = direction.normalized() * 3.2
		guard.move_and_slide()
	if player and guard_touch_cooldown <= 0.0 and guard.global_position.distance_to(player.global_position) < 1.5:
		guard_touch_cooldown = 3.0
		player.stun(1.0)
		remaining_time = maxf(remaining_time - 3.0, 0.0)
		_caption("SECURITY CHECK! −3 SECONDS")

func _update_camera(delta: float) -> void:
	if not camera or not player or not is_instance_valid(player):
		return
	var velocity_flat := Vector3(player.velocity.x, 0, player.velocity.z)
	var desired := player.global_position + Vector3(0, 8.5, 11.5) - velocity_flat * 0.12
	camera_follow = camera_follow.lerp(desired, 1.0 - exp(-6.5 * delta))
	camera.global_position = camera_follow
	camera.look_at(player.global_position + velocity_flat * 0.18)

func _make_mode_hud() -> void:
	var hud_script = load("res://scripts/ModeHUD.gd")
	mode_hud = CanvasLayer.new()
	if hud_script:
		mode_hud.set_script(hud_script)
		add_child(mode_hud)
		mode_hud.configure("SHOP & SEEK", "SHOPPER: FIND FIVE LIST ITEMS • E INTERACTS", ROUND_TIME)
	var overlay_script = load("res://scripts/SubtitleOverlay.gd")
	if overlay_script and overlay_script.has_method("mount"):
		overlay_script.mount(mode_hud)
	banner = Label.new()
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.anchor_top = 0.24
	banner.anchor_bottom = 0.24
	banner.offset_left = -390
	banner.offset_right = 390
	banner.offset_top = -32
	banner.offset_bottom = 32
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 20)
	banner.add_theme_constant_override("outline_size", 6)
	mode_hud.add_child(banner)

func _update_hud() -> void:
	if not mode_hud or not mode_hud.has_method("update_state"):
		return
	var progress := 0.0
	var status := _role_label(current_role)
	var color := _role_color(current_role)
	if current_role == Role.SHOPPER:
		progress = float(collected_items.size()) / float(shopping_list.size())
		var remaining: Array[String] = []
		for item in shopping_list:
			if not collected_items.has(item):
				remaining.append(_prop_label(item))
		status = "LIST %d/5: %s" % [collected_items.size(), ", ".join(remaining)]
	elif current_role == Role.HIDER:
		progress = clampf((ROUND_TIME - remaining_time) / ROUND_TIME, 0.0, 1.0)
		status = "DISGUISED" if disguised else "EXPOSED — FIND A PRODUCT"
	else:
		progress = 1.0 - scan_cooldown / SCAN_COOLDOWN
		status = "SCAN READY (Q)" if scan_cooldown <= 0.0 else "SCAN %.1fs" % scan_cooldown
	mode_hud.update_state(remaining_time, progress, status, color)

func _finish_round(success: bool, message: String) -> void:
	if round_over:
		return
	round_over = true
	if player:
		player.set_can_move(false)
	_show_banner(message, Color("a8ffbd") if success else Color("ff7070"))
	_caption(message)

func _show_banner(text: String, color: Color) -> void:
	if not banner:
		return
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.modulate.a = 1.0
	var tween := banner.create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(banner, "modulate:a", 0.0, 0.7)

func _caption(text: String) -> void:
	var cap := get_tree().get_first_node_in_group("subtitle_captions")
	if cap and cap.has_method("show_caption"):
		cap.show_caption(text)

func _make_static_box(node_name: String, pos: Vector3, size: Vector3, color: Color, alpha: float = 1.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = _material(Color(color, alpha), 0.72)
	body.add_child(mesh_node)
	add_child(body)
	return body

func _make_sign(text: String, pos: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 36
	label.outline_size = 10
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)

func _material(color: Color, roughness: float = 0.65, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = 0.8
	return mat
