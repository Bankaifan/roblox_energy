import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
HUD = (ROOT / "src" / "client" / "Controllers" / "Hud.luau").read_text(encoding="utf-8")


def code_lines():
    """The Luau source without comment lines, so a comment cannot satisfy or break a rule."""
    return [line for line in HUD.splitlines() if not line.strip().startswith("--")]


def test_no_per_row_text_scaling():
    code = "\n".join(code_lines())
    assert not re.search(r"TextScaled\s*=", code)
    assert "UITextSizeConstraint" not in code


def test_one_fixed_text_size_for_rows_and_buttons():
    assert re.search(r"local ROW_TEXT = 16\b", HUD)
    assert len(re.findall(r"TextSize = ROW_TEXT\b", HUD)) >= 2


def test_rows_wrap_and_grow_with_their_text():
    assert "TextWrapped = true" in HUD
    assert "AutomaticSize = Enum.AutomaticSize.Y" in HUD


def test_inner_padding_left_and_right_is_8_px():
    assert re.search(r"local ROW_SIDE_PADDING = 8\b", HUD)
    assert "PaddingLeft = UDim.new(0, ROW_SIDE_PADDING)" in HUD
    assert "PaddingRight = UDim.new(0, ROW_SIDE_PADDING)" in HUD


def test_scrollbar_is_inset_so_it_does_not_cover_text():
    assert "ScrollBarInset = Enum.ScrollBarInset.ScrollBar" in HUD


def test_shop_is_not_in_the_hud():
    # The shop is the market popup (Controllers/Market); the HUD keeps the stats and the grid expansion.
    code = "\n".join(code_lines())
    assert "openShop" not in code
    assert "BuyPlant" not in code and "BuyNode" not in code and "BuyTool" not in code


def test_crank_is_not_a_hud_button_and_buttons_keep_touch_size():
    code = "\n".join(code_lines())
    assert 'send("Crank")' not in code
    assert re.search(r"local BUTTON_MIN_HEIGHT = 44\b", HUD)


MARKET = (ROOT / "src" / "client" / "Controllers" / "Market.luau").read_text(encoding="utf-8")


def test_market_permanent_plant_lines_wrap_and_the_card_grows():
    # The cyan permanent plant lines (issue 252) wrap instead of being cut off, and the card height counts them.
    assert re.search(r"control\.TextWrapped = true", MARKET)
    assert "permanentHeights(card)" in MARKET
    assert MARKET.count("permanentHeights(card)") >= 2
    assert "TextTruncate" not in re.search(r"Permanent\{slot\}.*?permanent\[slot\] = control", MARKET, re.DOTALL).group(0)


CLOCK = (ROOT / "src" / "client" / "Controllers" / "Clock.luau").read_text(encoding="utf-8")


def test_clock_card_replaces_the_weather_text_row():
    # Step 2 of docs/weather-sky-design.md: the card is built by the Clock controller and the old text row is gone.
    code = "\n".join(code_lines())
    assert "Clock.build(frame, nextOrder" in code
    assert 't("weather." .. change.weather)' not in code


def test_clock_card_fits_360_px():
    # The HUD panel is at most 220 px wide (328 px at 360 px is the design limit); the dial beside the text leaves room.
    panel = int(re.search(r"local PANEL_MAX_WIDTH = (\d+)", HUD).group(1))
    dial = int(re.search(r"local DIAL_NARROW = (\d+)", CLOCK).group(1))
    gap = int(re.search(r"local GAP = (\d+)", CLOCK).group(1))
    pad = int(re.search(r"local CARD_PADDING = (\d+)", CLOCK).group(1))
    assert min(360 - 32, panel) <= 328
    assert dial <= 72
    # At least 100 px for the wrapped text beside the dial.
    assert min(360 - 32, panel) - 2 * pad - dial - gap >= 100
    assert re.search(r"local ROW_TEXT = 16\b", CLOCK)
    assert "TextWrapped = true" in CLOCK
    assert "AutomaticSize = Enum.AutomaticSize.Y" in CLOCK or "AutomaticSize.Y" in CLOCK


def test_clock_card_floats_only_when_it_cannot_meet_the_tutorial_box():
    # The tutorial box is at most half the width, centred; the floating card must start right of its right edge.
    wide_min = int(re.search(r"local WIDE_MIN = (\d+)", CLOCK).group(1))
    card = int(re.search(r"local WIDE_WIDTH = (\d+)", CLOCK).group(1))
    assert wide_min >= 480
    assert wide_min - 16 - card >= wide_min * 0.75


def test_expand_question_is_green_yes_and_red_cancel():
    code = "\n".join(code_lines())
    assert re.search(r"confirmYes\.BackgroundColor3 = Theme\.colors\.good\b", code)
    assert re.search(r"confirmNo\.BackgroundColor3 = Theme\.colors\.bad\b", code)


def test_expand_button_hides_while_the_question_is_open():
    assert "expand.Visible = not show" in HUD


def test_ask_expand_false_runs_after_the_expand_button_exists():
    # askExpand reads `expand`, so the top-level call (one tab deep, outside the handlers) must come after `expand = button(`.
    expand_built = HUD.index("expand = button(frame")
    assert HUD.find("\n\taskExpand(false)\n", expand_built) != -1


def test_last_goal_closes_an_open_question():
    # When the last goal is done (view.goal == nil) an open question must close, or the expand button stays hidden.
    start = HUD.index("local function shop(view: any)")
    end = HUD.index("-- Each server message", start)
    body = HUD[start:end]
    assert "askExpand(false)" in body[body.index("else"):]
