<!-- PARENT NOTE (Hermes, Sep 12 2026): Sections 1-2 (tokens, components) and 8-10 are
authoritative for implementation. Sections 3.x partially describe the CURRENT build; where a
3.x section matches existing code, the MANDATORY DELTAS below override it. Implementer must
apply every delta, verified by movie-frame captures before/after. -->

# MANDATORY DELTAS (changes vs current build — highest priority)

These fix the surveyed failure modes (see fe-ui-survey.md). Each delta = visible change
that must show up in before/after captures.

## D1 — Splash/title card (replace flat orange look)
- Scrims per token table (scrim_splash) over the REAL menu backdrop — never a flat fill.
- Brand lockup: kicker "4:59 PM FRIDAY" (13px, ORANGE, +8% tracking), title on TWO lines
  "FRIDAY 5PM" / "EVACUATION" (display_title 42px, TEXT with 3px ORANGE outline),
  tagline 16px TEXT_MUTED, pulsing prompt 22px ORANGE (alpha 0.5-1.0, 1.5s cycle).
- Dismiss: 0.45s fade (existing), focus to Play.

## D2 — Main menu hero emphasis
- Evacuation card = HERO: min height 84px, 20px title, accent strip 4px, "PRIMARY MODE"
  pill in ORANGE fill (dark text). Other 3 cards: 56px, 18px titles, muted pills.
- Tagline/description text gets a bottom-up gradient scrim panel (black 0.0->0.55) so it
  reads over the skyline (fixes low-contrast text-on-art).
- YOUR RIDE panel joins the layout grid (right column, 340px, shares vertical rhythm with
  mode list); not a floating card. Hidden <1080px (existing rule).
- Utility row: keep 28px pills but add hover brighten (SURFACE_HOVER) + focus outline ORANGE.

## D3 — Mode select regroup (fix density/clipping)
- Order: mode cards > RIDER/CHAIR row > TODAY'S OFFICE CHAOS > PLAY > MULTIPLAYER.
- Dropdown detail labels: 2-line max, autowrap, ellipsis; never clip mid-word (fixes
  "BOOST x1.00..." truncation) — min height 44px for detail labels.
- Modifier chips: 2 rows max in HFlow, chip = accent border 2px active / 1px muted inactive,
  title 14px + one-line desc 11px TEXT_MUTED. Selected chip also fills accent at 0.12 alpha.

## D4 — HUD hierarchy
- Timer = hero: 34px (timer_hud), ORANGE; <15s switch CORAL + 0.5s alpha pulse 0.6-1.0.
- Goal banner: move to its own centered strip UNDER top bar with panel bg
  Color(0.02,0.02,0.04,0.72), 14px caption, outline_size 4 (existing) — must never sit on
  raw ceiling lights.
- Speed meter: fill lerp #ffb52e -> Color(1.0,0.42,0.20) by speed ratio; add "km/h" unit
  label 11px TEXT_MUTED next to readout.
- Minimap: raise panel bg to Color(0.03,0.03,0.06,0.84) + exit marker #63e68a radius 5
  pulsing ring; player dot #70b7ff radius 6 with 10px arc (spec 2.5 values — apply them,
  current build shows near-empty box).
- Countdown moment: on race start, center-screen "3","2","1","GO!" at 64px ORANGE with
  scale 1.3->1.0 + fade tween, 0.7s per numeral (0.5s for GO!), then ControlsOverlay.

## D5 — Results celebration (biggest gap)
- Replace translucent grey box with SURFACE_RAISED panel (panel_style strong: 2px ORANGE
  border, radius 16, shadow 10) 600x400, fade+scale-in 0.4s ease_out.
- Winner banner: 32px, Color(1,0.65,0.1) with 4px dark outline; on win play
  ImpactFX.confetti() (CPUParticles2D burst top-center, ORANGE/LIME/CYAN mix, 1.2s).
- Stats grid (2 columns): TOP SPEED (value 24px ORANGE) / TRAPS HIT (value 24px TEXT);
  NEW TOP-SPEED RECORD and NEW CHAIR UNLOCKED lines render as LIME/VIOLET pills, not
  plain text lines.
- Buttons: REMATCH = apply_primary, MAIN MENU = apply_secondary, both 52px min height.
- Hide in-match HUD cards behind results (fade HUD modulate to 0.35).

## D6 — Settings grouping
- Section headers (VIDEO / AUDIO / ACCESSIBILITY / INPUT) 13px ORANGE, +10px top margin;
  sliders get styled grabber: 8px handle ORANGE, groove 4px SURFACE_HOVER radius 2;
  CheckButton text 14px. Keep 520px panel + scroll + pinned BACK.

# Friday 5PM: Evacuation — UI Design Specification

**Engine:** Godot 4.7.1, GL Compatibility renderer
**UI Construction:** Code-built Control nodes (no .tscn UI scenes), theme helpers in `scripts/UITheme.gd`
**Base Resolution:** 1280x720, stretch mode `canvas_items`, aspect `expand`
**Orientation:** Sensor landscape (project.godot `window/handheld/orientation=4`)
**Art Direction:** Dusk + Toybox + Emergency signage (user-approved, docs/design-panel/direction-approved.md)

---

## 1. Design Tokens

### 1.1 Color Palette

All tokens map directly to `FridayUITheme` constants in `scripts/UITheme.gd`. The implementer must use these exact hex values; no new colors without adding a constant first.

| Token | Hex | UITheme Const | Usage |
|---|---|---|---|
| `bg` | `#0a0a0f` | `BG` | App background, HUD top bar, bottom panel bg |
| `surface` | `#15151f` | `SURFACE` | Secondary button bg, card surfaces |
| `surface_raised` | `#1c1c2e` | `SURFACE_RAISED` | Strong panels, settings, pause, results |
| `surface_hover` | `#25253a` | `SURFACE_HOVER` | Button hover state |
| `text` | `#f7f6f2` | `TEXT` | Primary text, button labels |
| `text_muted` | `#9b9baa` | `TEXT_MUTED` | Secondary text, descriptions, hints |
| `orange` | `#ff9a1a` | `ORANGE` | Primary accent, active states, meters, borders |
| `orange_bright` | `#ffbd4a` | `ORANGE_BRIGHT` | Hover borders, boost-active text, flash highlights |
| `cyan` | `#57d7ff` | `CYAN` | Secondary accent, info, default secondary buttons |
| `lime` | `#b9f34a` | `LIME` | Success, ready state, exit gate on minimap |
| `coral` | `#ff6f61` | `CORAL` | Danger, trap warnings, sabotage, low timer |
| `violet` | `#9b82ff` | `VIOLET` | Special modifiers, unlock highlights |

**Dusk lighting palette (world-side, already applied):**
- Center lane light: `Color(0.78, 0.88, 1)` at 0.70 energy, 13.5 range
- Perimeter warm pools: `Color(1, 0.82, 0.60)` at 1.10 energy, 15.0 range
- Ambient: `Color(0.67, 0.79, 0.88)` at 0.58
- Key light: 0.78 energy

