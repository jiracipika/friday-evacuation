# INTEGRATION-AUDIT — Living Office / Frictionless Entry (Phases 1C, 2, 3, 4)

Read-only code-evidence audit. No code was modified; no Godot instance was run; no visual acceptance claims are made. PlayerChair.gd is foreign uncommitted work (per PLAN.md "Authority") and was treated as read-only reference. All citations are `path:line` against checkout at commit b6b4eaf (git status: PLAN.md, PlayerChair.gd, run_ladder.sh modified; hero_assembly.glb, HeroAssemblySmokeTest.gd untracked — none touched).

---

## 1. Procedural startup dependency chain (Phase 1C)

### Actual chain in `Evacuation._ready()` (scripts/Evacuation.gd:64-131)

Synchronous, single-frame, in this exact order:

1. `_setup_arena()` (Evacuation.gd:65 → 417-461), internally ordered:
   1. Modifier/layout read: `RaceModifiers` + `Network` peer check (419-423)
   2. `_build_floor` ×4 at y=0/6/12/18 (424-427) — slab+mesh+walls+ceiling; floor index 2 (stairwell) skips the slab (1011-1019)
   3. `_setup_environment()` (428) — env preset + directional light + **`_spawn_dust_motes()` (1557)**
   4. Four `_theme_floor*` functions (432-435) — cubicles/plants, tables/coolers/vending/clock/surface zones, stairwell landings/stripes/crates, cafeteria ice/tables/spills/parking lot
   5. Hazards node instantiation (438-443) — activates at race start, not here
   6. `_spawn_columns()` (446 → 876-901)
   7. `_build_elevator` ×3 (451-453) — Area3D triggers with teleport lambdas
   8. `_spawn_obstacles()` (455 → 1753-1782) — seeded desks + layout crates
   9. `_spawn_powerups()` (456 → 1832-1854) — seed 999, `PowerUp.create(...)` + `sync_name`
   10. `_add_exit_marker()` (457) + `animate_exit_marker()` looped tween (1340-1346)
   11. `_spawn_floor_blob_shadows()` (461 → 906-957) — **must stay after all dressing**; it reads live StaticBody3D footprints
2. `_style_results_panel()` (66), PortraitHint mount (69), optional VirtualPad (72-78)
3. Mouse capture + `InputPrefs.refresh_cache()` (82-85)
4. `_spawn_player()` (86 → 1880-1898) — local chair, respawn checkpoint
5. `_apply_player_modifiers()` (87), `_maybe_spawn_ghost()` (88 → 970-997), `Accessibility.apply_time_scale()` (91)
6. `PreMatchModal.mount(...)` (94-98) — **pauses the whole tree inside mount (scripts/PreMatchModal.gd:44)**; unpauses on dismissal (PreMatchModal.gd:189)
7. `_start_countdown()` (99 → 1902-1925) — sets `match_state`, freezes chair, mounts ControlsOverlay + CountdownOverlay. Timer only ticks after unpause (`_process` gated by pause).
8. `_setup_hud()` (100 → 2213-2244) — HUD.gd CanvasLayer, SubtitleOverlay mount, ChatOverlay (LAN), MobileControls
9. Camera fov, chair signal connects (101-108), `_connect_race_triggers()` (109 → 148-159)
10. PanicCam mount (113-115), Network signal wiring + replay of already-connected peers — remote chairs instantiated immediately (116-131)

### Known CPU-blocking hot spots inside the chain
- `_ceiling_material()` (Evacuation.gd:1131-1150): 256×256 per-pixel `Image.set_pixel` loop, built inline on first floor.
- `_dusk_window_material()` (1156-1184): 4×64 loop (minor).
- `_make_carpet_material` / NoiseTexture2D per floor (1186-1207); wood noise material cache (1352-1369).
- `BlenderProps.spawn` GLB instantiation at plants/vending/crates/clock (486-489, 586-590, 720-723).
- Flicker fixture discovery does a full `find_children` walk on first `_tick_light_flicker` (1420-1422) — first `_process` frame, not `_ready`, but worth knowing for 1C budgeting.

