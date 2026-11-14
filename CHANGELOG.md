# Changelog

## [Unreleased]

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
