# UI layouts and token migration

Authority: Astra. Base canvas: 1280 × 720 logical pixels.
Positions are (x, y, width, height), measured from the canvas top-left.
Use code-built Control nodes and the existing FridayUITheme helper architecture.
Extend the existing scene-defined ResultsPanel in place.
This specification supersedes conflicting old colors, fonts, and layout coordinates.

## 1. Typography

Package Noto Sans Regular 400, SemiBold 600, and Bold 700 with its license.
Use static font files for predictable weight selection.
Use tabular lining numerals for timer, speed, counters, and results.
Font fallback is reserved for missing glyph coverage, not ordinary English UI.
Do not simulate bold by enlarging regular text or adding a heavy outline.
Do not use a condensed font or italic for essential information.

| Role | Size px | Weight | Line height px | Use |
|---|---:|---:|---:|---|
| Display | 42 | 700 | 46 | Splash and menu brand |
| Outcome | 32 | 700 | 38 | Winner / defeat / completion |
| Timer | 34 | 700 | 40 | Immediate time remaining |
| Section | 24 | 700 | 30 | Screen title, resource values |
| Card hero | 20 | 700 | 25 | Evacuation mode card |
| Card/body | 18 | 600 | 24 | Other cards and action buttons |
| Body detail | 16 | 400 | 22 | Explanations and settings |
| Objective | 18 | 700 | 24 | Immediate gameplay action |
| Caption | 14 | 600 | 18 | Labels, hints, list rows |
| Micro | 12 | 600 | 16 | Nonessential utility metadata |
| Countdown | 64 | 700 | 72 | 3 / 2 / 1 / GO! |

Essential text never uses Micro.
World signage uses Noto Sans Bold with dimensions from the composition sheet.
Use sentence case for explanations and uppercase for short operational labels.
Letter spacing is 0 by default; kicker and section labels use +1 px.
Body copy wraps at word boundaries; no mid-word clipping.
Names ellipsize after the available width, with full name in focused detail.
Timer always reserves width for 00:00 to prevent horizontal jitter.
Counters reserve at least three digits unless the underlying value needs more.
No essential information depends on hover or a tooltip.

## 2. FridayUITheme token map

| Existing/new constant | Exact value | Migration decision |
|---|---|---|
| BG | #0A0A0F | Retain ink |
| SURFACE | #121921 | Replace purple-black surface |
| SURFACE_RAISED | #1B2532 | Replace old raised panel |
| SURFACE_HOVER | #263445 | Slate hover surface |
| TEXT | #F3E7D3 | Replace paper-white with ivory |
| TEXT_MUTED | #B8B5AE | Readable neutral secondary text |
| DISABLED_TEXT | #817F7C | Disabled text; always with lock/state label |
| ORANGE | #FF9A1A | Retain primary accent |
| ORANGE_BRIGHT | #F2C66D | Compatibility alias to BUTTER |
| ORANGE_PRESSED | #D98116 | Fixed pressed background |
| TEAL | #2C8C91 | New canonical information accent |
| CYAN | #2C8C91 | Legacy alias; migrate callers toward TEAL |
| LIME | #2C8C91 | Legacy ready alias; add check/text cue |
| CORAL | #E45B4F | New danger value |
| VIOLET | #8674B8 | New unlock value |
| BUTTER | #F2C66D | Hover highlight and record accent |
| SLATE | #263445 | Tracks and secondary structure |
| IVORY | #F3E7D3 | Alias to TEXT for world/shared terminology |

Legacy aliases prevent a broad caller rewrite.
Do not retain old neon values in local HUD Color literals.
Ready uses an ivory check on teal with READY text.
Small information text is ivory, not teal on ink.
Coral warnings use ivory words beside a coral symbol, not small coral-only copy.
Primary orange buttons use ink text.

### Component dimensions

