--!strict

export type WaveSpawnGroup = {
	Archetype: string,
	Count: number,
	Interval: number,
	DelayBefore: number,
}

export type WaveDefinition = {
	WaveNumber: number,
	Groups: { WaveSpawnGroup },
	RewardGold: number,
	RewardGems: number,
}

local WaveData = {}

local ScriptedWaves: { [number]: { WaveSpawnGroup } } = {
	[1] = {
		{ Archetype = "grunt", Count = 8, Interval = 1.2, DelayBefore = 0 },
	},
	[2] = {
		{ Archetype = "grunt", Count = 10, Interval = 1.0, DelayBefore = 0 },
		{ Archetype = "runner", Count = 4, Interval = 0.8, DelayBefore = 2 },
	},
	[3] = {
		{ Archetype = "grunt", Count = 12, Interval = 0.9, DelayBefore = 0 },
		{ Archetype = "runner", Count = 6, Interval = 0.7, DelayBefore = 2 },
		{ Archetype = "tank", Count = 2, Interval = 2.0, DelayBefore = 3 },
	},
	[4] = {
		{ Archetype = "runner", Count = 14, Interval = 0.6, DelayBefore = 0 },
		{ Archetype = "tank", Count = 5, Interval = 1.8, DelayBefore = 2 },
	},
	[5] = {
		{ Archetype = "grunt", Count = 15, Interval = 0.8, DelayBefore = 0 },
		{ Archetype = "tank", Count = 6, Interval = 1.5, DelayBefore = 1 },
		{ Archetype = "golem", Count = 1, Interval = 3.0, DelayBefore = 4 },
	},
	[6] = {
		{ Archetype = "runner", Count = 20, Interval = 0.5, DelayBefore = 0 },
		{ Archetype = "tank", Count = 8, Interval = 1.2, DelayBefore = 2 },
	},
	[7] = {
		{ Archetype = "grunt", Count = 25, Interval = 0.6, DelayBefore = 0 },
		{ Archetype = "golem", Count = 3, Interval = 2.5, DelayBefore = 3 },
	},
	[8] = {
		{ Archetype = "runner", Count = 25, Interval = 0.45, DelayBefore = 0 },
		{ Archetype = "tank", Count = 12, Interval = 1.0, DelayBefore = 2 },
		{ Archetype = "golem", Count = 4, Interval = 2.0, DelayBefore = 3 },
	},
	[9] = {
		{ Archetype = "tank", Count = 18, Interval = 0.9, DelayBefore = 0 },
		{ Archetype = "golem", Count = 6, Interval = 1.8, DelayBefore = 2 },
	},
	[10] = {
		{ Archetype = "runner", Count = 30, Interval = 0.4, DelayBefore = 0 },
		{ Archetype = "tank", Count = 15, Interval = 0.8, DelayBefore = 2 },
		{ Archetype = "golem", Count = 5, Interval = 1.5, DelayBefore = 3 },
		{ Archetype = "boss", Count = 1, Interval = 5.0, DelayBefore = 5 },
	},
}

function WaveData.GetWave(waveNumber: number): WaveDefinition
	local groups = ScriptedWaves[waveNumber]
	if not groups then
		-- Procedurally generated higher wave
		local runnerCount = 15 + math.floor(waveNumber * 1.5)
		local tankCount = 8 + math.floor(waveNumber * 1.0)
		local golemCount = 3 + math.floor(waveNumber * 0.5)
		local hasBoss = (waveNumber % 5 == 0)

		groups = {
			{ Archetype = "runner", Count = runnerCount, Interval = 0.35, DelayBefore = 0 },
			{ Archetype = "tank", Count = tankCount, Interval = 0.75, DelayBefore = 2 },
			{ Archetype = "golem", Count = golemCount, Interval = 1.5, DelayBefore = 3 },
		}

		if hasBoss then
			local bossCount = math.floor(waveNumber / 10) + 1
			table.insert(groups, { Archetype = "boss", Count = bossCount, Interval = 4.0, DelayBefore = 5 })
		end
	end

	local rewardGold = 120 + (waveNumber * 25)
	local rewardGems = 25 + math.floor(waveNumber * 3)
	if waveNumber % 5 == 0 then
		rewardGems += 50
	end

	return {
		WaveNumber = waveNumber,
		Groups = groups,
		RewardGold = rewardGold,
		RewardGems = rewardGems,
	}
end

return WaveData
