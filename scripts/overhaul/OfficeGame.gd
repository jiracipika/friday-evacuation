extends Node3D
## One fixed-step simulation for humans, AI and all four party modes.
const Motor = preload("res://scripts/overhaul/ChairMotor.gd")
const Rig = preload("res://scripts/overhaul/VisualRig.gd")
const Course = preload("res://scripts/overhaul/RaceCourse.gd")
const Builder = preload("res://scripts/overhaul/CourseBuilder.gd")
const World = preload("res://scripts/overhaul/ModeWorld.gd")
const Rules = preload("res://scripts/overhaul/PartyRules.gd")
const Command = preload("res://scripts/overhaul/DrivingCommand.gd")
const Driver = preload("res://scripts/overhaul/DriverInput.gd")
const Rival = preload("res://scripts/overhaul/RivalDriver.gd")
const Kit = preload("res://scripts/overhaul/OfficeKit.gd")
const UI = preload("res://scripts/overhaul/OfficeUI.gd")
const Save = preload("res://scripts/overhaul/OverhaulSave.gd")
const A11y = preload("res://scripts/Accessibility.gd")
const Prefs = preload("res://scripts/InputPrefs.gd")
const Roster = preload("res://scripts/CharacterRoster.gd")
var session: Node
var local_id := 1
var authority := true
var mode := "evacuation"
var trial := false
var actors: Dictionary = {}
var identities: Dictionary = {}
var brains: Dictionary = {}
var commands: Dictionary = {}
var command_ages: Dictionary = {}
var pending_states: Array = []
var interpolation: Array = []
var predictions: Array = []
var course: Resource
var builder: RefCounted
var rules: RefCounted
var input := Driver.new()
var cargo: RigidBody3D
var seek_props: Array[Node3D] = []
var camera: Camera3D
var hud: Label
var objective: Label
var notice: Label
var meter: ProgressBar
var overlay: PanelContainer
var hud_root: Control
var dashboard: PanelContainer
var boost_panel: PanelContainer
var speed_panel: PanelContainer
var clock: Label
var boost_label: Label
var speed_label: Label
var countdown_card: PanelContainer
var countdown_label: Label
var shade: ColorRect
var touch_direction: HBoxContainer
var touch_actions: HBoxContainer
var result_box: VBoxContainer
var pause_box: VBoxContainer
var paused_local := false
var snapshot_clock := 0.0
var tick := 0
var received_tick := -1
var notice_time := 0.0
var frame_clock := 0.0
var ghost_frames: Array = []
var previous_ghost: Array = []
var ghost: Node3D
var ghost_index := 0
var results_shown := false
var effects_root: Node3D
var chef: Node3D
var cutter: MeshInstance3D
var pads: Array[MeshInstance3D] = []
var camera_yaw := 0.0
var test_bot_local := false
var reduced_motion := false
var high_contrast := false
var displayed_effects: Array = []
var disguises: Dictionary = {}
var checkpoint_marker: MeshInstance3D
var test_mode := "--test-mode" in OS.get_cmdline_user_args()
var helper_grid: AStarGrid2D
var helper_routes: Dictionary = {}

func _ready() -> void:
	session = get_node("/root/OfficeSession")
	mode = session.configuration.mode
	trial = bool(session.configuration.trial) and mode == "evacuation"
	authority = not session.active or multiplayer.is_server()
	local_id = multiplayer.get_unique_id() if session.active else 1
	session.game = self
	Prefs.refresh_cache()
	Prefs.apply_saved_bindings()
	_refresh_preferences()
	if not session.active: A11y.apply_time_scale()
	AudioManager.start_music("race")
	session.start_requested.connect(_rematch)
	session.message.connect(func(words):
		announce(words)
		if not session.active and not authority:
			_leave.call_deferred())
	if not InputMap.has_action("brake_drift"):
		InputMap.add_action("brake_drift")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("brake_drift", key)
		var trigger := InputEventJoypadMotion.new()
		trigger.axis = JOY_AXIS_TRIGGER_LEFT
		trigger.axis_value = 1
		InputMap.action_add_event("brake_drift", trigger)
	course = Course.new(session.configuration.layout)
	if mode == "evacuation":
		builder = Builder.new()
		builder.build(self, course, trial)
	else:
		World.build(self, mode)
	if session.active:
		for id in session.roster:
			_spawn(id, session.roster[id])
	else:
		_spawn(1, session.local_identity())
	if authority and not trial and mode in ["evacuation", "pizza", "hauled"]:
		var count := mini(int(session.configuration.bots), 8 - actors.size())
		for i in count:
			_spawn(-i - 1, _bot_identity(i))
	rules = Rules.new()
	rules.setup(self, mode)
	if cargo:
		cargo.freeze = not authority
		cargo.body_entered.connect(func(_body):
			if authority and rules.state.phase == "running" and cargo.linear_velocity.length() > 5:
				rules.state.cargo_health = maxf(0, rules.state.cargo_health - cargo.linear_velocity.length() * 0.7))
	_make_camera()
	_make_hud()
	_refresh_preferences()
	effects_root = Node3D.new()
	add_child(effects_root)
	if mode in ["evacuation", "seek", "hauled"]:
		checkpoint_marker = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 1.3
		ring.outer_radius = 1.48
		ring.rings = 20
		ring.ring_segments = 8
		checkpoint_marker.mesh = ring
		checkpoint_marker.material_override = Kit.material(Kit.ORANGE)
		add_child(checkpoint_marker)
	if mode in ["seek", "pizza"]:
		chef = Rig.new()
		add_child(chef)
		chef.configure("facilities_frank", {"shirt_color": "f7f6f2", "expression": "derpy"})
		if mode == "pizza":
			Kit.prop(chef, "chef_hat", Vector3(0, 1.7, 0), 0, false)
	if mode == "pizza":
		for pad in rules.state.pads:
			var marker := MeshInstance3D.new()
			var circle := CylinderMesh.new()
			circle.top_radius = 1.5
			circle.bottom_radius = 1.5
			circle.height = 0.04
			circle.radial_segments = 24
			marker.mesh = circle
			marker.position = pad.p
			marker.material_override = Kit.material(Kit.IVORY)
			add_child(marker)
			pads.append(marker)
		cutter = Kit.decor_box(self, Vector3(18, 0.12, 0.18), Vector3(9, 0.25, 0), Kit.ORANGE)
	if trial:
		previous_ghost = Save.ghost(course.record_key(session.identity_profile, true))
		if previous_ghost.size() > 1:
			ghost = Rig.new()
			add_child(ghost)
			ghost.configure(GameManager.selected_character_id, GameManager.get_character_design(), GameManager.selected_skin_id)
			for mesh in ghost.find_children("*", "MeshInstance3D", true, false):
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.25, 0.8, 0.82, 0.28)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.material_override = mat
	session.ready_in_game()
	announce("WASD steer · SPACE boost · SHIFT drift / brake · E hop / interact · Q item")

