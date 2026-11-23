extends RefCounted
## Host-owned mode rules. State contains serializable values only.
const SEEK_HIDE_SECONDS := 8.0
const SECONDS_TO_CLAIM := 3.0
const CUTTER_RADIUS := 18.0
const CARGO_NAMES := ["FRIDGE OF BEES", "HAUNTED SOFA", "WET CARDBOARD"]
var mode := "evacuation"
var elapsed := 0.0
var countdown := 3.0
var finished := false
var state: Dictionary = {}
var game: Node
var first_finish := -1.0

func setup(owner: Node, selected: String) -> void:
	game = owner
	mode = selected
	state = {"phase": "countdown", "elapsed": 0.0, "remaining": 180.0, "headline": "", "players": {}, "pads": [], "holders": [], "round": 0, "delivered": 0, "cargo_health": 100.0, "cargo_kind": "FRIDGE OF BEES", "cargo_position": Vector3(-12, 0.7, -10), "cargo_velocity": Vector3.ZERO, "goal": Vector3(13, 0, 14), "roles": {}, "disguises": {}, "caught": {}, "collected": {}, "forts": [], "cheese": {}, "scan": {}, "items": [], "chef": Vector3(16, 0.8, 0), "cutter": 0.0}
	for id in game.actors:
		add_player(id)
	if mode == "pizza":
		for i in 12:
			var angle := float(i) * TAU / 12
			state.pads.append({"p": Vector3(cos(angle) * 11, 0.16, sin(angle) * 11), "owner": 0, "claimant": 0, "progress": 0.0})
	if mode == "hauled":
		state.remaining = 120.0
	elif mode == "seek":
		state.remaining = 90.0
	elif mode == "pizza":
		state.remaining = 120.0

func add_player(id: int) -> void:
	state.players[id] = {"score": 0, "alive": true}
	state.roles[id] = "seeker" if game.session.active and id == 1 else "hider" if game.session.active else "shopper"
	state.caught[id] = 0
	state.collected[id] = []
	state.cheese[id] = 3
	state.scan[id] = 0.0

func hide_time_remaining() -> float:
	if mode != "seek" or not game.session.active:
		return 0.0
	return maxf(0.0, SEEK_HIDE_SECONDS - elapsed)

func can_drive(id: int) -> bool:
	var player: Dictionary = state.players.get(id, {})
	if state.phase != "running" or not player.get("alive", false):
		return false
	return state.roles.get(id, "") != "seeker" or hide_time_remaining() == 0.0

func tick(delta: float) -> void:
	if finished:
		return
	if countdown > 0:
		countdown -= delta
		if countdown <= 0:
			state.phase = "running"
			game.announce("Find a display to hide. Seekers are held for %ds." % int(SEEK_HIDE_SECONDS) if hide_time_remaining() > 0 else "GO!")
		return
	elapsed += delta
	state.elapsed = elapsed
	state.remaining = maxf(0, state.remaining - delta)
	match mode:
		"evacuation": _race(delta)
		"hauled": _hauled(delta)
		"seek": _seek(delta)
		"pizza": _pizza(delta)
	if state.remaining <= 0:
		match mode:
			"seek": end("HIDERS WIN" if game.session.active else "STORE CLOSED")
			"hauled": end("DELIVERY WINDOW CLOSED")
			"pizza": end("SERVICE COMPLETE")
			_: end("THE CLOCK WON")

func _race(_delta: float) -> void:
	for id in game.actors:
		var actor = game.actors[id]
		if actor.finish_time >= 0:
			continue
		var next := mini(actor.checkpoint + 1, game.course.points.size() - 1)
		var point: Vector3 = game.course.points[next]
		if Vector2(point.x - actor.position.x, point.z - actor.position.z).length() < 2.6 and absf(actor.position.y - point.y) < 2.2:
			actor.checkpoint = next
			actor.spawn_point = point + Vector3(0, 0.7, 0)
			actor.checkpoint_time = elapsed
			if id == game.local_id:
				game.announce("%s / CHECKPOINT" % game.course.zone_names[mini(3, next / 8)])
		# The marked cross-cubicle shortcut requires an actual airborne hop.
		var zone := mini(3, actor.checkpoint / 8)
		var local_cp: int = actor.checkpoint % 8
		if local_cp in [1, 2] and not actor.is_on_floor() and absf(actor.position.x) < 4 and absf(actor.position.z - (zone * 68.0 - 3)) < 5:
			actor.checkpoint = zone * 8 + 3
			game.announce("DESK-HOP SHORTCUT!")
		if actor.position.y < game.course.points[actor.checkpoint].y - 9 or actor.position.y < -4:
			actor.respawn()
		if actor.checkpoint == game.course.points.size() - 1:
			actor.finish_time = elapsed
			state.players[id].score = 10000 - int(elapsed * 10)
			if first_finish < 0:
				first_finish = elapsed
			game.announce(actor.display_name + " CLOCKED OUT")
	var humans_done := true
	for actor in game.actors.values():
		if actor.finish_time < 0:
			humans_done = false
	if humans_done or (first_finish >= 0 and elapsed - first_finish > 25):
		end("OFF THE CLOCK")

