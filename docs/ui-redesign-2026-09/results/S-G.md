# S-G RESULTS — Customize spec-sheet treatment (spec section 7)

Implementer: GLM 5.3 Flash, 2026-09-26, canonical repo
(/Volumes/SERVER/sol-workspace/repos/friday-evacuation). Base: ca7d088.

## Scope

The FINAL-SPEC section 7 line "stat meters replace 'JUMP x1.00...'
run-on lines", applied to the CUSTOMIZE RIDE subview:

- **Chair spec sheet** (`Main.gd` `_build_skin_sheet` /
  `_update_skin_sheet`): the run-on "JUMP x1.00 GRIP x1.00 BOOST x1.00"
  string is gone from the chair tagline; a three-row meter sheet sits
  beneath it — JUMP / GRIP / BOOST, each a shared `UITheme.MeterBar`
  (scale 2.0 so fill width = 50% x value per R5, baseline tick at x1.0)
  plus a right-aligned "x1.00" value label. Below-baseline stats draw
  the R5 debuff treatment (new `MeterBar.debuff` dashed-coral fill) with
  a CORAL value label; above-baseline read LIME.
- **Rider spec line**: silhouette + accessory were tooltip-only (never
  visible on touch) — now a tracked-caps micro line under the tagline
  (RiderSpec label), populated on selection.

## Behavior preserved

Selection persistence (GameManager.save_identity), locked-chair rows,
hero preview refresh, narrow-width short item text, subview open/close
and focus restore. Meter rows use small min widths (110px expand) so
the 390px layout budget holds (MenuLayoutSmokeTest 23/23 unchanged).

## Verification

- MenuDepartureSmokeTest 107/107 (was 101; +6 S-G checks: sheet present
  beside the selector, three meters, x1.0 tick + 2.0 scale on all three,
  boost value label populated, run-on line gone from the tagline, rider
  spec line visible + tracked caps).
- MenuLayoutSmokeTest 23/23, PadNavSmokeTest ALL PASS,
  MenuHomeRedesignTest 8/8 (390px + pad navigation unaffected).
- Vision QA: probe movie capture of the real subview — meters render
  with visible track (SURFACE_HOVER fix from S-F carries over), fill at
  exactly half for the x1.00 Office Standard baseline, values right.

## Notes for the next session

- CharacterRoster riders are flavor-only (no stat multipliers), so the
  meter sheet is chair-only; the rider card got the visible micro-spec
  line instead.
- `MeterBar` references in Main.gd are deliberately untyped (inner
  class of the preloaded UITheme script — a `MeterBar` annotation would
  not resolve as a global type).
- Remaining spec-section-7 screens (Lobby, Credits) still use the older
  styling — candidate S-H if the design pass continues.