**Semantic color roles (derived, used in spec):**

| Role | Token | Hex | Context |
|---|---|---|---|
| `timer_normal` | ORANGE | `#ff9a1a` | Timer >= 30s |
| `timer_warning` | ORANGE_BRIGHT | `#ffbd4a` | Timer 15-30s |
| `timer_critical` | CORAL | `#ff6f61` | Timer < 15s, pulses |
| `boost_ready` | ORANGE | `#ff9a1a` | Boost off cooldown |
| `boost_active` | ORANGE_BRIGHT | `#ffbd4a` | Boost engaged |
| `boost_locked` | text_muted 45% | `#9b9baa` at 0.45 alpha | On cooldown |
| `speed_meter_low` | `#ffb52e` | — | 0-33% speed (warm amber) |
| `speed_meter_high` | `Color(1.0, 0.42, 0.20)` | — | 100% speed (coral blend) |
| `status_racing` | `Color(0.4, 1, 0.65)` | — | Green race status |
| `exit_marker` | `#63e68a` | — | Minimap exit dot |
| `player_marker` | `#70b7ff` | — | Minimap player dot |
| `scrim_menu` | `Color(0.02, 0.02, 0.04, 0.94)` | — | Settings/modal backdrop |
| `scrim_pause` | `Color(0.02, 0.02, 0.04, 0.82)` | — | Pause backdrop |
| `scrim_splash` | `Color(0.04, 0.03, 0.055, 0.965)` | — | Splash gate |

### 1.2 Typography

All UI uses Godot's `ThemeDB.fallback_font` (no custom font files in the project). Font sizes are set via `add_theme_font_size_override("font_size", N)`.

| Role | Size (px @ 720p) | Weight Note | Usage |
|---|---|---|---|
| `display_title` | 42 | Bold via size | Menu main title, "FRIDAY 5PM: EVACUATION" |
| `splash_title` | 42 | — | Splash brand title |
| `splash_kicker` | 13 | — | "4:59 PM FRIDAY" above splash title |
| `splash_prompt` | 22 | — | "CLICK / TAP / PRESS A TO START" |
| `h1` | 32 | — | Settings title, Pause "PAUSED", Results winner |
| `h2` | 24 | — | Play button, results buttons, timer in HUD |
| `h3` | 20 | — | HUD floor label, lobby title |
| `body` | 18 | — | Mode card title, boost label, settings rows |
| `body_sm` | 16 | — | Sabotage label, item readout, settings body |
| `caption` | 14 | — | Objective strip, mode card subtitle, hints |
| `micro` | 12 | — | Utility row buttons, stats line, credits body |
| `timer_hud` | 34 | — | Race timer in top bar |
| `minimap_label` | 11 | — | Floor label inside minimap |

**Outline:** Objective strip uses `outline_size=4`, `font_outline_color=Color(0,0,0,0.65)` for readability over world light pools.

### 1.3 Spacing & Layout

| Token | Value | Usage |
|---|---|---|
| `panel_padding_l/r` | 18px normal, 28px strong | `panel_style()` content margins |
| `panel_padding_t/b` | 12px normal, 24px strong | Strong = settings/pause/results |
| `panel_corner_radius` | 14px normal, 16px strong (settings/pause) | StyleBoxFlat corner |
| `panel_border_normal` | 1px at 0.2 alpha accent | Non-focused panels |
| `panel_border_strong` | 2px at 0.5 alpha accent | Focused/important panels |
| `panel_shadow_size` | 6px normal, 10px strong | Shadow offset (0,5) |
| `panel_shadow_color` | `Color(0,0,0,0.38)` | — |
| `button_padding_l/r` | 18px | `button_style()` |
| `button_padding_t/b` | 10px | `button_style()` |
| `button_corner_radius` | 12px standard, 14px primary | — |
| `button_shadow_size` | 7px | Shadow offset (0,4) |
| `button_min_height` | 52px | Pause/results/rematch/menu buttons |
| `mode_card_min_height` | 30px | Compact mode cards (two-line wraps) |
| `utility_button_min_height` | 28px | Settings/credits/map/touch row |
| `hbox_separation_default` | 16-26px | Varies by container |
| `vbox_separation_default` | 12px | Settings, lobby, pause |
| `vbox_separation_hud` | 4-6px | HUD ability stack, speed box |

### 1.4 UI Scale (Mobile/Responsive)

Implemented in `HUD.gd._ui_scale()`:
- Formula: `clampf(viewport_height / 720.0, 0.85, 1.6)`
- 720p viewport => scale 1.0
- 360px-tall landscape phone => ~0.72 (clamped to 0.85)
- All HUD pixel values pass through `_px(v)` = `int(round(v * _ui_scale()))`
- Menu: `_is_narrow()` switches utility row to `HFlowContainer`, shortens labels, hides hero panel below 1080px width

### 1.5 Motion & Easing

All animations use frame-rate-independent smoothing: `1.0 - exp(-k * delta)`.

| Motion | Duration | Easing | Trigger |
|---|---|---|---|
| Splash dismiss fade | 0.45s | Linear alpha tween | First ui_accept/click/touch |
| Results panel enter | ~0.4s | Scale + alpha, `ease_out` | `_end_race()` sets `results_panel.visible=true` |
| Objective strip flash | Decay over ~0.5s | Linear `modulate.a` from 1.6 to 1.0 at 2.0/s | Floor change via `set_floor()` |
| Mode card selection | Instant modulate swap | — | `selected` toggle in `apply_mode_card()` |
| Minimap redraw | Per-frame | — | `queue_redraw()` on `set_player()` |
| Controls overlay fade in/out | 1.2s | `FADE_TIME` alpha tween | Round start, auto-hide after 6s |
| Subtitle caption | 1.5s default | Auto-hide timer | Accessibility.caption() |
| Timer critical pulse | 0.5s cycle | Sinusoidal alpha 0.6-1.0 | Timer < 15s |
| Boost bar fill | Continuous | Instant value set | Per-frame `set_boost()` |
| Speed meter color ramp | Continuous | `Color.lerp()` by speed ratio | Per-frame `set_speed()` |
| Reduced motion | All fades skipped, instant show/hide | — | `accessibility.reduced_motion=true` |

### 1.6 Z-Order (CanvasLayer.layer)

| Layer | UI Element |
|---|---|
| 10 | HUD (CanvasLayer default) |
| 30 | ControlsOverlay |
| 50 | PauseMenu |
| 80 | CreditsScreen |
| 90 | PreMatchModal |
| 95 | SplashScreen |

---

## 2. Component Library

### 2.1 Panel (`FridayUITheme.panel_style`)

```
StyleBoxFlat:
  bg_color: SURFACE (#15151f) at 0.96 alpha, or SURFACE_RAISED (#1c1c2e) if strong
  border_color: accent at 0.2 alpha (normal) or 0.5 alpha (strong)
  border_width: 1px all (normal), 2px all (strong)
  corner_radius: 14px all
  content_margin: 18/18/12/12 (l/r/t/b)
  shadow_color: Color(0,0,0,0.38)
  shadow_size: 6 (normal), 10 (strong)
  shadow_offset: Vector2(0, 5)
```

