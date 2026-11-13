# Project rules

Optional and not managed by the template: project-specific rules go here, not into AGENTS.md.
The Limits in AGENTS.md win over anything in this file.

Project: "Power Grid Incremental", a Roblox incremental game (Luau). Plan: `Bauplan.md` (draft v0.2).

## Luau
- Code changes only as files in the repo (Rojo). Never edit the game through Studio MCP.
- Game logic lives in a pure Luau core (`src/shared/Core`) without Roblox APIs, so Lune tests run it unchanged.
- Tools are pinned in `rokit.toml` (Rojo, Lune, Selene, StyLua). `make check` runs `scripts/ci/luau-check.sh`:
  StyLua, Selene, Lune tests (`scripts/run-tests.luau`), Rojo build. Run `stylua src tests scripts` to format.
- A test is `tests/<Name>.test.luau`, returns `function(t, load)`, and loads code with `load("Core/<Module>")`. No other require.
- Keep it lean: no test a reviewer would call unnecessary.

## Studio MCP (local only, never in CI)
- Allowed (read and test): get_studio_state, start_stop_play, get_console_output, screen_capture, character_navigation,
  user_keyboard_input, user_mouse_input, search_game_tree, inspect_instance, script_read, script_grep, execute_luau (read only).
- Forbidden: multi_edit, insert_asset, generate_*, upload_image, save_place.
