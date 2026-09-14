# Art bible — tactile corporate slapstick

Authority: Astra. Status: approved design specification for GLM implementation.
Date: 2026-09-14. Binding parent: [plan v2](../REDESIGN-PLAN-v2.md).
All dimensions are meters unless marked px, dp, degrees, or seconds.
All hex colors are sRGB authoring values; lighting values are design inputs.
This package specifies appearance; it does not claim measured performance.

## 1. The visual promise

A carefully lit miniature office is suffering a very human Friday escape.
Workers are adults with compact bodies, expressive hands, and credible chairs.
Comedy comes from weight, resistance, delayed recovery, and over-serious signage.
Broad architecture stays quiet so movement and route choices remain legible.
Furniture reads as manufactured objects before its surface detail becomes visible.
Orange points toward an action; it is never a substitute for an arrow.
The dark theme belongs to interface panels, frames, and graphic recesses.
Playable floors remain bright enough to separate shoes, casters, and hazards.

### Authority and continuity

1. Plan v2 controls renderer, hardware contract, palette, budgets, and presets.
2. This package resolves specific visual choices within that contract.
3. The character bible retains roster names, IDs, roles, and personality.
4. The older UI spec retains code-built flows and theme-helper architecture.
5. Its old neon palette, fallback font, and desktop Compatibility requirement retire.
6. Its corrective intent survives: stronger menu hierarchy, grouped HUD, solid results.
7. The six concepts remain references; they are not engine screenshots or assets.
8. Concept 1 controls body chunkiness where concept 6 looks more realistic.
9. No new concept generation, engine invocation, or measurement phase belongs to Step 1.

## 2. Palette roles

| Token | Exact color | World role | UI role |
|---|---|---|---|
| INK | #0A0A0F | Rubber, deep recesses, graphic print | Background and dark text on accents |
| ORANGE | #FF9A1A | Route arrows, boost, action plates | Primary action and active objective |
| IVORY | #F3E7D3 | Wall paint, paper, shirt, retail shell | Primary text |
| SLATE | #263445 | Rails, frames, ceiling recesses | Secondary surfaces and tracks |
| TEAL | #2C8C91 | Upholstery, carpet inserts, cool balance | Information and ready-state accent |
| CORAL | #E45B4F | Hazard patterns, hostile machinery, sauce | Danger and destructive action |
| BUTTER | #F2C66D | Warm illumination, cheese, laminate tint | Hover highlight and records |
| VIOLET | #8674B8 | Roster accent and retail bands | Unlocks and selected variations |

### Derived-color rule

Only the following neutral UI values supplement the eight-color palette.
They are fixed blends, not additional semantic hues.
SURFACE is #121921.
SURFACE_RAISED is #1B2532.
SURFACE_HOVER is #263445, identical to SLATE.
TEXT_MUTED is #B8B5AE.
DISABLED_TEXT is #817F7C.
ORANGE_PRESSED is #D98116.
Skin, hair, food, and natural wood use the explicit swatches below.
Lighting may tint surfaces; never bake a directional light into base color.
Do not introduce lime success, cyan lift tubes, or RGB chair trim.
Success uses a check, a completed border, and the word READY or COMPLETE.

### Distribution by visible area

| Composition | Quiet light mass | Dark/cool structure | Semantic accents |
|---|---:|---:|---:|
| Evacuation interior | 60% | 30% | 10% |
| Hauled corridor | 45% | 40% | 15% |
| Shop & Seek | 65% | 20% | 15% |
| Pizza Colony | 60% food gold | 25% crust/structure | 15% sauce/markers |
| UI panel | 80% ink/slate | 15% ivory text | 5% accent |

These are composition targets for large masses, not texture pixel quotas.
Route orange occupies at most 3% of a normal office view.
Decorative orange is prohibited within 2 m of a route decision marker.
A player wearing orange does not get a route-shaped arrow on their clothing.
Coral hazards always carry teeth, stripes, an exclamation, or a physical boundary.
Butter food is distinguished from sunlight by geometry and material response.

### Natural swatches

