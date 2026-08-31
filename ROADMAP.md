# FRIDAY 5PM: EVACUATION — Development Roadmap

## Input Overhaul v2 (commit pending, Aug 29 2026) — COMPLETE
User asked: lower sens further, full keyboard+mouse support, remember device
selection with easy switching, easy controller configuration, controls recap
at the start of every round.
- **Sens defaults lowered again**: keyboard 0.7 → **0.55** (range now
  0.35–1.5), mouse/stick 1.0 → **0.8**. One-time cfg migration
  (`sens_migration_v2` flag) moves ONLY values still on old defaults;
  personalized settings untouched.
- **Full KB+M**: RMB = sabotage, MMB = action/jump (LMB boost + mouse orbit
  already existed). New `recenter_camera` action (R + Y/Triangle) wired in
  all 4 modes.
- **Scheme memory**: `control_scheme` = auto | keyboard_mouse | controller
  persisted in cfg. AUTO tracks whichever device was actually touched last
  (`last_device`, written deferred to avoid cfg IO in input handlers);
  stick-drift (<0.25) filtered. Controller scheme runs FULL chair accel
  (stick = finesse); keyboard scheme applies the gentler scale.
- **Easy controller config**: Settings → CONTROLLER BUTTONS section with
  per-action remap chips (tap row, press pad button; any key cancels) +
  RESET TO DEFAULT. `InputPrefs.set_pad_button()` rewrites the InputMap
  live; overlay/HUD labels are remap-aware via `pad_button_name()`.
  INVERT CAMERA PAN toggle added too.
- **ControlsOverlay.gd** (CanvasLayer 30): two-column CONTROLS recap
  (KEYBOARD & MOUSE vs CONTROLLER) shown at EVERY round start in all 4
  modes (7s, fades; reduced-motion = instant hide). Active scheme column
  highlighted; re-highlights LIVE if the player flips device mid-display.
  Doubles as the scheme-detection feed (`_input` → `note_device`) for the
  whole mode session.
- Tests: InputPrefsSmokeTest 56 checks (scheme/remap/invert/migration),
  ControlsOverlaySmokeTest 24 (mount dedupe, columns, live flip,
  auto-hide, all 4 modes trigger at round start), GamepadSupportTest 43
  (RMB/MMB/LMB/R/Y bindings + remap-aware live rewrite). Settings.gd
  added to BootTest compile list (was missing — let a parse error slip).
- GOTCHAs learned this slice:
  - `is_action_just_pressed` edge vs physics tick race: a synthesized
    `Input.parse_input_event` can land between physics ticks headlessly
    and the edge disappears (flake ~40%). Drive edges with
    `Input.action_press()` in tests; also `physics_frame` awaits fire
    BEFORE node `_physics_process` of that tick — await TWO frames.
  - Settings._apply_settings saves its whole local ConfigFile snapshot —
    after a remap, sync `config.set_value("input","pad_button_map",…)`
    or the next unrelated settings save wipes the remap from disk.


> **FOR IMPLEMENTATION AGENTS (GPT-5.6 Luna / others):**
> Read this entire file before writing any code. Each task below has exact file paths,
> function names, API calls, and acceptance criteria. Do not skip the "VERIFY" steps.
> After ANY code change, run: `godot --headless --script scripts/BootTest.gd` (must show 12/12 PASS).
> After all work, `git add -A && git commit && git push`.

---

## Current State (Phase 0 — COMPLETE)
- Godot 4.7 project at /Volumes/HARD/projects/friday-evacuation
- GitHub: github.com/jiracipika/friday-evacuation (private)
- 4 game modes: Evacuation (primary, playable), Hauled/ShopSeek/PizzaColony (stubs)
- Player controller: WASD movement, boost, jump, sabotage traps, stun system
- Smooth chase camera with velocity-aware trailing
- Procedural 4-story office building with ramps, desks, power-ups
- Multiplayer networking layer (ENet, not yet wired)
- Headless test suite (12/12 passing)
- Controls: WASD/Arrows=move, Space=boost, E=jump, Q=sabotage, Esc=menu

## Architecture Reference
```
scripts/
  GameManager.gd     — Autoload. GameMode enum, mode selection, player data
  Network.gd         — Autoload. ENet host/join (port 5005, 8 players max). NOT wired yet.
  PlayerChair.gd     — CharacterBody3D controller. Movement, boost, jump, traps, stun.
  Evacuation.gd      — Primary mode. Procedural building, camera follow, match flow.
  Hauled.gd          — Stub. Single floor + rigid body cargo boxes.
  ShopSeek.gd        — Stub. Single floor + shelf obstacles.
  PizzaColony.gd     — Stub. Giant cylinder pizza + pepperoni dots.
  SabotageTrap.gd    — Area3D trap. Random type (water/banana/stapler). Stuns on touch.
  Main.gd            — Main menu. 4 mode buttons + Play. Uses GameManager autoload.
  BootTest.gd        — Headless test runner. Run after every change.
  HeadlessTest.gd    — Older test script (can ignore, BootTest supersedes).

scenes/
  Main.tscn          — Control node, VBox layout, mode buttons, Play button
  Evacuation.tscn    — Node3D, WorldEnvironment, DirectionalLight3D, Camera3D, Arena/ExitZone
  PlayerChair.tscn   — CharacterBody3D, CapsuleShape3D, ModelParent, ChairMesh, Nametag, BoostParticles
  Hauled.tscn        — Node3D + light + camera (script spawns everything)
  ShopSeek.tscn      — Same pattern
  PizzaColony.tscn   — Same pattern
  objects/SabotageTrap.tscn — Area3D + CylinderMesh + CollisionShape3D
```

## GDScript Gotchas (LEARN THESE — they WILL break your build)
1. `randf(min, max)` does NOT exist. Use `randf_range(min, max)` or `rng.randf_range(min, max)`
2. Array `.size` is a property in some languages — in GDScript it's `.size()` (method call)
3. Scene files (.tscn): every SubResource referenced MUST be declared in the `[gd_scene load_steps=N]` header. Count = ext_resource + sub_resource + 1
4. `StandardMaterial3D.emission` requires `emission_enabled = true` BEFORE setting emission color
5. Camera follow code goes in `_process()` NOT `_physics_process()` — physics tick ≠ render frame = visual stutter
6. Frame-rate independent lerp: use `1.0 - exp(-k * delta)` as the weight, NOT a raw float like `0.1`
7. `angle_difference(a, b)` returns the shortest signed difference — use it for rotation lerping
8. `@onready var` references fail if the node path doesn't match the scene tree — check .tscn structure
9. Autoloads (GameManager, Network) are NOT available in SceneTree scripts (BootTest.gd) — only in normal game scenes
10. Use `is_instance_valid(node)` before accessing properties of nodes that might be freed
11. GPUParticles3D needs a `ParticleProcessMaterial` assigned or nothing renders
12. Tabs for indentation in GDScript — never spaces, never mixed
13. `load()` caches resources. Use `load().instantiate()` for scene instances, `load().duplicate()` for materials

