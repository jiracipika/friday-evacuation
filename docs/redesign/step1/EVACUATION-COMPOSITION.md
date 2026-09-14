# Evacuation — four-story atrium composition

Authority: Astra. Primary mode; strongest environment and marketing composition.
Use with [art bible](ART-BIBLE.md) and [presets](PRESETS.md).
Dimensions below describe visuals around existing procedural geometry.

## 1. Spatial decision

The building has exactly four playable stories, numbered 01, 02, 03, 04.
The existing progression ascends from 01 to 04.
The parking destination is an elevated parking deck connected to story 04.
Do not invert progression to match an assumed ground-floor escape.
Do not introduce story 00, a playable roof, or a basement.
The atrium is a four-story edge court visible through the south facade.
This preserves the solid 40 × 40 m slabs on stories 01, 02, and 04.
Do not cut a new central hole through those colliders.
The existing gapped story 03 remains the special stairwell crossing.
An exterior-facing atrium court supplies shared vertical sightlines without a layout rewrite.

### Existing coordinate contract

| Story | Internal index | Slab origin Y | Existing theme | Step 1 identity |
|---|---:|---:|---|---|
| 01 | 0 | 0 | Cubicles | ADMINISTRATION / clock wall |
| 02 | 1 | 6 | Open office | COLLABORATION / meeting drum |
| 03 | 2 | 12 | Gapped stairwell | FACILITIES / switchback gantry |
| 04 | 3 | 18 | Cafeteria and lot | DEPARTURES / parking portal |

The procedural floor footprint is X/Z = -20 to +20.
Slab top is approximately origin Y + 0.10; retain actual collision placement.
The existing lift transfer anchors use Y + 0.50.
Visual fixtures derive their grounding offset from the actual surface.
Signs use displayed story numbers, never raw zero-based indices.

### Atrium placement

Place the non-playable atrium court beyond Z = +20.
Its visual footprint is X = -20 to +20, Z = +20 to +32.
The opposite court wall stands at Z = +32.
Its four balcony bands align to Y = 0, 6, 12, 18.
No extra balcony band above story 04 may read as a fifth story.
Roof trim is a thin cap at Y = 24, with no floor numeral or doors.
Court bottom is an ivory planter bed and slate paving at Y = -0.15.
The opposite wall is 70% ivory plaster, 20% slate frame, 10% landmark inserts.
Use opaque window panels or sparse glazing per preset policy.
Retain existing wall colliders; atrium-facing visual openings do not grant traversal.
Opaque 1.10 m parapet infill makes retained collision boundaries understandable.
Window frames above the parapet are 0.10 m thick.
Window bays are 4 m wide, aligned across all four bands.
The parking portal occupies the story-04 bay centered at X = 0.

## 2. Composition hierarchy

1. Parking portal: largest sign, strongest frame, bright open center.
2. Current story numeral and next transfer arrow.
3. Landmark silhouette unique to the current story.
4. Warm/cool architectural masses and balcony rhythm.
5. Furniture groups and restrained surface detail.

Do not give a decorative copier or billboard a sign larger than the route signs.
The portal sign is visible from atrium-facing windows on every story where sightlines permit.
It need not be visible through opaque slabs or walls.
At occluded positions, local arrows point to the next actual transfer.
No through-wall world beacon is introduced.
The minimap may show the destination icon according to existing map behavior.
Distant floor numerals stay attached to architectural shells when room detail is culled.

## 3. Story 01 — Administration

Mood: the office is still pretending work is happening.
Dominant architecture: IVORY walls with SLATE lower skirting, 0.12 m high.
Floor: cool teal carpet inserts inside quiet ivory/slate circulation zones.
Landmark: oversized office clock on the atrium-facing wall.
Clock diameter is 1.8 m; face IVORY, rim SLATE, hands INK.
Hands show 4:59; clock has four major marks and no animated second hand.
Clock center is X = -8, Y = 3.6 on the inner south wall.
Pair it with the 01 numeral on a 2.0 × 1.5 m slate plaque.
Plaque lower edge is Y = 1.8.
Cubicle partitions retain existing placement and collision.
Visual fabric panels have a 0.05 m ivory frame and 0.02 m inset.
Desk clusters group in threes; scatter-free corridor edges are mandatory.
Only one paper tray and one monitor are visible on each dressed desk.
Route to the first transfer is reinforced by arrows toward (12, 0.5, 14).
No orange carpet strip crosses a non-traversable cubicle partition.
Threshold sign copy: UP TO 02 / COLLABORATION.

### Story 01 framing target

At spawn, the chair occupies the lower center.
Clock landmark sits in the upper-left or upper-middle field.
First transfer arrow sits on the right third when visible from the current route.
The atrium light is a side accent, not a white full-screen background.
Two furniture masses frame the route without adding collision.
Existing spawn slots and checkpoint routes have priority over dressing.

## 4. Story 02 — Collaboration

