# Friday 5PM: Evacuation

> It's 4:59 PM Friday. Race your office chair to the parking lot. Last one buys beers.

A comedic multiplayer office-chair physics game built with Godot 4.7.1. Cross-platform support: macOS ARM, Windows, Linux, Android, iOS, and Web.

**Play in browser:** https://friday-evacuation.vercel.app (touch controls appear automatically on phones)

## Quick Start

### From Scratch

1. Install Godot 4.7.1:
   - macOS: `brew install --cask godot`
   - Download: https://godotengine.org/download

2. Clone and open:
   ```bash
   git clone https://github.com/jiracipika/friday-evacuation.git
   cd friday-evacuation
   open -a Godot project.godot  # macOS
   # Or: File → Open → Select project.godot in Godot editor
   ```

3. Press F5 or click "Play Scene" to start.

### Downloads

CI builds fresh artifacts on every push to `main` (see the `continuous` prerelease): macOS zip, Android APK, and a web build. The APK is debug-signed — install it directly; macOS builds are ad-hoc signed (right-click → Open on first launch).

### Controls

Before every match, a briefing screen shows the full control map and pauses the game until you hit **I AGREE**. A quick recap also plays during the countdown. The active scheme (keyboard vs controller) is highlighted automatically based on the last device you touched.

**Keyboard & Mouse:**
- WASD / Arrow Keys: Move (camera-relative)
- Mouse: Camera pan (when enabled in Settings)
- Space / Left Mouse: Boost (Coffee power-up; hold to sustain)
- E / Middle Mouse: Jump — also GRAB power-ups (press E in range when the key prompt appears)
- Q / Right Mouse: Place sabotage item; seeker scan in Shop & Seek
- R + Y: Recenter camera
- Esc: Pause menu

**Controller (any pad):**
- Left stick: Move (response curve configurable: Linear / Expo / Precision)
- A/Cross: Boost — **RT/R2 analog trigger scales boost strength with pressure**
- X/Square: Jump / grab / interact
- B/Circle: Sabotage / scan
- Right stick / shoulders: Camera
- Start: Pause
- Rumble: boost hum, impact thump, hard-landing sputter (Settings toggle)

Buttons can be remapped in Settings. Sensitivity, stick curves, and invert-pan are all adjustable and persist.

**Touch (Mobile/Web):**
- Virtual joystick: Move
- BOOST / JUMP / TRAP buttons; power-ups auto-collect (no spare thumb needed)
- Auto-detects touchscreens; force on/off from the main menu's TOUCH button

## Game Modes

1. **Evacuation** (Primary): Race through a 4-floor office to the parking lot exit. Ride elevator pads floor-to-floor, grab coffee boosts (E to grab!), dodge Roombas, swinging doors, falling debris, and periodic fire drills. Coffee boosts, sabotage traps, 120s timer. Land an elevator jump dead-center for a perfect-landing boost bonus.

2. **Hauled**: Three-round physics delivery with six hostile cargo types (fridge of bees, haunted sofa...), damage/scoring, grab/throw, and rotating terrain gauntlets.

3. **Shop & Seek**: Shopper fallback with a five-item list and patrol guard, plus hider disguises (freeze as a product with a wobble tell), seeker scans, infection-ready role state, 24 product variants, and a full supermarket layout.

4. **Pizza Colony**: Zoned giant pizza (crust/cheese/sauce), claim pepperoni pads by standing on them, harvest cheese, build olive-bomb forts, dodge the chef patrol and the accelerating cutter sweep. Win by owning all pads or surviving 120s.

## Map Layouts (Evacuation)

Pick from the main menu's MAP button; the pick persists:
- **Open Plan** — the classic: scattered desks, wide corridors
- **Cubicle Maze** — dense floor-1 cubicle grid, narrow lanes, more power-ups
- **Executive Suite** — long sightlines, few obstacles, wide ice patch, extra crates

In LAN play the **host's pick is authoritative** — everyone races the host's map, and your own saved pick stays untouched for when you host.

## Race Modifiers

"TODAY'S OFFICE CHAOS" chips on the main menu toggle single-player modifiers (time attack, low gravity, ice rink, and more) with a live summary line. Combinations persist between sessions.

## Multiplayer

### Local Wi-Fi (LAN)

**Host:**
1. Main menu → "HOST LOCAL" — your LAN address is shown in the lobby ("your address: 192.168.x.x")
2. Friends scan, or type your address directly
3. Everyone readies up; host starts the match

**Join:**
1. Main menu → "JOIN LOCAL"
2. "SCAN LOCAL WI-FI" to discover hosts, or type the host's address
3. Ready up and wait for host to start

**Hotspot mode (no Wi-Fi):** one player hosts over a phone hotspot. Joiners get one-tap buttons for the common hotspot gateway addresses (Android `192.168.43.1` / `192.168.49.1`, iPhone `172.20.10.1`); discovery falls back to a subnet sweep when hotspot AP-isolation blocks broadcasts.

