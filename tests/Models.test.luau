--!strict
-- Lune only (excluded from the Rojo tree): reads every assets/models file as text. A third-party model must bring no code,
-- no sound, no unanchored part and no asset reference except visual content (mesh, texture, decal).
local fs = require("@lune/fs")

local DIR = "assets/models"
local BAD_CLASSES = { 'class="Script"', 'class="LocalScript"', 'class="ModuleScript"', 'class="Sound"' }
-- <Content name="..."> properties that may hold a rbxassetid/http reference: looks only, never audio or anything else.
local VISUAL_CONTENT = {
	Content = true,
	MeshContent = true,
	TextureContent = true,
	TexturePackContent = true,
	EmissiveMaskContent = true,
	MetalnessMapContent = true,
	NormalMapContent = true,
	RoughnessMapContent = true,
}

-- Problems in one file's text, as a list of messages (empty = clean).
local function problems(text: string): { string }
	local found = {}
	for _, class in BAD_CLASSES do
		if string.find(text, class, 1, true) then
			table.insert(found, `contains {class}`)
		end
	end
	if string.find(text, 'name="Anchored">false', 1, true) then
		table.insert(found, "has an unanchored part")
	end
	local content = ""
	for line in string.gmatch(text, "[^\n]+") do
		local name = string.match(line, '<Content name="([^"]*)"')
		if name then
			content = name
		end
		if string.find(line, "rbxassetid", 1, true) or string.find(line, "http", 1, true) then
			if not (string.find(line, "<uri>", 1, true) and VISUAL_CONTENT[content]) then
				table.insert(found, `asset reference outside visual content ({content}): {line}`)
			end
		end
	end
	return found
end

return function(t, _load)
	-- The checker itself, on small samples.
	t.equal(#problems('<Item class="Part"></Item>'), 0, "a plain part is clean")
	t.truthy(#problems('<Item class="Script">') > 0, "a Script is rejected")
	t.truthy(#problems('<Item class="LocalScript">') > 0, "a LocalScript is rejected")
	t.truthy(#problems('<Item class="ModuleScript">') > 0, "a ModuleScript is rejected")
	t.truthy(#problems('<Item class="Sound">') > 0, "a Sound is rejected")
	t.truthy(#problems('<bool name="Anchored">false</bool>') > 0, "an unanchored part is rejected")
	t.truthy(#problems('<Content name="SoundId">\n<uri>rbxassetid://1</uri>') > 0, "an audio reference is rejected")
	t.truthy(#problems('<string name="Value">http://example.com</string>') > 0, "a link in a string is rejected")
	t.equal(#problems('<Content name="MeshContent">\n<uri>rbxassetid://1</uri>'), 0, "a mesh reference is allowed")

	local files = 0
	for _, file in fs.readDir(DIR) do
		if string.match(file, "%.rbxmx$") then
			files += 1
			local found = problems(fs.readFile(`{DIR}/{file}`))
			t.equal(table.concat(found, "; "), "", `{file} is clean`)
		end
	end
	t.truthy(files >= 6, "the plant model files are present")
end