Normal panel: SURFACE at alpha 0.96, radius 14, border 1 px SLATE.
Normal panel padding: left/right 18, top/bottom 12.
Strong panel: SURFACE_RAISED at alpha 1.0, radius 16, border 2 px ORANGE.
Strong panel padding: left/right 28, top/bottom 24.
Panel shadow: INK alpha 0.38, offset (0, 5), size 6 normal / 10 strong.
Primary button: ORANGE fill, BUTTER 2 px border, radius 14.
Primary hover: BUTTER fill, IVORY 2 px border.
Primary pressed: ORANGE_PRESSED fill, BUTTER border, 2 px downward content offset.
Secondary button: SURFACE fill, SLATE 1 px border, IVORY text, radius 12.
Secondary hover: SURFACE_HOVER fill, ORANGE 2 px border.
Focus: an additional 2 px ORANGE outer outline with 3 px offset.
Focus must remain visible on orange-filled buttons; use IVORY inner keyline there.
Disabled: SURFACE fill, DISABLED_TEXT, lock icon or explicit unavailable label.
Desktop primary/secondary actions have minimum height 52 px.
Touch targets have minimum 48 dp independent of visual pixel scaling.
Progress track: SLATE, height 12 px, radius 4.
Progress fill: ORANGE, height 12 px, radius 4.
A labeled percentage or count accompanies every gameplay progress bar.
Use UITheme helpers for all these styles, including HUD local exceptions during migration.

## 3. Main menu — desktop

Left navigation owns x = 0–512, exactly 40% of the base canvas.
Right comedy owns x = 512–1280.
Navigation content has 32 px outer horizontal margins and width 448 px.
A fixed ink field covers the left 40%; blend into the right over x = 480–640.
This gradient is a backdrop treatment, not a transparent layer over gameplay.

| Element | Rectangle | Content/rule |
|---|---|---|
| Kicker | (32, 24, 448, 18) | 4:59 PM FRIDAY, 14 px orange |
| Brand | (32, 48, 448, 92) | FRIDAY 5PM / EVACUATION, 42 px ivory |
| Mode scroll | (32, 152, 448, 272) | Four mode cards, vertical gap 8 |
| Rider/chair row | (32, 436, 448, 52) | Two 218 px selectors, gap 12 |
| Selected ride detail | (32, 492, 448, 44) | Two lines, 14 px, wrapping |
| Chaos summary | (32, 544, 448, 32) | TODAY'S OFFICE CHAOS + selected count |
| Play | (32, 584, 448, 52) | Primary PLAY |
| Multiplayer | (32, 644, 448, 28) | Secondary utility-style LAN entry |
| Utility row | (32, 680, 448, 28) | SETTINGS / CREDITS / MAP / TOUCH |

Multiplayer's 28 px desktop visual receives a 48 dp target in touch layouts.
Mode cards: Evacuation 84 px high; remaining three 56 px each.
With three 8 px gaps the stack is 276 px; the 272 px viewport scrolls 4 px.
This tiny overflow is intentional; never shrink the hero card to fit.
Prefer a 4 px visible scrollbar rather than clipped text.
Evacuation has 4 px orange leading strip, 20 px title, PRIMARY MODE pill.
Other cards have 18 px title and a 12 px state label.
Selected card adds a check and SELECTED label; disabled is not used to mean selected.
Cards retain their actual playable/prototype state independently from selection.
The chaos summary opens the existing ModifierMenu for full two-row chips.
This keeps modifiers after the rider/chair row and before Play.
No modifiers are silently hidden or enabled by the layout.

### Right-side comedy

Hero chair center is (930, 442); full silhouette fits (712, 206, 480, 390).
Pose shows a three-quarter rear worker leaning into a tiny chair mishap.
A copier being tugged occupies (1100, 430, 140, 150).
Keep head and caster silhouettes clear of UI and screen edges.
YOUR RIDE panel is (908, 36, 340, 140), aligned to the right margin.
The panel uses the actual selected rider/chair names and available stats.
Mode description sits in (648, 612, 568, 64), maximum three lines at 16 px.
Its backdrop is an INK bottom-up scrim from alpha 0 to 0.72.
The right image retains a low-contrast office window and warm late-afternoon key.
Produce/pizza Easter eggs fit below y = 570 and are noninteractive.
MenuHero/MenuBackdrop may render the same composition with existing draw/mesh paths.
Use the same worker/chair resources for any live preview.
Menu key-art source is at least 2560 × 1440; runtime exports follow PRESETS.

### Backdrop motion correction

MenuBackdrop currently animates skyline sway, a moving floor pool, and ceiling pulses.
Replace them with one restrained 12 s chair-comedy loop.
Loop: 8 s stillness, 0.5 s tug, 0.7 s caster wobble, 2.8 s settle.
Keep window mullions, floor lighting, and the sun fixed.
Optional skyline parallax is capped at 3 px over 12 s.
Reduced motion displays the neutral composed frame.
No menu animation passes beneath a focused text field.

### Responsive menu

