# Creator Hub list

The eleven monetization offers from `Bauplan.md` section 4, ready to type into the Creator Hub.
Prices are Robux. The Founder Pack costs 59, not 49, because Roblox only allows promoted passes priced 50 to 800 Robux.

Type: **Pass** = Game Pass, **Product** = Developer Product.

## Offers

| # | English name | German name | Type | Robux | Description |
| --- | --- | --- | --- | --- | --- |
| 1 | Founder Pack | Gründer-Paket | Pass | 59 | Grants 30 minutes of harvest income once, plus a golden crank and a founder sign on the plot. |
| 2 | Smart Hub | Smart-Zentrale | Pass | 149 | Adds a third grid slot and unlocks automatic expansion immediately instead of after P3 and P8. |
| 3 | Long Meter | Langzeit-Zähler | Pass | 99 | Raises the offline cap by 4 hours. |
| 4 | Premium Tariff | Premium-Tarif | Pass | 249 | Permanently multiplies the sale price by 1.5. |
| 5 | Grid VIP | Netzbetreiber-VIP | Pass | 299 | Adds a name tag, glowing cables, VIP colours and one free turbo per day. |
| 6 | Neon Plants | Neon-Anlagen | Pass | 99 | Makes all plants glow in a colour the player chooses. |
| 7 | Upgrade Fireworks | Ausbau-Feuerwerk | Pass | 79 | Shows fireworks and a server message on every grid upgrade. |
| 8 | Plot Themes | Themen-Grundstück | Pass | 129 | Unlocks three designs for the plot's ground, fence and sign. |
| 9 | Sunshine Hour | Sonnenstunde für alle | Product | 79 | Doubles generation for every player on the server for 10 minutes. |
| 10 | Turbo Feed-in | Turbo-Einspeisung | Product | 29 | Doubles the buyer's own income for 15 minutes. |
| 11 | Time Skip | Zeitsprung | Product | 49 | Instantly adds 1 hour of harvest income, at most 3 per day. |

## Steps, in order

1. Create the eight Game Passes (rows 1 to 8) in the Creator Hub and set each price to the Robux value above.
2. Create the three Developer Products (rows 9 to 11) and set each price to the Robux value above.
3. Icons: open. `Bauplan.md` does not specify the icon for each offer.
4. Copy each ID into `src/shared/Config/Shop.luau`: Game Pass IDs and Developer Product IDs go into separate tables, because Roblox numbers them separately. The file does not exist yet; the M3 code task creates it.
5. In Studio test mode, buy each of the 11 items once and check that it takes effect (`Bauplan.md` section 7, row M3).

## Product defaults

Set as named constants in `Config` so they can be changed later. Daniel has not decided them yet (`Bauplan.md` section 10, question 1).

- Daily limits are on: at most 3 Time Skips per day and at most 60 minutes of booster stock.
- Smart Hub grants its extras immediately.
- No purchase hint before minute 12 of play, no pop-ups and no countdown offers.
