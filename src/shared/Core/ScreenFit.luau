--!strict
-- Shrinks the UI to a small screen (phone): the factor is 1 from DESIGN_WIDTH x DESIGN_HEIGHT up and falls to MIN_FIT below.
local ScreenFit = {}

ScreenFit.DESIGN_WIDTH = 800
-- 600 high: the HUD list (about 430 px) and the Style buttons at the bottom left (about 170 px) just fit one above the other.
ScreenFit.DESIGN_HEIGHT = 600
ScreenFit.MIN_FIT = 0.5

function ScreenFit.factor(width: number, height: number): number
	return math.clamp(math.min(width / ScreenFit.DESIGN_WIDTH, height / ScreenFit.DESIGN_HEIGHT), ScreenFit.MIN_FIT, 1)
end

return ScreenFit