func _bot_identity(index: int) -> Dictionary:
	var character: Dictionary = Roster.CHARACTERS[(index + 7) % Roster.CHARACTERS.size()]
	return {"name": character.name, "character": character.id, "design": {}, "skin": "office_standard", "profile": ["balanced", "agile", "heavy"][index % 3], "ready": true}

func _spawn(id: int, identity: Dictionary) -> void:
	if actors.has(id):
		return
	var actor := Motor.new()
	actor.name = "Coworker_%s" % str(id).replace("-", "bot")
	actor.profile_id = identity.get("profile", "balanced")
	actor.peer_id = id
	actor.is_local = id == local_id
	actor.bot = id < 0
	actor.display_name = identity.name
	actor.position = course.spawn(actors.size()) if mode == "evacuation" else Vector3(-14 + actors.size() * 2, 0.7, -16)
	if mode == "pizza":
		var angle := actors.size() * 1.1
		actor.position = Vector3(cos(angle) * 7, 0.7, sin(angle) * 7)
	actor.spawn_point = actor.position
	add_child(actor)
	if mode == "hauled":
		actor.collision_mask = 5
	var visual := Rig.new()
	actor.visual_heading.add_child(visual)
	visual.configure(identity.character, identity.design, identity.skin)
	actor.visual = visual
	visual.reduced_motion = reduced_motion
	actor.motor_event.connect(_motor_event.bind(id))
	actors[id] = actor
	identities[id] = identity.duplicate(true)
	commands[id] = Command.make()
	command_ages[id] = 0.0
	if id < 0:
		var brain := Rival.new()
		brain.personality = -id
		brain.difficulty = int(session.configuration.difficulty)
		brains[id] = brain
	if id != local_id:
		var name_tag := Kit.text(actor, actor.display_name, Vector3(0, 2.1, 0), 24, Kit.INK)
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag.no_depth_test = false

func add_human(id: int) -> void:
	if actors.has(id):
		return
	if actors.size() >= 8:
		for candidate in actors.keys():
			if candidate < 0:
				remove_human(candidate)
				break
	_spawn(id, session.roster[id])
	rules.add_player(id)
	if mode == "evacuation" and rules.state.phase == "running":
		# Join at the last safe gate, with no race time advantage in rankings.
		actors[id].finish_time = -1
	announce(session.roster[id].name + " joined the office")

func remove_human(id: int) -> void:
	if not actors.has(id):
		return
	actors[id].queue_free()
	actors.erase(id)
	identities.erase(id)
	commands.erase(id)
	command_ages.erase(id)
	brains.erase(id)
	if rules:
		for key in ["players", "roles", "disguises", "caught", "collected", "cheese", "scan"]:
			rules.state[key].erase(id)
		rules.state.holders.erase(id)
		if mode == "seek" and not actors.is_empty():
			var has_seeker := false
			for role in rules.state.roles.values():
				has_seeker = has_seeker or role == "seeker"
			if not has_seeker:
				rules.state.roles[actors.keys()[0]] = "seeker"

func accept_command(id: int, cmd: Dictionary) -> void:
	if not actors.has(id) or int(cmd.seq) <= int(commands[id].seq) or int(cmd.seq) > int(commands[id].seq) + 600:
		return
	commands[id] = cmd
	command_ages[id] = 0

