# Worker and chair model sheets

Authority: Astra; implement with the [art bible](ART-BIBLE.md).
Dimensions are meters at scale 1.0. Triangle counts include accessories.
These are construction sheets for reusable visuals inside procedural builders.
They do not authorize controller, collider, stat, or network changes.

## 1. Assembly contract

Retain PlayerChair as the gameplay CharacterBody3D.
Retain ModelParent as the facing and presentation root.
Preserve the ChairMesh reference expected by the existing script.
Attach replacement visuals under the existing presentation hierarchy.
Keep rider_root, chair_seat, chair_backrest, and chair_wheels addressable.
An adapter may reference authored children through the existing fields.
Do not rename network IDs or serialize visual bone transforms.
Keep skin_id and character_id independent.
Keep the selected chair skin's existing gameplay multipliers intact.
The roster's names, role strings, face keys, and unlock ownership remain intact.
The old 600-triangle silhouette ceiling is superseded by plan v2.
The old 8–14 primitive-node goal is not a requirement for authored detail.
Do not preserve primitive faceting merely to preserve a node count.

### Coordinate convention

Assembly origin is the existing gameplay root; do not move it to a new pivot.
Sheet ground plane is wheel contact Y = 0.
The adapter offsets the sheet ground plane to the existing controller ground.
Forward is local -Z; right is +X; up is +Y.
Seat center lies at X = 0, Z = 0.
Positive Z is the chair back.
Workers face -Z in the neutral pose.
All size changes are visual and stay within the existing interaction envelope.
If an existing collider is smaller than the sheet, scale the full visual uniformly.
Do not individually squeeze heads or wheels to force a fit.
GLM reports the required uniform scale if it differs from 1 by over 5%.

## 2. Neutral worker — front elevation

| Part | Width | Height/length | Depth | Ground-relative center |
|---|---:|---:|---:|---|
| Head excluding hair | 0.255 | 0.300 | 0.245 | (0, 1.355, -0.005) |
| Neck | 0.105 | 0.080 | 0.105 | (0, 1.175, 0.015) |
| Torso | 0.440 | 0.440 | 0.250 | (0, 0.980, 0.030) |
| Pelvis | 0.345 | 0.200 | 0.270 | (0, 0.705, 0.000) |
| Upper arm each | 0.115 | 0.245 | 0.125 | Shoulder pivot at (±0.24, 1.12, 0.02) |
| Forearm each | 0.105 | 0.225 | 0.110 | Elbow driven by neutral pose |
| Hand each | 0.105 | 0.190 | 0.060 | Rest near (±0.31, 0.87, -0.21) |
| Thigh each | 0.155 | 0.320 | 0.160 | Seated, projects toward -Z |
| Shin each | 0.110 | 0.320 | 0.120 | Knee near (±0.15, 0.61, -0.31) |
| Shoe each | 0.130 | 0.100 | 0.290 | Sole 0.12 above ground |

All part lengths describe design masses, not a required skeleton topology.
Shoulder-to-head ratio is 1.73:1.
Hip width is 78% of shoulder width.
Hands are deliberately 15% larger than realistic adult scaling.
Knees remain separated by 0.10 m at their nearest inner edges.
Front-view hands do not merge into the seat rim.
The head is never a perfect sphere.
Flatten the cheeks and back of skull by 8% relative to the side ellipse.
Nose projection is 0.025 m; ears project at most 0.020 m.
Hair adds at most 0.10 m to head height except Fiona's bun.

## 3. Neutral worker — side elevation

The seated spine tilts 6° toward the backrest.
Head tilts 3° forward to suggest attention.
Hip pivot sits 0.07 m above the cushion top.
Upper legs slope downward 8° toward the knees.
Shins slope 12° forward from vertical.
Feet point forward with 8° outward splay per side.
Elbows bend approximately 95° in the resting pose.
Wrists remain outside the armrest top faces.
Backrest contacts the lower torso without swallowing the shoulders.
Clothing thickness is 0.012 m at cuffs and 0.018 m at jacket hems.
Collar flaps are geometry at LOD0/1 and merged wedges at LOD2.
No simulated cloth is required.

