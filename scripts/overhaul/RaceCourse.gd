extends Resource
const REVISION := 2
const Profiles = preload("res://scripts/overhaul/HandlingProfiles.gd")
const NAMES := {"open_plan": "Open Plan", "cubicle_maze": "Cubicle Maze", "executive": "Executive Suite"}
var id := "open_plan"
var points: Array[Vector3] = []
var shortcuts: Array[Dictionary] = []
var zone_names := ["THE OPEN OFFICE", "MEETING MARATHON", "BREAK ROOM BREAKOUT", "THE LAST DOOR"]
var total_length := 0.0
var distances: Array[float] = []

func _init(layout := "open_plan") -> void:
	id = layout if NAMES.has(layout) else "open_plan"
	for floor_index in 4:
		var z := float(floor_index) * 68.0
		var y := 18.0 - floor_index * 6.0
		var side := 1.0 if floor_index % 2 == 0 else -1.0
		var width := 16.0 if id != "executive" else 18.0
		var local := [Vector3(-width, y, z - 16), Vector3(width, y, z - 16), Vector3(width, y, z - 3), Vector3(-width, y, z - 3), Vector3(-width, y, z + 10), Vector3(13, y, z + 10), Vector3(13, y, z + 21)]
		for p in local:
			p.x *= side
			points.append(p)
		if floor_index < 3:
			points.append(Vector3(13 * side, y - 6, z + 46))
		shortcuts.append({"from": floor_index * 8 + 1, "to": floor_index * 8 + 4, "zone": floor_index})
	points.append(Vector3(-13, 0, 229))
	distances.append(0)
	for i in range(1, points.size()):
		total_length += points[i].distance_to(points[i - 1])
		distances.append(total_length)

func record_key(profile: String, trial: bool) -> String:
	return "%s:r%d:p%d:%s:%s" % [id, REVISION, Profiles.PHYSICS_VERSION, profile, "trial" if trial else "race"]

func spawn(slot: int) -> Vector3:
	# Two columns and four lanes keep all eight chairs inside the cutaway
	# camera boundary, with clear floor between the grid and the plants.
	return points[0] + Vector3(-1.0 - (slot % 2) * 1.3, 0.65, (slot / 2) * 1.4 - 2.1)

func progress(position: Vector3, cp: int) -> float:
	if cp >= points.size() - 1:
		return total_length
	var a := points[cp]
	var b := points[cp + 1]
	var along := clampf((position - a).dot((b - a).normalized()), 0, a.distance_to(b))
	return distances[cp] + along
