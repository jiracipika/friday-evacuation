# SabotageTrap.gd — Water puddle / banana peel that stuns players
extends Area3D

@export var stun_duration: float = 1.5
@export var lifetime: float = 12.0

var age: float = 0.0
var trap_type: String = "water"  # "water", "banana", "stapler", "spill"
var triggered := false
var owner_id: int = 0  # instance id of the player who placed this trap
var forced_type: String = ""  # set before add_child to skip random selection

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

func _on_body_entered(body: CharacterBody3D) -> void:
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
