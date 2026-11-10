--!strict
local Config = {
	-- Player Starting Economy
	StartingGold = 650,
	StartingGems = 1000,
	
	-- Base Crystal Defense
	BaseMaxHealth = 100,
	
	-- Unit Loadout
	MaxEquippedUnits = 5,
	
	-- Wave & Game Loop
	IntermissionTime = 15,
	MinWaveWaitTime = 5,
	
	-- Map Dimensions & Placement
	GridSnapSize = 4,
	MaxPlacementDistance = 120,
	
	-- Gacha Currency Cost
	SinglePullCost = 100,
	MultiPullCost = 900, -- 10% discount for 10-pull
	
	-- Rewards
	WaveClearBaseGold = 120,
	WaveClearBaseGems = 35,
}

return Config
