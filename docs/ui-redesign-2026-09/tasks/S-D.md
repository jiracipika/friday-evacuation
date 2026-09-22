# SLICE S-D — Settings rework (spec section 5)

Run step 1 immediately. Minimal prose. You are GLM-5.3 Flash implementing
one bounded slice. Repo: /Volumes/HARD/projects/friday-evacuation.
Base: commit 057bd6c. Design FROZEN: docs/ui-redesign-2026-09/FINAL-SPEC.md
section 5 + board variant-final.html screen F3.

CONTEXT: scripts/Settings.gd already builds grouped sections (VIDEO/AUDIO/
ACCESSIBILITY/INPUT per D6, styled sliders via UITheme.styled_slider,
themed OptionButtons, remap grid). Read it fully first. This slice fixes
the surveyed failure modes that remain: slider FILL visibility, toggle
state legibility, label pattern consistency, autosave indicator, scroll
fade, header/footer chrome.

## Scope — scripts/Settings.gd, scripts/UITheme.gd, new test

1. UITheme.styled_slider: groove must be TWO-part visible fill —
   StyleBoxFlat cannot do partial fill; Godot HSlider has no fill either.
   Implement via the slider's "slider" stylebox + custom draw: simplest
   compliant approach = wrap each HSlider in a small custom Control
   (name "MeterTrack", ~260px wide, 6px tall) that _draw()s the track:
   bg #262638 rounded 3, fill ORANGE->ORANGE_BRIGHT gradient (two rects
   fine) from 0 to value%, and keep the native HSlider thumb (18px
   ORANGE_BRIGHT with dark ring) overlaid transparent-track (set its
   groove stylebox to StyleBoxEmpty, grabber styled). The wrapper draws
   BEHIND the slider (child order). Add helper in Settings.gd, not
   UITheme (HSlider-specific). Value % = value / (max-min).
2. Slider rows: ONE label pattern — HBox [Label name][spacer][Label
   value tabular] then full-width slider beneath (existing layout mostly
   matches; enforce value label color ORANGE 13px font_size,
   tabular via font variation impossible — accept default, right-align).
3. CheckButtons/toggles: ensure ON state reads: add text state tag Label
   ("ON" LIME / "OFF" #9a9aae, 9.5px, tracked) INSIDE the row before the
   CheckButton; CheckButton itself styled by UITheme.styled_checkbutton
   already — verify its ON color is ORANGE, fix if not.
4. Header: title "SETTINGS" + right-aligned "● AUTOSAVED" Label (LIME,
   11px, tracked) in the same row as title. Keep sections.
5. Footer: BACK button (existing) + version Label "v0.9 · 26 SEP 26"
   (10px #9a9aae, nowrap) in one row, border-top hairline above
   (HSeparator with theme color rgba(255,255,255,0.09)).
6. Scroll fade: the settings scroll container gets a bottom gradient —
   use a Control child (name "ScrollFade", anchors bottom, height 26,
   mouse IGNORE) that _draw()s 6 stacked rects from INK alpha 0.0 at
   top to alpha 0.9 at bottom INK (solid fade, opaque-friendly).
7. Dropdowns: no duplicated value in label row (label shows NAME only;
   the OptionButton shows the value) — check current and fix if doubled.

## Constraints
- Preserve ALL behavior: persistence (InputPrefs/settings.cfg), remap
  capture (incl. Main.remap_capture_active interplay), pause-menu
  mounting, quality presets, Accessibility toggles, S-PAD navigation
  (sliders ui_left/right native — VERIFY, do not break).
- Portrait 390px: rows fit; value labels ellipsis.
- Godot 4.7.1, tabs. Files: Settings.gd, UITheme.gd (styled_slider may
  stay; new code in Settings), NEW scripts/SettingsRedesignTest.gd.
- Test asserts: every HSlider has a MeterTrack sibling/parent drawing
  (node exists + its script class), fill rect width == expected value%
  within 2px (expose helper get_fill_fraction() on wrapper), every
  CheckButton row has ON/OFF tag matching button_pressed state, header
  contains AUTOSAVED label, footer has BACK + version, scroll fade node
  present, no duplicate value in dropdown label rows, 390px fit.
- Run serially (scan SCRIPT ERROR/Parse Error): SettingsRedesignTest,
  InputPrefsSmokeTest, PadNavSmokeTest, MenuLayoutSmokeTest,
  MenuHomeRedesignTest, BootTest. ALL PASS.
- No commits. Never touch automated-newsletter/pitchforge.

## Report
docs/ui-redesign-2026-09/results/S-D.md: files, commands, raw tails,
deviations.
