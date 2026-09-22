# FROZEN UI DESIGN SPEC — "AFTER HOURS" (Sep 22 2026)

Status: LOCKED at 9.3/10 external art-director review. This document is the
single source of truth for the menu/overlay redesign. Reference board:
variant-iter3.html (main menu), variant-final.html (modes/settings/how-to).
Boards PNG: /tmp/fe-ui/boards/final-main.png (archive to docs before /tmp wipe).

Lineage: survey (10 captures) -> variant-a Departure Board (4/10) ->
variant-b Safety Card (5/10) -> merged variant-final (7/10) ->
iter3 fixes (7.5) -> iter3b blockers closed (8.5) -> should-fixes (9.3 LOCK).

## 1. Concept

"GET OUT" — the main menu is an OFFICE EVACUATION NOTICE pinned over the
dusk skyline seen through the office window. Departure-board semantics
(4:59 clock, DEPARTURES ticker, gates) carry the comedy. Safety-card motifs
(hazard tape, form stamps, spec sheets) give personality. One accent family.

## 2. Tokens (extend UITheme.gd — map to FridayUITheme consts)

Colors (hex, all opaque fills per user preference):
- BG 0a0a0f / SURFACE 15151f / RAISED 1c1c2e / HOVER 25253a (existing)
- TEXT f7f6f2 / MUTED c4c4d2 (RAISED from 9b9baa) / FAINT 9a9aae (uplift)
- ORANGE ff9a1a / ORANGE_BRIGHT ffbd4a / INK 231303 (text on orange)
- PAPER f2ecdc (clock digits) / GREEN 2fa05a (exit sign, on-time)
- YELLOW f2c230 (hazard tape alt, gate letters, DELAYED) / RED e04a3a
- CYAN/LIME/CORAL/VIOLET unchanged (mode categories, player dots)
- Chair read color: teal 49c6d6 -> 2e8f9e gradient (matches in-game chair)

NEW consts needed: TEXT_MUTED value update, FAINT, PAPER, GREEN, YELLOW,
RED, INK, TICKER_BG rgba(0,0,0,.35), DIM rgba(5,5,9,.72-.8).

Radii: 8 (sm: buttons/inputs) / 12 (md: cards, CTA) / 16 (lg: modals) /
999 (pills). No other radii anywhere.

Rhythm: 8px base. Section gap 24-26, in-group 10-12, control gap 7-8.
CTA min-height 62 (main) / 52-56 (secondary contexts). Nav buttons 48.
Footer pills 32.

Elevation: e1 = shadow(0,2,8,black .5) cards/buttons; e2 = (0,10,28,.65)
modals + ride card. Panels also get 1px border rgba(255,255,255,.06-.09).

## 3. Main menu layout (1280x720)

Left column x=26 w=446 (responsive: 390px portrait collapses to full-width
column, ticker rows hide dest column; min width 305 preserved):
- Hazard tape header 16px (ink/yellow 45deg stripes, radius 8 top)
- Panel: kicker "OFFICE EVACUATION NOTICE" 13px ORANGE +red blink dot
- H1 "GET *OUT*" 56px, OUT in ORANGE (title = the action, not the subtitle)
- Clock "4:59" 30px PAPER on INK badge, tabular nums, seconds digit YELLOW
  pulsing 1s; caption "one minute to freedom" lowercase muted 13.5
- DEPARTURES ticker: 3 rows GATE/DEST/STATUS. Status pills: BOARDING
  (orange fill/ink), ON TIME (lime outline), DELAYED (yellow dashed).
  Content: GATE A PARKING LOT/BOARDING, GATE B PATIO BEERS/ON TIME,
  GATE C HOME/DELAYED (amber dashed = the joke lands)
- CTA EVACUATE 62px orange gradient + inset bevel + soft glow pulse 2.4s,
  run pictogram (dark silhouette, not color emoji), sub "LAST ONE BUYS
  BEERS" 10.5px 900 weight. SPACE/A hint beneath.
- Nav 2x2: FRIENDS LAN / OTHER MODES / CUSTOMIZE RIDE / OFFICE SETUP,
  48px, drawn 16px line icons (single accent per icon, 1.8 stroke)
