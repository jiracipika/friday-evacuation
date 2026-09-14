# Friday 5PM: Evacuation — Revised Visual Redesign Plan

**Choose Godot 4.7 with Forward+ for desktop.** Preserve the existing GDScript gameplay, ENet LAN multiplayer, chair physics, four modes, and approximately 40 test scripts. Use Compatibility for the secondary Android presentation.

The minimum desktop target is **AMD RX 580 8 GB + Intel i5-8400, at 1280 × 720 and 30 FPS**. That is a complete, acceptable experience. Higher resolutions, frame rates, and optional polish consume available headroom.

The art direction remains **tactile corporate slapstick**, now supported by richer authored geometry, standard 2K hero materials, baked indirect lighting, and selective dynamic shadows.

This document replaces the previous Mac mini hardware contract and all measurement-related execution steps. It is a read-only plan; no files were modified.

## 1. Engine decision

### Why Godot still wins under the new floor

The RX 580 target changes the rendering decision substantially. The project no longer needs to organize its desktop identity around the lowest-overhead Compatibility feature set. Forward+ becomes the desktop production renderer.

The new hardware also makes conventional UE5 rendering a credible option. Rejecting UE5 because of the old Intel Mac constraint would no longer be sound reasoning.

However, this game’s visual gains come primarily from authored models, expressive animation, material quality, lighting composition, and coherent interface design. Godot can deliver those while retaining working gameplay systems. Migrating would require reconstructing physics behavior, scene logic, multiplayer authority and synchronization, UI flows, and engine-specific tests.

**The decision is to spend production effort on the visible redesign instead of rebuilding the game’s foundation.**

| Candidate | Assessment at the new floor | Decision |
|---|---|---|
| **Godot 4.7 Forward+** | Supports the desired desktop material and lighting workflow while retaining existing systems. Expensive optional effects can remain disabled. | **Selected for desktop.** |
| **Godot 4.7 Compatibility** | Can deliver the art direction with simpler lighting and effects. Its restricted rendering path is no longer necessary as the desktop default. | **Selected for secondary Android presentation.** |
| **UE5, conventional rendering** | Credible with Nanite, Lumen, and Virtual Shadow Maps disabled; baked lighting, conventional meshes, LODs, and shadow maps remain useful. Strong authoring tools provide real upside, but insufficient project-specific benefit to justify rebuilding gameplay and networking. | Do not migrate. |
| **Unity 6 with URP** | A credible desktop/mobile choice with a suitable rendering pipeline. Requires C# gameplay migration, physics retuning, and multiplayer integration without a necessary visual capability gain. | Do not migrate. |
| **Stride** | A viable conventional 3D renderer, but entails C# migration and replacing the existing project workflow. No distinctive requirement favors it here. | Do not migrate. |
| **O3DE** | Atom supplies modern PBR rendering. Adopting its asset, entity, scripting, and networking workflows would create substantial integration work for this redesign. | Do not migrate. |