## 4. Neutral worker — rear elevation

Hair mass, shoulder line, elbows, and chair badge are the four reading anchors.
The backrest hides at most the lower 60% of the torso.
The head has at least 0.10 m clearance above the backrest in ordinary chairs.
Tall-back variants leave both elbows and hair cap visible.
Keep the accessory on one side or centered above the badge, never across it.
Badge center is 0.96 m above ground on the rear-facing backrest plane.
Badge plate is 0.18 × 0.18 m, protruding 0.006 m.
Badge icon occupies 0.12 × 0.12 m inside that plate.
Plate is INK; icon is IVORY with a 0.018 m player-color edge strip.
A stool uses the same badge on a short rear plate below the worker's waist.

## 5. Chair orthographic dimensions

| Component | Exact neutral dimensions | Position/shape |
|---|---|---|
| Wheelbase | Diameter 0.90 | Five spokes at 72° intervals |
| Spoke | 0.34 long × 0.075 wide × 0.055 high | Tapers toward caster |
| Caster pair | Each wheel diameter 0.11, width 0.025 | Two wheels around a 0.022 fork gap |
| Fork | 0.07 wide × 0.08 high | Visible U-profile |
| Gas column | Diameter 0.075, exposed height 0.24 | Centered under seat |
| Column shroud | Diameter 0.11, height 0.12 | Slate telescoping sleeve |
| Seat cushion | 0.52 wide × 0.49 deep × 0.10 thick | Top at Y = 0.62 |
| Seat shell | 0.54 wide × 0.51 deep × 0.035 thick | Below padding |
| Back cushion | 0.47 wide × 0.55 high × 0.10 thick | Top at Y = 1.20 |
| Back shell | 0.49 wide × 0.57 high × 0.035 thick | Behind cushion |
| Armrest pad | 0.065 wide × 0.27 long × 0.045 thick | Top at Y = 0.88 |
| Arm support | 0.035 square, 0.20 high | Distinct from gas column |
| Adjustment lever | 0.11 long × 0.025 thick | Right underside; visual only |

Seat front lip drops 0.015 m over its front 0.06 m.
Seat center has a 0.012 m depression; do not use a flat box top.
Back cushion rolls inward by 0.025 m at each side.
Padding seam sits 0.020 m inside the perimeter.
Five-spoke structure is preserved even for maintenance and gaming variants.
Caster sizes may differ visually by ±10%, preserving the same ground contact.
Mesh task chairs use opaque perforation artwork, not alpha-cutout mesh fabric.
No additional light is attached to a chair.
No chair has a mirror-like chrome base.

## 6. Three explicit LODs

LOD0 is the closest gameplay and lobby model.
LOD1 is the middle-distance model.
LOD2 is the distant gameplay and Android default model.
No fourth cinematic model is required.
Combined LOD0 maximum is 35,000 triangles, including accessory and badge.
Use the same three material families for all LODs.

| Component allocation | LOD0 | LOD1 | LOD2 |
|---|---:|---:|---:|
| Head, face, hair | 5,200 | 1,700 | 480 |
| Torso and clothing | 4,800 | 1,600 | 500 |
| Arms and hands | 3,600 | 1,200 | 360 |
| Legs and shoes | 3,400 | 1,100 | 360 |
| Primary accessory | 2,500 | 800 | 220 |
| Worker subtotal | 19,500 | 6,400 | 1,920 |
| Seat and back padding | 5,000 | 1,600 | 440 |
| Chair shell and armrests | 3,500 | 1,100 | 350 |
| Five-spoke base and column | 2,500 | 800 | 240 |
| Five caster assemblies | 3,500 | 900 | 300 |
| Badge and controls | 1,000 | 200 | 150 |
| Chair subtotal | 15,500 | 4,600 | 1,480 |
| Combined ceiling | 35,000 | 11,000 | 3,400 |

