--!strict
-- Theme decoration parts (docs/themes-design.md, section 4.2): every piece of the Christmas and Halloween sets has the parts its
-- budget counts, stands on the ground and stays inside the footprint its site reserves.
return function(t, load)
	local Themes = load("Config/Themes")
	local ThemeParts = load("Core/ThemeParts")

	for _, id in { "christmas", "halloween" } do
		for _, piece in Themes.sets[id].pieces do
			if piece.zone ~= "fixed" then
				local label = `{id} {piece.kind}`
				local parts = ThemeParts.kind(piece.kind, 1)
				t.truthy(parts ~= nil, `{label}: has parts`)
				if parts ~= nil then
					t.equal(#parts, piece.parts, `{label}: parts per piece`)
					local half = piece.footprint / 2 + 0.01
					for _, p in parts do
						local ok = math.abs(p.at[1]) + p.size[1] / 2 <= half and math.abs(p.at[3]) + p.size[3] / 2 <= half
						t.truthy(ok, `{label}: {p.shape} inside the footprint`)
						t.truthy(p.at[2] - p.size[2] / 2 >= -0.01, `{label}: {p.shape} on the ground`)
					end
				end
			end
		end
	end
end
