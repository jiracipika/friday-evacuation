# Friday 5PM overhaul

Approved direction: polished stylized office; skillful party chaos; desktop/browser first;
Evacuation followed by the other modes; four solo AI rivals and time trials;
balanced starter handling classes; native LAN and solo browser play.

## Delivery checklist
- [x] Shared command-driven motor, handling profiles, input and separate versioned saves.
- [x] Authored modular coworker/chair meshes, animation rig, office kit and asset audit.
- [x] Authored descending course graph: Open Plan, Cubicle Maze, Executive Suite.
- [x] Race director, rivals, checkpoints, hazards/items, ghosts and versioned records.
- [x] Host simulation, prediction/reconciliation, snapshots, protocol checks, late joins.
- [x] New launch, wardrobe, HUD, onboarding, camera, audio and accessible controls.
- [x] Hauled, Shop & Seek and Pizza Colony on the shared gameplay/presentation layer.
- [x] Browser/native export, touch controls, geometry LODs and offline baked lighting.
- [x] Automated game/LAN checks and real-renderer captures. See verification notes.

## Packaging decision
All four modes share almost their entire art kit. They fit together within a
50 MiB browser bundle, including the engine and three baked courses, so this
release uses one shared pack. Splitting that small shared payload into mode
downloads would duplicate the kit and introduce extra loading failures.
Only the selected world is instantiated. Legacy scenes remain test fixtures.

## Deliberate boundaries
Browser play is solo; ENet LAN parties use the desktop app. Online rooms,
internet NAT traversal and ranked competition are outside this release.
Touch controls are provided; phone performance and usability still need
real-device QA. M1 Air 720p/60 and older-device 30 fps remain measured-device
targets, rather than claims based on cloud software rendering.

Hardware and human-playtest goals remain targets until measured on actual devices.
Cloud software-renderer captures cannot certify M1/phone performance or subjective fun.
Existing scenes/tests remain regression fixtures while the new launch becomes the entrypoint.
