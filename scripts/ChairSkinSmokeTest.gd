extends SceneTree

# ChairSkinSmokeTest.gd — Phase 8A verification.
# Covers: skin roster schema, unlock boundary math, per-skin variant
# geometry on the REAL PlayerChair scene, stat personality application,
# rider mounting with seat_rise, and wheel-count sanity per chassis.

const Skins = preload("res://scripts/ChairSkins.gd")

var chairs: Array[CharacterBody3D] = []
var failures := PackedStringArray()
var checks := 0
var frames := 0
var expected_wheels := {
	"office_standard": 5, "bean_bag": 0, "exercise_ball": 0,
	"shopping_cart": 5, "toilet": 0, "racing_seat": 5,
}

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)

func feq(a: float, b: float) -> bool:
	return absf(a - b) < 0.001

func _init() -> void:
	# --- 1. Roster schema ---
	var skins: Array[Dictionary] = Skins.all()
	check(skins.size() == 6, "expected 6 skins, got %d" % skins.size())
	var ids := {}
	var prev_threshold := -1
	for skin in skins:
		var id := String(skin["id"])
		check(not ids.has(id), "duplicate skin id %s" % id)
		ids[id] = true
		for key in ["name", "tagline", "unlock_wins", "jump_mult", "friction_mult", "boost_mult", "seat_rise", "sfx"]:
			check(skin.has(key), "%s missing key %s" % [id, key])
		var threshold := int(skin["unlock_wins"])
		check(threshold > prev_threshold,
			"unlock_wins not strictly ascending at %s (%d after %d)" % [id, threshold, prev_threshold])
		prev_threshold = threshold
		check(float(skin["jump_mult"]) > 0.0 and float(skin["friction_mult"]) > 0.0 and float(skin["boost_mult"]) > 0.0,
			"%s has a zero/negative stat multiplier" % id)
	check(Skins.get_skin("nonexistent")["id"] == Skins.DEFAULT_ID, "unknown id must fall back to default skin")

	# --- 2. Unlock math ---
	check(Skins.is_unlocked("office_standard", 0), "default skin must be unlocked at 0 wins")
	check(Skins.is_unlocked("bean_bag", 1), "bean bag unlocks at exactly 1 win")
	check(not Skins.is_unlocked("toilet", 9), "throne locked at 9 wins")
	check(Skins.is_unlocked("toilet", 10), "throne unlocked at 10 wins")
	var fresh := Skins.newly_unlocked(0, 1)
	check(fresh.size() == 1 and fresh[0] == "Bean Bag", "(0,1) should unlock only Bean Bag, got %s" % str(fresh))
	check(Skins.newly_unlocked(1, 1).is_empty(), "(1,1) must unlock nothing — no win, no unlock")
	var mid := Skins.newly_unlocked(4, 6)
	check(mid.size() == 1 and mid[0] == "Shopping Cart", "(4,6) should unlock only Shopping Cart, got %s" % str(mid))
	check(Skins.newly_unlocked(24, 25)[0] == "Racing Seat", "(24,25) should unlock Racing Seat")
	var leap := Skins.newly_unlocked(5, 25)
	check(leap.size() == 2 and leap[0] == "The Throne" and leap[1] == "Racing Seat",
		"(5,25) should unlock Throne then Racing Seat in threshold order, got %s" % str(leap))
	var next2 := Skins.next_unlock(2)
	check(String(next2["id"]) == "exercise_ball" and int(next2["progress"]) == 2 and int(next2["unlock_wins"]) == 3,
		"next_unlock at 2 wins should be exercise_ball 2/3")
	check(Skins.next_unlock(25).is_empty(), "next_unlock at 25 wins should be empty (all unlocked)")

	# --- 3. Per-skin real-scene instantiation ---
	var packed := load("res://scenes/PlayerChair.tscn")
	for skin in skins:
		var id := String(skin["id"])
		var chair: CharacterBody3D = packed.instantiate()
		chair.skin_id = id
		chair.use_global_skin = false
		chair.player_color = Color(0.8, 0.4, 0.2)
		chair.position = Vector3(chairs.size() * 2.0, 1.0, 0)
		chairs.append(chair)
		root.add_child.call_deferred(chair)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var skins: Array[Dictionary] = Skins.all()
	for i in range(chairs.size()):
		var chair := chairs[i]
		var skin := skins[i]
		var id := String(skin["id"])
		if not is_instance_valid(chair):
			failures.append("%s chair was freed before checks" % id)
			continue
		# Skin resolved onto the chair.
		check(chair.skin_id == id, "%s chair did not keep its skin_id (got %s)" % [id, chair.skin_id])
		check(chair.skin.get("id", "") == id, "%s chair skin dict not resolved" % id)
		# Stat personality applied exactly once.
		check(feq(chair.jump_force, 8.0 * float(skin["jump_mult"])),
			"%s jump_force %.3f != %.3f" % [id, chair.jump_force, 8.0 * float(skin["jump_mult"])])
		check(feq(chair.friction, 16.0 * float(skin["friction_mult"])),
			"%s friction %.3f != %.3f" % [id, chair.friction, 16.0 * float(skin["friction_mult"])])
		check(feq(chair.boost_force, 28.0 * float(skin["boost_mult"])),
			"%s boost_force %.3f != %.3f" % [id, chair.boost_force, 28.0 * float(skin["boost_mult"])])
		# Rider mounted with seat_rise.
		if chair.rider_root == null:
			failures.append("%s did not build a rider on its variant chassis" % id)
		else:
			check(feq(chair.rider_y_offset, float(skin["seat_rise"])),
				"%s rider_y_offset %.3f != seat_rise %.3f" % [id, chair.rider_y_offset, float(skin["seat_rise"])])
			if float(skin["seat_rise"]) != 0.0:
				check(feq(chair.rider_root.position.y, float(skin["seat_rise"])),
					"%s rider not lifted by seat_rise" % id)
		# Wheel count per chassis + variant geometry markers.
		check(chair.chair_wheels.size() == int(expected_wheels[id]),
			"%s expected %d wheels, got %d" % [id, int(expected_wheels[id]), chair.chair_wheels.size()])
		match id:
			"exercise_ball":
				check(chair.get_node_or_null("ModelParent/ProceduralChair/Ball") != null, "ball chair missing Ball mesh")
			"bean_bag":
				check(chair.get_node_or_null("ModelParent/ProceduralChair/BeanBase") != null, "bean bag missing BeanBase mesh")
			"toilet":
				check(chair.chair_seat != null, "throne should assign its seat ring")
			"shopping_cart":
				var chassis := chair.get_node_or_null("ModelParent/ProceduralChair")
				check(chassis != null and chassis.get_child_count() > 10, "cart chair missing basket/handle decor")
	# Distinct skins must feel distinct: at least 5 unique stat triples.
	var triples := {}
	for skin in skins:
		triples["%s|%s|%s" % [skin["jump_mult"], skin["friction_mult"], skin["boost_mult"]]] = true
	check(triples.size() >= 5, "stat personalities not distinct enough (%d unique triples)" % triples.size())

	# Flush sfx wiring survives in AudioManager (text-level guard).
	var am := FileAccess.open("res://scripts/AudioManager.gd", FileAccess.READ)
	check(am != null and "\"flush\"" in am.get_as_text(), "AudioManager lost the flush effect")

	if failures.is_empty() and checks > 0:
		print("[PASS] ChairSkinSmokeTest: %d checks — schema, unlocks, variant geometry, stats, riders" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("[FAIL] " + failure)
		printerr("[FAIL] %d/%d checks failed" % [failures.size(), checks])
		quit(1)
	return false
