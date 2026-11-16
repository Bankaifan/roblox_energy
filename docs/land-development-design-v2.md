# Land development v2: tool chains, site map, river, aligned rows, capacity

Revision of [land-development-design.md](land-development-design.md) (design 0018) after the owner's play test of 2026-11-16. Plan only, no
code in this PR. Where the two differ, this document wins; everything not named here (popups, hold timing through `Core/Work`, server-only
`Prepare`, two rows of four 192-stud plots, land kept on grid expansion) stays as in 0018.

Builds on: PR #149 (free mowing, `land.cells`, open), PR #146 (flat panels, measured along world axes, merged), PR #145 (container button,
open). Step 1 starts after #149 is on `main`.

## 1. What the play test asked for

| Nr | Feedback | Answer in this design |
| --- | --- | --- |
| 1 | Every tool has its own job; hammer and cable drum must not mow | A tool chain per field (section 2). A cell is worked in stages, each stage needs its tool in the hand |
| 2 | Mounting Rails must not align by themselves; aligned starter panels give x2 | `Align` is a player action per row of four (section 5) |
| 3 | A real river with flowing water, wheels in chains of four, nothing on top of the market | River along an organic course, terrain water, one axle with four wheels per segment (section 4); site map with tested clearances (section 3) |
| 4 | Panel rows end up odd | One mown tile holds exactly one row of four; a "fill row" buy step; only a full row can be aligned |
| 5 | The wind turbine is far too small | About 60 studs to the blade tip, a slow big rotor, a 32-stud tamped pad, four in a line at the back of the plot (section 6) |
| 6 | Buy gate against balance | Several units per cell: every field holds at least 100 units (section 2). Measured: all figures stay in their ranges (section 7) |
| 7 | Tutorial | Crank, shop, scythe into the hand, mow, panel, then one hint per new tool (section 8) |
| 8 | Container in the shop popup | Stays as built. A central shop reached by car stays a later idea, not designed here |
| - | The yellow disc under the crank is garish | Removed. A ring of small stones on the worn earth patch marks the crank (section 6) |

## 2. Fields, tool chains and capacity

