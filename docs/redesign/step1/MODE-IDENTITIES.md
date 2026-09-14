# Mode identity sheets

Authority: Astra. Shared direction: tactile corporate slapstick.
Use the [art bible](ART-BIBLE.md) for materials, characters, and cameras.
Use [UI layouts](UI-LAYOUTS.md) for shared hierarchy and [presets](PRESETS.md) for parity.
This specifies existing gameplay presentation, not new mode mechanics.

## 1. Shared identity system

Every mode has one large environmental shape, one supporting palette, and one icon.
Primary actions remain ORANGE even when a mode's decorative accent differs.
Danger remains CORAL plus a physical edge or warning symbol.
Character proportions and chair construction remain consistent across modes.
Mode selection does not introduce a different font or HUD grid.
Use one rectangular mode stamp, 32 × 32 px, beside its title.
Icons use a 3 px stroke at 32 px size with rounded joins.
They have a filled 16 px fallback for compact UI.

| Mode | Mode icon | Accent | Large form | Material contrast |
|---|---|---|---|---|
| Evacuation | Chair plus forward arrow | ORANGE | Four stacked balcony bands | Ivory plaster / teal upholstery |
| Hauled | Crate with two lifting handles | CORAL | Rectangular loading portal | Painted metal / cardboard |
| Shop & Seek | Shopping bag with eye cutout | TEAL | Parallel cream shelf rows | Matte stock / satin packaging |
| Pizza Colony | Pizza wedge with flag | BUTTER | Circular crust horizon | Rough crust / soft cheese |

Labels describe the actual supported mode state.
Evacuation leads the menu and is the default selection.
Hauled reads DELIVERY PLAYABLE where the current delivery loop is available.
Shop & Seek reads SHOPPER PLAYABLE for the current fallback.
Pizza Colony reads SURVIVAL PLAYABLE for the current loop.
Do not advertise seeker/hider multiplayer as complete from role scaffolding alone.
No visual specification creates a new network capability.

## 2. Evacuation identity sheet

Promise: recognizable office workers flee an absurdly formal safety system.
Hero composition: warm four-story edge atrium, teal furniture, orange parking portal.
Architecture uses 6 m story rhythm and 4 m facade bays.
Floor numbering and landmarks follow EVACUATION-COMPOSITION exactly.
Furniture silhouettes are thick slabs, soft cushions, visible frames, and inset handles.
Use one comedy prop cluster per 8 × 8 m office zone at most.
A comedy cluster contains at most three objects and no new rigid bodies.
Paper piles are merged wedges; sheets do not scatter across the route.

### Palette and light

Walls are IVORY; rails and window frames are SLATE.
TEAL marks upholstery and limited carpet inserts.
ORANGE appears on route geometry, lift brackets, and the parking sign.
CORAL appears only on actual hazards and warning plates.
Sun key is BUTTER at 1.0 energy, falling obliquely across the route.
Cool fill uses the art-bible fixed-layout or arbitrary-layout values.
Reflection captures show broad windows, not moving characters.

### Gameplay objects

| Object | Silhouette | State cue | Forbidden treatment |
|---|---|---|---|
| Coffee pickup | Oversized cup with handle | Orange ring plus cup icon | Tiny glowing dot |
| Stapler pickup | Long wedge with open jaw | Stapler glyph and charge count | Abstract orb |
| Water spill | Low scalloped puddle | Ivory rim, coral warning wedges | Invisible transparent patch |
| Banana hazard | Three-lobed peel | Coral/ivory warning triangle nearby | Yellow color alone |
| Roomba | Flattened disc with bumper | Directional front notch | Unmarked dark floor disc |
| Moving door | Thick panel on visible hinge | Striped leading edge | Whole-door strobe |
| Falling debris | Broad paper-box mass | Existing-event ground marker | New physics dressing |
| Finish | Open framed portal | Car icon, words, threshold | Translucent green cube |

Warnings are attached to existing hazard activation events.
Do not invent extra prediction time or change hitboxes to match a cosmetic animation.
If an existing event provides no warning phase, keep the physical boundary readable.
The route must remain visible under all pickup effects.

### Readability contract

Player can identify current story without reading the timer.
Player can identify the next transfer by arrow, chair icon, and story numeral.
The parking exit is the largest destination marker.
Supported surfaces and gaps never share the same edge treatment.
The objective strip states the next action, not generic mode flavor text.
Boost readiness is a labeled bar and icon, not a tiny color change.
No decorative floor pattern resembles a spill boundary.
All these rules survive Android mesh and texture reductions.

