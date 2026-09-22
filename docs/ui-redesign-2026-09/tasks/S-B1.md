# SLICE S-B1 — Main menu home column: tape header, GET OUT, clock, ticker

Run step 1 immediately. Minimal prose. You are GLM-5.3 Flash implementing
one bounded slice. Design is FROZEN — do not redesign.
Repo: /Volumes/HARD/projects/friday-evacuation

READ FIRST: docs/ui-redesign-2026-09/FINAL-SPEC.md section 3 (main menu).
Board: docs/ui-redesign-2026-09/variant-iter3.html (READ THE HTML for exact
structure/copy/colors).

## Scope — scripts/Main.gd ONLY (plus scenes/Main.tscn text tweaks if needed)

The home column currently: Kicker "YOUR SHIFT IS OVER." / Title "FRIDAY 5PM
EVACUATION" / Subtitle / EVACUATE / 6 stacked buttons. Transform to:

1. Kicker -> "OFFICE EVACUATION NOTICE" (orange, keep size 14, add a small
   red blinking dot: a Label child of kicker row is overkill — instead set
   kicker text to "● OFFICE EVACUATION NOTICE" and animate its modulate
   alpha 1.0->0.55->1.0 over 1.6s from _process using menu_time. The dot
   character colored separately is NOT required; whole label pulses.)
2. Title -> "GET OUT" one line, font 52 (was 42): update scenes/Main.tscn
   node text to "GET OUT" AND _build_menu_theme size. Color stays IVORY;
   add a second Label directly under (name "TitleAccent", text "OUT" is
   NOT duplicated — instead make Title a RichTextLabel? NO — keep simple:
   Title = "GET OUT" plain; skip the two-tone accent if it requires a new
   node type; acceptable fallback: Title text "GET OUT" with font_color
   IVORY unchanged).
3. Subtitle -> clock row: replace subtitle text with "4:59" + caption.
   Implementation: subtitle_label.text = "4:59 — one minute to freedom"
   with font_size 20, color PAPER (new token from S-A; if S-A not merged
   yet use Color("f2ecdc")), tabular via
   add_theme_font_size_override only (no font file exists; fine).
4. NEW DeparturesTicker: build in code inside NavColumn, after subtitle,
   before PlayButton. A PanelContainer (bg Color(0,0,0,0.35), radius 12,
   border 1px rgba(255,255,255,0.09)) containing VBox:
   - header HBox: "DEPARTURES" (9.5->use 11px, ORANGE, bold-ish 800 weight
     via theme default) + spacer + "ALL FLOORS" (11px, color 9a9aae)
   - 3 rows HBox: gate Label (min width 88, color YELLOW f2c230, 13px,
     text "GATE A"/"GATE B"/"GATE C"), dest Label (expand fill, TEXT
     color, "PARKING LOT"/"PATIO · BEERS"/"HOME"), status PanelContainer
     pill (radius 999, padding 4x8): BOARDING = bg ORANGE text INK,
     ON TIME = border LIME b9f34a text LIME, DELAYED = border YELLOW
     dashed (StyleBoxFlat has no dashed — use border width 1 color
     f2c230 at 0.55 alpha, text YELLOW).
   Name nodes DeparturesTicker/GateRow# etc. custom_minimum_size height 30
   per row. Mouse filter IGNORE on all.
5. Reorder home column: Kicker, Title, Subtitle(clock), Ticker, [spacer =
   existing scroll flex], EVACUATE (CTA stays apply_primary, add text
   subline: change EVACUATE button text to "EVACUATE" and add a Label
   UNDER the button "LAST ONE BUYS BEERS" 10.5px ORANGE_BRIGHT-ish muted,
   centered — simpler than button subtext), then nav grid: convert the 4
   secondary buttons (OTHER MODES / CUSTOMIZE RIDE / OFFICE SETUP / PLAY
   WITH FRIENDS aka host_button) into a GridContainer 2 columns x 2 rows
   (min height 48 each, they currently stack; keep the same node
   references and pressed connections — only reparent into a
   GridContainer inserted at the same position in NavColumn).
   SETTINGS + CREDITS stay as-is after the grid, plus add a QUIT pill
   row? NO — do not add QUIT (not in current game). Leave SETTINGS /
   CREDITS stacked.
6. Version footer: Label "v0.9 · 26 SEP 26" 10.5px color 9a9aae after
   CREDITS (name VersionLabel).

## Constraints
- Preserve ALL existing behavior: button signals, focus order (play
  first), _block_navigation seam, responsive portrait rules
  (_layout_responsive), MenuLayoutSmokeTest expectations. If
  MenuLayoutSmokeTest asserts the old button ORDER, check it first
  (scripts/MenuLayoutSmokeTest.gd) and keep an order it accepts — if it
  hard-fails, adapt the TEST only if the assertion is purely order-based
  and the new order is per spec (document in results).
- The home column must still fit 390px portrait width: ticker dest labels
  get ellipsis overrun; gate column fixed 88px.
- Godot 4.7.1, tabs. Only files: scripts/Main.gd, scenes/Main.tscn,
  scripts/MenuLayoutSmokeTest.gd (only if truly needed), new test
  scripts/MenuHomeRedesignTest.gd.
- MenuHomeRedesignTest.gd (SceneTree --test-mode style, copy pattern from
  MenuLayoutSmokeTest.gd): instantiate Main scene, wait 2 frames, assert:
  Title text == "GET OUT"; kicker contains "EVACUATION NOTICE"; a node
  named like DeparturesTicker exists with 3 gate rows; EVACUATE button
  still present and focused; version label present; column min size
  <= 470.
- Run headless (serial): MenuHomeRedesignTest, MenuLayoutSmokeTest,
  MenuDepartureSmokeTest, BootTest. Scan output for SCRIPT ERROR / Parse
  Error. All PASS required.
- NO commits/pushes. Never touch automated-newsletter/pitchforge.

## Report
docs/ui-redesign-2026-09/results/S-B1.md: files, commands, raw outputs,
deviations.
