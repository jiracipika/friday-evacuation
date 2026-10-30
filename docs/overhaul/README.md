# Friday 5PM: After Hours overhaul

The launch screen now opens a shared driving game with eleven customizable,
animated office coworkers, three starter handling classes and six cosmetic
chair designs. The three Evacuation courses descend through four office wings
on continuous ramps, with checkpoints, desk-hop shortcuts, coffee, items,
moving hazards and four AI opponents by default. Normal AI rounds take about
two minutes. Time trials use fixed hazards and versioned personal-best ghosts.

Hauled delivers three physical cargo types through a loading bay, with optional
AI helpers. Shop & Seek has a solo shopping list/security patrol and a LAN
prop-disguise/scanner game. Pizza Colony adds claimable territory, cheese forts,
a telegraphed cutter and a chef. All modes use the same movement and LAN state
authority. Career wins keep unlocking cosmetics; cosmetics do not alter physics.

## Play and build

Tested with **Godot 4.6.3**. Open `project.godot` and run the project. The runtime
uses GL Compatibility on desktop and browser. Existing identity, cosmetic and
career saves are retained; new course records live in `user://friday_v2.cfg`.

```sh
godot --headless --editor --path . --import --quit
godot --path .
godot --headless --path . --export-release Web builds/friday-evacuation-web/index.html
godot --headless --path . --export-release Linux builds/friday-evacuation-linux.x86_64
```

Install the matching official export templates first. Serve the web export over
HTTP(S), with WebAssembly MIME support. Enable normal HTTP compression for a
smaller transfer. The web build is single threaded and needs no COOP/COEP headers.

Controls: WASD/arrows or left stick steer; Space/A boosts; Shift/LT drifts or
brakes; E/X hops or interacts; Q/B uses an item; Escape/Start pauses. Right stick
or shoulder controls orbit the camera; R/Y recenters it. Settings retain input
remapping, response curves, audio, captions, reduced motion and high contrast.
Touch devices receive movement and action buttons.

For LAN, use **Party** in desktop builds. Choose a name and appearance under
**Coworker**, host or enter the host's local address, then mark every guest ready.
The game supports eight chairs, filling available slots with the selected AI
count. Shop & Seek requires two humans. Gameplay uses UDP 5007; discovery uses
UDP 5008/5009. Incompatible protocol versions receive a refusal message.

## Assets and offline lighting

The Blender authoring script is the source for the coworker rig, modular hair,
faces, outfits and props, furniture, cosmetic chairs, pizza and chef hat. It emits
optimized GLBs. Six animation states cover idle, push, boost, air, landing and
stun. The imported NVIDIA chair is attributed in-game and in
[`third_party/nvidia`](../../third_party/nvidia/README.md), with an immutable
source manifest and the original CC BY 4.0 license.

```sh
python3 tools/overhaul/fetch_nvidia_chair.py
blender -b --python tools/overhaul/build_assets.py
python3 tools/overhaul/bake_courses.py
```

Use an official Blender build with USD import support. Baked course scenes carry
their UV2 unwraps, static geometry, lightmap atlases and metadata used to restore
dynamic coffee/hazard nodes. Baking requires a Vulkan-capable Godot editor and
a display; runtime GL Compatibility reads the saved result. Re-bake after
changing static course geometry or materials. Generated fallback geometry remains
available when opening a source checkout before bakes exist.

## Verification

```sh
bash scripts/run_ladder.sh
python3 tools/overhaul/verify.py
python3 tools/overhaul/check_network.py hauled
python3 tools/overhaul/check_network.py seek
python3 tools/overhaul/check_network.py pizza
godot --headless --path . --fixed-fps 60 --script tools/overhaul/SimulationCheck.gd -- open_plan hard --test-mode
godot --headless --path . --fixed-fps 60 --script tools/overhaul/SimulationCheck.gd -- open_plan trial --test-mode
```

The new checks exercise actual movement/interaction paths through complete
cargo deliveries, a complete shopping list, territory claims and bounded rounds;
all AI finish all three courses. Separate processes check authoritative movement,
prediction settling, joining an active race, readiness, and version refusal.
Avatar checks cover all 66 character/chair combinations, modular visibility,
animation states and the 20,000-triangle budget. The largest combination is
15,542 triangles; chair LODs are 5,498 / 2,638 / 1,538 triangles.

The existing 81-suite ladder passed; affected settings/accessibility suites were
re-run after the integration changes. Native OpenGL captures and a Chromium
WebGL run provide rendering/export evidence. Godot's known ObjectDB shutdown
warning is present in some headless probes; script errors fail verification.

Device frame-rate targets, real router/firewall discovery, real gamepads/phones
and subjective multiplayer balance still need hardware and human playtesting.
These limits do not have passing hardware claims attached to them.