### Safe batch/readiness boundaries (recommendation, evidence-backed)
- Batch A (base world): steps 1.1–1.3 + 1.6–1.7 (floors, walls, ceilings, lights, environment, columns, elevators). No cross-dependencies on later batches.
- Batch B (dressing): 1.4 + 1.5 (themes, hazards node). Themes only need `LevelLayouts.current_layout()` (already resolved — see LAN risk below).
- Batch C (gameplay props): 1.8–1.11 (obstacles, powerups, exit marker, blob shadows). Blob shadows MUST run after B and C dressing; powerups before HUD so minimap/pickup sync names exist.
- Readiness boundary: everything above must complete BEFORE `_spawn_player()` (86) and certainly before `PreMatchModal.mount` (94). Countdown authority (`_start_countdown`, 99) must remain strictly after modal mount and after all batches — do not let it start while any batch is pending.
- Ordering invariants that must not break (from comments/tests): blob shadows after obstacles (458-461); floor-3 slab replaced, not added (1011-1019); columns placed against verified lane geometry (871-895); `LevelClearTest`/`CheckpointBotTest` sync floor-3 landings (LevelLayouts.gd:4-6, LevelClearTest.gd:17-19,78-86).

### LAN / briefing readiness risks
- **Tree pause vs deferred batching:** `PreMatchModal.mount` sets `get_tree().paused = true` (PreMatchModal.gd:44). Any deferred-batch mechanism that relies on `_process`, tweens, or node timers will stall under pause unless nodes use `PROCESS_MODE_ALWAYS`. (`SceneTree.create_timer` defaults `process_always=true`; tween/node processing follows pause mode.) Sequence batches → mount modal → start countdown.
- **Layout authority timing:** LAN layout is delivered by `Network.begin_match(layout)` → `_apply_authoritative_layout` (scripts/Network.gd:376-405). `_setup_arena` reads `LevelLayouts.current_layout()` at 469-472, 571-573, 732-735, 1756-1758. If 1C defers any themed batch past the first frame, a late `set_current` could race the read. Layout must be pinned before Batch A starts.
- **Late-join/peer replay:** `_ready` lines 129-131 iterate `network.connected_players` and spawn remote chairs immediately. If player spawn or arena batches are deferred, remote chairs could arrive before routes/obstacles exist. Gate remote-chair spawning behind the same readiness signal.
- **Countdown must stay gated:** `player_ready_changed` / `all_players_ready` / `start_match` exist (Network.gd:30, 355-373); nothing in Evacuation currently waits on them for the local countdown — countdown starts purely from `_ready` order. A readiness service should wrap step 7, not change `Network` readiness semantics.
- **Host-loss path** already exists (`_on_host_lost`, 135-141) and captions + returns to menu; keep it wired after readiness too.

---

## 2. Workstation integration, floor culling, route-safe bays (Phase 2)

### Integration hooks (existing, verified)
- **Culling registration:** `_register_floor_node(floor_index, node)` (Evacuation.gd:1479-1482). Used by ceiling lights (1375), columns (900), elevator portals (1706), blob-shadow groups (957). `_update_floor_culling()` (1484-1502) hides whole groups ≥ `CULL_HIDE_DISTANCE_FLOORS`=2 away and drops OmniLights on the adjacent floor via `_set_floor_lights_enabled` (1504-1513). Floor index derives from `local_player.global_position.y / 6.0` (2255-2258). **Any workstation/worker group must call `_register_floor_node` with the matching floor or it will never cull.** Note: hidden nodes still run `_process` — seated-worker animation should additionally gate on the culling state or floor distance (see §4).
- **Blob shadows auto-pickup:** `_spawn_floor_blob_shadows` reads every StaticBody3D child with a CollisionShape3D (906-957); skips boxes with `size.x > 4.0` and radii outside 0.4–3.6 (928-940). A 2.4 m workstation desk with a ≤4 m box collider gets a shadow automatically if added before this runs — i.e. workstation spawning must happen before step 1.11 (or blob shadows re-run).
- **Shared materials:** `OfficeDressing` static `_mat` cache (OfficeDressing.gd:33-41, `clear_cache()` at 41), `beveled_box` mesh cache (25, 52), `column()` (208), `monitor()` (377), `desk_dressing()` (525). New workstation builders should follow this static-cache pattern.
- **Layout plumbing:** add per-layout fields to the `base` dict in `LevelLayouts.get_layout` (LevelLayouts.gd:44-80) and to every layout branch; `current_layout()` is read in four places in Evacuation (see §1). The file's own procedure requires a point-in-rect verification per new layout entry (LevelLayouts.gd:10-15) and `LevelLayoutSmokeTest` name registration (15).

