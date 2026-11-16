--!strict
-- Shop rules (Bauplan.md, section 4, and section 10 open questions 1 and 2). Product defaults until Daniel decides:
-- daily limits on, Smart Hub grants its extras at once. Change the numbers here only.
return {
	dailyLimits = true, -- limits per day are on (Bauplan section 10, question 1)
	timeSkipPerDay = 3, -- Zeitsprung: at most 3 a day while dailyLimits is on
	smartHubImmediate = true, -- Smart Hub grants its extras at once instead of through P3 and P8 (question 2)
	firstHintSeconds = 720, -- no purchase hint before minute 12 of play
}
