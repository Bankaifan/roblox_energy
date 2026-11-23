# Plot themes with decoration (design)

Issue: #308 (design note, no implementation in this PR). Refs #308.

## 1. Goal

Plot Themes (pass `themes`, 129 Robux) only recolours the ground strip, the fence and the sign today. Goal: each theme is a small
world on the plot, with its own decoration and atmosphere (Christmas with snow, snowmen, lights and gifts; Halloween with pumpkins,
cobwebs, tombstones and lanterns; Autumn with leaf piles and coloured trees; Summer with flowers and a beach corner), while the plant
cells, the river, the yard furniture, the walk lanes and the sign stay free. Everything is built from plain parts, nothing is uploaded,
and a theme costs nothing per frame.

## 2. Current state (file references)

- `src/shared/Core/Cosmetics.luau`: `THEMES = { "classic", "desert", "night" }`, `SLOT_THEME = 2`; `flags()` gives `theme` (default
  `classic`) and `themed` (pass owned); `choose()` and `nextItem()` check the slot list; `THEME_LOOKS` holds three RGB rows (`ground`,
  `fence`, `sign`), read by `themeLook(id)`.
- `src/server/Services/PlotStyle.luau`: `PlotStyle.theme(model, origin, facing, theme)` destroys the old `Theme` folder and builds a new
  one: 4 ground strips (3 studs wide, `Grass`), 48 fence posts (every 16 studs on the inner line at +-93), 4 rails, the name sign and
  its post at plot-relative (24, road side). That is 58 parts. All parts are anchored, `CanCollide`, `CanQuery`, `CanTouch` and
  `CastShadow` off.
- `src/server/Services/PlotService.luau:966-977`: `style()` runs once a second and rebuilds the theme only when `themeKey` changes, so fast
  taps on the style button collapse into one rebuild a second. The plot model streams atomically (`PlotService.luau:816`;
  `default.project.json`: `StreamingEnabled`, target radius 640).
- `src/client/Controllers/Style.luau:18`: the theme button sends `SetCosmetic` with `Cosmetics.nextItem(SLOT_THEME, current)`; the server
  checks it again (`Session.luau:295`) and saves the id as text in slot `"2"`.
- `src/shared/Config/Shop.luau:89`: pass `themes`; `src/shared/Config/Locale.luau:288-297, 601-610`: `offer.themes.info`
  ("Three designs for ground, fence and sign") and `style.theme.<id>` in English and German.
- Site map (`src/shared/Config/Assets.luau`, plot-relative studs, unmirrored, road side is +z, a plot with facing -1 is mirrored in z by
  the caller): tile 8, plot 192 (+-96), fence line +-93. Fields: F1 x -88..-48 z 8..48; F2 river course `Assets.river` (band 8, seeded
  per slot by `Core/River.course`); F3 x 0..88 z 16..56; F4 columns 7 and 9 (x -40..-32, -24..-16) z 0..56; F5 x 40..72 z -48..-16; F6
  four 32-stud cells x -88..88 z -88..-56 with 16-stud gaps at x -56..-40, -8..8, 40..56. Yard z 56..96: crank (0, 72), founder sign
  (9, 72), spawn pad 12 studs at (0, 88), market x -76..-36 z 68..88, container at (36, 78) (14 x 8, Mega Battery x1.25), control board
  (52, 78), name sign x 17..31 z 91. Ground cables (`Core/Cable.links`) run from every F5 and F6 cell to the control board.
- There is no walk-path data today; players walk the yard and the lane between F4 and F3 (x -16..0).
- `Lighting` belongs to `Ambience` and the weather (`docs/weather-sky-design.md`); plot terrain belongs to `PlotGround` (meadow grass,
  bare patches, restored when a plot is freed).

## 3. Options with trade-offs

