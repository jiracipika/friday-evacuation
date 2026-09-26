# GLM-NEXT-SLICE — for GPT-6 Astra

Repo: jiracipika/friday-evacuation (private). Base: the graphics pass
(435fa66) + this menu/UI slice. Read SKILL-level handoff at the bottom of
this doc; it lists every trap hit so you start ahead.

## Where the base stands

- Rendering: Godot 4.7.1, GL Compatibility renderer, 100% procedural
  geometry/materials (no external assets, and that's a feature — mobile
  download size is tiny). Filmic tonemap, per-floor material caches with
  normal maps, floor culling, quality presets LOW/MED/HIGH all exist.
- Architecture is now enclosed: 5.98m walls, real ceilings, troffer light
  panels at ceiling height, columns, elevator portals with EXIT signage,
  contact blob shadows under every prop (no SSAO in compat — discs are the
  SSAO substitute; don't add more real-time shadow casters, see traps).
- Players: riders have neck/hem/arms/mug; chairs have rounded backrests
  with an emissive player-color halo ring. All collision untouched.
- Menu is fully responsive: 390px portrait fits (menu min width 305px),
  desktop unchanged. PortraitHint gates in-match portrait play.
- Ladder: scripts/run_ladder.sh, 43 suites, all green.

## Where to polish (suggested order, biggest win first)

1. IN-GAME 3D FOLLOW-THROUGH — the menu got the design pass; the HUD is
   next: give HUD.gd the same treatment as UITheme (shared StyleBoxFlat
   tokens, consistent radii, the orange identity). ResultsPanel in
   Evacuation.tscn is still fixed 600x400 — make it shrink-to-fit
   (anchors + max size) and restyle with UITheme.
2. LIGHTING ART DIRECTION — omni intensity/range is uniform today. Try:
   warm pools near exit signage and power-ups (add small range OmniLights
   ONLY where culling already keeps them: same floor group), a slightly
   cooler tint on the stairwell floor, one flickering troffer per floor
   with a matched OmniLight pulse (currently flicker is emissive-only).
   Verify with movie frames, keep LOW profile identical (quality gate in
   Settings._apply_graphics_quality).
3. PROP VARIETY — OfficeDressing.monitor() has 3 screen variants; add a
   few more desk/lounge props (printer, box stacks, wall clock via
   Label3D, whiteboard in conference area). Keep them non-colliding or
   validate against checkpoint waypoints (CheckpointBotTest will catch
   blockers). PropMaterials.gd has wood/brushed-metal/plastic to reuse.
4. FLOOR 2/4 DRESSING PARITY — floor 1 has partitions + plants; floors
   2/4 are sparse (tables + coolers). Add water cooler props near
   conference tables, plants by windows (they read great against the
   dusk bands), maybe cable trays on the ceiling.
5. MENUBACKDROP/story — MenuBackdrop.gd draws a static-ish skyline;
   parallax it with menu_time (2 layers, slight hue drift) — cheap,
   menu-only.

## Traps (all hit the hard way this session)

- Container min width: a Control refuses to shrink below
  get_combined_minimum_size(). Responsive = minimize children min widths
  (wrap labels, ellipsis clip details, HFlowContainer for button rows,
  short dropdown items at narrow widths). MenuLayoutSmokeTest pins this.
- cast_shadow: any thin/ceiling geometry MUST set
  SHADOW_CASTING_SETTING_OFF or the tilted key light paints long stripes
  across the floor. Blob shadow discs too (they ARE shadows).
- Texture sine bands alias to moiré at gameplay distance: no high-freq
  sines in albedo textures; keep amplitudes <= ~7%. Carpet tile grid +
  grout normal map is the structure that survives mips — don't reintroduce
  per-pixel streaks.
- Shared cached materials: NEVER tween material_override directly on a
  node that shares a cached material — duplicate() first
  (_tick_light_flicker pattern).
- canvas_items stretch divides by content_scale_size; if you resize the
  window in a test, set win.content_scale_size to match or anchors
  resolve against a stale design size (LayoutProbe/MenuLayoutSmokeTest
  show the dance).
- --write-movie forces the PROJECT window resolution; to QA a phone
  portrait frame, temporarily edit project.godot viewport_width/height,
  capture, restore (never commit the temporary edit).
- GL Compatibility has no SSAO/vignette on some paths — guard
  environment props with `"prop" in env` checks like _setup_environment
  does.
- GDScript: untyped load() results need explicit types (`var x: GDScript
  = load(...)`), int params are pass-by-value (use Array accumulators),
  heredoc-inserted GDScript tends to mangle indentation — use write_file.
- Movie-mode vision QA can mislead: verify artifacts with pixel stats
  (strip luminance stdev) before changing rendering code. The stripe bug
  was in the textures, not the shadowmap — only the shadow-off A/B proved
  it.

## Verification ladder (run before you claim anything)

bash scripts/run_ladder.sh   # 43 suites, must be all green
godot --headless --path . --quit-after 3   # boot: 0 script errors
For visual changes: --write-movie frames + look at them (see skill for
the harness pattern), desktop AND 390-wide portrait (edit project.godot
temporarily). Commit + push only after the ladder is green.

## Out of scope for you (user-owned)

- Do not touch pitch-therapy/pitchforge (excluded project).
- Real-device QA (Android/iPhone touch feel) needs the user's hardware.
- Two-machine LAN QA same.

## DONE (2026-09-26 late session): texture-generation cost creep — OPTIMIZED

The queued floor/partition generator optimization shipped: hoisted the
per-pixel exp/pow lane term + 16-value tile hash out of FloorMaterials'
albedo loop, replaced 262k per-pixel set_height calls with 24 fill_rect
calls (floor grout) and ~43 (partition ribs/beats), and hoisted row
bases in NormalMapGen.normal_texture. Output verified BYTE-IDENTICAL
against pre-change reference buffers (albedo + floor normal + partition
normal). Same-thermal-window A/B: full-suite generation 11.4s ->
7.3s; the smoke test now asserts a THERMAL-ROBUST RATIO (generation vs
in-process bare-Sobel reference, < 16x; shipped ratio ~11.5x, old code
~20x) instead of absolute wall-clock. GOTCHA for future hoisting: do
NOT park hoisted float factors in PackedFloat32Array — 32-bit rounding
flipped final 8-bit texel quantization on 2 of 262k pixels; use plain
Array (64-bit).


The cold-boot normal/albedo generation measured ~3.0-3.8s at the fd8df79
baseline and now measures 7.1-9.0s (NormalMapSmokeTest budget raised
5s -> 12s with the history in its comments; caches make it one-time).
Profile on this machine: FloorMaterials.make ~1.3-1.6s PER FLOOR
(4 floors), WallMaterials.make_partition ~600-680ms (3 variants),
wall_normal ~250-490ms. The creep came from intentional art changes
(282aca5 partition 16px felt ribbing, 3ba893c resolution-scaled normal
strength) multiplying per-pixel set_height() traffic. Suggested win:
regenerate floors via the NormalMapGen set_height fast path only for
non-flat pixels (pre-fill + skip flat), or halve floor texture
resolution with uv1_scale compensation. Target: back under 5s total
without changing rendered pixels.
