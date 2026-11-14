--!strict
-- Numbers behind the upgrade, rule, storage and offline effects (Bauplan.md, sections 2 and 3). Names stay in the Bauplan.
-- Read by Core/GameCore through env.config.effects.
return {
	plantNodeFactor = 2, -- U01 to U06: the output of that plant ×2
	typeNodeFactor = 1.5, -- U07 solar, U08 wind: every plant of that type ×1,5
	grid = { U09 = 1.25, U10 = 1.25, U11 = 1.5 }, -- Netzverstärkung I to III: alles ×
	milestoneFactor = 2, -- per milestone (10, 25, 50, 100, 150, 200 pieces)
	milestoneFactorP7 = 2.5, -- P7 Serienfertigung
	storageNodes = { "U17", "U18", "U19", "U20" }, -- Speicher Stufe 1 to 4, each stage needs the one before
	storageEfficiency = 0.85, -- Wirkungsgrad beim Laden
	storageEfficiencyU22 = 0.95, -- U22 Neue Zellchemie
	storageRateSeconds = 60, -- Laden und Verkaufen höchstens Speicher_max / 60 je Sekunde
	keptNodes = { "U17", "U18", "U19", "U20", "U21", "U22" }, -- stay after Netz-Ausbau with P5
	ruleSlots = 2, -- U21 Regelzentrale
	ruleSlotsP8 = 3, -- P8 Dritter Regel-Platz
	ruleMin = 0.5, -- Schwelle von 0,5
	ruleMax = 2, -- bis 2,0, in Zehntelschritten
	crankBase = 1, -- energy per click
	crankGear = 3, -- U12 Kurbel-Übersetzung
	crankShare = 0.02, -- U13 Schwungrad: plus 2 % der Erzeugung/s
	marketStep = 0.1, -- U14 and U15: +10 % each
	eveningFactor = 1.25, -- U16 Spitzenlast-Vertrag: Abendpreis ×1,25
	startCoins = 1000, -- P1 Startkapital
	offlineMinimumSeconds = 60, -- counted from 60 seconds away
	offlineHours = 2, -- Deckel
	offlineHoursP2 = 4, -- P2 Größerer Zähler
	offlineHoursP6 = 8, -- P6 Riesenzähler
	longMeterHours = 4, -- Pass Langzeit-Zähler, on top
	offlineEfficiency = 0.5, -- Wirkungsgrad offline
	offlineEfficiencyP4 = 0.75, -- P4 Nachtschicht
}