**In lobby & in match:** chat overlay, name + color identity, live roster with ready states. Traps, pickups, and stuns replicate to all peers. Late joiners drop straight into a running match.

**Requirements:**
- All players on the same Wi-Fi network (or one phone's hotspot)
- macOS may ask for firewall permission for UDP ports 5005/5006
- Host and clients need compatible Godot version (4.7.1)

## Performance Settings

Optimized for mobile performance and the MacBook Air baseline. Adjust in Settings:

- **Low**: Disabled fog, reduced particles, baseline ambient
- **Medium**: Enabled fog, standard particles
- **High**: Enabled fog + glow, full particles, enabled shadows

Distant floors are culled automatically during races (adjacent floors drop their dynamic lights). Default is optimized performance (Low/Medium baseline).

## Project Structure

```
friday-evacuation/
├── project.godot           # Project metadata and config
├── export_presets.cfg      # macOS / Android / Web export presets
├── scenes/                 # Scene files (.tscn)
│   ├── Main.tscn          # Main menu
│   ├── Evacuation.tscn    # Primary race mode
│   ├── Hauled.tscn        # Cargo delivery
│   ├── ShopSeek.tscn      # Grocery hide & seek
│   ├── PizzaColony.tscn   # Pizza survival
│   └── objects/           # Reusable objects
│       └── SabotageTrap.tscn
├── scripts/                # GDScript logic
│   ├── GameManager.gd     # Global state and mode enum
│   ├── Network.gd         # LAN multiplayer and ENet (roster, chat, world sync, layout sync)
│   ├── AudioManager.gd    # Procedural audio and bus control
│   ├── PlayerChair.gd     # Player physics controller (drift, brake, boost, mash-recover)
│   ├── Evacuation.gd      # Primary mode logic
│   ├── LevelLayouts.gd    # Map layout data tables (Open Plan / Cubicle Maze / Executive)
│   ├── InputPrefs.gd      # Input settings: sensitivity, schemes, remaps, rumble
│   ├── Lobby.gd          # Multiplayer lobby
│   ├── MobileControls.gd # Touch controls
│   └── ...
├── .github/workflows/      # CI: exports + Vercel deploy on push
└── ROADMAP.md            # Detailed implementation roadmap
```

## Development

### Running Tests

The full serial verification ladder (32 suites):

```bash
bash scripts/run_ladder.sh
```

Individual suites (all under `scripts/`):

```bash
godot --headless --path . --script scripts/BootTest.gd        # compile + scene loads
godot --headless --path . --script scripts/NetworkTwoPeerTest.gd  # real ENet host+client
godot --headless --path . --script scripts/LevelClearTest.gd  # bot drives floor 1 → exit
bash scripts/run_multiplayer_sync_test.sh                     # two-process sync (gold standard)
godot --headless --path . --quit-after 3                      # full project boot
```

### Architecture

**Autoloads:**
- `GameManager`: Mode selection, player data, global state
- `Network`: LAN discovery, ENet hosting/joining, roster, ready-state, chat, world-event replication, host-authoritative match start (carries the host's map layout)
- `AudioManager`: Pooled procedural audio, AudioServer bus control

**Key Design Decisions:**
- Procedural generation over external assets (meshes, materials, textures — including runtime normal maps — and audio)
- Stable cross-platform GL Compatibility renderer with expensive effects gated by quality settings
- Frame-rate independent smoothing (exponential lerp with delta)
- Host-authoritative LAN multiplayer: roster/readiness/match-start/layout are server-authoritative; player movement is unreliable-snapshot with interpolation
- Reusable UI components (`ModeHUD`, `ModeCard`, `Lobby`, `PreMatchModal`)
- LAN multiplayer before Steam integration

### Contributing

1. `git pull --ff-only` before starting work
2. Always run the ladder after changes
3. Work on `main` branch
4. Commit with descriptive messages
5. Push after verifying

## Known Limitations

- Steam integration is deferred — LAN is the current multiplayer focus
- Real-device mobile QA not yet performed (touch layout, controller feel, rumble)
- Two-machine Wi-Fi QA pending over real hardware (software-verified via loopback two-process tests)
- Procedural character/prop art is intentionally lightweight and can be replaced by authored assets later

## License

Private repository — jiracipika/friday-evacuation

## Credits

Built with Godot 4.7.1. Procedural content, design, and development by Hermes Agent. Additional polish and visual treatment by GLM 5.2.

---

**Current Version:** 0.1.0  
**Godot Version:** 4.7.1  
**Status:** All four modes have playable, software-verified loops; LAN multiplayer verified in-process (roster/chat/world sync/layout sync); real-device and two-machine LAN QA pending