## 3. Hauled identity sheet

Promise: office machinery resists being delivered like an uncooperative colleague.
Hero composition: a cargo silhouette between cool utility walls and a warm loading bay.
Large forms are reinforced rectangular frames and low rolling trolley shapes.
Use a SLATE lower wall band from ground to 1.2 m, IVORY above.
Wall service strips are 0.16 m wide and repeat every 6 m.
Loading portal has 0.25 m frame sections and a 0.70 m header.
ORANGE arrows point along the delivery direction; CORAL marks cargo danger.
The utility floor is matte #B8B5AE, roughness 0.86, with 4 m low-contrast joints.
No polished floor reflection conceals dropped cargo.

### Integration anchors

Hauled.gd owns cargo types, terrain choices, three rounds, and delivery state.
Cargo spawn Z remains -20; delivery Z remains 25.
GRAB_RANGE remains 2.2 m and COOP_RADIUS remains 3.0 m.
Visual attachment grips align to the existing carry attachment.
Cargo collisions, mass, damage, and behavior remain owned by the current rigid body.
Replace only the visible primitive shell and local cosmetic articulation.
The reinforced trolley is part of the cargo visual where a support is appropriate.
Do not create a second simulated trolley body or tow constraint.

### Cargo sheets

| Cargo ID | Dominant palette | Preserved dimensions | Personality silhouette |
|---|---|---|---|
| fridge_of_bees | BUTTER / SLATE | 1.6 × 2.2 × 1.4 | Rounded tall box, offset handle, slanted vent brows |
| haunted_sofa | VIOLET / SLATE | 2.4 × 1.0 × 1.0 | Two sagging cushions, arched back, inward arms |
| angry_vending_machine | CORAL / IVORY | 1.4 × 2.2 × 1.2 | Tall beveled cabinet, recessed product grid, angry slot |
| wet_cardboard | #C99454 / SLATE | 1.4 × 1.4 × 1.4 | Soft bowed box, one drooping flap, broad waterline |
| exploding_cake | IVORY / CORAL | 1.2 × 1.0 × 1.2 | Two rounded tiers and one large cream crest |
| sentient_plant | #58724A / TEAL | 1.2 × 1.8 × 1.2 | Three broad leaf fans and heavy round pot |

Cargo size columns are X × Y × Z and retain the current gameplay envelope.
Recessed faces may create expression; no new floating cartoon face is required.
Bake tiny product windows into the vending atlas.
Plant leaves remain broad opaque geometry on all presets.
Wet cardboard uses a roughness band, not a particle drip shower.
Cake warning motion must follow existing explode state, not a new countdown.

### Cargo emotion grammar

| State | Pose | Indicator shape | Local animation |
|---|---|---|---|
| Available | Upright neutral | Open ivory handle brackets | 0.02 m breathing sway at 0.5 Hz |
| Held | Lean 4° away from carrier | Closed orange handle brackets | Lag 0.06 s behind carrier visual |
| Resisting | Tilt up to 8° | Coral zigzag plus exclamation | Two 0.08 s kicks, then 0.4 s hold |
| Damaged | Compress shell Y by 3% | Cracked shield icon | One 0.12 s recoil |
| Delivered | Upright settled | Teal check plus DELIVERED | 0.24 s settle, no looping bounce |
| Destroyed | Existing destroyed presentation | Coral X plus LOST | Stop optional idle immediately |

No emotion indicator claims hidden gameplay state.
If only behavior type is exposed, neutral and event-driven reactions suffice.
A carried cargo's value label sits in the HUD, never behind the cargo mesh.

### Delivery border and terrain

Delivery zone uses the exact existing Area3D footprint.
Draw an opaque orange 0.18 m perimeter with four 0.50 m corner brackets.
Place a crate-and-down-arrow symbol, 1.2 m wide, inside the zone.
Add DELIVER HERE on an ivory 2.0 × 0.5 m plate facing approach.
On completion, preserve the border and add a teal check; do not rely on a green fill.
Pendulum leading edges use coral/ivory stripes and visible hinge supports.
Conveyors use directional chevrons traveling with the existing belt direction.
Wrong-way escalators use opposing double arrows plus AGAINST FLOW text.
Flat gauntlet lanes remain quiet; no fake moving tread texture.

### Readability contract