Desktop width below 1080 hides YOUR RIDE, preserving the older responsive rule.
At width 960–1079, retain a 40% nav field with a minimum 352 px inner column.
Below 960 logical px, use a 56% navigation field and cropped chair art on the right.
This is the narrow/touch exception to the desktop 40% composition.
At low height, pin PLAY and MULTIPLAYER in a bottom action tray.
Put cards, selectors, detail, chaos, and utility entries in one vertical scroll region.
Never shrink essential font sizes below 14 px to avoid scrolling.
Touch reflow uses dp rules in section 9.

## 4. Splash, loading, and briefing

Splash sits above the actual menu backdrop, not a flat orange field.
Use an INK scrim alpha 0.88.
Centered brand region is (320, 224, 640, 220).
Kicker is 14 px ORANGE; title is two lines at 42 px IVORY with 3 px ORANGE outline.
Tagline is 16 px TEXT_MUTED; prompt is 22 px ORANGE.
Prompt reads CLICK / PRESS A TO START or TAP / PRESS A TO START by active device.
Prompt pulse is 1.5 s, alpha 0.65–1.0; reduced flashing makes it static.
Dismiss fade is 0.45 s; reduced motion makes dismissal immediate.
Focus transfers to Play after dismissal.

LoadingScreen uses INK background and a 320 × 12 px orange progress track at (480, 408).
Title is centered at y = 328, 24 px IVORY.
Use actual load progress if available; otherwise show a static LOADING label.
Never show fictional progress or a fake performance claim.
PreMatchModal uses a centered 600 × 440 strong panel.
Three rules appear as 18 px rows with 32 px icons, each at least 64 px high.
I AGREE is a 52 px primary action pinned to the panel bottom.
Countdown appears only after the existing briefing gate releases the match.
Countdown is centered, 64 px orange, 0.7 s each numeral and 0.5 s GO!.
Visual timings must follow authoritative start events; never delay gameplay to finish a tween.

## 5. Lobby

Lobby panel is (80, 48, 1120, 624), opaque SURFACE_RAISED.
Header is (108, 72, 1064, 38), 24 px MULTIPLAYER LOBBY.
Left setup column is (108, 128, 360, 432).
Right roster column is (492, 128, 680, 432).
Bottom actions occupy (108, 584, 1064, 60).
Name and LAN address fields are each 360 × 52 px with visible labels.
HOST GAME and JOIN/SCAN retain their existing actions and availability.
Address example belongs in helper text, never as submitted user content.
Connection status occupies two wrapped 16 px lines below the connection controls.
Error state uses a coral exclamation and an explicit reason, with a retry action.
Rider/chair selectors use the same components as the menu.
Identity swatches become 48 × 48 px targets with color, shape, and slot numeral.
They are keyboard-focusable; do not preserve the old FOCUS_NONE swatch policy.

Roster rows are 64 px high with 8 px gaps inside a ScrollContainer.
Nine entries may scroll; do not compress rows to fit all peers.
Each row contains a 40 px badge, name 18 px, rider/chair 14 px, readiness state.
Ready column is 116 px wide, with check + READY or hollow square + NOT READY.
Host label is a 12 px pill beside the name.
Local row has a 2 px orange border plus YOU text.
Bottom left: LEAVE 160 × 52.
Bottom right: READY UP 220 × 52 and START MATCH 220 × 52, gap 12.
START MATCH is visible only to the host and reflects actual start eligibility.
Full roster names appear on focus in a two-line detail strip above bottom actions.
Connection loss uses the same error panel, preserving the actual return-to-menu flow.
No animated 3D avatar lineup is required; one selected preview is sufficient.

## 6. Gameplay HUD hierarchy

Immediate objective is first, essential player state second, supporting data third.
Timer belongs to the objective group and remains its strongest numeral.
The central driving window x = 320–960, y = 160–560 stays free of persistent panels.
Transient interaction prompts may occupy its bottom edge, never its center.
Do not preserve the current full-width 76 px top bar.

| Group | Rectangle | Contents |
|---|---|---|
| Objective header | (352, 16, 576, 64) | Caption left; timer right |
| Objective strip | (352, 84, 576, 56) | Arrow/icon + immediate action, two lines max |
| Floor/map group | (24, 16, 200, 212) | Story 01 / 04, then 168 px map |
| Player state | (24, 576, 288, 120) | Speed, thrust, item/charges |
| Supporting status | (968, 16, 288, 64) | Mode/round/race state |
| Context prompt | (440, 568, 400, 40) | Input glyph + currently available action |
| Captions | (320, 620, 640, 64) | Up to two subtitle lines |

