# Appearance presets and construction allocations

Authority: Astra. Binding parent: [plan v2](../REDESIGN-PLAN-v2.md), sections 2 and 5.
Desktop: Godot 4.7 Forward+. Android: Godot 4.7 Compatibility only.
GLM aligns the installed patch and matching templates during implementation.
This is a content-construction specification, not evidence of measured performance.
No benchmark, timing route, thermal session, or performance release gate is prescribed.

## 1. Product contract

Standard is the complete default experience for RX 580 8 GB + i5-8400.
Its presentation target is 1280 × 720 at a 30 FPS cap.
Enhanced changes resolution, cap, filtering, and shadow sharpness only.
Android preserves identity and gameplay cues through simpler rendering.
Preset selection does not change collision, simulation, player capacity, or network behavior.
Keep current mode plus shared assets resident; unload the previous mode.
The 8 GB device specification is not an 8 GB texture budget.
Do not make the default look deliberately incomplete to sell Enhanced.

## 2. Exact feature matrix

| Feature | Standard | Enhanced | Android |
|---|---|---|---|
| Renderer | Forward+ | Forward+ | Compatibility |
| Default output | 1280 × 720 | 1920 × 1080 | Native landscape viewport |
| 3D internal scale | 1.0 | 1.0 | Fit longest edge ≤1280, retain aspect |
| Default frame cap | 30 | 60 | 30 |
| Dynamic resolution | Off | Off | Off |
| FXAA | On | On | Off |
| MSAA | Off | Off | 2× |
| TAA | Off | Off | Off |
| Anisotropic filtering | 4× | 8× | 2× |
| Mipmaps on 3D textures | On | On | On |
| Texture filtering | Linear mipmapped | Linear mipmapped | Linear mipmapped |
| SDFGI | Off | Off | Off |
| SSR | Off | Off | Off |
| Volumetric fog | Off | Off | Off |
| SSAO | Off | Off | Off |
| SSIL | Off | Off | Off |
| Conventional depth fog | Off | Off | Off |
| Glow/bloom | Off | Off | Off |
| Auto exposure | Off | Off | Off |
| Exposure multiplier | 1.0 | 1.0 | 1.0 |
| Tonemapping | Linear, fixed | Linear, fixed | Linear, fixed |
| Color grading LUT | Off | Off | Off |
| Motion blur | Off | Off | Off |
| Gameplay depth of field | Off | Off | Off |
| Menu depth of field | Off | Off | Off |
| Chromatic aberration | Off | Off | Off |
| Vignette | Off | Off | Off |
| Dynamic directional key | On, one | On, one | On, one unshadowed |
| Directional shadow | On except Shop & Seek | On except Shop & Seek | Off |
| Shadowed local lights | Off | Off | Off |
| Decorative live local lights | Off | Off | Off |
| Baked static indirect | On for matching fixed layouts | Same data | Same fixed-layout result |
| Baked character probes | On where available | Same data | Matching supported baked ambient path |
| Arbitrary-layout ambient fallback | On when no valid bake | Same | Same |
| Reflection probes | Static/baked only | Same captures | Off |
| Sky reflection fallback | Static environment | Same | Static low-detail environment |
| Dynamic probe updates | Off | Off | Off |
| Contact substitutes | Unbaked contacts only | Same | On where no baked contact |

Off means disabled, not hidden behind an automatic quality heuristic.
Android FXAA is off explicitly; its approved edge treatment is 2× MSAA.
UI renders at viewport resolution and does not inherit 3D internal downscaling.
Android internal sizing never stretches one axis independently.
Users may choose desktop resolution/cap separately without changing the appearance rules.
Do not expose expensive effects as Enhanced defaults.
If an exact setting is unavailable in the installed patch, GLM maps the visual intent to supported controls.
An unsupported setting does not authorize a visually different effect.

## 3. Key and ambient configuration

Evacuation/Hauled/Pizza key is #F2C66D, energy 1.0.
Shop & Seek key is #F3E7D3, energy 0.65.
Key elevation is 30° in every preset.
Default travel direction is (+0.75, -0.50, -0.43), normalized on application.
Procedural ambient is #B8CDD2, energy 0.45.
Matching baked-layout ambient is #B8CDD2, energy 0.20.
Use the same color/exposure inputs on all presets.
Emission surfaces do not create real-time indirect light.
Ceiling diffuser emission multiplier is 0.60, color IVORY.
Screen/indicator emission multiplier is 0.35, using its palette swatch.
Route and danger markers have no emission requirement for readability.
No real-time omni or spot light is added for a pickup, chair, or sign.

