# 0018 Land development: prepare the ground, buy tools, large plots, market and control board popups

Revised after the play test of 2026-11-16: see [land-development-design-v2.md](land-development-design-v2.md). Where the two differ, v2 wins.

Issue: none yet (owner request of 2026-11-16, no implementation in this PR). Related: #102 (market popup), #97 (rule thresholds), #71 (tutorial),
#73 (cosmetics), PR #101 (data model v2). Numbered 0018 because 0001 to 0017 are the template's studies and `tools/design_split.py` neither
checks nor splits a design numbered below 0016.

## 1. Goal

Daniel's vision, taken as requirements:

- R1 Market: the E prompt opens a popup with tabs Technik (plants), Upgrades, Speicher (storage) and Werkzeuge (tools). Once the Control
  Center (U21) is bought and wired, a control board stands on the plot and its E prompt opens the rule popup.
- R2 Placement: units have a fixed size that never changes with the count. Balcony panels lie flat on the earth: first a few "wild" ones
  (slightly turned and shifted), later neat rows of four without gaps, row behind row. The base area is much larger than today.
- R3 Every technology needs a preparation step with one tool or action: mow (scythe), dig a stream (shovel), build a house (hammer), and so on
  (table in section 4). Water wheels stand upright in the dug stream, in flowing water, and rotate.
- R4 Tools are bought in the market (scythe free), each with a one-line text saying what it unlocks. The storage needs a container first.
- R5 A guide leads through it, starting at the crank.
- R6 Multiplayer: every player has a large plot; the world, the saved ground state, replication and phone limits are thought through.

Not goals: a minigame, land as a Robux product, a cap on how many plants a player may own.

## 2. Current state (file references)

- Plot: `src/server/Services/PlotService.luau` builds 8 plots (`MAX_PLOTS`, line 16) in one row at `x = slot * Assets.PLOT_SPACING` (line 181):
  a 120 x 1 x 120 `Ground` part on the terrain, one pad per plant, and `updateCopies` (line 73) shows at most 4 copies per pad.
- Size changes with the count today: `PlotLayout.copies` (`src/shared/Core/PlotLayout.luau:27`) shrinks the cell as the grid grows (`COPY_GAP` 4,
  `MAX_CELL` 14 in `src/shared/Config/Assets.luau:17`), and `PlantModels.place` (`src/server/Services/PlantModels.luau:232`) scales to the cell.
- Market prompt: `PlotService.luau:220` creates `ShopPrompt` without a server handler; `src/client/Main.client.luau:21` calls `hud.openShop()`
  (`src/client/Controllers/Hud.luau:479`), which only scrolls the always-open list. Daniel's Studio test: nothing visible happens (#102, open).
- Control Center: `updateFurniture` (`PlotService.luau:142`) places the `control` model when rule slots exist; it has no prompt.
- World: `src/shared/Core/Landscape.luau:10` takes `(plotSize, plotSpacing, slots)`, assumes one row at z = 0 and derives `PLOTS`, `MEADOW`
  (lines 14 to 16), the road and the world box from it. `src/server/Services/WorldService.luau:160` fills the meadow with terrain grass (top at y = 0)
  and writes voxels of 4 studs (`Landscape.CELL`). Terrain colours are global per material (`GROUND_COLORS`, line 34).
- Rules: `GameCore.apply` (`src/shared/Core/GameCore.luau:410`) knows BuyPlant, BuyNode, Crank, SetRule, SetStorageMode, Prestige. `buyPlant` (line 279)
  checks only reveal and coins. `prestige` (line 378) resets plants, coins and run nodes.
- Data: `src/shared/Core/Data.luau` is version 1 on `main`; PR #101 (open) makes it version 2 with `Steps[1]` in `src/shared/Migrations/Steps.luau`.
  `STATE_FIELDS` (line 12) lists what moves between profile and state. `tutorial = 0` exists and is unused.
- Messages: `src/shared/Net.luau:11` and `src/server/Services/Action.luau` (limit per message, flood strikes). The crank prompt already goes through
  `Action.receive` (`Action.luau:65`), so a server-side prompt can share the limits.
- Balance: `sim/Sim.luau` (bots), `scripts/balance.luau` (report), `tests/Balance.test.luau`, ranges in `docs/balance/tolerances.md`, checked by
  `tests/test_balance_report.py`.
- Parts per model (counted in `assets/models/*.rbxmx`): panel 9, water wheel 19, house 49, mini turbine 4, solar farm 75, wind turbine 20, market 603,
  control 202, crank 17, battery 10. Today a full plot has at most 4 copies each: 704 plant parts plus 862 furniture parts.
- Open: `default.project.json` sets no streaming property and no `Terrain.Decoration`; what the built place uses is not measured.
- Tutorial: issue #71 is open and not started (pure step machine, ends at the storage, depends on #70).

## 3. Options with trade-offs

**Ground state: terrain or parts.**
- A Parts only: one thin part per prepared tile on the grass slab. Crisp, but a stream needs a hole (the slab is 1 stud thick) and every tile costs a part.
- B Terrain only: `Terrain:FillBlock` swaps Grass for Ground, Air or Water. No parts; grass blades vanish on mown tiles if `Decoration` is on. But
  terrain water has no direction, makes characters swim, and a voxel is 4 studs, so edges are soft and a crisp foundation is impossible.
- C Hybrid (chosen): terrain for mown earth and for the trench, parts for what must be crisp or must move (water surface, foundation, fence, cable).

**Flowing water in the stream (phone cost).**
- W1 Terrain water: free and pretty, but no flow direction, swimming state, blobby 4-stud banks.
- W2 One flat translucent part per stream, resized to the dug length, plus 3 thin foam strips that drift along it. The strips are local parts
  moved by one client loop. No image asset. At most 2 + 6 parts per plot.
- W3 Beam with `TextureSpeed` (scrolls on the GPU, no script) or a `Texture` with tweened offset. Best look for the cost, but needs an image
  asset; the project has none and `upload_image` is forbidden for agents.
- Chosen: W2 now. W3 is a later polish step once Daniel supplies a water image (not part of this design).