Objective header background is BG at alpha 0.96.
Objective strip background is BG at alpha 0.92, radius 8, padding 12.
Objective text is IVORY 18 px; arrow is ORANGE 28 px.
Its 4 px INK outline is retained for continuity but is not the main contrast mechanism.
Timer is 34 px ORANGE; label EVACUATION WINDOW is 14 px IVORY.
Below 15 s use CORAL timer and an exclamation icon.
Critical pulse is a 0.5 s alpha 0.75–1.0 cycle; reduced flashing makes it solid.
Floor text is 20 px IVORY with a small landmark icon.
Speed is 24 px IVORY with adjacent 12 px km/h.
Speed meter is 112 × 8 px, ORANGE throughout; no green-to-red ramp.
Thrust meter is 252 × 12 px with READY / ACTIVE / cooldown text at 14 px.
Item row uses a 20 px item icon, charge count, and current binding glyph.
Keep status and humor out of the immediate objective strip during active navigation.

### Evacuation objective copy

01: REACH CHAIR LIFT ↑ 02.
02: REACH CHAIR LIFT ↑ 03.
03: CROSS LANDINGS / REACH LIFT ↑ 04.
04: CROSS THE PARKING EXIT.
During a transfer: GOING UP / FLOOR NN.
Finish state: EVACUATION COMPLETE or TIME EXPIRED, using actual outcome.
Do not reuse HUD.gd's GREEN EXIT GATE text.
FLOOR CLEARANCE means actual story progress, not a new task counter.

### Minimap grammar

Panel is BG at alpha 0.96 with 1 px SLATE border and radius 10.
Map occupies a 168 × 168 inner square.
Route uses 3 px ORANGE segments with arrowheads.
Local player uses its slot shape, 10 px size, IVORY fill and INK outline.
Facing direction is a 6 px attached triangular nose.
Exit is an 18 px car-and-arrow icon inside an orange square.
Lift is a 14 px chair/up-arrow icon with destination numeral.
Other players appear only where current mode rules already permit them.
Shop & Seek does not gain an opponent minimap through this restyle.
Grid lines use IVORY at 0.06 alpha and never dominate the route.
Story label sits outside the map graphic, avoiding marker overlap.

### HUD.gd migration contract

Retain set_floor, set_speed, set_boost, set_item, set_timer_text, and set_status callers.
Move floor_label/minimap into one aligned group.
Move timer_label and objective_label into the top-center objective group.
Move speed_label, speed_bar, boost_label/bar, item_label, and sabotage_label into player state.
Keep Instruments and Abilities addressable if callers or tests reference those names.
Replace local StyleBoxFlat/color literals with UITheme component variants.
Replace FLOOR_GOALS copy with the four approved story actions.
Use _px only once per dimension; prevent double scaling with canvas stretch.
Replace height-only _ui_scale behavior with a single logical-canvas transform.
All HUD widgets use the same scale, safe rectangle, and margin source.

### Secondary ModeHUD adapter

Keep configure(title, objective, time_limit) and update_state entry points.
Map title/status to supporting state, objective/timer to the objective group.
Use mode-owned state for resource/list detail rather than parsing status strings.
Hauled player state: cargo value, carry state, action binding.
Hauled supporting state: round N / 3 and total score.
Shopper player state: five-item list, collected check marks, disguise state.
Shopper list may extend the left group to y = 420, leaving the central window clear.
Hider/seeker player state: active-role action and cooldown, only when role exists.
Pizza player state: cheese, toppings, build cost; supporting state: pads owned / 10.
A mode does not show unused speed or sabotage widgets merely to fill space.

## 7. ResultsPanel and mode outcomes

Keep $UI/ResultsPanel as the existing scene-defined Panel.
Base rectangle is (340, 160, 600, 400).
Use strong UITheme panel: opaque SURFACE_RAISED, 2 px ORANGE border, radius 16, shadow 10.
Keep VBox, WinnerLabel, StatsLabel, and existing button references valid through migration.
StatsLabel may become a hidden compatibility source while visible cells use the same data.
Never show both the legacy multiline block and the new stats grid.

