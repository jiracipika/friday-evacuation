# Next Development Slice — Friday 5PM: Evacuation

Status: implementation-ready handoff
Branch: `main` (Phase 8B accessibility — this session)
Godot: `/usr/local/bin/godot` 4.7.1

## Current verified baseline

Phases 1–7 complete in software. Phase 8A (chair skins) and Phase 8B
(accessibility) shipped:

- Phase 8A: 6 chair skins (`scripts/ChairSkins.gd`) unlocked by career
  wins (0/1/3/5/10/25), stat multipliers applied in `PlayerChair._ready()`;
  variant chassis; Throne flush sfx; menu CHAIR dropdown; unlock
  announcements; `ChairSkinSmokeTest.gd`.
- Phase 8B colorblind shape cues: `SabotageTrap.gd` now builds a name
  label ("BANANA PEEL" etc.) + a 32x32 glyph billboard per trap type via
  `_build_shape_cue()` (idempotent, wired into `_apply_visual()`, so all
  spawn paths — random, forced, remote-dropped — get cues). Silhouettes
  are pairwise-distinct: water waves / banana arc / staple U / spill
  droplet. PowerUps already had cues (`_build_label` + `_build_icon_sprite`).
- Phase 8B game speed: `Accessibility.apply_time_scale()` /
  `reset_time_scale()` now DRIVE `Engine.time_scale`. Applied in all four
  mode `_ready()`s (Evacuation, Hauled, ShopSeek, PizzaColony), reset in
  each `_exit_tree()`, and live-applied from Settings `_apply_settings()`
  (pause-menu change works mid-race, no restart). `get_time_scale()`
  returns 1.0 with a network peer, so LAN stays desync-safe; race clock
  ticks on `_process(delta)` so it auto-scales.
- `--test-mode` flag: `Accessibility.TEST_MODE` gates `apply_time_scale()`
  off under the flag (a dev's real 0.75x save can't skew ladder runs);
  `run_ladder.sh` passes `-- --test-mode` to every suite + boot. Test
  suites that exercise the real wiring override `TEST_MODE = false` and
  use an isolated `CFG_PATH`.
- `CheckpointBot.gd`: the traversal harness extracted out of
  CheckpointBotTest (single source of truth). Base bot and per-skin runs
  drive identical steering/assert logic. Bot finishes in ~12s sim.
- `SkinBotSanityTest.gd`: full traversal per skin id (GameManager stub
  with pinned `selected_skin_id` — the real player-pick path) + a
  median-spread check (>2.5x median = regression).
- `Phase8BAccessTest.gd` (40 checks): trap cue presence/labels/32x32
  glyph, pairwise glyph distinctness from the RENDERED texture alpha,
  time-scale round trip + corrupt snap + reset + TEST_MODE guard,
  dead-wiring detectors (mode + Settings call-site greps).
- Ladder now 37 suites (added `SkinBotSanityTest`, `Phase8BAccessTest`).

## Remaining software slices

1. **Skin sync (LAN)** — remote chairs currently spawn with defaults
   (handoff 8A guardrail). Match payload could carry the peer's skin id.
2. **Phase 8C candidates** — anything from PLAYTEST sessions; otherwise
   content polish (GLM pass: artsy FX, more arena props/skins).

## Hardware QA (unverified, needs real devices)

- PLAYTEST.md session 1: chair-skins feel checklist + NEW: game-speed
  slider sanity (0.75x should feel slower across physics AND the race
  clock; 1.25x faster), trap name labels readable at race distance.
- Session 2 controller QA, session 3 phone touch via Vercel build,
  session 4 two-machine LAN + hotspot (layout sync + remote-trap cues
  in the match payload).

## Guardrails

- `git pull --ff-only` before work; commit directly to `main` only
  after the full serial ladder passes (`bash scripts/run_ladder.sh`).
- Never run two implementation sessions against this working tree.
- Keep `FLOOR3_LANDINGS` synchronized across Evacuation, LevelClearTest,
  and Hazards.
- Skins apply in `PlayerChair._ready()` — anything that spawns a chair
  with `use_global_skin = true` inherits the local player's pick
  (remote chairs currently use defaults; leave unless doing skin sync).
- `CheckpointBotTest.gd` must stay in the ladder; keep traversal logic
  in `CheckpointBot.gd` (both suites import it — no copy drift).
- `SkinBotSanityTest` runs 6 full traversals (~2–4 min wall). Keep it
  AFTER the base bot in the ladder order.
- Ladder now 37 suites; `Phase8BAccessTest` + `AccessibilitySmokeTest`
  must both stay in `scripts/run_ladder.sh`.
