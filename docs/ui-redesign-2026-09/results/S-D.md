# S-D RESULTS — Settings rework (GLM worker + parent completion)

Base: commit 126c0e7 (S-D brief). Design FROZEN: FINAL-SPEC section 5 +
board variant-final.html screen F3.

## State found

The worker session (Sep 22) had implemented brief items 1–6 in
`scripts/Settings.gd` (MeterTrack slider fill, ScrollFade, toggle ON/OFF
state tags, AUTOSAVED header, footer hairline + BACK + version, one
slider label pattern) but had written NO test, run NO suite, and left
the tree uncommitted. This session completed the slice.

## Files

- `scripts/Settings.gd` — worker's S-D implementation PLUS parent
  portrait-fit fixes (below).
- `scripts/SettingsRedesignTest.gd` — NEW, 24 checks.
- `docs/ui-redesign-2026-09/results/S-D.md` — this report.

## Parent fixes on top of the worker slice

The brief's portrait constraint ("390px: rows fit; value labels
ellipsis") had never been verified — no test existed. Measuring the
real tree (headless probe, per repo law: measure, don't guess) showed
the panel could not shrink below 520px and several rows exceeded the
390 budget:

1. `panel.custom_minimum_size = Vector2(520, 620)` — hard floor. Below
   560px viewport the panel now mounts as a full-bleed sheet
   (PRESET_FULL_RECT, 12px margin, min height 620); desktop keeps the
   centered 520x620 card. Measured panel min width at 390: 520 -> 384.
2. CheckButton toggles: `clip_text` + `OVERRUN_TRIM_ELLIPSIS` (longest
   row measured 415px). Desktop unaffected — clipping only bites under
   squeeze.
3. Stick-response row: label's hard 190px column is dropped at narrow
   (kept on desktop) + clips; dropdown clips.
4. Remap title label: autowrap (measured 388px one-liner).
5. Remap cells + RESET button: clip + ellipsis.
6. Quality/time-scale/scheme dropdowns + ValueLabel: clip + ellipsis.

## Verification

Serial suite (brief's list), Godot 4.7.1, zero SCRIPT ERROR/Parse Error
in every log:

- SettingsRedesignTest — 24/24 PASS (NEW: wrapper + fill fraction
  tracking incl. 30 -> 0.30 + 2px fill-width contract, value-label
  live update, 10 toggle tags matching state + re-sync on flip + LIME
  colors, AUTOSAVED header, footer BACK + version, ScrollFade,
  no dropdown-label value duplication, 390px panel + row fit, cfg
  byte-restore around the run)
- InputPrefsSmokeTest — 68/68
- PadNavSmokeTest — ALL PASS
- MenuLayoutSmokeTest — 23/23
- MenuHomeRedesignTest — 8/8
- BootTest — ALL CHECKS PASSED

Vision QA: movie-captured the real menu -> SETTINGS flow
(UISurveyCapture) and inspected frames: fill meters render inside the
track behind the native thumb, ON/OFF tags legible, AUTOSAVED + footer
version present.

## Deviations

- Brief item 7 ("no duplicated value in dropdown label rows") was
  already satisfied by the worker's code; pinned by the test instead of
  changed.
- MeterTrack lives in Settings.gd (brief's "helper in Settings.gd, not
  UITheme") — UITheme.styled_slider still sets thumb/groove styles; the
  groove override (StyleBoxEmpty) is applied in Settings._make_slider.
- The scroll-fade draw uses INK at 6 steps exactly as briefed.
- Portrait fix went beyond the brief's letter (brief assumed only label
  ellipsis was needed; the 520px panel floor and 415px toggle row also
  had to move).

## Known limitations

- Settings has no live resize handler: the narrow/desktop layout is
  chosen at mount. Reopening the panel after a window resize re-resolves
  (Settings is remounted on every open).
- Remap cell names ellipsize at 390 (e.g. "MOUSE B…") — tap-to-rebind
  still works; full names visible on desktop widths.