Cargo type reads from its outer shape at LOD2.
Cargo emotion reads from pose plus indicator shape with color disabled.
Delivery limits match the actual trigger and never disappear on Android.
The carrier can see obstacles beside the cargo using the existing camera envelope.
The HUD leads with DELIVER CARGO, then time/value, then round/score.
Cosmetic resistance cannot change body mass or collision response.
Optional bees and debris cannot cover the delivery border.

## 4. Shop & Seek identity sheet

Promise: an orderly, pleasantly banal supermarket rewards careful observation.
Hero composition: cream end caps and repeating pastel stock under diffuse light.
Use seven existing aisles with 14 m shelves, 2.2 m shelf height, and 5 m aisle gap.
Preserve aisle positions, product spawn logic, and interaction distance 2.4 m.
The current round is 90 s; ignore older promotional copy claiming 60 s.
Cream fixture base is IVORY; structural feet and price rails are SLATE.
Packaging uses TEAL, VIOLET, BUTTER, and CORAL in category groups.
No randomly scattered saturated package colors across a shelf.

### Light and materials

Key is #F3E7D3 at energy 0.65, with the same 30° source elevation.
Cool ambient is #B8CDD2 at 0.45 for arbitrary layout, 0.20 with baked indirect.
Window amber is confined to the far checkout wall.
All stock surfaces remain readable in shadow with the same fixed exposure.
Shelf backs are opaque on every preset.
Freezer doors use opaque pale panels with printed frost borders.
Do not add reflective glass that reveals a player around a corner.
Product material roughness is 0.62 unless its category uses the art-bible food material.
Disguises use the identical mesh resource, palette, atlas region, and material as stock.

### Category groupings

| Category | Existing products | Shape family | Shelf accent |
|---|---|---|---|
| Produce | Avocado, Watermelon, Pineapple | Ovoid / broad leaf crown | TEAL band, leaf pictogram |
| Bakery/dairy | Baguette, Cheese Wheel, Milk Carton, Ice Cream | Long loaf / wheel / folded carton | BUTTER band, loaf pictogram |
| Breakfast | Cereal Box, Honey Jar, Orange Juice | Tall box / squat jar | VIOLET band, bowl pictogram |
| Condiments | Ketchup, Mustard, Hot Sauce, Pickles | Narrow neck / jar | CORAL band, bottle pictogram |
| Pantry | Soup Can, Cake Mix, Baking Soda | Can / compact box | BUTTER band, can pictogram |
| Household | Toilet Paper, Bleach, Detergent, Trash Bag | Roll / handled jug / tied bag | TEAL band, house pictogram |
| Pet supplies | Dog Food | Broad bag with folded top | VIOLET band, paw pictogram |

Each product retains its existing dimensions from DISGUISE_KINDS.
Category signs are 0.8 × 0.30 m with icon plus category name.
Shelf price strips are 0.05 m tall with large grouped marks, not tiny pseudo-text.
Repeat packaging in blocks of three to five facings.
A decorative facing that provides cover is part of the immutable cover shell.

### Disguise visibility policy

Hide worker, chair, accessory, public nameplate, player badge, and chair shadow when disguised.
Use the same object contact treatment as ordinary stock.
Do not keep a floating name label, boost trail, or rim light over a disguise.
Use the existing 2 s freeze and half-speed movement behavior.
Preserve the existing scale wobble: w = 1 + sin(phase) × 0.06.
Phase advances at 4 radians/s; scale is (w, 2 - w, w).
This gameplay tell persists on Android and with reduced motion.
Do not amplify it for Enhanced or suppress it for accessibility settings.
Private HUD may show DISGUISED and the freeze countdown.
Public scan feedback appears only from the actual authorized scan event.
Never add through-wall outlines or opponent markers as a cosmetic improvement.

### Readability contract

Category and product silhouettes create the hiding context.
No preset removes stock that can occlude a disguised player.
No preset makes the player prop smoother, shinier, brighter, or more outlined than stock.
Lighting, exposure, FOV, cover bounds, and interaction distance match across presets.
Texture reduction affects stock and disguised copies together.
Decorative mesh reduction preserves the stock's outer envelope.
Shopper HUD leads with COLLECT YOUR LIST and a count of actual collected items.
Hider/seeker labels only appear when those roles are genuinely active.
Scan cooldown is labeled with time and a ring, not hue alone.
Readability must not become an artificial reveal mechanism.

## 5. Pizza Colony identity sheet