### Fixed procedural assemblies

A procedural builder may generate a reproducible fixed layout for asset preparation.
Bake that exact assembled layout, including its final static occluders.
Each approved layout variant receives its own bake and matching layout identifier.
Static geometry must have suitable lightmap UVs and stable transforms.
Do not assign lightmaps by story number alone.
A furniture seed change invalidates affected room-dependent lighting.
Probe placement follows the actual traversable volume, including each story and transfer landing.
Bake data for one mode is unloaded with that mode.
Android uses a supported display path for prepared lighting, with no runtime baking.
GLM may prepare the bake with the renderer workflow appropriate to Godot 4.7.
This Step 1 delivery neither bakes assets nor runs Godot.

### Arbitrary assemblies

If no exact layout bake exists, use the authored fallback for the entire affected room partition.
Use the vertex-shading multipliers from ART-BIBLE.
Use the unshadowed ambient plus the single direct key.
Do not load an unrelated room bake merely to satisfy a checkbox.
Avoid a bright unbaked room adjacent to a heavily darkened baked one.
Fallback contact substitutes use a shared soft ellipse, INK alpha 0.18 maximum.
The ellipse is attached to the object's ground footprint, 0.008 m above ground.
For moving chairs, shrink the ellipse with altitude and hide above 0.8 m clearance.
No vertical wall receives a horizontal blob shadow.
Static floor contacts with valid baked darkening receive no extra blob.
Shop & Seek uses identical product contact substitutes across all presets.

## 4. Directional shadow specification

| Parameter | Standard | Enhanced | Android |
|---|---:|---:|---:|
| Shadow map size | 2048 | 4096 | 0 / disabled |
| Cascades | 2 | 2 | 0 |
| Maximum camera distance | 28 m | 28 m | 0 |
| Cascade split fraction | 0.35 | 0.35 | Not applicable |
| Cascade blending | On | On | Not applicable |
| Distance fade start fraction | 0.80 | 0.80 | Not applicable |
| Bias | 0.05 | 0.05 | Not applicable |
| Normal bias | 1.0 | 1.0 | Not applicable |
| Angular distance | 0.5° | 0.5° | Not applicable |
| Filter quality | Low PCF | Medium PCF | Not applicable |

Bias values are intended Godot material/light setting inputs, not world-meter offsets.
GLM may correct numerical acne/peter-panning issues while preserving contact and coverage.
Any need to extend shadow distance beyond 28 m returns to Astra.
Only near playable architecture and visible actors cast directional shadows.
Distant atrium shells, small accessories, glass, and effect cards do not cast.
Use simple closed shadow proxy meshes for repeated furniture.
Do not allocate shadows for all four floors merely because their shells are visible.
Baked static indirect supplies the room depth beyond the shadow region.
Enhanced does not add another shadowed light or farther shadow coverage.
Android uses baked/static contact treatment plus moving-character ellipses.

### Shop & Seek override

Dynamic directional shadows are off for the whole Shop & Seek mode on every preset.
Use the same baked/static room shadows and product contact substitutes everywhere.
Stock and disguise copies receive the same product lighting path.
Do not let a dynamic disguise shadow reveal a player where stock has no matching shadow.
Baked shelf shadow shapes and occlusion remain identical across presets.
Reflections in this mode contain architecture only, with no player or product identity information.
This override is mandatory even on Enhanced.

## 5. Texture-size assignments

A material set means base color, tangent-space normal, and packed ORM when useful.
Constant channels replace maps where no visible texture variation is needed.
All 3D assignments include mip chains and GPU-compressed imported formats.
The dimensions below are maximum runtime edges, not source art restrictions.

