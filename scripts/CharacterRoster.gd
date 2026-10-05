class_name FridayCharacterRoster
extends RefCounted

const DEFAULT_ID := "deadline_dana"

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "deadline_dana",
		"name": "Deadline Dana",
		"role": "PROJECT MANAGER",
		"tagline": "The calendar says leave. Dana says deliver.",
		"body": "ff9a1a",
		"accent": "57d7ff",
		"chair": "executive",
		"silhouette": "upright_blazer",
		"accessory": "clipboard_shield",
		"face": "determined",
	},
	{
		"id": "it_iggy",
		"name": "I.T. Iggy",
		"role": "SYSTEMS ADMIN",
		"tagline": "Has restarted the building twice.",
		"body": "57d7ff",
		"accent": "b9f34a",
		"chair": "mesh_task",
		"silhouette": "hoodie_headset",
		"accessory": "keyboard_booster",
		"face": "sleep_deprived",
	},
	{
		"id": "hr_harriet",
		"name": "H.R. Harriet",
		"role": "PEOPLE & CULTURE",
		"tagline": "This incident will require a workshop.",
		"body": "ff73b5",
		"accent": "ffd65c",
		"chair": "ergonomic",
		"silhouette": "power_bob_cardigan",
		"accessory": "policy_binder",
		"face": "professionally_concerned",
	},
	{
		"id": "intern_ian",
		"name": "Intern Ian",
		"role": "UNPAID VELOCITY",
		"tagline": "No access badge. Infinite optimism.",
		"body": "b9f34a",
		"accent": "9b82ff",
		"chair": "borrowed_stool",
		"silhouette": "oversized_hoodie",
		"accessory": "coffee_tower",
		"face": "terrified_delight",
	},
	{
		"id": "finance_fiona",
		"name": "Finance Fiona",
		"role": "BUDGET CONTROL",
		"tagline": "Every collision has a cost center.",
		"body": "9b82ff",
		"accent": "62efff",
		"chair": "premium_lumbar",
		"silhouette": "sharp_suit_bun",
		"accessory": "calculator_dash",
		"face": "unimpressed",
	},
	{
		"id": "facilities_frank",
		"name": "Facilities Frank",
		"role": "BUILDING OPERATIONS",
		"tagline": "Knows every shortcut and every loose wheel.",
		"body": "ffd65c",
		"accent": "ff6f61",
		"chair": "maintenance_cart",
		"silhouette": "hi_vis_toolbelt",
		"accessory": "mop_lance",
		"face": "seen_everything",
	},
	{
		"id": "legal_lee",
		"name": "Legal Lee",
		"role": "RISK & COMPLIANCE",
		"tagline": "Participation does not imply liability.",
		"body": "ff6f61",
		"accent": "f7f6f2",
		"chair": "leather_highback",
		"silhouette": "long_coat_glasses",
		"accessory": "waiver_scroll",
		"face": "objecting",
	},
	{
		"id": "remote_ron",
		"name": "Remote Ron",
		"role": "CAMERA OFF",
		"tagline": "Technically has not entered the office.",
		"body": "45d9ca",
		"accent": "ff9a1a",
		"chair": "gaming_rig",
		"silhouette": "blanket_headphones",
		"accessory": "webcam_drone",
		"face": "buffering",
	},
	{
		"id": "spreadsheet_stu",
		"name": "Spreadsheet Stu",
		"role": "FORMULA ENTHUSIAST",
		"tagline": "Both eyes are looking for the missing cell.",
		"body": "424b67", "accent": "ffd65c", "chair": "executive",
		"silhouette": "crooked_tie_glasses", "accessory": "calculator_dash", "face": "derpy",
	},
	{
		"id": "coffee_carl",
		"name": "Coffee Carl",
		"role": "BREAK ROOM REGULAR",
		"tagline": "One tooth. Three coffees. Zero brakes.",
		"body": "ff9a1a", "accent": "45d9ca", "chair": "borrowed_stool",
		"silhouette": "lanky_cardigan", "accessory": "coffee_tower", "face": "derpy",
	},
	{
		"id": "printer_pam",
		"name": "Printer Pam",
		"role": "PAPER JAM SPECIALIST",
		"tagline": "The printer is screaming. So is Pam.",
		"body": "ffd65c", "accent": "9b82ff", "chair": "maintenance_cart",
		"silhouette": "stocky_vest_bun", "accessory": "policy_binder", "face": "panic",
	},
]

static func all() -> Array[Dictionary]:
	return CHARACTERS.duplicate(true)

static func get_character(character_id: String) -> Dictionary:
	for character in CHARACTERS:
		if character.id == character_id:
			return character.duplicate(true)
	return CHARACTERS[0].duplicate(true)

static func ids() -> Array[String]:
	var result: Array[String] = []
	for character in CHARACTERS:
		result.append(character.id)
	return result

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for character in CHARACTERS:
		for key in ["id", "name", "role", "tagline", "body", "accent", "chair", "silhouette", "accessory", "face"]:
			if not character.has(key) or str(character[key]).strip_edges().is_empty():
				errors.append("%s missing %s" % [str(character.get("id", "unknown")), key])
		var character_id := str(character.get("id", ""))
		if seen.has(character_id):
			errors.append("duplicate id: " + character_id)
		seen[character_id] = true
	return errors
