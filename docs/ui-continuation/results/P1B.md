# P1B — in-race HUD UITheme unification: COMPLETE (2026-09-27)

- HUD.gd: every color now routes through UITheme token constants
  (UIT.BG/ORANGE/TEXT/TEXT_MUTED/SURFACE/ORANGE_BRIGHT/CORAL/VIOLET/YELLOW)
  — zero raw hex literals remain. Caught real drift en route: the item
  spill readout used off-palette "f2c66d"; now the YELLOW token.
- Boost accent: the instruments panel carries a 2px ORANGE border while
  boost is READY/ACTIVE, plain surface while cooling (state-change toggle,
  no per-frame churn).
- Chips: story chip + sabotage hint share _chip_style().
- Minimap.gd: frame bg/border via tokens; blip colors named consts.
- New HUDThemeSmokeTest (21 checks, in ladder): source audits (no raw hex,
  all tokens referenced) + behavioral border toggling on the REAL scene +
  chip radius + spill token color.

Verification: HUDThemeSmokeTest 21/21, ArtHUDTest 12/12,
ModeHUDResponsiveSmokeTest + BootTest exit 0. Evidence:
evidence/P1B/hud-accent.png.
