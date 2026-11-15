--!strict
-- Builds the world around the plots once at server start (issue 85). Its own script, so the game loop in Main never
-- waits for it.
local WorldService = require(script.Parent:WaitForChild("Services"):WaitForChild("WorldService") :: ModuleScript) :: any

WorldService.build()