Promise: tiny office improvisation takes place on a giant, tactile pizza.
Hero composition: broad butter cheese plain, rough golden rim, coral sauce basin.
Keep PIZZA_R = 25 m, CRUST_W = 3 m, and SAUCE_R = 7 m.
Keep ten pepperoni pads and existing claim/steal/resource timers.
The player remains the existing worker/chair controller.
Do not replace the player with an ingredient avatar without gameplay approval.
Office-supply silhouettes belong to forts, landmarks, and dressing.

### Surface forms

| Surface/state | Base | Form and edge | Readable meaning |
|---|---|---|---|
| Cheese ground | BUTTER | Broad smooth folds, matte ivory rim on safe joins | Traversable plain |
| Crust rim | #C99454 | Rounded ridge, coarse large pores | Outer supported perimeter |
| Sauce basin/channel | CORAL | Scalloped boundary, paired ivory dash marks | Slow terrain, not automatic death |
| Pepperoni neutral | #8E4938 | Raised disc with ivory segmented perimeter | Claimable pad |
| Pepperoni owned | Same base | Slot badge plus continuous teal perimeter | Owned territory |
| Active claim | Same base | Orange perimeter segment fills | Actual claim progress |
| Fort | IVORY / SLATE | Broad crust wall with stapler-shaped cap | Existing blocking structure |
| Cheese resource | BUTTER | Chunk with two geometric holes | Resource icon and count |
| Topping resource | CORAL | Disc with a triangular notch | Resource icon and count |
| Cutter danger | SLATE metal / CORAL | Visible blade and toothed danger line | Actual cutter footprint |
| Olive bomb | #58724A | Ovoid with large pimento notch | Existing fuse and danger radius |

Sauce is dangerous by slowdown/exposure; do not label it instant elimination.
The pizza's outside edge is a fall boundary with a broken ivory tooth pattern.
Boundary strips follow existing zone extents; no invented safe islands.
Cheese folds are visual relief at most 0.06 m high on flat gameplay ground.
Crust pore relief stays inside the existing outer silhouette.
Never displace a surface into a false ramp or step.

### Fort and threat presentation

Existing fort dimensions remain 2.0 × 1.0 × 0.5 m.
Use one crust block and one slate stapler-like cap within that envelope.
No extra collision is added for decorative office-supply parts.
Build affordance displays the actual cost: 5 cheese + 3 toppings.
Unavailable cost uses a lock symbol and named missing resource.
Cutter strip follows the actual 0.5 m width; visual teeth do not enlarge the hit area.
Olive threat radius is the existing 4 m radius.
Display its ground ring only during the actual 2 s fuse.
The ring is coral/ivory dashed geometry, visible on every preset.
Never hide a threat marker when an optional particle pool is full.

### Light and atmosphere

Use BUTTER key at energy 1.0 and cool fill from the shared lighting path.
Keep crust sides darker than cheese tops through material/vertex shading.
Sauce uses broad static reflections; no SSR or animated reflective ripples.
The horizon is IVORY fading to TEAL through opaque background art.
No fog obscures the outer edge or chef silhouette.
Chef's hat is a single broad ivory mass, not a cluster of small bubbles.
Office structures use recognizable staples, clips, and cardboard planes.
Do not copy the generated concept's fictional rule text onto signage.

### Readability contract

Safe ground is broad and continuous; fall edges have teeth.
Slow sauce has scallops and dash marks distinct from lethal threats.
Resources have different silhouettes and labeled counters.
Claimable, claiming, owned, and defended states differ by border shape.
Threat rings match existing gameplay radii and durations.
The HUD leads with CLAIM OR SURVIVE, then timer and resources, then pad count.
Reduced effects preserve cutter lines, olive rings, ownership, and resource icons.
The same territory remains visible and traversable on every preset.

## 6. Shared implementation boundaries

Evacuation.gd and OfficeDressing.gd own office placement and visual attachment points.
Hauled.gd owns cargo shells, delivery border, and terrain decoration.
ShopSeek.gd owns stock/disguise resource parity and category grouping.
PizzaColony.gd owns terrain zones, pads, forts, and threat visuals.
ModeHUD.gd retains configure/update_state entry points while adopting the shared layout.
Do not parse gameplay meaning from translated status strings to choose visual states.
Expose existing state values through a thin presentation adapter where necessary.
Do not invent new replicated state for ordinary cosmetic animation.
GLM reports missing event hooks as implementation questions, with these visuals as the target.