| Family | Allowed base colors | Application |
|---|---|---|
| Skin | #E8B894, #C58B65, #986344, #674333 | Select freely across roster; no role coding |
| Hair | #241E1B, #584236, #967052, #BDB2A0 | One main swatch plus geometric highlight |
| Wood/crust | #C99454, #A86F39 | Laminate edge and crust underside |
| Produce | #58724A, #78905B | Avocado, leaves, pickles, olives |
| Food shadow | #8E4938 | Sauce cavities and pepperoni edges |
| Metal | #929CA2 | Neutral metal under environment light |

No skin swatch implies speed, status, morality, or ability.
Individual variants share exactly the same lighting response.

## 3. Proportions and silhouette language

Use rounded wedges, flattened capsules, thick rims, and restrained asymmetry.
Adult standing-equivalent height is 1.72 m; head height is 0.30 m.
The seated assembly is normally 1.55 m tall from wheel contact to hair.
Hands are 0.19 m long; shoes are 0.29 m long.
Shoulders are wider than hips; neck remains visible above collar.
Avoid infant proportions, spherical torsos, and tiny unsupported limbs.
Front-view arms leave a 0.06 m negative gap from the torso when idle.
Rear-view elbows remain readable outside the backrest.
Keep five casters readable as a radial base, including at the lowest LOD.

### Shape grammar

| Object class | Primary form | Secondary cue | Edge policy |
|---|---|---|---|
| Worker torso | Tapered rounded block | Collar wedge and sleeve cuff | Soft 0.025 m transitions |
| Head | Rounded box/ellipsoid hybrid | Nose wedge and hair mass | No polygonal ball appearance |
| Chair padding | Flattened cushion | Inset seam and compressed center | 0.03 m perimeter roll |
| Desk | Thin rounded slab | Modesty panel and inset feet | 0.012 m bevel |
| Cabinet | Box with recessed face | Handle bridge and toe kick | 0.008 m bevel |
| Copier | Three stepped volumes | Paper throat and lid overhang | 0.018 m bevel |
| Retail shelf | Thin repeated trays | Solid end cap and price rail | 0.008 m bevel |
| Sign | Flat plate | Arrow cut or clipped corner | 0.01 m edge |
| Hazard | Low irregular mass | Teeth/stripes on exact perimeter | High-contrast edge |

An accessory changes a character silhouette once, not at every joint.
Do not cover wheels with skirts, particle clouds, or oversized back fins.
Model depth must survive a three-quarter rear view.
Small screws are texture marks; handles and caster forks are geometry.
Repeated props use one or two materials and shared meshes.
Bevels are visual only and never replace simple collision proxies.

## 4. Lighting composition

Default sun source is west/southwest of each authored composition.
In Evacuation coordinates, light travels approximately (+0.75, -0.50, -0.43).
The source elevation is 30 degrees above the horizon.
The key color is BUTTER #F2C66D at energy 1.0.
Interior fill color is #B8CDD2 at energy 0.45 for the procedural fallback.
Baked-layout ambient fill uses the same color at energy 0.20.
Exposure multiplier is 1.0; automatic exposure is disabled.
Use a fixed neutral tonemapping response across all modes and presets.
Do not desaturate a room to make an effect visible.

### Spatial hierarchy

1. Key light crosses the driving line obliquely.
2. The next decision landmark receives a broad warm face.
3. The opposite wall stays cool ivory, never black.
4. Ceiling recesses are slate-tinted and darker than walls.
5. Ceiling fixtures appear in groups separated by unlit ceiling tile.
6. Wheels read against a floor that is lighter than their rubber.
7. Exit surroundings form a dark frame around a bright open aperture.
8. Background windows remain less prominent than the destination sign.

### Ceiling correction

Ceiling tile base is IVORY with roughness 0.90.
Recess trim is SLATE at 0.30 m depth where existing clearance permits.
Troffer housings are 1.2 × 0.6 m with a 0.04 m recessed diffuser.
Place fixtures at 4 m intervals, grouped in pairs along room axes.
Skip every third pair to create quiet ceiling intervals.
Diffusers occupy no more than 8% of the visible ceiling area.
Static fixture contribution is baked for fixed assemblies.
Procedural fallback fixtures are emissive surfaces, not new live light arrays.
Do not pulse ceiling illumination or rotate light pools during play.

### Procedural lighting decision

