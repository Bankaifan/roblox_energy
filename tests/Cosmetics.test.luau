--!strict
-- Cosmetics (Bauplan.md, sections 3 and 4): the visible flags of a plot from the owned passes and the chosen glow colour
-- and theme, the PlotPublic payload (owner, level, counts and flags only) and its timing.
return function(t, load)
	local Cosmetics = load("Core/Cosmetics")

	local none = Cosmetics.flags({}, {})
	t.equal(none.founder, false, "no founder sign without the Founder Pack")
	t.equal(none.premium, false, "no golden meter house without the Premium Tariff")
	t.equal(none.vip, false, "no name tag without Grid VIP")
	t.equal(none.fireworks, false, "no fireworks without the Upgrade Fireworks")
	t.equal(none.neon, nil, "no glow colour without Neon Plants")
	t.equal(none.theme, "classic", "the classic theme without Plot Themes")

	local owned = { founder = true, premium = true, grid_vip = true, fireworks = true, neon = true, themes = true }
	local all = Cosmetics.flags(owned, {})
	t.equal(all.founder, true, "the founder sign follows the Founder Pack")
	t.equal(all.premium, true, "the golden meter house follows the Premium Tariff")
	t.equal(all.vip, true, "the name tag follows Grid VIP")
	t.equal(all.fireworks, true, "the fireworks follow the Upgrade Fireworks")
	t.equal(all.neon, "green", "the first colour is the default glow")
	t.equal(all.theme, "classic", "the first theme is the default")

	local chosen = Cosmetics.flags({ neon = true, themes = true }, { [1] = "gold", [2] = "night" })
	t.equal(chosen.neon, "gold", "the chosen glow colour is kept")
	t.equal(chosen.theme, "night", "the chosen theme is kept")

	local textKey = Cosmetics.flags({ neon = true }, { ["1"] = "cyan" })
	t.equal(textKey.neon, "cyan", "a slot key saved as text is read")
	local unknownColour = Cosmetics.flags({ neon = true }, { [1] = "purple" })
	t.equal(unknownColour.neon, "green", "an unknown colour falls back to the default")
	t.equal(Cosmetics.flags({}, { [1] = "gold" }).neon, nil, "a colour without the pass is not shown")

	local unknownTheme = Cosmetics.flags({ themes = true }, { [2] = "moon" })
	t.equal(unknownTheme.theme, "classic", "an unknown theme falls back to classic")
	t.equal(Cosmetics.flags({}, { [2] = "night" }).theme, "classic", "a theme without the pass is not shown")

	local payload = Cosmetics.publicState("Ada", 2, { [1] = 3, [2] = "x", [3] = 0 / 0 }, { premium = true }, {})
	local keys = 0
	for _ in payload do
		keys += 1
	end
	t.equal(keys, 4, "PlotPublic carries owner, level, plants and cosmetics only")
	t.equal(payload.owner, "Ada", "the owner's name is sent")
	t.equal(payload.level, 2, "the level is sent")
	t.equal(payload.plants[1], 3, "a plant count is sent")
	t.equal(payload.plants[2], nil, "a count that is not a number is not sent")
	t.equal(payload.plants[3], nil, "a NaN count is not sent")
	t.equal(payload.cosmetics.premium, true, "the flags are sent")

	t.equal(Cosmetics.publicState("Ada", 2.7, {}, {}, {}).level, 2, "the level is a whole number")
	t.equal(Cosmetics.publicState("Ada", -1, {}, {}, {}).level, 0, "a negative level counts as 0")
	t.equal(Cosmetics.publicState("Ada", 0 / 0, {}, {}, {}).level, 0, "a NaN level counts as 0")
	t.equal(Cosmetics.publicState("Ada", nil, {}, {}, {}).level, 0, "a missing level counts as 0")

	t.truthy(Cosmetics.publicDue(nil, 100, 5), "the first PlotPublic of a plot goes at once")
	t.equal(Cosmetics.publicDue(100, 104.9, 5), false, "no second PlotPublic before 5 seconds")
	t.truthy(Cosmetics.publicDue(100, 105, 5), "the next PlotPublic is due after 5 seconds")
end
