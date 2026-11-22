--!strict
-- Digits.group: dots in German, commas elsewhere, decimals kept, no separator below 1000 or after a leading digit group.
return function(t, load)
	local Digits = load("Core/Digits")
	t.equal(Digits.group(449041465, 0, "de"), "449.041.465", "millions get dots in German")
	t.equal(Digits.group(999, 0, "de"), "999", "no separator below 1000")
	t.equal(Digits.group(1000, 0, "de"), "1.000", "1000 gets a dot")
	t.equal(Digits.group(100000, 0, "de"), "100.000", "no leading separator")
	t.equal(Digits.group(1234567.55, 1, "de"), "1.234.567,6", "a decimal comma in German")
	t.equal(Digits.group(1234567.5, 1, "en"), "1,234,567.5", "commas and a point in English")
	t.equal(Digits.group(-1500, 0, "de"), "-1.500", "the sign is kept")
	t.equal(Digits.group(0.04, 1, "de"), "0,0", "a rounded zero has no sign")
end