Mood: a meeting was interrupted at exactly the wrong moment.
Dominant architecture: IVORY walls with broad TEAL acoustic panels.
Floor: quiet laminate in meeting areas; carpet on retained circulation surfaces.
Landmark: a circular meeting-room drum visible through the atrium facade.
The non-colliding facade feature is centered at X = -8, Z = 23.
Its visual diameter is 3.2 m and height 2.4 m above story 02.
Use an ivory cylindrical canopy, teal lower panels, and slate mullions.
No transparent cylinder encloses playable space.
Numeral 02 sits on the drum's inward face, 1.2 m tall.
Conference table visuals retain their existing placement and proxy shape.
Tables gain a 0.06 m thick rounded laminate slab and two inset pedestal feet.
Monitors face away from the main escape line to keep silhouettes quiet.
Route points from the arrival anchor toward (-12, 6.5, -2).
Threshold sign copy: UP TO 03 / FACILITIES.

### Story 02 framing target

The meeting drum is the story's single round architectural landmark.
Keep nearby props rectilinear so the drum remains distinct.
One warm key patch crosses the route before the transfer entrance.
The transfer sign remains readable against a cool wall plane.
Do not add a competing orange presentation screen.

## 5. Story 03 — Facilities

Mood: the building's practical machinery is now part of the race.
Preserve the existing concrete landing rectangles and real fall-through gaps.
Do not cover gaps with a new visual floor, carpet, or non-colliding bridge.
Dominant materials are slate-painted metal, ivory concrete, and teal equipment.
Landmark: visible switchback stair flights and a square gantry frame.
Gantry is decorative beyond the playable boundary at X = +15, Z = +23.
Frame width is 3.6 m; height is 4.2 m above story 03.
Frame sections are 0.18 m thick with rounded 0.012 m corners.
Numeral 03 is 1.2 m tall on a 1.8 × 1.6 m ivory plate.
Add a wrench pictogram 0.40 m high beneath the numeral.
Keep current crates at their existing collision locations.
Crate visuals gain recessed handles and a 0.045 m edge rail.
Gap edges use coral/ivory teeth aligned to the actual collision edge.
Tooth band is 0.18 m wide; alternating teeth are 0.25 m long.
Route arrows stay at least 0.35 m inside supported ground.
Route points toward (12, 12.5, 14).
Threshold sign copy: UP TO 04 / PARKING.

### Gap readability

Supported surfaces are matte, broad, and continuous.
Void interiors are cool SLATE with no false horizontal cap.
Hazard teeth end exactly where supported floor ends.
Do not use butter stripes for a gap; butter is reserved for warm materials and highlights.
Rails only appear where existing collision already prevents departure.
An unguarded playable edge must not receive a decorative protective rail.
Safety language must describe what the controller can actually traverse.

## 6. Story 04 — Departures

Mood: the cafeteria opens toward freedom and a very ordinary parking deck.
Dominant architecture: IVORY canopy, TEAL seating, warm laminate counters.
Landmark: PARKING EXIT portal centered on the actual finish approach.
Existing ExitZone center is (0, 18.5, 15).
Its current BoxShape3D dimensions are 10 × 6 × 4.
Keep this trigger, its name, and race-completion signal unchanged.
The approach plane is Z = 13, the near edge of the trigger volume.
Place a 0.20 m orange threshold band on supported ground at this edge.
Frame uprights stand outside X = ±5 so they do not narrow the trigger.
Upright visible width is 0.30 m; portal crown is 0.45 m high.
Portal sign is 6.0 × 0.85 m, mounted above the clear opening.
Text is PARKING EXIT with a 0.60 m car pictogram and forward arrow.
Sign ground is ORANGE; lettering and pictogram are INK.
The far deck beyond the trigger uses simplified parked-car silhouettes.
Show three cars at most, each with a different large roof profile.
Use slate, ivory, and teal car colors; avoid a fourth orange destination-like mass.

### Dominance rules

Parking sign letters are 0.45 m cap height.
Ordinary story labels are 0.22 m cap height.
Portal is the only 6 m wide high-contrast sign in the building.
Its frame is SLATE; the area behind it is warm IVORY lit by the key.
No glow haze, translucent green finish cube, or pulsing giant arrow remains.
Use a static open portal, a ground threshold, and directional geometry.
Keep cafeteria furniture clear of the existing final approach.
The exterior deck is connected to story 04; do not imply a hidden fifth floor.

## 7. Switchback stair transition design

The approved image establishes switchback architecture.
The existing game uses triggered lift transfers, explicitly to avoid stair physics issues.
Step 1 preserves those transfers and makes their purpose legible.
Place the playable lift landing beside an architectural switchback stair bay.
Label the landing CHAIR LIFT plus an upward arrow and destination number.
Label the inaccessible stair flight STAFF STAIRS on a slate plate.
Do not put an orange route arrow on an inaccessible tread.
Stairs provide building identity; the chair lift remains the traversable transition.
Walkable chair stairs would be a separate gameplay change requiring a constraint report.

### Stair module dimensions

