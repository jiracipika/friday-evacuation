# SabotageTrap.gd — Water puddle / banana peel that stuns players
extends Area3D

@export var stun_duration: float = 2.0
@export var lifetime: float = 15.0

var age: float = 0.0
var trap_type: String = "water"  # "water", "banana", "stapler"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Randomly assign type
	var types = ["water", "banana", "stapler"]
	trap_type = types.pick_random()
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
		_:
			mat.albedo_color = Color(1, 0, 1)
	
	var mesh_node = get_node_or_null("Mesh")
	if mesh_node:
		mesh_node.material_override = mat

func _on_body_entered(body: CharacterBody3D) -> void:
	if body.is_in_group("players"):
		if body.has_method("stun"):
			body.stun(stun_duration)
			print("[TRAP] %s hit %s trap!" % [body.player_display_name if "player_display_name" in body else "Player", trap_type])
			# Remove trap after hit
			queue_free()

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