---

## Phase 1: VISUAL IDENTITY & ATMOSPHERE
**Goal: Make it look like a real game, not grey boxes.**
**Target: Get to ~80% visual quality. GLM will polish the last 20%.**

### 1A: Material & Lighting Overhaul

**File: scripts/Evacuation.gd — modify `_build_floor()` function**

Current floors are flat StandardMaterial3D boxes. Replace with:

1. Create a helper function `_make_carpet_material(base_color: Color) -> StandardMaterial3D`:
   ```gdscript
   func _make_carpet_material(base_color: Color) -> StandardMaterial3D:
       var mat = StandardMaterial3D.new()
       mat.albedo_color = base_color
       mat.roughness = 0.95
       mat.metallic = 0.0
       # Procedural noise texture for subtle variation
       var noise = FastNoiseLite.new()
       noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
       noise.frequency = 0.05
       var tex = NoiseTexture2D.new()
       tex.width = 512
       tex.height = 512
       tex.seamless = true
       tex.noise = noise
       mat.albedo_texture = tex  # Subtle darkening pattern
       return mat
   ```

2. Create a helper function `_make_wood_material() -> StandardMaterial3D`:
   ```gdscript
   func _make_wood_material() -> StandardMaterial3D:
       var mat = StandardMaterial3D.new()
       mat.albedo_color = Color(0.35, 0.25, 0.15)
       mat.roughness = 0.7
       var noise = FastNoiseLite.new()
       noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
       noise.frequency = 0.02
       var tex = NoiseTexture2D.new()
       tex.width = 256
       tex.height = 256
       tex.seamless = true
       tex.noise = noise
       mat.albedo_texture = tex
       return mat
   ```

3. In `_build_floor()`, apply carpet material to floors, darkened variant to walls.

4. In `_make_desk()`, apply wood material instead of flat brown.

5. Add ceiling lights to each floor. New function `_spawn_ceiling_lights(floor_pos: Vector3, floor_color: Color)`:
   - Create a grid of OmniLight3D nodes at floor_pos.y + 3.0 (ceiling height)
   - Grid: 3x3, spacing 12 units, each light has: light_energy=0.4, light_color=warm white (Color(1, 0.95, 0.8)), omni_range=18, shadow_enabled=true
   - Also create thin BoxMesh strips as visible fluorescent fixture geometry (emissive material, Color(1,1,0.9), emission_energy_multiplier=2.0)

6. Set DirectionalLight3D light_energy to 0.3 (the ceiling lights do the heavy lifting now).

7. Update the WorldEnvironment:
   - ambient_light_energy: 0.3 (darker ambient, lights do the work)
   - fog_enabled: true, fog_density: 0.008, fog_aerial_perspective: 0.5
   - glow_enabled: true, glow_intensity: 0.8, glow_strength: 1.0 (for bloom on emissive materials)

**VERIFY:** Run game, floors should have subtle texture, ceilings should have visible light fixtures casting warm light, desks look woody.

### 1B: Office Chair Model (Code-Constructed)

**File: scripts/PlayerChair.gd — add `_build_chair_model()` function**

Build the chair from primitives in code instead of a single capsule. This goes in `_ready()` after the current mesh setup.

Create a function `_build_chair_model() -> Node3D` that returns a Node3D containing:
1. **Seat**: MeshInstance3D with BoxMesh(size=Vector3(0.7, 0.15, 0.7)), position=(0, 0, 0)
2. **Backrest**: MeshInstance3D with BoxMesh(size=Vector3(0.7, 0.8, 0.1)), position=(0, 0.45, -0.3)
3. **Gas cylinder stem**: MeshInstance3D with CylinderMesh(radius=0.06, height=0.4), position=(0, -0.25, 0), dark metallic material
4. **5-star base**: Create 5 box "arms" radiating from center:
   - For i in range(5): angle = i * TAU / 5.0
   - BoxMesh(size=Vector3(0.1, 0.05, 0.5)), position rotated around Y by angle, offset outward by 0.25
5. **5 castor wheels**: For i in range(5): angle = i * TAU / 5.0
   - SphereMesh(radius=0.08), position at the end of each arm (offset 0.45 from center), black material
   - Add these to a "wheels" group: `wheel.add_to_group("chair_wheels")`
6. All parts share the player_color material EXCEPT stem and wheels (dark/black)
7. Parent all parts to a single Node3D, return it
8. In `_ready()`, replace the ChairMesh reference: hide the capsule mesh, add the built chair as child of ModelParent

**Animation hooks** (actual animation in Phase 2, but set up the references now):
- Store wheel references in an array: `var wheels: Array[MeshInstance3D] = []`
- Store references to seat and backrest for squash/stretch later

**VERIFY:** Run game, player should look like an actual office chair, not a capsule. Wheels visible at bottom.

### 1C: Post-Processing & Environment

**File: scripts/Evacuation.gd — modify `_ready()` or add `_setup_environment()`**

1. Access the WorldEnvironment node's Environment resource.
2. Configure glow: `env.glow_enabled = true`, `env.glow_intensity = 0.8`, `env.glow_strength = 1.0`, `env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE`
3. Configure vignette: `env.vignette_enabled = true`, `env.vignette_intensity = 0.4`, `env.vignette_radius = 0.7`
4. Configure color correction: Create a GradientTexture for warm tint (slight orange shift in midtones)
5. Set `env.fog_enabled = true`, `env.fog_light_color = Color(0.05, 0.05, 0.08)`, `env.fog_density = 0.008`
6. Enable SSAO: `env.ssr_enabled = false` (too expensive on mobile), `env.ssao_enabled = true`, `env.ssao_radius = 1.0`, `env.ssao_intensity = 2.0`
7. Set `env.tonemap_mode = Environment.TONEMAPER_FILMIC` for better color rolloff

**VERIFY:** Game has bloom on power-up orbs and exit zone, slight vignette darkening at screen edges, warm color grade.

### 1D: Power-Up Visual Upgrade

**File: scripts/Evacuation.gd — modify `_make_powerup()`**

1. Change power-up mesh from a sphere to a floating coffee cup:
   - Main body: CylinderMesh(top_radius=0.3, bottom_radius=0.25, height=0.5) — the cup
   - Handle: TorusMesh(major_radius=0.15, minor_radius=0.04) positioned on the side, rotated 90° on X
   - "Coffee" top: CylinderMesh(top_radius=0.28, bottom_radius=0.28, height=0.05) dark brown, at the top
   - All parented to a Node3D, emissive orange material on the cup body
2. Add a `_process` function to power-ups that makes them float and rotate:
   ```gdscript
   # In the powerup Area3D, add a script or inline:
   # rotation.y += delta * 2.0
   # position.y = base_y + sin(Time.get_ticks_msec() * 0.003) * 0.3
   ```