- A. More colours only (today's approach, more rows). Cheap, but it is exactly what the issue calls not enough. Rejected.
- B. Free Toolbox or marketplace models (snowmen, pumpkins, palms). Look good, but bring unreviewed scripts, unknown part counts and
  licences, and an asset id per model. Rejected, as for the weather.
- C. Own meshes uploaded as assets. Best shapes, but needs uploads (forbidden here) and a mesh pipeline. Rejected for now; a kind can
  switch to a mesh later without touching the layout.
- D. Plain parts: `Part` (Block, Ball, Cylinder), `WedgePart`, `CornerWedgePart`, `SpecialMesh` with a built-in `MeshType` (Sphere,
  Cylinder, Wedge; no asset id) for squashed shapes, `Material` and `Color`, `Neon` for glow, built-in particle textures. No upload, every
  part counted. Chosen. A cone (tree tier) is four `CornerWedgePart`s; a pumpkin is a sphere mesh scaled (1, 0.8, 1).
- Lighting per plot: impossible (one `Lighting` for the server) and owned by the weather. Rejected; a theme shows its mood with colours,
  materials, `Neon` parts and a few `PointLight`s.
- Snow cover: a) parts over the meadow (hundreds of parts, fight the cells), b) `PlotGround` writes `Snow` instead of `Grass` as the meadow
  material of a Christmas plot (one writer, patches stay bare earth, grass blades vanish because they grow on `Grass` only). b chosen,
  as its own step, since it costs a terrain write per theme change.

## 4. Chosen approach

### 4.1 Theme list

Ids are appended, so saved choices (`classic`, `desert`, `night`) stay valid and `classic` stays the default. `Cosmetics.THEMES` becomes
`classic, desert, night, spring, summer, autumn, halloween, christmas`.

| Id (EN / DE) | Mood | Ground strip (material, RGB) | Fence | Sign |
|---|---|---|---|---|
| classic (Classic / Klassisch) | the farm as it is | Grass 96,150,70 | 150,110,70 | 190,150,100 |
| desert (Desert / Wüste) | dry, hot, sun-bleached | Sand 214,180,120 | 170,100,60 | 232,120,70 |
| night (Night / Nacht) | quiet blue night with lamps | Grass 40,56,96 | 70,80,120 | 20,28,56 |
| spring (Spring / Frühling) | fresh blossom, pastel | LeafyGrass 110,190,80 | 240,240,235 | 230,150,180 |
| summer (Summer / Sommer) | beach holiday, bright | Sand 230,210,150 | 240,240,240 | 40,170,190 |
| autumn (Autumn / Herbst) | golden harvest afternoon | Grass 150,120,50 | 120,80,50 | 200,110,40 |
| halloween (Halloween / Halloween) | spooky but friendly, orange glow | Ground 70,52,40 | 40,36,44 | 90,40,120 |
| christmas (Christmas / Weihnachten) | cosy winter, warm lights in snow | Snow 240,244,250 | 235,235,240 | 180,30,40 |

The look row gains a `material` name per strip (text, so Core stays free of Roblox enums; `PlotStyle` maps it to `Enum.Material`).

### 4.2 Decoration sets

Zones (computed by Core, section 4.3): `rim` = within 5 studs inside the fence line, `yard` = z 60..90 outside the furniture,
`corner` = the east yard corner x 60..90 z 60..90 (the free 30 x 30 square beside the control board, the first thing seen from the
road), `open` = any other free spot, `near:<kind>` = within 10 studs of the first placed piece of that kind, `fenceRoad` = along the
road-side rail every N studs, skipping the sign and the spawn pad. Parts = parts per piece x count.

**Christmas** (121 parts, 1 light, snowfall)

| Piece | Built from | Count | Zone | Parts |
|---|---|---|---|---|
| Christmas tree, 12 studs | trunk cylinder, 3 tiers of 4 CornerWedges, Neon star, 8 Neon bauble balls; star PointLight | 1 | corner | 22 |
| Snowman | 3 balls (4, 3, 2), 2 black eyes, orange wedge nose, hat of 2 cylinders | 2 | open | 16 |
| Gift | box block + 2 ribbon strips, red/green/gold | 6 | near:tree (4), yard (2) | 18 |
| Fairy lights | Neon balls 0.6 on the road rail, red/green/gold/blue in turn | 31 | fenceRoad every 6 | 31 |
| Small pine | trunk + 4 CornerWedges | 6 | open (F6 gaps first) | 30 |
| Snow on rails | thin white block on top of each rail | 4 | the rails | 4 |

**Halloween** (104 parts, 6 lights, wisps)

