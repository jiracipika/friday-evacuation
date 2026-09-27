# P1B — in-race HUD UITheme unification (design-doc item 1, remainder)

S4 landed the orange hero timer + objective strip. What remains for the
in-race HUD to fully match the design language:

- Boost/speed panel + minimap frame: migrate their ad-hoc StyleBoxFlat
  values to UITheme tokens (SURFACE_RAISED bg, 2px ORANGE border on the
  boost panel when ready, radius tokens, TEXT_FAIR secondary labels).
- Boost READY vs COOLDOWN states get the D5-style accent treatment (orange
  ready / muted cooling) instead of per-state ad-hoc colors.
- Story chip (STORY 01/04) + sabotatge hint share one chip style from
  UITheme.

Files (exclusive): scripts/HUD.gd, scripts/Minimap.gd (frame only),
scripts/UITheme.gd (only if a token is genuinely missing),
scripts/HUDThemeSmokeTest.gd (NEW contract test),
docs/ui-continuation/{tasks,results}/P1B.md.

Acceptance:
- No hardcoded hex outside UITheme in HUD.gd (test greps for Color("...")).
- Movie-frame captures at 1280x720 + 390x844 show consistent radii/borders.
- Full ladder green (HUD suites: ModeHUDResponsiveSmokeTest, HUD-related
  art suites).

Worker rules (from the validated pattern): one Godot process at a time;
suppress_next() for any scene instantiation; grep worker diffs for bare
`UITheme.` vs const `UI_THEME`; background the ladder, never foreground.

Est: one 60–90 min slice. Parent: CampaignGoal operator.