### 2.2 Button (`FridayUITheme.button_style` + `apply_primary` / `apply_secondary`)

**Primary button** (`apply_primary`):
- Normal: bg=ORANGE `#ff9a1a`, border=ORANGE_BRIGHT `#ffbd4a` 2px, radius 14
- Hover: bg=ORANGE_BRIGHT, border=WHITE 2px
- Pressed: bg=ORANGE.darkened(0.18), border=ORANGE_BRIGHT 2px
- Font: size 24, color=BG `#0a0a0f` (dark text on orange)
- Min height: 52px (for large buttons), 28px (utility)

**Secondary button** (`apply_secondary`):
- Normal: bg=SURFACE `#15151f`, border=accent at 0.28 alpha, 1px
- Hover: bg=SURFACE_HOVER `#25253a`, border=accent 2px
- Font: size 18, color=TEXT at 0.86 alpha (normal), TEXT (hover)

**Mode card button** (`apply_mode_card`):
- Normal: `panel_style(accent, false)` — surface bg, 1px accent border at 0.2 alpha
- Hover: `button_style(SURFACE_HOVER, accent, 2)` — 2px accent border
- Pressed: `button_style(accent.darkened(0.68), accent.lightened(0.18), 2)`
- Disabled: `panel_style(accent, true)` — strong variant
- Font: size 18, color=TEXT; disabled=accent.lightened(0.18)
- `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`, `clip_text = false`
- Selected: `modulate = Color.WHITE`; unselected: `Color(1,1,1,0.94)`
- Min height: 30px (compact)
- Custom `_draw()` accent bar + status pill via `ModeCard.gd`

### 2.3 Label (factory: `_make_label`)

```
Label:
  add_theme_font_size_override("font_size", size)
  add_theme_color_override("font_color", color)
  # Optional outline for world-overlapping labels:
  add_theme_constant_override("outline_size", 4)
  add_theme_color_override("font_outline_color", Color(0,0,0,0.65))
```

### 2.4 Progress Bar (meter)

```
ProgressBar:
  show_percentage = false
  fill StyleBoxFlat: bg=ORANGE, corner_radius=4
  background StyleBoxFlat: bg=Color(0.1,0.1,0.15,1.0), corner_radius=4
  # Speed bar fill color lerps from #ffb52e (low) to Color(1.0,0.42,0.20) (high)
  # Boost bar fill: ORANGE when active/ready, dimmed when locked
  custom_minimum_size: Vector2(_px(220), _px(14)) for speed, _px(240), _px(12)) for boost
```

### 2.5 Minimap (`Minimap.gd`)

- Size: 150x150px (scaled by `_px()`)
- Position: top-right, offset `(-map_size - 24, 92)` from top-right anchor
- `_draw()` renders: dark panel (`Color(0.03,0.03,0.06,0.84)`), orange border at 0.65 alpha, 2px, corner_radius 10
- Grid: 3x3 lines at 0.08 alpha white, 1px
- Exit marker: green circle `#63e68a`, radius 5px, at `(0.5, 0.92)` normalized
- Player marker: blue circle `#70b7ff`, radius 6px, with 10px arc ring at 0.35 alpha
- Floor label: "F%d" at 11px, white at 0.7 alpha, top-left

### 2.6 Color Swatch (Lobby)

- Button 36x30px, `focus_mode=FOCUS_NONE`
- Normal: bg=player_color, corner_radius 8
- Hover: same + white border 2px
- Pressed: same + white border 3px at 0.6 alpha
- Selected: tracked separately via `_mark_selected_swatch()`

### 2.7 CheckButton (Settings)

- Standard Godot CheckButton with text label
- No custom stylebox override (uses default theme)
- Connected to `_apply_settings()` on `toggled`

### 2.8 Slider (Settings)

- `HSlider`, min_height 28px
- `keyboard_sens_slider`: range 0.15-1.5, step 0.05
- `camera_sens_slider`: range 0.25-2.0
- `master/music/sfx_slider`: range 0-100
- All connect `value_changed` to `_apply_settings()`

### 2.9 OptionButton (Settings)

- Standard Godot OptionButton
- `quality_option`: LOW / MEDIUM / HIGH
- `time_scale_option`: 0.75x / 1.0x / 1.25x
- `scheme_option`: AUTO / KEYBOARD & MOUSE / CONTROLLER
- Font size 12 for utility-level option buttons

### 2.10 Chip (ModifierMenu)

- Focusable `Button` (not checkbox) with per-modifier accent color
- Wrapping via `HFlowContainer`
- Active chip: accent border 2px + accent-tinted bg
- Inactive chip: surface bg, 1px muted accent border
- Summary line below: plain-language description of combined effects

---

## 3. Per-Screen Layouts

### 3.1 Splash Screen (`SplashScreen.gd`, layer 95)

**Purpose:** First-input gate for audio unlock (web) and brand presentation.

**Layout:** Full-rect `ColorRect` scrim `Color(0.04, 0.03, 0.055, 0.965)` over the menu.

**Content (centered VBox, separation 18):**
1. Kicker label: "4:59 PM FRIDAY" — 13px, ORANGE, centered
2. Title label: "FRIDAY 5PM: EVACUATION" — 42px, TEXT, centered
3. Sub label: tagline — 16px, TEXT_MUTED, centered
4. Prompt label: "CLICK / TAP / PRESS A TO START" — 22px, ORANGE, centered, pulsing alpha 0.5-1.0 at ~1.5s cycle

**Interaction:** Any `ui_accept` (Enter/Space), mouse click, touch, or pad A dismisses. Dismiss = 0.45s alpha fade, then `queue_free()`, then `play_button.grab_focus()`.

**Platform phrasing:** "TAP" on Android/iOS/web-touchscreen; "CLICK" on desktop. Determined by `OS.get_name()` check.

**Reduced motion:** Skip pulse; static prompt at 0.85 alpha.

### 3.2 Main Menu (`Main.gd`)

**Structure:** Full-rect `Control` with `MenuBackdrop` (animated dusk skyline + office windows), then `VBox` column.

**VBox contents (top to bottom):**
1. **Title** — "FRIDAY 5PM: EVACUATION" — 42px, ORANGE, centered
2. **Subtitle** — "OFFICE CHAIR RACING" — 14px, TEXT_MUTED, centered
3. **Description** — mode description text — 14px, TEXT_MUTED, centered (updates on mode select)
4. **ModeListScroll** (ScrollContainer) containing **ModeList** (VBox):
   - 4x ModeCard buttons, 30px min height each, separation ~4px
   - Each card: title (18px), subtitle (14px accent), status pill (PLAYABLE/PROTOTYPE)
   - Selected card: full opacity + accent border strong; others: 0.94 modulate
   - Card accent colors: Evacuation=#ff9a1a, Hauled=#ff5959, ShopSeek=#4dd966, PizzaColony=#ffcc33
