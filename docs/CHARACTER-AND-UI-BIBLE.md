# Friday 5PM: Evacuation — Visual & Character Bible

## Design language: “Corporate Panic”

Friday is not generic neon sci-fi. It is a dead-serious corporate safety system being used for absurd chair racing.

Core contrast:
- Environment: fluorescent office beige, charcoal carpet, faded cubicle blue.
- Interface: near-black `#0a0a0f`, paper-white `#f7f6f2`, emergency orange `#ff9a1a`.
- Secondary signals: elevator cyan `#57d7ff`, approval lime `#b9f34a`, incident coral `#ff6f61`, HR violet `#9b82ff`.
- Typography: condensed uppercase for status/labels; large blunt sentence case for decisions.
- Shapes: 12–14px panels, 2px active borders, clipped “badge” corners, thick progress tracks.
- Motion: cards snap 2–4px, labels stamp in, results panels overshoot once. No endless bouncing except tiny ambient status lights.

## UI hierarchy

1. Primary action: orange fill, black text, minimum 54px desktop / 56px touch.
2. Selected mode: mode accent border plus darker accent fill; never color alone—retain `>>`/status text.
3. Secondary action: dark surface, hairline cyan or white border.
4. Prototype modes: honest `PROTOTYPE` label; never imitate full playable state.
5. Danger/destructive: coral. Success/exit: lime. Traversal/elevator: cyan.

HUD style:
- Treat it as building-operations telemetry, not fantasy HUD chrome.
- Timer label: `EVACUATION WINDOW`.
- Floor: `FLOOR CLEARANCE 02 / 04`.
- Boost: `CHAIR THRUST`.
- Traps: `INCIDENTS FILED`.
- Results: workplace incident report language with comedy in secondary copy.

## Character construction rules

Every character must read at gameplay distance using three layers:
1. Silhouette: hairstyle/headwear + torso block.
2. Chair: distinct backrest/wheelbase profile.
3. Prop: one oversized accessory, readable from behind and in profile.

Avoid face-detail dependence. Faces may be two eyes + brow/mouth state. Color never carries identity alone; chair and prop remain unique for colorblind readability.

### Roster

#### Deadline Dana — Project Manager
- Silhouette: upright blazer, rolled sleeves, sharp shoulder line.
- Chair: executive chair with exaggerated tall back.
- Prop: clipboard used like a shield.
- Palette: orange body, cyan accents.
- Animation: checks watch during idle; points forward while boosting.

#### I.T. Iggy — Systems Administrator
- Silhouette: hoodie, large headset, rounded posture.
- Chair: breathable mesh task chair.
- Prop: keyboard strapped behind chair as a booster fin.
- Palette: cyan body, lime LEDs.
- Animation: chair flickers/reboots after stun.

#### H.R. Harriet — People & Culture
- Silhouette: power bob, cardigan, immaculate posture.
- Chair: ergonomic chair with absurd lumbar support.
- Prop: policy binder that flaps open during jumps.
- Palette: pink body, yellow details.
- Animation: writes notes after collisions.

#### Intern Ian — Unpaid Velocity
- Silhouette: oversized hoodie, lanyard too long.
- Chair: borrowed rolling stool—small seat, wide unstable wheels.
- Prop: stack of coffees balanced overhead.
- Palette: lime body, violet details.
- Animation: coffees wobble independently; panic face during boost.

#### Finance Fiona — Budget Control
- Silhouette: sharp suit, high bun, compact profile.
- Chair: premium lumbar chair she claims was “already approved.”
- Prop: calculator mounted like a dashboard.
- Palette: violet body, cyan data lights.
- Animation: calculator prints receipts after collecting coffee.

#### Facilities Frank — Building Operations
- Silhouette: hi-vis vest, tool belt, broad stance.
- Chair: maintenance cart/chair hybrid with mismatched casters.
- Prop: mop used as a lance.
- Palette: yellow body, coral hazard stripes.
- Animation: taps wheels with wrench during idle.

#### Legal Lee — Risk & Compliance
- Silhouette: long coat, rectangular glasses, narrow profile.
- Chair: leather high-back with severe geometry.
- Prop: waiver scroll trailing like a ribbon.
- Palette: coral body, white legal-paper accents.
- Animation: raises objection finger after trap hit.

#### Remote Ron — Camera Off
- Silhouette: blanket shoulders, giant headphones.
- Chair: gaming rig with RGB ring.
- Prop: webcam drone hovering where a badge should be.
- Palette: teal body, orange status LED.
- Animation: occasionally freezes for two frames as a visual gag—not gameplay movement.

## Procedural 3D budget

Per character target:
- 8–14 primitive MeshInstance3D nodes beyond base chair.
- One StandardMaterial3D per main palette color; share resources.
- No extra shadow-casting light.
- Accessory animation via transforms only.
- Keep silhouette pieces under 600 total triangles when converted to authored meshes later.
- LOD/mobile: hide tiny face pieces and secondary prop details; preserve chair, silhouette, main prop.

## Integration contract

`res://scripts/CharacterRoster.gd` is authoritative for IDs, names, role copy, palette, chair, silhouette, accessory, and face key.

Recommended next slice:
1. Add `selected_character_id` persistence to `GameManager`.
2. Build `CharacterVisual.gd` that accepts one roster dictionary and adds primitive meshes under `PlayerChair/ModelParent`.
3. Apply same builder to menu preview and gameplay chair; never maintain separate portraits/models.
4. Add colorblind pattern decals: vertical stripe, checker, diagonal stripe, split block.
5. Verify eight silhouettes in one lineup scene at gameplay camera distance and mobile renderer.
