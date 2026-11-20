--!strict
-- TutorialView: the line and pointer per step (docs/design/tutorial-v2.md, section 4.2).
return function(t, load)
	local TutorialView = load("Core/TutorialView")
	local Tutorial = load("Core/Tutorial")

	local function input(changes: { [string]: any }?): any
		local result: { [string]: any } = {
			coins = 100,
			rate = 0,
			view = {
				plants = { { cost = 15, needsSite = false, sites = 1 }, { cost = 120 } },
				tools = { { id = "shovel", price = 30, buyable = false, textKey = "tool.shovel" } },
				goal = { required = 10000000, allowed = false, sparks = 5 },
			},
			upgrades = { run = { { id = "U12", cost = 50 }, { id = "U17", cost = 2000 } } },
			land = { containerCost = 500 },
			hand = nil,
			popup = nil,
		}
		for key, value in changes or {} do
			result[key] = value
		end
		return result
	end

	-- Every step answers with a known key (or no line at all for a silent expand).
	local known: { [string]: boolean } = {}
	for _, key in TutorialView.KEYS do
		known[key] = true
	end
	for index = 1, Tutorial.COUNT do
		local presentation = TutorialView.present(Tutorial.id(index) :: string, input())
		t.truthy(presentation.key == nil or known[presentation.key], `step {index} returns a listed key`)
	end

	-- The five variants of a purchase step (panel: 15 coins).
	local far = TutorialView.present("panel", input({ coins = 3, rate = 0 }))
	t.truthy(far.key == "tutorial.save" and far.target == "crank", "far from the price: turn the crank")
	t.equal(far.args.cost, 15, "the line carries the price")
	local near = TutorialView.present("panel", input({ coins = 14, rate = 1 }))
	t.truthy(near.key == "tutorial.wait" and near.target == nil, "almost there: wait, no pointer")
	t.equal(
		TutorialView.present("panel", input({ popup = nil })).target,
		"market",
		"affordable, popup closed: the market"
	)
	t.equal(TutorialView.present("panel", input({ popup = "tools" })).tab, "plants", "other tab: pulse the tab")
	t.equal(TutorialView.present("panel", input({ popup = "plants" })).card, "plant.1", "right tab: pulse the card")

	-- A panel without a mown tile falls back to mowing.
	local view = input().view
	view.plants[1] = { cost = 15, needsSite = true, sites = 0 }
	t.equal(
		TutorialView.present("panel", input({ view = view })).key,
		"tutorial.mow.take",
		"no tile yet: take the scythe"
	)

	-- Tool steps.
	t.equal(TutorialView.present("mow", input({ hand = nil })).hotbar, "scythe", "scythe not in hand: the hotbar")
	t.equal(TutorialView.present("mow", input({ hand = "scythe" })).target, "field1", "in hand: the meadow")
	t.equal(TutorialView.present("dig", input({ hand = "scythe" })).hotbar, "shovel", "dig needs the shovel")
	t.equal(TutorialView.present("dig", input({ hand = "shovel" })).target, "field2", "the spring of the river")

	-- Costs come from the config and the view.
	t.equal(TutorialView.present("gear", input({ coins = 10 })).args.cost, 50, "U12 costs 50")
	t.equal(TutorialView.present("shovel", input({ coins = 10 })).args.cost, 30, "the shovel price from the view")
	t.equal(
		TutorialView.present("container", input({ coins = 10 })).args.cost,
		500,
		"the container cost from the land config"
	)
	t.equal(TutorialView.present("storage", input({ coins = 10 })).args.cost, 2000, "U17 costs 2000")

	-- Grow and expand.
	t.equal(TutorialView.present("grow", input()).args.required, 10000000, "grow names the revenue goal")
	t.equal(TutorialView.present("expand", input()).key, nil, "expand is silent before the goal is reached")
	local ready = input()
	ready.view.goal.allowed = true
	local expand = TutorialView.present("expand", ready)
	t.truthy(expand.button == "expand" and expand.args.sparks == 5, "expand pulses the button and names the sparks")

	-- Nudges.
	local idle = input({ coins = 0, rate = 0 })
	t.equal(TutorialView.nudge(idle).key, "nudge.crank", "no income and no coins: the crank")
	local rich = input({ coins = 100, rate = 0 })
	t.equal(TutorialView.nudge(rich), nil, "nothing to say")
	rich.view.tools[1].buyable = true
	local tool = TutorialView.nudge(rich)
	t.truthy(
		tool ~= nil and tool.key == "nudge.tool" and tool.args.tool == "tool.shovel",
		"a buyable tool is mentioned"
	)

	-- Follow-up after a purchase: the action comes first, then the step shows again.
	t.equal(TutorialView.followUp(input()), nil, "no land in the view: no follow-up")
	local function owned(land: any, panels: number): any
		local base = input().view
		base.land = land
		base.production = { rows = { { count = panels } } }
		return input({ view = base })
	end
	t.equal(TutorialView.followUp(owned({ tools = {} }, 3)), nil, "nothing bought: no follow-up")
	local rails = { tools = { rails = true }, aligned = {} }
	t.equal(TutorialView.followUp(owned(rails, 0)), nil, "rails without panels: nothing to align")
	t.equal(TutorialView.followUp(owned(rails, 3)).key, "tutorial.align.take", "rails bought: take the rails")
	local holding = owned(rails, 3)
	holding.hand = "rails"
	local align = TutorialView.followUp(holding)
	t.truthy(align ~= nil and align.key == "tutorial.align.do" and align.target == "field1", "rails in hand: align")
	rails.aligned = { 13 }
	t.equal(TutorialView.followUp(owned(rails, 3)), nil, "one panel aligned: back to the step")
	local pliers = { tools = { pliers = true }, container = true, wired = false }
	t.equal(TutorialView.followUp(owned(pliers, 0)).key, "tutorial.wire.take", "pliers bought: take the pliers")
	pliers.wired = true
	t.equal(TutorialView.followUp(owned(pliers, 0)), nil, "wired: back to the step")
end