### Route-safe geometry constraints (all layouts)
- Floor slab 40×40 m; walls at ±20 (0.3 thick, inner face ±19.85) — Evacuation.gd:1047-1077.
- Floor-1 cubicle grid: partitions 5.4×0.8×0.25, long in X, at every (8·gx, 8·gz), gx/gz ∈ −2..2, skipping the center corridor (`f1_corridor_gap` 0 or 1) — Evacuation.gd:468-489. Corridor for CUBICLE_MAZE (gap=1) is x,z ∈ −8..8.
- Columns 0.7×0.7 at (±10,±10) on solid floors, (±17.5,±17.5) on floor 3 — Evacuation.gd:883-895; column collider 0.7 wide (OfficeDressing.gd:208-216).
- Elevator pads/triggers 4×3×4 at (12,0.5,14), (−12,6.5,−2), (12,12.5,14) (+ destination markers) — Evacuation.gd:451-453, 1644-1651; portal housing ~2.3 m out from pad along the outward normal (1694-1706).
- Floor 3 is voids — **never place desks/workers there** (desks already excluded, Evacuation.gd:1753-1758; traps excluded, 1983-1986).
- Floor 4: ice zone half-extent 26 (EXECUTIVE 34) centered origin (730-739); exit/lot strip z≈10–22 with parked cars at (−12,18) and (4,18), crates per layout (LevelLayouts.gd:53, 62-65, 73-76); exit beam zone at (0, y, 15).
- Floor 2 fixtures: tables at `f2_tables` x, z=0 (571-577); coolers (−12,10),(12,10),(0,−12) (579-582); vending (±17,∓17) decorative (586-587); tile slick zone 10×6 at (0,8) (592-594); carpet 8×8 at (−10,−8) (595-597).
- Deterministic RNG placements that bays must be checked against: desks `obstacle_seed` 1337/4242/909, counts [5,5,5]/[3,6,6]/[2,2,8], range 15/15/16, y ∈ {0.5, 6.5, 18.5} (1753-1777, LevelLayouts.gd:44-80); powerups seed 999, count 8/10/6, ±12, four floor heights (1836-1854); traps seed 4242 (1987-2004). **Audit limitation:** these RNG outputs were not hand-simulated (doing so offline would risk inventing numbers). Any fixed bay coordinate must be validated with a headless probe (point-in-rect vs desk positions per the three seeds) before commit — this is the same verification LevelLayouts.gd:11-15 already mandates.

### Recommended bays (2.4×2.4 m footprint, plan-spec desks; y = slab top +0)
Occupied (with NPC worker) — floor 1 (y=0, solid slab):
- **Bay 1: center (−12, 0, −12), desk facing +Z** — clear of cubicle rows z=−8/−16 (partition slabs span z −8.125..−7.875 and −16.125..−15.875; bay z −13.2..−10.8), clear of column (−10,−10) (spans −10.35..−9.65), outside both corridor variants (x<−8), clear of plants (±4,±14) and elevator pad (12,14). Seated occupant faces the desk back toward the SW quadrant; ~4 m clearance to nearest corridor mouth.
- **Bay 2: center (14, 0, −12), desk facing −Z** — clear of partitions at x-grid z=−8/−16, clear of column (10,−10), inside walls (x ≤ 15.2 < 19.85), far from pad (12,14) and start slots (START_SLOTS all within x −7.5..7.5, z 0..6, Evacuation.gd:1861-1865).

Quiet (desk only, no NPC) — floor 2 (y=6, solid slab):
- **Bay 3: center (−16, 6, 8)** — clear of cooler (−12,10), tables (z=0 line), tile zone (x −5..5), carpet (x −14..−6, z −12..−4), columns (±10,±10), elevator portal at ≈(−14.3,−2.4).
- **Bay 4: center (16, 6, −8)** — clear of column (10,−10), vending (17,17), coolers, both surface zones, pads at (∓12,−2).

All four avoid every explicitly-authored fixture in all three layouts; the only residual check is the seeded desk/powerup RNG overlap noted above. Dimensions per plan: partition 1.25 m tall × 0.08 thick, footprint 2.4×2.4 — comfortably under the 5.94 m ceiling (Evacuation.gd:1119-1124) and under the blob-shadow size.x ≤ 4 cull-friendly threshold. Keep `size.x ≤ 4.0` on the desk collider or it silently loses its contact shadow.

---

## 3. Inventory / powerup APIs, host-authority gaps, input binding (Phase 4)

