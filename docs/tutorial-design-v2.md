# Tutorial v2: guidance from the first crank turn to the first grid expansion

Status: draft, implementation-ready. Scope: a new player's first run only, from joining to the first grid expansion
(Netz-Ausbau, `level` 0 -> 1). Nothing here changes trust, tokens or CODEOWNERS paths, so this is a plain design note
(not a numbered study; `tools/design_split.py` only splits `NNNN-*.md`). Section 8 still uses the README step format so
the issues can be created by hand or by renaming the file.

## 1. Goal

A player who has never seen the game reaches the first grid expansion without outside help and without being nagged:

- At every moment of the first run there is at most one clear next action, shown as one HUD line plus one pointer
  (world arrow, hotbar pointer, market tab/card pulse or button pulse).
- The player learns why the crank matters: it is the only income before the first panel, the fastest way to close a small
  price gap, and the restart engine after an expansion.
- The path covers: crank, saving up, scythe and mowing, market, first panel, Crank Gear, tools (shovel, digging), water
  wheel, container, Home Battery, the long build-up, the grid expansion itself.
- Progress survives rejoin, steps done out of order are skipped silently, skipping is one button, and nothing shows a
  purchase (Robux) hint (Bauplan section 4: none in the first 10 minutes; `Core/Hints` stays separate).

Non-goals: guidance after the first expansion (except one closing line), the control board and rules (U21, pliers,
wiring; they have their own prompt and tab hint), sounds, metrics, a settings switch to bring hints back.

## 2. Current state (file references)

On `main` (1088c3b; the files and prices cited here did not change after 5d868eb):

- `src/shared/Core/Tutorial.luau`: pure core, six linear steps `crank, market, mowing, shovel, container, storage`;
  `Progress = { index, done }`; `step` walks forward while the current step's condition holds; `skip` is final; every
  `from` is 0 (unused). Tests: `tests/Tutorial.test.luau`.
- `src/shared/Core/Data.luau`: profile fields `tutorial = 1`, `tutorialDone = false` (version 6; `VERSION` is 7 now).
  `src/shared/Migrations/Steps.luau` 5 -> 6 marks every profile with `lifetimeEarned > 0` as `tutorialDone`.
- No service runs the core on `main`, so every saved `tutorial` is still 1.

On the open PR #185 (`origin/agent/step15-arrows`, not merged, "not yet seen in Studio"):

- `Tutorial.facts(state, seconds, cranks, marketOpened)` builds the facts from the run state.
- `src/server/Services/TutorialService.luau`: per-player entry (progress, session crank count, market opened), `observe`
  once per second from `Session.tick`, saves `tutorial`/`tutorialDone` into `profile.Data`, sends `Tutorial`.
- `src/shared/Net.luau`: `MarketOpened` and `TutorialSkip` (client), `Tutorial { id, index }` (server, `id = ""` = none).
- `src/client/Controllers/TutorialArrow.luau`: a bobbing `BillboardGui` arrow on the own plot's `CrankPrompt` or
  `ShopPrompt`; no arrow for mowing; always on, never fades.
- `Hud.tutorial`: one accent-coloured line and a skip button at the top of the HUD list.
- Locale keys `tutorial.<step>` and `tutorial.skip` in en and de.

Game facts the path is built on (all read from `main`):

- Crank: `CrankPrompt` on the crank model (`PlotService.create`), `HoldDuration` 0, at most 8 per second; one click earns
  `crankBase` (1) x price, 3 with U12 Crank Gear (50 coins) (`GameCore.crank`, `Config/Effects`).
- First panel: Balcony Panel costs 15; `buyPlant` refuses while `land.sites[1] < 1`, so one tile must be mown first.
- The scythe is owned from the start (`Config/Land.start.tools`); tools sit in the Roblox hotbar (`ToolService`); the
  field prompt shows only while the needed tool is in the hand and the player stands on a free cell (`LandService.follow`).
- The shovel (30) is revealed by the first panel; the river (field 2) needs two shovel stages per cell, cell 1 first
  (`downstream`); Water Wheel costs 120.