Godot documents its renderer differences and baked-lighting support in its [rendering documentation](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html). Epic separates advanced rendering feature requirements from general engine requirements; editor recommendations are not this game’s runtime minimum. See [UE5 hardware and rendering requirements](https://dev.epicgames.com/documentation/unreal-engine/hardware-and-software-specifications-for-unreal-engine). The other alternatives are informed by [Unity 6 requirements](https://docs.unity3d.com/6000.0/Documentation/Manual/system-requirements.html), [Stride requirements](https://doc.stride3d.net/4.3/en/manual/install-and-update/requirements.html), and [O3DE Atom documentation](https://www.docs.o3de.org/docs/user-guide/visualization/rendering/).

These are project-specific engineering judgments, not comparative performance results.

### Toolchain policy

Retain the project’s Godot 4.7 toolchain and matching export templates. GLM resolves the exact installed patch and aligns project metadata with the selected renderer during implementation. Engine upgrades remain separate work.

Desktop renderer selection is fixed by this plan. Android receives an explicit Compatibility configuration with shared assets and documented material fallbacks.

## 2. Inclusive hardware contract

| Item | Decision |
|---|---|
| Minimum desktop GPU | AMD RX 580, specifically the 8 GB model |
| Minimum desktop CPU | Intel i5-8400 |
| Required experience | 720p, 30 FPS target, full gameplay and complete visual identity |
| Default minimum-spec preset | **Standard** |
| Stronger hardware | Optional resolution, frame-rate, filtering, and shadow-quality increases |
| Android/touch | Secondary, using the same visual language with reduced rendering complexity |
| Previous Intel Mac mini requirement | Retired as a design constraint |

A performance-measurement phase is removed entirely. There are no benchmark routes, baseline captures, percentile timing requirements, thermal sessions, hardware comparison reports, or benchmark release gates.

The team engineers toward 720p30 through bounded content, conventional rendering, resource sharing, and controlled simulation complexity. These construction rules support the target; they are not a claim that an unbuilt redesign has already achieved a measured frame rate.

### Construction rules

The following are initial production ceilings for Standard, not runtime measurement tasks.

| Area | Standard construction rule |
|---|---|
| Geometry | Assemble worst-case camera views to approximately 500,000 visible triangles or fewer through authored LODs and visibility partitions |
| Worker and chair | Combined closest gameplay LOD up to roughly 35,000 triangles; two simpler LODs |
| Materials | Normally no more than three material slots per worker/chair assembly; one or two per repeated prop |
| Lighting | Baked static indirect lighting; one shadowed directional key; no shadowed decorative local lights |
| Shadow coverage | Restricted to the nearby playable area, rather than the entire four-story building |
| Reflections | Baked/static reflection probes; no continuous probe updates |
| Expensive effects | SDFGI, SSR, volumetric fog, SSAO, and SSIL disabled on Standard |
| Transparency | Sparse glass and small effect cards; avoid stacked full-screen transparent layers |
| Textures and lightmaps | Plan a maximum active-mode allocation of 2 GiB using imported formats and mip-chain sizes |
| Residency | Current mode plus shared assets; unload the previous mode |
| Decorative physics | No newly added rigid bodies for ordinary dressing; animation or pooled visual effects instead |
| Effect population | Fixed pool capacities; optional celebration effects may be dropped when full |
| Network traffic | Local cosmetic animation; replicate gameplay events through existing authority rules |

An atrium can expose several floors simultaneously. Distant floors therefore use simplified architectural shells and grouped furnishings. Detailed room interiors appear only where the camera can meaningfully see them. Group repeated objects by room or floor so instancing does not prevent useful culling.

These rules apply at the existing supported match occupancy, including a player hosting LAN gameplay. The redesign does not increase that occupancy or simulation complexity.

### Quality presets

- **Standard:** 720p30 default, 2K hero textures, baked lighting, restrained directional shadows, static reflections, FXAA, and 4× anisotropic filtering.
- **Enhanced:** same art and gameplay geometry, with optional higher resolution, 60 FPS cap, 8× filtering, and sharper shadows. No higher-performance promise is attached.
- **Android:** Compatibility, generally 512–1K textures, simplified decorative meshes, baked lighting and contact-shadow substitutes, reduced particles, and landscape touch controls.

Quality settings must preserve silhouettes, hazard boundaries, hiding cover, player cues, and interaction distances. A low preset must never become a visibility advantage in Shop & Seek.

## 3. Visual authority and responsibility

**Astra owns every visual design decision. GLM owns implementation, verification, and orchestration.**

| Astra decides | GLM delivers |
|---|---|
| Art direction, palette, proportions, silhouettes, composition, materials, lighting, cameras, typography, UI layout, animation style, effects, and preset appearance | Scene integration, shaders and material setup, asset imports, renderer configuration, LOD implementation, loading, builds, tests, LAN checks, and issue tracking |
| Visual acceptance of assets and in-game presentation | Evidence that the approved presentation is implemented correctly |
| Revisions when a technical constraint affects appearance | A concrete constraint report with affected screenshots and implementation options |

GLM can make routine technical choices that preserve the approved appearance. Any choice that changes appearance returns to Astra for a design decision. This is an internal production responsibility, not a request for additional user approval.

## 4. Art direction: tactile corporate slapstick

The game should resemble a carefully lit miniature office undergoing a ridiculous Friday escape.

Use chunky forms, softened edges, expressive adult workers, tactile materials, and readable physical comedy. The additional hardware allowance buys convincing chair construction, rounded furniture edges, fabric response, contact lighting, and animation polish.

### Characters and chairs

Workers have slightly oversized heads and hands, compact limbs, and strong seated silhouettes. Identity comes from hairstyle, clothing shape, posture, and one restrained accessory.

Chairs retain five-spoke caster bases, padded backrests, armrests, and understandable supports. Give wheel assemblies and upholstery enough geometry to hold up during lobby close-ups.

Animation priorities are steering lean, braking compression, caster flutter, cargo resistance, impact reaction, recovery, and victory. Ties, badges, and sleeves use short authored secondary motion.

Gameplay camera motion stays restrained. Reduced shake and reduced flashing are available. Motion blur and gameplay depth of field remain disabled for clear racing and hiding.

### Palette

| Role | Color | Use |
|---|---|---|
| Ink | `#0A0A0F` | Menus, panel backgrounds, deepest graphic accents |
| Friday orange | `#FF9A1A` | Primary action, boost, route guidance |
| Warm ivory | `#F3E7D3` | Text, walls, paper, shirts |
| Slate | `#263445` | Frames, rails, secondary UI |
| Office teal | `#2C8C91` | Upholstery, carpet accents, cool environmental balance |
| Tomato coral | `#E45B4F` | Danger, hostile cargo, sauce |
| Butter yellow | `#F2C66D` | Sunlight, cheese, selected props |
| Muted violet | `#8674B8` | Player accents and retail variety |

The dark theme belongs primarily to the interface. Playable interiors remain bright enough to read wheels, stairs, obstacles, and opponents.

Orange route guidance always includes arrows or geometry. Danger combines coral with symbols or patterns. Player identity combines color, a shape badge, and silhouette cues.

### Lighting

Late-afternoon amber sunlight contrasts with cool interior fill. Static indirect light supplies room depth; broad highlights separate fabric, plastic, laminate, metal, and food.

Moving workers and chairs receive direct light and baked probe lighting where appropriate. Near-player directional shadows give grounded movement. Avoid excessive ambient-occlusion darkening at baked contacts.

For fixed layouts, bake each assembled layout. Arbitrary procedural layouts receive authored ambient lighting, vertex shading, and simple direct lighting; they cannot reuse room-dependent lightmaps indiscriminately. Godot’s lightmap baking runs in the editor through Forward+ or Mobile, while Compatibility can display the result. [Godot lighting architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html)

### Mode identities

| Mode | Visual identity | Readability contract |
|---|---|---|
| **Evacuation — primary** | Warm corporate atrium, teal furniture, ivory architecture, orange escape route | Exactly four playable stories; large floor numerals, distinctive landmarks, clear stair entries, and a dominant parking exit |
| **Hauled** | Utility corridors, loading bays, reinforced trolleys, disgruntled office machinery | Cargo emotion reads through pose, indicator shape, and animation; delivery zones have unmistakable borders |
| **Shop & Seek** | Cream retail fixtures, orderly pastel packaging, bright diffuse lighting | Product silhouettes and category groupings create hiding opportunities; disguises share the ordinary stock’s material and lighting treatment |
| **Pizza Colony** | Golden crust cliffs, buttery cheese terrain, coral sauce channels, office-supply structures | Safe ground, danger, resources, and defended space have distinct forms and edge treatments |

Evacuation receives the first finished environment and the strongest marketing composition. The other modes share material response and character language while remaining recognizable without their titles.

### Interface and touch

Use ink panels, ivory text, orange primary actions, and restrained corner rounding. Use **Noto Sans**, packaged with its license, with strong numeral hierarchy.

The main menu reserves the left 40% for navigation and places chair comedy on the right. Mode cards lead with Evacuation.

HUD hierarchy is immediate objective, essential player state, then supporting information. Keep central route visibility clear.

Landscape touch controls use at least 48 dp targets, safe-area margins, a left steering region, and right-side action controls. Support control scaling and repositioning. Every touch action also has a desktop input equivalent; essential information never depends on hover.

## 5. HD texture and material strategy

### Standard desktop texture allocation

The RX 580 8 GB target supports a deliberate 2K material workflow. Use that allowance on visible quality while retaining shared materials and atlases.

| Asset | Standard runtime allocation |
|---|---|
| Hero worker | One 2K material set, with shared accessory resources |
| Hero chair | One 2K set shared across color variants |
| Carpet, plaster, laminate, upholstery | Shared 2K tiling sets |
| Repeated furniture | Shared 2K trim sheets and atlases |
| Groceries and office props | 1K–2K category atlases |
| Pizza surfaces and major ingredients | Shared 2K sets |
| Small or distant decoration | 512–1K shared resources |
| UI and signage | Vector sources where practical; raster output sized for display |
| Menu key art | At least 2560 × 1440 source, with desktop and mobile exports |

Use approximately 512 texels per meter for commonly approached environment surfaces, reducing density for distant architecture. Hero UV allocation follows screen coverage. Unique 4K runtime sets are unnecessary for this direction.

### Material language

Maintain a compact library covering carpet, wall paint, ceiling tile, laminate, upholstery, plastic, rubber, metal, paper, packaging, cheese, crust, sauce, vegetables, and glass.

Use:

- Base color without painted directional illumination.
- Tangent-space normals with restrained detail.
- Packed occlusion, roughness, and metallic maps where useful.
- Constant channels where maps add no visible value.
- Small emission masks for screens and indicators.
- Palette-driven variants that reuse textures.

Fabric weave, laminate grain, crust pores, and cheese folds should survive downsampling without shimmer. Avoid microscopic noise and universal scratches.

Use mipmaps and platform-appropriate GPU compression. Compute resource allocations from imported texture formats, mip chains, and lightmaps rather than source PNG sizes. Eight gigabytes of VRAM is not an eight-gigabyte texture allowance.

### Asset construction

Replace prototype visual meshes with reusable authored scenes while preserving layout logic, collision proxies, network identifiers, and gameplay attachment points.

Keep visual bevels separate from collision geometry. Reuse mesh and material resources. Provide explicit LODs for workers, chairs, shelving, ingredients, and repeated furniture.

Generated material images remain references or editable sources until their seams, scale, normal orientation, and roughness behavior are corrected. Each production material receives a neutral-light review, tiled review, gameplay-camera review, and provenance record.

## 6. Five-step execution system

### Step 1 — Define the visual world

**Goal:** establish a complete design package for implementation.

**Astra delivers:**

- Art bible with palette, proportions, lighting, material scale, and animation language.
- Worker/chair model sheets and player identity rules.
- Four-story Evacuation composition and route-signage system.
- Mode identity sheets.
- Main menu, lobby, HUD, results, and touch layouts.
- Standard, Enhanced, and Android appearance specifications.

**GLM delivers:**

- Asset inventory mapped to existing scenes and gameplay attachment points.
- Dependency-ordered implementation backlog.
- Godot toolchain alignment and desktop/Android renderer configuration.
- Asset manifest fields for LODs, textures, materials, provenance, and ownership.

**Completion:** Astra’s designs are specific enough to implement without GLM inventing visual policy. Every existing player-facing flow has a planned treatment.

### Step 2 — Finish the flagship playable slice

**Goal:** establish the production appearance in actual gameplay.

**Deliverables:**

- One finished worker and chair.
- One office room, corridor, stair transition, and atrium-to-exit view.
- Core office material library.
- Baked lighting and moving-character lighting.
- Driving animation, route markers, and race HUD.
- Corresponding Android material and shadow treatment.

**Astra verifies:** 720p readability, character charm, surface separation, route clarity, lighting balance, and camera composition.

**GLM verifies:** scene loading, material compatibility, chair behavior, collision preservation, construction-rule compliance, and shared-resource setup.

**Completion:** approved in-game views and motion define the production bar. There is no frame-time gate.

### Step 3 — Build the shared art system

**Goal:** make consistent production across all four modes practical.

**Deliverables:**

- Modular office, stair, lobby, and loading-area kits.
- Retail fixtures, package families, and grocery characters.
- Pizza terrain, ingredients, and office-supply construction pieces.
- Worker variants, chair variants, and core animation library.
- Trim sheets, atlases, LODs, collision proxies, and import rules.
- Reusable UI components and bounded effect pools.

**Astra verifies:** silhouettes, material consistency, variation, scale, and animation style.

**GLM verifies:** pivots, UVs, imports, resource sharing, collision contracts, LOD configuration, and relevant existing asset/scene tests.

**Completion:** each mode can be assembled from approved assets with documented resource allocations.

### Step 4 — Complete all modes and presentation

**Goal:** deliver the full visual replacement.

**Deliverables:**

- Evacuation’s four floors, transitions, lobby, and parking exit.
- Hauled environments, cargo states, and delivery presentation.
- Shop & Seek retail world, disguises, and interaction cues.
- Pizza Colony terrain, resources, structures, and survival feedback.
- Main menu, lobby, mode selection, HUDs, results, and touch layouts.
- Visibility partitions, active-mode loading, and quality presets.

**Astra verifies:** composition, mode distinction, information hierarchy, preset fairness, and consistency across the whole game.

**GLM verifies:** relevant repository tests and real two-machine LAN behavior, including joining, mode changes, cargo interactions, disguises, colony events, and race completion.

**Completion:** no unintended prototype visuals remain, and the redesign preserves gameplay and network behavior.

### Step 5 — Finish presentation and deliver

**Goal:** close visual defects and package a coherent release.

**Deliverables:**

- Final lighting, animation timing, material cleanup, and UI alignment.
- Completed Standard, Enhanced, and Android configurations.
- Desktop exports and an Android build for functional device validation.
- Final screenshots, asset documentation, licenses, and known-issue register.
- Completed applicable regression checks.

**Astra verifies:** final visual consistency, readable gameplay at 720p, polished transitions, touch composition, and faithful quality variants.

**GLM verifies:** export startup, missing-resource and shader errors, input, safe areas, mode unloading behavior, and full LAN progression. Android support is described according to completed functional device checks.

**Completion:** the approved redesign is integrated and packaged, with material issues resolved or explicitly recorded. No benchmark, thermal report, or performance-baseline artifact is required.

## 7. Concept-art prompts

**The six existing concept-art prompts stand unchanged.**

The renderer revision changes how the established appearance is implemented. The prompts already call for tactile miniature materials, rounded geometry, carefully composed light, readable silhouettes, and polished character presentation. Standard 2K materials and selective dynamic shadows make those targets more directly attainable without changing their subject or style.

Retain the existing prompts for:

1. Office chair race heroes.
2. Four-story Evacuation lobby.
3. Shop & Seek supermarket.
4. Pizza Colony environment.
5. Office PBR material direction.
6. Main-menu composition.

The material-sheet prompt remains a visual reference brief, not a specification for automatically usable PBR maps. No revised image prompts are needed.
