--!strict
-- Plants from Bauplan.md, section 3. Plain tables, no logic.
-- kind: Solar, Wind or Grundlast (Bauplan column "Typ").
return {
	{ id = 1, kind = "Solar", baseCost = 15, nominalPower = 1 },
	{ id = 2, kind = "Grundlast", baseCost = 120, nominalPower = 1.5 },
	{ id = 3, kind = "Solar", baseCost = 1100, nominalPower = 28 },
	{ id = 4, kind = "Wind", baseCost = 12000, nominalPower = 40 },
	{ id = 5, kind = "Solar", baseCost = 130000, nominalPower = 900 },
	{ id = 6, kind = "Wind", baseCost = 1400000, nominalPower = 1300 },
}