func interact(id: int, hop: bool, item: bool) -> void:
	if not can_drive(id) or not game.actors.has(id):
		return
	var actor = game.actors[id]
	match mode:
		"hauled":
			if hop:
				if state.holders.has(id):
					state.holders.erase(id)
					if state.holders.is_empty():
						game.cargo.freeze = false
						game.cargo.linear_velocity = Vector3(-sin(actor.facing), 0.35, -cos(actor.facing)) * 9
				elif actor.position.distance_to(game.cargo.position) < 2.7 and state.holders.size() < 2:
					state.holders.append(id)
		"seek":
			if state.roles[id] == "shopper" and hop:
				for index in game.seek_props.size():
					if actor.position.distance_to(game.seek_props[index].position) < 2.3 and index % 5 == state.collected[id].size():
						state.collected[id].append(index)
						state.players[id].score += 1
						game.announce("LIST ITEM %d / 5" % state.collected[id].size())
						if state.collected[id].size() == 5:
							end("CHECKOUT COMPLETE")
						break
			elif state.roles[id] == "hider" and hop:
				if state.disguises.has(id):
					state.disguises.erase(id)
				else:
					for index in game.seek_props.size():
						if actor.position.distance_to(game.seek_props[index].position) < 2.3 and actor.velocity.length() < 1:
							state.disguises[id] = index
							break
			elif state.roles[id] == "seeker" and item and state.scan[id] <= 0:
				state.scan[id] = 5.0
				for target in game.actors:
					if state.roles[target] != "hider":
						continue
					var rival = game.actors[target]
					var direction: Vector3 = rival.position - actor.position
					var ahead := Vector3(-sin(actor.facing), 0, -cos(actor.facing))
					if direction.length() < 6 and direction.normalized().dot(ahead) > 0.45 and game.line_of_sight(actor, rival):
						state.roles[target] = "seeker"
						state.disguises.erase(target)
						state.players[id].score += 1
						game.announce("FOUND " + rival.display_name)
		"pizza":
			if item and state.cheese[id] >= 3 and state.forts.size() < 16:
				state.cheese[id] -= 3
				state.forts.append({"p": actor.position + Vector3(-sin(actor.facing), -0.3, -cos(actor.facing)) * 1.4, "life": 10.0, "owner": id})
		_:
			if item and actor.item_kind != "":
				state.items.append({"p": actor.position + Vector3(sin(actor.facing) * 1.5, -0.55, cos(actor.facing) * 1.5), "owner": id, "life": 10.0, "kind": actor.item_kind, "armed": 0.6})
				actor.item_kind = ""

func _hauled(delta: float) -> void:
	state.holders = state.holders.filter(func(id): return game.actors.has(id))
	if not state.holders.is_empty():
		game.cargo.freeze = true
		var center := Vector3.ZERO
		for id in state.holders:
			var actor = game.actors[id]
			center += actor.position + Vector3(-sin(actor.facing) * 1.2, 0.2, -cos(actor.facing) * 1.2)
		center /= state.holders.size()
		var desired: Vector3 = game.cargo.position.lerp(center, 1 - exp(-12 * delta))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = game.cargo.get_child(0).shape
		query.transform = game.cargo.global_transform
		query.motion = desired - game.cargo.position
		query.collision_mask = 1
		var safe: PackedFloat32Array = game.get_world_3d().direct_space_state.cast_motion(query)
		game.cargo.position += query.motion * maxf(0, safe[0] - 0.02)
		game.cargo.rotation.y = game.actors[state.holders[0]].facing
	else:
		game.cargo.freeze = false
	state.cargo_position = game.cargo.position
	state.cargo_velocity = game.cargo.linear_velocity
	var behavior := int(state.round) % 3
	state.cargo_kind = CARGO_NAMES[behavior]
	for id in game.actors:
		game.actors[id].collision_mask = 1 if state.holders.has(id) else 5
		game.actors[id].desired_speed = (0.66 if state.holders.size() == 1 else 0.85) if state.holders.has(id) else 1.0
		if state.holders.has(id) and game.actors[id].boost_active:
			state.cargo_health = maxf(0, state.cargo_health - delta * (6 if behavior == 2 else 2))
	if state.cargo_health <= 0:
		end("RETURN TO SENDER")
		return
	if behavior == 1 and fmod(elapsed, 8.0) > 7.0 and state.holders.is_empty():
		game.cargo.apply_central_force((Vector3(-12, 0, -10) - game.cargo.position).normalized() * 18)
	if behavior == 2:
		game.cargo.mass = 3.0 + (100.0 - float(state.cargo_health)) * 0.03
	if game.cargo.position.y < -2:
		state.cargo_health = maxf(0, state.cargo_health - 15)
		game.cargo.position = Vector3(-12, 1, -10)
		game.cargo.linear_velocity = Vector3.ZERO
	if Vector2(game.cargo.position.x - state.goal.x, game.cargo.position.z - state.goal.z).length() < 3:
		state.delivered += 1
		for id in state.players:
			state.players[id].score += int(state.cargo_health)
		if state.delivered >= 3:
			end("DELIVERY APPROVED")
		else:
			state.round += 1
			state.cargo_health = 100.0
			state.remaining += 35.0
			state.holders.clear()
			game.cargo.position = Vector3(-12, 1, -10)
			game.cargo.linear_velocity = Vector3.ZERO
			game.cargo.mass = 4
			state.cargo_position = game.cargo.position
			state.cargo_velocity = Vector3.ZERO
			state.cargo_kind = CARGO_NAMES[int(state.round) % 3]
			game.announce("DELIVERED! NEXT: " + state.cargo_kind)
	for actor in game.actors.values():
		if actor.position.y < -3:
			actor.respawn()

