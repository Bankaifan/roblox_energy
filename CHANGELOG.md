# Changelog

## [Unreleased]

## [0.13] - 2026-11-20
- Welcome screen after the join: shows the time away and the offline coins, with one Collect button.
- Saved data moves to version 2 (migration step 1 to 2) as the base for the shop catalogue.
- Purchases on the server: one receipt callback for all products, a receipt is credited once, owned passes are checked on join.
- Sunshine Hour: a server-wide x2 generation booster for all players, with a queue of up to 60 minutes. The sky turns golden and a banner names the buyer. Turbo Feed-in: 15 minutes x2 for one player.
- Language: all HUD, shop, welcome and banner texts are in English and German. The game starts in the player's language, and a Language button in the HUD switches between them.
- Tutorial core: the opening steps from the crank to the storage, skippable and never shown again once done. Data version 4 saves the tutorial step and a done flag.
- Leaderboards: the server list (live, by grid level and run earnings) and the world list (top 50, updated at most once a minute), opened from a button at the bottom left. Both in English and German.
- The Collect button on the welcome screen and the Sunshine Hour button are at least 44 px high (touch size).
- Plots show the supplied plant models (sanitised, capped copies per plant) and fall back to the primitive columns.
- Plots show a crank, a mini market (no posters, two solar panels), a control center from U21 and one green battery unit per storage stage.
- A world around the plots: a valley with hills, a lake, rocks, trees, bushes, a country road with power poles and wind turbines, built at runtime from terrain and simple parts.
- Day and night follow the day phases: warm hazy days, a long golden evening, a blue night with lamps, glowing flowers and softly lit power plants.
- Plots are now 120 x 120 studs with large plant pads (at most 3 copies each), furniture spread around them, and the market's solar panels mounted flat on its facade.
- The crank can now be used on the crank model in the world: the plot owner gets a "Crank" prompt next to it. The HUD button still works.
- The market is about three times bigger, its solar panels sit on the building, and its "Shop" prompt opens the shop panel (new Shop button in the HUD). Each field shows up to four copies, 2 x 2.
- The HUD explains the storage (hint line, fill percent, one line per mode) and the battery units on the plot tint by charge level.
- The electricity price shows in the HUD. The Storage tab of the market has a Regelautomatik section: price now, buy-below and sell-above thresholds with steppers and a switch; Auto needs a rule. Saved rule slots are migrated.
- Battery units now stack directly on top of each other, without a gap.
- Layout core for the large plots: plot slots, land fields with fixed-size sites and wild panels (not used by the game yet).
- Internal: a timing check for holds on land work (a hold counts only if it is nearly full length and on the same target).
- Plots are 192 studs and stand in two rows of four beside the road; instance streaming is on (min radius 192, target radius 640).
- Plots face the road without a grass slab and show min(owned, sites) fixed-size units; panels lie wild until Mounting Rails, then in rows of four.
- A plot stays a natural meadow: only the patches around the crank and the market, prepared sites and units become bare earth with an irregular outline, and a field that waits for its tool is marked by a low, slightly crooked stake-and-rope fence; the straight sand frame is gone.
- Cables on the ground now run from the solar farm and wind turbine cells to the grid box once the cable drum has laid them.
- Prompts on each plot prepare the land: only the owner, standing at the site and holding the full time, prepares the next site; BuyTool is a limited client message.
- Wind rotors and water wheels only turn within 150 studs of the camera, which saves work on phones.
- The market popup has four tabs (Plants, Upgrades, Storage, Tools); a plant without a site names its tool, and Storage starts with the container.
- The control board has a prompt that opens the rule slots (storage tab) in the popup.
- Tutorial steps now lead from the crank over market, mowing, shovel and container to the storage.
- Tool belt: every owned tool is a real tool in the hotbar (scythe from the start). Land is prepared only with the matching tool in the hand, grass goes only by mowing, and a plant needs a prepared site before it can be bought.
- The land development design study lives in docs/land-development-design.md.
- Der Hammer zieht um jede Solarfarm-Zelle einen Holzzaun, sobald die Zelle fertig ist.
- Der Schraubenschlüssel setzt auf jede Mini-Windrad-Zelle einen verspannten Mast mit Querarm, dessen Spitze auf Nabenhöhe liegt; er verschwindet, sobald das Windrad steht.
- Field prompts name the step of the tool in hand: the scythe mows, the cable drum lays cable.
- A power overview tab in the market and on the control board (key F) shows what each plant makes and how it is calculated.
- The tutorial has twelve steps from the first crank turn to the first grid expansion; steps already done are skipped.
- The tutorial now points with an arrow, a hotbar pointer and market outlines, and names the price gap while you save up.
- Die Studio-Konsole meldet keine volle Warteschlange mehr für Net.PlotPublic, weil der Client den Kanal jetzt annimmt.
- PlotPublic listener (no-op) in Main.client.luau
- make check lässt luau-lsp die Typen in src/client prüfen; eine unbekannte Eigenschaft an einer getypten Instanz bricht die Prüfung ab

## [0.12] - 2026-11-14
- Plots: each player gets their own plot, up to 8 per server; a plot is freed when its player leaves. A ninth player is told the server is full.

## [0.11] - 2026-11-14
- Saving: each player's run is saved on the server (ProfileStore, session lock), restored on rejoin, and the time away is paid as offline income. A profile that cannot be loaded is not played; the player is told to rejoin.

## [0.10] - 2026-11-14
- HUD: all rows share one text size and wrap onto a second line instead of shrinking; inner padding keeps text off the edge and the scrollbar on narrow screens.

## [0.9] - 2026-11-14
- HUD: every upgrade has a short effect text. Tapping a row selects it; a fixed detail area shows its name, effect, cost and lock reason, and its Buy button buys it.

## [0.8] - 2026-11-14
- HUD: the panel fits narrow screens (at most 300 px wide, scrolls), captions shrink to 12 px and wrap instead of being cut off, and unaffordable rows stay readable.

## [0.7] - 2026-11-14
- HUD: run upgrade nodes with cost and state, storage modes, rule slots and the grid expansion button.

## [0.6] - 2026-11-14
- HUD: buy buttons show the plant name, its next price and dim when unaffordable; the crank button shows its energy per click; the next grid expansion and the run earnings are shown; phase and weather labels are in English.

## [0.5] - 2026-11-14
- First playable screen: one plot built from basic parts, a simple HUD (coins, rates, crank, buy buttons, storage, grid level) and the server session that runs GameCore once per second.

## [0.4] - 2026-11-14
- Balance: simulation bots (optimal, occasional, child) on GameCore and a balance report against Z1 to Z11 (part 1: values reported, tolerances not enforced yet; no player-visible change).

## [0.3] - 2026-11-14
- Core: GameCore with tick, apply and offline, server checks for every action, and the upgrade effect numbers in Config (no player-visible change yet).

## [0.2] - 2026-11-14
- Core: economy formulas and day and weather phases from a seed (no player-visible change yet).

## [0.1] - 2026-11-13
- Bootstrap: agent template, Luau tooling (Rokit, Rojo, Lune, Selene, StyLua), test runner.
