--!strict
-- Economy formulas from Bauplan.md, section 2. Pure functions: every table is passed in, nothing is read
-- from Config or from Roblox. The constants below are the formula's own numbers (Bauplan section 2).
type Phase = { id: string, duration: number, solar: number, price: number }
type Weather = { id: string, share: number, solar: number, wind: number, price: number }

local Formulas = {}

local COST_GROWTH = 1.15 -- Kosten_i = Basiskosten_i × 1,15^Anzahl_i
local MILESTONE_COUNTS = { 10, 25, 50, 100, 150, 200 } -- Meilensteine bei 10, 25, 50, 100, 150, 200 Stück
local GRID_GROWTH = 1.6 -- Global = 1,6^Netzstufe × Netzverstärkung
local STORAGE_SECONDS = { 30, 60, 100, 150 } -- Speicher Stufe 1 bis 4 in Sekunden Mittagserzeugung
local PRESTIGE_BASE = 10000000 -- Netz-Ausbau ab 10 Mio. × 6^bisherige Netzstufe
local PRESTIGE_GROWTH = 6
local PRESTIGE_SPARKS_BASE = 5 -- Funken = 5 + 3 × bisherige Netzstufe
local PRESTIGE_SPARKS_STEP = 3

-- Phase part of Faktor_Typ: solar follows the day, wind and base load do not.
local function phaseFactor(kind: string, phase: Phase): number
	if kind == "Solar" then
		return phase.solar
	end
	return 1
end

-- Weather part of Faktor_Typ: Faktor_solar uses Wetter.solar, Faktor_wind uses Wetter.wind, base load 1.
local function weatherFactor(kind: string, weather: Weather): number
	if kind == "Solar" then
		return weather.solar
	elseif kind == "Wind" then
		return weather.wind
	end
	return 1
end

-- Faktor_Typ = Phase part × Wetter part, for kind "Solar", "Wind" or "Grundlast".
function Formulas.factor(kind: string, phase: Phase, weather: Weather): number
	return phaseFactor(kind, phase) * weatherFactor(kind, weather)
end

-- Preis = Phase.preis × Wetter.preis × Markt (Markt: upgrades U14, U15, U16 as one number).
function Formulas.price(phase: Phase, weather: Weather, market: number): number
	return phase.price * weather.price * market
end

-- Erzeugung_i = Basis_i × Anzahl_i × M_i × Faktor_Typ. basis is the plant's nominal power.
function Formulas.production(basis: number, count: number, multiplier: number, factor: number): number
	return basis * count * multiplier * factor
end

-- Number of milestones reached: one for each threshold at or below count.
function Formulas.milestones(count: number): number
	local reached = 0
	for _, threshold in MILESTONE_COUNTS do
		if count >= threshold then
			reached += 1
		end
	end
	return reached
end

-- Plant part of M_i: milestoneFactor^Meilensteine × Knoten (2 normally, 2.5 with P7).
function Formulas.plantMultiplier(count: number, milestoneFactor: number, nodes: number): number
	return milestoneFactor ^ Formulas.milestones(count) * nodes
end

-- Global part of M_i: 1,6^Netzstufe × Netzverstärkung (U09, U10, U11).
function Formulas.globalMultiplier(gridLevel: number, reinforcement: number): number
	return GRID_GROWTH ^ gridLevel * reinforcement
end

-- Kosten_i = Basiskosten_i × 1,15^Anzahl_i, the price of the next unit when `owned` are owned.
function Formulas.cost(baseCost: number, owned: number): number
	return baseCost * COST_GROWTH ^ owned
end

-- Speicher_max = Sekunden_Stufe × Mittagserzeugung. Stage 0 means no storage.
function Formulas.storageCapacity(stage: number, middayOutput: number): number
	return (STORAGE_SECONDS[stage] or 0) * middayOutput
end

-- Einnahmen im Lauf, die für den Ausbau auf `level` (1 bis 10) nötig sind: 10 Mio. × 6^(level − 1).
function Formulas.prestigeThreshold(level: number): number
	return PRESTIGE_BASE * PRESTIGE_GROWTH ^ (level - 1)
end

-- Funken für den Ausbau, wenn die bisherige Netzstufe `currentLevel` ist.
function Formulas.prestigeSparks(currentLevel: number): number
	return PRESTIGE_SPARKS_BASE + PRESTIGE_SPARKS_STEP * currentLevel
end

-- Erwartungswert je Einheit Nennleistung in Coins pro Sekunde (Schnittrate, Bauplan section 2).
-- Income is Erzeugung × Preis. Phase and weather are taken as independent, so the expectation is
-- (average over phases of phase factor × phase price) × (average over weather of weather factor × weather price).
function Formulas.expectedIncome(kind: string, phases: { Phase }, weathers: { Weather }): number
	local phaseSum, phaseTime = 0, 0
	for _, phase in phases do
		phaseSum += phase.duration * phaseFactor(kind, phase) * phase.price
		phaseTime += phase.duration
	end

	local weatherSum, weatherTotal = 0, 0
	for _, weather in weathers do
		weatherSum += weather.share * weatherFactor(kind, weather) * weather.price
		weatherTotal += weather.share
	end

	return (phaseSum / phaseTime) * (weatherSum / weatherTotal)
end

return Formulas