| Piece | Built from | Count | Zone | Parts |
|---|---|---|---|---|
| Jack-o'-lantern | sphere-mesh body, stem cylinder, 2 Neon wedge eyes, Neon mouth; PointLight on 3 | 8 | rim, yard | 40 |
| Giant pumpkin, 7 studs | as above, one PointLight | 1 | corner | 6 |
| Plain pumpkin | body + stem | 6 | near:giant pumpkin | 12 |
| Tombstone | Slate slab + cylinder top | 6 | rim (back side first) | 12 |
| Cobweb | 4 thin white bars (0.1, transparency 0.3) in a fence corner | 4 | the four corners | 16 |
| Dead tree | dark trunk + 3 angled branch blocks | 3 | open | 12 |
| Post lantern | Neon orange block on a road-side post, PointLight on 2 | 6 | fenceRoad every 32 | 6 |

**Autumn** (61 parts, no lights, falling leaves)

| Piece | Built from | Count | Zone | Parts |
|---|---|---|---|---|
| Maple tree | trunk + 3 LeafyGrass balls in orange, red, yellow | 4 | corner (1), open (3) | 16 |
| Leaf pile | 2 flattened sphere meshes, orange and red | 10 | near:maple (4), open (6) | 20 |
| Hay bale | cylinder (like the world bale) | 4 | yard | 4 |
| Scarecrow | post, arm bar, head ball, shirt block, hat (2), straw block | 1 | open | 7 |
| Pumpkin | body + stem | 4 | near:hay bale | 8 |
| Harvest crate | wood block + apple ball | 3 | yard | 6 |

**Summer** (70 parts, 2 lights)

| Piece | Built from | Count | Zone | Parts |
|---|---|---|---|---|
| Beach corner | Sand disc 18, 2 umbrellas (pole, canopy disc, top ball), 2 deck chairs (3 wedges/blocks), towel (2), beach ball | 1 | corner | 16 |
| Palm tree | 2 leaning trunk cylinders + 4 green leaf wedges | 3 | open, rim | 18 |
| Flower | stem + bloom ball, mixed colours | 12 | rim | 24 |
| Sandcastle | base block, 2 tower cylinders, flag wedge | 1 | near:beach corner | 4 |
| Tiki torch | pole + Neon flame, PointLight on 2 | 4 | fenceRoad every 40 | 8 |

**Spring** (61 parts, no lights, petals): blossom tree (trunk + 3 pink balls) x3 = 12 (corner, open); tulip bed (soil block + 5 tulips
of stem and bloom) x3 = 33 (rim); Easter egg (sphere mesh 1 x 1.3, pastel) x10 = 10 (open); bird house (post, box, roof wedge) x2 = 6 (yard).

**Desert** (21 parts): cactus (body cylinder + 2 arm cylinders) x5 = 15 (open, rim); rock (block, Slate) x6 = 6 (open).
**Night** (18 parts, 4 lights, fireflies): lamp post (pole, Neon head, PointLight) x4 = 12 (yard, fenceRoad); bench (seat, back, legs as
one block) x2 = 6 (yard). **Classic** keeps no decoration: it is the baseline and the look without the pass.

Every piece is anchored with `CanCollide`, `CanQuery`, `CanTouch` off (no piece blocks walking or the tool and click raycasts);
`CastShadow` only on the centrepiece. Each kind lives in one builder function in a new server module `ThemeProps.luau` and returns its
parts in a `Model` named after the kind; a later mesh swap changes only the builder.

### 4.3 Where decoration may stand (pure Core module `Core/ThemeDecor`)

No Roblox APIs, no `require` of other modules; the caller passes the data (like `PlotLayout` and `River`).

- `ThemeDecor.keepOut(input)` returns boxes in plot-relative studs: every cell of every field, mown or not (so the decoration never has to
  move when the plot grows), plus a gap (1.5 studs for low pieces up to 3 studs high, `Assets.CLEARANCE` for taller ones); every
  furniture box at its largest size (container x `Cosmetics.MEGA_CONTAINER_SCALE`), the crank, the founder sign spot, the spawn pad, the
  name sign, plus `CLEARANCE`; the walk lanes from `Config/Themes.lanes` (proposal: yard lane x -36..60 z 62..90, north lane x -16..0
  z -56..62, back lane z -56..-48 over the full width; checked in Studio in step 3).
- Lines that are not boxes: the river course samples (distance to the centre line at least `band + CLEARANCE` + half the footprint) and
  the cable links of all F5 and F6 cells to the board (`Cable.links` by the caller; distance at least half the footprint + 2).