A field consists of cells. A cell is worked in stages; `chain` lists the tool of each stage. The player stands on the cell with the right
tool in the hand and holds (as in #149: any cell, any order; the river is the exception, it is dug downstream). A cell is prepared when
its last stage is done. Units stand only on prepared cells and a prepared cell carries `capacity` units.

| Field | Plant | Cell | Cells | Chain (hold seconds) | What each stage shows | Visible per cell | Capacity per cell | Field total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| F1 | Balcony Panel | 1 tile (8 studs) | 25 | scythe 1 | bare earth with a wobbly outline | 4 panels | 4 | 100 |
| F2 | Water Wheel | 1 river segment (about 25 studs) | 7 | shovel 1, shovel 1 | a dry trench, then the bank is breached and water runs in | 1 axle with 4 wheels | 16 | 112 |
| F3 | Rooftop Solar | 2 x 2 tiles | 7 | scythe 1, hammer 2.5 | mown lot, then a house without PV (frame first, then walls and roof) | 4 roof arrays | 16 | 112 |
| F4 | Mini Turbine | 1 tile | 7 | scythe 1, wrench 1.5 | mown spot, then a guyed mast with a cross arm | 4 small rotors | 16 | 112 |
| F5 | Solar Farm | 2 x 2 tiles | 4 | scythe 1, hammer 2.5, cable drum 3 | mown, then a post fence, then cables on the ground from the grid box to the module feet | 1 module block | 25 | 100 |
| F6 | Wind Turbine | 4 x 4 tiles | 4 | scythe 1, tamper 4, cable drum 3 | mown, then a tamped gravel pad with a concrete foundation, then the grid cable | 1 turbine | 25 | 100 |

Rules:
- Gate (owner's rule): `BuyPlant` is accepted only while `owned < prepared cells x capacity`. The card says "Prepare more ground" otherwise.
- Units fill the visible places of all prepared cells first, one to one, in the order the cells were prepared. Only when every visible place is
  taken do further units go onto existing cells as stages II to IV (plants 2 to 4) or as a count (plants 5 and 6). A cell that holds more
  units than it shows carries one small plate "x12" at its edge (one part, text set by the server). So early purchases always show a new
  model, and the player chooses between more ground (more models) and denser cells.
- Rooftop PV: the hammer builds the house bare. Every bought unit puts one PV array on the roof (one part each, four per house).
- Tools are bought once and kept. A tool appears in the tool tab with the first plant that needs it (hammer with plant 3, drum with 5).
  Prices stay: scythe 0, shovel 30, hammer 250, wrench 2,500, cable drum 25,000, tamper 250,000, rails 300, pliers 600.

Tool tab, one line per tool (English text, German likewise, at most 60 characters):

| Tool | Text |
| --- | --- |
| Scythe | Mows grass. Every field except the river starts with it |
| Mounting Rails | Hold on a full row of four panels: aligned, output x2 |
| Shovel | Digs the river bed, then lets the water in |
| Hammer | Builds houses for rooftop PV and fences the solar farm |
| Wrench | Sets the mast for four mini turbines |
| Cable Drum | Lays the cables of the solar farm and the wind turbines |
| Tamper | Tamps the gravel pad for a wind turbine |
| Cable Pliers | Wires the control board to the container |

Parts on a full plot (parts per model from `Assets.partsPerModel`): panels built from two parts each plus two rails per aligned row 250,
wheels 28 x 19 + 7 axles = 539, houses 7 x 49 + 28 arrays = 371, mini turbines 28 x 4 + 7 masts = 119, solar farm 4 x 75 = 300, wind
4 x 20 = 80: 1,659 plant parts (`MAX_PLANT_PARTS` 1,700, today 1,300). Ground parts (fences, cables, plates, bridges, stones) at most 200
(`MAX_GROUND_PARTS`, new). Both sums are computed in a Lune test from config tables.

## 3. Site map (192-stud plot, 24 x 24 tiles)

Tile (column, row); column 0 is the left edge, row 0 the back, row 23 the road side. Stud x = column x 8 - 96, z = row x 8 - 96, relative to
the plot centre; a plot with facing -1 is mirrored as today. Column 0, column 23 and row 0 stay meadow.

| Zone | Tiles (columns, rows) | Studs (x, z) | Content |
| --- | --- | --- | --- |
| Wind line | 1-22, 1-4 | -88..88, -88..-56 | F6: four pads of 4 x 4 tiles at columns 1, 7, 13, 19; the tower stands up to 3 studs off the pad centre |
| Solar farm | 17-20, 6-9 | 40..72, -48..-16 | F5: four cells of 2 x 2 tiles in a block |
| River | 1-22, about 8-12 | course below | F2: spring, seven segments, pond |
| Panels | 1-5, 13-17 | -88..-48, 8..48 | F1: 5 x 5 tiles |
| Mini turbines | 7-9, 12-18 | -40..-16, 0..56 | F4: seven tiles in a zigzag: (8,12) (7,13) (9,14) (7,15) (9,16) (7,17) (9,18) |
| Village | 12-22, 14-18 | 0..88, 16..56 | F3: lots at columns 14, 17, 20 (rows 14-15) and 12, 15, 18, 21 (rows 17-18); each house is shifted by up to 1 stud and turned by up to 6 degrees |
| Yard | 1-22, 19-23 | -88..88, 56..96 | market centre (-56, 78), 40 x 20, front towards the plot; crank (0, 72); container (36, 78); control board (52, 78) |

River course (centre line, studs): spring (-84, -28), (-56, -16), (-28, -20), (0, -8), (28, -8), (56, 0), pond (80, -4). The line is a smooth
curve through these points plus a wobble of up to 2 studs from the plot seed; the water is 12 studs wide. Length about 175 studs, cut into
seven segments of equal length. Two plank bridges (five parts each) at about x = -42 and x = 14 appear when their segment is flooded; the
river is also shallow enough to wade.

Clearance rule, enforced by `tests/Assets.test.luau` (it fails on today's map: water wheel row 16 lies under the market): every cell of every
field, the river band (centre line plus 8 studs) and every furniture box keep at least 4 studs from each other and lie inside the usable
area. The numbers above are the starting values; the test is the truth and the implementer may move a point to satisfy it.

`Assets.fields` changes shape: a field is `{ size, cells = { { column, row }, ... } }` (the cell number is the index), the river is not a field
of tiles but `Assets.river = { points, width, segments }`.

## 4. River

- **Pure core** `Core/River.luau`: curve through the points (Catmull-Rom), sampled every 4 studs; `segment(k)` gives the sample range, the axle
  pose (middle of the segment, heading across the flow) and the two dig halves; `mask(done, seed, cells, cell)` gives the terrain cells of the
  dug part with wobbly banks (same noise as `Core/Meadow`); `bridges()`. Tests: deterministic, no heading change above 30 degrees between
  samples, clearance, every dug cell inside the plot.
- **Digging**: segment k can be worked only when k - 1 is flooded (the water comes from the spring). Stage 1 writes the trench (material Ground,
  surface 3 studs lower), stage 2 fills it with terrain Water up to 1 stud below the meadow and the foam starts. One `WriteVoxels` per stage on
  the plot region, as `PlotGround` does today; a join replays one write.
- **Water**: terrain Water (real reflections and waves, no part, no image asset). Terrain water has no flow direction, so the flow is shown by
  foam: at most three thin white strips per flooded segment that drift along the centre line and fade at the pond. Foam and wheel rotation
  are client-only (`PlotFx`): one `BulkMoveTo` at 20 Hz, only for the plot the player stands on or within 150 studs, at most 21 foam parts.
- **Wheels**: one axle per flooded segment across the river, bank to bank on two posts, four wheels threaded on it side by side; the wheels
  turn with the flow. A wheel is scaled to at most 2.6 studs wide so that four fit the 12-stud water.
- **Phone cost**: terrain edits are not instances; the river adds 7 axles, 14 posts, 10 bridge parts and about 12 stones at the spring and pond.
- **Fallback** if terrain water in a one-voxel channel looks blocky or the character swims awkwardly in Studio: one translucent part per
  segment, turned along the centre line (0018 option W2), same foam. The core and the data do not change.

## 5. Aligned rows and the x2

- **Layout**: a mown tile holds four panels. Loose: a 2 x 2 scatter, each panel shifted by up to 0.4 studs and turned by up to 12 degrees
  (hash of plot seed and place, as today). Aligned: one straight row of four on two rails, edge to edge. A panel is 1.9 x 3.2 studs (today
  8.2 x 5.2, almost twice a real module next to a character), built from two parts by code from a config table, like the tools; the 9-part
  model stays on the market wall.
- **Odd counts**: tile i (in mowing order) shows `clamp(owned - 4 x (i - 1), 0, 4)` panels, so only the last tile can be incomplete. The
  panel card shows "Row 2 of 4" and gets the buy step "fill row" (`qty = "row"`: up to the next multiple of four, for every plant).
- **Action** `Align { cell }`: rails owned and in the hand, the player stands on the tile, the tile is mown, holds four panels and is not
  aligned yet; hold 1.5 s; the server sends it like `Prepare` (no client message). Nothing aligns without this hold.
- **Data**: `land.aligned = { cell, ... }` (F1 cell numbers). Recommended: kept on grid expansion like the rest of the land: the rails stay
  on the tile and panels bought onto a railed tile sit straight (the work was done for that row once).
- **Formula**: `Erzeugung_1 = Basis x (Anzahl + A x (alignFactor - 1)) x M x Faktor`, with A = the panels on aligned tiles and
  `Land.align = { factor = 2, hold = 1.5 }`. Milestones count real units only. The storage capacity uses the same production.
- **Economy**: an aligned row adds 4 nominal units for one hold. With 20 panels the next four cost 245 + 282 + 325 + 373 = 1,225 coins; the
  rails cost 300 once. Together with U01 (150 coins, x2) a panel reaches x4, still below one water wheel per coin from the second minute on.
- **UI**: prompt "Align row" (object text "Mounting Rails") under the player; a short spark and a click sound when the row snaps; panel card
  line "Aligned 12 of 20: x2"; the tool tab text of section 2.

## 6. Wind turbine and crank marker

- **Wind turbine**: hub at 44 studs, rotor diameter 32, so about 60 studs to the blade tip (a character is 5). `Assets.plants[6]` gets a fixed
  `height` instead of fitting the cell; the size never depends on the count. Pad: 4 x 4 tiles (32 studs) of tamped gravel with an organic
  rim, a 12-stud concrete foundation, a cable in a narrow earth trench to the grid box. Four towers 48 studs apart along the back of the plot
  form its skyline and do not shade any field. The rotor turns slowly on the client (`PlotFx`, 6 rpm plus 10 rpm x the weather's wind
  factor). If the model has no separate rotor parts (open since 0018), the rotor is built by code: hub and three blades.
- **Crank**: no disc. Seven to nine small grey stones in a loose ring of 5 studs radius (code-built, positions from the plot seed) on the
  bare earth patch that is already there. New players still get the tutorial arrow.

## 7. Balance (measured with the Lune sim)

Method: `sim/Sim.luau` and `GameCore` patched locally with this design (gate `owned < cells x capacity`; cells and capacities of section 2;
chain hold times per cell; the bot prepares four panel tiles or one cell of another field whenever a field is full, 3 s walking plus the
holds, no cranking meanwhile; the bot buys the rails with the fourth panel and aligns every full row at once, 3 s walking plus 1 s per row).
27 runs per bot (9 seeds x 3 start times), minutes, median (min-max). The patch is not part of this PR.

| Figure | Range (tolerances.md) | Today (`main`) | Capacity gate and chains | Gate, chains and x2 rows (kept) |
| --- | --- | --- | --- | --- |
| Z1 first expansion, optimal | 15 to 22 | 19.7 (16.3-22.7) | 19.7 (16.3-22.7) | 19.5 (16.2-22.6) |
| Z2 first expansion, occasional | 39 to 50 | 46.6 (43.9-49.0) | 47.0 (44.0-51.5) | 48.4 (45.2-54.6) |
| Z3 stage 2 | 12 to 19 | 16.0 | 16.0 | 15.8 |
| Z3 stage 3 | 9 to 16 | 12.3 | 12.4 | 11.4 |
| Z3 stage 4 | 9 to 17 | 11.7 | 11.6 | 11.0 |
| Z3 stage 5 | 10 to 18 | 15.0 | 14.7 | 13.6 |
| Z3 stage 6 | 15 to 23 | 19.1 | 19.0 | 19.2 |
| Z5 play time to stage 6 | 82 to 98 | 92.1 | 92.6 | 89.0 |
| Z9 longest pause, first 10 min | 0 to 45 s | 2 | 1 | 1 |
| Z4 stage 7 | 0 to 60 | 39.4 | not measured | 39.6 |
| Z4 stage 8 | 0 to 150 | 107.6 | not measured | 107.7 |
| Child bot, first expansion | no range | 24.9 | 24.9 | 22.6 |

Largest park the optimal bot owns in any run, against capacities 100 / 112 / 112 / 112 / 100 / 100: up to stage 6 it is 89 / 90 / 82 / 72 /
73 / 63, so the gate never binds; up to stage 8 it is 100 / 112 / 112 / 97 / 100 / 87, so panels, wheels, houses and the solar farm are
full in stages 7 and 8, and the stage times still move by at most 0.2 minutes. The first panel comes within 15 s as today (measured in
5 s steps). Reading: the gate with these capacities costs nothing measurable; the x2 rows shorten the way to stage 6 by about 4 % and
stay inside every range. Z2 moves towards its upper edge (the occasional bot pays the aligning time but buys only every 20 s). Rows that
start loose again in every run (optimal bot only): stages 1 to 6 take 19.5 / 16.1 / 12.6 / 12.1 / 15.6 / 19.5 and stage 6 comes after
95.2 minutes, inside the ranges but slower than today, because the bot aligns again in every run. Not measured here: Z6, Z7, Z8, Z10;
the implementation steps regenerate
`docs/balance/report.md` and `make check` compares every row.

## 8. Tutorial

Steps of `Core/Tutorial` (PR #129 defines crank, panel, wheel, storage; this replaces its table), each with the fact it waits for:

1. Crank: arrow to the stone ring; one crank click.
2. Shop: arrow to the market; the popup was opened once.
3. Scythe: hotbar place 1 pulses, text "Take the scythe (1)"; the scythe is equipped.
4. Mow: arrow to the roped panel field; one tile mown.
5. Panel: the Balcony Panel card pulses; one panel owned.
6. Row: "Fill the row"; four panels owned.
7. Shovel: tool tab; shovel owned. 8. River: first segment flooded. 9. Water wheel owned.
10. Container bought. 11. Storage (U17) owned: end.

Later tools are not steps. When a tool becomes buyable for the first time, one hint line names it and what it prepares (rails after the
first full row, hammer, wrench, cable drum, tamper), and the field shows its rope and stakes. The tutorial needs three new facts from the
server: popup opened, equipped tool, land state.

## 9. Sparks, popup and place contents

**What sparks are (checked against Bauplan sections 2 and 3 and `GameCore`).** Sparks multiply nothing. A grid expansion gives two things:
the grid level, which multiplies all output (x1.6 at level 1 up to x110 at level 10), and sparks, a currency for permanent nodes. Today
the HUD only says "Grid expansion: +5 sparks", the multiplier is never shown, and the eight permanent nodes P1 to P8 exist in the core
(`BuyNode`) but no screen offers them: sparks cannot be spent at all.

- **Say it**: the HUD chip reads "Grid level 2: output x2.6" and "Sparks 8". The expansion button opens a confirm popup: "You get: output
  x1.6 -> x2.6, +8 sparks. You lose: plants, coins, run upgrades. You keep: land, tools, rails, spark upgrades."
- **Spark shop**: a fifth market tab "Sparks" ("Funken"). One card per item: name, price in sparks, one line that states the effect in
  numbers, owned or buy. It lists P1 to P8 (unchanged) and six new items (draft numbers):

| ID | Name | Effect | Sparks |
| --- | --- | --- | --- |
| S1 | Starter Kit | every run starts with 4 Balcony Panels and 2 Water Wheels (if their ground is prepared) | 4 |
| S2 | Tool Rebate | tools not yet owned cost half | 2 |
| S3 | Quick Hands | every hold takes half the time | 6 |
| S4 | Fine Tuning | aligned rows give x2.5 instead of x2 | 10 |
| S5 | Sign Paint | pick one of six colours for sign, rope and blade tips of the own plot | 3 |
| S6 | Golden Crank | a golden crank with a faint glow on its stone ring | 5 |

- **Balance**: levels 1 to 10 give 185 sparks and P1 to P8 cost 185; the new items cost 30 more, so a player chooses. The bots buy P1 to
  P8 in order and none of the new items, so the report does not move by construction (not measured: a bot that buys S1 or S4 first).
  Sparks are never sold for Robux and no pass gives them; S5 and S6 are small and do not replace the Plot Themes or Neon passes.
- **Hotbar over the tab row** (measured in a Studio screenshot): while a popup is open the client hides the tool bar
  (`SetCoreGuiEnabled(Backpack, false)`) and shows it again on close; the tool in the hand stays. The popup also keeps a bottom inset.
- **Tests in the place**: `default.project.json` maps `tests` to `ReplicatedStorage.Tests` and ships `TestRunner.server.luau`, so every
  client downloads the tests. The published project drops both; a second project file `test.project.json` adds them for Studio test runs.

## 10. Data and migration

- `land` gains `steps[field]` (stages done per entry of `cells[field]`) and `aligned` (list). `sites[field]` stays the number of prepared
  cells. `Land.unitsPerSite` of #149 is replaced by `Land.capacity = { 4, 16, 16, 16, 25, 25 }` (nil switches the gate off: the rollback),
  `Land.chains`, `Land.align`, and `Land.fields = { 25, 7, 7, 7, 4, 4 }`.
- Data version: the next free one (5 on today's `main`; PR #129 also wants a version, whichever merges second takes the next). The step,
  with literal numbers: per field `n = min(max(old sites, ceil(owned / capacity)), new cell count)`; cells 1..n in order, all stages done;
  for the river the first n segments. `reconcile` clamps cell numbers, stages and `aligned` to the config. Fixture test for a version 4
  profile. `aligned` needs no version step (step 4): a profile without the field that owns the rails gets every full row aligned, because
  its panels stood in rows before; every other profile starts with none.
- The game is not published, so only test profiles migrate.

## 11. Risks

| Risk | Effect | Mitigation |
| --- | --- | --- |
| Terrain water in a narrow channel looks blocky, or water leaks over the bank at 4-stud voxels | River looks wrong | Studio check in the river step before anything depends on it; fallback of section 4 |
| Parts rise from about 1,300 to 1,900 per full plot | Frame time on phones with eight full plots | Budgets in a test; streaming is on; measure in the phone emulator before the last step; lever: slimmer market (603 parts) |
| Wheel and wind models have no separable rotor | Whole wheel must turn, or no spin | Code-built rotor for the wind turbine; wheels turn as a whole model about the axle (4 x 19 parts per axle, only near the player) |
| Panels become smaller and code-built | Owner may prefer the current model | Owner decision 2; the layout works with any panel that fits 2 x 4 studs |
| Stages II to IV show a plate, not more models | Feels less direct than one model per unit | Visible places fill first; the alternative (one model per unit) does not fit a plot: 100 houses or wheels |
| Fields are full from stage 7 on (bots: panels, wheels, houses, solar farm) | Milestones 150 and 200 are out of reach; a human may hit the limit earlier | Stage times unchanged in the sim; the card says the field is full; owner decision 1 |
| Each logic step changes the sim | `make check` compares `docs/balance` | Every logic step adapts `sim/Sim.luau` and regenerates the report in the same PR |
| #129 and this design both add a data version and a tutorial table | Merge conflict | Tutorial steps here start after #129 is merged or closed; version = next free |
| River splits the plot | Long walks | Two bridges, shallow water, the yard and all early fields are on the road side |

## 12. Implementation steps

One small PR each, branched from `main`. Kind: logic = pure core plus Lune tests (and sim plus regenerated report when bot results change);
server = Roblox services; visual = look and motion (Fable). Steps with no dependency on each other can run in parallel: after step 1 the
steps 2, 3, 4, 5 and 12 are independent; steps 19 and 20 can start at once.

### Step 1: Site map and cell lists (logic)
Files: `src/shared/Config/Assets.luau`, `src/shared/Core/PlotLayout.luau`, `src/shared/Config/Land.luau`, `src/shared/Core/Data.luau`, `tests/Assets.test.luau`, `tests/PlotLayout.test.luau`, `sim/Sim.luau`, `docs/balance/report.md`
Acceptance: fields are cell lists as in section 3, furniture stands in the yard, the clearance test passes and fails on the old map, cell counts are 25, 7, 7, 7, 4, 4.
Depends on: PR #149

### Step 2: Tool chains in the core (logic)
Files: `src/shared/Config/Land.luau`, `src/shared/Core/GameCore.luau`, `src/shared/Core/Toolbelt.luau`, `src/shared/Core/Data.luau`, `src/shared/Migrations/Steps.luau`, `tests/GameCore.test.luau`, `tests/Toolbelt.test.luau`, `tests/Data.test.luau`, `sim/Sim.luau`, `docs/balance/report.md`
Acceptance: `Prepare { target, cell }` advances one stage only with the tool of that stage, the river only downstream, a cell counts when its chain is done; the migration of section 10 has a fixture test.
Depends on: 1

### Step 3: Capacity gate and the fill-row step (logic)
Files: `src/shared/Config/Land.luau`, `src/shared/Core/GameCore.luau`, `src/shared/Core/ShopView.luau`, `src/shared/Config/Locale.luau`, `tests/GameCore.test.luau`, `tests/ShopView.test.luau`, `tests/Locale.test.luau`, `sim/Sim.luau`, `docs/balance/report.md`
Acceptance: buying stops at prepared cells x capacity, `qty = "row"` buys up to the next multiple of four, the view gives capacity and visible units per cell, the card says "Prepare more ground"; the report stays in its ranges.
Depends on: 1

### Step 4: Aligned rows in the core (logic)
Files: `src/shared/Config/Land.luau`, `src/shared/Core/GameCore.luau`, `src/shared/Core/Data.luau`, `tests/GameCore.test.luau`, `tests/Data.test.luau`, `sim/Sim.luau`, `docs/balance/report.md`, `changelog.d/<issue>.md`
Acceptance: `Align { cell }` works only on a full mown row with the rails, aligned panels count twice in production and storage capacity, milestones do not change, the report stays in its ranges.
Depends on: 1

### Step 5: River course in the core (logic)
Files: `src/shared/Core/River.luau`, `tests/River.test.luau`, `src/shared/Config/Assets.luau`
Acceptance: curve, segments, axle poses, terrain mask and bridges as in section 4, with the tests named there.
Depends on: 1

### Step 6: Work the chain under the player (server)
Files: `src/server/Services/LandService.luau`, `src/server/Services/Action.luau`, `src/shared/Net.luau`, `tests/Net.test.luau`, `src/shared/Config/Locale.luau`
Acceptance: the prompt under the owner names the next stage of the cell he stands on and shows only with that tool in the hand; "Align row" works the same way; hold time, tool and cell are checked on the server.
Depends on: 2, 4

### Step 7: Units per cell on the plot (server)
Files: `src/server/Services/PlotService.luau`, `src/server/Services/PlantModels.luau`, `src/server/Services/PlantModels.test.luau`, `src/shared/Core/PlotLayout.luau`, `tests/PlotLayout.test.luau`
Acceptance: every prepared cell shows its visible units in fill order and a plate when it holds more; half-worked cells show their stage; nothing stands outside its cell.
Depends on: 2, 3

### Step 8: Panels loose and aligned (visual)
Files: `src/shared/Config/Assets.luau`, `src/server/Services/PlantModels.luau`, `src/server/Services/PlotService.luau`, `tests/Assets.test.luau`, `changelog.d/<issue>.md`
Acceptance: a mown tile shows up to four code-built panels as a loose scatter, an aligned tile shows a straight row on two rails; the parts sum stays in the budget.
Depends on: 4, 7

### Step 9: River with water, axles and bridges (visual)
Files: `src/server/Services/PlotGround.luau`, `src/server/Services/PlotService.luau`, `src/server/Services/PlantModels.luau`, `changelog.d/<issue>.md`
Acceptance: digging shows a trench, the second hold floods it from the spring; each flooded segment has one axle with up to four wheels across the flow; the bridges appear; leaving the server restores the meadow. The PR records the Studio check of terrain water or switches to the fallback.
Depends on: 5, 7

### Step 10: House, mast, farm fence and cables (visual)
Files: `src/server/Services/PlotGround.luau`, `src/server/Services/PlotService.luau`, `src/shared/Config/Assets.luau`, `changelog.d/<issue>.md`
Acceptance: the hammer builds a bare house and PV arrays appear on the roof per unit; the wrench sets a guyed mast with four rotor places; the farm cell shows fence after the hammer and ground cables after the drum.
Depends on: 7

### Step 11: Big wind turbine, tamped pad and crank stones (visual)
Files: `src/shared/Config/Assets.luau`, `src/server/Services/PlantModels.luau`, `src/server/Services/PlotGround.luau`, `src/server/Services/PlotService.luau`, `tests/Assets.test.luau`, `changelog.d/<issue>.md`
Acceptance: the turbine is about 60 studs to the blade tip at every count, stands on a gravel pad with foundation and cable, and the crank has a stone ring instead of the yellow disc.
Depends on: 7

### Step 12: Rotors, wheels and foam on the client (visual)
Files: `src/client/Controllers/PlotFx.luau`, `src/client/Main.client.luau`
Acceptance: tagged rotors and wheels within 150 studs turn with one `BulkMoveTo` per tick, the wind rotor follows the weather, foam drifts down flooded segments.
Depends on: 1 (tags are set in steps 9 and 11; without tags nothing moves)

### Step 13: Market texts and plant cards (visual)
Files: `src/client/Controllers/Market.luau`, `src/shared/Core/ShopView.luau`, `src/shared/Config/Locale.luau`, `tests/ShopView.test.luau`, `tests/Locale.test.luau`, `changelog.d/<issue>.md`
Acceptance: the tool tab shows the texts of section 2, a plant card shows "owned of capacity", the fill-row button and the aligned line.
Depends on: 3, 4

### Step 14: Tutorial steps (logic)
Files: `src/shared/Core/Tutorial.luau`, `tests/Tutorial.test.luau`
Acceptance: the eleven steps of section 8 advance on their facts and a finished tutorial stays finished.
Depends on: 2, PR #129

### Step 15: Tutorial arrows and hints (visual)
Files: `src/client/Controllers/Tutorial.luau`, `src/client/Main.client.luau`, `src/server/Services/Session.luau`, `src/shared/Config/Locale.luau`, `changelog.d/<issue>.md`
Acceptance: arrow or pulse for every step, the hotbar hint for the scythe, one hint per new tool.
Depends on: 6, 13, 14

### Step 16: Spark items in the core (logic)
Files: `src/shared/Config/Upgrades.luau`, `src/shared/Config/Effects.luau`, `src/shared/Core/GameCore.luau`, `src/shared/Core/ShopView.luau`, `src/shared/Config/Locale.luau`, `tests/GameCore.test.luau`, `tests/ShopView.test.luau`, `tests/Locale.test.luau`, `tests/Config.test.luau`
Acceptance: S1 to S4 work as in section 9 (S5 and S6 are owned flags plus a colour choice), the view gives the grid multiplier now and after the next expansion, and `ShopView` has the tab "sparks" with a card per permanent item; the balance report does not change.
Depends on: 4 (S4 only; without step 4 the PR leaves S4 out)

### Step 17: Spark tab, multiplier chip and expansion popup (visual)
Files: `src/client/Controllers/Market.luau`, `src/client/Controllers/Hud.luau`, `src/shared/Config/Locale.luau`, `tests/Locale.test.luau`, `tests/View.test.luau`, `changelog.d/<issue>.md`
Acceptance: the market has the tab "Sparks" with buyable cards, the HUD shows "Grid level n: output x..." and the spark count, and the expansion asks for confirmation with the get, lose and keep lines.
Depends on: 16

### Step 18: Spark effects on the plot (server)
Files: `src/server/Services/LandService.luau`, `src/server/Services/PlotService.luau`, `src/server/Services/Session.luau`, `src/shared/Net.luau`, `tests/Net.test.luau`
Acceptance: Quick Hands halves the hold the server expects and the prompt shows, Sign Paint recolours sign, rope and blade tips of the own plot, the Golden Crank replaces the crank look.
Depends on: 6, 11, 16

### Step 19: Popups clear of the tool bar (visual)
Files: `src/client/Controllers/Market.luau`, `src/client/Main.client.luau`, `changelog.d/<issue>.md`
Acceptance: while the market or the control board popup is open the tool bar is hidden and no popup control lies under it; closing shows it again with the same tool in the hand.
Depends on: none

### Step 20: Tests out of the published place (logic)
Files: `default.project.json`, `test.project.json`, `src/server/TestRunner.server.luau` (moved to `src/dev/`), `tests/test_studio_project.py`, `scripts/ci/luau-check.sh`, `README.md`
Acceptance: the place built from `default.project.json` has no `ReplicatedStorage.Tests` and no TestRunner; `test.project.json` builds with both and the Studio test run still passes; CI builds both. The change to `scripts/ci` goes through the security reviewer.
Depends on: none

### Step 21: Bauplan and the Studio checklist (logic)
Files: `Bauplan.md`, `docs/land-development-design.md`
Acceptance: the Bauplan names the chains, capacities, the x2 rows, the spark items and the data version; the PR records a two-player Studio run and the phone emulator numbers (parts, frame time) with eight full plots.
Depends on: 8, 9, 10, 11, 12, 13, 15, 17, 18

## 13. Owner decisions

1. Capacity: every field holds 100 to 112 units, several per cell (recommended; balance unchanged, measured). Milestones 150 and 200 become
   unreachable. Alternative: 200 per field by doubling the capacity per cell (no new ground, more units hidden behind a plate).
2. Panels: small code-built panels, four per mown tile (recommended), or keep the current large model with one panel per tile, which needs
   100 tiles and about 900 parts for the same capacity.
3. Aligned rows are kept on grid expansion like the land (recommended; stage 6 after 89.0 minutes). Alternative: every run starts loose again (95.2 minutes, the aligning repeats each run).
4. Water: terrain water with foam (recommended). The character swims in it; if that is unwanted, the part fallback is used.
5. Wind turbine about 60 studs tall, four of them at the back of the plot (recommended), or one single landmark turbine that carries all 100 units.
6. The tutorial replaces the step table of PR #129 (recommended: merge #129 first, then step 14), or #129 is closed and step 14 writes it new.
7. Spark shop: the six new items of section 9 with their draft prices (recommended), and the 185 sparks of levels 1 to 10 stay, so a player
   cannot own everything. Alternative: raise the sparks per level so that everything is affordable by level 10.
8. While a popup is open the tool bar is hidden (recommended), or the popup is moved up and the bar stays visible.