**Rotation (wheels, turbine blades).** Server-side motion would replicate every frame: rejected. Constraints or motors need unanchored parts and
the sanitiser removes them (`PlantModels.luau:13`). Chosen: a client loop that turns tagged rotor parts with one `workspace:BulkMoveTo` call at
20 Hz, only for models within 150 studs of the camera. Open: whether each model has separable rotor parts; otherwise the whole wheel turns
about its axle and a turbine does not spin.

**How the land limits the player.**
- L1 Hard capacity (one prepared site per owned unit): breaks buy-max, auto-build, the milestones up to 200 units and the balance figures.
- L2 Gate plus display (chosen): one prepared site unlocks buying that plant without limit; the plot shows `min(owned, prepared sites)` units.
  More sites show more of the park. No change to production formulas.
- L3 Capacity tied to milestones: adds forced pauses in the middle of a run; rejected.

**Which site is worked.** Free choice needs a bit mask per field and a prompt per site. Chosen: sites fill in a fixed order (row of four, then the
row behind), so the state is one number per field and one prompt per field. A later change to free choice is `count n -> mask 2^n - 1`.

**How the action is triggered.** Roblox `Tool` objects need the backpack bar (bad on phones). A custom hold button needs new UI and a client
message. Chosen: `ProximityPrompt` with `HoldDuration` on the next site: tap-and-hold with a progress ring on touch, E on keyboard, a pad button
on a controller, and `Triggered` arrives on the server. The tool is shown in the hand while holding (cosmetic, client side).
Owner decision after play-testing (2026-11-16): the tools are real `Tool` objects in the hotbar after all (`ToolService`, models from
`Config/Tools`). The hold prompt stays, but it shows and counts only while the matching tool is in the hand (`Core/Toolbelt`, checked
on the server). Units stand only on prepared sites and buying never clears grass; `Land.required` is on.

**Tools: free or bought.** All free keeps the first minute fast but leaves "buyable" (R4) unmet. All bought delays the first panel. Chosen: scythe
free, every other tool costs about a fifth of the base cost of the plant it serves (table below).

**World for large plots (8 players per server stay, Bauplan section 5).**
- P1 One row of 8 as today with 192-stud plots: 1,920 studs of plots, two minutes on foot end to end.
- P2 Two rows of four on both sides of the road (chosen): 960 studs, every plot faces the road, the spawn is at the road end.
- P3 Six players per server: smaller world, but fewer players share a Sunshine Hour; rejected.

**Who builds what other players see.** Server-built models replicate to all (today). Client-built visuals from `PlotPublic` counts would allow a
lower detail for foreign plots but move the models and the sanitiser to the client. Chosen: server-built plus streaming; client-built is the
fallback if the phone measurement in section 6 fails.

## 4. Chosen approach

**Grid.** A tile is 8 studs (2 x 2 terrain voxels). A plot is 24 x 24 tiles = 192 studs (`Assets.PLOT_SIZE`), 48 studs between plots
(`PLOT_SPACING` 240), all on multiples of 8. Plots stand at x = 240 * column (1 to 4) and z = +128 or -128; the road runs along z = 0. A plot has a
`facing` of +1 or -1 so its market looks at the road; layout coordinates are mirrored in z and models are turned by 180 degrees for -1. Slots
fill from the spawn outwards, alternating the two rows. `Landscape.new` gets the row count; the meadow becomes x -48..1104, z -240..240.
Estimate from the formulas in `Landscape.luau:25`: the world box is about 1,664 x 1,280 studs against 1,920 x 896 today (+24 % terrain).

**Fields** (tile columns x rows on the plot; row 0 is the back, row 23 the road side; a site is the footprint of one unit):

| Field | Plant | Site | Sites | Tiles (columns, rows) | Parts when full |
| --- | --- | --- | --- | --- | --- |
| F1 | Balcony Panel | 1 x 1 | 24 (4 x 6) | 1-4, 12-17 | 216 |
| F2 | Water Wheel | 1 stream tile | 12 (2 streams of 6) | 7-12, rows 13 and 16 | 228 |
| F3 | Rooftop Solar | 2 x 2 | 8 (4 x 2) | 1-8, 6-9 | 392 |
| F4 | Mini Turbine | 1 x 1 | 12 (4 x 3) | 15-18, 13-15 | 48 |
| F5 | Solar Farm | 2 x 2 | 4 (4 x 1) | 11-18, 7-8 | 300 |
| F6 | Wind Turbine | 2 x 2 | 4 (4 x 1) | 8-15, 2-3 | 80 |

Furniture stands in rows 19 to 23: market, crank, storage container, control board. Sum of plant parts on a full plot: 1,264 (budget
`Assets.MAX_PLANT_PARTS = 1300`, checked by a Lune test from a parts-per-model table). With the furniture a plot has at most about 2,150 parts,
8 full plots about 17,000 (today about 12,500). The market alone is 603 parts; slimming it is the cheapest saving and a separate issue.

**Preparation, one tool or action per technology.** A timed hold on the next site, no minigame. Everything here is kept on grid expansion.

| Technology | Tool (price) | Hold | What the player does and sees |
| --- | --- | --- | --- |
| Market | hand (free) | 1 s, once | Opens the shutter of the stall; the first hold the tutorial teaches. After that the prompt opens the popup |
| Balcony Panel | Scythe (free, owned at the start) | 1 s per tile | Mows grass to bare earth. Panels lie flat on it |
| Balcony Panel, tidy | Mounting Rails (300) | none | Panels move from the wild layout into rows of four without gaps |
| Water Wheel | Shovel (30) | 1.5 s per tile | Digs the stream tile by tile; water flows in. A wheel stands upright in each tile and turns |
| Rooftop Solar | Hammer (250) | 2.5 s per lot | Builds a house (frame, then walls and roof). Bought PV goes on the roof |
| Mini Turbine | Wrench (2,500) | 1.5 s per site | Screws a mast anchor into the ground |
| Solar Farm | Cable Drum (25,000) | 3 s per site | Fences the site and lays the cable to the grid connection |
| Wind Turbine | Tamper (250,000) | 4 s per site | Compacts the ground; a concrete foundation appears |
| Storage | Container (500, Speicher tab) | none | A container is delivered; U17 to U20 put up to 4 battery units inside. U17 needs it |
| Control Center | Cable Pliers (600) | 2 s, once | After U21: wires the control board to the container. Rules run and the board opens only when wired |