- `ThemeDecor.sites(set, keepOut, lines, seed)`: candidates on a 2-stud grid inside the fence (`|x|, |z| <= 93 - footprint/2 - 0.5`),
  filtered by zone; pieces are placed in the set's order, each on the candidate chosen by an integer hash of (seed, piece, n) like
  `PlotLayout.wild`, so the same (theme, slot) gives the same layout on every machine. A placed piece blocks its footprint plus 2 studs
  for the next ones. A piece with no candidate left is dropped (never overlapped); the tests below make sure that does not happen on the
  real map. `fenceRoad` pieces come from `ThemeDecor.fenceLine(every, keepOut)`. Result: `{ kind, x, z, yaw, scale }`, `yaw` in 90-degree
  steps plus a hash wobble of up to 15 degrees, `scale` 0.9..1.1. The seed is the plot slot, so neighbours do not look identical.
- `PlotStyle` mirrors z by facing (as for every other site) and adds the origin.

### 4.4 Atmosphere

- Ground strip, fence and sign: colours and material from the look row (section 4.1).
- Snow cover (Christmas only): `PlotGround` takes the meadow material from the theme (`Grass` by default, `Snow` for Christmas); bare
  patches, the river and the rope stay as they are, a freed plot gets `Grass` back. Terrain material colours are global; `Snow` is used
  nowhere else today, so this changes no other plot.
- Lights: at most 6 `PointLight`s per plot, `Range` 8 to 12, `Brightness` 1, `Shadows` false. Fairy lights and most lanterns are `Neon`
  without a light. Lights show most at night, which the day cycle already brings; `Lighting` is never touched.
- Particles: at most one `ParticleEmitter` per plot, on one invisible anchored box part over the plot (`Shape` Box, `ShapeStyle` Volume),
  built-in texture only, `Rate` at most 10: Christmas snow (white, 8/s), Autumn leaves (orange specks from the corner tree, 4/s), Spring
  petals (pink, 3/s), Halloween wisps (pale green, low, 2/s), Night fireflies (yellow, 3/s). Summer and Desert have none. The engine runs
  them; no script.

### 4.5 Performance budget