5. **Character selector** — HBox: RIDER OptionButton + detail Label
   - Dropdown with character names; locked entries disabled ("Name — LOCKED")
   - Detail: tagline + stat multipliers + next unlock progress
6. **Skin selector** — HBox: CHAIR OptionButton + detail Label
   - Dropdown with chair skin names; locked entries show "Name — LOCKED (win N)"
   - Detail: tagline + exact multipliers (jump/friction/boost)
7. **ModifierMenu** (Evacuation only) — PanelContainer with chip flow + summary
8. **PlayButton** — Primary button, "PLAY", 24px font, full width
9. **HostButton** — "MULTIPLAYER", secondary style
10. **Utility row** — HBox (or HFlowContainer if narrow):
    - SETTINGS (12px, 28px height, expand-fill)
    - CREDITS (12px, 28px height, expand-fill)
    - MAP: OptionButton (OPEN PLAN / CUBICLE MAZE / EXECUTIVE, or short names if narrow)
    - TOUCH: cycle button (AUTO / ON / OFF)
11. **StatsLabel** — career stats summary, 12px, TEXT_MUTED at 0.6 alpha, centered

**Hero panel** (right side, >=1080px only): Rotating chair preview + identity pickers. Hidden below 1080px width.

**Backdrop** (`MenuBackdrop.gd`): 11-stop dusk gradient sky, office-window foreground silhouette. Renders behind all VBox content.

**Responsive behavior:**
- Below 1080px width: hero panel hidden, single column
- Narrow viewport: utility row becomes `HFlowContainer` (wraps 2x2), map names shortened
- Title shrinks from 24 to 22px when skin selector row is present (layout budget reclamation)

### 3.3 Settings Overlay (`Settings.gd`)

**Structure:** Full-rect backdrop `Color(0.02,0.02,0.04,0.94)` + centered `PanelContainer` (520x620 min).

**Panel style:** bg=SURFACE_RAISED `#1c1c2e`, border=ORANGE 2px, corner_radius 16, padding 28/28/24/24.

**Layout (VBox, separation 12):**
1. Title: "SETTINGS" — 32px, ORANGE, centered
2. ScrollContainer (vertical only, horizontal disabled):
   - **GRAPHICS QUALITY** — OptionButton: LOW / MEDIUM / HIGH
   - **MASTER VOLUME** — HSlider 0-100
   - **MUSIC VOLUME** — HSlider 0-100
   - **SFX VOLUME** — HSlider 0-100
   - **ENABLE SCREEN SHAKE** — CheckButton
   - **ENABLE FLASH EFFECTS** — CheckButton
   - **SINGLE-PLAYER GHOST PACER** — CheckButton
   - **REDUCED MOTION** — CheckButton
   - **HIGH CONTRAST HUD** — CheckButton
   - **AUDIO CUE SUBTITLES** — CheckButton
   - **GAME SPEED (SINGLE PLAYER ONLY)** — OptionButton: 0.75x / 1.0x / 1.25x
   - Section header "INPUT" — 13px, ORANGE
   - **CONTROL SCHEME** — OptionButton: AUTO / KEYBOARD & MOUSE / CONTROLLER
   - **KEYBOARD SENSITIVITY** — HSlider 0.15-1.5, step 0.05
   - **MOUSE LOOK** — CheckButton (toggle)
   - **MOUSE SENSITIVITY** — HSlider 0.25-2.0
   - **INVERT Y** — CheckButton
   - **CAMERA CURVE** — OptionButton
   - **REMAP CONTROLS** — GridContainer with key/pad button pairs
3. Pinned **BACK** button — full width, 52px height, 20px font

**Persistence:** `user://settings.cfg` via `ConfigFile`. All toggles use `_cfg_bool()` for safe string-to-bool conversion (GDScript `bool("yes")` crashes).

**Behavior:** `_restoring` flag blocks reentrant `_apply_settings()` during value restore. Settings apply immediately on change (audio bus volumes, renderer quality, accessibility flags).

### 3.4 Lobby (`Lobby.gd`)

**Structure:** Full-rect backdrop `Color(0.02,0.02,0.04,0.96)` + centered PanelContainer (540x440).

**Layout (VBox, separation 12):**
1. Title: "MULTIPLAYER LOBBY" — 30px, centered
2. Status label: instruction text — 14px, centered
3. **Name** — LineEdit, max_length 16, placeholder "Your name"
4. **Color row** — HBox of color swatches (36x30px each, separation 6)
5. **Address** — LineEdit, placeholder "LAN address (default: 127.0.0.1)"
6. **Hotspot quick-fill row** — HBox:
   - "192.168.43.1" button (Android hotspot gateway)
   - "192.168.49.1" button (newer Android hotspot)
7. **Host button** — "HOST GAME"
8. **Join button** — "SCAN LOCAL WI-FI" / "JOIN"
9. **Host list** — ItemList showing discovered hosts (name + player count)
10. **Player list** — ItemList showing roster with "name - Rider / Chair - READY" labels
11. **Ready button** — toggles `lobby_ready`
12. **Start button** — host-only, enabled when all players ready
13. **Back button** — returns to menu

**Avatar label format** (`Lobby._avatar_label`): `"name - Rider / Chair - READY"` or `"...NOT READY"`.

### 3.5 In-Match HUD — Evacuation (`HUD.gd`, layer 10)

**Top bar** (PanelContainer, PRESET_TOP_WIDE, offset_bottom=_px(76)):
- bg: `Color(0.045, 0.045, 0.08, 1.0)`, bottom border: ORANGE at 0.5 alpha, 3px
- HBox centered, separation _px(26):
  - **Floor label**: "FLOOR 1" — _px(20)px, white at 0.92 alpha
  - **Timer label**: "2:00" — _px(34)px, `#ffb52e` (shifts to CORAL below 15s with pulse)
  - **Status label**: "RACE" — _px(18)px, `Color(0.4, 1, 0.65)`

**Objective strip** (Label, PRESET_TOP_WIDE, offset_top=_px(80), offset_bottom=_px(102)):
- "GOAL 1/4 - FIND THE ELEVATOR - GLASS TUBE AT THE EDGE" — _px(14)px, `Color(1.0, 0.72, 0.30)`
- Centered, outline_size=4, outline_color=`Color(0,0,0,0.65)`
- Flash on floor change: modulate.a jumps to 1.6, decays to 1.0 at 2.0/s in `_process()`

**Floor goal strings** (FLOOR_GOALS const):
1. "GOAL 1/4 - FIND THE ELEVATOR - GLASS TUBE AT THE EDGE"
2. "GOAL 2/4 - UP TO FLOOR 3 - RIDE THE ELEVATOR"
3. "GOAL 3/4 - TOP FLOOR LOT - LAST ELEVATOR"
4. "FINAL GOAL - CROSS THE GREEN EXIT GATE!"

**Minimap** (top-right, 150x150 scaled):
- Position: `Vector2(-map_size - _px(24), _px(92))` from top-right
- See component 2.5 for draw details