A tool appears in the Werkzeuge tab when its plant is revealed (the previous plant owned once, as today). Prices are run-1 costs only (tools are
kept); together 278,350 coins plus the container, against 10 million revenue for the first expansion.

**Wild and tidy panels (R2).** Without Mounting Rails the panels use the wild layout: three per mown row on every second row (rows 1, 3, 5), at
most 9, each shifted by up to 0.4 studs and turned by up to 12 degrees. The jitter comes from an integer hash of (seed, site index) in the pure
core (`PlotLayout.wild`), the seed is the plot slot; it is computed once when a copy is placed, nothing runs per frame. With the rails the same
panels sit edge to edge (pitch = footprint = 8 studs), four per row, one per mown tile, up to 24. The size is the same in both layouts.

**Pure core** (`src/shared/Core`, no Roblox APIs, Lune tests):
- `Config/Land.luau`: the two tables above as data (targets, tool, price, hold seconds, sites), `required = false` until the last step.
- `GameCore`: state field `land = { sites = {0,0,0,0,0,0}, tools = { scythe = true }, container = false, wired = false, market = false }`.
  New actions `BuyTool { tool }` (revealed, not owned, coins) and `Prepare { target }` (tool owned, sites below the field's count; the container
  costs coins). With `required`: `buyPlant` needs `sites[plant] >= 1`, U17 needs the container, rule slots need `wired`. `prestige` keeps `land`.
  `view` adds the land state, per plant `needsSite`, and the tool rows (price, owned, buyable, text key).
- `Core/Work.luau`: the hold check without a clock of its own: `begin(session, target, now)`, `finish(session, target, now, hold)` is true only for
  the same target, at least 0.9 x hold after `begin`, and one hold at a time.
- `PlotLayout`: `slot(n)` (x, z, facing), `sites(field, count)`, `wild(field, count, seed)`, field rectangles from `Assets.fields`.

**Server.**
- `PlotService` drops the grass slab (plot ground is the terrain at y = 0, `Assets.GROUND_Y`), keeps four thin border parts (level colour, Bauplan
  section 3) and shows `min(owned, sites)` fixed-size units. A prepared site without a unit shows its prepared state (earth, anchor, house, fence).
- New `PlotGround.luau`: renders `land` on the plot's slot. Mown tile: `FillBlock` 8 x 4 x 8 of `Ground`. Stream tile: `FillBlock` of `Air`, 4 deep, and
  the water part grows by one tile. Parts for house frame, anchor, fence, cable, foundation. Full rows are written as one block, so a join
  replays at most about 20 calls. `PlotService.remove` resets the plot region to grass with one call. Terrain edits replicate by themselves.
- New `LandService.luau`: one `ProximityPrompt` per field on an invisible anchor at the next site, plus container, wiring and market: at most 9 per
  plot. `PromptButtonHoldBegan` and `Triggered` feed `Work`; then owner check, distance check (root part within 18 studs of the site) and
  `Session.apply` through `Action.receive` with a `Prepare` entry in `Net` that creates no RemoteEvent (limit 2 per second). There is no client
  message for preparing, so a client can only skip the animation, never the server time. `BuyTool` is a normal client message (4 per second).
- State lives in the player's profile, never in the plot slot: whoever gets slot 3 sees their own land there.

**Client.**
- Market popup with four tabs (Technik, Upgrades, Speicher, Werkzeuge) on top of #102: a plant row without a site shows "Prepare the ground first" and
  the tool instead of Buy; a tool row shows name, price and one line of text; the Speicher tab starts with the container row.
- Control board popup: prompt on the `control` model (text "Steuerboard"), opens the rule slots and thresholds of #97 as a modal.
- Both modals: centred, at most 360 px wide content, tab buttons at least 44 px high, fixed text size, close button, close when the player walks
  16 studs away. No hover.
- `PlotFx`: turns tagged rotors, drifts the foam strips, shows the tool in the hand while a hold runs (character attribute set by the server),
  and disables prompts on foreign plots (plot attribute `Owner`).