func _seek(delta: float) -> void:
	for id in state.scan:
		state.scan[id] = maxf(0, state.scan[id] - delta)
	if game.session.active:
		if hide_time_remaining() > 0.0:
			return
		var hiders := 0
		for id in game.actors:
			if state.roles[id] == "hider":
				hiders += 1
		if hiders == 0:
			end("EVERYONE HAS BEEN FOUND")
	else:
		var player = game.actors[game.local_id]
		var patrol := Vector3(sin(elapsed * 0.2) * 14, 0.8, cos(elapsed * 0.2) * 13)
		var guard_ray := PhysicsRayQueryParameters3D.create(state.chef + Vector3.UP * 0.5, player.position + Vector3.UP * 0.5, 1)
		var sees_player: bool = player.position.distance_to(state.chef) < 8 and game.get_world_3d().direct_space_state.intersect_ray(guard_ray).is_empty()
		var target: Vector3 = player.position if sees_player else patrol
		target.y = 0.8
		state.chef = game.sweep_agent(state.chef, state.chef.move_toward(target, 3.0 * delta))
		if player.position.distance_to(state.chef) < 1.2 and player.immunity <= 0:
			state.caught[game.local_id] += 1
			player.apply_hit(Vector3(0, 0, -3), 0.5)
			player.immunity = 4.0
			game.announce("SECURITY STRIKE %d / 3" % state.caught[game.local_id])
			if state.caught[game.local_id] >= 3:
				end("SECURITY ESCORT")

func _pizza(delta: float) -> void:
	state.cutter = elapsed * (0.35 + elapsed / 400.0)
	var target_id := 0
	var nearest := INF
	for id in game.actors:
		var actor = game.actors[id]
		if actor.position.y < -2:
			state.players[id].alive = false
			actor.enabled = false
		if not state.players[id].alive:
			continue
		var distance: float = actor.position.distance_to(state.chef)
		if distance < nearest:
			nearest = distance
			target_id = id
		state.cheese[id] = minf(12, state.cheese[id] + delta * 0.3)
		if fmod(elapsed, 12) > 3:
			var ray := Vector2(cos(state.cutter), sin(state.cutter))
			var pos := Vector2(actor.position.x, actor.position.z)
			if absf(pos.cross(ray)) < 0.65 and pos.dot(ray) > 0 and pos.dot(ray) <= CUTTER_RADIUS and actor.position.y < 1.7:
				actor.apply_hit(Vector3(ray.y * 4, 2, -ray.x * 4), 0.3)
	_claim_territory(delta)
	if target_id:
		var target: Vector3 = game.actors[target_id].position
		target.y = 0.8
		state.chef = game.sweep_agent(state.chef, state.chef.move_toward(target, (2.1 + elapsed * 0.01) * delta))
		if nearest < 1.4:
			var actor = game.actors[target_id]
			actor.apply_hit((actor.position - state.chef).normalized() * 5, 0.4)
	var alive: Array[int] = []
	for id in state.players:
		state.players[id].score = 0
		if state.players[id].alive:
			alive.append(id)
	for pad in state.pads:
		if state.players.has(pad.owner):
			state.players[pad.owner].score += 1
	if alive.is_empty():
		end("THE CHEF WINS")
	elif alive.size() == 1 and state.players.size() > 1:
		end(game.actors[alive[0]].display_name + " IS THE LAST RIDER")
	else:
		for id in alive:
			if state.players[id].score == state.pads.size():
				end(game.actors[id].display_name + " CLAIMED THE WHOLE PIE")
				break

func _claim_territory(delta: float) -> void:
	for pad in state.pads:
		var sole_rider := 0
		for id in game.actors:
			var offset: Vector3 = game.actors[id].position - pad.p
			if not state.players[id].alive or absf(offset.y) > 1.3 or Vector2(offset.x, offset.z).length() >= 1.5:
				continue
			if sole_rider != 0:
				sole_rider = 0
				break
			sole_rider = id
		if sole_rider != pad.claimant or sole_rider == 0:
			pad.claimant = sole_rider
			pad.progress = 0.0
		if sole_rider != 0 and sole_rider != pad.owner:
			pad.progress += delta
			if pad.progress >= SECONDS_TO_CLAIM:
				pad.owner = sole_rider
				pad.progress = 0.0

func end(headline: String) -> void:
	if finished:
		return
	finished = true
	state.phase = "results"
	state.headline = headline
	game.announce(headline)
