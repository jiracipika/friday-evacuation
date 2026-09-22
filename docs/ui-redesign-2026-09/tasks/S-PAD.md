# SLICE S-PAD — full controller support across the redesigned UI

Run step 1 immediately. Minimal prose. You are GLM-5.3 Flash implementing
one bounded slice. Repo: /Volumes/HARD/projects/friday-evacuation.
Base: commit cea8cc5 (S-B1 landed). Design: docs/ui-redesign-2026-09/FINAL-SPEC.md.

CONTEXT: gameplay controller input already works (GamepadSupportTest 43/43:
axes, A/X/B, camera stick, pause on Start, rumble, remap UI, scheme
auto-switch). This slice closes the UI-layer gaps so a player can do
EVERYTHING from a pad, with visible affordances per the locked spec.

## Scope

### 1. scripts/UITheme.gd — one new helper
apply_focus(button) — sets "focus" stylebox: StyleBoxFlat, draw_center
false, border ORANGE width 2, radius 12, expand_margin 2 all sides.
Call it from apply_primary, apply_secondary, apply_utility,
apply_mode_card, style_option_button (replace the StyleBoxEmpty focus on
option buttons ONLY if it does not break OptionButton popup visuals —
if unsure, leave option buttons alone and note it).

### 2. scripts/Main.gd — pad-first navigation
a) Every interactive Control gets focus_mode = FOCUS_ALL where missing
   (ticker/labels are IGNORE already — do not change them). Verify order:
   EVACUATE first (existing grab_focus), then NavGrid buttons, SETTINGS,
   CREDITS, then subview BACK last. Godot focus neighbors default to
   paint order — confirm grid 2x2 arrows land correctly at runtime via
   the test below.
b) EVACUATE accepts pad A as well as kb: it's a Button with focus, so
   ui_accept already covers it — VERIFY with test, don't change.
c) Subviews (modes/ride/office): BACK focusable (verify), Escape
   (ui_cancel) closes — ADD joypad B (JOY_BUTTON_B=1) as cancel: in
   _unhandled_input, also accept InputEventJoypadButton button_index 1
   pressed when open_subview != null. Same for the settings panel and
   pause menu if they have their own handlers — search for
   "ui_cancel" across scripts/ and extend ALL menu-layer cancel
   handlers to also match joypad B and pad Start (button 6) where it
   makes sense (pause menu: Start toggles close, B = back/close).
d) Option buttons (RIDER/CHAIR/MAP in subviews, dropdowns in Settings):
   joypad left/right (ui_left/ui_right) must cycle selection. Godot
   OptionButton does NOT do this natively — implement: connect to
   ui_focus_enter, store a class-level dict; in _unhandled_input, when
   an OptionButton has focus and ui_left/ui_right (including joypad
   axis 0 / dpad 7/8) is pressed, select adjacent enabled item and emit
   item_selected. Guard: ignore when a remap capture is active
   (Settings remap listens for raw events — check _remap_kind).
e) Sliders in Settings already respond to ui_left/right natively —
   verify in test, don't change.

### 3. scripts/PreMatchModal.gd — already shows both columns; add pad
   button hints in the CTA per spec F4: change CTA subtext/hint line to
   include pad glyph text "A / CROSS" (plain text, no new fonts).

### 4. NEW test scripts/PadNavSmokeTest.gd (SceneTree --script style):
   - Boot Main.tscn headless, synthesize InputEventJoypadButton
     (device 0, button 0) via Input.parse_input_event with press+release:
     the focused EVACUATE button must react (check focus owner, then
     button.disabled == false and that pressing Enter via
     InputEventAction ui_accept triggers _on_play — use the _block_navigation
     seam: set main._block_navigation = true, press, assert
     GameManager selected mode became EVACUATION).
   - Send joypad B (button 1) after opening OTHER MODES via
     main._open_modes_subview(): assert subview closed.
   - Focus the RIDER OptionButton in customize subview (open it, grab
     focus), send ui_right action event: assert selected index advanced.
   - Send dpad down (button 7) with EVACUATE focused: assert focus moved
     into NavGrid's first button (find via get_viewport().gui_get_focus_owner()).
   - Verify UITheme focus stylebox applied on play_button: fetch
     get_theme_stylebox("focus") — must NOT be StyleBoxEmpty.

## Constraints
- Godot 4.7.1, tabs. Files: UITheme.gd, Main.gd, Settings.gd (only if a
  cancel/remap guard needs it), PreMatchModal.gd, PauseMenu path if
  separate (check scenes/Evacuation.tscn node scripts), new test only.
- Run serially, scan for SCRIPT ERROR / Parse Error:
  PadNavSmokeTest, GamepadSupportTest, MenuHomeRedesignTest,
  MenuLayoutSmokeTest, MenuDepartureSmokeTest, ControlsOverlaySmokeTest,
  BindingsSmokeTest, InputPrefsSmokeTest, BootTest. ALL PASS.
- Do NOT touch Evacuation.gd, PlayerChair.gd, Network.gd. No commits.
- Never touch automated-newsletter / pitchforge.

## Report
docs/ui-redesign-2026-09/results/S-PAD.md: files, commands, raw tails,
deviations (esp. anything you left alone in OptionButton focus styling).