### Actual inventory API (PlayerChair.gd — foreign file, read-only)
- State: `item_kind: StringName` (`&"none"`, `&"stapler"`, `&"spill"` only), `item_charges: int`, `item_ready: bool`, `item_cooldown` — PlayerChair.gd:76-78.
- `give_item(kind: StringName, charges: int)` — replaces any held item, sets ready — PlayerChair.gd:1145-1157. Called by pickups: `body.give_item(&"stapler", 3)` / `(&"spill", 2)` (PowerUpVisual.gd:410-414). **No capacity model** (only one item slot), no authority gate, callable by anyone with the node reference.
- `_use_item()` — consumes one charge, fires stapler bolt or drops spill trap; zeroes to `&"none"` — PlayerChair.gd:1160-1197. HUD reads `item_kind/item_charges` (Evacuation.gd:2026; HUD.gd:290 `set_item`).
- Powerup kinds: `Kind { COFFEE, ENERGY_DRINK, STAPLER, SPILL, PRINTER, EXTINGUISHER }`, weights 60/15/10/8/4/3 — PowerUpVisual.gd:7-17. Boost-granting kinds apply `body._start_boost()` locally (PowerUpVisual.gd:398-408). Factories: `PowerUp.create(kind)` / `pick_weighted(rng)` (54-97). Cross-peer despawn identity: `sync_name` (43, 66-67), reported via `Network.report_pickup_taken(sync_name)` (506-509).
- Contract test that pins this API: scripts/PowerUpSmokeTest.gd:66-85.

### Host-authority gaps that MUST be closed before trades
1. **Clients self-grant.** `_collect()` applies boosts/items entirely on the collector's machine (PowerUpVisual.gd:385-428) and `give_item` mutates local state unconditionally (PlayerChair.gd:1145). A trade that reuses this path lets a client grant itself any powerup. Trades need a host-validated request/response RPC pair; the host must perform the atomic consume+grant and echo the new inventory.
2. **Pickup sync is trust-the-client despawn only.** `report_pickup_taken` → `submit_pickup_taken` (any_peer) → server relays (Network.gd:531-548). No validation of proximity, round state, or item identity. Acceptable for world pickups; not for inventory-affecting trades.
3. **No idempotence/rate limiting anywhere.** Existing RPCs are fire-and-relay; there is no request-id or dedupe. PLAN.md requires request-id idempotence + rate limiting — must be built new in `OfficeTradeService.gd`.
4. **No late-join world-state snapshot for items.** Precedents to copy: `request_roster`/`send_roster` (Network.gd:407-418) and `request_match_state`/`confirm_match_state` (384-392). Worker stock + trade results need an equivalent host-pushed snapshot on join/rematch (`_on_rematch` is a plain `reload_current_scene()`, Evacuation.gd:2172-2173 — per-round worker stock resets naturally only if the host also resets its service).
5. **Remote stun precedent is the wrong model for grants.** `report_remote_stun` lets the victim's client apply the effect locally (Network.gd:553-575, Evacuation.gd:392-400) — fine for stuns, wrong for inventory (see gap 1).
6. **Inventory is not replicated at all.** Remote chairs mirror position/velocity/rot only (Network.gd:479-500, Evacuation.gd:351-360). Trades will need at least a cosmetic carry-item state per peer, host-authoritative.
7. **Disconnect handling:** `player_disconnected` + roster cleanup exist (Network.g:24, 134-135); the trade service must refund/void in-flight requests on it.

### Input map and a conflict-free interaction binding
Existing actions (project.godot:40-115):
- `move_forward/back/left/right` — WASD + arrows + left stick
- `boost` — Space, joy 0 (A/Cross), left mouse button (project.godot:70-76, button_index 1).
- `action` — **E**, joy 2 (X/Square), MMB (77-83) — this is jump/grab (PowerUpVisual.gd:339), NOT trade; plan's "E is jump" concern confirmed
- `sabotage` — Q, joy 1 (B), LMB (84-90)
- `pause` — Esc, joy 6 Start (91-96)
- `camera_left/right` — right stick axis 2 + buttons 9/10 + dpad 13/14 (98-109)
- `recenter_camera` — R, joy 3 (Y/Triangle) (111-115)