func _physics_process(delta: float) -> void:
	while not pending_states.is_empty():
		_receive(pending_states.pop_front())
	if not actors.has(local_id):
		return
	var cmd := input.read(camera, paused_local or rules.state.phase == "results")
	if test_bot_local:
		cmd = brains.get(local_id, Rival.new()).drive(actors[local_id], course, delta)
		input.sequence += 1
		cmd.seq = input.sequence
	if authority:
		commands[local_id] = cmd
		if paused_local and not session.active:
			return
		for id in actors:
			var actor = actors[id]
			var command: Dictionary = commands[id]
			if id < 0:
				command = _bot_command(id, delta)
			elif id != local_id:
				command_ages[id] += delta
				if command_ages[id] > 0.3:
					command = Command.make(Vector2.ZERO, false, false, false, false, int(command.seq))
			var active_actor: bool = rules.state.phase == "running" and rules.state.players[id].alive
			if rules.state.disguises.has(id) and command.move.length() > 0.2:
				rules.state.disguises.erase(id)
			actor.enabled = active_actor and not rules.state.disguises.has(id)
			if active_actor and actor.stun <= 0:
				rules.interact(id, command.hop, command.item)
			var motor_cmd := command.duplicate()
			if mode in ["hauled", "seek"]:
				motor_cmd.hop = false
			actor.step(motor_cmd, delta)
			commands[id].hop = false
			commands[id].item = false
		_bumps()
		rules.tick(delta)
		_world_rules(delta)
		tick += 1
		snapshot_clock += delta
		if snapshot_clock >= 0.05:
			snapshot_clock = 0
			session.publish(snapshot())
	else:
		session.submit(cmd)
		var actor = actors[local_id]
		actor.enabled = rules.state.phase == "running" and rules.state.players.get(local_id, {"alive": true}).alive and not rules.state.disguises.has(local_id)
		var motor_cmd := cmd.duplicate()
		if mode in ["hauled", "seek"]:
			motor_cmd.hop = false
		actor.step(motor_cmd, delta)
		predictions.append({"cmd": motor_cmd, "delta": delta})
		if predictions.size() > 120:
			predictions.pop_front()
	if trial and rules.state.phase == "running":
		frame_clock += delta
		if frame_clock >= 0.1:
			frame_clock = 0
			ghost_frames.append({"t": rules.elapsed, "p": actors[local_id].position, "f": actors[local_id].facing})

func _bot_command(id: int, delta: float) -> Dictionary:
	var actor = actors[id]
	if mode == "evacuation":
		return brains[id].drive(actor, course, delta)
	var target := Vector3.ZERO
	var interact := false
	if mode == "hauled":
		var holding: bool = rules.state.holders.has(id)
		var human = actors[local_id]
		if holding:
			target = human.position + Vector3(-1, 0, 0)
		else:
			target = cargo.position if rules.state.holders.has(local_id) else human.position + Vector3(id * 0.8, 0, 1.5)
			interact = actor.position.distance_to(cargo.position) < 2.5 and rules.state.holders.has(local_id) and rules.state.holders.size() < 2
		target = _helper_waypoint(id, actor.position, target)
	else:
		actor.desired_speed = [0.7, 0.85, 1.0][clampi(int(session.configuration.difficulty), 0, 2)]
		var index := (int(-id * 3) + int(rules.elapsed / 8)) % 12
		target = rules.state.pads[index].p
	var move := Vector2(target.x - actor.position.x, target.z - actor.position.z)
	return Command.make(move.normalized() if move.length() > 0.7 else Vector2.ZERO, false, false, interact or (mode == "pizza" and fmod(rules.elapsed + id, 12) < 0.025), mode == "pizza" and fmod(rules.elapsed + id, 15) < 0.025)

func _helper_waypoint(id: int, from: Vector3, goal: Vector3) -> Vector3:
	if not helper_grid:
		helper_grid = AStarGrid2D.new()
		helper_grid.region = Rect2i(0, 0, 31, 27)
		helper_grid.cell_size = Vector2.ONE * 1.5
		helper_grid.offset = Vector2(-22.5, -19.5)
		helper_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		helper_grid.update()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.65
		shape.height = 1.2
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = 1
		for x in 31:
			for z in 27:
				var p := helper_grid.get_point_position(Vector2i(x, z))
				query.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, 0.8, p.y))
				helper_grid.set_point_solid(Vector2i(x, z), not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty())
	var route: Dictionary = helper_routes.get(id, {"time": -INF, "path": PackedVector2Array()})
	if rules.elapsed - float(route.time) > 0.5:
		var a := Vector2i(((Vector2(from.x, from.z) - helper_grid.offset) / 1.5).round()).clamp(Vector2i.ZERO, Vector2i(30, 26))
		var b := Vector2i(((Vector2(goal.x, goal.z) - helper_grid.offset) / 1.5).round()).clamp(Vector2i.ZERO, Vector2i(30, 26))
		route.path = helper_grid.get_point_path(a, b, true)
		route.time = rules.elapsed
		helper_routes[id] = route
	var path: PackedVector2Array = route.path
	if path.size() > 1:
		var p := path[1]
		return Vector3(p.x, 0.6, p.y)
	return goal

