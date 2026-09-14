# D1 ResultsPanel restyle — implementation notes (2026-09-14)

Spec: docs/redesign/step1/UI-LAYOUTS.md §7. Scope kept bounded: this slice =
responsive panel + UITheme styling + structured stats display. The full
grid/reward-pill/enter-animation treatment follows in the GLM polish pass.

Current state:
- ResultsPanel: scene-defined Panel in Evacuation.tscn, fixed 600x400
  (offsets ±300/±200 around center), default theme (unstyled).
- VBox holds WinnerLabel (32px orange), RematchButton, MenuButton.
- StatsLabel is get_node_or_null'd in _end_race() but DOES NOT EXIST in the
  tscn — top speed / traps / records / unlocks / modifiers are silently
  dropped every race (pre-existing bug, visible here).
- _end_race() appends to stats_label.text as a multiline block.

Changes:
1. tscn: panel becomes shrink-to-fit — anchors center, offsets -280..+280 x
   -240..+240 BUT with growth handled via container min size; add StatsLabel
   node (spec §7 keeps the reference valid), autowrap, muted color.
   Simpler + spec-compliant: keep VBox-driven layout, set panel offsets to
   -280/+280 (560 wide = base 600 spec minus stylebox margins) and make
   offsets responsive by anchoring with max size via code.
2. Evacuation.gd _ready (UI setup area): style panel via
   FridayUITheme.panel_style(strong), apply_primary(RematchButton),
   apply_secondary(MenuButton), WinnerLabel 32px BUTTER #F2C66D with INK
   outline, cap panel max width 600 / max height 90% viewport so portrait
   (390px) shrinks it (anchors 8 + custom max via set_anchors + offsets).
3. StatsLabel wiring already works once the node exists; keep multiline
   block (spec: legacy block allowed while new stats grid absent — never
   both).
4. Reduced-motion-safe: no enter animation in this slice (allowed; spec's
   animation is part of the full polish pass).

Verification: ladder (ArtHUDTest + ModeSmokeTest exercise results), boot 0
errors, plus MenuLayoutSmokeTest-style narrow-width check via existing suites.