| Asset family from plan section 5 | Standard | Enhanced | Android |
|---|---|---|---|
| Hero worker | One shared 2048 set | Same | One shared 1024 set |
| Hero chair | One shared 2048 set across colors | Same | One shared 1024 set |
| Shared accessories | 1024 atlas | Same | 512 atlas |
| Carpet | Shared 2048 tiling set | Same | 1024 base, 512 normal |
| Plaster | Shared 2048 tiling set | Same | 1024 base, constant normal |
| Laminate | Shared 2048 tiling set | Same | 1024 base, 512 normal |
| Upholstery | Shared 2048 tiling set | Same | 1024 base, 512 normal |
| Repeated furniture | Shared 2048 trim/atlas sets | Same | 1024 trim/atlas sets |
| Groceries | 2048 category atlases | Same | 1024 category atlases |
| Office props | 1024 category atlas; 2048 for copier/trolley | Same | 512 category; 1024 copier/trolley |
| Pizza surfaces | Shared 2048 sets | Same | 1024 sets |
| Major ingredients | Shared 2048 sets | Same | 1024 sets |
| Small/distant dressing | Shared 512–1024 resources | Same | Shared 512 resources |
| UI icons | Vector source; 1×/2× raster export | Same | Vector or display-sized raster |
| World signage | 2048 shared atlas plus geometry | Same | 1024 atlas plus same geometry |
| Menu key art | 2560 × 1440 export | Same source/export | 1280 × 720 export |
| Lightmap page maximum | 2048 | Same bake | 1024 repack/resample |
| Reflection cubemap face | 128 | Same | Probes off |

Small UI glyphs have 24, 32, and 48 px exports, plus 2× equivalents.
No UI glyph is downsampled from an entire menu screenshot.
World arrow silhouettes remain mesh geometry even when their sign atlas gets smaller.
Noto Sans stays font data, not an atlas of English phrases.
Menu art has a source at least 2560 × 1440, per the binding plan.
Do not load desktop and Android menu exports simultaneously.
Shared 2K resources remain shared; color variants do not duplicate the image set.

## 6. Active-mode allocation ceilings

Standard maximum active-mode texture/lightmap allocation is 2 GiB = 2048 MiB.
Enhanced shares that ceiling; it does not load larger texture families.
Android design ceiling is 512 MiB for the same accounting scope.
All values below are imported resident allocations including mip chains.
Unused allocation remains reserve; it does not demand more textures.

| Residency bucket | Standard/Enhanced MiB | Android MiB |
|---|---:|---:|
| Shared worker/chair/accessory sets | 128 | 32 |
| Shared UI/fonts/signage | 64 | 24 |
| Current-mode surface materials | 384 | 96 |
| Current-mode furniture/prop/category atlases | 384 | 96 |
| Current-mode lightmaps and probe data | 512 | 128 |
| Static reflection/sky resources | 64 | 16 |
| Current effects/noise/contact resources | 32 | 8 |
| Import padding and unassigned reserve | 480 | 112 |
| Maximum active allocation | 2048 | 512 |

Menu residency is a separate state, not an extra bucket piled onto a match.
Menu art/preview/UI must fit within 256 MiB desktop or 96 MiB Android.
Release menu-only art before constructing the active-mode texture set.
Mode changes release old-mode material/lightmap references before new-mode residency completes.
The budget does not cover render targets, geometry buffers, driver memory, or simulation data.
Those are reasons not to treat the device's full VRAM as a texture allowance.

### Allocation arithmetic for GLM's manifest

Record imported width, height, layers/faces, mip count, block format, and bytes.
Sum each mip's rounded compressed block count, including small final mip levels.
Multiply cubemaps by six faces and arrays by their actual layer count.
Count a shared resource once, using its canonical resource identity.
Count separate platform imports separately in their platform manifest, not simultaneously.
Count packed ORM once; do not count its three channels as three images.
A 2048² image in an 8-bits-per-pixel block format is about 5.33 MiB with full mips.
A three-map set in that format is about 16 MiB, before format-specific padding.
This example is allocation arithmetic, not a mandated compression format or timing test.
Source PNG/JPEG size is not a valid residency estimate.
No measurement session is requested; use imported resource metadata and construction sums.

## 7. Geometry and visibility allocation

The Standard worst-case visible view is planned at 500,000 triangles or fewer.
Use the same gameplay geometry and LOD thresholds on Enhanced.
Nine-player construction allowance includes host plus eight clients without increasing capacity.
The following envelope assumes four nearest LOD0 actors and five LOD1 actors.

| Visible bucket | Triangle ceiling |
|---|---:|
| Four LOD0 + five LOD1 worker/chair assemblies | 195,000 |
| Current-story architecture and stairs | 75,000 |
| Current-story furniture and gameplay props | 85,000 |
| Adjacent-story simplified furnishings | 35,000 |
| Four-story shells and landmarks | 35,000 |
| Cargo/ingredients/hazards | 35,000 |
| Signs and effect geometry | 10,000 |
| Unassigned reserve | 30,000 |
| Total | 500,000 |

