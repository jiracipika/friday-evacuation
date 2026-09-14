# Friday 5PM: Evacuation — Full Visual Redesign Plan

**Choose Godot 4 with the Compatibility renderer.** Retain the existing gameplay and LAN systems, and replace the procedural prototype presentation with authored models, carefully budgeted HD materials, and deliberately composed lighting.

The visual identity is **“Friday afternoon corporate chaos”**: chunky, expressive office workers; tactile miniature-like environments; warm late-afternoon sunshine; and absurd physical comedy. The result should look polished at 720p on the power-limited Intel Mac mini, with additional detail available on stronger machines.

This is a read-only production plan. No files were modified and no performance benchmarks were run.

## Engine decision and hardware contract

### Why Godot is the right choice

The hard requirement is sustained performance on weak hardware. A new engine would introduce migration work without establishing that the game will run faster.

The inspected `project.godot` already explicitly selects `gl_compatibility`, although its feature metadata still mentions Forward Plus. The renderer is therefore already aligned with the proposed baseline; the redesign must improve asset quality, lighting, composition, and resource usage.

Godot describes Compatibility as its renderer for older desktop and mobile hardware. Its low base rendering cost suits this project, provided scenes keep lights, material changes, and transparent effects under control. This is a reasoned fit, not a measured guarantee. [Godot renderer overview](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

| Option | Strength | Tradeoff for this project | Decision |
|---|---|---|---|
| **Godot 4 Compatibility** | Broad hardware coverage; existing gameplay, tools, and ENet integration remain usable | Requires disciplined lighting and asset budgets; fewer advanced rendering features | **Selected** |
| Unreal Engine 5 | Strong cinematic authoring and sophisticated rendering tools | Rebuilding gameplay and networking adds substantial work; flagship features are poorly matched to the Intel baseline | Reject |
| Another engine migration | Could offer a different workflow | No benchmark evidence that a rewrite improves this game on these machines | Reject |

Epic’s current macOS documentation recommends an M3 and at least 32 GB RAM, while Nanite and Virtual Shadow Maps require M2 or newer in the documented configuration. Earlier UE5 versions supported Intel editor binaries, but that does not establish suitability for a power-limited Intel mini. UE5 can use conventional rendering; doing so removes much of the proposed visual justification for this migration. [Epic macOS requirements](https://dev.epicgames.com/documentation/en-us/unreal-engine/macos-development-requirements-for-unreal-engine)

**Version policy:** begin with the project’s stated Godot 4.7.1 toolchain and matching export templates. Verify the installed binary during baseline capture. Keep engine upgrades separate from the visual redesign.

### Platform priorities

| Platform | Production commitment |
|---|---|
| Intel Mac mini, approximately 35 W operating limit | Primary performance gate; test while hosting LAN gameplay |
| MacBook Air | Same baseline until its exact chip, RAM, and OS are recorded; native architecture export where supported |
| Android | Secondary target using the same art and Compatibility baseline, smaller textures, fewer effects, and landscape touch UI |

Compatibility requires suitable OpenGL/OpenGL ES support; export availability alone does not prove device compatibility. Validate the actual Macs and a named Android test device. [Godot system requirements](https://docs.godotengine.org/en/stable/about/system_requirements.html)

### Proposed performance targets

These are acceptance targets, not claims about current performance.

| Metric | Required baseline | Optional enhanced preset |
|---|---|---|
| Internal 3D resolution | 1280 × 720 | 1920 × 1080 where measured sustainable |
| Frame pacing | Stable 30 FPS cap; uncapped p95 frame time ≤30 ms and p99 ≤40 ms | Stable 60 FPS cap; uncapped p95 ≤15 ms |
| Thermal verification | 30-minute representative session | Same |
| Resident texture budget, including lightmaps | ≤256 MiB | ≤512 MiB |
| Process memory on Macs | Initial ceiling: 1.5 GiB resident | Initial ceiling: 2 GiB |
| Visible geometry | Start at ≤200,000 triangles per worst-case view | Up to 400,000 if measured safe |
| Draw calls | Start at ≤250, including shadow passes | Up to 400 if measured safe |
| Dynamic lighting | At most two overlapping local lights per visible object; no dynamic shadows | One tightly bounded shadowed key light |
| Effects | Pooled, short-lived, limited screen coverage | Increased density within timing budget |

Geometry and draw-call limits are initial guardrails. Actual frame time, memory, and thermal behavior decide whether a scene passes.

Measure exported release builds with the editor closed. Use maximum supported match occupancy and the busiest mode-specific situations. Record loading separately from gameplay. Compare the first and final five minutes to expose thermal degradation.

A 60 FPS baseline remains desirable, but this plan does not promise it without knowing the Mac mini’s GPU and the Air’s generation.

## Art direction

### Style: tactile corporate slapstick

Create an original stylized 3D world with broad surfaces, rounded edges, restrained texture detail, and strong silhouettes.

Characters have slightly oversized heads and hands, short readable limbs, and flexible poses. Chairs remain instantly recognizable: padded backrest, armrests, central support, and a five-spoke caster base. Character identity comes from posture, hairstyle, clothing shape, and accessories.

Environments use realistic material categories with simplified detail. Carpet should feel woven, laminate should feel inexpensive, and cheese should feel soft and oily. Avoid photographic grime, tiny scratches everywhere, and dense procedural noise.

Comedy comes from ordinary objects in unreasonable situations: a chair towing an angry copier, a banana hiding among cereal boxes, or a stapler serving as a colony gate.

### Shared palette

| Role | Color | Use |
|---|---|---|
| Ink | `#0A0A0F` | Menu background, deepest accents |
| Slate | `#263445` | Furniture frames, secondary UI |
| Warm ivory | `#F3E7D3` | Walls, paper, readable foreground text |
| Friday orange | `#FF9A1A` | Primary action, boost, route emphasis |
| Office teal | `#2C8C91` | Upholstery, environmental contrast |
| Tomato coral | `#E45B4F` | Danger accents, cargo hostility, pizza sauce |
| Butter yellow | `#F2C66D` | Sunlight, cheese, selected props |
| Muted violet | `#8674B8` | Additional player identity and shop accents |

Keep most surfaces neutral. Saturated colors carry gameplay information.

Player identification must combine color with a shape badge and silhouette cue. Danger uses coral plus a warning symbol or pattern. Route guidance uses orange arrows and clear geometry, so navigation remains understandable without color.

### Lighting mood

Use late-afternoon amber sunlight against cooler teal ambient fill. Interiors stay bright enough to read chair wheels, floor edges, hazards, and opponents at speed.

Static environments receive baked lighting where practical. Moving characters use simple direct and ambient lighting with inexpensive contact-shadow meshes on the baseline preset. Specular response is broad and restrained.

LightmapGI can display baked lighting in Compatibility, but its built-in baking path requires hardware supporting Forward+ or Mobile. Establish a working baking machine before depending on this workflow. If neither Mac qualifies, use offline-baked ambient occlusion, vertex color gradients, and simple runtime lighting for the baseline. [Godot LightmapGI documentation](https://docs.godotengine.org/en/stable/classes/class_lightmapgi.html)

No required visual depends on real-time global illumination, volumetric fog, screen-space reflections, or heavy bloom. Build perceived richness through composition, material separation, and lighting.

### References to assemble

Build a reference board around specific visual problems:

- **1970s office furniture and corporate interiors:** warm laminate, fabric panels, chunky plastic, restrained geometric signage.
- **Miniature photography and stop-motion sets:** tactile surfaces, simplified construction, carefully staged light.
- **Slapstick animation storyboards:** anticipation, readable imbalance, expressive reaction poses.
- **Supermarket packaging grids:** broad color blocks and recognizable product silhouettes.
- **Food macro photography:** crust pores, melted cheese folds, vegetable translucency translated into inexpensive materials.

Use these as design references. Create original characters, packaging, logos, and signage.

### Mode identities

| Mode | Visual treatment | Gameplay readability |
|---|---|---|
| **Evacuation** | Four-story office atrium, warm sunlight, teal furniture, orange route markers | Floor numerals and distinct wall bands orient players; parking exit remains visually dominant |
| **Hauled** | Loading areas, utility corridors, battered carts, copier-like hostile cargo | Cargo state changes through pose, lights, and symbols; delivery bays have clear borders |
| **Shop & Seek** | Bright retail lighting, cream shelves, pastel packaging, oversized groceries | Product categories read by silhouette; scenery and disguised players follow fair concealment rules |
| **Pizza Colony** | Golden crust cliffs, coral sauce channels, cheese fields, office-supply structures | Traversable surfaces, dangerous sauce, resources, and colony boundaries have distinct shapes |

### Interface and animation

Retain the dark menu identity and orange primary action. Use warm ivory text, clear rectangular panels with modest rounding, and a licensed sans-serif with strong numerals.

Prioritize speed, placement, objectives, and immediate hazards. Keep decorative information out of the central driving view.

Landscape touch controls need at least 48 dp interaction targets, safe-area handling, and a layout that preserves the route ahead. Provide reduced camera shake and reduced flashing.

Invest animation effort in leaning, braking, caster wobble, recoil, recovery, and victory poses. Use short controlled secondary motion for ties and badges; avoid making cloth simulation a baseline requirement.

## HD texture and material strategy

### Author high resolution; ship according to screen size

“HD” means useful close-up detail and consistent material quality. It does not mean every prop receives a unique 4K texture.

| Asset category | Authoring source | Baseline runtime |
|---|---|---|
| Hero worker and chair | Separate 2K sets; 4K source only where useful | 1K per set; 2K selectively for close-up presentation |
| Carpet, walls, laminate, food surfaces | Seamless 2K textures | 1K–2K shared tiles |
| Repeated furniture and shelving | 2K trim sheets and atlases | 1K–2K shared sets |
| Small office props and groceries | Shared 2K atlas | 512–1K atlas |
| Signs and interface graphics | Vector masters where appropriate | Resolution matched to display size |
| Menu key art | At least 2560 × 1440 master | 1080p desktop and smaller mobile variants |

Start around 256 texels per meter for environment surfaces. Increase density for regularly approached hero surfaces and reduce it for upper floors and distant scenery.

A 2048² RGBA8 texture with a full mip chain is approximately 21.3 MiB before GPU compression. A three-map uncompressed material can therefore consume roughly 64 MiB. Track imported GPU formats and residency rather than PNG file size.

### Material structure

Use a small shared library of standard PBR materials:

- Base color in sRGB, with no painted directional illumination.
- Tangent-space normals imported as normal data.
- Packed occlusion, roughness, and metallic channels where supported and verified.
- Constant roughness or metallic values when a texture would add little.
- Optional small emission masks for screens and status indicators.

Start with 12–16 core materials: carpet, painted wall, acoustic ceiling, laminate, upholstery, plastic, rubber, metal, paper/cardboard, retail packaging, cheese, crust, sauce, vegetables, and glass accents.

Use mipmaps throughout. Set anisotropic filtering according to measured benefit on racing floors. Generate platform-appropriate GPU-compressed imports, checking actual device support and memory use.

Keep glass scarce. Prefer opaque reflective panels where transparency does not affect gameplay. Apply scuffs and labels through atlases or fitted mesh overlays rather than assuming renderer decal support.

### Replace runtime visual generation selectively

Preserve procedural layout logic, collision contracts, and network identifiers. Replace visual construction with reusable authored scenes.

- Build office walls, stairs, floors, and storefronts as modular pieces.
- Share mesh and material resources across instances.
- Create LODs for chairs, workers, shelving, and repeated props.
- Organize repeated instances by room or floor so grouping does not defeat visibility culling.
- Replace purely decorative runtime noise generation with offline-authored or offline-generated textures.
- Keep collision geometry simple and independent of visual bevels.

For fixed layout variants, assemble and bake each supported layout offline. Arbitrary runtime layouts use the validated ambient/vertex-lighting fallback; moving modules cannot blindly reuse lighting baked for different surroundings.

Only the active mode’s assets should remain resident. Avoid loading all four environments for menu thumbnails.

### Texture production and quality checks

Generated images serve as references or editable source material. They are not automatically seamless, physically valid, or correctly aligned PBR maps.

Every production material must pass:

- Seam inspection across a 3 × 3 tiled surface.
- Neutral-light and gameplay-light review.
- Roughness and normal inspection under a moving light.
- Mipmap and motion review at the actual camera distance.
- Scale consistency against neighboring assets.
- Source provenance and license tracking.

Keep high-resolution sources outside runtime export paths where practical. Maintain a material manifest containing physical scale, source, runtime sizes, compression, and affected assets.

## Five-step execution system

### Step 1 — Establish the measured baseline

**Goal:** turn the weak-hardware requirement into a reproducible pass/fail contract.

**Concrete deliverables:**

- Hardware inventory: CPU, GPU, RAM, OS, display resolution, and power configuration.
- Confirmed Godot binary and export-template versions.
- Baseline release builds and captures for all four modes.
- Fixed benchmark routes, occupancy settings, and mode-specific stress scenarios.
- CPU/GPU timing, memory, draw-call, triangle, and loading measurements.
- Renderer and configuration audit, including the contradictory feature metadata.

**Acceptance criteria:**

- Both Macs run the exported project and participate in a real LAN session.
- Each mode has a repeatable benchmark.
- Current failures against the proposed budget are explicitly recorded.
- Host simulation cost is distinguishable from rendering cost.

**Verification:** run three repetitions of each benchmark, followed by a 30-minute thermal session on each Mac. Capture baseline screenshots from fixed cameras. Do not treat loopback networking tests as two-machine verification.

### Step 2 — Prove the art direction in one playable slice

**Goal:** demonstrate that the proposed appearance works within the baseline budget before replacing every asset.

**Concrete deliverables:**

- Art bible covering palette, silhouettes, lighting, typography, and material scale.
- One finished worker and chair.
- One office room, corridor, stair transition, and lobby viewpoint.
- Initial carpet, wall, laminate, upholstery, plastic, and metal materials.
- Lighting-bake proof or a documented working fallback.
- Baseline and enhanced preset comparison captures.

**Acceptance criteria:**

- The slice passes the baseline frame-time and memory targets.
- Players, route, exit, and hazards remain recognizable at 720p in motion.
- Materials remain distinct without optional post-processing.
- The slice’s approved screenshots define the production quality bar.

**Verification:** compare matched before/after screenshots and racing footage. Conduct a five-person unfamiliar-player test: at least four identify the route and immediate hazard within three seconds. Repeat on the Intel mini after thermal warm-up.

### Step 3 — Build the reusable production asset system

**Goal:** make the approved style economical to reproduce across every mode.

**Concrete deliverables:**

- Modular office and loading-area kits.
- Supermarket shelving, packaging, and grocery-character kits.
- Pizza terrain, ingredient, and colony-construction kits.
- Shared texture library, trim sheets, atlases, LODs, collision proxies, and import presets.
- Worker/chair identity variants and core animation set.
- Asset manifest with ownership, provenance, and resource budgets.

**Acceptance criteria:**

- Every asset has correct scale, pivot, collision, material assignments, and appropriate LODs.
- Repeated assets share resources.
- Tiled materials show no obvious seams or distracting repetition.
- Representative crowded scenes stay within the provisional geometry and draw-call limits.
- No cosmetic replacement changes collision behavior unintentionally.

**Verification:** review assets in a neutral material scene and a dense gameplay test scene. Inspect imported memory, resource sharing, LOD transitions, and collisions. Run relevant existing material and scene smoke tests.

### Step 4 — Redesign all modes and presentation flows

**Goal:** complete the visual replacement while preserving playable, synchronized game behavior.

**Concrete deliverables:**

- Complete Evacuation treatment across four floors and the parking exit.
- Hauled cargo states, delivery zones, environment dressing, and effects.
- Shop & Seek supermarket, groceries, concealment cues, and interaction effects.
- Pizza Colony terrain, resources, structures, survival states, and effects.
- Main menu, lobby, mode selection, HUDs, results screens, and touch layouts.
- Floor/room visibility organization, effect pools, and quality settings.

**Acceptance criteria:**

- No unintended prototype visuals remain in player-facing scenes.
- Every mode communicates objectives consistently.
- Cosmetic changes preserve physics, interaction reach, and network identities.
- Quality presets preserve Shop & Seek concealment and hazard visibility.
- Touch controls remain usable without obstructing critical information.
- All modes meet the baseline performance gate at supported occupancy.

**Verification:** run the repository’s required verification ladder and real two-machine LAN sessions. Check joins, reconnects, mode changes, cargo interactions, hiding, survival events, and race completion. Compare visibility across presets and test landscape phone layouts.

### Step 5 — Optimize, validate, and lock the visual release

**Goal:** deliver a finished redesign with evidence that it holds up on target hardware.

**Concrete deliverables:**

- Final baseline and enhanced presets.
- Platform import/export settings and active-mode resource loading.
- Optimized hotspots identified by measurement.
- Thirty-minute thermal reports for both Macs.
- Android install, rendering, touch, memory, and thermal report on a named device.
- Final screenshot set, asset documentation, and remaining-issue register.

**Acceptance criteria:**

- Both Macs pass the agreed baseline timing and memory targets.
- Repeated mode changes produce no continuing memory growth.
- No missing materials, shader failures, major texture seams, or collision regressions remain.
- Menu and loading behavior fit the same resource discipline as gameplay.
- Android readiness is claimed only after real-device validation; otherwise it remains explicitly pending.

**Verification:** repeat the original benchmarks in release exports, run the required regression ladder, and perform a full LAN session through all modes. Fix measured bottlenecks, then rerun the affected checks and final thermal gate.

## Six image-generation prompts

These prompts share one art direction. They describe visual targets; generated lighting and geometry must later be translated into the approved runtime budgets.

### 1. Office chair race heroes — character concept lineup

> Create an original stylized 3D character concept sheet for “Friday 5PM: Evacuation,” a comedy office-chair racing game. Show four distinct adult office workers racing ergonomic swivel chairs: a determined analyst with round glasses, an exuberant receptionist with rolled sleeves, a deadpan manager clutching a mug, and a frantic technician with a crooked headset. Use slightly oversized heads and hands, compact readable bodies, expressive leaning poses, and mechanically understandable five-spoke caster bases. Materials feel like tactile miniature props: woven teal upholstery, warm ivory shirts, slate plastic, brushed metal, and selective orange accents. Add coral and muted violet identity details. Present full silhouettes, one side-view chair study, and small accessory studies against warm ivory. Soft amber key light, cool fill, crisp edges, restrained wear, original designs, no logos, no photorealistic skin, no motion blur.

### 2. Four-story office lobby — Evacuation key art

> Create cinematic 16:9 key art for “Friday 5PM: Evacuation,” an original comedy office-chair racing game. Show a generous atrium with exactly four occupied office levels, including the ground floor, connected by clearly visible switchback stairs and broad landings. Four expressive adult workers descend chaotically on recognizable five-caster office chairs, ties flying, papers scattering, one coffee cup improbably upright. Place the parking-lot exit visibly at ground level, with late-afternoon sunlight entering beyond parked cars. Use tactile miniature-style 3D forms, rounded furniture, warm ivory walls, teal carpet, slate railings, and orange route arrows. Strong diagonal composition carries the eye from the upper floor to the exit. Warm amber sunlight balances cool interior fill. Preserve architectural clarity, readable faces, and clean silhouettes. No destruction, smoke, illegible signage, or photorealistic clutter.

### 3. Shop & Seek — supermarket gameplay concept

> Create a 16:9 environment concept for “Shop & Seek,” a playful supermarket hide-and-seek mode within “Friday 5PM: Evacuation.” Use original stylized 3D miniature aesthetics: rounded shelves, broad shapes, tactile cardboard, matte plastic, and restrained surface detail. View the scene from grocery height along two readable aisles opening toward checkout counters. A nervous banana character peeks beside matching bananas, a tiny milk-carton character blends into dairy stock, and a cereal-box character hides among ordinary packages while an adult office-worker seeker passes at the far end. Use warm ivory fixtures, teal shelf edges, orange promotional shapes, and controlled coral and violet packaging. Bright soft retail lighting receives warm afternoon window accents. Preserve believable hiding spaces and clear aisle boundaries. No brands, readable packaging text, heavy depth of field, or visual clutter.

### 4. Pizza Colony — survival environment concept

> Create a wide 16:9 concept image for “Pizza Colony,” a whimsical survival mode within “Friday 5PM: Evacuation.” Tiny adult office workers build a settlement on an enormous pizza, using a stapler as a gate, binder clips as barricades, and cardboard takeaway scraps as shelters. Show golden crust forming distant cliffs, broad melted-cheese plains, coral tomato-sauce channels, mushroom platforms, and green pepper arches. A wheeled office chair transports a carefully stacked resource bundle toward the colony. Use original tactile miniature-style 3D art, chunky readable silhouettes, softly beveled objects, simplified appetizing food textures, and restrained glossy highlights. Amber late-afternoon light and cool teal fill unite the scene. Clearly separate traversable cheese, dangerous sauce, and defended settlement space. No gore, mold, realistic grease puddles, excessive particles, or microscopic texture noise.

### 5. Office materials — PBR texture style sheet

> Create a clean material-direction sheet for the stylized 3D comedy game “Friday 5PM: Evacuation.” Arrange three equal columns showing teal woven office carpet, warm ivory painted plaster wall, and honey-colored laminate desk surface. Each column contains a large square orthographic surface swatch, a small shaded material sphere, and a beveled sample slab. Add aligned smaller visual studies suggesting base color, tangent-space normal detail, and grayscale roughness beneath each primary sample. Keep surface features broad enough for a miniature-like game viewed at 720p: short carpet fibers, subtle paint stipple, restrained wood grain, sparse believable wear. Use neutral illumination for swatches and consistent soft studio light for previews. Plain slate background, meticulous spacing, no labels, no logos, no perspective in texture swatches, no directional shadows painted into base-color studies.

### 6. Main menu — composition with interface space

> Create polished 16:9 main-menu background key art for “Friday 5PM: Evacuation,” an original comedy 3D co-op game. Reserve the left forty percent as a quiet near-black ink field, hex #0A0A0F, with a subtle warm architectural gradient for later title and menu placement. On the right, three expressive adult office workers skid toward an office parking exit on teal upholstered swivel chairs, one towing a grumpy copier strapped onto a cargo trolley. Include tiny background hints of grocery packaging and a pizza delivery box. Use tactile miniature-style materials, rounded silhouettes, ivory clothing, slate furniture, orange highlights, and restrained coral details. Golden Friday-afternoon sunlight creates a clear focal group against cool interior fill. Crisp composition, humorous anticipation, readable wheels and faces. No rendered text, buttons, logos, motion blur, or essential details near crop edges.
