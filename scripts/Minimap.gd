extends Control

var _pulse_time := 0.0

func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()

var player_position := Vector2.ZERO
var player_floor := 0
var exit_position := Vector2(0.5, 0.92)

func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_player(world_position: Vector3, floor_index: int) -> void:
	player_position = Vector2(clampf(world_position.x / 40.0 + 0.5, 0.04, 0.96), clampf(world_position.z / 40.0 + 0.5, 0.04, 0.96))
	player_floor = clampi(floor_index, 0, 3)
	queue_redraw()

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	draw_style_box(_panel_style(), rect)
	var inset = Rect2(Vector2(12, 12), size - Vector2(24, 24))
	for i in range(1, 4):
		var x = inset.position.x + inset.size.x * float(i) / 4.0
		var y = inset.position.y + inset.size.y * float(i) / 4.0
		draw_line(Vector2(x, inset.position.y), Vector2(x, inset.end.y), Color(1, 1, 1, 0.08), 1.0)
		draw_line(Vector2(inset.position.x, y), Vector2(inset.end.x, y), Color(1, 1, 1, 0.08), 1.0)
	var exit = inset.position + Vector2(exit_position.x, exit_position.y) * inset.size
	draw_circle(exit, 5.0, Color("63e68a"))
	# D4: slow pulsing ring so the exit is findable at a glance.
	var ring_r := 9.0 + 3.0 * (0.5 + 0.5 * sin(_pulse_time * TAU / 1.6))
	draw_arc(exit, ring_r, 0.0, TAU, 20, Color(0.39, 0.9, 0.54, 0.45), 2.0)
	var player = inset.position + player_position * inset.size
	draw_circle(player, 6.0, Color("70b7ff"))
	draw_arc(player, 10.0, 0.0, TAU, 16, Color(0.44, 0.72, 1.0, 0.35), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(12, 11), "F%d" % (player_floor + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))

func _panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.06, 0.84)
	style.border_color = Color(1, 0.6, 0.1, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style