3. Store the base_y position for the floating calculation.
4. Add a PointLight3D (OmniLight3D, light_energy=1.0, light_color=Color(1,0.6,0.1), omni_range=5) as child of each power-up so they cast warm light.

**VERIFY:** Power-ups look like floating spinning coffee cups with warm glow.

---

## Phase 2: ANIMATION & GAME FEEL
**Goal: Juicy, satisfying movement and feedback.**

### 2A: Player Squash & Stretch + Feedback

**File: scripts/PlayerChair.gd**

1. Add state variables:
   ```gdscript
   var squash_amount: float = 1.0  # 1.0 = normal, <1 = squashed, >1 = stretched
   var target_squash: float = 1.0
   var was_on_floor: bool = true
   var landing_velocity: float = 0.0
   ```

2. Track fall velocity for landing detection. In `_physics_process()`, before `move_and_slide()`:
   ```gdscript
   if was_on_floor and not is_on_floor():
       landing_velocity = 0.0  # reset, start tracking fall
   if not is_on_floor():
       landing_velocity = min(landing_velocity, velocity.y)  # track most negative
   was_on_floor = is_on_floor()
   ```

3. Landing squash — after `move_and_slide()`, detect new landing:
   ```gdscript
   if is_on_floor() and not was_on_floor_pre_move:
       if landing_velocity < -5.0:
           target_squash = 0.7  # hard land = big squash
           _camera_shake(abs(landing_velocity) * 0.15)
       elif landing_velocity < -2.0:
           target_squash = 0.85  # soft land
       landing_velocity = 0.0
   ```

4. Jump stretch — in `_handle_input()`, when jump fires:
   ```gdscript
   target_squash = 1.2  # stretch up on jump
   ```

5. Boost wheelie — in `_start_boost()`:
   ```gdscript
   target_squash = 1.0  # normal height
   # Store a boost_visual_timer for wheelie rotation
   boost_visual_timer = boost_duration
   ```
   In `_physics_process`, add wheelie rotation:
   ```gdscript
   if boost_visual_timer > 0:
       boost_visual_timer -= delta
       var wheelie_amount = sin(boost_visual_timer / boost_duration * PI) * 0.15
       model_parent.rotation.x = lerp(model_parent.rotation.x, -wheelie_amount, delta * 10)
   else:
       model_parent.rotation.x = lerp(model_parent.rotation.x, 0.0, delta * 10)
   ```

6. Smooth squash interpolation in `_physics_process`:
   ```gdscript
   target_squash = lerp(target_squash, 1.0, 1.0 - exp(-8.0 * delta))  # recover to normal
   squash_amount = lerp(squash_amount, target_squash, 1.0 - exp(-15.0 * delta))
   if model_parent:
       model_parent.scale = Vector3(
           2.0 - squash_amount,  # inverse: squash = wider
           squash_amount,         # squash = shorter
           2.0 - squash_amount
       )
   ```

7. Add camera shake function:
   ```gdscript
   var shake_amount: float = 0.0
   func _camera_shake(amount: float) -> void:
       shake_amount = max(shake_amount, amount)
   ```
   The Evacuation.gd camera system will read this and apply offset. Add a signal:
   ```gdscript
   signal shake_requested(amount: float)
   ```
   Emit on landing, wall hit, stun. Evacuation.gd connects to this and adds random offset to camera.

8. Stun spin-out — in `_physics_process`, stunned section:
   ```gdscript
   if is_stunned > 0:
       model_parent.rotation.y += delta * 15.0  # spin rapidly
   ```

9. FOV kick on boost — emit a signal `boost_started` that Evacuation.gd listens to:
   ```gdscript
   signal fov_kick(active: bool)
   ```
   In Evacuation.gd `_update_camera()`, when boost active:
   ```gdscript
   camera.fov = lerp(camera.fov, 80.0 if boosting else 70.0, 1.0 - exp(-5.0 * delta))
   ```

**VERIFY:** Jump stretches the chair up, landing squashes it flat then recovers. Boost tilts back slightly. Stunned = wild spin. Hard landings shake the screen.

### 2B: Particle Systems

**File: scripts/PlayerChair.gd + new script scripts/ParticleHelper.gd**

1. Create a ParticleProcessMaterial for boost trail:
   ```gdscript
   func _make_boost_particles() -> ParticleProcessMaterial:
       var mat = ParticleProcessMaterial.new()
       mat.direction = Vector3(0, 0, 1)  # emit backward
       mat.spread = 15.0
       mat.initial_velocity_min = 2.0
       mat.initial_velocity_max = 4.0
       mat.gravity = Vector3(0, -2, 0)
       mat.scale_min = 0.1
       mat.scale_max = 0.3
       mat.color = Color(1.0, 0.6, 0.1, 0.8)
       # Ramp color from yellow to red over lifetime
       var ramp = Gradient.new()
       ramp.set_color(0, Color(1, 0.8, 0.2, 1))
       ramp.set_color(1, Color(1, 0.3, 0.0, 0))
       mat.color_ramp = ramp
       return mat
   ```

2. Assign this material to the BoostParticles GPUParticles3D in `_ready()`. Set amount=30, lifetime=0.4.

3. Add dust particles on sharp turns and hard stops. In PlayerChair._physics_process:
   - Track previous velocity direction
   - If angle between current velocity and previous > 45° AND speed > 5.0: spawn dust particle burst
   - Create a one-shot GPUParticles3D at the chair's position, brownish particles, auto-free after 1s

4. Confetti at exit zone. In Evacuation.gd `_on_player_reached_exit()`:
   - Spawn a GPUParticles3D at exit zone position
   - 100 particles, colorful gradient (rainbow), gravity pulls down, lifetime 2s
   - One-shot, queue_free after 3s

5. Trap spawn poof. In SabotageTrap.gd `_ready()`:
   - Spawn a small dust cloud GPUParticles3D, one-shot, auto-free after 0.5s

6. Power-up collect splash. In the powerup body_entered handler:
   - Spawn coffee-colored particle splash before queue_free

**VERIFY:** Boost leaves a fiery trail. Sharp turns kick up dust. Exit zone explodes with confetti. Traps spawn with a poof.

### 2C: Audio System

**New file: scripts/AudioManager.gd (autoload)**

1. Register as autoload in project.godot:
   ```
   [autoload]
   AudioManager="*res://scripts/AudioManager.gd"
   ```

2. AudioManager structure:
   ```gdscript
   extends Node

   var sfx_players: Array[AudioStreamPlayer] = []
   var music_player: AudioStreamPlayer = null
   var sfx_volume: float = 1.0
   var music_volume: float = 0.7

   # Call from anywhere: AudioManager.play_sfx("boost")
   func play_sfx(name: String) -> void:
       pass  # Implementation loads from res://audio/sfx/{name}.wav

   func play_music(name: String) -> void:
       pass

   func set_sfx_volume(vol: float) -> void:
       sfx_volume = vol

   func set_music_volume(vol: float) -> void:
       music_volume = vol
   ```