These are visible-scene buckets, not a claim that every mode contains office stories.
Secondary modes reuse the architecture/furnishing buckets for their own terrain and fixtures.
Any nearer-actor overflow uses LOD1 under MODEL-SHEETS priority rules.
Static partitions are room/floor groups; avoid one building-wide MultiMesh group.
Android local actor uses LOD1, other actors LOD2.
Android removes interior bevel loops and tiny hardware while preserving cover silhouettes.
Android decorative geometry ceiling is 180,000 visible triangles including actors.
If Shop & Seek cover cannot fit, reduce hidden interior faces before any outer envelope.
The 500,000 desktop ceiling is maintained by authoring and visibility rules, not a benchmark gate.

## 8. Android material substitutions

Plaster/ceiling omit normal maps and retain broad base-value variation.
Upholstery keeps a 512 normal only for local actor and approached chairs.
Metal uses roughness 0.42 and static sky response in place of reflection probes.
Office glass becomes opaque #B8CDD2 panels with SLATE frames.
Shop freezer panels are already opaque on all presets.
Food surfaces retain color, broad relief, and the same hazard-edge geometry.
Small packaging omits normal/ORM maps together for stock and disguise copies.
Do not replace disguise materials independently of their stock category.
No screen-space contact effect is needed; use the approved baked/ellipse substitutes.

### Effect population

| Pool | Desktop total | Android total |
|---|---:|---:|
| Ground dust cards | 24 | 8 |
| Impact bursts | 16 × 3 ticks | 8 × 3 ticks |
| Pickup rings | 8 | 4 |
| Confetti pieces | 64 | 24 |
| Decorative motes | 24 | 0 |

Shop & Seek suppresses identity-revealing cosmetic effects on every preset.
Existing gameplay projectiles and hazards are not deleted to satisfy a decorative pool cap.
Threat borders, cargo-state icons, and player badges are not optional particles.
No new decorative rigid body or continuously updated reflection is permitted.

## 9. Preset fairness invariants

All presets keep the same gameplay camera FOV and collision occlusion behavior.
All presets keep identical hazard boundaries, route dimensions, and interaction ranges.
All presets keep the same player identity shapes outside disguise rules.
All presets keep the same supported floors, gaps, shelf backs, and product cover.
All presets keep the same object-placement seeds for the same match.
All presets keep the same stock/disguise wobble and material category treatment.
All presets keep essential markers opaque and available when cosmetic pools are full.
No lower preset removes curtains, shelf products, foliage, or geometry that hides players.
No higher preset introduces reflective opponent reveals or extra shadow information.
No brightness setting may selectively brighten player props relative to ordinary stock.
Accessibility contrast changes UI, not competitive world lighting.
LOD changes simplify internal detail and preserve the outer cover envelope.
Android cannot turn a solid stock cluster into separated sparse boxes.
A removed decorative face must be invisible from all valid gameplay sightlines.

## 10. Handoff and acceptance by construction

GLM records renderer, preset feature flags, LOD assignments, and imported resource sums.
GLM records fixed-layout bake identifiers and arbitrary-layout fallback ownership.
GLM preserves mode-unload resource ownership and shared asset references.
GLM identifies any unsupported setting with an equivalent supported implementation option.
Astra decides any appearance-changing substitution.
Standard has no SDFGI, SSR, volumetric fog, SSAO, or SSIL exception.
Enhanced does not become a different art direction.
Android retains complete route, hazard, disguise, and identity information.
No engine invocation, runtime capture, or hardware measurement is required for Step 1 completion.

## 11. Layout bake classification for implementation

| Current layout family | Approved preparation path | Runtime rule until prepared |
|---|---|---|
| Evacuation named layouts | Separate assembled bake per named layout and static modifier combination | Authored fallback |
| Shop & Seek seed 62026 | Bake immutable supermarket shell; product contact handled identically for stock/disguise | Authored fallback for shell and all products |
| Pizza Colony seed 630 | Bake static pizza terrain; claims, forts, chef, and resources remain dynamic | Authored fallback |
| Hauled four terrain kinds | Separate reusable static corridor/terrain assembly per kind; cargo remains dynamic | Authored fallback |
| Any arbitrary seed/layout | No borrowed room bake | Authored fallback |

A fixed seed alone is insufficient if geometry depends on other unrecorded settings.
Record all geometry-affecting inputs in the bake identifier.
Shop product contacts are not baked into the floor as unique silhouettes.
This avoids a moved disguise carrying a shadow inconsistent with the stock treatment.
A previously baked room falls back as a whole if its static input signature changes.
The design approves both paths; GLM does not need to invent a lighting policy for missing data.
