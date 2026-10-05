extends SceneTree

const UIThemeScript = preload("res://scripts/UITheme.gd")
const RosterScript = preload("res://scripts/CharacterRoster.gd")

func _init() -> void:
	var failures := PackedStringArray()
	var roster_errors: PackedStringArray = RosterScript.validate()
	failures.append_array(roster_errors)

	var characters: Array[Dictionary] = RosterScript.all()
	if characters.size() != 11:
		failures.append("expected 11 characters including three new coworkers, got %d" % characters.size())
	if not RosterScript.ids().has(RosterScript.DEFAULT_ID):
		failures.append("default character id missing from roster")

	var panel: StyleBoxFlat = UIThemeScript.panel_style(UIThemeScript.color(UIThemeScript.ORANGE), true)
	if panel.corner_radius_top_left < 12:
		failures.append("panel corner radius below design-system minimum")
	if panel.border_width_left != 2:
		failures.append("strong panel border should be 2px")

	var button := Button.new()
	UIThemeScript.apply_primary(button)
	if button.get_theme_font_size("font_size") < 20:
		failures.append("primary button typography too small")
	button.free()

	# S-F primitives: TapeStrip draws the yellow ground, MeterBar clamps
	# fill and honors the reference tick.
	var tape = UIThemeScript.TapeStrip.new()
	tape.size = Vector2(200, 10)
	tape._draw()
	var meter = UIThemeScript.MeterBar.new()
	meter.size = Vector2(170, 8)
	meter.maximum = 10.0
	meter.tick = 6.0
	meter.value = 25.0  # clamps fill to full width, must not throw
	if meter.value != 25.0:
		failures.append("meter value setter lost assignment")
	meter._draw()

	if failures.is_empty():
		print("[PASS] Friday visual system: 11-character roster + shared UI theme")
		quit(0)
	else:
		for failure in failures:
			push_error("[FAIL] " + failure)
		quit(1)
