# Weather in the world and a day clock (design)

Issue: #288 (design study, no implementation in this PR). Refs #288.

## 1. Goal

The weather text in the HUD says "Cloudy" while the sky shows clear weather, its effects are barely visible, and the day and
night are only a word. Goal: the world shows the weather the HUD names, a larger clock panel shows the time of day with the length
of day and night, the current weather sits beside it, and a player with the forecast extension sees the next weather. One source of
truth: the weather id the server already sends in `Env`; the client invents no weather of its own.

## 2. Current state (file references)

- `src/shared/Config/Weather.luau`: five states, share in percent: Sonnig 40, Bewoelkt 25, Windig 20, Gewitter 10, Flaute 5
  (HUD labels Sunny, Cloudy, Windy, Storm, Calm). Fields `solar`, `wind`, `price`.
- `src/server/Services/Env.luau:10`: the weather changes every `WEATHER_SECONDS = 120`; `payload` sends `phase` and `weather` ids to all
  clients (`remotes.Env`); `nextWeather()` (line 37) computes the following period.
- `src/shared/Core/GameCore.luau:1043-1053`: the Snapshot `price.nextWeather` is set only when `state.nodes.U15` is bought.
  U15 "Exchange Access" (`src/shared/Config/Upgrades.luau:26`, "Sale +10%, next weather") is the forecast extension.
- `src/shared/Config/Phases.luau`: Morgen 100 s, Mittag 300 s, Abend 160 s, Nacht 160 s. **One game day lasts 720 s = 12 minutes
  real time** (changelog `day-length.md`), so six weather periods fit into one day exactly.
- `src/shared/Core/DayCycle.luau`: `HOURS` = Morgen 5.5, Mittag 9, Abend 16.5, Nacht 20; `clockAt(time, Phases)` gives the clock hour
  from server time, linear inside a phase; `mood(hour)` gives the light. Clock hours: daylight 5.5 to 20 h is 560 s (9:20 min),
  night 20 to 5.5 h is 160 s (2:40 min). The dial turns by the clock hour, not linearly in seconds.
- `src/shared/Ambience.luau:46-49`: `Clouds.Cover = 0.56`, `Density = 0.6`, fixed. `apply(mood)` reads only the time of day. **This is
  the cause of the mismatch: nothing in the lighting or the sky reads the weather.**
- `src/client/World.client.luau:15,75`: rotors turn at the constant `ROTOR_SPEED` whatever the weather; `World.client.luau:144-158`
  sets `Lighting.ClockTime` and the mood every frame or every `MOOD_SECONDS`, and never reads `Env`.
- `src/client/Controllers/Hud.luau:364-366`: the weather is one text row, `phase / weather`, in the 220 px wide left panel
  (`PANEL_MAX_WIDTH`, line 23). `tests/test_hud_text_layout.py` pins text sizes.
- `src/shared/Config/Locale.luau:110-114, 419-423`: `weather.<id>` and `phase.<id>` texts exist in English and German.

## 3. Options with trade-offs

Roblox features considered:

- `Clouds` (on `Terrain`): `Cover`, `Density`, `Color`. Already created in `Ambience.setup`. Cover 0 is clear, 1 is overcast.
  Chosen: it is the one block that makes "cloudy" visible.
- `Atmosphere`: `Density`, `Haze`, `Color`, `Decay`. Already driven by the mood. Chosen: a weather factor multiplies haze and density.
- `Sky`: skybox, sun, moon, stars. Chosen: stars and sun stay; cloud cover and haze hide them, no second skybox.
- `Lighting` (`Brightness`, `ExposureCompensation`, `ClockTime`) and `ColorCorrectionEffect`: chosen for the dim light under clouds and
  the lightning flash.
- `ParticleEmitter`: rain, wind streaks. Chosen, one emitter each on a part that follows the camera (no per-plant emitters, so the
  count does not grow with the plots). `WindAffectsDrag`/`Workspace.GlobalWind` can also move particles and terrain grass; whether it
  is worth setting is open and the step measures it.
