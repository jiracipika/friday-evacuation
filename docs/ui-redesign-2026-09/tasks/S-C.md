# SLICE S-C — Mode select rework ("PICK YOUR EXIT")

Run step 1 immediately. Minimal prose. You are GLM-5.3 Flash implementing
one bounded slice. Repo: /Volumes/HARD/projects/friday-evacuation.
Base: commit 7474143. Design FROZEN: docs/ui-redesign-2026-09/FINAL-SPEC.md
section 4 + board variant-final.html screen F2.

## Scope — scripts/Main.gd (subview builders), scripts/ModeCard.gd, new test

Current modes subview: _subview_shell("MODES", ...) with ModeCard buttons
84/56px, title+desc footer readout, PLAY SELECTED. Transform to:

1. Shell title "MODES" -> "PICK YOUR EXIT" (keep BACK row pattern).
2. ModeCard.gd rework to spec F2. Each card is a grid: [icon 40px]
   [title 18px + desc 12px] [meta right-aligned]. Keep it a Button.
   - Icon: draw via _draw in a nested Control (name "IconGlyph"):
     EVACUATION = pennant flag (mast rect + triangle polygon, ORANGE fill),
     HAULED = flag mirrored (CORAL), SHOP & SEEK = eye outline (arc via
     draw_arc, muted) with pupil dot, PIZZA COLONY = dashed-look circle
     (draw_arc segments, VIOLET). Muted stroke #c4c4d2 unselected; icon
     border ORANGE when selected. No emoji.
   - Meta slots FIXED two lines right-aligned (Labels in VBox, name
     "MetaBox"): line1 category, line2 crew. Data per spec:
     EVACUATION: PRIMARY / 1-4 PLAYERS (line1 ORANGE)
     HAULED: VERSUS / TEAMS OF 2+
     SHOP & SEEK: SOCIAL / 1 SEEKER · 3+ HIDERS
     PIZZA COLONY: CO-OP / 2-4 PLAYERS
   - Selected state HARD per R9: border ORANGE 2px, 4px left rail
     (accent-colored, including unselected cards' category color:
     HAULED coral, S& S lime, PIZZA violet — rail visible always but
     ORANGE-accented only when selected? SIMPLIFY: rail = category
     color always; selection adds orange border + orange icon ring +
     "SELECTED" mini-pill (PanelContainer radius 999, bg ORANGE, text
     INK 8.5px) pinned top-right overlapping -8px (use a child Control
     anchored top-right, offset up 8).
   - Keep existing configure() API + set_selected(); extend with
     category/crew params via new optional args (update call site).
   - Min height 78 all cards (drop the 84/56 split), separation 10.
3. Footer readout block (modes_title_label/modes_desc_label) becomes the
   desc panel per F2: PanelContainer bg gradient impossible — use flat
   Color(0,0,0,0.45) radius 12 border 1px rgba(255,255,255,0.09);
   - FORM stamp: Label "FORM EX-01" rotated -4deg (Control rotation_degrees
     on a Label with pivot_offset centered), border 2px RED e04a3a, text
     RED, 9px, positioned top-right of panel overlapping -10px.
   - Title line: selected mode name ORANGE 11px tracked (existing
     modes_title_label restyle).
   - Desc: modes_desc_label, but emphasize "before 5:00 PM" — BBCode
     bold yellow: set bbcode_enabled true, wrap the phrase in
     [color=#f2c230][b]5:00 PM sharp[/b][/color]. Update MODE_INFO desc
     strings if needed (keep source data, transform in _select_mode).
   - CAUTION chips row: HFlowContainer name "CautionRow", three pills
     (radius 8, border 1px dashed impossible -> border YELLOW at 0.55
     alpha, text YELLOW 10px): "COFFEE = BOOST", "WATER = TRAP",
     "STAPLERS BITE". Shown only when EVACUATION selected (hide otherwise).
4. PLAY SELECTED -> "CLOCK OUT" (keep apply_primary, height 52, all
   signal wiring identical).

## Constraints
- Preserve behavior: _select_mode/_play_selected_mode/focus flow
  (S-PAD: BACK pad-reachable, cards focusable), MenuDepartureSmokeTest
  expectations (it asserts modes subview geometry/scroll at 390px — check
  its assertions BEFORE finalizing; adapt TEST only if purely visual
  order-based, document it).
- Portrait 390px: cards must fit — meta box may drop to one line (crew)
  under 560px via _is_narrow-ish check at build; ellipsis everywhere.
- Godot 4.7.1, tabs. Files: Main.gd, ModeCard.gd, MenuDepartureSmokeTest.gd
  (only if needed), NEW scripts/ModeSelectRedesignTest.gd.
- Test asserts: shell title text, 4 ModeCards each with IconGlyph +
  MetaBox (2 labels, correct data), selected card has border style with
  ORANGE border + SELECTED pill visible, desc panel has FORM stamp +
  CautionRow with 3 chips (visible when idx 0), CTA text "CLOCK OUT",
  390px fit (cards min width <= 366).
- Run serially (scan SCRIPT ERROR/Parse Error): ModeSelectRedesignTest,
  MenuDepartureSmokeTest, PadNavSmokeTest, MenuLayoutSmokeTest,
  MenuHomeRedesignTest, BootTest. ALL PASS.
- No commits. Never touch automated-newsletter/pitchforge.

## Report
docs/ui-redesign-2026-09/results/S-C.md: files, commands, raw tails,
deviations.