Each story gap is 6 m, split into two 3 m rises.
Each flight has 18 visible risers at 0.1667 m nominal height.
Each tread run is 0.28 m; flight projected run is 5.04 m.
Flight clear width is 2.2 m.
Midlanding depth is 2.4 m.
Flights sit side by side with a 0.30 m central gap.
Total bay width is 4.7 m and length 7.44 m.
Rail height is 1.10 m with 0.055 m top rail.
Stringer depth is 0.22 m, painted SLATE.
Treads are IVORY with a 0.035 m SLATE nosing.
Midlandings have no story numeral, preventing them from reading as extra stories.
Mount these bays outside X = ±20, within decorative edge volumes.
Right-side bays connect 01–02 and 03–04; left-side bay connects 02–03.
Stair geometry receives simplified distant LODs without losing the two-flight outline.
All decorative stairs remain outside the player's existing navigable/collision envelope.

### Transfer anchors and presentation

| Transfer | Existing entry | Existing arrival | Landing header |
|---|---|---|---|
| 01 → 02 | (12, 0.5, 14) | (12, 6.5, -2) | CHAIR LIFT ↑ 02 |
| 02 → 03 | (-12, 6.5, -2) | (-12, 12.5, 14) | CHAIR LIFT ↑ 03 |
| 03 → 04 | (12, 12.5, 14) | (12, 18.5, -2) | CHAIR LIFT ↑ 04 |

Use the actual Area3D footprint for each landing's orange perimeter.
Place four solid corner brackets, each 0.25 m long and 0.08 m wide.
Interior plate is matte SLATE with a large IVORY chair-and-up-arrow symbol.
Any lift enclosure uses opaque lower panels and open upper structure.
No glowing cyan glass tube is needed for recognition.
During transfer, display GOING UP / 02, 03, or 04 in the objective strip.
Do not animate a false physical trip along stairs between remote anchors.
Keep the current controller's transit duration and checkpoint update timing.
Update the destination numeral only when the actual checkpoint advances.

## 8. Route-signage grammar

| Sign type | Size | Content | Placement |
|---|---|---|---|
| Story plaque | 2.0 × 1.5 m | 1.2 m numeral + department | Facing arrival route |
| Decision plate | 1.4 × 0.50 m | Arrow + destination | 1.8 m lower edge |
| Reassurance plate | 0.80 × 0.35 m | Arrow + next story number | After long straight |
| Floor arrow | 0.70 × 1.00 m | Solid shaft + triangle | Supported route surface |
| Lift header | 1.8 × 0.50 m | CHAIR LIFT ↑ NN | Above trigger approach |
| Parking crown | 6.0 × 0.85 m | Car + PARKING EXIT + arrow | Final portal |
| Hazard plate | 0.70 × 0.45 m | Exclamation + named hazard | Before actual boundary |

Route plates are ORANGE with INK arrows and type.
Floor arrows use ORANGE fill with a 0.025 m INK border.
Arrow shaft is one-third of arrow width.
Arrow head occupies the forward 40% of its length.
A left or right arrow rotates the whole shape by 90°.
A transfer arrow points up and includes a chair icon and destination number.
No chevron may point toward an inaccessible decorative balcony.
Reassurance signs repeat every 8 m of unobstructed route at most.
Place a decision sign 2 m before the actual turn where geometry permits.
Place one confirmation arrow 1 m after the turn.
Avoid more than three route signs in a single ordinary camera view.
At constrained corners, use one wall plate instead of overlapping floor arrows.
Noto Sans Bold is used for numerals and sign lettering.
Text uses real authored glyphs; do not copy generated concept lettering.
All signs are opaque meshes or opaque atlas regions with mipmaps.
Android uses the same arrow geometry, word content, and physical dimensions.

## 9. Camera compositions and shell visibility

The spawn composition reveals a destination system before detailed scenery.
The atrium-facing composition shows four bands and one dominant portal.
The transfer approach shows supported ground, the trigger brackets, and its destination.
The story-03 composition shows actual voids without effects covering their edges.
The story-04 composition frames the finish in the center third.
These are framing briefs, not new scripted camera movements.
Do not seize the camera during a race to display architecture.
Keep existing chase and orbit control rules from the art bible.

Detailed current-story rooms are a visibility partition.
Adjacent-story furniture uses simplified grouped meshes.
Other stories retain only architectural shells, numerals, and landmarks.
Register shell and detail groups separately from the existing all-floor culling list.
Do not let current _update_floor_culling hide all four-story evidence.
Room instancing groups must not span the whole building.
Opaque parapets, canopy bands, and end caps supply useful occlusion.
Static reflection probes are bounded to rooms, not updated during a match.
Every shell and sign counts toward the 500,000 visible-triangle ceiling.

## 10. Implementation handoff

Use _build_floor and _build_floor_walls as geometry integration points.
Use the four _theme_floor functions for story-specific visual replacements.
Use _add_floor_number and _add_exit_indicators for the signage system.
Use _build_elevator for landing frames and retained transfer presentation.
Use _add_exit_marker to replace the current green-volume finish appearance.
Use _register_floor_node with distinct shell/detail ownership.
Do not change checkpoint positions, spawn slots, obstacle proxies, or finish geometry.
If a specified decorative anchor intersects an existing protected lane, omit that prop instance.
The landmark moves only along its assigned facade bay; its scale and visual role stay fixed.
If no such placement fits, report the collision and proposed facade anchor to Astra.
No new measurement route or engine run is part of this document delivery.
