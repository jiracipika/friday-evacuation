extends Node3D
const Design = preload("res://scripts/CharacterDesign.gd")
const Roster = preload("res://scripts/CharacterRoster.gd")
var body: Node3D
var chair: Node3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var head_bone := -1
var elapsed := 0.0
var clip := ""
var configured: Dictionary = {}
var model_height := 1.8
var rim: MeshInstance3D
var chair_style := "office_standard"
var expressions: Dictionary = {}
var base_expression := "focused"
var applied_expression := ""
var landed := 0.0
var was_airborne := false
var reduced_motion := false

func configure(character_id: String, overrides: Dictionary, skin_id := "office_standard") -> void:
	configured = Design.resolve(Roster.get_character(character_id), overrides)
	chair_style = skin_id
	body = load("res://models/overhaul/coworker.glb").instantiate()
	add_child(body)
	var palette := ShaderMaterial.new()
	palette.shader = load("res://models/overhaul/palette.gdshader")
	for pair in [["skin", "skin_tone"], ["hair", "hair_color"], ["cloth", "shirt_color"], ["accent", "accent_color"]]:
		palette.set_shader_parameter(pair[0], Color(configured[pair[1]]))
	base_expression = str(configured.expression)
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var label: String = node.name
		node.material_override = palette
		if label.begins_with("Hair_"):
			node.visible = label == "Hair_" + str(configured.hair)
		if label.begins_with("Face_"):
			expressions[label.trim_prefix("Face_")] = node
			node.visible = false
		if label.begins_with("Outfit_"):
			node.visible = label == "Outfit_" + str(configured.outfit)
		if label.begins_with("Prop_"):
			node.visible = label == "Prop_" + str(configured.accessory)
	set_expression(base_expression)
	if configured.build == "stocky":
		body.scale = Vector3(1.16, 0.96, 1.06)
	elif configured.build == "lanky":
		body.scale = Vector3(0.94, 1.07, 0.96)
	animator = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		head_bone = skeleton.find_bone("Head")
	var chair_path := "res://models/overhaul/office_chair.glb" if skin_id == "office_standard" else "res://models/overhaul/chair_%s.glb" % skin_id
	chair = load(chair_path).instantiate()
	chair.name = "Chair"
	if skin_id == "office_standard":
		chair.rotation.y = PI
	add_child(chair)
	for mesh in chair.find_children("*", "MeshInstance3D", true, false):
		if skin_id == "office_standard":
			mesh.visibility_range_end = 17
			mesh.visibility_range_end_margin = 1
		for surface in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(surface)
			if source and source.resource_name == "teal":
				var cushion := source.duplicate() as StandardMaterial3D
				cushion.albedo_color = Color(configured.shirt_color).darkened(0.15)
				mesh.set_surface_override_material(surface, cushion)
	if skin_id == "office_standard":
		for level in [1, 2]:
			var lod: Node3D = load("res://models/overhaul/office_chair_lod%d.glb" % level).instantiate()
			lod.rotation.y = PI
			add_child(lod)
			for mesh in lod.find_children("*", "MeshInstance3D", true, false):
				mesh.visibility_range_begin = 17 if level == 1 else 33
				mesh.visibility_range_end = 33 if level == 1 else 90
				mesh.visibility_range_begin_margin = 1
				mesh.visibility_range_end_margin = 1
	if character_id in ["it_iggy", "remote_ron"]:
		# Headphone silhouette remains independent of hair selection.
		var props = load("res://scripts/overhaul/OfficeKit.gd")
		for side in [-1.0, 1.0]:
			props.decor_box(self, Vector3(0.055, 0.16, 0.14), Vector3(side * 0.22, 1.52, 0.02), Color(configured.accent_color))
	_play("Idle")

func set_expression(expression: String) -> void:
	if expression == applied_expression:
		return
	applied_expression = expression
	for key in expressions:
		expressions[key].visible = key == expression

func _play(wanted: String, rate := 1.0) -> void:
	if not animator:
		return
	if clip != wanted:
		for candidate in animator.get_animation_list():
			if String(candidate).contains(wanted):
				animator.play(candidate, 0.18, rate)
				var animation := animator.get_animation(candidate)
				animation.loop_mode = Animation.LOOP_LINEAR
				clip = wanted
				break
	animator.speed_scale = rate

func animate(delta: float, speed: float, drifting: bool, boosting: bool, airborne: bool, stunned: float) -> void:
	elapsed += delta
	if was_airborne and not airborne:
		landed = 0.22
	was_airborne = airborne
	landed = maxf(0, landed - delta)
	_play("Stun" if stunned > 0 else "Air" if airborne else "Land" if landed > 0 else "Boost" if boosting else "Push" if speed > 1 else "Idle", clampf(speed / 5.0, 0.7, 1.8))
	rotation.z = lerpf(rotation.z, 0.0 if reduced_motion else (sin(elapsed * 20) * 0.08 if stunned > 0 else 0.1 if drifting else 0.0), 1.0 - exp(-8 * delta))
	rotation.x = lerpf(rotation.x, -0.06 if boosting else 0.0, 1.0 - exp(-8 * delta))
	set_expression("panic" if airborne or stunned > 0 else base_expression)
