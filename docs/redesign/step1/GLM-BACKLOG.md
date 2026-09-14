# Step 1 — GLM Implementation Backlog (living document)

Owner: GLM (implementation/verification). Depends on: `step1/` Astra design
package for all appearance decisions — implement only what Astra specifies.

## 0. Toolchain alignment (done 2026-09-14)

- Godot 4.7.1.stable (brew cask), project features already `("4.7", "Forward Plus")`.
- `project.godot` still sets `renderer/rendering_method="gl_compatibility"`
  and `mobile` fallback. **Action:** flip desktop to `forward_plus` per plan
  v2 section 1; keep a Compatibility profile for Android export only.
  Verify the ladder (43 suites) stays green under Forward+ — texture sine
  bands and shadow-bias tuning were calibrated against GL Compatibility.
- Settings quality model today: LOW/MEDIUM/HIGH option (0/1/2) in
  `Settings.gd::_apply_graphics_quality` gates fog/glow/vignette (q>0) and
  omni shadows (q>=2). Plan v2 renames presets to **Standard / Enhanced /
  Android**. Action: remap — Standard ≈ today's HIGH-with-construction-rules,
  Enhanced adds resolution/FXAA/aniso headroom, Android stays Compatibility.
- Baseline suite: `bash scripts/run_ladder.sh` (43 suites) + boot check
  `godot --headless --path . --quit-after 3` (grep SCRIPT ERROR).

## 1. Asset inventory (current state)

### Procedural geometry (all in scripts/, GDScript-built meshes)
- Core level: `Evacuation.gd` (2,223 ln) — 4 floors, elevators, hazards,
  `_setup_environment` (ambient/dir light/fog/glow/tonemap), blob shadows.
- Dressing: `OfficeDressing.gd` (partitions, plants, printers, coolers,
  columns), `SurfaceLibrary.gd`/`FloorMaterials.gd`/`WallMaterials.gd`
  (procedural textures + normal maps), `PropMaterials.gd` (wood/metal/plastic).
- Modes: `Hauled.gd`, `ShopSeek.gd`, `PizzaColony.gd` (each self-building).
- Actors: `PlayerChair.gd` (1,243 ln — chair + rider, primitive meshes),
  `GhostRacer.gd`, `Roomba.gd`, `MenuHero.gd`.
- FX/props: `ImpactFX.gd`, `PowerUpVisual.gd`, `StaplerBolt.gd`,
  `StunFixture.gd`, `SurfaceZone.gd`, `Hazards.gd`.
- Authored GLBs (6): water_cooler, wall_clock, desk_printer, vending_machine,
  crate, potted_plant (`models/`, imported via Blender headless pipeline).

### Known rendering debts (from 2026-09-12 parent review + plan v2)
- Coarse noisy normal texture on walls; overly dark floor seams (moiré trap).
- Ceiling = flat uniform wash (no light pools); furniture silhouettes primitive.
- HUD scattered; ResultsPanel fixed 600x400 (not responsive).
- All materials procedural `StandardMaterial3D` — no 2K texture pipeline,
  no lightmaps, no reflection probes, no LODs anywhere.

## 2. Dependency-ordered implementation backlog

Order matters; each item blocks the next in its lane. Appearance decisions
(A hex, B proportions) wait on Astra step1 docs; engineering prep can start.

### Lane A — Renderer & toolchain (blocks everything visual)
- A1. Flip desktop renderer to `forward_plus` in project.godot (+ `mobile`
  fallback for future Android), run full ladder, fix fallout (shadow bias,
  material conversions, environment props that were Compatibility-gated).
- A2. Preset remap: LOW/MED/HIGH → Standard/Enhanced (+ Android export
  preset). Standard = SDFGI/SSR/volumetric fog/SSAO/SSIL off, FXAA on,
  4x aniso; Enhanced = those enabled per Astra PRESETS.md.
- A3. Texture import pipeline: 2K hero / shared tiling sets, VRCompressed,
  mip + aniso defaults; document allocation per plan v2 section 5.

### Lane B — Asset authoring pipeline (blocked by A1; design by Astra)
- B1. Blender headless → GLB pipeline hardening (models/ has 6 props; add
  provenance + poly budget checks in export script).
- B2. Worker + chair hero models (Step 2 flagship): authored meshes with 3
  LODs, ≤3 material slots, preserving PlayerChair.gd collision/attachment
  contracts. Replace visual meshes only; gameplay untouched.
- B3. Core office material library: carpet/plaster/laminate/upholstery 2K
  sets replacing procedural textures (keep procedural as Android fallback).
- B4. Room kit + stair kit + atrium shell pieces (Step 3 scope).

### Lane C — Lighting composition (blocked by A1; design by Astra)
- C1. Lightmap bake path: fixed layouts bake per-layout in editor
  (Forward+); procedural layouts get authored ambient + vertex shading.
  Needs a "fixed vs procedural layout" decision per mode from Astra.
- C2. Directional key: one shadowed sun, shadows restricted to nearby
  playable area (plan construction rule); remove per-omni shadows on
  Standard.
- C3. Reflection probes: static probes per room/atrium view.

### Lane D — UI (HUD/Results restyle can start now; layout per Astra)
- D1. ResultsPanel responsive (anchors + max size) + UITheme restyle.
- D2. HUD hierarchy per Astra UI-LAYOUTS.md (objective > state > support).
- D3. Touch layouts (48dp, safe areas) — Android lane, after desktop lock.

### Lane E — Verification
- E1. Keep ladder green every slice; add Forward+ boot smoke to CI script.
- E2. Movie-frame QA harness reuse (UISurveyCapture pattern) for visual
  acceptance evidence at 720p; pixel-stat verification before render changes.

## 3. Open questions for Astra (answer in step1/STATUS.md)

1. Which mode layouts are "fixed" (lightmap-bakeable) vs procedural?
2. Confirm triangle budgets per prop family for B4 kits.
3. Android texture ceiling confirm (512-1K) vs shared 2K sources.
