# Step 1 — Astra design package status

Date: 2026-09-14. Owner: Astra. State: complete design handoff; implementation remains GLM's work.
Binding authority: [REDESIGN-PLAN-v2.md](../REDESIGN-PLAN-v2.md).
No scripts, scenes, project settings, runtime assets, or engine processes were changed by this delivery.
This is an authored specification, not a claim that the redesigned game is already implemented.

## Deliverables

| Deliverable | Status | One-line decision summary |
|---|---|---|
| [ART-BIBLE.md](ART-BIBLE.md) | Complete | Quiet tactile surfaces, amber key/cool fill, adult miniature proportions, bounded expressive motion. |
| [MODEL-SHEETS.md](MODEL-SHEETS.md) | Complete | Eight preserved roster silhouettes, nine session badges, 35k/11k/3.4k actor LODs and per-prop ceilings. |
| [EVACUATION-COMPOSITION.md](EVACUATION-COMPOSITION.md) | Complete | Four-story edge atrium, retained ascending lift progression, architectural switchbacks, dominant elevated parking exit. |
| [MODE-IDENTITIES.md](MODE-IDENTITIES.md) | Complete | Four distinct material/shape identities with explicit hazard, cargo, disguise, and territory readability contracts. |
| [UI-LAYOUTS.md](UI-LAYOUTS.md) | Complete | Noto Sans, 40% desktop navigation, consolidated HUD, in-place ResultsPanel restyle, safe-area touch layouts. |
| [PRESETS.md](PRESETS.md) | Complete | Exact Forward+/Compatibility flags, 2 GiB desktop allocation, 512 MiB Android allocation, immutable competitive visibility. |
| [STATUS.md](STATUS.md) | Complete | Handoff decisions, integration questions, and document verification scope. |

## Resolved continuity decisions

Plan v2 supersedes the old neon palette, fallback-font rule, and desktop Compatibility renderer.
The roster retains all eight IDs, names, roles, personality cues, and existing gameplay skin behavior.
The approved concept images remain visual references, not runtime-ready materials or engine evidence.
The parent review is answered with low-frequency surfaces, directional lighting, authored prop silhouettes, and aligned HUD groups.
Existing solid slabs and story-03 gaps remain intact; the atrium occupies a facade edge court.
The actual route goes upward to the story-04 parking deck; no inverted progression is implied.
Switchback stairs are architectural identity beside accessible chair lifts, not newly promised stair-driving physics.
The current Shop & Seek shopper fallback is labeled honestly; future roles do not become shipping claims.
Nine badge slots cover eight network clients plus host without increasing configured occupancy.
Enhanced keeps SDFGI, SSR, volumetric fog, SSAO, and SSIL off, just like Standard.
Shop & Seek disables dynamic directional shadows on all presets for stock/disguise parity.

## Answers to GLM's implementation backlog

The independently present GLM-BACKLOG.md is GLM-owned and was not edited or included in Astra's commit.
Its assumption that Enhanced enables expensive effects is superseded by PRESETS section 2.
Its suggested Mobile renderer fallback must not replace the binding Android Compatibility configuration.
Fixed-versus-procedural treatment is resolved in PRESETS section 11, with authored fallback until exact bake data exists.
Per-prop triangle budgets are specified in MODEL-SHEETS section 11.
Android runtime textures are 512–1024 maximum for 3D assets, derived from shared desktop sources.
No instruction in the backlog adds a measurement phase to this design handoff.

## Open implementation questions for GLM

These require repository/toolchain facts, not additional visual-policy invention.
They do not block completion of Astra's Step 1 package.

1. Which exact static layout signatures will GLM prepare as bakeable assemblies first?
   Use the approved ambient/vertex/contact fallback until matching data exists.
2. Does the existing actor collision envelope require more than 5% uniform scaling of the neutral sheet?
   Preserve colliders and report the required scale; do not distort body parts independently.
3. Can the existing culling registry retain separate facade shells and landmarks while hiding room detail?
   Preserve the four-story composition using separate visual groups within the stated triangle ceiling.
4. Are all secondary-mode action/state hooks exposed to ModeHUD and touch controls?
   Report missing hooks; retain current capability labels and do not infer new multiplayer support.
5. Does the installed Godot patch expose every specified shadow/filter control under the expected property names?
   Map supported controls to the specified appearance; report any appearance-changing constraint to Astra.

## Delivery verification

Package length is within the requested approximately 1500–3000 lines.
Local Markdown links, required deliverable names, allocation sums, and whitespace were checked statically.
The actor triangle envelope and 2048/512 MiB residency tables balance by construction.
Commit scope is limited to the seven requested Astra Markdown files; staging was blocked.
No Godot run, image generation, build, benchmark, or runtime measurement was performed.
Commit message: `docs(astra): Step 1 design package — art bible, model sheets, compositions, UI layouts, presets`.

## Commit blocker

The sandbox rejected Git creation of `.git/index.lock` with `Operation not permitted`.
The session grants read-only access to `.git` and does not permit approval escalation.
No commit was created; the seven design documents remain available in the working tree.
Commit only the seven deliverables above, excluding the independently authored GLM-BACKLOG.md.