The allocation is a ceiling, not a demand to spend every triangle.
Unused head allocation may move to a hairstyle within the same worker subtotal.
Do not borrow from environment allocation to exceed the assembly ceiling.
Accessory swaps must all fit the reserved 2,500/800/220 allocation.
Round rings and sleeves need silhouette subdivisions, not hidden backside subdivisions.

### LOD selection policy

Standard/Enhanced use LOD0 at camera distance below 8 m.
Use LOD1 from 8 m to below 20 m.
Use LOD2 from 20 m onward.
Apply 1 m hysteresis around both thresholds.
Limit simultaneous LOD0 worker/chair assemblies to four in gameplay.
The local player has first priority; choose remaining slots by camera distance.
Other nearby players use LOD1 without losing identity cues.
Use opaque swaps at a stable pose; no transparent crossfade shells.
Do not cull players merely because they exceeded an LOD distance.
Lobby shows one LOD0 preview; roster entries are UI badges, not nine 3D portraits.
Android uses LOD1 for the local player and LOD2 for others.
Android lobby uses one LOD1 preview.
Disguised Shop & Seek players use the stock-product LOD policy instead.

### Preserved through every LOD

Keep head outer contour, hair mass, shoulders, elbows, and footwear direction.
Keep the five-spoke base, armrest silhouette, and backrest family.
Keep accessory outer contour and identity badge.
Keep enough geometry for steering, compression, and impact poses.
Merge fingers into a mitten form at LOD2; keep thumb projection.
Merge caster pairs into forked wheel silhouettes at LOD2.
Remove seam geometry, screws, keyboard keys, and receipt print first.
Never remove identity shapes or turn the stool into a tall-backed chair.

## 7. Material and texture slots

Slot A: worker atlas, one shared 2K base/normal/ORM set.
Slot B: chair atlas, one shared 2K base/normal/ORM set across color variants.
Slot C: shared accent/accessory atlas, 1K base plus constant roughness where sufficient.
The shared accessory atlas is charged once in residency accounting.
Skin, hair, cloth, and shoes are atlas regions of slot A.
Padding, rubber, plastic, and metal are atlas regions of slot B.
Badge and accessory artwork use slot C or reserved regions in A/B.
Use per-instance palette masks or vertex color for player accents.
Do not create one unique texture set per roster member or player color.
There are normally at most three material slots for the whole assembly.
No transparent hair cards, transparent headset lenses, or dangling decal stacks.
Face expressions use the worker atlas or solid geometry, not a fourth material.

## 8. Roster silhouette sheets

### Deadline Dana — deadline_dana

Body/accent: ORANGE / TEAL.
Front: 0.46 m blazer shoulders and squared collar.
Side: upright spine, 0.04 m pointed jacket hem.
Rear: short angular hair and narrow shoulder-to-waist taper.
Chair: executive back top at 1.34 m with rounded rectangular crown.
Accessory: clipboard shield 0.24 × 0.32 m on left forearm.
Idle: one watch glance every 9 s, lasting 0.65 s.
Boost: right index-hand wedge points forward within the hand envelope.
LOD2 cue: squared blazer plus high rectangular back plus clipboard slab.

### I.T. Iggy — it_iggy

Body/accent: TEAL / BUTTER.
Front: 0.44 m hoodie shoulders and 0.055 m headset ear cups.
Side: 10° relaxed forward posture, hood bulge behind neck.
Rear: rounded hood and short horizontal keyboard fin.
Chair: mesh-task silhouette; opaque slate back with teal perimeter.
Accessory: keyboard 0.36 × 0.13 m strapped behind the backrest.
Idle: 4° head nod every 11 s; no bright flickering LEDs.
Stun: one slate-to-butter screen icon change, never a flashing light.
LOD2 cue: ear cups, hood, low keyboard rectangle.

### H.R. Harriet — hr_harriet

