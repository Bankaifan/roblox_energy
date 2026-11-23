--!strict
-- Shrinks the UI to a small screen (phone): the factor is 1 from DESIGN_WIDTH x DESIGN_HEIGHT up and falls to MIN_FIT below.
local ScreenFit = {}

ScreenFit.DESIGN_WIDTH = 800
ScreenFit.DESIGN_HEIGHT = 500
ScreenFit.MIN_FIT = 0.5

function ScreenFit.factor(width: number, height: number): number
	return math.clamp(math.min(width / ScreenFit.DESIGN_WIDTH, height / ScreenFit.DESIGN_HEIGHT), ScreenFit.MIN_FIT, 1)
end

return ScreenFit