func _bumps() -> void:
	var keys := actors.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a = actors[keys[i]]
			var b = actors[keys[j]]
			var diff: Vector3 = a.position - b.position
			if diff.length() < 0.82 and diff.length() > 0.01:
				var normal := Vector3(diff.x, 0, diff.z).normalized()
				var speed: float = maxf(0, (b.velocity - a.velocity).dot(normal))
				a.position += normal * 0.025
				b.position -= normal * 0.025
				if speed > 4:
					a.apply_hit(normal * speed * 0.5, 0.25)
					b.apply_hit(-normal * speed * 0.5, 0.25)

func _world_rules(delta: float) -> void:
	if rules.state.phase != "running":
		return
	if builder:
		for pickup in builder.pickups:
			if not pickup.active:
				pickup.timer -= delta
				pickup.active = pickup.timer <= 0
				continue
			for actor in actors.values():
				if actor.position.distance_to(pickup.position) < 1.3:
					if pickup.kind == "coffee":
						actor.boost_charge = minf(100, actor.boost_charge + 38)
					else:
						actor.item_kind = "coffee_spill" if (actor.checkpoint / 8) % 2 == 0 else "paper_jam"
					pickup.active = false
					pickup.timer = INF if trial else 8.0
					if actor.is_local:
						announce("COFFEE +38" if pickup.kind == "coffee" else "ITEM READY · Q to drop")
					break
		for hazard in builder.hazards:
			var p: Vector3 = hazard.base + Vector3(sin(rules.elapsed * 0.7 + hazard.phase) * 3, 0, 0)
			for actor in actors.values():
				if actor.position.distance_to(p) < 1.1:
					actor.apply_hit((actor.position - p).normalized() * 3, 0.35)
	for trap in rules.state.items:
		trap.life -= delta
		trap.armed -= delta
		if trap.armed > 0:
			continue
		for actor in actors.values():
			if actor.position.distance_to(trap.p) < 1.3:
				if actor.apply_hit(-actor.velocity.normalized() * 4, 0.6):
					trap.life = 0
	rules.state.items = rules.state.items.filter(func(item): return item.life > 0)
	for fort in rules.state.forts:
		fort.life -= delta
		if mode == "pizza" and fort.p.distance_to(rules.state.chef) < 2:
			rules.state.chef += (rules.state.chef - fort.p).normalized() * delta * 6
	rules.state.forts = rules.state.forts.filter(func(fort): return fort.life > 0)
	if mode == "seek":
		for id in rules.state.disguises.keys():
			if actors[id].velocity.length() > 1:
				rules.state.disguises.erase(id)

func snapshot() -> Dictionary:
	var states := {}
	for id in actors:
		states[id] = actors[id].snapshot()
	var pickup_states: Array = []
	if builder:
		for pickup in builder.pickups:
			pickup_states.append(pickup.active)
	return {"tick": tick, "actors": states, "identities": identities, "rules": rules.state.duplicate(true), "countdown": rules.countdown, "pickups": pickup_states}

func _receive(frame: Dictionary) -> void:
	# A routine frame can overtake the reliable late-join handshake.
	# Wait for the host to include us before replacing the local roster.
	if not frame.actors.has(local_id):
		return
	if int(frame.tick) <= received_tick:
		return
	received_tick = frame.tick
	for id in frame.identities:
		_spawn(id, frame.identities[id])
	for id in actors.keys():
		if not frame.actors.has(id):
			remove_human(id)
	rules.state = frame.rules
	rules.elapsed = float(rules.state.elapsed)
	rules.countdown = float(frame.countdown)
	if frame.actors.has(local_id):
		var authoritative: Dictionary = frame.actors[local_id]
		predictions = predictions.filter(func(p): return int(p.cmd.seq) > int(authoritative.seq))
		actors[local_id].restore(authoritative)
		for prediction in predictions:
			actors[local_id].step(prediction.cmd, prediction.delta, false)
	if builder:
		for i in mini(frame.pickups.size(), builder.pickups.size()):
			builder.pickups[i].active = bool(frame.pickups[i])
	frame["arrival"] = Time.get_ticks_msec() / 1000.0
	interpolation.append(frame)
	while interpolation.size() > 8:
		interpolation.pop_front()