Body/accent: VIOLET / BUTTER.
Front: cardigan with 0.42 m shoulders and straight placket.
Side: immaculate upright posture and 0.055 m lumbar bulge.
Rear: power bob cut flat across the nape.
Chair: ergonomic back with two large connected cushion lobes.
Accessory: policy binder 0.24 × 0.30 m beside right thigh.
Idle: binder opens 15° once every 10 s.
Impact: pen-hand gesture lasts 0.30 s after recovery, not during stun.
LOD2 cue: bob, two-lobe back, binder rectangle.

### Intern Ian — intern_ian

Body/accent: BUTTER / VIOLET.
Front: oversized hoodie 0.48 m wide and short visible neck.
Side: nervous 8° forward lean with raised shoulders.
Rear: low stool exposes the full hoodie silhouette.
Chair: borrowed rolling stool with 0.48 m round padded seat.
Accessory: three coffee cups as one stack, maximum 0.36 m high.
The coffee stack attaches beside the right shoulder, not over the camera target.
Lanyard is part of clothing, 0.18 m visible length, not a second hero prop.
LOD2 cue: hood, exposed back, coffee tower, low seat.

### Finance Fiona — finance_fiona

Body/accent: VIOLET / TEAL.
Front: suit shoulders 0.41 m with a narrow lapel wedge.
Side: compact posture; hair bun radius 0.07 m.
Rear: high bun and compact premium lumbar back.
Chair: back top at 1.18 m with a broad lower cushion and narrow neck.
Accessory: calculator dash 0.20 × 0.14 m between armrests.
Idle: two button taps every 12 s, each 0.10 s.
Pickup: one attached paper tab extends 0.05 m then retracts over 0.60 s.
LOD2 cue: bun, pinched back, dashboard block.

### Facilities Frank — facilities_frank

Body/accent: BUTTER / CORAL.
Front: 0.50 m vest shoulders, two broad ivory safety strips.
Side: thick toolbelt is a single clothing band, not loose tools.
Rear: broad shoulders and horizontal maintenance chair brace.
Chair: five-spoke maintenance variant with 0.10 m squared spoke sleeves.
Accessory: mop handle 0.75 m long with a 0.15 m head, carried diagonally.
Mop tip stays within 0.25 m of the assembly's outer visual envelope.
Idle: hand taps the armrest; no independent wrench prop is added.
LOD2 cue: broad vest, square brace, diagonal mop.

### Legal Lee — legal_lee

Body/accent: CORAL / IVORY.
Front: 0.40 m narrow coat with rectangular glasses.
Side: coat hem ends above the wheelbase; no trailing cloth on floor.
Rear: severe high-back crown with clipped 0.04 m corners.
Chair: padded leather-look back top at 1.32 m, roughness 0.60.
Accessory: waiver scroll 0.16 m wide, exposed length 0.28 m.
Idle: raises one finger for 0.45 s every 13 s.
Impact: scroll unrolls 0.06 m then returns with the recovery pose.
LOD2 cue: narrow coat, clipped crown, paper ribbon.

### Remote Ron — remote_ron

Body/accent: TEAL / ORANGE.
Front: blanket shoulders 0.49 m wide and 0.065 m headphones.
Side: relaxed curved blanket hem, no hidden wheel contacts.
Rear: broad headband and high gaming-chair shoulder wings.
Chair: gaming rig uses a solid orange inset ring, never animated RGB.
Accessory: webcam 0.10 × 0.08 m on a short attached stalk.
It may hover visually by 0.025 m; it has no physics or network identity.
Idle: brief cosmetic freeze specified in the art bible.
LOD2 cue: blanket wedge, headphones, winged back, camera dot block.

## 9. Player identity independent of roster

The same character can be chosen by multiple players.
Roster silhouette identifies the character; slot badge identifies the player.
The lobby assigns a stable session slot to each peer and preserves it on ready changes.
The host occupies slot 1; later peers fill the lowest available slot.
Slots are not ranks and do not change with race position.
Network.gd allows eight clients in addition to the host; design for nine visible slots.
If GLM confirms a stricter gameplay occupancy, unused slots remain harmless.