- `BloomEffect`, `SunRaysEffect`: already in the mood; the weather scales rays down under clouds.
- Free Toolbox or marketplace weather modules: rejected. They bring their own weather randomness (a second weather, the exact thing
  the issue forbids), unreviewed scripts and a mobile cost nobody measured.
- Server-driven visuals (change `Clouds` on the server, replicate): rejected for particles and flashes (network and per-player
  budget). Clouds and light are set by the client from `Env`; the server keeps its default and stays the only authority for the state.

Clock face:

- A. A rotated image of a dial. Needs an asset id nobody has uploaded. Rejected.
- B. A rotating container frame with 24 hour segments (thin frames, colored day or night) and a fixed pointer at the top. No asset, 24
  frames, one `Rotation` write per frame. Chosen.
- C. Text only ("Night in 2:40"). Cannot be read at a glance; kept as the second line of B.

## 4. Chosen approach

### 4.1 Mapping weather to the world (one row per `Config/Weather` id)

New pure module `Core/WeatherLook` (no Roblox APIs, table keyed by the weather id, like `Core/DayCycle`). The client blends from the
previous to the new look over 6 s (a tween, no jump) when `Env` arrives. Rotor speed is `ROTOR_SPEED * weather.wind` (the config value,
no second table); the angle becomes an accumulated angle so a speed change does not make the rotor jump.

| Weather id (HUD EN / DE) | Clouds Cover / Density | Light (brightness x, haze x) | Particles | Turbines and plants |
|---|---|---|---|---|
| Sonnig (Sunny / Sonnig) | 0.15 / 0.40 | 1.00, 1.0 | none; sun rays as the mood | rotor 0.6x, plants still |
| Bewoelkt (Cloudy / Bewölkt) | 0.85 / 0.70 | 0.75, 1.3 | none | rotor 1.0x, light sway |
| Windig (Windy / Windig) | 0.40 / 0.50 | 0.90, 1.0 | wind streaks, about 20 per second | rotor 1.6x, strong sway |
| Gewitter (Storm / Gewitter) | 1.00 / 0.90 | 0.50, 1.6 | rain, about 120 per second; lightning flash every 8 to 20 s | rotor 2.0x, strong sway |
| Flaute (Calm / Flaute) | 0.20 / 0.30 | 1.00, 1.2 (still, hazy) | none | rotor 0.2x, plants still |

The Cover and Density values are a first proposal: the step checks them in Studio against sunrise and night. The sky and the HUD text
agree because both read the same id: a test walks every id of `Config/Weather` and fails if one has no row (acceptance of step 1).
The lightning timing is random per client and purely visual; it changes no number of the game (production reads `weather.solar` and
`weather.wind` as today). Night keeps its mood: the weather factor multiplies the mood, it never lights a night.

Particle budget: at most two emitters in the world, on one part that follows the camera; none when the weather has none; rates above are
caps, halved on touch devices.

### 4.2 Clock panel

- One card replaces the text row `phase / weather`. Left: the dial, 24 hour segments in a container frame; day hours 5.5 to 20 in a warm
  color, night in a dark blue (`DayCycle.HOURS`); a fixed pointer at the top. The container turns by `(12 - clockAt(now, Phases)) * 15` degrees,
  so the current time is under the pointer and the dial turns with `DayCycle`; no clock of its own, the client reads `workspace:GetServerTimeNow()`
  like `World.client.luau`.
- Right of the dial: line 1 the phase and the clock time ("Midday 13:20"), line 2 the next change ("Night in 4:10"), line 3 the lengths
  ("Day 9:20 / Night 2:40"). Lengths and the countdown are sums and remainders of `Config/Phases`; nothing is hard-coded.
- Below the clock line, the weather chip: a colored chip with the weather text of the current id (`weather.<id>`).

### 4.3 Forecast

Shown only when the Snapshot carries `price.nextWeather`, which the server sets only with U15 (so the client cannot show it without the
extension): an arrow `>` and a second chip with the next weather text and the seconds left in this period (`120 - now % 120`). Without
U15 the chip and the arrow are not created visible: hidden, and the row takes no height. No icon assets: the chip color and text carry it.