func _process(delta: float) -> void:
	if not actors.has(local_id) or not rules:
		return
	if not authority:
		_interpolate()
	for id in actors:
		var actor = actors[id]
		actor.present(delta)
		actor.visual.visible = not rules.state.disguises.has(id)
		if rules.state.disguises.has(id):
			# Matching prop appears in the exact actor location on every peer.
			actor.visual.visible = false
	_camera(delta)
	if builder:
		builder.tick_visuals(rules.elapsed)
		checkpoint_marker.position = course.points[mini(actors[local_id].checkpoint + 1, course.points.size() - 1)] + Vector3(0, 0.1, 0)
		for room in builder.rooms:
			room.visible = absf(room.position.z - actors[local_id].position.z) < 82
	elif mode == "hauled":
		checkpoint_marker.position = rules.state.goal + Vector3.UP * 0.08 if rules.state.holders.has(local_id) else Vector3(cargo.position.x, 0.08, cargo.position.z)
	elif mode == "seek":
		checkpoint_marker.visible = rules.state.roles.get(local_id, "shopper") == "shopper" and rules.state.collected.get(local_id, []).size() < 5
		if checkpoint_marker.visible:
			var nearest := INF
			var next_item: int = rules.state.collected.get(local_id, []).size()
			for index in seek_props.size():
				if index % 5 == next_item:
					var distance: float = actors[local_id].position.distance_to(seek_props[index].position)
					if distance < nearest:
						nearest = distance
						checkpoint_marker.position = seek_props[index].position + Vector3.UP * 0.08
	if chef:
		chef.position = rules.state.chef - Vector3(0, 0.6, 0)
		chef.animate(delta, 3, false, false, false, 0)
	if cargo:
		if not authority:
			cargo.position = cargo.position.lerp(rules.state.cargo_position, 1 - exp(-20 * delta))
		cargo.get_node("Fridge").visible = int(rules.state.round) % 3 == 0
		cargo.get_node("HauntedSofa").visible = int(rules.state.round) % 3 == 1
		cargo.get_node("WetCardboard").visible = int(rules.state.round) % 3 == 2
	if cutter:
		var angle: float = rules.state.cutter
		cutter.position = Vector3(cos(angle) * 9, 0.22, sin(angle) * 9)
		cutter.rotation.y = -angle
		cutter.visible = fmod(rules.elapsed, 12) > 3
		for i in pads.size():
			var owner_id: int = rules.state.pads[i].owner
			pads[i].material_override = Kit.material(Kit.IVORY if owner_id == 0 else Kit.TEAL if owner_id == local_id else Kit.ORANGE)
	_effects()
	_update_ghost()
	_update_hud(delta)
	if Input.is_action_just_pressed("pause") and rules.state.phase != "results":
		paused_local = not paused_local
		overlay.visible = paused_local
		shade.visible = paused_local
		_layout_hud.call_deferred()
		pause_box.visible = paused_local
		result_box.visible = false
		if paused_local:
			pause_box.find_children("*", "Button", true, false)[0].grab_focus()
	if rules.state.phase == "results" and not results_shown:
		_show_results()

func _interpolate() -> void:
	if interpolation.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0 - 0.1
	while interpolation.size() > 2 and float(interpolation[1].arrival) <= now:
		interpolation.pop_front()
	var a: Dictionary = interpolation[0]
	var b: Dictionary = interpolation[mini(1, interpolation.size() - 1)]
	var fraction := clampf((now - float(a.arrival)) / maxf(0.001, float(b.arrival) - float(a.arrival)), 0, 1)
	for id in actors:
		if id == local_id or not a.actors.has(id) or not b.actors.has(id):
			continue
		var actor = actors[id]
		actor.restore(b.actors[id])
		actor.position = a.actors[id].p.lerp(b.actors[id].p, fraction)
		actor.facing = lerp_angle(a.actors[id].f, b.actors[id].f, fraction)

func _make_camera() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 64
	camera.far = 115
	add_child(camera)
	if mode == "evacuation":
		camera_yaw = -PI / 2
	_camera(1)