3. Since no audio files exist yet, generate placeholder SFX procedurally using AudioStreamGenerator:
   - `boost`: white noise burst, 0.3s, descending pitch
   - `jump`: sine wave, 0.15s, ascending pitch 200→600Hz
   - `land`: low thud, sine 80Hz, 0.1s, quick decay
   - `powerup`: bright ding, two sine waves (600+900Hz), 0.2s
   - `trap`: cartoon slip sound, descending pitch sweep, 0.4s
   - `countdown_beep`: square wave, 440Hz, 0.1s
   - `go_horn`: sawtooth, 220Hz, 0.5s
   - `victory`: ascending arpeggio, 0.8s
   - `wall_bonk`: short noise burst, 0.05s

   Implementation pattern for procedural SFX:
   ```gdscript
   func _generate_beep(freq: float, duration: float, wave_type: String) -> AudioStream:
       var sample_rate = 44100
       var samples = int(sample_rate * duration)
       var stream = AudioStreamGenerator.new()
       stream.mix_rate = sample_rate
       stream.buffer_length = duration
       # Fill buffer with waveform...
       return stream
   ```

4. Call AudioManager from the right places:
   - PlayerChair `_start_boost()`: `AudioManager.play_sfx("boost")`
   - PlayerChair `_handle_input()` jump: `AudioManager.play_sfx("jump")`
   - PlayerChair landing detection: `AudioManager.play_sfx("land")`
   - Powerup pickup: `AudioManager.play_sfx("powerup")`
   - SabotageTrap `_on_body_entered()`: `AudioManager.play_sfx("trap")`
   - Evacuation `_start_countdown()`: beep each second
   - Evacuation `_start_race()`: `AudioManager.play_sfx("go_horn")`
   - Evacuation `_on_player_reached_exit()`: `AudioManager.play_sfx("victory")`

5. Background music: generate a simple looping bass line + melody using AudioStreamGenerator, or leave a commented-out load path for when real music files are added.

**VERIFY:** Boost plays a whoosh, jumps play a spring sound, countdown beeps, power-ups ding. No errors if audio files are missing (graceful fallback).

---

## Phase 3: UI/UX POLISH
**Goal: Professional menus and HUD.**

### 3A: Main Menu Redesign

**File: scripts/Main.gd + scenes/Main.tscn**

1. **Background**: Add a SubViewport with a slowly rotating 3D office chair (load PlayerChair.tscn, place on a platform, rotate slowly via `_process`).
   - Alternatively: add a ColorRect background with a subtle animated gradient (ShaderMaterial that shifts hue slowly).