**Bottom panels** (MarginContainer, PRESET_BOTTOM_WIDE, offset_top=-_px(152), margins l/r=_px(28), b=_px(24)):
- HBox, separation _px(24), alignment BEGIN
- **Instruments panel** (PanelContainer, left):
  - bg: `Color(0.045,0.045,0.08,1.0)`, left border: ORANGE 0.5 alpha, 3px, corner_radius 10, padding 20/20/12/12
  - VBox (separation _px(6)):
    - Speed label: "0 km/h" — _px(24)px, WHITE
    - Speed bar: _px(220) x _px(14), fill color ramps from `#ffb52e` to `Color(1.0,0.42,0.20)`
- **Spacer** (Control, expand-fill)
- **Abilities panel** (PanelContainer, right):
  - Same style as Instruments
  - VBox (separation _px(4)):
    - Boost label: "COFFEE BOOST READY [SPACE]" — _px(18)px, ORANGE when ready, ORANGE_BRIGHT when active, TEXT_MUTED at 0.45 when locked
    - Boost bar: _px(240) x _px(12), ORANGE fill
    - Sabotage label: "Q SABOTAGE" — _px(16)px, white at 0.72 alpha
    - Item label: "STAPLER x2 [Q]" or "SPILL x1 [Q]" — _px(16)px, coral for stapler, amber for spill

### 3.6 In-Match HUD — Secondary Modes (`ModeHUD.gd`, layer 10)

**Structure:** Full-rect root Control (mouse_filter=IGNORE) + PanelContainer at (24,24), size 420x142.

**Panel style:** bg=`Color(0.055,0.055,0.09,0.94)`, border=ORANGE 0.8 alpha 2px all, corner_radius 12.

**Layout (VBox, separation 5):**
1. Title: mode name — 24px, `#ffb52e`
2. Objective: objective text — 14px, `#d0d0df`
3. Timer: "TIME M:SS" — 16px, white
4. Progress label: "PROGRESS 0%" — 14px, `#a8ffbd`
5. Progress bar: full width, 14px height, ORANGE fill, corner_radius 6
6. Status: "READY" — 14px, `#a8ffbd` (color varies by status)

**API:**
- `configure(title, objective, time_limit)` — sets initial values, awaits `ready` if children not yet built
- `update_state(remaining, progress, status, status_color)` — updates timer/progress/status each frame

**Per-mode configuration:**

| Mode | Title | Objective | Time Limit | Progress Metric |
|---|---|---|---|---|
| Hauled | "HAULED" | "DELIVER HOSTILE CARGO" | 180s | Cargo-to-zone deliveries |
| Shop & Seek | "SHOP & SEEK" | "FIND 6 GROCERIES" | 60s | Targets found / 6 |
| Pizza Colony | "PIZZA COLONY" | "SURVIVE AND CLAIM TERRITORY" | 90s | Territory score % |

### 3.7 Pause Menu (`PauseMenu.gd`, layer 50)

**Structure:** Full-rect ColorRect backdrop `Color(0.02,0.02,0.04,0.82)` + centered PanelContainer (420px min width).

**Panel style:** bg=SURFACE_RAISED `#1c1c2e`, border=ORANGE 2px, corner_radius 16, padding 28/28/24/24.

**Layout (VBox, separation 16):**
1. Title: "PAUSED" — 36px, ORANGE, centered
2. Hint: "ESC to resume" — 13px, white at 0.55 alpha, centered
3. Resume button — 52px height, 20px font
4. Settings button — 52px height, 20px font
5. Quit to Menu button — 52px height, 20px font

**Behavior:**
- `process_mode = PROCESS_MODE_ALWAYS` (runs while tree paused)
- `get_tree().paused = true` on `_ready()`
- Mouse mode = VISIBLE
- Resume: unpauses, sets mouse CAPTURED, emits `resumed`, `queue_free()`
- Esc re-triggers resume via `_unhandled_input`
- Settings opens Settings.gd as child; hides pause panel while open
- Quit: unpauses, sets mouse VISIBLE, calls `_quit_callable` or changes scene to Main.tscn
- Resume button grabs focus on build (pad-navigable)

### 3.8 Results Panel (Evacuation, .tscn-defined Panel)

**Structure:** Center-anchored Panel, 600x400 (-300/-200 to 300/200), initially hidden.

**Layout (VBox, separation 20, insets 20px):**
1. **WinnerLabel**: "%s WINS!" — 32px, `Color(1, 0.65, 0.1, 1)`, centered
2. **StatsLabel**: multi-line — "TOP SPEED: X km/h\nTRAPS HIT: N"
   - Conditional lines:
     - "NEW TOP-SPEED RECORD" (with star glyph)
     - "NEW CHAIR UNLOCKED: SkinName - pick it in the menu" (with diamond glyph)
     - "MODIFIERS: Mod1, Mod2"
3. **RematchButton**: "REMATCH" — 60px height, 24px font
4. **MenuButton**: "MAIN MENU" — 60px height, 24px font

**Enter animation:** Fade + scale-in (~0.4s, ease_out). Implemented via `_end_race()` setting `visible=true` + tween.

**On show:** Confetti via `ImpactFX.confetti()`, victory audio if personal best, announcer + caption for skin unlocks.

### 3.9 Controls Overlay (`ControlsOverlay.gd`, layer 30)

**Purpose:** Round-start controls recap (6s auto-hide) + input device tracking.

**Layout:** Two-column PanelContainer:
- Left column: Keyboard & Mouse bindings (header + action rows)
- Right column: Controller bindings (header + action rows, uses `InputPrefs.pad_button_name()`)
- Active scheme column highlighted (accent border 2px vs muted 1px)
- Tip label below: "DEVICE: KEYBOARD" or "DEVICE: CONTROLLER"

**Fade:** 1.2s alpha tween in/out. Reduced motion: instant show/hide.

**Rebuild trigger:** Scheme or pad map signature change detected in `_process()`.

### 3.10 Subtitle Overlay (`SubtitleOverlay.gd`)

**Purpose:** Audio-cue captions for accessibility (traps, powerups, elevators, race events).

**Layout:** PanelContainer at bottom-center, `position=(0, -140)`, grow both directions.
- bg: `Color(0.02,0.02,0.04,0.88)`, border white 0.18 alpha 1px, corner_radius 10, padding 18/18/10/10
- Label inside, auto-sized
- Max width: 70% of viewport
- Auto-hide: 1.5s default (configurable per caption)

**Group:** `caption_overlays` — found by `Accessibility.caption()` from anywhere.

### 3.11 Mobile Controls (`MobileControls.gd`)

**Layout:** Full-rect Control, `mouse_filter=IGNORE`, drawn via `_draw()`.

**Elements (all positioned relative to bottom-right):**
- **Virtual joystick**: rest at `(130, 0)` from bottom-left, limit radius 92px
- **BOOST button**: center `(-130, -150)` from bottom-right, radius 58px
- **JUMP button**: center `(-260, -100)`, radius 44px
- **TRAP button**: center `(-130, -290)`, radius 40px

