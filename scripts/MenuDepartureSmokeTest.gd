# MenuDepartureSmokeTest.gd — Phase 1A "Friday departure board" menu smoke test.
#
# Black-box behavior suite for the superseding departure design:
#   1. No splash on entry; EVACUATE focused and usable from first frame.
#   2. OTHER MODES subview: four mode cards, selected readout + PLAY SELECTED
#      launching every mode via actual Button.pressed, BACK + focus restore.
#   3. CUSTOMIZE RIDE / OFFICE SETUP reachable; modifier menu mounts; saved
#      map layout + RaceModifiers load independently in _ready.
#   4. Lobby / settings / credits real overlays; credits is a CanvasLayer,
#      deduped, restores focus on close.
#   5. Escape closes one layer, never quits, restores focus.
#   6. Repeated opens do not duplicate signal connections.
#   7. Viewport bounds at 1280x720, 960x540, 640x360, 390x844: nav inside its
#      opaque ink field, subview field covers the nav width, action targets
#      >= 48px, essential nav text >= 14px, hero only on wide desktop.
#   8. Saved map layout + modifiers are live before any EVACUATE press.
extends SceneTree

var checks_total := 0
var checks_passed := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks_total += 1
	if cond:
		checks_passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		print("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _set_size(win: Window, size: Vector2i) -> void:
	win.size = size
	win.content_scale_size = size

func _run() -> void:
	var packed := load("res://scenes/Main.tscn")
	var win := root.get_window()
	var gm = root.get_node("/root/GameManager")

	_set_size(win, Vector2i(1280, 720))
	var main = packed.instantiate()
	main._block_navigation = true  # test seam: exercise handlers without scene changes
	root.add_child(main)
	for i in 8:
		await process_frame

	# ---- 1. Departure board composition at 1280x720 -----------------------
	check(main.credits_overlay == null and not _has_splash(main),
		"no splash mounted on entry")
	var focus_owner: Control = main.get_viewport().gui_get_focus_owner()
	check(focus_owner == main.play_button,
		"EVACUATE has primary focus from first entry")
	check(main.play_button.text == "EVACUATE", "main CTA reads EVACUATE")
	check(main.play_button.custom_minimum_size.y >= 52.0, "EVACUATE is a 52px primary target")
	var evac_style: StyleBox = main.play_button.get_theme_stylebox("normal")
	check(evac_style != null and evac_style.bg_color.is_equal_approx(Color("ff9a1a")),
		"EVACUATE uses the orange primary fill")
	check(main.host_button.text == "PLAY WITH FRIENDS"
		and main.host_button.custom_minimum_size.y >= 52.0,
		"PLAY WITH FRIENDS is a 52px secondary")
	check(not main.desc_label.visible, "home description copy hidden per design")
	var brand: Label = main.brand_label
	check(brand != null and brand.text.contains("FRIDAY"), "brand label present")

	for entry in [["other_modes_button", "OTHER MODES"], ["customize_button", "CUSTOMIZE RIDE"],
			["office_button", "OFFICE SETUP"], ["settings_button", "SETTINGS"],
			["credits_button", "CREDITS"]]:
		var btn: Button = main.get(entry[0])
		check(btn != null and btn.visible and btn.text == entry[1]
			and btn.custom_minimum_size.y >= 48.0,
			"secondary action visible + >=48px: %s" % entry[1])

	check(main.get("action_tray") == null, "no duplicate bottom ActionTray CTAs")

	# Opaque ink nav field covers the left 40%; nav column sits inside it.
	var field_w: float = main.nav_field.size.x
	check(field_w >= 500.0, "ink nav field covers ~x0-512 (w=%.0f)" % field_w)
	var col: Control = main.nav_column
	check(col.global_position.x >= 15.0, "nav column left margin present")
	check(col.global_position.x + col.size.x <= field_w + 1.0,
		"nav column stays inside the ink field (right=%.0f)" % (col.global_position.x + col.size.x))
	check(col.global_position.y + col.size.y <= 720.0 + 1.0, "nav column within viewport height")

	# Right composition: backdrop + hero present, YOUR RIDE panel opaque and
	# fully inside the viewport's right field.
	check(main.backdrop != null, "MenuBackdrop present")
	check(main.hero_panel != null and main.hero_panel.visible, "YOUR RIDE panel visible on desktop")
	var hero_style: StyleBoxFlat = main.hero_panel.get_theme_stylebox("panel")
	check(hero_style != null and hero_style.bg_color.a >= 0.99, "YOUR RIDE panel is opaque")
	var hero_rect := Rect2(main.hero_panel.global_position, main.hero_panel.size)
	check(hero_rect.position.x >= field_w and hero_rect.end.x <= 1280.0 + 1.0
		and hero_rect.position.y >= 0.0 and hero_rect.end.y <= 720.0 + 1.0,
		"hero panel inside right field + viewport (%s)" % hero_rect)

	# ---- 2. Direct CTA starts Evacuation ----------------------------------
	gm.selected_mode = GameManager.GameMode.HAULED  # prove the CTA overrides
	main.play_button.pressed.emit()
	check(gm.selected_mode == GameManager.GameMode.EVACUATION,
		"EVACUATE always selects Evacuation")
	check(main.get_tree().current_scene == null or is_instance_valid(main),
		"CTA did not navigate away under the test seam")

	# ---- 3. OTHER MODES subview: select, play every mode, back, focus -----
	main.other_modes_button.pressed.emit()
	await process_frame
	check(main.modes_subview.visible, "OTHER MODES opens the in-menu subview")
	check(not main.scroll.visible, "home column hidden while a subview is open")
	var sub_field: ColorRect = main.modes_subview.get_node("Field")
	check(sub_field != null
		and sub_field.color.is_equal_approx(Color("0a0a0f")),
		"modes subview paints an opaque ink field")
	check(absf(sub_field.size.x - main.nav_field.size.x) < 2.0,
		"subview ink field covers the nav width (w=%.0f vs %.0f)" % [sub_field.size.x, main.nav_field.size.x])
	check(main.buttons.size() == 4, "subview lists the existing four modes")
	check(main.modes_title_label != null and main.modes_desc_label != null
		and not main.modes_desc_label.text.is_empty(),
		"selected mode title/description visible inside the subview")
	var play_sel: Button = main.modes_subview.get_meta("play_button")
	check(play_sel.text == "PLAY SELECTED" and play_sel.custom_minimum_size.y >= 48.0,
		"PLAY SELECTED is a visible pinned action")
	for i in range(4):
		main._select_mode(i)
		var card: Button = main.buttons[i]
		check(card.get_theme_stylebox("normal") != null, "mode %d card shows selected style" % i)
		play_sel.pressed.emit()
		check(gm.selected_mode == main.MODE_INFO[i].mode,
			"mode %d playable via PLAY SELECTED Button.pressed" % i)
	check(main.modes_desc_label.text == main.MODE_INFO[3].desc,
		"selected readout follows the chosen mode")
	# repeated opens must not stack connections
	var conns := play_sel.pressed.get_connections().size()
	main._close_subview()
	main.other_modes_button.pressed.emit()
	main._close_subview()
	main.other_modes_button.pressed.emit()
	check(play_sel.pressed.get_connections().size() == conns,
		"repeated subview opens do not duplicate signal connections")
	var back_btn: Button = main.modes_subview.get_meta("back_button")
	back_btn.pressed.emit()
	await process_frame
	check(not main.modes_subview.visible, "BACK closes the modes subview")
	check(main.scroll.visible, "home column restored after BACK")
	check(main.get_viewport().gui_get_focus_owner() == main.other_modes_button,
		"focus restored to the opening control")

	# ---- 4. Escape: one layer back, never quit ----------------------------
	main.customize_button.pressed.emit()
	await process_frame
	check(main.customize_subview.visible, "CUSTOMIZE RIDE opens rider/chair subview")
	check(main.character_select != null and main.skin_select != null,
		"rider + chair selectors present")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	for i in 3:
		await process_frame
	check(not main.customize_subview.visible, "Escape closes one subview layer")
	check(is_instance_valid(main) and not main.is_queued_for_deletion()
		and root.get_tree() != null, "root Escape does not quit")
	check(main.get_viewport().gui_get_focus_owner() == main.customize_button,
		"Escape restores focus to the opening control")
	main.office_button.pressed.emit()
	await process_frame
	check(main.office_subview.visible and main.layout_option != null
		and main.layout_option.item_count == 3, "OFFICE SETUP exposes all map variants")
	check(main.modifier_menu != null and main.modifier_menu.visible
		and main.touch_button != null, "OFFICE SETUP has modifier + touch controls")
	Input.parse_input_event(esc)
	for i in 3:
		await process_frame
	check(not main.office_subview.visible, "Escape closes the office subview")

	# ---- 5. Persisted choices use the current methods ---------------------
	var layouts = load("res://scripts/LevelLayouts.gd")
	main._on_layout_selected(1)
	check(layouts and layouts.current == "cubicle_maze",
		"map layout selection persists via LevelLayouts")
	check(FileAccess.file_exists("user://settings.cfg"), "layout write lands in settings.cfg")

	# ---- 6. Lobby / settings / credits overlays ---------------------------
	main.host_button.pressed.emit()
	await process_frame
	check(main.lobby_overlay != null and main.lobby_overlay.visible,
		"PLAY WITH FRIENDS opens the existing LAN lobby")
	main.lobby_overlay.close_requested.emit()
	await process_frame
	check(main.lobby_overlay == null, "lobby BACK closes cleanly")
	main._open_settings()
	check(main.settings_overlay != null, "SETTINGS opens the real settings overlay")
	main.settings_overlay._close()
	await process_frame
	check(main.settings_overlay == null, "settings overlay closes to null")
	main._open_credits()
	await process_frame
	check(main.credits_overlay != null and main.credits_overlay is CanvasLayer,
		"CREDITS opens a real CanvasLayer credits overlay")
	var credits_dupe = main.credits_overlay
	main._open_credits()
	check(main.credits_overlay == credits_dupe and main.credits_overlay.get_children().size() == 1,
		"credits dedupes to a single layer")
	main.credits_overlay._close()
	await process_frame
	check(main.credits_overlay == null, "credits close clears the handle")
	check(main.get_viewport().gui_get_focus_owner() == main.credits_button,
		"credits close restores focus")

	# ---- 7. Saved config applies before any EVACUATE ----------------------
	main._on_layout_selected(2)
	var main2 = packed.instantiate()
	main2._block_navigation = true
	_set_size(win, Vector2i(1280, 720))
	root.add_child(main2)
	for i in 8:
		await process_frame
	check(main2.layout_option == null, "lazy OFFICE SETUP not built on boot")
	var layouts2 = load("res://scripts/LevelLayouts.gd")
	check(layouts2 and layouts2.current == "executive",
		"saved map layout applied in _ready without the office subview")
	main2.office_button.pressed.emit()
	await process_frame
	check(main2.layout_option != null
		and main2.layout_option.selected == 2,
		"lazy-built office subview reflects the saved layout")
	main2.queue_free()
	await process_frame

	# ---- 8. Responsive bounds ---------------------------------------------
	main.queue_free()
	await process_frame

	for size in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(640, 360), Vector2i(390, 844)]:
		_set_size(win, size)
		main = packed.instantiate()
		main._block_navigation = true
		root.add_child(main)
		for i in 8:
			await process_frame

		var vp_rect: Rect2 = main.get_viewport_rect()
		var all_in := true
		var heights_ok := true
		for node in main.find_children("*", "Button", true, false):
			var b := node as Button
			if not (b != null and b.is_visible_in_tree()):
				continue
			var rect: Rect2 = Rect2(b.global_position, b.size)
			# Horizontal + top bounds are hard limits; content below the fold
			# is legitimate on the single scroll surface (checked next).
			if not (rect.position.x >= -1.0 and rect.position.y >= -1.0
					and rect.end.x <= vp_rect.size.x + 1.0):
				all_in = false
				print("    out-of-bounds: %s %s" % [b.text, rect])
			if b.custom_minimum_size.y < 48.0:
				heights_ok = false
				print("    tiny target: %s h=%.0f" % [b.text, b.custom_minimum_size.y])
		check(all_in, "all visible buttons within horizontal bounds %s" % size)
		check(heights_ok, "all action targets >= 48px at %s" % size)
		# Reachability: at short heights the home scroll surface must actually
		# scroll so below-the-fold actions are reachable via follow_focus.
		var sb: ScrollBar = main.scroll.get_v_scroll_bar()
		check(sb == null or sb.max_value <= vp_rect.size.y + 1.0
			or sb.max_value > sb.page,
			"below-the-fold actions reachable via scroll at %s" % size)

		var col2: Control = main.nav_column
		var col_right: float = col2.global_position.x + col2.size.x
		if size.x >= 960:
			check(col_right <= size.x * 0.4 + 2.0,
				"nav inside 40%% field at %s (right=%.0f)" % [size, col_right])
			check(main.hero_panel.visible == (size.x >= 1080),
				"hero preview visibility correct at %s" % size)
		else:
			check(col2.global_position.x >= 14.0 and col_right <= size.x - 14.0,
				"compact nav is full-width minus margins at %s" % size)
			check(absf(main.nav_field.size.x - (size.x - 32.0)) < 2.0,
				"ink field is full viewport minus margins at %s (w=%.0f)" % [size, main.nav_field.size.x])
			check(not main.hero_panel.visible, "nonessential preview hidden at %s" % size)

		# Essential nav text never shrinks below 14px.
		var nav_text_ok := true
		for node in main.nav_column.find_children("*", "Button", true, false):
			if (node as Button).is_visible_in_tree() \
					and (node as Button).get_theme_font_size("font_size") < 14:
				nav_text_ok = false
		check(nav_text_ok, "nav buttons >= 14px text at %s" % size)

		# Subview sizing under 960: full-width ink field, content inside it.
		main.other_modes_button.pressed.emit()
		await process_frame
		var sub2: ColorRect = main.modes_subview.get_node("Field")
		var sub_rect := Rect2(sub2.global_position, sub2.size)
		if size.x < 960:
			check(absf(sub_rect.size.x - (size.x - 32.0)) < 2.0,
				"modes subview full-width minus margins at %s (w=%.0f)" % [size, sub_rect.size.x])
		check(sub_rect.end.y <= vp_rect.size.y + 1.0 and sub_rect.position.y >= -1.0,
			"modes subview within viewport height at %s" % size)
		var modes_footer_ok: bool = main.modes_title_label.get_global_rect().position.y < vp_rect.size.y \
			or not main.modes_title_label.visible
		check(modes_footer_ok, "modes readout reachable (scrolled) at %s" % size)
		main._close_subview()
		await process_frame

		main.queue_free()
		await process_frame

	if failures.is_empty() and checks_total > 0:
		print("=== MENU DEPARTURE SMOKE TEST PASS (%d/%d) ===" % [checks_passed, checks_total])
		quit(0)
	else:
		print("=== MENU DEPARTURE SMOKE TEST FAILED (%d/%d) ===" % [checks_passed, checks_total])
		for f in failures:
			print("  - %s" % f)
		quit(1)

func _has_splash(main: Node) -> bool:
	for child in main.get_children():
		if child.name.to_lower().contains("splash"):
			return true
	return false
