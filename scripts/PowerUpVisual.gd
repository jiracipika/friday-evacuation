extends Area3D

var base_y: float = 0.0
var time_offset: float = 0.0

func _ready() -> void:
	base_y = position.y
	time_offset = float(get_instance_id() % 1000) * 0.01

func _process(delta: float) -> void:
	rotation.y += delta * 1.8
	position.y = base_y + sin(Time.get_ticks_msec() * 0.003 + time_offset) * 0.22
