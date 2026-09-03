# PLAYTEST.md — Human QA Checklist

> Everything on this list NEEDS a human, real hardware, or a second machine.
> The automated ladder (`bash scripts/run_ladder.sh`) and the checkpoint bot
> (`scripts/CheckpointBotTest.gd`) already prove the software; this doc is the
> "does it FEEL right" pass. Check items off, note timings/feel, and file any
> tuning changes as follow-up work.

## Session 1 — Solo feel pass (any Mac, keyboard first)

Setup: fresh `settings.cfg` not required — note your settings first if you
want to compare. Run the real game: `open -a Godot` → open `project.godot` → F5.

### Movement & feel (Evacuation, Open Plan)
- [ ] Pre-match briefing appears; timer frozen until I AGREE; countdown runs after
- [ ] Keyboard drive: taps ramp in smoothly (~80ms), stops are snappy (~120ms) — not icy, not twitchy
- [ ] Camera-relative steering feels right when driving toward the camera (no input fighting)
- [ ] Drift: above ~8 m/s the chair swings wide through turns (feels like momentum, not lag)
- [ ] Brake (hold S while rolling): stops in under a second from top speed
- [ ] Reverse: slow foot-shove backwards, no flap between brake/reverse
- [ ] Air control off a desk jump: mild but present
- [ ] Corner camera roll (±2°) reads as lean, not nausea; reduced-motion setting kills it
- [ ] Coffee pickup: "E — GRAB" key cap appears in range; E collects; feels OK or does the key press add friction? (flag: consider auto-collect for COFFEE only)
- [ ] Hold boost: sustains to ~1.4s cap, cooldown grows while held; jump-cancel within 0.2s halves the cooldown
- [ ] Stun: mash any move key to recover faster; frantic wheel spin visible
- [ ] Elevator perfect landing: hit the pad dead-center → small boost + confetti + caption

### Checkpoints & navigation (the bot covers this — confirm by eye)
- [ ] Elevator pads read as portals (billboard + destination ring) from across the floor
- [ ] Finish line reads from anywhere on floor 4 (green beam, checkered columns)
- [ ] If you fall through a floor-3 gap: respawn at the last checkpoint (the floor you entered from)

### Camera & visibility
- [ ] Camera never clips the floor above on any floor (esp. floor 3 stairwell gaps)
- [ ] Snap is instant after elevator teleports (no slow pan)

### Sound & captions
- [ ] Boost/jump/land/trap/powerup/countdown/go/victory sounds all fire
- [ ] Captions appear for race events (announcer, elevator, ghost finish)
- [ ] Music/SFX sliders in Settings actually change volumes

### Performance baseline
- [ ] 60 fps on this Mac during floor-1 crowding (enable fps overlay: Godot debug menu or `--verbose`… or eyeball smoothness)
- [ ] No frame hitches when Hazards fire (roombas, fire drill strobes, debris)

### Chair skins & unlocks (Phase 8A)
- [ ] CHAIR dropdown on the main menu (under RIDER): only Office Standard unlocked on a fresh save; locked ones read "LOCKED (win N)"
- [ ] Detail label shows the chair's tagline + JUMP/GRIP/BOOST multipliers, and next-unlock progress ("0/1 WINS → Bean Bag")
- [ ] Unlock one win (solo race vs. ghost counts): results screen says "NEW CHAIR UNLOCKED: Bean Bag", menu dropdown now offers it
- [ ] Drive each unlocked skin at least once — Bean Bag should feel heavy/grippy, Exercise Ball jumpy/ slippery, The Throne boost plays a FLUSH sound
- [ ] Skin choice persists across app restarts and is the chair you spawn with

### Accessibility — traps & game speed (Phase 8B)
- [ ] Every trap shows a floating name label + shape icon (waves / banana arc / staple / droplet); readable at driving speed without stopping
- [ ] Banana and spill (both yellow) are instantly tellable apart by SHAPE alone — squint or glance, don't read
- [ ] Game speed: Settings → GAME SPEED 0.75x makes the whole race feel slower (physics AND the countdown/timer together, not just one); 1.25x faster; back to 1.0x normal
- [ ] Changing game speed in the pause menu mid-race applies the moment you resume — no restart needed
- [ ] Game speed returns to normal on the main menu after leaving a race (menu animations not stuck fast/slow)

## Session 2 — Controller pass (real pad required)

