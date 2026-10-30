extends RefCounted
## Separate versioned records keep old wins, cosmetics and PB files untouched.
static var PATH := "user://friday_v2.cfg"
const MAX_GHOST_FRAMES := 2400
static func read() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(PATH)
	return config

static func setting(key: String, fallback: Variant) -> Variant:
	return read().get_value("settings", key, fallback)

static func set_setting(key: String, value: Variant) -> void:
	var config := read()
	config.set_value("settings", key, value)
	config.save(PATH)

static func record(key: String, seconds: float, frames: Array) -> bool:
	if not is_finite(seconds) or seconds <= 0:
		return false
	var config := read()
	var old := float(config.get_value("records", key, 0.0))
	if old > 0 and seconds >= old:
		return false
	config.set_value("records", key, seconds)
	config.set_value("ghosts", key, frames.slice(0, MAX_GHOST_FRAMES))
	return config.save(PATH) == OK

static func ghost(key: String) -> Array:
	var data: Variant = read().get_value("ghosts", key, [])
	if not data is Array:
		return []
	var clean: Array = []
	for frame in data.slice(0, MAX_GHOST_FRAMES):
		if frame is Dictionary and frame.get("p") is Vector3 and frame.get("t") is float:
			var facing: Variant = frame.get("f", 0.0)
			if (facing is float or facing is int) and frame.p.is_finite() and is_finite(frame.t) and is_finite(float(facing)) and frame.t >= 0:
				if clean.is_empty() or frame.t > clean.back().t:
					clean.append({"p": frame.p, "t": frame.t, "f": float(facing)})
	return clean
