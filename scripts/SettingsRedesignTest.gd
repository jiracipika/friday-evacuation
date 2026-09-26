# SettingsRedesignTest.gd — S-D settings-rework verification.
#
# Pins the S-D slice (docs/ui-redesign-2026-09/tasks/S-D.md):
#   - every HSlider is wrapped in a MeterTrack that draws the two-part
#     visible fill (StyleBoxFlat grooves can't do partial fill), with a
#     fill fraction that actually tracks the slider value;
#   - slider rows use ONE label pattern: name left, orange value right,
#     value label live-updates with the slider;
#   - every CheckButton row carries an ON/OFF state tag that matches the
#     button state and re-colors (LIME when ON) on toggle;
#   - header carries the ● AUTOSAVED indicator, footer carries BACK +
#     version beside a hairline separator;
#   - scroll container has the INK bottom fade;
#   - dropdown rows show the NAME only — no value duplicated from the
#     OptionButton items into the label;
#   - the whole panel still fits a 390px portrait viewport.
# Run: godot --headless --path . --script scripts/SettingsRedesignTest.gd
extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + description)

func _init() -> void:
	_run.call_deferred()

func _cfg_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes("user://settings.cfg")

func _restore_cfg(bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		return
	var f := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _labels_in(parent: Node) -> Array:
	var out: Array = []
	for child in parent.get_children():
		if child is Label:
			out.append(child)
	return out

func _run() -> void:
	var SettingsScript: GDScript = load("res://scripts/Settings.gd")
	var cfg_backup := _cfg_bytes()

	# ---------- desktop-size mount ----------
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var settings: Control = SettingsScript.new()
	main.add_child(settings)
	for i in 12:
		await process_frame

	# 1. MeterTrack: every HSlider is wrapped, wrapper sized by layout.
	var sliders: Array = settings.find_children("*", "HSlider", true, false)
	check(sliders.size() >= 5, "settings exposes sliders (%d)" % sliders.size())
	var all_wrapped := true
	var any_track_wide := false
	for s in sliders:
		var wrapper: Control = s.get_parent()
		if wrapper == null or wrapper.get_script() != SettingsScript.MeterTrack:
			all_wrapped = false
			continue
		if wrapper.size.x > 40.0:
			any_track_wide = true
	check(all_wrapped, "every HSlider sits inside a MeterTrack wrapper")
	check(any_track_wide, "at least one MeterTrack has layout width (fill is visible)")

	# 2. Fill fraction tracks the value (master 100 -> 1.0; set 30 -> 0.30).
	var master: HSlider = settings.master_slider
	var mtrack: Control = master.get_parent()
	check(absf(mtrack.get_fill_fraction() - 1.0) < 0.02,
		"fill fraction is 1.0 at max value")
	master.value = 30.0
	await process_frame
	await process_frame
	check(absf(mtrack.get_fill_fraction() - 0.30) < 0.01,
		"fill fraction tracks value after change (30 -> 0.30)")
	var expected_px: float = 0.30 * mtrack.size.x
	check(absf(mtrack.get_fill_width() - expected_px) <= 2.0,
		"fill width matches fraction within 2px (%.1f vs %.1f)" % [mtrack.get_fill_width(), expected_px])

	# 3. Slider row label pattern: name left + orange value right, live.
	var value_label: Label = null
	for child in mtrack.get_parent().get_children():
		if child == mtrack:
			break
		if child is HBoxContainer:
			var found: Label = child.get_node_or_null("ValueLabel")
			if found:
				value_label = found
	check(value_label != null, "slider row has a ValueLabel sibling row")
	if value_label:
		check(value_label.text == "30", "value label live-updates with slider (got %s)" % value_label.text)
		var val_color: Color = value_label.get_theme_color("font_color")
		check(val_color == Color("ff9a1a"), "value label is ORANGE")

	# 4. Toggle rows: ON/OFF tag matches state and flips with it.
	var toggles: Array = settings.find_children("*", "CheckButton", true, false)
	check(toggles.size() >= 8, "settings exposes toggles (%d)" % toggles.size())
	var tags_ok := true
	var colors_ok := true
	for t in toggles:
		var row: Control = t.get_parent()
		var tag: Label = row.get_node_or_null("StateTag") if row else null
		if tag == null:
			tags_ok = false
			continue
		if tag.text != ("ON" if t.button_pressed else "OFF"):
			tags_ok = false
		var want := Color("b9f34a") if t.button_pressed else Color("9a9aae")
		if tag.get_theme_color("font_color") != want:
			colors_ok = false
	check(tags_ok, "every CheckButton row has an ON/OFF tag matching state")
	check(colors_ok, "state tag colors follow ON/OFF state (LIME / faint)")
	var shake: CheckButton = settings.shake_toggle
	var was_pressed: bool = shake.button_pressed
	shake.button_pressed = not was_pressed
	await process_frame
	var shake_tag: Label = shake.get_parent().get_node("StateTag")
	check(shake_tag.text == ("ON" if shake.button_pressed else "OFF"),
		"state tag re-syncs when the toggle flips")
	shake.button_pressed = was_pressed
	await process_frame

	# 5. Header autosave indicator.
	var autosave: Label = settings.find_child("AutosaveLabel", true, false)
	check(autosave != null and "AUTOSAVED" in autosave.text,
		"header carries the AUTOSAVED indicator")
	if autosave:
		check(autosave.get_theme_color("font_color") == Color("b9f34a"),
			"autosave indicator is LIME")

	# 6. Footer: BACK + version in one row.
	var footer: Control = settings.find_child("Footer", true, false)
	check(footer != null, "footer row exists")
	if footer:
		var has_back := false
		var version: Label = footer.get_node_or_null("VersionLabel")
		for child in footer.get_children():
			if child is Button and child.text == "BACK":
				has_back = true
		check(has_back, "footer holds the BACK button")
		check(version != null and version.text.begins_with("v0.9"),
			"footer holds the version label")

	# 7. Scroll fade node present.
	check(settings.find_child("ScrollFade", true, false) != null,
		"scroll container has the INK bottom fade")

	# 8. Dropdown rows: the label shows the NAME, never an item value.
	var option_buttons: Array = settings.find_children("*", "OptionButton", true, false)
	check(option_buttons.size() >= 3, "settings exposes dropdowns (%d)" % option_buttons.size())
	var dup_found := false
	for ob in option_buttons:
		var row: Control = ob.get_parent()
		if row == null or not (row is VBoxContainer):
			continue
		var items: Array = []
		for i in ob.item_count:
			var item_text: String = ob.get_item_text(i)
			if item_text.length() >= 5:
				items.append(item_text.to_lower())
		for lbl in _labels_in(row):
			var low: String = String(lbl.text).to_lower()
			for item_text in items:
				if item_text in low:
					dup_found = true
					printerr("  duplicated value: row '%s' contains item '%s'" % [lbl.text, item_text])
	check(not dup_found, "no dropdown row label duplicates an item value")

	# ---------- 390px portrait fit ----------
	settings.queue_free()
	await process_frame
	var win: Window = root
	win.size = Vector2i(390, 844)
	win.content_scale_size = Vector2i(390, 844)
	await process_frame
	var settings2: Control = SettingsScript.new()
	main.add_child(settings2)
	for i in 12:
		await process_frame
	var vp_w: float = settings2.get_viewport_rect().size.x
	var min_w: float = settings2.get_combined_minimum_size().x
	check(min_w <= vp_w + 2.0, "portrait 390: settings min width fits (%.0f vs %.0f)" % [min_w, vp_w])
	var overflow := false
	var stack: Array = [settings2]
	while not stack.is_empty():
		var node: Control = stack.pop_back()
		for child in node.get_children():
			if child is Control:
				stack.append(child)
		if node == settings2:
			continue
		var m: Vector2 = node.get_combined_minimum_size()
		if m.x > vp_w + 2.0:
			overflow = true
			printerr("  overflow: %s min=%.0f" % [node.name, m.x])
	check(not overflow, "portrait 390: every row's minimum width fits")
	check(sliders.size() > 0 and checks > 0, "sanity: checks actually ran")

	settings2.queue_free()
	await process_frame
	main.queue_free()
	await process_frame
	_restore_cfg(cfg_backup)

	var passed := checks - failures
	print("SettingsRedesignTest: %d/%d checks PASS" % [passed, checks])
	quit(1 if failures else 0)
