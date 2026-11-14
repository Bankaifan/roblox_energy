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
    assert re.search(r"local ROW_TEXT = 14\b", HUD)
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


def test_detail_buy_stays_pinned_below_scrolling_text():
    # Source check only: the detail area keeps its fixed height, its text scrolls, and Buy sits at the bottom edge outside the scroll.
    code = "\n".join(code_lines())
    assert re.search(r"detail\.Size = UDim2\.new\(1, -32, 0, DETAIL_HEIGHT\)", code)
    assert re.search(r"local detailText = Instance\.new\(\"ScrollingFrame\"\)", code)
    assert re.search(r"detailText\.AutomaticCanvasSize = Enum\.AutomaticSize\.Y", code)
    assert re.search(r"detailText\.Size = UDim2\.new\(1, 0, 1, -\(ROW_MIN_HEIGHT \+ DETAIL_GAP\)\)", code)
    assert re.search(r"local detailBuy = button\(detail, \"Buy\"", code)
    assert re.search(r"detailBuy\.AutomaticSize = Enum\.AutomaticSize\.None", code)
    assert re.search(r"detailBuy\.AnchorPoint = Vector2\.new\(0, 1\)", code)
    assert re.search(r"detailBuy\.Position = UDim2\.fromScale\(0, 1\)", code)
    assert re.search(r"local DETAIL_GAP = 4\b", HUD)
