extends RefCounted
const PHYSICS_VERSION := 2
const IDS := ["balanced", "agile", "heavy"]
const PROFILES := {
	"balanced": {"name": "Balanced", "speed": 6.8, "accel": 20.0, "steer": 1.0, "boost": 1.0, "mass": 1.0, "description": "Easy to learn. Ready for anything."},
	"agile": {"name": "Agile", "speed": 6.12, "accel": 22.0, "steer": 1.12, "boost": 1.0, "mass": 0.9, "description": "Quick off the line. Loves a tight corner."},
	"heavy": {"name": "Heavy", "speed": 6.8, "accel": 18.0, "steer": 0.9, "boost": 1.1, "mass": 1.2, "description": "Big boost. Needs room to turn."},
}
static func get_profile(id: String) -> Dictionary:
	return PROFILES.get(id, PROFILES.balanced).duplicate()
