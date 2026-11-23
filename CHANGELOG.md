# Changelog

## [Unreleased]

## [0.17] - 2026-11-23
- Netz-Ausbau: Das Land beginnt wieder bei null (nur Sense, nichts vorbereitet, kein Container, keine Verkabelung, keine Schienen, Werkzeuge müssen neu gekauft werden). Stamm-Anlagen und das Start-Set (S1) stehen auf frisch vorbereitetem Boden. Funken-Upgrades bleiben.
- Netz-Ausbau setzt das Land zurück (GameCore.prestige, Container-Modell in PlotService)

## [0.16] - 2026-11-23
- Grid VIP: Die Erdkabel deines Netzes leuchten jetzt neonfarben mit einem sanften Licht.
- Die Stamm-Anlagen (Robux) auf den Pflanzenkarten sind jetzt cyan Buttons und sehen so aus, als kann man sie antippen.
- Beim Leuchten gibt es jetzt die Option "Aus".
- Plot Themes: fünf neue Designs (Frühling, Sommer, Herbst, Halloween, Weihnachten) mit eigenem Bodenmaterial.
- Neu für Smart-Hub-Besitzer: Die dritte Regel "Vorausschau laden" ersetzt die Reserve-Regel und lädt den Speicher, wenn das nächste Wetter deutlich mehr zahlt als der Preis jetzt.

## [0.15] - 2026-11-23
- Alle gekauften Module sind jetzt sichtbar: gibt es mehr Einheiten als vorbereitete Zellen, teilen sie sich die Zellen in einem kleinen Raster (bis zu 4 pro Zelle, verkleinert, ohne sich zu beruehren).
- Die PV-Module der Solaranlage sitzen jetzt passend im Gestell: das Gestell steht aufrecht und die Module neigen sich mit ihm.
- Große Zahlen haben Tausenderpunkte (449.041.465): bei Coins, Rate, Speicher, Offline-Coins und Rangliste; auf Englisch mit Kommas.
- Der Pfosten des Namensschilds verdeckt die Schrift nicht mehr.
- Der Extras-Tab erscheint nur im ersten Spiel erst nach 12 Minuten, danach sofort nach dem Tutorial.
- Die Bestenliste hat das Shop-Design: dunkles Fenster mit gelbem Rand, große Tabs, rotes Schließen. Der Bestenlisten-Knopf ist gelb und größer.
- Windräder und Wasserräder drehen sich wieder zuverlässig, auch wenn das Grundstück erst nachgeladen wird.
- Beim Netz-Ausbau ist "Netz ausbauen" grün und "Abbrechen" rot. Der Netz-Ausbau-Knopf ist währenddessen ausgeblendet.
- Häuser: der gelbe Block auf dem Dach ist weg, innen wächst kein Gras mehr, und die Häuser sind größer, damit die Tür zur Spielfigur passt.
- Die Spawn-Plattform ist unsichtbar und ebenerdig, die Figur schaut beim Spawn zur Kurbel, und das Founder-Schild steht neben dem Namensschild.
- Meilensteine sind jetzt sichtbar: die Anlagenkarten zeigen den naechsten Meilenstein, ein Hinweis meldet erreichte Meilensteine, und P7 nennt die Schwellen.
- Die Ertrag-Zeilen erklaeren sich selbst: Meilensteine/Upgrades und Wetter/Tageszeit statt "M" und "jetzt".
- Smart-Zentrale: Auto-Ausbau (P3) und Dritter Regel-Platz (P8) werden mit dem Pass nicht mehr fuer Funken angeboten, sie sind enthalten.
- Die Extras-Karten zeigen jetzt die Store-Icons der Angebote statt des Geschenk-Symbols.
- Alle Windräder und Wasserräder auf deinem eigenen Grundstück drehen sich jetzt immer.