| Slot | Accent | Badge | Additional graphic cue |
|---|---|---|---|
| 1 | ORANGE | Circle | One vertical stripe |
| 2 | TEAL | Square | Two vertical stripes |
| 3 | VIOLET | Triangle | One diagonal stripe |
| 4 | BUTTER | Diamond | Two diagonal stripes |
| 5 | CORAL | Pentagon | Split horizontal block |
| 6 | IVORY | Hexagon | Checker of four large cells |
| 7 | ORANGE | Cross | Central horizontal bar |
| 8 | TEAL | Semicircle, flat edge down | Wide center column |
| 9 | VIOLET | Eight-point star | Corner blocks |

Use numerals 1–9 beside badges in lobby, results, and permitted world nameplates.
In-world badges are flat inserts, never protruding competitive silhouette changes.
Clothing player-color area is limited to shoulder patches and sleeve bands.
Chair player-color area is the rear badge strip and 0.04 m seat-rim band.
Do not recolor skin, hair, whole chairs, or entire costumes with the slot color.
Freeform legacy player colors quantize to the nearest listed accent for display.
The shape and numeral remain stable even if an accent repeats.
In Shop & Seek, disguise presentation suppresses all public player identity cues.
Private HUD identity remains visible only to its owner.

## 10. Accessory restrictions and handoff

One readable primary accessory per worker is mandatory.
Tiny clothing details do not become independent props.
Accessories do not block the forward camera ray or hide another player's hazard cue.
All accessory motions stay inside the neutral envelope plus 0.10 m.
No new rigid bodies, cloth simulation, bones synchronized over LAN, or light sources.
A chair skin may change cushion seams and shell contours within the same envelope.
It cannot obscure the character silhouette or player badge.
All skins reuse the five-spoke construction and three-slot budget.
Menu previews and gameplay instantiate the same visual resources.
GLM inventories pivots, atlas regions, LOD counts, and attachment references.
Any existing gameplay skin that cannot fit this envelope returns to Astra for a specific variant sheet.

## 11. Repeated environment mesh ceilings

Counts include visible bevels and attached visual details, excluding separate gameplay actors.
Repeated props use at most two materials; distant groups share those materials.
Prop LOD0/1/2 distances are 0–10 m / 10–24 m / 24 m onward, with 1 m hysteresis.
Shop stock/disguises use identical distances and mesh resources.
A grouped shell must preserve every gameplay-relevant cover surface.

| Mesh family | LOD0 tris | LOD1 tris | LOD2 tris | Required outer cue |
|---|---:|---:|---:|---|
| Desk or conference table | 2,400 | 800 | 160 | Slab, inset support, rounded corners |
| Unoccupied office chair | 5,000 | 1,500 | 450 | Padding, armrests, five-spoke base |
| Cabinet or copier | 3,600 | 1,000 | 240 | Recessed face, stepped lid, toe kick |
| Cubicle partition module | 800 | 240 | 48 | Framed opaque panel |
| Plant and pot | 2,400 | 720 | 240 | Three broad opaque leaf masses |
| Crate or utility trolley | 2,400 | 720 | 180 | Reinforced rim and handle |
| Retail shelf bay | 2,000 | 600 | 200 | Solid back, trays, end cap |
| Stock/disguise product | 1,200 | 400 | 120 | Category silhouette and cover envelope |
| Cargo hero shell | 12,000 | 4,000 | 1,200 | Cargo type and emotion articulation |
| Stair two-flight bay | 8,000 | 2,400 | 600 | Two flights, landing, rail silhouette |
| Atrium facade 4 m bay | 2,000 | 600 | 120 | Story bands, parapet, mullions |
| Parked car | 4,000 | 1,200 | 300 | Roof, hood, wheel arches |
| Pizza ingredient/pad | 2,400 | 720 | 240 | Raised disc/food contour |
| Fort | 1,200 | 400 | 120 | Blocking wall and stapler cap |
| Portal with sign | 3,000 | 1,000 | 300 | Open frame, sign, arrow |

Sign numerals/arrows remain legible independently of the frame's LOD.
The per-view allocation in PRESETS takes precedence over summed per-asset maxima.
