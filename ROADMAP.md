# FRIDAY 5PM: EVACUATION — Development Roadmap

## Current State (Phase 0 — COMPLETE)
- Godot 4.7 project, cross-platform config (PC/Mac ARM/Android/iOS/Web)
- 4 game modes: Evacuation (primary, playable), Hauled/ShopSeek/PizzaColony (stubs)
- Player controller: WASD movement, boost, jump, sabotage traps, stun system
- Smooth chase camera with velocity-aware trailing
- Procedural 4-story office building with ramps, desks, power-ups
- Multiplayer networking layer (ENet, not yet wired)
- Headless test suite (12/12 passing)

---

## Phase 1: Visual Identity & Atmosphere
**Goal: Make it look like a real game, not grey boxes**

### 1A: Material & Lighting Overhaul
- Replace flat StandardMaterial3D with proper PBR materials
  - Floors: carpet texture (procedural noise normal map), tile for bathrooms
  - Walls: drywall with subtle color per floor theme
  - Desks: wood grain procedural
- Add Environment fog (already stubbed) with exponential density
- Add point lights: fluorescent ceiling strips per floor (omni lights in a grid)
- Screen-space reflections on polished floors (if renderer supports)
- Contact shadows under player and objects

### 1B: Office Chair Model
- Build a proper office chair in Blender or construct from primitives in code:
  - Seat (cushion), backrest, gas cylinder stem, 5-star wheel base, 5 castor wheels
  - Wheels should visually spin and steer based on velocity
  - Slight bounce/squash on landing from jumps
  - Lean back slightly when boosting (visual feedback)
- Alternative: use a free CC0 chair GLB from Kenney.nl or similar

### 1C: Post-Processing
- Enable bloom on boost particles, power-up orbs, exit zone
- Vignette for focus
- Slight chromatic aberration during boost (speed effect)
- Motion blur when boosting (if performant on mobile)
- Color grading: warm orange tint (end-of-workday vibe)

---

## Phase 2: Animation & Game Feel
**Goal: Juicy, satisfying movement and feedback**

### 2A: Player Animations
- Squash & stretch on jump (stretch up) and land (squash flat)
- Chair wheelie when boosting (front lifts slightly)
- Spin-out animation when stunned (chair rotates wildly)
- Screen shake on: heavy landing, hitting walls at speed, getting stunned
- Camera FOV kick: widen FOV slightly during boost for sense of speed

### 2B: Particle Systems
- Boost trail: orange/yellow speed lines behind chair
- Dust/skid marks when stopping hard or turning sharply
- Confetti explosion at exit zone when someone finishes
- Trap spawn poof (dust cloud when dropping sabotage)
- Coffee splash particles when collecting power-up

### 2C: Audio (SFX + Music)
- SFX: chair rolling (loop, pitch scales with speed), boost whoosh, 
  jump spring, land thud, trap bonk/slip, power-up collect ding,
  wall bonk, countdown beeps, GO horn, victory fanfare
- Music: upbeat funky office elevator music (royalty-free or generated)
- Duck music volume during countdown for tension
- 3D positional audio for traps and other players

---

## Phase 3: UI/UX Polish
**Goal: Professional menus and HUD**

### 3A: Main Menu Redesign
- Animated background (slowly rotating 3D office chair, or gameplay footage)
- Big bold title with subtitle cycling through mode descriptions
- Mode cards with icons/illustrations instead of plain buttons
- Settings button (graphics quality, audio, controls)
- Credits screen
- Version number in corner

### 3B: In-Match HUD
- Speedometer (km/h, office chair themed)
- Boost cooldown indicator (coffee cup filling up)
- Minimap showing floor layout, your position, exit zone, other players
- Position indicator (1st/2nd/3rd etc. in multiplayer)
- Sabotage trap cooldown
- Lap/checkpoint progress through floors

### 3C: Results Screen Overhaul
- Animated podium with player names
- Race stats: time, top speed, traps hit, traps placed
- "Beer owed" tally for last place
- Rematch / Change Mode / Main Menu buttons with animations
- Confetti and screen shake on winner reveal

### 3D: Settings Menu
- Graphics quality: Low / Medium / High (toggles shadows, particles, SSAO)
- Master / Music / SFX volume sliders
- Sensitivity slider (for future camera control)
- Key rebinding display
- Toggle: screen shake, motion blur, particles amount

---

## Phase 4: Gameplay Depth — Evacuation Mode
**Goal: Make the primary mode genuinely fun and replayable**

### 4A: Level Design
- Design 3-5 hand-crafted floors with distinct themes:
  - Floor 1: Cubicle farm (maze of desks, tight turns)
  - Floor 2: Open office with water cooler traps and carpet vs tile (speed difference)
  - Floor 3: Stairwell chaos (spiral ramps, handrails to grind)
  - Floor 4: Cafeteria (slippery floor, tables to weave)
  - Floor 5 (exit): Parking lot with cars as obstacles
- Checkpoint system: must pass through specific zones per floor
- Shortcut paths for skilled players (ramps, jumps over railings)

