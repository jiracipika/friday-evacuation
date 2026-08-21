# Next Development Slice — Friday 5PM: Evacuation

Status: implementation-ready handoff
Branch: `main`
Godot: `/usr/local/bin/godot` 4.7.1

## Current verified baseline

Phases 1–4 are implemented, Phase 5 has a software-verified LAN baseline (real two-machine Wi-Fi QA still required), Phase 6A Hauled is playable, Phase 6B has a complete single-player shopper loop plus multiplayer-ready role/disguise/scan state, and Phase 7A touch controls are wired in all modes.

The latest GPT-5.6 Sol review fixed core playability defects rather than merely polishing scaffolding:

- Corrected reversed camera-relative keyboard input: W now moves along camera forward.
- Replaced additive drift steering with responsive target-velocity steering while retaining reduced boost steering.
- Stationary boost, stapler bolts, traps, spill placement, and idle camera use the visible chair's facing instead of the unrotated CharacterBody3D root.
- Normal traps now remain on the player's current floor instead of teleporting to floor 1.
- Hauled and Shop & Seek share the PlayerChair interaction signal, so keyboard and touch action buttons run the same mode interaction.
- Shop & Seek suppresses ordinary sabotage while Q/touch Trap is a seeker scan, preventing simultaneous scan + trap drops.
- Results now preserve the real player display name instead of always recording `Unknown`.
- Removed unsupported screen-space AA from the GL Compatibility renderer, eliminating the warning on every boot/test.

## Phase 6B — Shop & Seek software baseline

`scripts/ShopSeek.gd` now provides:

- Seven deterministic shelf aisles plus checkout, produce, and frozen sections.
- 24 labeled product props with unique variant IDs and eight primitive shape families.
- Hider disguise entry/exit: two-second freeze, half-speed movement, product replacement visual, and wobble tell.
- Seeker red vest and five-second Q/touch scan cooldown.
- Single-player five-item shopping list, automatic/interactive collection, 60-second failure timer, and a patrolling security guard that stuns and costs time.
- Player-ID role state as the seam for later authoritative replication.
- Honest menu status: `SHOPPER PLAYABLE`, not a false multiplayer-complete claim.

`ShopSeekSmokeTest.gd` verifies the real scene, layout, unique props, list, guard, disguise transitions, movement penalties, seeker vest, scan routing/cooldown, no accidental trap drop, and role state.

## Character content

The existing eight-character roster is now live gameplay content rather than dead metadata:

- Main menu rider selector with persisted identity.
- Eight procedural office-worker riders, character palettes, badges, and named accessories.
- Character visuals mount on the shared chair in every mode.
- Network/lobby player color remains authoritative for chair color; character art no longer overwrites remote color.
- `CharacterRosterSmokeTest.gd` instantiates and verifies all eight unique riders/accessories.

## Verification ladder

Run serially:

```bash
git diff --check
/usr/local/bin/godot --headless --path . --script scripts/BootTest.gd
/usr/local/bin/godot --headless --path . --script scripts/PlayerChairMechanicsSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/CharacterRosterSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/ShopSeekSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/HauledSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/TouchControlsSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/HazardsSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/ThemedFloorsSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/LevelClearTest.gd
/usr/local/bin/godot --headless --path . --script scripts/PowerUpSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/PauseMenuSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/ModeSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/NetworkSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/AccessibilitySmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/RaceModifiersSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/GhostRacerSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/StatsRoundTripTest.gd
/usr/local/bin/godot --headless --path . --script scripts/VisualDesignSmokeTest.gd
/usr/local/bin/godot --headless --path . --quit-after 3
```

## Next coherent slice

Phase 6C — Pizza Colony:

1. Implement real pepperoni ownership and three-/five-second capture/steal progress.
2. Add cheese/topping resources and physics-safe crust-wall placement.
3. Add chef edge patrol, rotating cutter telegraph/hit elimination, and olive bombs.
4. Implement last-player/first-to-five win conditions plus single-player survival fallback.
5. Add a real-scene `PizzaColonySmokeTest.gd` covering capture, economy, attacks, elimination, and win state.

After 6C: Phase 7B exports/device QA, then real two-machine LAN role/authority testing for Shop & Seek and the race.

## Guardrails

- `git pull --ff-only` before work; commit directly to `main` only after the full serial ladder passes.
- Never run two implementation sessions against this working tree.
- Keep `FLOOR3_LANDINGS` synchronized across Evacuation, LevelClearTest, and Hazards.
- Do not label Shop & Seek multiplayer-complete until seeker assignment, catches/infection, authority, and scoring work on two real peers.
- Preserve `MobileControls.mount_for_mode(parent, chair)` as the only direct mobile routing owner.
