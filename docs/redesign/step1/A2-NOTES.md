# A2 preset remap plan (GLM implementation notes, 2026-09-14)

Binding spec: docs/redesign/step1/PRESETS.md (Astra). Supersedes the
LOW/MEDIUM/HIGH fog/glow/vignette ladder and the filmic "office at night" grade.

## Current state
- Settings.gd: LOW(0)/MEDIUM(1)/HIGH(2) OptionButton; _apply_graphics_quality
  gates fog/glow/vignette (q>0), omni shadows (q>=2), dust motes (q>0).
- Evacuation.gd _setup_environment: ambient 0.62/0.74/0.90 @0.50, key warm
  @0.78, filmic tonemap white 6.0, fog/glow configured-off but quality-gated,
  vignette quality-gated, dust motes quality-gated.
- Persisted: user://settings.cfg graphics/quality int 0..2 (default 1).

## Target per PRESETS.md
- Presets renamed: STANDARD / ENHANCED (+ Android export preset later, D3 lane).
- Persisted value stays an int (0=Standard, 1=Enhanced) with migration:
  old 0 -> 0 (Standard); old 1,2 -> 0 (Standard default; Enhanced is opt-in).
  Rationale: Enhanced only adds resolution/cap/filtering/sharpness, and cfg
  default must be Standard (plan v2: Standard is THE default).
- Environment (both desktop presets, from §2/§3 matrix):
  fog OFF, glow OFF, vignette OFF, SSAO/SSIL/SDFGI/SSR never enabled,
  tonemap LINEAR (was filmic), exposure 1.0.
  Ambient #B8CDD2 @ 0.45 (was 0.62/0.74/0.90 @ 0.50).
  Key #F2C66D @ 1.0, elevation 30°, direction (+0.75,-0.50,-0.43) normalized
  (Evacuation/Hauled/Pizza; ShopSeek key #F3E7D3 @ 0.65 — its own mode file).
- Directional shadow (§4): 2048 map, 2 cascades, max distance 28, blend on,
  fade 0.80, bias 0.05 / normal 1.0 (Enhanced: 4096, Medium PCF; Standard Low PCF).
- Omni/spot shadows OFF on ALL presets (was q>=2 enabled them).
- Dust motes: desktop pool 24 (§8) on both presets (decorative motes are
  a fixed pool, not a quality gate).
- _quality_allows_post() retires: post-processing is always off now.
- Differences Standard vs Enhanced: frame cap 30 vs 60, aniso 4x vs 8x,
  shadow map 2048 vs 4096, PCF low vs medium, default output 720p vs 1080p.

## Fairness (§9)
- No preset removes hiding cover; quality never changes geometry.
- Shop & Seek: directional shadows off on every preset (separate slice —
  touches ShopSeek.gd key light; do it with the S&S dressing pass).

## Tests to update/add
- SettingsRoundTripTest: quality round-trip still byte-stable after migration.
- GraphicsPassSmokeTest: assert fog/glow/vignette disabled, tonemap linear.
- Add: preset label test (STANDARD/ENHANCED in OptionButton).
