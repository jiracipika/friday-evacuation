extends Area3D

var base_y: float = 0.0
var time_offset: float = 0.0
var glow_radius: float = 0.0
var glow_light: OmniLight3D

func _ready() -> void:
	base_y = position.y
	time_offset = float(get_instance_id() % 1000) * 0.01

	glow_light = OmniLight3D.new()
	glow_light.light_color = Color(1.0, 0.55, 0.08)
	glow_light.light_energy = 0.8
	glow_light.omni_range = 3.5
	glow_light.shadow_enabled = false
	add_child(glow_light)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	rotation.y += delta * 1.8
	position.y = base_y + sin(Time.get_ticks_msec() * 0.003 + time_offset) * 0.22

	glow_radius = (sin(Time.get_ticks_msec() * 0.004 + time_offset) * 0.5 + 0.5) * 0.4
	if glow_light:
		glow_light.omni_range = 3.0 + glow_radius
		glow_light.light_energy = 0.7 + glow_radius * 0.4

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		var audio = get_node_or_null("/root/AudioManager")
		if audio:
			audio.play_sfx("powerup", 1.2)

		var fx = load("res://scripts/ImpactFX.gd")
		if fx:
			fx.burst(get_parent(), global_position + Vector3.UP * 0.2, Color(1.0, 0.65, 0.15), 16)

		if body.has_method("_start_boost"):
			body._start_boost()

		queue_free()