- Footer: SETTINGS/CREDITS/PUNCH OUT pills 32px + version tabular nowrap
Right side:
- Window: EVEN mullions (26px frame #20202f), sill 26px, ceiling fixture
  bars (rounded, deliberate, with mount notch), office prop silhouettes
  (water cooler with cyan bottle glow, copier, ficus) readable at 10-15%
  lift, skyline + sun between mullion panes, grain overlay 5%
- EXIT sign: green #2fa05a, NO glow, opacity .92 — signage not a button
- Ride card docked to right pane (right 52, top 126, w 330): tape strip
  4px under top edge, SPEC 07-A chip, chair pictogram (5-star base with
  hub+4 arms+casters #4a4a66/#73739a, tilted back, headrest, armrest),
  warm glow pool, "THE STANDARD / DRIVER · DANA PM", 3 honest meters
  (JUMP/GRIP/BOOST) with 1.0 baseline tick at 50%, orange fill up,
  coral dashed fill for debuffs, tabular values

## 4. Mode select ("PICK YOUR EXIT")

Same left column (w 520). Mode cards: icon tile 40px with drawn pictogram
(flag/flag-flipped/eye/pizza-slice, muted strokes, orange only when
selected), title 18, desc 12, meta slots FIXED two lines (category +
crew: "PRIMARY/1-4 PLAYERS", "VERSUS/TEAMS OF 2+", "SOCIAL/1 SEEKER 3+
HIDERS", "CO-OP/2-4 PLAYERS"). Selected: orange border + 4px left rail +
translateX(4) + "SELECTED" mini-pill overlapping top-right (orange fill,
ink text) — hard state, not brightness. Desc block: FORM EX-01 red stamp
rotated -4deg, yellow "5:00 PM sharp" emphasis inline, CAUTION chips row
(yellow dashed: COFFEE=BOOST / WATER=TRAP / STAPLERS BITE). CTA "CLOCK OUT".

## 5. Settings

Centered 560 modal, tape header, sections VIDEO/AUDIO/ACCESSIBILITY.
ONE label pattern: label left + tabular orange value right + full-width
control below. Sliders: 6px track, orange fill to thumb (thumb TERMINATES
fill), 18px ORANGE_BRIGHT grabber with dark ring; value 0-100 tabular.
Dropdowns: RAISED fill, chevron, no duplicated value in label row.
Toggles: row container 44px + pill switch (orange+white ON, #2c2c40+#8a8a9c
OFF) + text state tag (LIME ON / FAINT OFF). Autosave indicator LIME.
Scroll fade at bottom edge (gradient mask). Footer: BACK + version,
border-top hairline.

## 6. How-to-Play overlay

Tape header, 680 wide, scrim rgba(4,4,8,.8) + hide HUD timer behind
overlay (paused = invisible). Three step cards with 01/02/03 tabular
numerals top-right, 46px circle icon frames (2.2 stroke drawn pictos:
flag, elevator doors, house+door), ORANGE titles, muted copy.
Controls: two columns divided by hairline, keycap chips (30x26 raised,
bottom shadow 2px, 11px 800) and pad circles for controller; action
labels RIGHT at #c4c4d2 (not faint). CTA "CLOCK OUT — GO" + SPACE/A hint.

## 7. Remaining screens (apply system, same rules)

- Results (S5, still unstyled): tape header, FORM EX-02 stamp, stats grid
  with honest meters + record pills (LIME), confetti per D5, REMATCH
  primary / MAIN MENU secondary.
- Pause menu: modal panel_style strong + tape header, muted game behind.
- Friends/LAN, Credits, Customize, Office Setup: left-column pattern,
  spec-sheet treatment for rider/chair pickers, stat meters replace
  "JUMP x1.00..." run-on lines.
- HUD (already S4): keep; align accents to new tokens (C4C4D2 units).

## 8. Rules that came from critique (do not regress)

R1 Orange = actions/selection ONLY. Green = exit signage + on-time.
Yellow = hazard/gates. Red = stamps/danger. Coral = debuffs.
R2 No emoji in final UI — all icons drawn (SVG in boards -> Godot
   Polygon2D/Line2D or font glyphs at implementation).
R3 Tabular numerals everywhere numbers animate (clock, meters, timer).
R4 Lowercase only for voice/joke captions ("one minute to freedom");
   everything else tracked caps.
R5 Stat bars must be honest: baseline tick at x1.0, width = 50%*(value),
   debuff = dashed coral fill + coral value.
R6 CTA contrast: INK text on ORANGE (>=7:1). Micro-labels >= #9a9aae on
   #0a0a0f panels.
R7 Exactly two hazard-tape uses per screen max (header + one accent).
R8 No dead zones: every vertical band has content or intentional air
   backed by the ticker/scene.
R9 Selected states must be hard (border + rail + pill), never brightness.
R10 All corners from the 4-step radius scale; shadows from e1/e2 only.

## 9. Implementation order (Godot slices)

S-A UITheme token expansion + MenuBackdrop v2 (mullions, fixtures, props,
grain) — foundation, no behavior change.
S-B Main menu: tape header, H1 GET OUT, clock, ticker, CTA, nav 2x2,
   footer, EXIT sign, ride card v2 (meters + pictogram stage).
S-C Mode select rework (cards, meta slots, stamps, CAUTION chips, CLOCK OUT).
S-D Settings rework (slider fill fix, toggle states, label pattern).
S-E How-to overlay (pictos, keycaps, scrim+HUD hide).
S-F Results S5 per spec section 7 + PauseMenu tape treatment.
Each slice: RED test where behavior changes, MenuSnap captures vs board,
full ladder before push. MenuSnap.gd (already in scripts/) is the capture
harness; boards are the reference.
