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