## [0.14] - 2026-11-21
- Ein gebautes Haus auf dem Dach-PV-Feld steht nach dem Hammer als leeres Haus da; mit dem Kauf des Dach-PV kommen die Module dazu.
- bare house cells (PlotLayout.bare), panel models stripped from the house clone
- Each player spawns on a platform at their own plot.
- Field work can be done in any order: mow all cells first, work them on later.
- The tutorial text is a box at the top centre with a yellow border; the income per second is large in the top right corner.
- The income per second is large in the top right corner.
- The production tab opens only at the control board, not in the shop.
- Shop cards grow to fit their text, so nothing is cut off.
- After buying Mounting Rails or Cable Pliers the tutorial points at aligning or wiring until it is done.
- Gemähte Zellen sind bis zum Rand kahl, Nachbarzellen bleiben Gras: man sieht, wo noch gemäht werden muss.
- Jeder Netz-Ausbau bringt 3 Funken mehr (8 bis 35, zusammen 215), sodass alle Funken-Upgrades ohne Bezahlung erreichbar sind.
- Premium-Tarif, Sonnenstunde, Turbo-Einspeisung, Langzeit-Zähler und Smart-Zentrale wirken jetzt im Spiel (Verkaufspreis, Erzeugung, Offline-Deckel, dritte Regel, Auto-Bau).
- Zeitsprung zahlt jetzt 20 Minuten Ertrag aus, das Gründer-Paket einmalig 30 Minuten; Langzeit-Zähler zählt schon bei der Offline-Gutschrift.
- Pässe zählen nur noch, wenn Roblox sie in dieser Sitzung bestätigt; gespeicherte Pass-Flags werden entfernt.
- Der Shop liest die Robux-Preise zur Laufzeit von Roblox (regionale Preise); Angebote ohne ID oder Preis bleiben verborgen.
- Neue geplante Robux-Preise: Turbo 39, Sonnenstunde 99, Long Meter 129, Smart Hub 199, Premium 349, VIP 399.
- Neuer Reiter Extras im Marktfenster listet die Robux-Angebote mit Live-Preis, ab Minute 12 und nur ohne Tutorial.
- Neue stille Kaufhinweise: Gründerpaket, Smart-Zentrale, Premium-Tarif und Langzeit-Zähler erscheinen als eine Zeile an ihrem Ort und führen zur Extras-Karte.
- Der Balance-Bericht misst jetzt Läufe mit Käufen (Premium-Tarif, Premium plus Turbo, drei Zeitsprünge); Z11 ist gemessen (höchstens x3).
- Pass Auto Crank / Kurbelmotor: der Server dreht die Kurbel 4-mal pro Sekunde, solange der Spieler online ist (mit Handkurbeln höchstens 8 pro Sekunde).
- Die Riesenbatterie (249 Robux) macht den Speicher 1,5-mal so groß; erhältlich im Speicher-Tab ab dem zweiten Akku und unter Extras.
- Funken-Pakete für Robux (5, 15 und 40 Funken) im Funken-Tab und im Extras-Tab; sie lassen sich nur kaufen, solange dir noch mindestens so viele Funken für Ausbauten fehlen.
- Anlagen lassen sich für Robux als Stamm-Anlagen kaufen (bis zu 10 je Typ) und bleiben nach jedem Netz-Ausbau erhalten.
- Gründer-Paket: kupferne Kurbel und Gründer-Schild am Grundstück, mit S6 gewinnt die goldene Kurbel.
- Neon-Anlagen, Ausbau-Feuerwerk und Themen-Grundstück wirken jetzt: Leuchten und Thema sind wählbar, das Feuerwerk samt Server-Meldung kommt bei jedem Netz-Ausbau.
- Der Riesenbatterie-Pass zeigt jetzt einen sichtbar größeren Container am Grundstück.
- Windrad: Rotor dreht sich um seine Nabe auf waagerechter Achse, und das Windrad steht mittig auf seinem Sockel.
- Das Tutorial führt jetzt durch den Hausbau: Hammer kaufen, dann Sense und Hammer auf dem Hausfeld einsetzen.
- Die Kurbel zeigt am Prompt, wie viele Münzen eine Drehung und eine Sekunde einbringen.

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