Recommended new `interact` action (remappable):
- Keyboard: **physical F** (F/G are unused; all mouse buttons are taken).
- Gamepad: **binding unresolved**. Parent source review rejected the audit's original recommendation: button 9 is already bound to `camera_left` and 10 to `camera_right` (project.godot:101,107). Their absence from DEFAULT_PAD_MAP does not make them unbound. Resolve against the complete live InputMap, including UI actions, before assigning an interaction button; test collision fencing explicitly.
- Wiring requirements: add to `DEFAULT_PAD_MAP` and `KEY_FALLBACK_NAMES` (InputPrefs.gd:63-70, 659-666) so labels work; use `InputPrefs.set_key_binding` / `set_pad_binding` (577, 620) which already do conflict fencing + swap via `_fenced_conflict` (527); persist via `save_bindings` (502).
- Touch: no spare key — precedent is auto-collect for touch in PowerUpVisual (`_on_body_entered`, 342-357). **Trades must NOT auto-fire on touch** (plan: deliberate press); the pattern to use is an on-screen button routing through `trigger_mobile_action` (MobileControls → Evacuation.gd:2250-2252 → chair). Verify MobileControls supports a new action name before committing.

---

## 4. Caption / reduced-motion / culling hooks for seated NPC animation (Phase 3)

- **Captions:** `Accessibility.caption(text, duration)` — static, gated by the `subtitles` setting, routes to any node in group `caption_overlays` with `show_caption` (Accessibility.gd:79-88). `SubtitleOverlay` is mounted on the HUD in every match (Evacuation.gd:2228-2230), joins `caption_overlays`, and **replaces any in-flight caption** via a token (SubtitleOverlay.gd:6, 51-66) — this gives the plan's "one short caption at a time" behavior for free; NPC code only needs the `SPEAKER: line` format and its own cooldown/repeat suppression + cleanup on `_exit_tree`. Do not create a second overlay.
- **Reduced motion:** `Accessibility.reduced_motion_enabled()` (Accessibility.gd:96-97); existing consumers: camera roll gate (Evacuation.gd:269-271) and screen shake (307-311); flashes separately gated by `flash_effects_enabled` (93-94, used PowerUpVisual.gd:457-460). Seated NPC idle must return to a neutral pose when `reduced_motion_enabled()` is true (per plan §3); check it once per state change, not per frame (config reads load a ConfigFile — `_cfg()` at 28-31).
- **Culling:**
  - Register each workstation+worker group with `_register_floor_node(floor_index, group)` (Evacuation.gd:1479) — visibility culling then handles floors ≥2 away automatically, matching the plan's "animate only current/adjacent floors."
  - `_update_floor_culling` only flips `visible`; `_process` still runs on hidden nodes. Worker animation should early-out unless its floor is within `CULL_LIGHT_DISTANCE_FLOORS` (1477-1502 constants at 53-54) — derive via the same `int(y/6.0)` logic as `_current_floor_index` (2255-2258), using the worker's own y, not the player's node distance.
  - Keep workers out of StaticBody3D-with-box-collider footprint so `_spawn_floor_blob_shadows` (906-957) doesn't generate stray shadows from NPC colliders (they shouldn't have any — workers are decorative, integrated through the workstation controller, not player physics).
  - No decorative replication packets: workers are local-only; nothing in Network.gd carries them (verified — only player state, traps, pickups, stuns, chat, roster, readiness RPCs exist).

### Cross-cutting test obligations (existing ladder that must stay green)
- `LevelClearTest.gd` (waypoint route incl. floor-3 connector at (0,12.5,14), LevelClearTest.gd:81-86) and `CheckpointBotTest.gd` — new furniture must not narrow the route these bots drive.
- `FloorCullingTest.gd` asserts all four floors registered in `_floor_groups` (FloorCullingTest.gd:39-46) — new groups extend, never replace.
- `PowerUpSmokeTest.gd:66-85` pins the `give_item`/`_use_item` contract any trade service must respect.
- `LevelLayoutSmokeTest` must list any new layout fields (LevelLayouts.gd:15).

### Honest limitations of this audit
- Static code reading only: no Godot run, no screenshot, no frame measurement, no RNG simulation of seeded desk/powerup placement. Bay coordinates in §2 are derived from all explicitly-authored geometry but the seeded-RNG overlap check is explicitly deferred to the mandated headless probe.
- PlayerChair.gd is foreign uncommitted work; its inventory API was read but is subject to change by its owner before Phase 4.
- No LAN two-peer experiment was run; all multiplayer claims cite RPC source only.
