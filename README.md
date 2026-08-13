# Friday 5PM: Evacuation

> It's 4:59 PM Friday. Race your office chair to the parking lot. Last one buys beers.

A comedic multiplayer office-chair physics game built with Godot 4.7.1. Cross-platform support: macOS ARM, Windows, Linux, Android, iOS.

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

### Controls

**Desktop:**
- WASD / Arrow Keys: Move
- Space: Boost (Coffee power-up)
- E: Jump
- Q: Place sabotage trap
- Esc: Menu

**Touch (Mobile):**
- Virtual joystick: Move
- Boost button: Coffee power-up
- Jump button: Jump

## Game Modes

1. **Evacuation** (Primary): Race through a 4-floor office to the parking lot exit. First to reach wins. Coffee boosts give speed, sabotage traps stun opponents.

2. **Hauled**: Co-op delivery of hostile cargo (fridge of bees, haunted sofa). Deliver cargo to zones within 180 seconds.

3. **Shop & Seek**: Supermarket hide & seek as groceries. Find 6 targets within 60 seconds.

4. **Pizza Colony**: Survival on giant pizza as toppings. Claim territory and survive for 90 seconds.

## Multiplayer

### Local Wi-Fi (LAN)

**Host:**
1. Open main menu
2. Click "HOST LOCAL"
3. Other players on same Wi-Fi can scan and join
4. Host controls match start

**Join:**
1. Open main menu
2. Click "JOIN LOCAL"
3. Click "SCAN LOCAL WI-FI" to discover hosts
4. Select a host and click "JOIN"
5. Wait in lobby until host starts match

**Requirements:**
- All players on same Wi-Fi network
- macOS may ask for firewall permission for UDP ports 5005/5006
- Host and clients need compatible Godot version (4.7.1)

### Direct IP Join

1. Open main menu
2. Click "JOIN LOCAL"
3. Enter host's local IP (e.g., `192.168.1.5:5005`)
4. Click "JOIN"

## Performance Settings

The game is optimized for mobile performance. Adjust in Settings:

- **Low**: Disabled fog, reduced particles, baseline ambient
- **Medium**: Enabled fog, standard particles
- **High**: Enabled fog + glow, full particles, enabled shadows

Default is optimized performance (Low/Medium baseline).

## Project Structure

```
friday-evacuation/
├── project.godot           # Project metadata and config
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
│   ├── Network.gd         # LAN multiplayer and ENet
│   ├── AudioManager.gd    # Procedural audio and bus control
│   ├── PlayerChair.gd     # Player physics controller
│   ├── Evacuation.gd      # Primary mode logic
│   ├── HUD.gd            # In-match HUD
│   ├── Settings.gd       # Settings and graphics quality
│   ├── Lobby.gd          # Multiplayer lobby
│   ├── MobileControls.gd # Touch controls
│   ├── ModeHUD.gd        # Secondary-mode HUD
│   └── ...
├── GLM_HANDOFF.md         # Development handoff for GLM polish
└── ROADMAP.md            # Detailed implementation roadmap
```

## Development

### Running Tests

```bash
# Script compilation and scene loading
godot --headless --script scripts/BootTest.gd

# Local ENet multiplayer verification
godot --headless --path . --script scripts/NetworkSmokeTest.gd

# Secondary mode runtime instantiation
godot --headless --path . --script scripts/ModeSmokeTest.gd

# Full autoload-enabled project boot
godot --headless --path . --quit-after 3
```

### Architecture

**Autoloads:**
- `GameManager`: Mode selection, player data, global state
- `Network`: LAN discovery, ENet hosting/joining, roster, ready-state
- `AudioManager`: Pooled procedural audio, AudioServer bus control

**Key Design Decisions:**
- Procedural generation over external assets (meshes, materials, textures, audio)
- Mobile-first rendering (Mobile renderer, disabled expensive effects)
- Frame-rate independent smoothing (exponential lerp with delta)
- Pooled audio players to avoid per-sfx node overhead
- Reusable UI components (`ModeHUD`, `ModeCard`, `Lobby`)
- LAN multiplayer before Steam integration

### Contributing

1. `git pull --ff-only` before starting work
2. Always run tests after changes
3. Work on `main` branch
4. Commit with descriptive messages
5. Push after verifying

## Known Limitations

- Steam integration is deferred — LAN is the current multiplayer focus
- Real-device mobile testing not yet performed
- Two-machine Wi-Fi testing pending (bugs may exist in firewall/reachability)
- Procedural assets may be replaced with polished art by GLM 5.2

## License

Private repository — jiracipika/friday-evacuation

## Credits

Built with Godot 4.7.1. Procedural content, design, and development by Hermes Agent. Additional polish and visual treatment by GLM 5.2 (in progress).

---

**Current Version:** 0.1.0  
**Godot Version:** 4.7.1  
**Latest Commit:** 258a1b1 (Performance and playability optimizations)  
**Status:** Playable single-player and LAN multiplayer; polish and visual treatment ongoing