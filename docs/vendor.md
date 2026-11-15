# Vendored code

| File | Source | Pinned commit | License | Fetched |
| --- | --- | --- | --- | --- |
| `src/server/Vendor/ProfileStore.luau` | https://github.com/MadStudioRoblox/ProfileStore (`ProfileStore.luau`) | `45c9847cbcf1fc260369c50eb335aba7c35aecdd` | Apache-2.0, see `src/server/Vendor/LICENSE` | 2026-11-14 |

SHA-256 of the vendored file: `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f`.

The file is kept unchanged. StyLua and Selene skip `src/server/Vendor/` (`.styluaignore`, `selene.toml`); the Rojo build includes it.

To update: fetch the file from the new commit, replace the file and `LICENSE`, update the commit, date and hash above, run `make check`.

## Models (`assets/models/*.rbxmx`)

Third-party free models (Creator Store, public domain), taken from the Studio place where Daniel inserted them and saved as text (`.rbxmx`). Scripts, sounds, lights, particles, body movers and legacy joints were removed before saving, all parts are anchored. No automatic check guards these files yet; issue #80 adds a Lune test that fails if a model file contains script or sound classes. Files were matched to the asset ids by name, size and structure, so check the look in Studio.

| File | Asset id | Asset name | Creator |
| --- | --- | --- | --- |
| `plant1_panel.rbxmx` | 138971850808156 | Solar Panel | Cultist_Yellow |
| `plant2_waterwheel.rbxmx` | 149796590 | a water wheel | ziplocBag |
| `plant3_house.rbxmx` | 8207033915 | house with roof PV | Snowfox_Brinson |
| `plant4_miniturbine.rbxmx` | 1101863864 | Wind turbine | iNfinite_SE |
| `plant5_solarfarm.rbxmx` | 8974359787 | Paneles Solares | Roclotes |
| `plant6_windturbine.rbxmx` | 10669204148 | Anomic wind turbine | confinedregion |
| `crank.rbxmx` | 139394337070318 | Hand Crank | albertmihai24 |
| `market.rbxmx` | 9460683942 | mini market | mine64gamer |
| `control.rbxmx` | 103009434750482 | Computer Terminals NASA | rick132 |
| `battery.rbxmx` | 16831123402 | TWC Intellistar 1 | buho_9000 |