The current scripts generate floors, walls, props, and modes at runtime.
Their current output is not assumed to possess valid lightmap UVs or bake data.
Fixed approved layout variants may be assembled deterministically for baking.
Each such assembled variant gets its own static indirect-light data.
Transform changes, room changes, or occluder changes invalidate that association.
Arbitrary layouts use authored ambient fill, broad vertex shading, and the key.
Fallback vertex shading varies by face orientation, never by random vertex noise.
Use multipliers 1.00 on upward faces, 0.90 on side faces, 0.78 underneath.
Fallback contact cards darken floor contacts by at most 18%.
Do not layer a fallback contact card over a baked contact for the same prop.
Moving characters use appropriate baked probes where available.
They use the authored ambient fallback where probe data is unavailable.
GLM records which lighting path each layout uses in its asset manifest.

## 5. Materials and frequency

Nominal environment density is 512 texels/m at approached surfaces.
A shared 2048-pixel tile therefore represents 4 × 4 m.
Far atrium shells use 128 texels/m through UV scale and mip selection.
Hero UVs prioritize head, hands, seat rim, and backrest over hidden undersides.
Texture detail never carries required route or hazard information.
No unique 4K runtime texture set is approved.

| Material | Roughness | Metallic | Normal strength | Physical detail scale |
|---|---:|---:|---:|---|
| Wall paint | 0.86 | 0 | 0.06 | 30–60 mm broad plaster variation |
| Ceiling tile | 0.90 | 0 | 0.04 | 40 mm soft fiber clumps |
| Carpet | 0.95 | 0 | 0.16 | 15–25 mm merged yarn groups |
| Upholstery | 0.88 | 0 | 0.22 | 8–12 mm stylized weave groups |
| Laminate | 0.56 | 0 | 0.10 | 80–160 mm grain flow |
| Molded plastic | 0.48 | 0 | 0.08 | Broad molded waviness only |
| Rubber | 0.92 | 0 | 0.10 | 20 mm tread blocks |
| Painted metal | 0.50 | 0 | 0.06 | Smooth face, shaped edge |
| Exposed metal | 0.32 | 1 | 0.04 | Broad directional brushing |
| Paper/cardboard | 0.84 | 0 | 0.08 | 20 mm fiber clusters |
| Printed packaging | 0.62 | 0 | 0.05 | Creases at 50 mm or greater |
| Cheese | 0.42 | 0 | 0.20 | 0.25–0.60 m folds |
| Crust | 0.82 | 0 | 0.26 | 0.08–0.18 m pores |
| Sauce | 0.30 | 0 | 0.12 | 0.30–0.80 m smooth lobes |
| Vegetable skin | 0.58 | 0 | 0.14 | 30–60 mm simplified dimples |
| Glass | 0.18 | 0 | 0 | Flat shared panes only |

Normal strength is the intended material normal-scale input.
Base-color variation on walls stays within ±3% of the assigned value.
Carpet variation stays within ±5%; it cannot resemble gravel.
Floor seams are 0.008 m wide with at most 8% value reduction.
A 0.5 m checker grid is prohibited on general office floors.
Carpet uses 2 × 2 m broad tile groups with alternating grain orientation only.
Architectural expansion joints use 4 m spacing and no black outlines.
Scuffs occur at door bottoms and chair contact areas, never uniformly.
At most one scuff cluster occupies any 4 × 4 m material tile.
Use shape and roughness to distinguish surfaces before adding wear.

## 6. Animation language

Animation runs on visual children; controller transforms remain authoritative.
All timings are seconds and are independent of render frame count.
Use smoothstep for holds and cubic ease-out for recovery unless stated.
Primary state priority is impact > braking > boost > steer > idle.
Secondary accessories follow the resolved primary state.
No cosmetic pose may imply a longer stun or invulnerability period.

