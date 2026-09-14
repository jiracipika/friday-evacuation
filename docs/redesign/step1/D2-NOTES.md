# D2 HUD hierarchy restyle — implementation notes (2026-09-14)

Spec: UI-LAYOUTS §6 + HUD.gd migration contract. This slice covers the full
§6 desktop hierarchy; ModeHUD adapter §6.5 and minimap grammar stay intact.

## Changes vs current HUD.gd
1. KILL the full-width 76px top bar (spec: "Do not preserve"). Replace with:
   - Objective header, top-center (352,16,576,64): caption "EVACUATION
     WINDOW" 14px ivory left, timer 34px orange right. BG alpha 0.96.
   - Objective strip below (352,84,576,56): arrow + FLOOR_GOALS copy,
     BG alpha 0.92, radius 8, ivory 18px text, orange 28px arrow.
   - Floor/map group top-left (24,16,200,~230): FLOOR NN 20px + minimap 168px
     (move minimap from top-right; spec puts map with floor label).
   - Player state bottom-left (24,576,288,120): speed 24px ivory + 12px unit,
     112x8 orange meter (spec width; keep warm identity constant orange —
     spec says "ORANGE throughout; no green-to-red ramp", retire the amber→
     coral lerp), boost 252x12 + READY/ACTIVE text 14px, item row.
   - Supporting status top-right (968,16,288,64): RACE/round state.
2. All colors/panels via UITheme tokens (BG #0a0a0f panels, ORANGE, IVORY
   TEXT #f7f6f2, TEXT_MUTED, CORAL #ff6f61 critical). Kill local literals.
3. Keep set_floor/set_speed/set_boost/set_item/set_timer_text/set_status
   signatures; keep Instruments/Abilities names addressable; keep
   _px single-scaling (height-based clamp kept — full logical-canvas rework
   is deferred; spec item noted in STATUS open questions).
4. FLOOR_GOALS copy per §6 Evacuation objective copy:
   01: REACH CHAIR LIFT ↑ 02 / 02: REACH CHAIR LIFT ↑ 03 /
   03: REACH LIFT ↑ 04 / 04: CROSS THE PARKING EXIT.
   (GREEN EXIT GATE copy retired.)
5. Critical timer <15s: CORAL + pulse (existing behavior kept; reduced
   motion = solid).

## Tests
- ArtHUDTest exercises HUD build — must stay green.
- ModeSmokeTest covers set_* callers.
