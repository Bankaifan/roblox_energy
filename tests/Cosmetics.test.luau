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

	local plainCable = Cosmetics.cableLook(Cosmetics.flags({}, {}).vip)
	t.equal(plainCable.neon, false, "plain cables without Grid VIP")
	t.equal(plainCable.glow, false, "no cable light without Grid VIP")
	local vipCable = Cosmetics.cableLook(Cosmetics.flags({ grid_vip = true }, {}).vip)
	t.equal(vipCable.neon, true, "Grid VIP makes the cables neon")
	t.equal(vipCable.glow, true, "Grid VIP gives the cables a soft light")
	t.truthy(vipCable.rgb[3] > plainCable.rgb[3], "the VIP cable colour is brighter than the dark strip")

	t.equal(Cosmetics.crankLook(false, false), "plain", "no pass, no S6: the plain crank")
	t.equal(Cosmetics.crankLook(true, false), "copper", "the Founder Pack gives the copper crank")
	t.equal(Cosmetics.crankLook(false, true), "golden", "S6 gives the golden crank")
	t.equal(Cosmetics.crankLook(true, true), "golden", "with S6 the golden crank wins")
	t.equal(Cosmetics.containerScale(false), 1, "no Mega Battery: the normal container")
	t.truthy(Cosmetics.containerScale(true) > 1, "the Mega Battery shows a larger container")

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

	-- Selection (SetCosmetic): only with the pass, only listed items, saved keys as text, the old choice is kept.
	t.equal(Cosmetics.flags({ themes = true }, {}).themed, true, "Plot Themes shows the design")
	t.equal(Cosmetics.flags({ neon = true }, {}).themed, false, "no design without Plot Themes")
	local picked = Cosmetics.choose({ neon = true, themes = true }, { [2] = "night" }, Cosmetics.SLOT_NEON, "gold")
	t.equal(picked and picked["1"], "gold", "a glow colour is chosen")
	t.equal(picked and picked["2"], "night", "the other slot keeps its choice")
	t.equal(Cosmetics.flags({ neon = true, themes = true }, picked or {}).neon, "gold", "the chosen colour shows")
	t.equal(Cosmetics.choose({}, {}, Cosmetics.SLOT_NEON, "gold"), nil, "no choice without the pass")
	t.equal(Cosmetics.choose({ neon = true }, {}, Cosmetics.SLOT_THEME, "night"), nil, "a theme needs Plot Themes")
	t.equal(Cosmetics.choose({ neon = true }, {}, Cosmetics.SLOT_NEON, "purple"), nil, "an unknown colour is refused")
	t.equal(Cosmetics.choose({ neon = true }, {}, 3, "gold"), nil, "an unknown slot is refused")
	t.equal(Cosmetics.nextItem(Cosmetics.SLOT_NEON, "green"), "cyan", "the next colour")
	t.equal(Cosmetics.nextItem(Cosmetics.SLOT_NEON, "gold"), "green", "the colours wrap around")
	t.equal(Cosmetics.nextItem(Cosmetics.SLOT_THEME, nil), "classic", "no choice starts at the first theme")
	t.equal(Cosmetics.nextItem(9, "x"), nil, "an unknown slot has no next item")
	for _, id in Cosmetics.NEON_COLOURS do
		t.equal(#Cosmetics.neonRgb(id), 3, `{id}: a glow colour`)
	end
	for _, id in Cosmetics.THEMES do
		local look = Cosmetics.themeLook(id)
		t.truthy(#look.ground == 3 and #look.fence == 3 and #look.sign == 3, `{id}: ground, fence and sign`)
	end
	t.truthy(Cosmetics.themeLook("desert").ground[1] ~= Cosmetics.themeLook("night").ground[1], "the themes differ")

	-- Upgrade Fireworks: at a grid expansion of an owner of the pass only.
	t.truthy(Cosmetics.fireworksDue(0, 1, true), "an expansion with the pass fires")
	t.equal(Cosmetics.fireworksDue(0, 1, false), false, "no fireworks without the pass")
	t.equal(Cosmetics.fireworksDue(2, 2, true), false, "no expansion, no fireworks")
	t.equal(Cosmetics.expansionNotice("Ada", 3), "Ada expanded the grid to level 3!", "the server message")

	t.truthy(Cosmetics.publicDue(nil, 100, 5), "the first PlotPublic of a plot goes at once")
	t.equal(Cosmetics.publicDue(100, 104.9, 5), false, "no second PlotPublic before 5 seconds")
	t.truthy(Cosmetics.publicDue(100, 105, 5), "the next PlotPublic is due after 5 seconds")
end
