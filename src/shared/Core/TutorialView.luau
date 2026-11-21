--!strict
-- Tutorial v2 presentation (docs/design/tutorial-v2.md, section 4.2): from the current step and what the client knows, the one
-- line and the one pointer to show. Pure functions, no Roblox APIs; the numbers in `args` are raw (the caller formats them).
local TutorialView = {}

export type Input = {
	coins: number,
	rate: number, -- coins per second now
	view: any, -- the server's view (plants, tools, goal)
	upgrades: any, -- Config/Upgrades ({ run = { ... } })
	land: any, -- Config/Land (containerCost)
	hand: string?, -- id of the tool in the character's hand
	popup: string?, -- the open market tab, nil when the market is closed
}
export type Presentation = {
	key: string?, -- the Locale key of the line, nil = no line
	args: { [string]: any }?, -- numbers, or a Locale key for `tool`
	target: string?, -- "crank", "market", "field1", "field2", "field3"
	hotbar: string?, -- a tool id to point at above the hotbar
	tab: string?, -- a market tab to pulse
	card: string?, -- a market card to pulse
	button: string?, -- "expand": the expand button pulses
}

-- Every Locale key present() and nudge() can return, for the locale test.
TutorialView.KEYS = {
	"tutorial.align.take",
	"tutorial.align.do",
	"tutorial.wire.take",
	"tutorial.wire.do",
	"tutorial.crank",
	"tutorial.save",
	"tutorial.wait",
	"tutorial.mow.take",
	"tutorial.mow.do",
	"tutorial.market",
	"tutorial.panel",
	"tutorial.gear",
	"tutorial.shovel",
	"tutorial.dig.take",
	"tutorial.dig.do",
	"tutorial.wheel",
	"tutorial.container",
	"tutorial.storage",
	"tutorial.hammer",
	"tutorial.build.take",
	"tutorial.build.do",
	"tutorial.grow",
	"tutorial.expand",
	"nudge.crank",
	"nudge.tool",
}

-- Seconds of waiting that still count as "almost there": longer than that, the crank is pointed at.
TutorialView.WAIT_SECONDS = 10

local function runUpgradeCost(input: Input, id: string): number
	for _, node in input.upgrades.run do
		if node.id == id then
			return node.cost
		end
	end
	return 0
end

local function toolOf(input: Input, id: string): any
	for _, tool in input.view.tools or {} do
		if tool.id == id then
			return tool
		end
	end
	return nil
end

-- A purchase step: the coin gap first (save or wait), then the market, then the tab, then the card.
local function buy(input: Input, key: string, cost: number, tab: string, card: string): Presentation
	if input.coins < cost then
		local missing = cost - input.coins
		local args = { coins = math.floor(input.coins), cost = cost }
		if input.rate * TutorialView.WAIT_SECONDS < missing then
			return { key = "tutorial.save", args = args, target = "crank" }
		end
		return { key = "tutorial.wait", args = args }
	end
	if input.popup == nil then
		return { key = key, target = "market" }
	elseif input.popup ~= tab then
		return { key = key, tab = tab }
	end
	return { key = key, card = card }
end

-- A tool step: take the tool first, then work on the target.
local function work(input: Input, tool: string, prefix: string, target: string): Presentation
	if input.hand ~= tool then
		return { key = prefix .. ".take", hotbar = tool }
	end
	return { key = prefix .. ".do", target = target }
end

-- The tool the house field needs now: its chain (scythe, then hammer) is worked stage by stage, so the stage of the cell in
-- work (land.steps[3], stages done) picks the tool. Before any cell is started it is the first stage.
local function houseTool(input: Input): string
	local chain = input.land.chains[3]
	local stage = 0
	local land = input.view.land
	if land ~= nil and land.steps ~= nil then
		for _, done in land.steps[3] or {} do
			stage = math.max(stage, done)
		end
	end
	return chain[math.min(stage + 1, #chain)].tool
end

-- What to show for the step `id`.
function TutorialView.present(id: string, input: Input): Presentation
	local view = input.view
	if id == "crank" then
		return { key = "tutorial.crank", target = "crank" }
	elseif id == "mow" then
		return work(input, "scythe", "tutorial.mow", "field1")
	elseif id == "market" then
		return { key = "tutorial.market", target = "market" }
	elseif id == "panel" then
		local plant = view.plants[1]
		if plant.needsSite == true and (plant.sites or 0) < 1 then
			return work(input, "scythe", "tutorial.mow", "field1")
		end
		return buy(input, "tutorial.panel", plant.cost, "plants", "plant.1")
	elseif id == "gear" then
		return buy(input, "tutorial.gear", runUpgradeCost(input, "U12"), "upgrades", "U12")
	elseif id == "shovel" then
		local tool = toolOf(input, "shovel")
		return buy(input, "tutorial.shovel", if tool ~= nil then tool.price else 0, "tools", "tool.shovel")
	elseif id == "dig" then
		return work(input, "shovel", "tutorial.dig", "field2")
	elseif id == "wheel" then
		return buy(input, "tutorial.wheel", view.plants[2].cost, "plants", "plant.2")
	elseif id == "container" then
		return buy(input, "tutorial.container", input.land.containerCost, "storage", "container")
	elseif id == "storage" then
		return buy(input, "tutorial.storage", runUpgradeCost(input, "U17"), "upgrades", "U17")
	elseif id == "hammer" then
		local tool = toolOf(input, "hammer")
		return buy(input, "tutorial.hammer", if tool ~= nil then tool.price else 0, "tools", "tool.hammer")
	elseif id == "build" then
		return work(input, houseTool(input), "tutorial.build", "field3")
	elseif id == "grow" then
		local goal = view.goal
		return { key = "tutorial.grow", args = { required = if goal ~= nil then goal.required else 0 } }
	elseif id == "expand" then
		local goal = view.goal
		if goal ~= nil and goal.allowed == true then
			return { key = "tutorial.expand", args = { sparks = goal.sparks }, button = "expand" }
		end
	end
	return {}
end

-- A purchase that needs an action afterwards shows that action until it is done; then the step it interrupted shows again.
-- Mounting Rails: align one panel tile. Pliers: wire the control board. Nil when nothing waits.
function TutorialView.followUp(input: Input): Presentation?
	local land = input.view.land
	if land == nil then
		return nil
	end
	local tools = land.tools or {}
	local rows = if input.view.production ~= nil then input.view.production.rows else nil
	local panels = if rows ~= nil and rows[1] ~= nil then rows[1].count or 0 else 0
	if tools.rails == true and panels >= 1 and #(land.aligned or {}) < 1 then
		return work(input, "rails", "tutorial.align", "field1")
	end
	if tools.pliers == true and land.container == true and land.wired ~= true then
		return work(input, "pliers", "tutorial.wire", "wiring")
	end
	return nil
end

-- A small hint for a moment the steps do not cover, or nil. The caller asks only while the step shows no line.
function TutorialView.nudge(input: Input): Presentation?
	local view = input.view
	local cheapest = math.huge
	for _, plant in view.plants do
		cheapest = math.min(cheapest, plant.cost)
	end
	if input.rate == 0 and input.coins < cheapest then
		return { key = "nudge.crank", target = "crank" }
	end
	for _, tool in view.tools or {} do
		if tool.buyable == true then
			return { key = "nudge.tool", args = { tool = tool.textKey }, target = "market", card = "tool." .. tool.id }
		end
	end
	return nil
end

return TutorialView
