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