### Detection & scheme memory
- [ ] Plug pad in mid-menu → controls overlay/lobby reflects CONTROLLER scheme
- [ ] Auto scheme flips to controller on first stick move; back to KB+M on first key
- [ ] Scheme choice persists across app restarts when pinned

### Feel checklist (Phase 3 hardware QA)
- [ ] Stick curve EXPO (default): gentle center, full-throw edge — try PRECISION and LINEAR, pick a favorite
- [ ] RT/R2 analog boost: light pressure = weak boost, full pull = full boost; A/Cross = full fallback
- [ ] Deadzone 0.2: no drift-when-untouched; weak third-party sticks still center
- [ ] Rumble vocabulary: boost HUM (low, continuous), impact THUMP (sharp), hard-landing SPUTTER (twin pulses) — clearly distinct?
- [ ] Rumble peak-preemption: a thump during a hum interrupts it; a hum does not cancel a thump
- [ ] Remap a face button in Settings (e.g. swap A/X) → works live, survives restart, RESET restores
- [ ] INVERT CAMERA PAN behaves as labeled
- [ ] Dpad/stick navigate ALL menus incl. lobby, settings, pre-match modal; A agrees

## Session 3 — Touch pass (real phone, web build)

Setup: phone on same Wi-Fi → https://friday-evacuation.vercel.app
- [ ] Touch controls appear WITHOUT tapping anything (AUTO detect)
- [ ] Main-menu TOUCH button cycles AUTO→ON→OFF with the resolved state in the label
- [ ] Joystick + BOOST/JUMP/TRAP: comfortable thumb zones; buttons don't steal joystick touches
- [ ] Powerups auto-collect on touch (no E needed)
- [ ] Pre-match modal I AGREE works by touch
- [ ] 30fps+ felt during floor-1; floor culling keeps it smooth on upper floors
- [ ] Landscape/portrait both usable (landscape expected primary)

## Session 4 — Two-machine LAN + hotspot (the real Phase 5)

Setup: two machines (or phone hotspot + laptop + phone), same subnet ideally.

### Discovery & lobby
- [ ] SCAN finds the host; host sees "your address: x.x.x.x" in the lobby
- [ ] Join by typed IP works even when SCAN finds nothing
- [ ] macOS firewall prompt appears on host; allow → joins fine
- [ ] Roster shows names/colors; READY UP gates the host's START button

### Map sync (NEW — software-verified, never tested on real peers)
- [ ] Host picks CUBICLE MAZE, client picked OPEN PLAN locally → everyone races the maze
- [ ] Client's own menu MAP pick is unchanged after the match (check their menu after)
- [ ] Late join a running match → late joiner spawns on the host's map

### In-match sync
- [ ] Both chairs visible and interpolating smoothly (no rubber-banding at rest)
- [ ] Opponent's trap drop appears on your screen; their pickup despawns for you
- [ ] Stuns replicate (opponent visibly spins)
- [ ] Chat works lobby + in-match
- [ ] Ghost racer absent in multiplayer

### Hotspot mode (no Wi-Fi)
- [ ] Host via phone hotspot; laptop joins with the one-tap gateway button (Android 192.168.43.1/49.1, iPhone 172.20.10.1)
- [ ] If SCAN dies under AP isolation, the unicast sweep still finds the host
- [ ] 4-player sanity: 3 laptops + 1 host — spawn slots distinct, no chair overlap

## Session 5 — Secondary modes quick pass (30 min total)

Each mode: one full loop, pre-match modal correct, HUD timer honest.
- [ ] HAULED: deliver fridge of bees; damage/scoring reads; throw physics sane
- [ ] SHOP & SEEK: disguise in/out (2s freeze, wobble tell), guard stun, 5-item list beatable in 90s
- [ ] PIZZA COLONY: claim a pad (3s), cheese harvest, olive bomb fort, chef chase, cutter sweep elimination
- [ ] Modifiers: toggle 2-3 chips (NO COFFEE + JUST WAXED) → race applies them; LAN match ignores modifiers (single-player only)

## Regression guards (already automated — don't hand-test)

The bot now proves these headlessly: `bash scripts/run_ladder.sh` (32 suites)
+ `scripts/CheckpointBotTest.gd` (checkpoint traversal: 3 elevators, respawn
point advancement, real ExitZone finish signal, chair-only finish).

## After each session

Note anything that felt wrong with numbers (times, distances, screen). File
tuning as a list — the GLM polish pass eats concrete numbers for breakfast.
