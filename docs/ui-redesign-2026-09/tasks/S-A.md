# SLICE S-A — UITheme tokens v2 + MenuBackdrop office dressing

Run step 1 immediately. Minimal prose. You are GLM-5.3 Flash implementing one
bounded slice for Friday 5PM: Evacuation. Design owner (Astra) already
approved the spec; do NOT redesign. Repo: /Volumes/HARD/projects/friday-evacuation.

READ FIRST: docs/ui-redesign-2026-09/FINAL-SPEC.md (sections 2, 3, 8).
Reference board: docs/ui-redesign-2026-09/variant-iter3.html + final-main.png.

## Scope (only these files)
1. scripts/UITheme.gd — ADD constants (do not rename/remove existing):
   TEXT_FAIR "9a9aae", PAPER "f2ecdc", GREEN "2fa05a", YELLOW "f2c230",
   RED "e04a3a", INK "231303", TICKER_BG Color(0,0,0,0.35),
   DIM Color(0.02,0.02,0.04,0.72).
   Add static helpers: tape_style() -> StyleBoxFlat with hazard-stripe
   imitation (use bg_color INK + draw cannot stripe in StyleBoxFlat; instead
   return a flat YELLOW-dim style; the drawn tape is done in MenuBackdrop
   and panels will use a ColorRect-based TapeStrip node added in Main.gd —
   NOT this slice). Keep it minimal: constants only this slice.
2. scripts/MenuBackdrop.gd — in _draw_office_foreground (or new
   _draw_office_props called after skyline, before mullions):
   - Office prop silhouettes along the sill (bottom band y>=0.90sz):
     water cooler (rounded top box with faint cyan bottle glow), copier
     (box with paper tray), ficus (trunk + round canopy). Colors lifted
     ~10-15% above current floor pool (e.g. Color(0.09,0.09,0.13)) so they
     read as set dressing, not artifacts. Positions relative to sz, spread
     across width, deterministic (no random).
   - Green EXIT sign top-right: rect Color GREEN 2fa05a at (sz.x-120, 36)
     size 84x30 radius 4, white arrow (two rects) + "EXIT" impossible
     without font — draw arrow only, plus a small white-bordered rect
     inside. NO glow. opacity feel via exact color, no alpha.
   - Grain: skip (Godot _draw grain = perf risk). Do NOT add.
   Keep ALL existing drawing (sky, sun, clouds, skyline, mullions,
   troffer, floor pool) unchanged. Opaque fills only.
3. Test: add scripts/MenuBackdropPropsTest.gd (SceneTree --script style,
   copy structure from an existing small smoke test like
   ChairSkinSmokeTest.gd): instantiate MenuBackdrop, assert _draw does not
   error after 3 queue_redraw cycles, assert new helper
   _office_props() returns array of >=3 prop rects within bounds, assert
   _exit_sign_rect() returns Rect2 fully inside control rect.

## Constraints
- Godot 4.7.1 GDScript, tabs indentation. No new files beyond listed.
- Do not touch Main.gd, Evacuation.gd, tests other than your new one.
- Run: /usr/local/bin/godot --headless --path . --script scripts/MenuBackdropPropsTest.gd
  and the existing MenuLayoutSmokeTest.gd + BootTest.gd. All must PASS.
  Scan output for SCRIPT ERROR / Parse Error lines explicitly.
- git diff --check clean. NO commits, NO pushes.
- Never touch automated-newsletter, pitchforge, other projects.

## Report
Write docs/ui-redesign-2026-09/results/S-A.md: files changed, test commands
+ raw tail outputs, deviations. Parent verifies; do not claim VERIFIED.