### 4B: Power-Up Variety
- Coffee (speed boost) — existing
- Energy Drink (mega boost, longer duration, screen shake)
- Office Supplies (drop a stapler bomb that launches nearby players)
- Spilled Coffee (create a slip zone, wider than regular sabotage)
- Printer Paper (blind nearby players with paper airplanes)
- Fire Extinguisher (freeze/stun all players within radius for 2s)

### 4C: Dynamic Hazards
- Moving elevator platforms between floors
- Swinging doors that bash players
- Collapsible ceiling tiles (falling debris)
- Rogue Roomba (NPC that wanders and stuns on contact)
- Fire drill alarm (strobe lights, periodically narrows paths)

### 4D: Match Modes Within Evacuation
- Classic Race (first to exit wins)
- Time Trial (beat your best time, ghosts)
- Last One Standing (floor collapses behind you, don't fall)
- Beer Run (collect 6 beer cans scattered across floors, then exit)

---

## Phase 5: Multiplayer
**Goal: Play with friends over LAN/internet**

### 5A: Core Netcode
- Wire Network.gd ENet to actual player sync
- RPC calls for: position, rotation, velocity, boost state, trap placement
- Interpolation for remote players (smooth their movement)
- Lobby system: host creates, friends join by IP
- Player name + color selection in lobby
- Ready check system

### 5B: Multiplayer UI
- Host/Join screen with IP entry
- Lobby showing connected players
- Ping indicator
- Disconnect handling (graceful when someone leaves)
- Chat (simple text overlay)

### 5C: Steam Integration (optional, stretch)
- Steamworks plugin for Godot (matchmaking, invites, Steam lobby)
- Friend join via Steam overlay

---

## Phase 6: Secondary Modes — Full Implementation
**Goal: Make all 4 modes genuinely fun**

### 6A: HAULED — Physics Delivery
- Grab/throw mechanics for cargo (hold E to grab, release to throw)
- Cargo with personality: bees swarm and stun, haunted sofa drags you,
  vending machine randomly launches cans at nearby players
- Terrain: spinning hallways, conveyor belts, escalators going wrong way
- Drop zone with scoring: more money for gentle delivery
- Co-op: some cargo requires 2+ players to carry

### 6B: SHOP & SEEK — Hide & Seek
- Prop disguise system: press E near an object to disguise as it
- Shopper role: given a shopping list, must collect real items
- Seeker role: must identify disguised players among real objects
- 60-second timer, point scoring
- Abilities: seeker can "scan" (briefly highlights fakes), hiders can reposition

### 6C: PIZZA COLONY — Survival
- Territory capture (stand on pepperoni to claim it)
- Chef NPC with giant pizza cutter (rotating blade sweeps across pizza)
- Resource gathering: harvest cheese, collect toppings for power-ups
- Build forts from crust fragments
- Cheese melting zones (slow movement)
- Oven heat waves (damage over time in certain areas)

---

## Phase 7: Mobile & Cross-Platform
**Goal: Ship on Android, iOS, Mac**

### 7A: Mobile Controls
- Virtual joystick (left thumb) for movement
- Buttons (right thumb): Boost, Jump, Sabotage
- Touch-responsive UI (larger tap targets)
- Gyroscope option: tilt to steer
- Haptic feedback on boost, stun, trap hit

### 7B: Export Configuration
- Android: configure export_presets.cfg (API level, architecture ARM64)
- iOS: configure export (provisioning profile, signing)
- macOS: codesign + notarize for ARM
- Web: HTML5 export with mobile touch support
- App icons for all platforms

### 7C: Performance Optimization
- LOD (Level of Detail) for distant objects
- Occlusion culling
- Reduce shadow distance on mobile
- Particle count scaling based on device tier
- 30fps cap option on mobile (battery saving)

---

## Phase 8: Polish & Ship
**Goal: Release-ready**

### 8A: Meta Progression
- Unlockable chair skins (racing chair, bean bag, toilet, exercise ball)
- Unlockable player colors/patterns
- Stats tracking: races won, beers owed, traps landed
- Achievements

### 8B: Accessibility
- Colorblind mode
- Subtitles for audio cues
- Adjustable game speed (0.75x, 1x, 1.25x)
- Toggle for screen shake and flash effects

### 8C: Final Polish
- Loading screen with tips ("Press Q to ruin someone's day")
- Pause menu (resume, settings, quit)
- Reconnect handling for dropped multiplayer sessions
- Crash reporter
- Credits with funny "inspired by real Friday afternoons" text

---

## PRIORITY ORDER FOR EXECUTION
1. Phase 1A+1B — Visual identity (biggest "wow" per effort)
2. Phase 2A+2B — Animation & game feel (makes it fun to just move around)
3. Phase 3A+3B — Menu & HUD polish (professional feel)
4. Phase 4A — Level design (makes Evacuation replayable)
5. Phase 5A — Multiplayer (play with friends = core value prop)
6. Phase 1C + Phase 2C — Post-processing & audio (atmosphere)
7. Phase 4B+4C — Power-ups & hazards (variety)
8. Phase 7A — Mobile controls (platform expansion)
9. Phase 6 — Secondary modes (content breadth)
10. Phase 8 — Polish (ship quality)
