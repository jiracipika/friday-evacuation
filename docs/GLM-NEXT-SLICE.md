# Next Development Slice — Friday 5PM: Evacuation

Status: implementation-ready handoff
Branch: `main` at `fed08a0` (Phase 8A chair skins)
Godot: `/usr/local/bin/godot` 4.7.1

## Current verified baseline

Phases 1–7 complete in software. Phase 8A shipped this session:

- 6 chair skins (`scripts/ChairSkins.gd`) unlocked by career wins
  (0/1/3/5/10/25), each with stat multipliers (jump/friction/boost)
  applied once in `PlayerChair._ready()`.
- Variant chassis builders in `PlayerChair._build_chair_model()`;
  riders mount via the shared path with per-skin `seat_rise`.
- The Throne boosts with the new procedural "flush" sfx (AudioManager).
- Menu CHAIR dropdown with LOCKED rows, multiplier readout, next-unlock
  progress; persisted `identity.cfg player/skin`.
- `_end_race` announces fresh unlocks on the results panel.
- `ChairSkinSmokeTest.gd` (132 checks) in the ladder → 35 suites green.

## Remaining software slices

1. **Phase 8B colorblind support** — power-ups/traps need distinct
   SHAPE cues, not just color. Touch points: `PowerUpVisual.gd`
   (add per-kind silhouette toppers), `SabotageTrap.gd`,
   `Accessibility.gd` (`colorblind_mode` setting + Settings toggle).
2. **Phase 8B game speed** — `Accessibility.get_time_scale()` exists;
   verify a Settings slider actually drives `Engine.time_scale` and
   that race timers scale consistently (add a round-trip test).
3. **CheckpointBot per-skin sanity (optional)** — one bot run per skin
   id to prove no chassis breaks traversal (ball/beanbag change
   friction/jump enough to matter).

## Hardware QA (unverified, needs real devices)

- PLAYTEST.md session 1: now includes the chair-skins feel checklist
  (per-skin drive feel, flush sfx, unlock celebration on a real win).
- Session 2 controller QA, session 3 phone touch via Vercel build,
  session 4 two-machine LAN + hotspot (layout sync ships in the
  match payload — verify on real peers).

## Guardrails

- `git pull --ff-only` before work; commit directly to `main` only
  after the full serial ladder passes (`bash scripts/run_ladder.sh`).
- Never run two implementation sessions against this working tree.
- Keep `FLOOR3_LANDINGS` synchronized across Evacuation, LevelClearTest,
  and Hazards.
- Skins apply in `PlayerChair._ready()` — anything that spawns a chair
  with `use_global_skin = true` inherits the local player's pick
  (remote chairs currently use defaults; leave unless doing skin sync).
- Ladder now 35 suites; `ChairSkinSmokeTest` must stay in
  `scripts/run_ladder.sh` and BootTest.