| Event | Anticipation | Main pose | Recovery |
|---|---|---|---|
| Steering | 0.08 | Torso rolls up to 12° into turn | 0.18 to neutral |
| Braking | 0.06 | Seat drops 0.035 m; torso pitches 10° forward | 0.24, one 2° rebound |
| Boost | 0.06 | Torso pitches 8° back; elbows open 6° | 0.20 |
| Jump | Existing event | Knees tuck 0.06 m; hands lift 0.04 m | Land event controls release |
| Landing | None | Seat compresses 0.045 m over 0.08 | 0.22 |
| Light impact | None | Torso recoil 8°, head delayed 0.04 | 0.30 |
| Heavy impact | None | Torso recoil 16°, chair padding scale Y 0.92 | 0.42 |
| Stun | Event onset | Head droops 8°, two short confused glances | End immediately on recovery |
| Recovery | None | Shoulders square over 0.16 | Settle 0.12 |
| Victory | 0.12 | One arm raised 65°, chest opens 8° | Hold 0.6, settle 0.3 |
| Cargo resistance | 0.10 | Shoulders pull forward 6°, wrists held | 0.20 after release |

### Casters and secondary motion

Caster yaw follows planar velocity with a 0.10 s settling time.
At speed above 8 m/s, apply ±4° caster flutter at 7 Hz.
Flutter stops below 6 m/s; no extra wheel physics is created.
Wheel spin derives from traveled distance and authored wheel radius.
Ties and lanyards use at most two articulated segments.
Accessory lag is 0.06 s with one overshoot of at most 6°.
Sleeves compress by at most 5%; skin volumes do not inflate.
Coffee can wobble inside its accessory envelope but never becomes loose cargo.
Ron’s freeze gag pauses only cosmetic idle for 0.067 s once per 12 s.
Never pause a moving chair, player input, replication, or a disguise tell.

## 7. Camera contract

Gameplay field of view is 70° vertical on every preset.
Evacuation boom is 7.5 m with 4.2 m height and 1.0 m look height.
Secondary-mode boom is 8.0 m with 4.5 m height and 1.0 m look height.
Secondary speed trail may reach 9.44 m using the existing 12 m/s normalization.
Position smoothing uses the existing 8/s exponential response.
Near plane is 0.10 m; far plane is 100 m.
Keep existing orbit input and input preferences.
Keep the camera upright; no steering roll.
Resolve occlusion with a 0.35 m collision margin and no wall transparency.
Restore the boom over 0.20 s after an obstruction clears.
Transfers snap the camera at completion instead of flying through floors.
Do not widen FOV during boost; motion is carried by character pose.
No motion blur, gameplay depth of field, chromatic aberration, or vignette.
Camera shake is capped at 0.04 m translation and 0.4° rotation for 0.12 s.
Reduced shake sets both amplitudes to zero.
Reduced motion also suppresses shake and nonessential idle secondary motion.
Gameplay hazard motion and existing disguise wobble remain intact.

## 8. Bounded effects

| Pool | Standard/Enhanced capacity | Lifetime | Shape |
|---|---:|---:|---|
| Ground dust puffs | 24 cards total | 0.35 s | Small ivory crescent |
| Impact ticks | 16 bursts × 3 ticks | 0.18 s | Butter wedge |
| Pickup rings | 8 rings | 0.30 s | Orange open ring |
| Celebration confetti | 64 pieces | 1.20 s | Orange/teal/butter rectangles |
| Decorative motes | 24 total | 2.0 s | Sparse ivory dot |

Only one celebration burst may be active at once.
An exhausted optional pool drops the new cosmetic request.
Hazard telegraphs and interaction borders are persistent geometry, not drop-prone FX.
No decorative rigid bodies or shadow-casting effect lights are added.
Reduced flashing removes impact brightness pulses; retain shape ticks.
Reduced motion removes confetti and motes; retain static outcome text.
Shop & Seek has no motes, dust, pickup rings, or identity trails around disguises.

## 9. Parent-review closure

| 2026-09-12 concern | Binding answer |
|---|---|
| Coarse wall noise | 0.06 normal strength; ±3% color; broad quiet plaster |
| Dark noisy floor grid | 2 m tile groups; 8 mm low-contrast seams; no checker grid |
| Flat ceiling wash | Recessed fixture pairs, gaps, warm key/cool fill hierarchy |
| Primitive furniture | Beveled slabs, recessed faces, handles, caster forks, material separation |
| Scattered HUD | Two aligned information groups plus dedicated objective strip |

Step 2 must realize these large-scale corrections before adding small decoration.
GLM may choose resource caching and mesh assembly techniques without changing this design.
Appearance-changing constraints return to Astra with the affected rule and concrete options.
