--!strict
-- Plants from Bauplan.md, section 3. Plain tables, no logic.
-- kind: Solar, Wind or Grundlast (Bauplan column "Typ"). name: the English name (Bauplan section 3), shown in the HUD.
return {
	{ id = 1, name = "Balcony Panel", kind = "Solar", baseCost = 15, nominalPower = 1 },
	{ id = 2, name = "Water Wheel", kind = "Grundlast", baseCost = 120, nominalPower = 1.5 },
	{ id = 3, name = "Rooftop Solar", kind = "Solar", baseCost = 1100, nominalPower = 28 },
	{ id = 4, name = "Mini Turbine", kind = "Wind", baseCost = 12000, nominalPower = 40 },
	{ id = 5, name = "Solar Farm", kind = "Solar", baseCost = 130000, nominalPower = 900 },
	{ id = 6, name = "Wind Turbine", kind = "Wind", baseCost = 1400000, nominalPower = 1300 },
}