| Element | Panel-local rectangle | Treatment |
|---|---|---|
| Report kicker | (28, 24, 544, 18) | INCIDENT REPORT, 14 px muted |
| Winner | (28, 48, 544, 44) | 32 px BUTTER, 4 px INK outline |
| Stats grid | (28, 108, 544, 76) | Two 266 px columns, gap 12 |
| Reward/status region | (28, 196, 544, 92) | Record/unlock/modifier lines; scroll if needed |
| Buttons | (28, 324, 544, 52) | REMATCH / MAIN MENU, equal widths, gap 12 |

Top speed value is 24 px ORANGE; traps-hit value is 24 px IVORY.
Their labels are 14 px TEXT_MUTED above each value.
Record pill: BUTTER background, INK star + NEW TOP-SPEED RECORD.
Unlock pill: VIOLET leading diamond, IVORY text on SURFACE.
Multiple unlocks wrap in the scroll region; buttons never move offscreen.
Modifier summary uses actual selected modifiers in 14 px text.
Winner name may use two lines by consuming 20 px of reward-region height.
No winner displays NO WINNER; it does not award a winner banner to the local player.
Secondary modes reuse the panel with actual outcome and two mode-appropriate stats.
Hauled: total score / deliveries; Shop: collected / target; Pizza: pads / resources.
If a statistic is unavailable, show an em dash with NOT RECORDED, never invent a value.

Panel enter: alpha 0→1 and scale 0.96→1.0 over 0.4 s, cubic ease-out.
One 1.01 overshoot at 0.28 s is allowed; reduced motion shows the final state instantly.
HUD behind results fades to 0.35 over 0.15 s and becomes noninteractive.
Touch controls disappear immediately when player movement is disabled for results.
Winner-only celebration uses the art-bible 64-piece confetti cap for 1.2 s.
Current ImpactFX.confetti is a world effect; adapt or reuse it without assuming a 2D API.
Do not fire both a world burst and a duplicate UI burst.
Focus REMATCH on open, restore visible mouse, and retain existing rematch/menu signals.

## 8. Remaining player-facing flows

Pause: centered 440 × 360 strong panel, RESUME / SETTINGS / QUIT TO MENU, 52 px rows.
Pause background is INK alpha 0.82; first focus is RESUME.
Settings: 520 × 620 strong panel, scroll body, pinned 52 px BACK.
Settings sections: VIDEO / AUDIO / ACCESSIBILITY / INPUT, 14 px ORANGE, 10 px top gap.
Video names: Standard / Enhanced on desktop; Android on Compatibility mobile.
Keep resolution and frame-cap controls distinct from appearance preset selection.
Sliders: 4 px SLATE groove, 8 px ORANGE visual handle, 48 dp touch hit height.
CheckButton: 16 px IVORY text with explicit ON/OFF state and check shape.
ControlsOverlay: 680 × 300 centered panel, two equal columns, 18 px actions and glyphs.
Place round-start recap below the objective, dismiss through its existing behavior.
ModifierMenu: 640 × 480 strong panel, two chip rows maximum before scrolling.
Modifier chips: 14 px title, 12 px description, 2 px active border and check.
PreMatchModal: use section 4; do not merge its consent gate with countdown.
CreditsScreen: INK background, 32 px title, 16 px two-column credits, pinned BACK.
Include Noto Sans attribution/license entry with the existing credits flow.
ChatOverlay: bottom-left above player state, 288 × 240 max, 16 px text.
When typing, temporarily replace the local player-state panel; do not cover the route center.
SubtitleOverlay: two lines, 18 px IVORY on BG alpha 0.96, default 1.5 s or event duration.
Long captions queue rather than stack; no more than two visible lines.
PortraitHint: opaque ink with landscape-device icon and ROTATE TO LANDSCAPE, 20 px.
Stats/unlocks: reuse results pills and menu ride detail; do not add a new progression system.
Host loss: 520 × 300 modal with connection icon, explicit status, MAIN MENU action.
All errors retain the user's entered address/name and show text beside the icon.

## 9. Landscape touch layout

Touch uses a safe-area-relative dp coordinate system, independent of 720p HUD pixels.
Convert physical safe-area insets once into the logical layout coordinate space.
Let S be the safe rectangle after device cutouts and gesture insets.
Apply an additional 16 dp margin inside S on all sides.
No target may straddle the cutout or system gesture region.
Every interactive target is at least 48 × 48 dp, with 8 dp separation.
Default layout below uses a 640 × 360 dp safe rectangle before the extra margin.