### 4.4 Placement at 360 px

- Below 480 px viewport width the card is the first row of the left HUD panel, full panel width (at 360 px at most 328 px), dial 72 px, text
  right of it at the shared `ROW_TEXT` size 16, the card grows in height with wrapped text like the other rows (`AutomaticSize.Y`).
- At 480 px and wider the card floats at the top right, under the coin rate, 168 px wide, dial 88 px; it never overlaps the tutorial box
  (top centre, `Hud.luau:175`).
- The forecast chip goes on its own line under the weather chip, so nothing needs more than 328 px width.
- Pixel sizes are the proposal; the layout test of step 2 measures the computed widths at 360 px.

### 4.5 Texts (English / German, in `Config/Locale`)

| Key | English | German |
|---|---|---|
| `clock.time` | `{phase} {time}` | `{phase} {time}` |
| `clock.nightIn` | `Night in {time}` | `Nacht in {time}` |
| `clock.dayIn` | `Day in {time}` | `Tag in {time}` |
| `clock.lengths` | `Day {day} / Night {night}` | `Tag {day} / Nacht {night}` |
| `clock.next` | `Next: {weather} in {time}` | `Danach: {weather} in {time}` |

Weather and phase names reuse `weather.<id>` and `phase.<id>`; no new weather text.

## 5. Migration and compatibility

Additive. No remote, no save field, no config field changes: the server payload, the Snapshot and the economy numbers are untouched. The
HUD text row is replaced in step 2; `Env` carries the same fields. A client without the new modules keeps today's sky.

## 6. Test and verification plan

Each must be able to fail on today's code:
- `WeatherLook`: for every id in `Config/Weather` a row exists with Cover in 0..1; today the module does not exist. A row removed from the
  table, or a new weather without a row, fails.
- Wind: the rotor factor equals `Config/Weather.wind` for every id (no second table); a changed config value moves the rotor.
- Clock: the dial angle for a given server time matches `DayCycle.clockAt` (noon 0 degrees, midnight 180 degrees); the day and night lengths
  equal the sums of `Phases` (560 s and 160 s today); changing a phase duration changes the texts.
- Forecast: with `price.nextWeather = nil` the forecast chip is not visible; with a value it shows that weather's text.
- Texts: every `clock.*` key exists in English and German with the same placeholders; the HUD layout test checks the card at 360 px width.
- Manual, in Studio (open until run): the five weather states side by side with the HUD text, and the frame cost on a phone with Storm.

## 7. Rollback

Each step is one rebase-merged commit set. Reverting step 1 returns the fixed clouds, reverting step 2 returns the text row; steps 1 and
2 do not depend on each other, step 3 hides itself without its data.

## 8. Split into PR-sized implementation issues

Each issue carries `Design: docs/weather-sky-design.md`, at most ~400 changed lines.

### Step 1: World weather matches the state
Files: `src/shared/Core/WeatherLook.luau`, `src/shared/Ambience.luau`, `src/client/World.client.luau`, `tests/WeatherLook.test.luau`
Acceptance: every weather id of `Config/Weather` has a row; clouds, light, particles and rotor speed follow the `Env` weather and blend over 6 s.

### Step 2: Rotating day clock with the weather beside it
Files: `src/shared/Core/ClockView.luau`, `src/client/Controllers/Clock.luau`, `src/client/Controllers/Hud.luau`, `src/shared/Config/Locale.luau`, `tests/ClockView.test.luau`, `tests/test_hud_text_layout.py`
Acceptance: the dial turns with `DayCycle.clockAt`, day and night lengths come from `Config/Phases`, texts exist in English and German, the card fits at 360 px.

### Step 3: Next-weather arrow with the forecast extension
Files: `src/client/Controllers/Clock.luau`, `src/shared/Core/ClockView.luau`, `tests/ClockView.test.luau`
Acceptance: the arrow and the next weather chip show only when the Snapshot carries `price.nextWeather` (U15); hidden without it.
Depends on: 2

Steps 1 and 2 are independent with disjoint files and run in parallel. Step 3 needs step 2 (same files).

## 9. Owner decisions

none
