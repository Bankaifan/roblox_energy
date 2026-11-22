--!strict
-- Reads large numbers easily: thousands are separated by a dot in German (1.234.567,5), by a comma elsewhere (1,234,567.5).
local Digits = {}

-- `decimals` digits after the separator (0 rounds to a whole number); a negative value keeps its sign.
function Digits.group(value: number, decimals: number, lang: string): string
	local text = string.format(`%.{decimals}f`, math.abs(value))
	local whole, fraction = string.match(text, "^(%d+)%.?(%d*)$")
	local thousands, point = ",", "."
	if lang == "de" then
		thousands, point = ".", ","
	end
	local grouped = string.reverse(string.gsub(string.reverse(whole), "(%d%d%d)", `%1{thousands}`))
	if string.sub(grouped, 1, 1) == thousands then
		grouped = string.sub(grouped, 2)
	end
	local sign = if value < 0 and tonumber(text) ~= 0 then "-" else ""
	return if fraction == "" then sign .. grouped else `{sign}{grouped}{point}{fraction}`
end

return Digits
