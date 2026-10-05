class_name FridayCharacterDesign
extends RefCounted
## Bounded, save/RPC-safe cosmetic choices. Empty overrides keep preset defaults.

const OPTIONS := {
	"outfit": ["blazer", "hoodie", "cardigan", "hi_vis"],
	"hair": ["side_part", "bob", "bun", "bedhead", "bald"],
	"expression": ["focused", "sleepy", "derpy", "panic"],
	"build": ["regular", "stocky", "lanky"],
	"skin_tone": ["f3cfaf", "e5ad83", "c68b61", "a66a47", "774a35", "50352c"],
	"hair_color": ["332c32", "71462f", "dca85b", "c9cbd1", "b76e55", "7865ad"],
	"shirt_color": ["ff9a1a", "57d7ff", "ff73b5", "b9f34a", "9b82ff", "ffd65c", "ff6f61", "45d9ca", "f7f6f2", "424b67"],
	"accent_color": ["ff9a1a", "57d7ff", "ff73b5", "b9f34a", "9b82ff", "ffd65c", "ff6f61", "45d9ca", "f7f6f2", "62efff"],
	"accessory": ["clipboard_shield", "keyboard_booster", "policy_binder", "coffee_tower", "calculator_dash", "mop_lance", "waiver_scroll", "webcam_drone", "none"],
}
const LABELS := {
	"outfit": "OUTFIT", "hair": "HAIR", "expression": "EXPRESSION",
	"build": "BUILD", "skin_tone": "SKIN TONE", "hair_color": "HAIR COLOR",
	"shirt_color": "OUTFIT COLOR", "accent_color": "ACCENT", "accessory": "OFFICE PROP",
}
const COLOR_NAMES := {
	"f3cfaf": "Porcelain", "e5ad83": "Peach", "c68b61": "Honey",
	"a66a47": "Caramel", "774a35": "Chestnut", "50352c": "Espresso",
	"332c32": "Ink", "71462f": "Brown", "dca85b": "Golden",
	"c9cbd1": "Silver", "b76e55": "Copper", "7865ad": "Lilac",
	"ff9a1a": "Deadline orange", "57d7ff": "Printer cyan", "ff73b5": "HR pink",
	"b9f34a": "Highlighter lime", "9b82ff": "Spreadsheet violet", "ffd65c": "Safety yellow",
	"ff6f61": "Incident coral", "45d9ca": "Mint", "f7f6f2": "Paper white",
	"424b67": "Office navy", "62efff": "Ice blue",
}
const PRESETS := {
	"deadline_dana": ["blazer", "side_part", "focused", "regular", "c68b61", "332c32"],
	"it_iggy": ["hoodie", "bedhead", "sleepy", "lanky", "f3cfaf", "71462f"],
	"hr_harriet": ["cardigan", "bob", "focused", "regular", "774a35", "332c32"],
	"intern_ian": ["hoodie", "bedhead", "panic", "lanky", "e5ad83", "dca85b"],
	"finance_fiona": ["blazer", "bun", "sleepy", "regular", "a66a47", "332c32"],
	"facilities_frank": ["hi_vis", "bald", "focused", "stocky", "e5ad83", "c9cbd1"],
	"legal_lee": ["blazer", "side_part", "focused", "lanky", "50352c", "c9cbd1"],
	"remote_ron": ["hoodie", "bedhead", "derpy", "stocky", "c68b61", "71462f"],
	"spreadsheet_stu": ["blazer", "side_part", "derpy", "stocky", "f3cfaf", "b76e55"],
	"coffee_carl": ["cardigan", "bald", "derpy", "lanky", "774a35", "332c32"],
	"printer_pam": ["hi_vis", "bun", "panic", "stocky", "e5ad83", "7865ad"],
}

static func sanitize(raw: Variant) -> Dictionary:
	var clean := {}
	if raw is Dictionary:
		for key in OPTIONS:
			if raw.get(key) is String and OPTIONS[key].has(raw[key]):
				clean[key] = raw[key]
	return clean

static func resolve(character: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var preset: Array = PRESETS.get(str(character.get("id", "")), PRESETS.deadline_dana)
	var result := {}
	var keys := ["outfit", "hair", "expression", "build", "skin_tone", "hair_color"]
	for i in keys.size():
		result[keys[i]] = preset[i]
	result.shirt_color = character.get("body", "ff9a1a")
	result.accent_color = character.get("accent", "57d7ff")
	result.accessory = character.get("accessory", "clipboard_shield")
	result.merge(sanitize(overrides), true)
	return result

static func display_name(value: String) -> String:
	return COLOR_NAMES.get(value, value.replace("_", " ").capitalize())