- Container: 500, Storage tab (`ShopView.storageCards`, card `container`); U17 Home Battery: 2,000, needs the container.
- Grid expansion: `Prestige` when `runEarned >= 10,000,000`; plants, run nodes and coins reset; land and tools stay
  (`GameCore.prestige`). The HUD already shows `goal.next` and the expand button.
- Market popup: tabs `plants, upgrades, storage, tools, sparks`, cards with ids `plant.N`, node id, `container`,
  `tool.<id>` (`Core/ShopView`); the popup hides the hotbar (`Core/PopupGate`).

Gaps of #185 that v2 closes: no pointer for mowing or tools, no explanation of the crank, the step order does not match
the real gates (the market step comes before mowing although nothing can be bought before a tile is mown), the path ends at
the storage, no fade-out or cooldown, no handling of "not enough coins yet".

## 3. Options with trade-offs

A. Keep the linear script of #185 and only append steps. Small diff, but each step has one fixed text and target, so a
   player 10 coins short of the shovel stares at "Buy the shovel" with an arrow on the market. Rejected.

B. Server owns the step, client owns the presentation (chosen). The server keeps the ordered step list, decides the
   current step from run facts and saves it. A pure shared module turns the step plus what the client already knows
   (coins, the server's view, tool in hand, open popup tab) into a presentation: line, pointer, pulse. No new messages,
   no per-frame server work, everything except the drawing is covered by Lune tests.

C. Fully client-side objectives derived from the Snapshot/Delta, nothing saved. Simplest, but soft steps and skip would
   not survive a rejoin and the server could not stop the tutorial for good. Rejected.

D. Quest-log panel with a checklist. Clear, but a permanent panel on a phone HUD that already scrolls is heavier than one
   line; the goal bar already covers the long stretch before the expansion. Rejected.

## 4. Chosen approach

### 4.1 Steps (server, `Core/Tutorial`)

Twelve steps in this order. `fact` is the completion condition; all facts except the two session ones come from the saved
run state, so they hold again after a rejoin. A `soft` step also passes after it has been shown that many seconds.

| # | id | fact (completion) | soft |
|---|-----------|-----------------------------------------------------------|------|
| 1 | crank | `cranks >= 1` (session) or `state.lifetimeEarned > 0` | |
| 2 | mow | `land.sites[1] >= 1` | |
| 3 | market | `marketOpened` (session) or `state.plants[1] >= 1` | |
| 4 | panel | `state.plants[1] >= 1` | |
| 5 | gear | `state.nodes.U12` | 90 s |
| 6 | shovel | `land.tools.shovel` | |
| 7 | dig | `land.sites[2] >= 1` | |
| 8 | wheel | `state.plants[2] >= 1` | |
| 9 | container | `land.container` | |
| 10 | storage | `state.nodes.U17` | |
| 11 | grow | never by fact | 20 s |
| 12 | expand | `state.level >= 1` (finishes the tutorial) | |

Rules of `Tutorial.step(progress, facts)`:

- Start at the saved index (the floor) and walk forward while the step's fact holds or it is a soft step whose
  `facts.shown >= soft`. After one pass by expiry, `shown` counts as 0 for the rest of the call, so two soft steps never
  expire in the same call.
- The index never goes back. Steps done early (shovel bought before the gear, a tile mown before the first crank turn)
  are passed the moment the walk reaches them, with no message for them.
- `facts.shown` replaces `facts.seconds`: seconds the current step has been current in this session. The `from` column
  is removed.
- `Tutorial.skip` and a finished step 12 set `done = true`; a done tutorial never returns (unchanged).
- `Tutorial.facts(state, shown, cranks, marketOpened)` returns `{ shown, earned, mown, marketOpened, panels, gear,
  shovel, dug, wheels, container, nodes, level }`.

### 4.2 Presentation (client, new pure `Core/TutorialView`)

`TutorialView.present(step, input)` returns what to show. `input` mirrors `ShopView.Input` plus local facts:
`{ coins, rate, view, upgrades, land, hand: string?, popup: string? }` (`hand` = id of the tool in the character's hand,
`popup` = open market tab or nil). Result:
`{ key: string, args: {}?, target: "crank"|"market"|"field1"|"field2"|nil, hotbar: string?, tab: string?,
card: string?, button: "expand"? }`. `TutorialView.KEYS` lists every key it can return (for the Locale test).

Buy steps share one helper `buy(cost, tab, card)`:

1. `coins < cost` and waiting would take more than 10 s (`rate * 10 < cost - coins`): key `tutorial.save`, target `crank`.
2. `coins < cost` otherwise: key `tutorial.wait`, no pointer.
3. Popup closed: the step's own key, target `market`.
4. Popup open on another tab: the step's key, `tab` pulses.
5. Popup open on the right tab: the step's key, `card` pulses (its buy button).

Tool steps share `work(tool, target)`: tool not in the hand: `<step>.take` with `hotbar = tool`; in the hand: `<step>.do`
with the world target.

| step | variants | pointer |
|-----------|-------------------------------------------------------------|---------|
| crank | `tutorial.crank` | arrow + beam on `CrankPrompt`, highlight on the crank model |
| mow | `work("scythe", "field1")` | hotbar pointer, then arrow on field 1 |
| market | `tutorial.market` | arrow on `ShopPrompt` |
| panel | `buy(view.plants[1].cost, "plants", "plant.1")`; if `view.plants[1].needsSite`, the `mow` variants | as helper |
| gear | `buy(50, "upgrades", "U12")` (cost from `upgrades.run`) | as helper |
| shovel | `buy(view.tools[shovel].price, "tools", "tool.shovel")` | as helper |
| dig | `work("shovel", "field2")` | hotbar pointer, then arrow on river cell 1 |
| wheel | `buy(view.plants[2].cost, "plants", "plant.2")` | as helper |
| container | `buy(land.containerCost, "storage", "container")` | as helper |
| storage | `buy(2000, "upgrades", "U17")` | as helper |
| grow | `tutorial.grow { required }` | none |
| expand | `view.goal.allowed`: `tutorial.expand { sparks }`, `button = "expand"`; else nothing at all | expand button pulse |

During `expand` before 10M the tutorial is silent on purpose: the existing goal line carries the long stretch.

Closing line: when the id changes from `expand` to `""` the client shows `tutorial.done` for 12 s (a skip never shows it).

Nudges (client only, first run only, i.e. while the tutorial is not done): `TutorialView.nudge(input, step)` returns a
presentation or nil. It is asked only while the current step shows no line (rule 1 of 4.5).

- `nudge.crank`: `rate == 0` and `coins` below the cheapest plant cost in `view.plants`, target `crank`.
- `nudge.tool { tool }`: a tool in `view.tools` is `buyable` and no step points at the market, target `market`.

### 4.3 Texts (`Config/Locale`, both tables, same placeholders)

| key | en | de |
|---|---|---|
| `tutorial.crank` | Turn the crank at the stone ring to earn coins | Dreh die Kurbel am Steinring und verdiene Coins |
| `tutorial.save` | Turn the crank: {coins} of {cost} coins | Dreh die Kurbel: {coins} von {cost} Coins |
| `tutorial.wait` | Almost there: {coins} of {cost} coins | Gleich geschafft: {coins} von {cost} Coins |
| `tutorial.mow.take` | Take the Scythe from the bar at the bottom | Nimm die Sense aus der Leiste unten |
| `tutorial.mow.do` | Step onto the meadow and mow one tile: panels need clear ground | Geh auf die Wiese und mähe ein Feld: Module brauchen freien Boden |
| `tutorial.market` | Walk to the market and open it | Geh zum Markt und öffne ihn |
| `tutorial.panel` | Buy your first Balcony Panel: it earns coins on its own | Kaufe dein erstes Balkonmodul: es verdient von allein Coins |
| `tutorial.gear` | Upgrades: the Crank Gear makes every turn count three times | Upgrades: Die Kurbel-Übersetzung lässt jede Drehung dreifach zählen |
| `tutorial.shovel` | Tools: buy the Shovel for the river | Werkzeuge: Kaufe die Schaufel für den Fluss |
| `tutorial.dig.take` | Take the Shovel from the bar at the bottom | Nimm die Schaufel aus der Leiste unten |
| `tutorial.dig.do` | Dig at the spring of the river: two digs open one stretch | Grabe an der Quelle des Flusses: zweimal graben öffnet ein Stück |
| `tutorial.wheel` | Buy a Water Wheel: it runs day and night | Kaufe ein Wasserrad: es läuft Tag und Nacht |
| `tutorial.container` | Storage: buy the container, the battery goes inside | Speicher: Kaufe den Container, dort kommt der Speicher hinein |
| `tutorial.storage` | Upgrades: the Home Battery stores cheap power and sells it at the evening peak | Upgrades: Der Heimspeicher lädt billigen Strom und verkauft ihn zur Abendspitze |
| `tutorial.grow` | Keep building. The grid expansion unlocks at {required} revenue | Bau weiter aus. Der Netz-Ausbau kommt bei {required} Einnahmen |
| `tutorial.expand` | Grid expansion ready: restart with +{sparks} sparks. Land and tools stay | Netz-Ausbau bereit: Neustart mit +{sparks} Funken. Land und Werkzeuge bleiben |
| `tutorial.done` | Well done! Your plants are gone, the crank gets the new run going | Geschafft! Die Anlagen sind weg, die Kurbel bringt den neuen Lauf in Gang |
| `tutorial.skip` | Skip tutorial | Tutorial überspringen |
| `tutorial.skipConfirm` | Tap again to skip | Zum Überspringen nochmal tippen |
| `nudge.crank` | No income yet: turn the crank | Noch keine Einnahmen: dreh die Kurbel |
| `nudge.tool` | New in the market: {tool} | Neu im Markt: {tool} |

Texts name no key or button ("press E"), so they hold on touch and gamepad. The key `tutorial.mowing` (replaced by
`tutorial.mow.*`) is removed; German U17 is "Heimspeicher" (the Locale name), not "Heimbatterie" as in #185.
Numbers are formatted with `ShopView.short`. Open: the longest lines (`tutorial.storage`, de 86 characters) against the
limits of `tests/test_hud_text_layout.py`; shorten there if it fails.

### 4.4 Visual hints (client)

- World arrow (`TutorialArrow`, extended): the existing bobbing arrow. Targets: `crank` -> `CrankPrompt`, `market` ->
  `ShopPrompt`, `field1`/`field2` -> the parts `TutorialSpot1`/`TutorialSpot2` (below). Fades to transparent within 12
  studs of the target (the prompt itself takes over) and back beyond 16.
- Beam: a `Beam` on the ground from the character to the target, only when the target has been the same for 8 s without
  the step changing and the player is farther than 30 studs. Gone as soon as he is within 12 studs.
- Highlight: a `Highlight` on the target's furniture model (crank, market) for 3 s when a step first points at it.
- Hotbar pointer (new `TutorialHotbar`): the Roblox hotbar is CoreGui and cannot be styled, so this is an own
  `ScreenGui` (`ResetOnSpawn = false`) with a bobbing arrow above the hotbar strip and the tool's name. It hides while a
  popup is open (the hotbar is hidden then, `PopupGate`) and when the tool is in the hand. Open: pointing at the exact
  slot. Slot order is the order tools were added this session, which the client cannot query; measure in Studio whether
  "above the strip, tool name in the label" is enough.
- Market pulse (`Market`): `market.highlight({ tab, card })` pulses the outline of one tab button and one card's button
  (two soft pulses, then a steady accent outline); `market.state()` returns `{ open, tab }`.
- Expand pulse (`Hud`): `hud.pulse("expand", on)` pulses the existing expand button.
- HUD line (`Hud.tutorial`, extended): takes `{ key, args }`; one pulse when the key changes, then steady; skip button
  beside it.

`TutorialSpot1` and `TutorialSpot2` are invisible, non-colliding, non-queryable parts the server puts into the plot model
in `PlotService.create`: the centre cell of field 1 and cell 1 of field 2 (the spring), from `Assets.fields[n]` and
`PlotLayout.cellCentre`. They carry no prompt and no state.

### 4.5 Anti-annoyance rules

1. One line and one pointer at a time; a nudge shows only when the step shows nothing.
2. No world or hotbar pointer while any popup is open (market, welcome, leaderboard); inside the market only the tab/card
   pulse shows.
3. Pointers fade near the target (12 studs) and the beam needs 8 s of standing still in progress.
4. A pulse runs twice, never loops; the arrow bob is the only endless motion.
5. The line dims to 60 % after 10 s on the same key and returns to full on a change.
6. Nudges: not within 10 s after a step change, each at most 3 times per session, at least 120 s between two shows of
   the same nudge, each show lasts 8 s.
7. `tutorial.save`/`tutorial.wait` update at most once per second (they ride on `Delta`).
8. Soft steps expire by themselves (gear 90 s, grow 20 s); the expiry is saved through the index, so they do not return.
9. Silent stretch: nothing from the tutorial between `grow` and 10M revenue.
10. Skip is always visible from step 2 on (step 1: after 20 s), needs a second tap within 3 s (`tutorial.skipConfirm`,
    client only), then everything is gone for good, nudges included.
11. No sound, no pop-up, no countdown, no purchase hint.

### 4.6 Server and client split

Server (authoritative, saved): step list and order, facts, soft-step timer, skip, `tutorialDone`, the `Tutorial`
message, the two spot parts. `TutorialService` changes: entry gains `since` (clock when the index last changed, reset
on change and on `send` after `Ready`), `observe` passes `os.clock() - since` as `shown`.

Client (presentation only, never trusted): `TutorialGuide` (new controller) collects the step id, the last `Delta`
(coins, rate, view), the tool in the hand (`Tool` child of the character with attribute `ToolId`, rebound on
`CharacterAdded`) and `market.state()`, calls `TutorialView.present`/`nudge` on each `Delta`, tool change, popup change
and step change, and drives `hud.tutorial`, the arrow, the hotbar pointer, `market.highlight` and `hud.pulse`. All
timers of 4.5 live here.

### 4.7 Net messages

No new message. Unchanged from #185: `MarketOpened` (client, 2 per second), `TutorialSkip` (client, 1 per 2 s),
`Tutorial { id: string, index: int }` (server; `id = ""` when done). The ids sent change to the twelve of 4.1.
`tests/Net.test.luau` counts 21 on `main`; the three messages above take it to 24, the count the steps keep.

### 4.8 Data model

- `profile.tutorial` (number): the floor index into the twelve steps. `profile.tutorialDone` (boolean): unchanged.
- No new field. Session-only: `cranks`, `marketOpened`, `since`.
- `Data.VERSION` + 1 (8 today) with one migration, see section 5.

### 4.9 Edge cases

- Rejoin: the entry is rebuilt from the profile; the walk starts at the saved floor with facts from the saved run. The
  session facts are zero again, but both are OR-ed with a saved fact, so only `market` can show once more, and only
  before the first panel, where the arrow to the market is right anyway. The soft timer restarts.
- Welcome screen (offline earnings) open on join: rule 2 hides pointers until it closes.
- `Tutorial` arrives before the plot model replicates: the arrow keeps looking every 0.5 s (already so in #185).
- Steps out of order or skipped by the player: see 4.1; `panel` falls back to the `mow` variants when no tile is mown.
- Not enough coins: `buy` variants 1 and 2; never an arrow on a card the player cannot pay.
- Player ignores a soft step: it expires. Player ignores a hard step: the line dims, the pointer stays quiet (rules 3, 5).
- Death or respawn: the arrow hangs on plot parts and survives; the hotbar gui has `ResetOnSpawn = false`; the hand is
  read again from the new character.
- Other players: every pointer is created on the client, only for the own plot (`OwnerId`).
- No plot (server full): `TutorialService.send` is never reached, the client shows nothing for `""`.
- Language button: `Hud.paint` renders the kept `{ key, args }` again; the hotbar label is rebuilt.
- Prestige: the first expansion finishes the tutorial (`level >= 1`) and shows the closing line. A profile that
  already has `level >= 1` or `tutorialDone` never gets a step; with P1/S1 irrelevant in the first run, no special case.
- Existing players: migration 5 -> 6 already set `tutorialDone` for everyone who had earned coins, also those who never
  reached the first expansion; they see nothing and get no v2 hints.
- Skip is final: no settings switch brings the hints back (4.5 rule 10).
- Exploit: a client can only send `MarketOpened` and `TutorialSkip`; both change nothing but its own hints.

## 5. Migration and compatibility

- Precondition: PR #185 is merged or its commit is the base of step 1; v2 edits its files rather than replacing them.
- The step list changes meaning of a saved index (old 3 = mowing, new 3 = market). Migration 7 -> 8: `tutorial = 1`
  unless `tutorialDone`. Because the facts come from the saved run, the first `observe` (within one second) walks the
  index forward to the right step; at worst a soft step shows once more.
- If another change takes version 8 first, this migration takes the next free number; it does not depend on the others.
- `Data.template` keeps `tutorial = 1`, `tutorialDone = false`.
- The Locale key `tutorial.mowing` is removed in the same PR that stops sending the id `mowing` (step 3 below adds the
  new keys first; the old key goes in step 6 with the HUD change).

## 6. Test and verification plan

Lune tests (all fail on today's code because the modules, ids or keys do not exist yet):

`tests/Tutorial.test.luau` (rewritten):
- `COUNT == 12`, ids in the order of 4.1, `next` chain.
- Each fact finishes exactly its step; `crank` by `lifetimeEarned > 0` without a session click (rejoin); `market` by
  `plants[1] >= 1` without `marketOpened`.
- Walk: a fresh run stays at `crank`; all facts true ends done in one call.
- Out of order: shovel owned at floor 5 with gear missing stays at `gear`; after the gear it lands on `dig`, not `shovel`.
- Soft: `gear` passes at `shown = 90`, not at 89; one call with `shown = 500` passes only one soft step (`grow` stays).
- Floor: an index never decreases even when a fact turns false (plants 0 after an expansion on a not-done progress).
- `expand` at `level = 1` sets `done`; `skip` and clamping as today.
- `Tutorial.facts` from a state with and without `land`.

`tests/TutorialView.test.luau` (new):
- Every id of `Core/Tutorial` returns a presentation with a key in `TutorialView.KEYS`.
- `buy`: the five variants for `panel` (coins 3/cost 15 rate 0 -> save + crank; coins 14 rate 1 -> wait, no target;
  affordable, popup nil -> market; popup "tools" -> tab "plants"; popup "plants" -> card "plant.1").
- `panel` with `needsSite` -> mow variants. `mow`: hand nil -> hotbar "scythe"; hand "scythe" -> target "field1".
- `dig` with hand "scythe" -> hotbar "shovel".
- `expand`: goal not allowed -> no key; allowed -> button "expand", args.sparks = 5.
- `nudge`: crank when rate 0 and coins below the cheapest plant; none while the step shows a line; tool nudge carries
  the tool's text key.

`tests/Locale.test.luau`: every key in `TutorialView.KEYS` plus `tutorial.done`, `tutorial.skip`,
`tutorial.skipConfirm` exists in en and de (placeholders are compared by the existing test).

`tests/Data.test.luau`: migration 7 -> 8 resets `tutorial` to 1 when not done and keeps a done profile done.

`tests/Net.test.luau`: count 24 (21 on `main` plus the three messages of #185); green only once #185 is merged.

Studio (local, `rojo serve test.project.json`, Studio MCP read/test tools only, fresh profile):
1. Join: arrow and highlight on the crank, line `tutorial.crank`; screenshot en and de.
2. One turn: hotbar pointer and `tutorial.mow.take`; equip: arrow on the meadow; mow: arrow on the market.
3. Open the market with 3 coins: `tutorial.save` with numbers, arrow on the crank; with 15 coins: Plants tab and the
   panel card pulse; buy.
4. Walk on through gear, shovel, dig, wheel, container, storage; check each pointer once.
5. Leave and rejoin at `dig`: same step, no earlier step shown.
6. Skip with two taps: everything gone, still gone after rejoin.
7. With a dev profile at 10M revenue: expand pulse and `tutorial.expand`; after the expansion `tutorial.done` for 12 s,
   then nothing; console without errors or warnings.
8. Phone emulator: line and skip button fit, hotbar pointer does not cover the hotbar.

## 7. Rollback

Revert the client PRs (steps 5 to 9) in any order: without `TutorialGuide` the server still sends ids and nothing is
drawn. Reverting step 1 after release needs no data repair: the version stays, `tutorial` and `tutorialDone` remain valid
numbers and booleans for the old core (the index is clamped). A player can always leave the tutorial with the skip button.

## 8. Split into PR-sized implementation issues

Steps 1, 5 and 6 edit files that PR #185 adds or changes, so they also wait for it. `Depends on: #185` is the issue form
that `tools/deps.py` reads. `tools/design_split.py` takes step numbers only: if this file is renamed to an NNNN design,
the #185 line goes into those issues by hand.

### Step 1: Tutorial core with twelve steps and soft steps
Files: `src/shared/Core/Tutorial.luau`, `tests/Tutorial.test.luau`, `src/shared/Core/Data.luau`, `src/shared/Migrations/Steps.luau`, `tests/Data.test.luau`, `src/server/Services/TutorialService.luau`
Acceptance: the Tutorial and Data tests of section 6 pass and TutorialService passes the seconds the step has been shown

### Step 2: Pure presentation model TutorialView
Files: `src/shared/Core/TutorialView.luau`, `tests/TutorialView.test.luau`
Acceptance: present and nudge return the variants of 4.2 for every step id, proven by the TutorialView tests
Depends on: 1

### Step 3: Tutorial and nudge texts in English and German
Files: `src/shared/Config/Locale.luau`, `tests/Locale.test.luau`
Acceptance: every key of TutorialView.KEYS and the skip and done keys exist in both languages with equal placeholders
Depends on: 2

### Step 4: Spot parts for field 1 and the river spring
Files: `src/server/Services/PlotService.luau`
Acceptance: every plot model holds invisible parts TutorialSpot1 and TutorialSpot2 at the centre of field 1 and at river cell 1

### Step 5: Arrow targets, proximity fade, beam and highlight
Files: `src/client/Controllers/TutorialArrow.luau`
Acceptance: the arrow takes a target name (crank, market, field1, field2 or none), fades within 12 studs and draws the beam by the rules of 4.4
Depends on: 4

### Step 6: HUD line with arguments, dimming, skip confirm and expand pulse
Files: `src/client/Controllers/Hud.luau`
Acceptance: hud.tutorial takes a key with arguments, dims after 10 s, the skip button needs two taps and hud.pulse pulses the expand button
Depends on: 3

### Step 7: Market tab and card pulse
Files: `src/client/Controllers/Market.luau`
Acceptance: market.highlight pulses one tab and one card button and market.state reports whether the popup is open and on which tab

### Step 8: Hotbar pointer
Files: `src/client/Controllers/TutorialHotbar.luau`
Acceptance: a pointer with the tool name shows above the hotbar on request and hides while a popup is open or the tool is in the hand

### Step 9: TutorialGuide wires steps, nudges and anti-annoyance timers
Files: `src/client/Controllers/TutorialGuide.luau`, `src/client/Main.client.luau`
Acceptance: the Studio checklist of section 6 passes in English and German with no console errors
Depends on: 2, 5, 6, 7, 8

Each step adds its own `changelog.d/<issue>.md` fragment where the change is visible to players (steps 5 to 9).

## 9. Owner decisions

none

