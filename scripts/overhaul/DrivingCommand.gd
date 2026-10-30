extends RefCounted
## The only simulation input. Camera/device/AI concerns stop at this boundary.
static func make(move := Vector2.ZERO, boost := false, drift := false, hop := false, item := false, seq := 0) -> Dictionary:
	return {"move": move.limit_length(), "boost": boost, "drift": drift, "hop": hop, "item": item, "seq": seq}

static func clean(raw: Dictionary) -> Dictionary:
	var value: Variant = raw.get("move", Vector2.ZERO)
	var move: Vector2 = value if value is Vector2 else Vector2.ZERO
	if not is_finite(move.x) or not is_finite(move.y):
		move = Vector2.ZERO
	var seq: Variant = raw.get("seq", 0)
	return make(move, raw.get("boost", false) == true, raw.get("drift", false) == true, raw.get("hop", false) == true, raw.get("item", false) == true, clampi(seq, 0, 2147483647) if seq is int else 0)