- One folder per plot: everything of a theme stays in the existing `Theme` folder of the plot model, so it streams with the plot and is
  destroyed as one when the theme changes or the player leaves (today's `PlotStyle.theme` already does both).
- Parts: base 58 + decoration at most 152 = `THEME_PARTS` 210 per plot (Christmas 121 + 58 = 179 is the largest set). That is 15% of the
  plant budget `Assets.MAX_PLANT_PARTS` (1400); 8 plots add at most 1680 anchored parts to a server.
- Lights at most 6, emitters at most 1 with `Rate` at most 10 per plot (8 plots: 80 particles a second at most).
- No per-frame work: no scripts in the decoration, no tweens, no `Heartbeat`. The server builds a theme only when `themeKey` changes
  (at most once a second), never on a plant purchase, a mown cell or a battery upgrade.

### 4.6 Choice, save and shop

- The pass and the slot stay: `themes` pass, `SLOT_THEME = 2`, `Cosmetics.choose()` and `nextItem()` work on the longer list unchanged; the
  style button cycles through 8 themes. Saved ids are unchanged, so no migration. A player without the pass sees nothing new.
- Shop: same pass, same price and Roblox id; only the info text changes. Assumption: all themes are open all year to every pass owner
  (a seasonal lock would take away what was sold).
- Optional last step: a ninth item `season` that picks the theme by the server date (Core: `ThemeDecor.season(month)`: Mar-May spring,
  Jun-Aug summer, Sep-Nov autumn but October halloween, December christmas, January-February classic). Open; it ships only if the cycle
  with nine items still feels fine.

### 4.7 Texts (English / German, in `Config/Locale`)

| Key | English | German |
|---|---|---|
| `offer.themes.info` | `Eight plot worlds with their own decoration: Christmas, Halloween, Autumn, Summer and more` | `Acht Grundstücks-Welten mit eigener Deko: Weihnachten, Halloween, Herbst, Sommer und mehr` |
| `style.theme.spring` | `Spring` | `Frühling` |
| `style.theme.summer` | `Summer` | `Sommer` |
| `style.theme.autumn` | `Autumn` | `Herbst` |
| `style.theme.halloween` | `Halloween` | `Halloween` |
| `style.theme.christmas` | `Christmas` | `Weihnachten` |
| `style.theme.season` (optional step) | `Season` | `Jahreszeit` |

## 5. Migration and compatibility

Additive. No remote, no save field, no price change. Saved slot `"2"` keeps its meaning; an id that a rollback removes falls back to
`classic` through `flags()` (already tested). `PlotPublic` carries the same `theme` id.

## 6. Test and verification plan

Lune, each must be able to fail on today's code:
- Every id of `Cosmetics.THEMES` has a look row with a known material name, a `Config/Themes` set and `style.theme.<id>` in English and
  German (today five ids are missing).
- For every theme and slot seeds 1 to 8, on the real `Config/Assets` map: no site box overlaps a keep-out box, the river band or a cable
  line; every site lies inside the fence; no two pieces overlap; every piece of the set is placed (none dropped).
- Same (theme, seed) twice gives equal lists.
- Budget: for every theme, 58 + the parts of all placed pieces <= `THEME_PARTS`, lights <= 6, emitters <= 1 with `Rate` <= 10.
- (optional step) `season(month)` for all twelve months.
- Studio (MCP read and test tools only, open until run): a screenshot per theme from the road, the part count of the `Theme` folder by
  a read-only `execute_luau`, a walk from the spawn to the market, the container and the north lane without hitting a piece.

## 7. Rollback

Each step is one rebase-merged commit set. Reverting a builder step leaves the looks; reverting step 1 brings back three themes and
saved new ids fall back to `classic`. Reverting the snow step gives Christmas plots grass again.

## 8. Split into PR-sized implementation issues

Each issue carries `Design: docs/themes-design.md`, at most ~400 changed lines, and a `changelog.d/<issue>.md` fragment.

### Step 1: Eight themes with their colours and materials
Files: `src/shared/Core/Cosmetics.luau`, `src/server/Services/PlotStyle.luau`, `src/shared/Config/Locale.luau`, `tests/Cosmetics.test.luau`
Acceptance: the style button cycles 8 themes, each strip, fence and sign shows its colour and material, texts exist in English and German.

### Step 2: Decoration sites in Core
Files: `src/shared/Core/ThemeDecor.luau`, `src/shared/Config/Themes.luau`, `tests/ThemeDecor.test.luau`
Acceptance: for every theme and slots 1 to 8 every piece is placed inside the fence and off cells, river, cables, furniture, lanes and sign.
Depends on: 1

### Step 3: Christmas and Halloween decoration on the plot
Files: `src/server/Services/ThemeProps.luau`, `src/server/Services/PlotStyle.luau`, `src/server/Services/PlotService.luau`
Acceptance: a Christmas and a Halloween plot show their sets in Studio, the `Theme` folder has at most 210 parts, the walk lanes are free.
Depends on: 2

### Step 4: Autumn, Summer and Spring decoration
Files: `src/server/Services/ThemeProps.luau`, `src/shared/Config/Themes.luau`
Acceptance: the three themes show their sets in Studio within the budget test.
Depends on: 3

### Step 5: Desert and Night decoration
Files: `src/server/Services/ThemeProps.luau`, `src/shared/Config/Themes.luau`
Acceptance: Desert shows cacti and rocks, Night lamp posts and benches, within the budget test.
Depends on: 3

### Step 6: Theme lights and particles
Files: `src/server/Services/PlotStyle.luau`, `src/shared/Config/Themes.luau`, `tests/ThemeDecor.test.luau`
Acceptance: Christmas snows, Autumn drops leaves, Spring petals, Halloween wisps, Night fireflies; at most 6 lights and 1 emitter per plot.
Depends on: 3

### Step 7: Snow cover on Christmas plots
Files: `src/server/Services/PlotGround.luau`, `src/server/Services/PlotService.luau`
Acceptance: a Christmas plot's meadow is `Snow`, patches stay bare, switching away or leaving gives `Grass` back.
Depends on: 1

### Step 8 (optional): Season item
Files: `src/shared/Core/ThemeDecor.luau`, `src/shared/Core/Cosmetics.luau`, `src/shared/Config/Locale.luau`, `tests/ThemeDecor.test.luau`
Acceptance: `season` picks the theme by the server month; all twelve months are tested.
Depends on: 4

Steps 4, 5 and 6 touch the same files and run one after another; step 7 runs beside steps 2 to 6.

## 9. Open

- The lane boxes and the zone sizes are a proposal; step 3 checks them in Studio.
- Step 8 is optional (section 4.6).