| Control | Center or rectangle relative to S | Visible/target size |
|---|---|---|
| Steering base | (88, S.height - 88) | 112 dp circle |
| Steering knob | At base center when idle | 48 dp circle |
| Boost | (S.width - 64, S.height - 72) | 72 dp circle |
| Context action | (S.width - 152, S.height - 64) | 56 dp circle |
| Secondary action | (S.width - 64, S.height - 152) | 56 dp circle |
| Pause | (S.width - 64, 16, 48, 48) | 48 dp square |
| Objective | (S.width/2 - 140, 16, 280, 56) | Two-line 16 dp text |
| State strip | (S.width/2 - 96, S.height - 56, 192, 40) | 14 dp state text |

Steering input capture stays in the left 42% of S below the top objective.
Right actions stay in the right 38%; center remains available for the route view.
Steering travel radius is 40 dp; knob does not leave its base target.
Boost is ORANGE with INK cup/arrow glyph and BOOST label.
Context is SLATE with IVORY glyph and actual action label.
Secondary is SLATE with CORAL icon only for actual sabotage/danger actions.
Cooldown retains a hollow ring, time text, and lock symbol.
Never show JUMP when the same action currently means GRAB, DISGUISE, or BUILD.
MobileControls action_pressed names remain boost/action/sabotage at the routing boundary.
Map labels from actual mode hooks and InputPrefs bindings.
Hauled context: GRAB / RELEASE according to held state.
Shop context: DISGUISE / REVEAL; seeker action: SCAN only if supported.
Pizza context: BUILD; suppressed actions are omitted with remaining targets reflowed.
Evacuation context: JUMP; secondary: item name or SABOTAGE.
Every touch action displays its desktop equivalent in ControlsOverlay.

### Scaling and repositioning

Control scale choices are 100%, 115%, and 130%; 100% is default.
Targets never scale below 48 dp, including compact variants.
Drag repositioning is enabled only in Settings > Input > Edit touch layout.
Show 8 dp snap grid, safe bounds, and a RESET button.
Store normalized safe-rectangle positions separately for steering and action cluster.
Clamp the whole scaled cluster inside S plus margins, not just its center.
Reject overlapping targets and show the previous valid position with an outline.
Persist positions per landscape aspect class: below 1.8 and 1.8 or above.
If S is under 320 dp high, use 56 dp boost and 48 dp action targets with 8 dp gaps.
Hide supporting status and minimap before shrinking touch targets or objective text.
Captions move above the bottom state strip and remain outside thumb regions.
Touch menu rows grow to 48 dp; use scrolling and pinned actions.

## 10. Accessibility, focus, and layers

High contrast uses opaque BG, IVORY text, 2 px normal borders, 4 px focus borders.
Retain shape icons and labels; do not introduce a red/green meter gradient.
Reduced motion skips entry scale, overshoot, parallax, confetti, and decorative loops.
Reduced flashing disables timer/splash pulses and impact brightness changes.
Neither option changes disguise wobble, hazard motion, or threat duration.
Keyboard/gamepad focus follows visual reading order, ending on the primary action.
Cancel returns one layer and restores focus to the opening control.
Input glyphs come from active InputPrefs bindings, not hardcoded Q/E/Space strings.
Preserve existing mouse capture lifecycle on play, pause, resume, and results.
Use layer 10 for HUD, 20 results, 25 chat/captions, 30 controls recap.
Use layer 50 pause/settings, 80 credits, 90 briefing, 95 splash.
Only the top modal accepts pointer/focus input.
Results hide gameplay captions before its winner text appears.
No fullscreen backdrop remains mouse-intercepting after its owning modal closes.

### Compact modal geometry

All modal rectangles above are maximum base-canvas sizes, centered in the safe rectangle.
Desktop modal width is min(specified width, safe width - 32 px).
Desktop modal height is min(specified height, safe height - 32 px).
Below the base height, keep header and 52 px footer fixed; scroll the middle content.
Touch modal padding is 16 dp and footer buttons are at least 48 dp high.
If two footer buttons cannot each reach 120 dp width, stack them with an 8 dp gap.
Results on touch uses a maximum 560 × 320 dp panel with a scrollable stats/rewards body.
Long winner names remain above that scroll body in a two-line 24 dp heading.
No results, pause, briefing, settings, or error action is placed outside the safe rectangle.
For 960–1079 px desktop menus, reduce nav horizontal margins to 16 px.
That gives the 960 px canvas a 352 px inner column within its exact 40% nav field.