**What others see, and cost.** Everything is server-built and replicates: other players see mown fields, streams and houses. Streaming is set in
`default.project.json` (`StreamingEnabled`, target radius 640, min radius 192, opportunistic stream-out; each plot model `Atomic`), so a phone
holds its own plot and the neighbours. Ground changes are terrain, not instances. Terrain colours are global, so a Plot Themes pass (#73) can
recolour border, fence and sign, not the earth. No pass or product sells land, tools or hold time.

**Tutorial (R5).** #71 stays the owner of the step machine; its step table gets the land steps: crank (arrow) -> open the market (first hold) ->
mow four tiles -> buy a panel -> buy the shovel -> dig -> buy a water wheel -> ... -> buy the container -> buy the storage (end, as in the Bauplan).
Later tools are not tutorial steps: a revealed field shows corner pegs and a sign with the tool icon.

**Where things are sold.** The core knows offers and actions (`BuyPlant`, `BuyNode`, `BuyTool`, `Prepare`), not places. `view` gives every offer a
`place` field (now always `market`) and the popup draws whatever list it gets per tab, so an offer can later move to another seller without a
change to the rules or the saved data.

**Later ideas (not designed, not in the split).** Large items such as the storage container could be bought in a central shop in the world that
the player drives to by car.

**Economy.** First panel: 15 cranks, one market hold, four mown tiles, about 15 s instead of 5 s. First water wheel needs 30 + 120 coins and 6 s of
digging per four tiles. The sim models a `Prepare` as hold seconds plus 3 s of walking during which the bot neither cranks nor buys, and buys
tools like any offer. Estimate (not measured): under one minute and under 3 % of revenue in run 1, nothing in later runs.

## 5. Migration and compatibility

- Data version 3 (after PR #101 is merged; version 2 on `main` is a precondition of step 2). `Steps[2]`, with literal numbers so the step never
  changes later: a profile with `lifetimeEarned > 0` gets the first row of every field (`sites = {4,4,4,4,4,4}`), all tools except the rails,
  `market = true`, `container = true`, `wired = (nodes.U21 == true)`. A fresh profile gets the template. `land` joins `STATE_FIELDS`; `reconcile`
  clamps every count to its field and drops unknown tools. A version 2 profile is added to `tests/Data.test.luau` as a fixture.
- The game is not published (Bauplan M5), so only test profiles migrate.
- All steps merge dark: `Config/Land.required = false` keeps today's rules. The last step turns it on.
- Bauplan sections 1 (first minute), 3 and 5 (plot size, data model, messages) are updated in the last step. Daniel's sentence "first panel after
  about 5 s" becomes about 15 s.
- #102 keeps its three tabs; this design adds the fourth and the row states. #71 should start after step 1 so its step table can name land steps.

## 6. Test and verification plan

Lune tests, each fails on today's code (the module, field or action does not exist, or the assertion is false today):
- `tests/GameCore.test.luau`: with `required`, BuyPlant 1 is rejected before a site and accepted after `Prepare`; `Prepare` without the tool is
  rejected; BuyTool checks coins and reveal; U17 needs the container; rule slots need `wired`; `prestige` keeps `land`; random actions never make
  coins negative or a count exceed its field.
- `tests/Work.test.luau`: finish before 0.9 x hold, for another target, or without begin is rejected.
- `tests/Assets.test.luau`: fields and furniture do not overlap and lie inside the plot; adjacent tidy sites are exactly one footprint apart (fails
  today: `COPY_GAP` 4); the site size is the same for 1 and for 24 units (fails today: the cell shrinks); wild panels never overlap for slots 1 to 8
  and are identical on a second call; the parts sum is within `MAX_PLANT_PARTS`.
- `tests/Landscape.test.luau`: eight slots in two rows lie on the flat meadow, none on the road, height 0 under every plot.
- `tests/Data.test.luau`: version 2 fixture migrates to the land above; a broken `land` is repaired.
- `tests/Balance.test.luau`: the optimal bot owns a panel within 30 s and a water wheel within 120 s, and never owns a plant without a site.
  `scripts/balance.luau` adds the row "first panel / first water wheel" to the report; `tests/test_balance_report.py` checks all rows again.
- `tests/Locale.test.luau`: every new key exists in English and German.

Studio (Daniel or a local MCP run, read and play tools only), before `required` is turned on: two players, each prepares and buys on the own plot,
neither can trigger the other's prompts; rejoin restores the ground; a hold released early changes nothing. Phone emulator: frame time and part
count with eight full plots. Open until measured: streaming defaults, `Terrain.Decoration` cost, rotor parts of the models.

## 7. Rollback

Set `Config/Land.required = false` (one line): buying works without sites, tools and container; the visuals stay. Single steps are reverted as PRs
in reverse order. The data step is not reverted once a version 3 profile exists (a version 2 server cannot load it); the `land` field is then
simply unused. World and plot size are constants in `Config/Assets.luau`.

## 8. Split into PR-sized implementation issues

*Superseded by section 11 where it differs from v2 (v2 wins). Section 11 maps each step here to its replacement; section 10 names every difference.*

### Step 1: Land rules in the pure core
Files: `src/shared/Config/Land.luau`, `src/shared/Core/GameCore.luau`, `tests/GameCore.test.luau`, `tests/Config.test.luau`
Acceptance: BuyTool and Prepare work as in section 4, the gates apply only with `required`, prestige keeps `land`, and without `config.land` nothing changes.

### Step 2: Data version 3 with the land field
Files: `src/shared/Core/Data.luau`, `src/shared/Migrations/Steps.luau`, `tests/Data.test.luau`
Acceptance: after PR #101 is on main, a version 2 profile migrates as in section 5 and `land` survives toState and fromState.

### Step 3: Fields, fixed-size sites and wild panels in the layout core
Files: `src/shared/Core/PlotLayout.luau`, `src/shared/Config/Assets.luau`, `tests/Assets.test.luau`
Acceptance: `slot`, `sites`, `wild` and `Assets.fields` exist next to the old pad constants and pass the layout tests of section 6.

### Step 4: Hold timing check in the pure core
Files: `src/shared/Core/Work.luau`, `tests/Work.test.luau`
Acceptance: `Work.finish` accepts only a hold of at least 0.9 times its duration on the target it began on.

### Step 5: English and German texts for land, tools and popups
Files: `src/shared/Config/Locale.luau`, `tests/Locale.test.luau`
Acceptance: every prompt, tool name, tool one-liner, tab and hint of section 4 has an English and a German text of at most 60 characters.

### Step 6: World for two rows of four large plots
Files: `src/shared/Core/Landscape.luau`, `tests/Landscape.test.luau`, `src/server/Services/WorldService.luau`, `src/server/Services/PlotService.luau`, `src/shared/Config/Assets.luau`, `default.project.json`
Acceptance: plots are 192 studs, stand in two rows beside the road on flat meadow at `PlotLayout.slot`, and the streaming properties are set.
Depends on: 3

### Step 7: Fixed-size units on sites
Files: `src/server/Services/PlotService.luau`, `src/server/Services/PlantModels.luau`, `src/server/Services/PlantModels.test.luau`, `src/server/Services/Session.luau`
Acceptance: a plot faces the road, has no grass slab, and shows min(owned, sites) units of constant size, panels wild or in rows of four.
Depends on: 1, 6

### Step 8: Ground, stream and prepared sites on the plot
Files: `src/server/Services/PlotGround.luau`, `src/server/Services/PlotGround.test.luau`, `src/server/Services/PlotService.luau`
Acceptance: mown earth, the stream with its water part, house, anchor, fence, foundation, container and cable follow `land` and vanish when the player leaves.
Depends on: 7

### Step 9: Prompts and the server path for preparing
Files: `src/server/Services/LandService.luau`, `src/server/Services/Action.luau`, `src/shared/Net.luau`, `tests/Net.test.luau`, `src/server/Main.server.luau`
Acceptance: only the owner, standing at the site and holding the full time, prepares the next site; BuyTool is a limited client message.
Depends on: 1, 3, 4, 7

### Step 10: Rotors, water foam and the tool in the hand on the client
Files: `src/client/Controllers/PlotFx.luau`, `src/client/Main.client.luau`
Acceptance: tagged wheels and blades within 150 studs turn with one BulkMoveTo per tick, foam drifts, and foreign prompts are disabled.
Depends on: 3

### Step 11: Market popup with the tools tab and site states
Files: `src/client/Controllers/Hud.luau`, `tests/View.test.luau`
Acceptance: on top of #102 the popup has the Werkzeuge tab, a plant without a site names its tool instead of Buy, and Speicher starts with the container.
Depends on: 1, 5

### Step 12: Control board popup
Files: `src/client/Controllers/RulesPopup.luau`, `src/client/Main.client.luau`
Acceptance: the prompt on the wired control board opens a modal with the rule slots and closes by button or by walking away.
Depends on: 5, 10

### Step 13: Bots prepare the land in the balance sim
Files: `sim/Sim.luau`, `scripts/balance.luau`, `tests/Balance.test.luau`, `docs/balance/report.md`, `docs/balance/tolerances.md`
Acceptance: bots buy tools and spend hold plus walking time, the report has the first-panel row, and every figure is inside its range or the PR says which is not.
Depends on: 1

### Step 14: Land steps in the tutorial
Files: `src/shared/Core/Tutorial.luau`, `tests/Tutorial.test.luau`, `src/client/Controllers/Tutorial.luau`
Acceptance: after #71 is merged, its step table leads from the crank over market, mowing, shovel and container to the storage.
Depends on: 1, 9

### Step 15: Turn the land rules on
Files: `src/shared/Config/Land.luau`, `Bauplan.md`, `docs/balance/report.md`, `changelog.d/<issue>.md`
Acceptance: `required` is true, the Studio checklist of section 6 is recorded in the PR, and the Bauplan names the new first minute and data version.
Depends on: 2, 8, 9, 10, 11, 12, 13, 14

## 9. Owner decisions

1. Does land only gate and display (recommended), or cap how many plants a player may own? A cap would need new balance figures.
2. Land, tools and container are kept on grid expansion (recommended), so the work happens once per player. Resetting them repeats it every run.
3. Tool prices: scythe free, the rest about a fifth of the plant's base cost (recommended, table in section 4), or all tools free.
4. The first panel comes after about 15 s instead of 5 s (market hold plus four mown tiles). Recommended: accept; otherwise drop the market hold.
5. World: two rows of four plots of 192 studs, 8 players per server (recommended), or fewer players with a smaller world.
6. Flowing water without an image asset now (recommended); a scrolling water texture later needs an image uploaded by Daniel.

Owner decisions from the v2 revision (v2 section 13, proposed default first; v2 wins, see section 10):

7. Capacity: every field holds 100 to 112 units, several per cell (recommended, measured in v2 section 7). This is a cap on owned plants
   (the gate of v2 section 2), which 0018 section 1 excluded; the owner confirms that it is a cap. Alternative: 200 per field by doubling the
   capacity per cell. With the default, milestones 150 and 200 are unreachable.
8. Panels: small code-built panels, four per mown tile (recommended). Alternative: the current large model, one panel per tile, about 900 parts
   for the same capacity.
9. Aligned rows stay on grid expansion like the land (recommended). Alternative: every run starts loose again (95.2 minutes for stage 6).
10. Water: terrain water with foam (recommended). If the character swimming in it is unwanted, the part fallback of v2 section 4 is used.
11. Wind turbine about 60 studs tall, four at the back of the plot (recommended). Alternative: one landmark turbine that carries all units.
12. Tutorial replaces the step table of PR #129: merge #129 first (recommended). Alternative: close #129 and write step 19 new.
13. Spark shop with the six new items and their draft prices (recommended); the 185 sparks of levels 1 to 10 stay, so not everything is
    affordable. Alternative: more sparks per level.
14. While a popup is open the tool bar is hidden (recommended). Alternative: the popup moves up and the bar stays visible.
15. Market hold and first panel: drop the one-second market hold, so the first panel comes within 15 s as measured in v2 section 7 (recommended,
    see C8 and C14 in section 10). Alternative: keep the hold; the first panel then takes longer.
16. Rollback switch: `Land.capacity = nil` switches the gate off, and no separate `required` flag is added (recommended, see C12).

## 10. Contradictions between 0018 and v2

v2 wins where both speak. Each difference is named here; none is resolved silently. "Handling" says what section 11 does.

| # | Topic | 0018 says | v2 says | Handling |
| --- | --- | --- | --- | --- |
| C1 | Water | Terrain water rejected (W1: no flow direction, swimming, blobby banks); flat part W2 chosen | Terrain water with foam; part is the fallback (v2 section 4) | v2; the part fallback stays a switch in step 12 |
| C2 | Gate and cap | Gate L2: one prepared site unlocks a plant without limit; not a cap (section 1 non-goal) | Gate `owned < cells x capacity` (v2 section 2) | v2 gate in step 4; it is a cap, owner decision 7 |
| C3 | Cells and sites | 24 / 12 / 8 / 12 / 4 / 4 sites, one unit per site | 25 / 7 / 7 / 7 / 4 / 4 cells, several units per cell (v2 sections 2 and 3) | v2 in step 1 |
| C4 | Alignment | Mounting Rails align panels by themselves, hold "none" | `Align { cell }` is a player action with a 1.5 s hold on a full row (v2 section 5) | v2 in step 5 and 10; the "none" hold is dropped |
| C5 | Panel model | Fixed size, the 9-part panel model | Code-built panel 1.9 x 3.2 studs from two parts; the 9-part model stays on the market wall (v2 section 5) | v2 in step 11; owner decision 8 |
| C6 | Water wheels | One upright wheel per stream tile; 12 sites in rows 13 and 16 | One axle per flooded segment with four wheels; seven segments (v2 section 4) | v2 in steps 6 and 12 |
| C7 | Wind turbine | 2 x 2 sites, four of them, tamper 4 s per site | 4 x 4 tiles per cell, about 60 studs tall, 32-stud pad (v2 section 6) | v2 in step 14 |
| C8 | Market hold | Market: hand, 1 s, once; the first hold the tutorial teaches | Tutorial step 2 only opens the popup; no hold in the v2 chains (v2 section 8); silent on the hold | Open. Default: drop the hold (owner decision 15); step 19 follows v2 |
| C9 | When a tool appears | When its plant is revealed (the previous plant owned once) | With the first plant that needs it: hammer with plant 3, drum with plant 5 (v2 section 2) | v2 in step 3 |
| C10 | Tools in the hand | Roblox `Tool` objects rejected (backpack bar bad on phones); custom hold prompt | Real `Tool` objects in the hotbar, prompt counts only with the tool in the hand, bar hidden while a popup is open (0018 section 3 owner decision; v2 section 9) | Both kept: the prompt uses `Core/Toolbelt` (step 3), the hotbar rule is step 24 |
| C11 | Data version | Version 3 after PR #101; `Steps[2]` with literal grants (`sites = {4,4,4,4,4,4}`, all tools, market, container, wired) | Next free version (5 on `main`); per field `n = min(max(old sites, ceil(owned / capacity)), cells)`; PR #129 may take one too (v2 section 10) | v2 in step 3; the number is open until the merge order of #129 and #101 is known |
| C12 | Rollback switch | `Config/Land.required = false` (0018 section 7) | `Land.capacity = nil` switches the gate off (v2 section 10) | Open. Default: the v2 switch only (owner decision 16); step 26 uses it |
| C13 | Land state | `land.sites` is the count per field | Adds `cells`, `steps`, `aligned`; `sites` stays the number of prepared cells (v2 section 10) | v2 in steps 3 and 5 |
| C14 | First panel | "About 15 s instead of 5 s" (0018 section 4 and owner decision 4) | "Within 15 s as today, measured in 5 s steps" (v2 section 7) | Open. Default: the v2 measurement (owner decision 15); the balance report of step 27 decides |
| C15 | Where the market popup lives | Popup opened through `Hud.luau` (`openShop`, today) | v2 steps 13, 17 and 19 edit `Market.luau`; v2 never creates it | Open. Default: step 16 moves the popup from `Hud.luau` into a new `Market.luau` |
| C16 | Tutorial step table | #71 owns the step machine and its table (0018 section 8) | PR #129 defines the table; this design replaces it (v2 section 8; owner decision 12) | Step 19 waits for #129 or #71, per owner decision 12 |
| C17 | Sim changes | Separate step 13: bots prepare the land in the sim | Every logic step patches `sim/Sim.luau` and regenerates the report (v2 section 12 and section 11 risks) | v2; no separate sim step |
| C18 | Step numbering | 0018 steps 1 to 15 | v2 steps 1 to 21, which assume 0018 steps 2, 3, 4, 6 and 8 to 15 still exist | Section 11 is the one numbering; the mapping is listed there |

## 11. Implementation split (v2 wins)

Each step is one PR with tests (logic steps: Lune tests; visual steps: look and motion checked by Daniel or Fable). Size: each step is meant to
stay near 400 changed lines; the sizes are an estimate and not measured. Steps 3, 9, 11, 12 and 13 are the likely ones to cut.

**Order rule.** Files that several steps edit are: `Config/Assets.luau`, `Config/Land.luau`, `Core/GameCore.luau`, `Core/Data.luau`, `Config/Locale.luau`,
`Core/ShopView.luau`, `Services/PlotService.luau`, `Services/PlotGround.luau`, `Services/PlantModels.luau`, `Client/Controllers/Market.luau`,
`Client/Main.client.luau`, `Shared/Net.luau`, `Services/Session.luau`, `default.project.json`, `sim/Sim.luau`, `docs/balance/report.md`.
Two steps that share a file run in the order of their Depends lines; if neither depends on the other, the lower number goes first and the
higher one rebases. Steps that can run at once: 1 and 2; after 1: 3, 6; after 6: 8.

**Mapping.** The v2 section 12 steps and the 0018 section 8 steps are both replaced here. v2 1 to 21 become steps 1, 3, 4, 5, 6, 10, 9,
11, 12, 13, 14, 15, 18, 19, 20, 21, 22, 23, 24, 25, 27. 0018 steps: 1 to 3 are covered by steps 1, 3, 4, 9 and 10; 4 is step 2; 5 is step 7;
6 is step 8; 7 is step 9; 8 is steps 11 to 13; 9 is step 10; 10 is step 15; 11 is step 16 with 18; 12 is step 17; 13 is folded into the sim
edits of steps 1, 3, 4 and 5 (C17); 14 is steps 19 and 20; 15 is step 26. Steps 2, 7, 8, 16, 17, 26 come from 0018 (v2 is silent on them).

Open facts that a step must measure, not assume: whether the models have separable rotor parts; `StreamingEnabled` defaults and
`Terrain.Decoration` cost (v2 section 6); phone frame time and part count with eight full plots (step 27).

1. **Site map and cell lists** (logic; v2 1). Files: `src/shared/Config/Assets.luau`, `src/shared/Core/PlotLayout.luau`, `src/shared/Config/Land.luau`,
   `src/shared/Core/Data.luau`, `tests/Assets.test.luau`, `tests/PlotLayout.test.luau`, `sim/Sim.luau`, `docs/balance/report.md`.
   Acceptance: fields are cell lists (25, 7, 7, 7, 4, 4), furniture stands in the yard, the clearance test passes on the new map and fails on today's.
   Depends on: PR #149.
2. **Hold timing check** (logic; 0018 step 4). Files: `src/shared/Core/Work.luau`, `tests/Work.test.luau`.
   Acceptance: `finish` is true only for the target `begin` started on, after at least 0.9 x hold, with one hold at a time. Depends on: none.
3. **Tool chains in the core** (logic; v2 2, plus the container and wiring gates of 0018 step 1). Files: `src/shared/Config/Land.luau`,
   `src/shared/Core/GameCore.luau`, `src/shared/Core/Toolbelt.luau`, `src/shared/Core/Data.luau`, `src/shared/Migrations/Steps.luau`,
   `tests/GameCore.test.luau`, `tests/Toolbelt.test.luau`, `tests/Data.test.luau`, `sim/Sim.luau`, `docs/balance/report.md`.
   Acceptance: `Prepare { target, cell }` advances one stage only with that stage's tool; the river only downstream; a cell counts when its chain
   is done; U17 needs the container; rule slots need `wired`; the migration of C11 has a fixture test. Depends on: 1.
4. **Capacity gate and fill-row** (logic; v2 3). Files: `src/shared/Config/Land.luau`, `src/shared/Core/GameCore.luau`, `src/shared/Core/ShopView.luau`,
   `src/shared/Config/Locale.luau`, `tests/GameCore.test.luau`, `tests/ShopView.test.luau`, `tests/Locale.test.luau`, `sim/Sim.luau`, `docs/balance/report.md`.
   Acceptance: buying stops at prepared cells x capacity; `qty = "row"` buys up to the next multiple of four; the card says "Prepare more ground";
   the report stays in its ranges. Depends on: 3 (v2 says 1; both edit `GameCore` and `Land`).
5. **Aligned rows in the core** (logic; v2 4). Files: `src/shared/Config/Land.luau`, `src/shared/Core/GameCore.luau`, `src/shared/Core/Data.luau`,
   `tests/GameCore.test.luau`, `tests/Data.test.luau`, `sim/Sim.luau`, `docs/balance/report.md`, `changelog.d/<issue>.md`.
   Acceptance: `Align { cell }` works only on a full mown row with rails; aligned panels count twice in production and storage capacity; milestones
   do not change; the report stays in its ranges. Depends on: 4.
6. **River course in the core** (logic; v2 5). Files: `src/shared/Core/River.luau` (new), `tests/River.test.luau` (new), `src/shared/Config/Assets.luau`.
   Acceptance: curve, segments, axle poses, terrain mask and bridges as in 0018 section 4 and v2 section 4, with the tests named there.
   Depends on: 1.
7. **Texts for land, tools and popups** (logic; 0018 step 5). Files: `src/shared/Config/Locale.luau`, `tests/Locale.test.luau`.
   Acceptance: every prompt, tool name, tool line (at most 60 characters), tab and hint of steps 3 to 6 has an English and a German text; later steps
   add their own keys in their own PRs. Depends on: 4, 5.
8. **World for two rows of four plots** (server; 0018 step 6, v2 silent). Files: `src/shared/Core/Landscape.luau`, `tests/Landscape.test.luau`,
   `src/server/Services/WorldService.luau`, `src/server/Services/PlotService.luau`, `src/shared/Config/Assets.luau`, `default.project.json`.
   Acceptance: plots are 192 studs, in two rows beside the road on flat meadow at `PlotLayout.slot`; the streaming properties are set; eight slots
   lie on the meadow, none on the road. Depends on: 1, 6.
9. **Units per cell on the plot** (server; v2 7, plus 0018 step 7). Files: `src/server/Services/PlotService.luau`, `src/server/Services/PlantModels.luau`,
   `src/server/Services/PlantModels.test.luau`, `src/shared/Core/PlotLayout.luau`, `tests/PlotLayout.test.luau`.
   Acceptance: a plot faces the road and has no grass slab; every prepared cell shows its visible units in fill order and a plate when it holds
   more; half-worked cells show their stage; nothing stands outside its cell. Depends on: 3, 4, 8.
10. **Work the chain under the player** (server; v2 6, plus 0018 step 9). Files: `src/server/Services/LandService.luau` (new),
    `src/server/Services/Action.luau`, `src/shared/Net.luau`, `tests/Net.test.luau`, `src/server/Main.server.luau`.
    Acceptance: one prompt per field, container and wiring on an invisible anchor at the next cell (at most 9 per plot); the prompt names the next
    stage of the cell the owner stands on and shows only with that tool in the hand; `Align row` works the same way; owner, distance (18 studs),
    hold time, tool and cell are checked on the server; `BuyTool` is the only client message. Depends on: 2, 3, 5, 7.
11. **Loose and aligned panels, mown earth** (visual; v2 8, plus the mown tile of 0018 step 8). Files: `src/shared/Config/Assets.luau`,
    `src/server/Services/PlantModels.luau`, `src/server/Services/PlotService.luau`, `src/server/Services/PlotGround.luau` (new),
    `tests/Assets.test.luau`, `changelog.d/<issue>.md`. Acceptance: a mown tile is `FillBlock` of `Ground` and shows up to four code-built panels
    as a loose scatter; an aligned tile shows a straight row on two rails; the parts sum stays in the budget. Depends on: 5, 8, 9.
    (v2 has no step for the mown earth; it is assigned here.)
12. **River with water, axles and bridges** (visual; v2 9). Files: `src/server/Services/PlotGround.luau`, `src/server/Services/PlotService.luau`,
    `src/server/Services/PlantModels.luau`, `changelog.d/<issue>.md`. Acceptance: digging shows a trench, the second hold floods it from the spring;
    each flooded segment has one axle with up to four wheels; the bridges appear; leaving the server restores the meadow; the PR records the Studio
    check of terrain water or switches to the part fallback (C1). Depends on: 6, 9, 11.
13. **House, mast, farm fence and cables** (visual; v2 10). Files: `src/server/Services/PlotGround.luau`, `src/server/Services/PlotService.luau`,
    `src/shared/Config/Assets.luau`, `changelog.d/<issue>.md`. Acceptance: the hammer builds a bare house and one PV array appears per bought unit;
    the wrench sets a guyed mast with four rotor places; the farm cell shows fence after the hammer and ground cables after the drum.
    Depends on: 9, 12.
14. **Big wind turbine, tamped pad and crank stones** (visual; v2 11). Files: `src/shared/Config/Assets.luau`, `src/server/Services/PlantModels.luau`,
    `src/server/Services/PlotGround.luau`, `src/server/Services/PlotService.luau`, `tests/Assets.test.luau`, `changelog.d/<issue>.md`.
    Acceptance: the turbine is about 60 studs to the blade tip at every count, stands on a gravel pad with foundation and cable; the crank has a
    stone ring instead of the yellow disc. Depends on: 9, 13.
15. **Rotors, wheels, foam and the tool in the hand on the client** (visual; v2 12, plus 0018 step 10). Files: `src/client/Controllers/PlotFx.luau`,
    `src/client/Main.client.luau`. Acceptance: tagged rotors and wheels within 150 studs turn with one `BulkMoveTo` per tick; the wind rotor follows
    the weather; foam drifts down flooded segments; the tool is shown in the hand while a hold runs (character attribute set by the server).
    Depends on: 12, 14 (the tags come from steps 12 and 14).
16. **Market popup with the tools tab and site states** (visual; 0018 step 11, on top of #102). Files: `src/client/Controllers/Hud.luau`,
    `src/client/Controllers/Market.luau` (new; the popup moves out of `Hud.luau`, C15), `tests/View.test.luau`. Acceptance: tabs Technik, Upgrades,
    Speicher and Werkzeuge; a plant without a site names its tool instead of Buy; Speicher starts with the container; a tool row shows name, price
    and its line. Depends on: 3, 7, #102.
17. **Control board popup** (visual; 0018 step 12). Files: `src/client/Controllers/RulesPopup.luau` (new), `src/client/Main.client.luau`.
    Acceptance: the prompt on the wired control board (text "Steuerboard") opens a modal with the rule slots of #97 and the thresholds; it closes
    by button or by walking 16 studs away. Depends on: 7, 10, 15, #97.
18. **Market texts and plant cards** (visual; v2 13). Files: `src/client/Controllers/Market.luau`, `src/shared/Core/ShopView.luau`,
    `src/shared/Config/Locale.luau`, `tests/ShopView.test.luau`, `tests/Locale.test.luau`, `changelog.d/<issue>.md`.
    Acceptance: a plant card shows "owned of capacity", the fill-row button and the aligned line; the tool tab shows the texts of v2 section 2.
    Depends on: 4, 5, 7, 10, 16.
19. **Tutorial steps** (logic; v2 14, 0018 section 8). Files: `src/shared/Core/Tutorial.luau`, `tests/Tutorial.test.luau`.
    Acceptance: the eleven steps of v2 section 8 advance on their facts (the three server facts come in step 20); a finished tutorial stays
    finished. Depends on: 3, PR #129 or #71 (C16, owner decision 12).
20. **Tutorial arrows and hints** (visual; v2 15). Files: `src/client/Controllers/Tutorial.luau`, `src/client/Main.client.luau`,
    `src/server/Services/Session.luau`, `src/shared/Config/Locale.luau`, `changelog.d/<issue>.md`. Acceptance: an arrow or pulse for every step; the
    server sends popup opened, equipped tool and land state; the hotbar hint for the scythe; one hint per new tool. Depends on: 10, 16, 18, 19.
21. **Spark items in the core** (logic; v2 16). Files: `src/shared/Config/Upgrades.luau`, `src/shared/Config/Effects.luau`,
    `src/shared/Core/GameCore.luau`, `src/shared/Core/ShopView.luau`, `src/shared/Config/Locale.luau`, `tests/GameCore.test.luau`,
    `tests/ShopView.test.luau`, `tests/Locale.test.luau`, `tests/Config.test.luau`. Acceptance: S1 to S4 work as in v2 section 9 (S5 and S6 are owned
    flags with a colour choice); the view gives the grid multiplier; `ShopView` has the "sparks" tab with a card per permanent item; the balance
    report does not change. Depends on: 5 (S4), 18.
22. **Spark tab, multiplier chip and expansion popup** (visual; v2 17). Files: `src/client/Controllers/Market.luau`, `src/client/Controllers/Hud.luau`,
    `src/shared/Config/Locale.luau`, `tests/Locale.test.luau`, `tests/View.test.luau`, `changelog.d/<issue>.md`. Acceptance: the "Sparks" tab has
    buyable cards; the HUD shows "Grid level n: output x..." and the sparks; the expansion asks for confirmation with the get, lose and keep lines.
    Depends on: 16, 21.
23. **Spark effects on the plot** (server; v2 18). Files: `src/server/Services/LandService.luau`, `src/server/Services/PlotService.luau`,
    `src/server/Services/Session.luau`, `src/shared/Net.luau`, `tests/Net.test.luau`. Acceptance: Quick Hands halves the hold the server expects and
    the prompt shows it; Sign Paint recolours sign, rope and blade tips of the own plot; the Golden Crank replaces the crank look. Depends on: 10, 14, 21.
24. **Popups clear of the tool bar** (visual; v2 19). Files: `src/client/Controllers/Market.luau`, `src/client/Main.client.luau`, `changelog.d/<issue>.md`.
    Acceptance: while the market or the control board popup is open the tool bar is hidden and no popup control lies under it; closing shows it
    again with the same tool in the hand. Depends on: 17, 22 (shared files).
25. **Tests out of the published place** (logic; v2 20). Files: `default.project.json`, `test.project.json` (new), `src/dev/TestRunner.server.luau`
    (moved from `src/server`), `tests/test_studio_project.py`, `scripts/ci/luau-check.sh`, `README.md`. Acceptance: the place built from
    `default.project.json` has no `ReplicatedStorage.Tests` and no TestRunner; `test.project.json` has both and the Studio test run passes; CI builds
    both. `scripts/ci` is a CI protection file: it goes through the security reviewer (AGENTS.md Limits 5). Depends on: 8.
26. **Turn the land gate on** (logic; 0018 step 15, switch per C12). Files: `src/shared/Config/Land.luau`, `docs/balance/report.md`, `changelog.d/<issue>.md`.
    Acceptance: the gate of step 4 and the land rules apply by default (`Land.capacity` set); the rollback of section 7 is one line. Depends on:
    3, 4, 5, 8 to 20.
27. **Bauplan and Studio checklist** (logic; v2 21, 0018 section 5 updates). Files: `Bauplan.md`, `docs/land-development-design.md`,
    `docs/balance/report.md`. Acceptance: the Bauplan names the chains, capacities, the aligned rows, the spark items and the data version; the PR
    records a two-player Studio run (each player prepares and buys on their own plot; rejoin restores the ground; an early release changes nothing)
    and the phone emulator numbers (parts, frame time) with eight full plots. Depends on: 22, 23, 24, 25, 26.