2. **Title styling**: 
   - Use a large font (load a free font like "Extra" or use Godot's default at size 64+)
   - Apply gradient text: orange to yellow
   - Add a subtle bounce animation (sine wave on Y position, amplitude 5px, period 3s)

3. **Mode cards**: Replace plain buttons with styled Panel containers:
   - Each card: 80px tall, rounded corners (use StyleBoxFlat with corner_radius), dark background (#1c1c2e), colored left border (mode color)
   - Title (24pt bold), subtitle (14pt), description (12pt) inside each card
   - Hover effect: card grows slightly (scale 1.02) + border glows
   - Selected state: border thicker, background lighter, ">> SELECTED <<" text
   - Use `mouse_entered` / `mouse_exited` signals for hover

4. **Settings button**: Below Play button, smaller, with gear icon (can use a Unicode emoji or draw with primitive shapes).

5. **Version number**: Label in bottom-right corner, "v0.2.0", gray text.

6. **Dark theme colors** (MUST match user's design language):
   - Background: #0a0a0f
   - Cards/panels: #1c1c2e
   - Text primary: #FFFFFF
   - Text secondary: rgba(255,255,255,0.6)
   - Accent (Evacuation): #ff9a1a (orange)
   - Accent (Hauled): #ff5963 (red)
   - styled with StyleBoxFlat, use theme overrides

### 3B: In-Match HUD

**New file: scripts/HUD.gd + scenes/HUD.tscn**

The HUD is a CanvasLayer that Evacuation.tscn loads as a child. Structure:

1. **Top bar**: Timer (center, large), floor indicator (left), player position (right for MP)
2. **Bottom-left**: Speedometer
   - Semi-transparent circular gauge (draw with `_draw()` on a Control, or use ProgressBars)
   - Shows current speed as percentage of max_speed
   - Color shifts from green → yellow → red as speed increases
   - Numeric speed display (speed * 3.6 rounded, labeled "km/h" for humor since it's an office chair)
3. **Bottom-right**: Boost cooldown indicator
   - Coffee cup icon that fills up over 3 seconds
   - When ready: cup glows orange + pulses
   - When on cooldown: cup is empty/gray, filling animation
4. **Bottom-center**: Sabotage cooldown indicator
   - Small icon (banana/water drop), gray when on cooldown
5. **Top-left corner**: Minimap (SubViewport camera looking straight down)
   - 150x150px, semi-transparent, shows floor outlines, player dot (blue), exit zone (green)
   - Camera follows player from above at all times (separate Camera3D at y=30 looking down)

**Integration**: In Evacuation.gd `_ready()`, load and instantiate HUD.tscn as child of the UI CanvasLayer. In `_process()`, update HUD values:
```gdscript
hud.set_speed(Vector2(local_player.velocity.x, local_player.velocity.z).length())
hud.set_boost_ready(local_player.boost_cd_timer <= 0)
hud.set_timer_text(timer_label.text)
```

### 3C: Results Screen Overhaul

**File: scripts/Evacuation.gd — modify `_show_results()` and the ResultsPanel in Evacuation.tscn**

1. Expand the ResultsPanel VBox to include:
   - WinnerLabel (existing, make bigger: 42pt, with bounce-in animation)
   - StatsContainer (HBox): Time | Top Speed | Traps Hit
   - BeerLabel: "🍺 Last place owes beers!" (or text equivalent)
   - Button row: Rematch | Change Mode | Main Menu

2. Animate the results panel:
   - Start invisible (modulate.a = 0, scale = 0.8)
   - Tween in: fade to 1.0 + scale to 1.0 over 0.3s with ease-out-back
   - WinnerLabel bounces in 0.1s after panel

3. Track race stats in Evacuation.gd:
   ```gdscript
   var top_speed: float = 0.0
   var traps_hit: int = 0
   var traps_placed: int = 0
   ```
   Update top_speed each frame in `_process` when racing.

### 3D: Settings Menu

**New file: scripts/Settings.gd + scenes/Settings.tscn**

1. Accessible from Main Menu settings button.
2. Contains:
   - **Graphics Quality**: OptionButton (Low / Medium / High)
     - Low: shadows off, particles at 50%, SSAO off, fog off
     - Medium: shadows on (low distance), particles at 75%, SSAO off, fog on
     - High: shadows on (full), particles at 100%, SSAO on, fog on
   - **Master Volume**: HSlider (0-100)
   - **Music Volume**: HSlider (0-100)
   - **SFX Volume**: HSlider (0-100)
   - **Screen Shake**: CheckButton (on/off)
   - **Back Button**: Returns to previous screen
3. Settings persist using `ConfigFile`:
   ```gdscript
   var config = ConfigFile.new()
   config.set_value("audio", "master", 1.0)
   config.save("user://settings.cfg")
   ```
   Load on game start in GameManager autoload.

---

## Phase 4: GAMEPLAY DEPTH — EVACUATION MODE
**Goal: Make the primary mode genuinely fun and replayable.**

### 4A: Themed Floor Design

**File: scripts/Evacuation.gd — rewrite `_setup_arena()` and add floor-specific builders**

Replace the current uniform floor generation with distinct themed floors:

1. **Floor 1 — Cubicle Farm** (y=0):
   - Generate a grid of cubicle desks: rows of desks with low partitions (0.8m tall boxes) between them
   - Leave a main corridor (4 units wide) down the center and cross-paths
   - Cubicle partitions are collision + mesh, color: gray-blue (#3a4a5a)
   - Add a few office plants (cylinder trunk + sphere foliage) as obstacles
   - Ramp to floor 2 at the back-right

2. **Floor 2 — Open Office** (y=6):
   - Fewer obstacles, more open space
   - 2 large conference tables (4x1.2x2 boxes) in the center
   - Water coolers (cylinder body + sphere top, blue transparent material) scattered — these ARE traps (stun on touch, like sabotage traps but permanent fixtures)
     - Carpet area (slower, friction 2x) vs tile area (faster, friction 0.5x) — use physics materials
   - Ramp to floor 3 at the back-left

3. **Floor 3 — Stairwell Chaos** (y=12):
   - Central spiral ramp winding upward (use a series of angled box segments in a spiral)
   - Handrails (thin boxes along ramp edges) — you can grind them by staying on the edge
   - Gaps in the floor (fall through = respawn at floor 3 start)
   - No desks, pure dexterity challenge
   - Ramp to floor 4 at the top

4. **Floor 4 — Cafeteria** (y=18):
   - Slippery floor (ice physics: low friction, high slide)
   - Round tables (cylinders) with chairs around them
   - Spilled drinks on the floor (small Area3D zones that stun like traps)
   - Lunch trays as movable RigidBody3D objects (slide and bump you)
   - Exit zone at the far end — the parking lot door

5. **Floor 5 — Parking Lot** (exit area, y=18, behind the cafeteria):
   - Actually part of floor 4's level but visually different
   - Concrete floor (gray, rough), painted parking lines (decals or thin colored boxes)
   - Parked cars (box approximations: body + cabin + 4 wheels) as obstacles
   - The ExitZone is here, styled as a glowing "EXIT" sign above a door

6. **Checkpoint system**:
   - Add invisible Area3D zones at each ramp entrance
   - Player must pass through them in order — track `current_checkpoint` per player
   - If player falls off (y < current_checkpoint_y - 5), respawn at last checkpoint position

7. **Respawn logic** in PlayerChair.gd:
   ```gdscript
   var respawn_point: Vector3 = Vector3.ZERO
   func respawn() -> void:
       global_position = respawn_point
       velocity = Vector3.ZERO
       is_stunned = 1.0  # brief stun on respawn
   ```

**VERIFY:** Each floor looks and plays differently. Cubicle farm is a maze. Open office has carpet/tile speed zones. Stairwell is a spiral challenge. Cafeteria is slippery chaos.

### 4B: Power-Up Variety

**File: scripts/Evacuation.gd — modify `_make_powerup()` and add powerup types**

1. Define power-up types:
   ```gdscript
   enum PowerUpType { COFFEE, ENERGY_DRINK, STAPLER, SPILL, PRINTER, EXTINGUISHER }
   ```

2. Each type has different mesh, color, and effect:
   - COFFEE: coffee cup (existing), orange glow, triggers `_start_boost()`
   - ENERGY_DRINK: tall thin can (cylinder, taller), green glow, triggers `_start_boost()` with 1.5x force and 2x duration
   - STAPLER: small box, red glow, gives player 3 "stapler charges" — press Q to launch a projectile that knocks back nearby players
   - SPILL: yellow puddle, gives player 2 "spill charges" — press Q to create a wide (3x3) stun zone
   - PRINTER: flat box, blue glow, fires paper airplanes in all directions on pickup (visual only, blinds nearby players with white screen overlay for 1s — emit signal `player_blinded`)
   - EXTINGUISHER: red cylinder, white glow, freezes/stuns ALL players within 8 units for 2s (including possibly yourself if you're too close to others)

3. Visual differentiation: each type gets a unique emissive color and shape. Add a PointLight3D matching the color.

4. Distribution: 60% coffee, 15% energy drink, 10% stapler, 8% spill, 4% printer, 3% extinguisher (weighted random).

**VERIFY:** At least 3 different power-up types visible in a single race. Each has a distinct visual and effect.

**STATUS: COMPLETE (commit `37166a7`, verified).** All six kinds implemented with the exact weighted distribution. Distinct procedural meshes + per-kind OmniLight3D + colorblind-safe Label3D name on every pickup. Item charges (stapler ×3 fired forward via new `StaplerBolt.gd` projectile; spill ×2 wide puddle trap behind), printer paper-burst + blind flash (respects `flash_effects_enabled`), extinguisher 8u/2s area stun. `PowerUpSmokeTest.gd` (31 checks) verifies distribution (coffee ≈60% over 6000 rolls), forced-type traps, charge consumption, bolt flight, per-kind collision+label, HUD item readout, overlay dedupe, and energy-drink boost multipliers. Also fixed while in here: HUD.gd was dead code (never instantiated — now wired into Evacuation with true boost-cooldown bar, item readout, minimap, floor label); SubtitleOverlay was mounted by zero modes (captions silently dropped — now mounted in all 4 via new `SubtitleOverlay.mount()`); MobileControls was never instantiated (now mounted on Android/iOS); removed a duplicate powerup pickup connect in Evacuation.gd.

**STATUS: COMPLETE (commit `18bdbda`, verified).** All themed floors implemented. Floor 1 cubicle farm (partition grid + central corridor + plants), floor 2 open office (conference tables, 3 water-cooler stun fixtures, tile 0.55 / carpet 1.8 speed zones), floor 3 stairwell chaos with REAL fall-through gaps (base slab replaced by concrete landings — perimeter ring, both elevator pads solid, north connector added after the LevelClearTest caught an unreachable elevator; warning stripes; crates), floor 4 cafeteria (ice 0.16 zone, round tables, spill puddles) + parking lot (painted lines, parked cars). Checkpoint system: spawn sets floor-1 point, elevators advance it, `_respawn_if_fell()` respawns anyone 5u below their checkpoint. Desks/traps no longer spawn over floor-3 gaps; ghost waypoint moved onto solid ground. `ThemedFloorsSmokeTest.gd` (16 checks) + LevelClearTest (real gapped geometry) both PASS; full 12-suite ladder green, boot 0 errors.

### 4C: Dynamic Hazards

**New file: scripts/Hazards.gd (loaded by Evacuation.gd)**

1. **Rogue Roomba** (NPC enemy):
   - A flat cylinder (radius 0.4, height 0.2), dark with a glowing red indicator strip
   - Wanders using simple AI: pick random direction every 3-5s, move at 4 units/s
   - Add 2-3 Roombas per floor
   - On contact with player: stun for 1.5s + knockback (velocity += direction * 10)
   - Implementation: CharacterBody3D or AnimatableBody3D with `_physics_process` for movement

2. **Swinging Doors**:
   - On floor 1 and 4, place door frames in corridors
   - Door is a BoxMesh hinged on one side, rotates back and forth (sin wave, period 2s, amplitude 60°)
   - Collision follows the rotation (use a StaticBody3D with the rotation updated each frame, or AnimatableBody3D)
   - Getting hit by the door: knockback + 0.5s stun

3. **Fire Drill Alarm** (periodic event):
   - Every 30s during a race, trigger fire drill for 5s
   - Red strobe lights flash (OmniLight3D modulating energy between 0 and 3 at 5Hz)
   - During fire drill, all player friction increases by 50% (panicking)
   - Announce with AudioManager: "FIRE DRILL! EVERYBODY PANIC!" (text on HUD)

4. **Falling Debris** (floor 3 only):
   - Every 5-8s, a ceiling tile (box) falls from y+3 to the floor
   - Warning: tile appears and shakes for 1s before falling
   - Getting hit: 1s stun + knockback
   - Tile disappears after landing (queue_free after 2s)

**VERIFY:** Roombas wander and stun on contact. Doors swing and knock players. Fire drill flashes lights.

**STATUS: COMPLETE (commit `90362d7`, verified).** `Hazards.gd` controller + `Roomba.gd` entity wired into Evacuation (built in `_setup_arena`, `start_race()` at go, `stop()` at race end). 8 Roombas (2/floor; floor-3 spawns sampled from landing rects — never over gaps), collision-normal reflection wandering (plain reversal ping-ponged in clutter, caught by test), 1.5s stun + knockback + caption on contact. 4 swinging doors (F1 corridor mouths, F4 cafeteria entrances): ±60° sin swing, 0.5s stun + directional shove. Fire drill every 30s for 5s: 5Hz red strobes all floors, +50% panic friction on every chair (restored afterward), caption announce. Floor-3 falling debris every 5-8s: 1s warning shake (respects reduced_motion), spawns above landings only, 1s stun + knockback on hit, despawns 2s after landing. Also fixed a real crash the test exposed: `SabotageTrap._on_body_entered` typed-param crash when AnimatableBody3D (doors) entered its Area3D. `HazardsSmokeTest.gd` = 18 checks; full 13-suite ladder green; boot 0 errors. Tuning (Roomba density, drill cadence, debris rate) flagged for on-Mac playtest.

---

## Phase 5: MULTIPLAYER
**Goal: Play with friends over LAN/internet.**

### 5A: Core Netcode

**Files: scripts/Network.gd (modify), scripts/PlayerChair.gd (modify), scripts/Evacuation.gd (modify)**

1. **Player spawning in multiplayer**:
   - Each peer gets a unique `multiplayer.get_unique_id()`
   - Host (id=1) spawns all players. Use `multiplayer.spawn()` pattern:
     ```gdscript
   - Player scene must have `multiplayer` authority set via `set_multiplayer_authority(id)`
   ```

2. **Position/rotation sync** — add to PlayerChair.gd:
   ```gdscript
   var last_sync_pos: Vector3 = Vector3.ZERO
   var last_sync_rot: float = 0.0
   const SYNC_THRESHOLD_POS: float = 0.05  # Only sync if moved >5cm
   const SYNC_THRESHOLD_ROT: float = 0.05  # Only sync if rotated >0.05 rad

   @rpc("any_peer", "call_local", "unreliable_ordered")
   func sync_transform(pos: Vector3, rot_y: float, vel: Vector3, boosting: bool) -> void:
       if multiplayer.is_server():
           return
       # Interpolate toward received position
       target_remote_pos = pos
       target_remote_rot = rot_y
       remote_velocity = vel
       is_remote_boosting = boosting

   func _physics_process(delta):
       if not is_multiplayer_authority():
           # Remote player: interpolate
           global_position = global_position.lerp(target_remote_pos, 1.0 - exp(-15.0 * delta))
           model_parent.rotation.y = lerp(model_parent.rotation.y, target_remote_rot, 1.0 - exp(-15.0 * delta))
           return
       # Local player: send sync every tick if moved enough
       if global_position.distance_to(last_sync_pos) > SYNC_THRESHOLD_POS:
           rpc("sync_transform", global_position, model_parent.rotation.y, velocity, is_boosting)
           last_sync_pos = global_position
   ```

3. **Trap placement sync** — when a player drops a trap:
   ```gdscript
   @rpc("authority", "call_local", "reliable")
   func rpc_drop_trap(pos: Vector3, trap_type: String) -> void:
       # All peers spawn the trap at the same position
   ```

4. **Lobby system**:
   - New scene: scenes/Lobby.tscn + scripts/Lobby.gd
   - Host button: calls Network.host_game(), shows waiting screen
   - Join button: IP entry field, calls Network.join_game(ip)
   - Player list updates via Network signals (player_connected/disconnected)
   - "Start Game" button (host only) — changes scene to Evacuation.tscn for all peers via rpc

5. **Player name + color selection**: In the lobby, each player picks a name (LineEdit) and color (ColorPickerButton).

6. **Ready check**: Each player clicks "Ready" button. When all ready, host can start.

### 5B: Multiplayer UI

**New files: scripts/Lobby.tscn + scripts/Lobby.gd**

1. Host/Join screen:
   - Title: "FRIDAY 5PM: MULTIPLAYER"
   - "Host Game" button → creates server on port 5005
   - "Join Game" button → shows IP entry field (default 127.0.0.1) + Connect button
   - Status label: "Waiting for players..." / "Connected!" / "Connection failed"
   - Connected players list (VBox of labels with player names + colors)
   - Name field (LineEdit, default "Player1")
   - Color picker (ColorPickerButton, default blue)
   - "Ready" toggle button per player
   - "Start Race" button (host only, enabled when all ready)
   - "Back" button → returns to main menu

2. Style with the dark theme (#0a0a0f bg, #1c1c2e panels, orange accent).

3. Chat overlay (simple): during a race, Enter key opens a text input at bottom of screen, messages appear as fading text for 5s.

---

## Phase 6: SECONDARY MODES (FULL IMPLEMENTATION)
**Goal: Make all 4 modes genuinely fun.**

### 6A: HAULED — Physics Delivery

**File: scripts/Hauled.gd (rewrite), scenes/Hauled.tscn**

1. **Cargo types** (RigidBody3D with custom behavior):
   ```gdscript
   const CARGO_TYPES = {
       "fridge_of_bees": {"color": Color(0.9, 0.85, 0.3), "mass": 3.0, "behavior": "bees"},
       "haunted_sofa": {"color": Color(0.5, 0.3, 0.4), "mass": 2.5, "behavior": "haunted"},
       "angry_vending_machine": {"color": Color(0.8, 0.2, 0.2), "mass": 4.0, "behavior": "vending"},
       "wet_cardboard": {"color": Color(0.6, 0.5, 0.3), "mass": 1.0, "behavior": "normal"},
       "exploding_cake": {"color": Color(0.9, 0.7, 0.5), "mass": 1.5, "behavior": "explode"},
       "sentient_plant": {"color": Color(0.2, 0.6, 0.2), "mass": 2.0, "behavior": "plant"},
   }
   ```

2. **Cargo behaviors** (script attached to each cargo RigidBody3D):
   - `bees`: every 3-5s, emit a particle swarm (yellow dots) that stuns any player within 3 units for 1s
   - `haunted`: randomly applies force to itself (drifts in random directions), harder to control
   - `vending`: every 5-8s, launches a can (small RigidBody3D) in a random direction, can knock players
   - `explode`: after being held for 5 cumulative seconds, explodes (stuns all nearby, launches itself upward)
   - `plant`: slowly grows over time, increasing mass from 2.0 to 5.0 over 30s

3. **Grab/throw mechanic** (on PlayerChair.gd or a new GrabComponent):
   - Press E near a cargo (within 2 units): attach cargo to player (reparent to player, disable RigidBody mode)
   - While carrying: movement speed reduced by 30%, can't boost
     - Press E again: release cargo (re-parent to world, re-enable RigidBody, apply forward velocity = throw)
   - Cargo takes damage on hard landings (fall_velocity < -8): reduce "value" by 25%
   - Cargo fully destroyed if value hits 0 or falls off the map

4. **Terrain/level**:
   - Spinning hallway: a long corridor that slowly rotates on its Z axis (AnimatableBody3D rotating, collision follows)
   - Conveyor belt: floor section that applies horizontal force to objects on it
   - Wrong-way escalator: ramp surface that pushes you backward (constant force opposite to ramp direction)
   - Delivery zone: Area3D at the end, when cargo enters: score = cargo value * gentleness multiplier

5. **Scoring**:
   - Base value per cargo type (100-500 points)
   - Gentleness bonus: if cargo took 0 damage, +50%
   - Speed bonus: if delivered in under 30s, +25%
   - Co-op bonus: if 2+ players are within 3 units of cargo at delivery, +100%

6. **Match flow**: 3 rounds, each with a random cargo type and terrain combination. Highest score wins.

### 6B: SHOP & SEEK — Hide & Seek

**File: scripts/ShopSeek.gd (rewrite), scenes/ShopSeek.tscn**

1. **Map layout**: Supermarket with aisles:
   - 6-8 parallel shelves (8m long, 2m tall, 1m apart) creating aisles
   - Checkout area at the front
   - Produce section (round tables for fruit displays)
   - Frozen section (upright freezer boxes, transparent blue material)

2. **Disguise system**:
   - Hiders: press E near any shelf object to "disguise" — player model replaced by the object's mesh (avocado, cereal box, milk carton, etc.)
   - While disguised: can't move for 2s (freeze), then can move slowly (50% speed)
   - Press E again to undisguise and move normally
   - Disguise has a subtle "wobble" (slight scale animation) that's the tell
   - 20+ possible disguise objects, each with unique mesh

3. **Roles**:
   - 1 seeker per 4 players (rounded down)
   - Seekers wear a red vest (add red cylinder around torso)
   - Seekers have a "scan" ability (5s cooldown): highlights all moving objects in red for 1s
   - Hiders who are caught (seeker touches them while disguised) become seekers

   - **Infection mode**: caught hiders join seekers. Last hider standing wins.

4. **Shopper role** (if no seekers): players must collect 5 items from a shopping list within 60s while AI "security guard" NPCs patrol

5. **Scoring**:
	- Hiders: +1 point per 10s alive, +5 if survive full round
	- Seekers: +3 per catch

**STATUS: COMPLETE for the single-player slice (commit `c386a70`, verified).**
Phase 6B builds seven deterministic shelf aisles plus checkout, produce, and
frozen sections; 22 uniquely identified product disguises; E-driven disguise
entry/exit with a real two-second freeze, half-speed movement, and wobble
tell; a five-item single-player shopper fallback with a patrolling security
guard that stuns on touch; seeker vest visual language on the guard; and
role/scan state with a five-second cooldown ready for later network
authority. `ShopSeekSmokeTest.gd` verifies 25 gameplay assertions against the
real scene. Real-peer role assignment, infection conversion, catches, and
replicated scoring remain Phase 5/6B network QA rather than being falsely
claimed from headless tests.

### 6C: PIZZA COLONY — Survival

**File: scripts/PizzaColony.gd (rewrite), scenes/PizzaColony.tscn**

1. **Pizza terrain**:
   - Giant pizza (radius 25m) with distinct zones:
     - Crust ring (outer 3m): solid, safe to walk
     - Cheese layer (middle): normal friction, harvestable for resources
     - Sauce sea (inner area): slow movement (50% speed), can't build on
     - Pepperoni pads (8-12 circles, radius 2m): claimable territory, safe zones

2. **Territory capture**:
   - Stand on a pepperoni for 3 continuous seconds to claim it
   - Claimed pepperoni changes to your color
   - Each pepperoni generates 1 resource per 5s while owned
   - Enemy pepperoni: must stand for 5s to steal (convert)

3. **Chef NPC** (the threat):
   - Giant chef (scaled-up model or abstract: large white box with chef hat cone)
   - Walks around the pizza edge, periodically uses "pizza cutter" attack:
     - A rotating line hazard sweeps across the pizza from crust to center
     - Visually a bright red line (thickness 0.5m) that rotates like a clock hand
     - Touching it: launched off the pizza (instant elimination)
   - Chef throws "olive bombs": dark circles that explode into stun zones after 2s
   - Chef speed increases over time

4. **Resource economy**:
   - Cheese: harvested from cheese layer by standing still on it (progress bar)
   - Toppings: random spawns on the pizza, collect by touching
   - Build forts: spend 5 cheese + 3 toppings to place a crust wall (2x1x0.5 box, blocks chef attacks)

5. **Win condition**: Last player standing, or first to claim 5 pepperoni.

**STATUS: COMPLETE for the single-player slice (commit `f74a9cd`, verified).**
Zoned pizza (crust rim / cheese plain / sauce sea at 55% speed / 10 pepperoni
pads). Continuous-presence claims: 3s neutral, 5s steal, leaving resets
progress. Owned pads generate cheese (+50% topping chance) every 5s; standing
still on the cheese plain harvests +2 per 3s. E builds crust-wall forts ahead
of the chair's facing for 5 cheese + 3 toppings. Chef walks the rim with
accelerating speed; a rotating red pizza-cutter line sweeps every 9s
(distance-to-line check, comedy launch elimination); olive bombs land near
the player every 6s with a 2s fuse and 4m stun zone. Win by claiming all
pepperoni or surviving 120s; falling off the edge eliminates. Multiplayer
last-standing/contest mechanics remain network QA. `PizzaColonySmokeTest.gd`
verifies 32 gameplay assertions (5/5 deterministic consecutive runs).

---

## Phase 7: MOBILE & CROSS-PLATFORM
**Goal: Ship on Android, iOS, Mac.**

### 7A: Mobile Touch Controls

**New file: scripts/TouchControls.gd + scenes/TouchControls.tscn**

1. **Virtual Joystick** (left side):
   - A TouchScreenButton or custom Control with `_draw()` for the base + stick
   - Track touch IDs: left half of screen = joystick, right half = action buttons
   - Output: Vector2 direction, fed into PlayerChair as input_dir
   - Visual: outer circle (80px, semi-transparent white) + inner knob (40px, accent color)
   - Knob follows finger within the base radius, clamped

2. **Action Buttons** (right side):
   - BOOST button: 70px circle, orange, right side middle
   - JUMP button: 60px circle, blue, right side upper
   - SABOTAGE button: 50px circle, red, right side lower
   - Each is a TouchScreenButton or custom Control with touch handlers
   - Visual feedback: scale down on press, flash on cooldown

3. **Integration**: PlayerChair.gd checks if touch controls are active:
   ```gdscript
   var use_touch: bool = false  # Set by platform detection

   func _handle_input(delta):
       var input_dir = Vector3.ZERO
       if use_touch:
           input_dir = TouchControls.get_move_vector()  # Returns Vector3
           if TouchControls.is_boost_pressed():
               _start_boost()
           # etc.
       else:
           # existing keyboard code
   ```

4. **Platform detection**:
   ```gdscript
   func _ready():
       match OS.get_name():
           "Android", "iOS":
               use_touch = true
           _:
               use_touch = false
   ```

5. **Haptic feedback**:
   ```gdscript
   # On boost, stun, trap hit:
   if use_touch:
       OS.vibrate(50)  # 50ms vibration
   ```

**STATUS: COMPLETE (commit `201b4e8`, verified).** Implemented in
`scripts/MobileControls.gd` (custom-drawn joystick plus BOOST/JUMP/TRAP
buttons), mounted and directly wired in all four modes. Desktop preview uses
`FE_TOUCH=1`; Android/iOS activate automatically. Boost ring reflects the
real chair cooldown synchronously; stun and button presses use handheld
haptics. `TouchControlsSmokeTest.gd` passes 20 checks, including real chair
movement, cooldown lockout, all actions, and every mode mount.

### 7B: Export Configuration

**File: export_presets.cfg (create in project root)**

1. Desktop (macOS):
   - Platform: macOS
   - Binary path: builds/friday-evacuation-mac.zip
   - Architecture: arm64 (for Apple Silicon)
   - Codesign: off (for now, add signing later)
   - App category: games
   - Identifier: com.jiracipika.friday-evacuation
   - Short version: 0.2.0
   - Icon: needs a 1024x1024 PNG icon (placeholder for now)

2. Android:
   - Platform: Android
   - Binary path: builds/friday-evacuation.apk
   - Architecture: arm64-v8a
   - Min SDK: 24 (Android 7.0)
   - Target SDK: 34 (Android 14)
   - Package: com.jiracipika.fridayevacuation
   - Keystone: needs debug keystore (can auto-generate)

3. iOS:
   - Platform: iOS
   - Binary path: builds/friday-evacuation.xcode.zip
   - Architecture: arm64
   - Orientation: landscape only
   - Requires iOS 15+

4. Web:
   - Platform: Web
   - Binary path: builds/friday-evacuation-web/index.html
   - Threads: off (browser limitation)
   - VRAM: 128MB texture compression

### 7C: Performance Optimization

1. **LOD system**: For distant objects (other floors), reduce mesh detail:
   ```gdscript
   # On each floor mesh, add a LOD generator in code
   # Floors below/above current: hide non-collision meshes entirely
   ```

2. **Shadow distance**: In lighting setup, set DirectionalLight3D shadow distance to 30 (only nearby objects cast shadows)

3. **Mobile renderer**: project.godot already uses "mobile" renderer — verify it works with all effects

4. **Particle scaling**: Scale particle counts based on device:
   ```gdscript
   var particle_scale = 1.0
   if OS.get_name() in ["Android", "iOS"]:
       particle_scale = 0.5
   ```

---

## Phase 8: POLISH & SHIP

### 8A: Meta Progression

1. **Chair skins** (unlockable):
   - Default: standard office chair
   - Bean Bag: flat sphere, sinks when stationary
   - Exercise Ball: bouncy, higher jump, harder to control
   - Shopping Cart: metal grid visual, louder roll sound
   - Toilet: white porcelain, flush sound on boost
   - Racing Seat: sporty, lower friction
   - Each skin modifies stats slightly (jump, friction, boost force)

2. **Unlock conditions**: Win 1/3/5/10/25/50 races

3. **Stats tracking**: Save to user://save.cfg using ConfigFile:
   - total_races, races_won, beers_owed, traps_landed, top_speed_ever

### 8B: Accessibility

1. Colorblind mode: adjust power-up colors to have distinct shapes too (not just color)
2. Subtitles: show text for all audio cues at bottom of screen
3. Adjust game speed: time_scale slider in settings (0.75x, 1x, 1.25x)
4. Toggle screen shake, flash effects, motion blur independently

### 8C: Final Polish

1. Loading screen with tips
2. Pause menu (resume, settings, quit to menu)
3. Credits screen
4. Crash handling (try/catch around critical sections, show error message)

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

---

## HANDOFF NOTES FOR GLM (Final Polish Pass)

**What GPT-5.6 Luna should deliver (the 80%):**
- All code compiles, all 12 BootTest checks pass
- Phases 1-4 implemented with working features (not stubs)
- Game runs at 60fps on the MacBook Air
- Visual identity is cohesive (dark theme, warm lighting, themed floors)
- Game feel is juicy (squash/stretch, particles, screen shake, audio)
- Multiplayer lobby exists and connects (at least on LAN)
- Commit everything to git, push to GitHub

**What GLM will polish (the last 20%):**
- Fine-tune all numerical values (acceleration, friction, boost force, camera lerp speeds)
- Adjust particle counts, colors, and lifetimes for visual perfection
- Tune audio volumes and pitches
- Balance power-up spawn rates and effect durations
- Optimize camera behavior for edge cases (falling, respawning, transitions between floors)
- Ensure cross-platform renderer compatibility (mobile vs desktop quality settings)
- Add the "artsy" touches: multi-axis parallax, dramatic animations, progressive blur
- Code review and cleanup
- Final QA pass: play test every mode, find and fix remaining bugs