**Visual:**
- Joystick: outer ring (accent at 0.3 alpha, 2px), knob fill (accent at 0.5 alpha)
- Buttons: circle outline (accent 2px), label text inside ("BOOST"/"JUMP"/"Q")
- BOOST ring: dimmed while on cooldown (reads chair's actual cooldown via `local_chair_ref`)
- Press feedback: 0.15s flash (accent fill at 0.6 alpha decaying)

**Colors:** ACCENT = `Color(1.0, 0.6, 0.1)` (ORANGE equivalent).

**Gate:** Auto-on for Android/iOS; web auto-detects touchscreen; desktop via `FE_TOUCH=1` or `InputPrefs.touch_mode()=="on"`.

### 3.12 Modifier Menu (`ModifierMenu.gd`)

**Layout:** VBoxContainer mounted above PlayButton in Main.gd.

**Contents:**
1. Title: "TODAY'S OFFICE CHAOS" — 18px, ORANGE
2. Sub: "Optional rules for your solo race. Tap to mix and match." — 14px, TEXT_MUTED
3. Clear button: visible only when any modifier active
4. Chip flow (HFlowContainer): 5 toggle chips
   - NO COFFEE — accent `#ff6f61` (coral)
   - DOUBLE TRAPS — accent `#9b82ff` (violet)
   - LOW GRAVITY — accent `#57d7ff` (cyan)
   - SLIPPERY — accent `#b9f34a` (lime)
   - TIME ATTACK 90 — accent `#ff9a1a` (orange)
5. Summary label: plain-language description of combined effects

**Summary lines:**
- No modifiers: "Classic race - no special rules today."
- All on: "FULL CHAOS. Every rule at once. Good luck."

### 3.13 Credits Screen (`CreditsScreen.gd`, layer 80)

**Layout:** Full-rect ColorRect bg `Color(0.03,0.03,0.05,1.0)` + centered VBox.

**Content:** Two-column rows (role + name), 14 entries. Title at 32px ORANGE. Body at 16px TEXT. Special thanks line. "MADE WITH / Coffee. Obviously." closer.

**Exit:** Esc or back button returns to menu via `closed` signal.

---

## 4. Microcopy

### 4.1 Menu

| Element | Copy |
|---|---|
| Title | FRIDAY 5PM: EVACUATION |
| Subtitle | OFFICE CHAIR RACING |
| Play button | PLAY |
| Multiplayer button | MULTIPLAYER |
| Settings | SETTINGS |
| Credits | CREDITS |
| Map picker | MAP: OPEN PLAN / MAP: CUBICLE MAZE / MAP: EXECUTIVE |
| Touch toggle | AUTO / ON / OFF |

### 4.2 Mode Cards

| Mode | Title | Subtitle | Status | Description |
|---|---|---|---|---|
| Evacuation | Friday 5PM: Evacuation | PRIMARY MODE | PLAYABLE | It's 4:59 PM. Race your office chair through the building to the parking lot. Coffee boosts, water traps, stapler sabotage. Last one buys beers. |
| Hauled | HAULED | CO-OP PHYSICS DELIVERY | DELIVERY PLAYABLE | Delivery of absurd HOSTILE cargo - a fridge full of bees, a haunted sofa - through impossible terrain. Drop it, you owe money. |
| Shop & Seek | SHOP & SEEK | HIDE & SEEK | SHOPPER PLAYABLE | Half of you disguise as groceries in a supermarket. The other half are frantic shoppers with a list and 60 seconds. Spot the fake avocado. |
| Pizza Colony | PIZZA COLONY | CO-OP SURVIVAL | SURVIVAL PLAYABLE | You're toppings on a GIANT living pizza. Claim pepperoni territory, dodge the chef's slice-cutter, harvest cheese. |

### 4.3 HUD Readouts

| Element | Ready State | Active State | Locked State |
|---|---|---|---|
| Boost | COFFEE BOOST READY [SPACE] | COFFEE BOOST ACTIVE | COFFEE BOOST X.Xs |
| Sabotage | Q SABOTAGE | — | — |
| Item (stapler) | STAPLER x2 [Q] | — | — |
| Item (spill) | SPILL x1 [Q] | — | — |
| Timer | M:SS (orange) | — | M:SS (coral, pulsing <15s) |
| Status | RACE (green) | — | — |

### 4.4 Announcer Lines (sample, `Announcer.gd`)

**Boost:**
- "WHEEE!"
- "Chair mode: ENGAGED."
- "HR said no speeding. HR is not here."
- "That coffee was DECAF? Couldn't tell."
- "Physics remaining: zero."

### 4.5 Lobby

| Element | Copy |
|---|---|
| Title | MULTIPLAYER LOBBY |
| Status (default) | Choose HOST or enter a LAN address to JOIN. |
| Host button | HOST GAME |
| Join button | SCAN LOCAL WI-FI |
| Ready button | READY UP / NOT READY |
| Start button | START MATCH |
| Address placeholder | LAN address (default: 127.0.0.1) |
| Name placeholder | Your name |
| Avatar label | name - Rider / Chair - READY |

### 4.6 Results

| Element | Copy |
|---|---|
| Winner | %s WINS! |
| No winner | NO WINNER |
| Stats | TOP SPEED: %d km/h / TRAPS HIT: %d |
| Personal best | NEW TOP-SPEED RECORD |
| Skin unlock | NEW CHAIR UNLOCKED: %s - pick it in the menu |
| Modifiers | MODIFIERS: %s |
| Rematch | REMATCH |
| Main menu | MAIN MENU |

### 4.7 Pause

| Element | Copy |
|---|---|
| Title | PAUSED |
| Hint | ESC to resume |
| Resume | RESUME |
| Settings | SETTINGS |
| Quit | QUIT TO MENU |

### 4.8 Splash

| Element | Copy |
|---|---|
| Kicker | 4:59 PM FRIDAY |
| Title | FRIDAY 5PM: EVACUATION |
| Prompt (desktop) | CLICK / PRESS A TO START |
| Prompt (mobile) | TAP / PRESS A TO START |

---

## 5. Motion Specification

### 5.1 Tween Library

All tweens use Godot `Tween` created via `create_tween()` or `get_tree().create_tween()`.

| Name | Duration | Property | From | To | Easing |
|---|---|---|---|---|---|
| `splash_dismiss` | 0.45s | `modulate.a` | 1.0 | 0.0 | `Tween.EASE_OUT` |
| `results_enter` | 0.4s | `scale` + `modulate.a` | `Vector2(0.92,0.92)` / 0.0 | `Vector2.ONE` / 1.0 | `Tween.EASE_OUT` |
| `controls_fade_in` | 1.2s | `modulate.a` | 0.0 | 1.0 | `Tween.EASE_IN_OUT` |
| `controls_fade_out` | 1.2s | `modulate.a` | 1.0 | 0.0 | `Tween.EASE_IN_OUT` |
| `objective_flash` | ~0.3s (decay) | `modulate.a` | 1.6 | 1.0 | Linear (manual in `_process`) |
| `timer_pulse` | 0.5s cycle | `modulate.a` | 0.6 | 1.0 | Sinusoidal |
| `splash_prompt_pulse` | ~1.5s cycle | `modulate.a` | 0.5 | 1.0 | Sinusoidal |
| `boost_press_flash` | 0.15s | fill alpha | 0.6 | 0.0 | Linear (manual decay) |

### 5.2 Frame-Rate Independence

All per-frame smoothing uses `1.0 - exp(-k * delta)` where `k` controls sharpness:
- Camera follow: `k=8.0` (snappy)
- Chair facing lerp: `k=10.0`
- FOV kick: `k=5.0` (smooth)
- Objective flash decay: manual `delta * 2.0` subtraction

### 5.3 Reduced Motion

When `accessibility.reduced_motion = true`:
- All fade tweens: skip, instant show/hide
- Splash pulse: static at 0.85 alpha
- Timer pulse: disabled, solid CORAL
- Objective flash: disabled, instant text swap
- Controls overlay: instant show, 3s visible (shorter), instant hide
- Camera shake: disabled (separate `screen_shake` toggle, but reduced motion also gates)

### 5.4 High Contrast HUD

When `accessibility.high_contrast = true`:
- HUD panel bg: solid `#000000` at 1.0 alpha (no transparency)
- Text: pure white `#ffffff` at 1.0 alpha
- Timer: pure orange `#ff9a1a`, no gradient
- Speed meter: pure green `#00ff00` to red `#ff0000` ramp (engine default high-contrast)
- Border widths: doubled (2px -> 4px normal, 3px -> 6px top bar)

---

## 6. Accessibility

### 6.1 Settings (all persisted in `user://settings.cfg`)

| Setting | Key | Default | Effect |
|---|---|---|---|
| Screen shake | `accessibility.screen_shake` | true | Gates camera shake signal |
| Flash effects | `accessibility.flash_effects` | true | Gates visual flash on impacts |
| Reduced motion | `accessibility.reduced_motion` | false | Disables all non-essential animation |
| High contrast HUD | `accessibility.high_contrast` | false | Forces opaque bg + pure colors |
| Audio cue subtitles | `accessibility.subtitles` | false | Shows SubtitleOverlay captions |
| Game speed | `accessibility.time_scale` | 1.0 | 0.75x/1.0x/1.25x (single-player only) |
| Ghost pacer | `race.ghost_enabled` | true | Single-player ghost bot |

### 6.2 Input Accessibility

- Deadzones: 0.2 project-wide (lowered from 0.5 for weak sticks)
- Keyboard sensitivity: 0.15-1.5 slider (default 0.35, scales acceleration only)
- Mouse look: toggle + sensitivity 0.25-2.0 + Y invert
- Control scheme: AUTO (follows last device) / KEYBOARD & MOUSE / CONTROLLER
- Full remap grid: key + pad button per action
- Pad A always bound to `ui_accept` for menu navigation
- Mouse click = boost in race; release does NOT re-trigger
- All menus: `grab_focus()` on primary button for pad/keyboard nav

### 6.3 Caption System

`Accessibility.caption(text, duration)` routes to all nodes in group `caption_overlays`. Used by:
- Announcer lines (all categories)
- Trap hits ("WATER TRAP!", "BANANA PEEL!", "STAPLER FIRE!")
- Powerup pickups ("COFFEE BOOST!")
- Elevator events ("FLOOR 2 - GO!")
- Race events ("NEW TOP-SPEED RECORD!", "NEW CHAIR: %s")

---

## 7. Test Impact

### 7.1 Existing Test Files (must remain green)

| Test | Checks | What It Validates |
|---|---|---|
| `BootTest.gd` | ~48 | Script compilation + scene load + all smoke tests |
| `MenuLayoutSmokeTest.gd` | — | Menu VBox layout, overflow, narrow-window reflow |
| `SplashGateTest.gd` | 8 | Splash mount dedupe, dismissal, focus handoff |
| `ControlsOverlaySmokeTest.gd` | — | Two-column overlay mount + device tracking |
| `PauseMenuSmokeTest.gd` | — | Pause create/resume/quit cycle |
| `SettingsRoundTripTest.gd` | — | Settings save/load/apply round-trip |
| `ModifierMenuSmokeTest.gd` | — | Chip toggles + summary + persistence |
| `ArtHUDTest.gd` | 21 | HUD panel styles, meter fills, color ramps |

### 7.2 Implementation Test Requirements

Any UI change must pass:
1. `git diff --check` (no whitespace errors)
2. `godot --headless --script scripts/BootTest.gd` (all scripts compile)
3. `godot --headless --path . --quit-after 3` (project boots clean)
4. Relevant smoke test from the table above
5. **Vision QA** via `scripts/UISurveyCapture.gd` movie frames for any visual change

### 7.3 UISurveyCapture Harness

```bash
FE_UI_SCENE=res://scenes/Evacuation.tscn \
FE_UI_SCRIPT="10:hide_controls,12:click=I AGREE,40:real_pause,55:click=SETTINGS" \
godot --path . --script scripts/UISurveyCapture.gd --write-movie DIR/f.png --fixed-fps 10 --quit-after N
```

**Gotchas:**
- Never use `--headless` (viewport texture null = movie crash)
- Pre-create frame dir or movie writer fails `ERR_UNCONFIGURED`
- `--write-movie` forces project window resolution; `--resolution` flags ignored
- Splash needs `ui_accept` at ~frame 30 to reach the real menu
- For portrait captures: temporarily edit `viewport_width/height` in project.godot (restore after)

### 7.4 New Tests Required for Spec Changes

| Change Area | Test | Assertion |
|---|---|---|
| New token color | Add to UITheme const + BootTest | Const exists, color() returns correct Color |
| New panel variant | ArtHUDTest extension | StyleBoxFlat properties match spec |
| Timer critical pulse | HUD test extension | Timer label color == CORAL when <15s |
| Results animation | Evacuation smoke test | results_panel.visible transitions false->true with scale tween |
| Settings new toggle | SettingsRoundTripTest | New key persists + _apply_settings reads it |
| Mobile layout change | MobileControls mount test | Button positions match spec constants |

---

## 8. Implementation Notes for Godot GL Compatibility

### 8.1 Constraints

- **No .tscn UI scenes** for new UI. All UI built in code via `Control.new()`, `PanelContainer.new()`, etc. Exception: `Evacuation.tscn` contains `ResultsPanel` as a `.tscn`-defined Panel (already exists; extend in-place).
- **No custom fonts.** Use `ThemeDB.fallback_font` everywhere. Font size via `add_theme_font_size_override`.
- **No bloom/SSAO.** GL Compatibility renderer. Visual richness comes from StyleBoxFlat shadows, emissive materials, and procedural particles.
- **No shadows on UI.** Panel shadows are StyleBoxFlat `shadow_*` properties, not light shadows.
- **`_process()` not `_physics_process()`** for camera follow and visual smoothing (avoids stutter).
- **Frame-rate independent smoothing:** `1.0 - exp(-k * delta)`, never raw lerp factor.

### 8.2 StyleBoxFlat Patterns

All panels use `StyleBoxFlat` created via `FridayUITheme` static methods:
- `panel_style(accent, strong)` — panels, cards
- `button_style(bg, border, width, radius)` — buttons
- `apply_primary(button)` — play button
- `apply_secondary(button, accent)` — secondary buttons
- `apply_mode_card(button, accent, selected)` — mode cards

Never inline-create a `StyleBoxFlat` for a themed element without going through UITheme. Exception: HUD top bar and bottom panels have their own local StyleBoxFlat (already in `HUD.gd`).

### 8.3 Responsive Scaling

- HUD: `_ui_scale()` = `clampf(viewport_height / 720.0, 0.85, 1.6)`, all sizes via `_px(v)`
- Menu: `_is_narrow()` boolean gates layout mode (HBox vs HFlowContainer, hero panel visibility, label shortening)
- Settings: fixed 520x620 panel with ScrollContainer for overflow
- Mobile controls: absolute positions from bottom-right, not scaled by `_ui_scale()` (fixed pixel radii)

### 8.4 Mouse Capture Lifecycle

- Menu/Settings/Pause/Credits: `MOUSE_MODE_VISIBLE`
- Race start: `MOUSE_MODE_CAPTURED`
- Pause: `MOUSE_MODE_VISIBLE` -> Resume: `MOUSE_MODE_CAPTURED`
- Results: `MOUSE_MODE_VISIBLE`
- `_exit_tree()` safety: always sets `MOUSE_MODE_VISIBLE` (rematch reload skips `_on_back_to_menu`)
- Settings opened from pause: does not change mouse mode (pause already set VISIBLE)

### 8.5 Focus Management

- Splash dismiss: `play_button.grab_focus()`
- Pause open: `resume_btn.grab_focus()`
- Settings open: first slider/option grabs focus
- Mode card navigation: dpad/stick drives `ui_up`/`ui_down` through the ModeList VBox
- Utility row: focus flows left-to-right via `ui_right`/`ui_left`

### 8.6 CanvasLayer Layering Summary

```
Layer  10: HUD / ModeHUD (gameplay chrome)
Layer  30: ControlsOverlay (round-start recap)
Layer  50: PauseMenu (modal, process_mode=ALWAYS)
Layer  80: CreditsScreen (full-screen)
Layer  90: PreMatchModal (pre-race countdown)
Layer  95: SplashScreen (first-input gate, top of stack)
```

### 8.7 Z-Index Within HUD

Within HUD CanvasLayer (layer 10), child draw order follows tree order:
1. Top bar (PanelContainer)
2. Objective strip (Label)
3. Minimap (Control)
4. Bottom panels (MarginContainer > HBox > Instruments/Spacer/Abilities)

MobileControls (if mounted) is a sibling Control under the same parent as HUD, drawn after (on top).

---

## 9. Cross-Reference: Existing Code Locations

| Spec Section | File | Key Functions |
|---|---|---|
| Design tokens | `scripts/UITheme.gd` | `color()`, `panel_style()`, `button_style()`, `apply_primary()`, `apply_secondary()`, `apply_mode_card()` |
| HUD | `scripts/HUD.gd` | `_build_hud()`, `_ui_scale()`, `_px()`, `set_floor()`, `set_speed()`, `set_boost()`, `set_item()`, `set_timer_text()`, `set_status()` |
| Main menu | `scripts/Main.gd` | `_build_mode_buttons()`, `_build_hero_panel()`, `_build_character_selector()`, `_build_skin_selector()`, `_build_modifier_row()`, `_select_mode()` |
| Settings | `scripts/Settings.gd` | `_build_ui()`, `_apply_settings()`, `_cfg_bool()`, `_load_settings()` |
| Pause | `scripts/PauseMenu.gd` | `create()`, `_build_ui()`, `_resume()`, `_quit()` |
| Lobby | `scripts/Lobby.gd` | `_ready()`, `_refresh_players()`, `_avatar_label()` |
| Mode HUD | `scripts/ModeHUD.gd` | `configure()`, `update_state()` |
| Minimap | `scripts/Minimap.gd` | `set_player()`, `_draw()`, `_panel_style()` |
| Splash | `scripts/SplashScreen.gd` | `mount()`, `_build_ui()`, `_input()` |
| Mobile | `scripts/MobileControls.gd` | `mount_for_mode()`, `bind_local_chair()`, `_draw()` |
| Results | `scripts/Evacuation.gd` | `_end_race()`, `_on_rematch()`, `_on_back_to_menu()` + `Evacuation.tscn` ResultsPanel node |
| Modifiers | `scripts/ModifierMenu.gd` | `mount()`, `_ready()` |
| Controls overlay | `scripts/ControlsOverlay.gd` | `mount()`, `show_for()` |
| Subtitles | `scripts/SubtitleOverlay.gd` | `_ready()` (joins `caption_overlays` group) |
| Credits | `scripts/CreditsScreen.gd` | `_build_ui()` |
| Announcer | `scripts/Announcer.gd` | `mount()`, `say()` |
| Accessibility | `scripts/Accessibility.gd` | `caption()`, `reset_time_scale()` |
| Input prefs | `scripts/InputPrefs.gd` | `refresh_cache()`, `apply_mouse_motion()`, `touch_mode()`, `touch_enabled()` |

---

## 10. Future-Proofing & Extension Points

### 10.1 Adding a New Mode Card

1. Add entry to `MODE_INFO` in `Main.gd` (title, subtitle, desc, mode enum, accent color)
2. Add status string to `MODE_STATUS` array
3. ModeCard auto-builds from the array; no UITheme changes needed
4. Add smoke test entry in `ModeSmokeTest.gd`

### 10.2 Adding a New Setting

1. Add CheckButton/Slider/OptionButton in `Settings.gd._build_ui()`
2. Add `_cfg_bool()` or `config.get_value()` read in `_load_settings()`
3. Add apply logic in `_apply_settings()`
4. Add round-trip assertion in `SettingsRoundTripTest.gd`

### 10.3 Adding a New UI Overlay

1. Create `scripts/YourOverlay.gd` extending `CanvasLayer`
2. Implement `static func mount(parent: Node)` with dedup check (pattern: `get_node_or_null` by name)
3. Pick a layer number from the z-order table (section 1.6)
4. Add to `BootTest.gd` script list
5. Add smoke test `YourOverlaySmokeTest.gd`

### 10.4 Adding a New Token Color

1. Add `const YOUR_COLOR := "hexvalue"` to `FridayUITheme`
2. Use via `FridayUITheme.color(FridayUITheme.YOUR_COLOR)`
3. Add assertion in `ArtHUDTest.gd` that the const exists and parses
4. Update this spec's token table

---

*End of specification. Implement verbatim in Godot 4.7.1 GL Compatibility renderer using code-built Control nodes and `scripts/UITheme.gd` theme helpers.*