func _camera(delta: float) -> void:
	var actor = actors[local_id]
	var reduced: bool = reduced_motion
	var turn := Input.get_axis("camera_left", "camera_right") * Prefs.camera_x_sign()
	camera_yaw += turn * delta * 1.6
	if Input.is_action_just_pressed("recenter_camera"):
		camera_yaw = actor.facing
	var target: Vector3 = actor.position + Vector3(0, 0.8, 0)
	var offset := Vector3(sin(camera_yaw) * 7.5, 6.0 if reduced else 4.8, cos(camera_yaw) * 7.5)
	var query := PhysicsRayQueryParameters3D.create(target, target + offset, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var desired: Vector3 = hit.position.lerp(target, 0.15) if not hit.is_empty() else target + offset
	# Keep the chase camera inside cutaway office walls at edge checkpoints.
	# This also keeps wall lights out of the foreground at the starting grid.
	if mode == "evacuation":
		desired.x = clampf(desired.x, -23, 23)
	camera.position = camera.position.lerp(desired, 1.0 - exp(-7 * delta))
	if camera.position.distance_to(target) > 0.01:
		camera.look_at(target)
	camera.fov = lerpf(camera.fov, 64.0 if reduced else 68.0 if actor.boost_active else 64.0, 1.0 - exp(-4 * delta))

func _make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.theme = UI.theme()
	layer.add_child(hud_root)
	dashboard = PanelContainer.new()
	dashboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(dashboard)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	dashboard.add_child(stack)
	hud = UI.heading(stack, "", 24)
	clock = UI.heading(stack, "00:00", 43)
	UI.rule(stack)
	objective = UI.label(stack, "", 13)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boost_panel = PanelContainer.new()
	boost_panel.add_theme_stylebox_override("panel", UI.style(UI.INK, 3, 13))
	hud_root.add_child(boost_panel)
	var reserve := VBoxContainer.new()
	boost_panel.add_child(reserve)
	boost_label = UI.label(reserve, "COFFEE RESERVE", 11, UI.PAPER)
	meter = ProgressBar.new()
	meter.custom_minimum_size = Vector2(170, 8)
	meter.show_percentage = false
	meter.add_theme_stylebox_override("fill", UI.style(UI.ORANGE, 0, 0))
	meter.add_theme_stylebox_override("background", UI.style(Color("526455"), 0, 0))
	reserve.add_child(meter)
	speed_panel = PanelContainer.new()
	speed_panel.add_theme_stylebox_override("panel", UI.style(UI.PAPER, 3, 12))
	hud_root.add_child(speed_panel)
	var speedometer := VBoxContainer.new()
	speedometer.add_theme_constant_override("separation", -3)
	speed_panel.add_child(speedometer)
	speed_label = UI.heading(speedometer, "00", 39)
	UI.label(speedometer, "CHAIR SPEED / KM/H", 10, UI.MUTED)
	notice = UI.label(hud_root, "", 14, UI.PAPER)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.max_lines_visible = 2
	notice.add_theme_stylebox_override("normal", UI.style(UI.INK, 3, 8))
	countdown_card = PanelContainer.new()
	countdown_card.add_theme_stylebox_override("panel", UI.style(UI.ORANGE, 3, 16))
	hud_root.add_child(countdown_card)
	var countdown := VBoxContainer.new()
	countdown.add_theme_constant_override("separation", -8)
	countdown_card.add_child(countdown)
	UI.heading(countdown, "CLOCK OUT IN", 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label = UI.heading(countdown, "3", 76)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _touch_enabled():
		_touch_controls(hud_root)
	shade = ColorRect.new()
	shade.color = Color(0.065, 0.10, 0.085, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.add_child(shade)
	overlay = PanelContainer.new()
	overlay.add_theme_stylebox_override("panel", UI.style(UI.PAPER, 3, 24))
	hud_root.add_child(overlay)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	overlay.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contents)
	pause_box = VBoxContainer.new()
	contents.add_child(pause_box)
	UI.heading(pause_box, "TAKING A BREATHER.", 42).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.rule(pause_box)
	var pause_note := UI.label(pause_box, "The office keeps moving during LAN play." if session.active else "Your shift can wait. Take your time.", 14)
	pause_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.primary(pause_box, "RESUME   ↗", func(): paused_local = false; overlay.hide(); shade.hide())
	UI.button(pause_box, "Settings", func():
		var settings = load("res://scripts/Settings.gd").new()
		settings.office_style = true
		var settings_layer := CanvasLayer.new()
		settings_layer.layer = 10
		add_child(settings_layer)
		settings_layer.add_child(settings)
		settings.closed.connect(func(): _refresh_preferences(); settings_layer.queue_free()))
	UI.button(pause_box, "Back to the office", _leave)
	result_box = VBoxContainer.new()
	contents.add_child(result_box)
	overlay.hide()
	shade.hide()
	hud_root.resized.connect(_layout_hud)
	get_window().size_changed.connect(_fit_window)
	_fit_window()

func _fit_window() -> void:
	UI.fit_window(get_window())
	_layout_hud.call_deferred()

func _layout_hud() -> void:
	var bounds := hud_root.size
	var compact := bounds.x < 760
	var touch := is_instance_valid(touch_direction)
	var controls_height := 132 if compact and touch else 76 if touch else 0
	dashboard.position = Vector2(18, 18)
	dashboard.size.x = minf(262, bounds.x - 36)
	boost_panel.position = Vector2(18, bounds.y - controls_height - 79)
	speed_panel.position = Vector2(bounds.x - 152, bounds.y - controls_height - 93)
	var notice_width := minf(640, bounds.x - 36)
	notice.position = Vector2((bounds.x - notice_width) * 0.5, bounds.y - controls_height - 157)
	notice.size = Vector2(notice_width, 42)
	countdown_card.size = Vector2(176, 143)
	countdown_card.position = (bounds - countdown_card.size) * 0.5
	var active_box := pause_box if paused_local else result_box
	var overlay_height := clampf(active_box.get_combined_minimum_size().y + 52, 230, maxf(230, bounds.y - 36))
	overlay.size = Vector2(minf(510, bounds.x - 36), overlay_height)
	overlay.position = (bounds - overlay.size) * 0.5
	if touch:
		touch_direction.position = Vector2(18, bounds.y - (135 if compact else 64))
		touch_actions.position = Vector2(maxf(18, bounds.x - touch_actions.get_combined_minimum_size().x - 18), bounds.y - 58)

func _touch_enabled() -> bool:
	if Prefs.touch_mode() == "on": return true
	if Prefs.touch_mode() == "off": return false
	if OS.has_feature("web"):
		# Mouse-to-touch emulation must not expose phone controls on laptops.
		return bool(Engine.get_singleton("JavaScriptBridge").eval("navigator.maxTouchPoints > 0"))
	return Prefs.touch_enabled()

func _touch_controls(root: Control) -> void:
	var row := HBoxContainer.new()
	touch_direction = row
	root.add_child(row)
	for direction in [Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2.RIGHT]:
		var b := UI.button(row, "<" if direction == Vector2.LEFT else "^" if direction == Vector2.UP else "v" if direction == Vector2.DOWN else ">", func(): pass)
		b.custom_minimum_size = Vector2(64, 64)
		b.button_down.connect(func(): input.touch_move = direction)
		b.button_up.connect(func(): input.touch_move = Vector2.ZERO)
	var actions := HBoxContainer.new()
	touch_actions = actions
	root.add_child(actions)
	for title in ["BOOST", "DRIFT", "E", "Q"]:
		var b := UI.button(actions, title, func(): pass)
		b.button_down.connect(func():
			match title:
				"BOOST": input.touch_boost = true
				"DRIFT": input.touch_drift = true
				"E": input.touch_hop = true
				"Q": input.touch_item = true
		)
		b.button_up.connect(func():
			match title:
				"BOOST": input.touch_boost = false
				"DRIFT": input.touch_drift = false
		)

func _update_hud(delta: float) -> void:
	var actor = actors[local_id]
	var state: Dictionary = rules.state
	meter.value = actor.boost_charge
	hud.text = {"evacuation": "TIME TRIAL" if trial else "EVACUATION", "hauled": "HAULED", "seek": "SHOP & SEEK", "pizza": "PIZZA COLONY"}[mode]
	clock.text = "%02d:%02d" % [int(state.remaining) / 60, int(state.remaining) % 60]
	if trial:
		clock.text = "%02d:%05.2f" % [int(state.elapsed) / 60, fmod(state.elapsed, 60)]
	clock.add_theme_color_override("font_color", Color("a83a19") if not trial and state.remaining < 20 else Color.BLACK if high_contrast else UI.INK)
	boost_label.text = "COFFEE RESERVE  %d%%" % int(actor.boost_charge)
	speed_label.text = "%02d" % int(Vector2(actor.velocity.x, actor.velocity.z).length() * 3.6)
	countdown_card.visible = state.phase == "countdown" and not paused_local
	countdown_label.text = str(maxi(1, ceili(rules.countdown)))
	match mode:
		"evacuation":
			var place := 1
			for rival in actors.values():
				if course.progress(rival.position, rival.checkpoint) > course.progress(actor.position, actor.checkpoint):
					place += 1
			objective.text = "POSITION  %d / %d\nFLOOR %d  /  %s" % [place, actors.size(), 4 - mini(3, actor.checkpoint / 8), course.zone_names[mini(3, actor.checkpoint / 8)].capitalize()]
			if actor.item_kind != "":
				objective.text += "\nQ  /  " + actor.item_kind.replace("_", " ")
			objective.text += "\nNEXT CHECKPOINT %dm" % int(actor.position.distance_to(course.points[mini(actor.checkpoint + 1, course.points.size() - 1)]))
		"hauled": objective.text = "%s · INTEGRITY %d%%\nDELIVERED %d / 3 · E grab / release" % [state.cargo_kind, state.cargo_health, state.delivered]
		"seek": objective.text = "%s · LIST %d / 5 · STRIKES %d / 3\nE collect / disguise · Q scanner" % [str(state.roles.get(local_id, "shopper")).to_upper(), state.collected.get(local_id, []).size(), state.caught.get(local_id, 0)]
		"pizza": objective.text = "YOUR SLICES %d / 12 · CHEESE %d\nStay on a tile to claim · Q build a fort" % [state.players.get(local_id, {"score": 0}).score, state.cheese.get(local_id, 0)]
	if mode == "seek" and state.roles.get(local_id, "shopper") == "shopper":
		objective.text += "\nNEXT: " + ["Plant", "Printer", "Water cooler", "File cabinet", "Vending machine", "Checkout complete"][mini(5, state.collected.get(local_id, []).size())]
	notice_time = maxf(0, notice_time - delta)
	notice.visible = notice_time > 0

func _show_results() -> void:
	results_shown = true
	paused_local = false
	overlay.show()
	shade.show()
	countdown_card.hide()
	pause_box.hide()
	result_box.show()
	UI.label(result_box, "DEPARTURE REPORT", 12, UI.MUTED)
	UI.heading(result_box, rules.state.headline.to_upper(), 38).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.rule(result_box)
	var ranking := actors.keys()
	ranking.sort_custom(func(a, b): return rules.state.players[a].score > rules.state.players[b].score)
	for id in ranking:
		var actor = actors[id]
		var score := ("%.2fs" % actor.finish_time if actor.finish_time >= 0 else "Did not finish") if mode == "evacuation" else "%d pts" % rules.state.players[id].score
		var row := HBoxContainer.new()
		result_box.add_child(row)
		UI.heading(row, "%02d" % (ranking.find(id) + 1), 23, UI.TEAL if id == local_id else UI.MUTED)
		var rider := UI.label(row, actor.display_name + ("  /  YOU" if id == local_id else ""), 14)
		rider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rider.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		UI.label(row, score, 13)
		UI.rule(result_box)
	if mode == "evacuation" and actors[local_id].finish_time >= 0 and not session.active and not test_mode:
		var record: bool = Save.record(course.record_key(actors[local_id].profile_id, trial), actors[local_id].finish_time, ghost_frames if trial else [])
		if record:
			UI.label(result_box, "NEW PERSONAL BEST", 20, Color("347f71"))
	if mode == "evacuation" and not trial and not test_mode:
		StatsManager.record_race(ranking[0] == local_id, actors[local_id].profile.speed * 1.5, 0)
	if authority:
		UI.primary(result_box, "ONE MORE SHIFT   ↗", func(): session.start())
	else:
		UI.label(result_box, "Waiting for the host to start the next shift.", 16)
	UI.button(result_box, "Back to the office", _leave)
	result_box.find_children("*", "Button", true, false)[0].grab_focus()
	_layout_hud.call_deferred()

func _update_ghost() -> void:
	if not ghost or previous_ghost.size() < 2:
		return
	while ghost_index < previous_ghost.size() - 2 and float(previous_ghost[ghost_index + 1].t) < rules.elapsed:
		ghost_index += 1
	var a: Dictionary = previous_ghost[ghost_index]
	var b: Dictionary = previous_ghost[ghost_index + 1]
	var blend := clampf((rules.elapsed - float(a.t)) / maxf(0.001, float(b.t) - float(a.t)), 0, 1)
	ghost.position = a.p.lerp(b.p, blend) - Vector3(0, 0.6, 0)
	ghost.rotation.y = lerp_angle(a.f, b.f, blend)
	ghost.visible = rules.state.phase == "running"
	ghost.animate(get_process_delta_time(), 8, false, false, false, 0)

func _effects() -> void:
	# Reuse small visual nodes; no per-frame scene allocations after count stabilizes.
	var wanted: Array = rules.state.items.duplicate()
	for fort in rules.state.forts:
		wanted.append({"p": fort.p, "kind": "fort"})
	for id in disguises.keys():
		if not rules.state.disguises.has(id) or not actors.has(id):
			disguises[id].queue_free()
			disguises.erase(id)
	for id in rules.state.disguises:
		if not actors.has(id):
			continue
		if not disguises.has(id):
			var prop_kind: String = ["plant", "printer", "water", "cabinet", "vending"][int(rules.state.disguises[id]) % 5]
			disguises[id] = Kit.prop(self, prop_kind, Vector3.ZERO, 0, false)
		disguises[id].position = actors[id].position - Vector3(0, 0.6, 0)
	while effects_root.get_child_count() < wanted.size():
		Kit.decor_box(effects_root, Vector3.ONE, Vector3.ZERO, Kit.ORANGE)
	for i in effects_root.get_child_count():
		var mesh: MeshInstance3D = effects_root.get_child(i)
		mesh.visible = i < wanted.size()
		if i >= wanted.size():
			continue
		var item: Dictionary = wanted[i]
		mesh.position = item.p
		mesh.scale = Vector3(2, 0.06, 1.6) if item.kind != "fort" else Vector3(1.4, 1.2, 0.4)
		mesh.material_override = Kit.material(Color("a97d4b") if item.kind == "coffee_spill" else Kit.IVORY if item.kind == "paper_jam" else Kit.ORANGE)

func line_of_sight(a: Node3D, b: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a.position + Vector3.UP * 0.5, b.position + Vector3.UP * 0.5, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func sweep_agent(from: Vector3, desired: Vector3) -> Vector3:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.2
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = desired - from
	query.collision_mask = 1
	var fraction := get_world_3d().direct_space_state.cast_motion(query)
	if fraction[0] < 0.99:
		query.motion = Vector3(query.motion.x, 0, 0)
		var slide_x := get_world_3d().direct_space_state.cast_motion(query)
		if slide_x[0] > 0.99: return from + query.motion
		query.motion = Vector3(0, 0, desired.z - from.z)
		var slide_z := get_world_3d().direct_space_state.cast_motion(query)
		return from + query.motion * slide_z[0]
	return desired

func announce(words: String) -> void:
	if notice:
		notice.text = words
		notice_time = 5

func _motor_event(kind: String, _strength: float, id: int) -> void:
	if id != local_id:
		return
	if kind == "respawn":
		announce("BACK AT THE LAST SAFE CHECKPOINT")
	AudioManager.play_sfx({"hop": "jump", "land": "land", "hit": "crash", "respawn": "checkpoint"}.get(kind, "click"))
	if kind == "hit":
		Prefs.rumble_thump(0.5)

func _rematch() -> void:
	get_tree().reload_current_scene()

func _leave() -> void:
	session.close()
	get_tree().change_scene_to_file("res://scenes/overhaul/OfficeLaunch.tscn")

func _refresh_preferences() -> void:
	reduced_motion = A11y.reduced_motion_enabled()
	high_contrast = A11y.high_contrast_enabled()
	for actor in actors.values():
		actor.visual.reduced_motion = reduced_motion
	if hud:
		hud.add_theme_color_override("font_color", Color.BLACK if high_contrast else UI.INK)
		objective.add_theme_color_override("font_color", Color.BLACK if high_contrast else UI.INK)
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	var quality := int(config.get_value("graphics", "quality", 0))
	for sun in find_children("OfficeSun", "DirectionalLight3D", true, false):
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 28 if quality == 0 else 42
	get_viewport().scaling_3d_scale = 0.75 if quality == 0 else 1.0

func _input(event: InputEvent) -> void:
	Prefs.note_device(event)

func _exit_tree() -> void:
	A11y.reset_time_scale()
	if session and session.game == self:
		session.game = null
