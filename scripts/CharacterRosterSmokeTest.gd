extends SceneTree

const Roster = preload("res://scripts/CharacterRoster.gd")
var chairs: Array[CharacterBody3D] = []
var expected_colors: Array[Color] = []
var failures := PackedStringArray()
var frames := 0

func _init() -> void:
	var packed := load("res://scenes/PlayerChair.tscn")
	for character in Roster.all():
		var chair: CharacterBody3D = packed.instantiate()
		chair.character_id = character["id"]
		chair.use_global_character = false
		chair.player_color = Color.from_hsv(float(chairs.size()) / 8.0, 0.7, 0.9)
		expected_colors.append(chair.player_color)
		chair.position = Vector3(chairs.size() * 2.0, 1.0, 0)
		chairs.append(chair)
		root.add_child.call_deferred(chair)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 4:
		return false
	var rider_names := {}
	for i in range(chairs.size()):
		var chair := chairs[i]
		var character: Dictionary = Roster.all()[i]
		if chair.rider_root == null:
			failures.append("%s did not build a rider" % character["id"])
			continue
		if not chair.player_color.is_equal_approx(expected_colors[i]):
			failures.append("%s overwrote authoritative chair color" % character["id"])
		rider_names[chair.rider_root.name] = true
		var accessory_name := "Accessory_%s" % character["accessory"]
		if chair.rider_root.get_node_or_null(accessory_name) == null:
			failures.append("%s missing %s" % [character["id"], accessory_name])
	if rider_names.size() != chairs.size():
		failures.append("character riders do not have unique runtime identities")
	if failures.is_empty():
		print("[PASS] %d selectable characters build unique riders and accessories" % chairs.size())
		quit(0)
	else:
		for failure in failures:
			printerr("[FAIL] " + failure)
		quit(1)
	return false
