--!strict

export type UnitRarity = 3 | 4 | 5 | 6

export type UnitStats = {
	Damage: number,
	Range: number,
	Cooldown: number,
	SplashRadius: number?,
	SlowPercent: number?,
	ChainTargets: number?,
	BurnDps: number?,
}

export type UnitDefinition = {
	Id: string,
	Name: string,
	Title: string,
	Rarity: UnitRarity,
	Role: string,
	PlacementCost: number,
	SellRefundRatio: number,
	Color: Color3,
	AccentColor: Color3,
	ModelShape: "Cylinder" | "Block" | "Wedge" | "Ball",
	Stats: UnitStats,
	Description: string,
}

local StatMultipliers = { 1.00, 1.35, 1.80, 2.35, 3.00, 3.80 }
local UpgradeCostMultipliers = { 0.45, 0.65, 0.90, 1.20, 1.60 }

local Units: { [string]: UnitDefinition } = {
	archer = {
		Id = "archer",
		Name = "Silver Archer",
		Title = "Keen Eye",
		Rarity = 3,
		Role = "SingleTarget",
		PlacementCost = 100,
		SellRefundRatio = 0.7,
		Color = Color3.fromRGB(80, 160, 220),
		AccentColor = Color3.fromRGB(255, 255, 255),
		ModelShape = "Cylinder",
		Stats = {
			Damage = 18,
			Range = 20,
			Cooldown = 0.85,
		},
		Description = "Reliable rapid-fire archer. Effective against early scout swarms.",
	},
	rock_slinger = {
		Id = "rock_slinger",
		Name = "Stone Thrower",
		Title = "Earthbound",
		Rarity = 3,
		Role = "Splash",
		PlacementCost = 130,
		SellRefundRatio = 0.7,
		Color = Color3.fromRGB(160, 120, 70),
		AccentColor = Color3.fromRGB(220, 190, 120),
		ModelShape = "Block",
		Stats = {
			Damage = 26,
			Range = 18,
			Cooldown = 1.6,
			SplashRadius = 6,
		},
		Description = "Hurls hefty boulders that deal splash damage to tightly clustered foes.",
	},
	frost_mage = {
		Id = "frost_mage",
		Name = "Frost Sorceress",
		Title = "Glacial Maiden",
		Rarity = 4,
		Role = "Support",
		PlacementCost = 260,
		SellRefundRatio = 0.7,
		Color = Color3.fromRGB(60, 200, 255),
		AccentColor = Color3.fromRGB(200, 240, 255),
		ModelShape = "Ball",
		Stats = {
			Damage = 32,
			Range = 22,
			Cooldown = 1.35,
			SlowPercent = 0.35,
			SplashRadius = 7,
		},
		Description = "Blasts cold air freezing enemies, reducing their movement speed by 35%.",
	},
	cannoneer = {
		Id = "cannoneer",
		Name = "Iron Bombardier",
		Title = "Siege Specialist",
		Rarity = 4,
		Role = "Splash",
		PlacementCost = 320,
		SellRefundRatio = 0.7,
		Color = Color3.fromRGB(180, 60, 50),
		AccentColor = Color3.fromRGB(240, 140, 50),
		ModelShape = "Block",
		Stats = {
			Damage = 70,
			Range = 24,
			Cooldown = 2.0,
			SplashRadius = 9,
		},
		Description = "High-caliber explosive mortar. Clears waves of armored ground units.",
	},
	storm_shaman = {
		Id = "storm_shaman",
		Name = "Storm Shaman",
		Title = "Thunderbringer",
		Rarity = 5,
		Role = "Chain",
		PlacementCost = 600,
		SellRefundRatio = 0.75,
		Color = Color3.fromRGB(150, 70, 240),
		AccentColor = Color3.fromRGB(220, 180, 255),
		ModelShape = "Cylinder",
		Stats = {
			Damage = 95,
			Range = 26,
			Cooldown = 1.5,
			ChainTargets = 4,
		},
		Description = "Channels lightning that arcs through up to 4 consecutive enemies.",
	},
	sniper_assassin = {
		Id = "sniper_assassin",
		Name = "Phantom Sniper",
		Title = "Silent Death",
		Rarity = 5,
		Role = "Sniper",
		PlacementCost = 750,
		SellRefundRatio = 0.75,
		Color = Color3.fromRGB(230, 40, 70),
		AccentColor = Color3.fromRGB(50, 50, 50),
		ModelShape = "Block",
		Stats = {
			Damage = 250,
			Range = 40,
			Cooldown = 3.2,
		},
		Description = "Tremendous sniper rifle range. Defaults to eliminating strongest targets first.",
	},
	solar_paladin = {
		Id = "solar_paladin",
		Name = "Solar Archon",
		Title = "Dawn's Wrath",
		Rarity = 6,
		Role = "SolarAoE",
		PlacementCost = 1100,
		SellRefundRatio = 0.8,
		Color = Color3.fromRGB(255, 190, 20),
		AccentColor = Color3.fromRGB(255, 240, 180),
		ModelShape = "Ball",
		Stats = {
			Damage = 160,
			Range = 30,
			Cooldown = 1.15,
			SplashRadius = 10,
			BurnDps = 35,
		},
		Description = "Unleashes blazing orbital solar bursts, burning targets with lingering damage.",
	},
	chrono_overlord = {
		Id = "chrono_overlord",
		Name = "Chrono Overlord",
		Title = "Time Bender",
		Rarity = 6,
		Role = "TimeAura",
		PlacementCost = 1400,
		SellRefundRatio = 0.8,
		Color = Color3.fromRGB(180, 40, 210),
		AccentColor = Color3.fromRGB(100, 240, 255),
		ModelShape = "Cylinder",
		Stats = {
			Damage = 300,
			Range = 34,
			Cooldown = 2.4,
			SlowPercent = 0.50,
			SplashRadius = 12,
		},
		Description = "Distorts space-time, slowing all nearby foes by 50% while dealing crushing damage.",
	},
}

local UnitData = {
	Units = Units,
	MaxLevel = 5,
	StatMultipliers = StatMultipliers,
	UpgradeCostMultipliers = UpgradeCostMultipliers,
}

function UnitData.Get(unitId: string): UnitDefinition?
	return Units[unitId]
end

function UnitData.GetAll(): { [string]: UnitDefinition }
	return Units
end

function UnitData.GetStatsAtLevel(unitId: string, level: number): UnitStats?
	local unit = Units[unitId]
	if not unit then
		return nil
	end

	level = math.clamp(level, 0, UnitData.MaxLevel)
	local multIndex = level + 1
	local multiplier = StatMultipliers[multIndex] or 1.0

	local base = unit.Stats
	return {
		Damage = math.floor(base.Damage * multiplier + 0.5),
		Range = base.Range + (level * 1.5),
		Cooldown = math.max(0.2, base.Cooldown * (1 - (level * 0.04))),
		SplashRadius = base.SplashRadius and (base.SplashRadius + (level * 0.6)) or nil,
		SlowPercent = base.SlowPercent,
		ChainTargets = base.ChainTargets and (base.ChainTargets + math.floor(level / 2)) or nil,
		BurnDps = base.BurnDps and math.floor(base.BurnDps * multiplier + 0.5) or nil,
	}
end

function UnitData.GetUpgradeCost(unitId: string, currentLevel: number): number?
	local unit = Units[unitId]
	if not unit or currentLevel >= UnitData.MaxLevel then
		return nil
	end

	local costMult = UpgradeCostMultipliers[currentLevel + 1] or 1.0
	return math.floor(unit.PlacementCost * costMult + 0.5)
end

function UnitData.GetSellValue(unitId: string, currentLevel: number): number
	local unit = Units[unitId]
	if not unit then
		return 0
	end

	local totalInvested = unit.PlacementCost
	for lvl = 0, currentLevel - 1 do
		local costMult = UpgradeCostMultipliers[lvl + 1] or 1.0
		totalInvested += math.floor(unit.PlacementCost * costMult + 0.5)
	end

	return math.floor(totalInvested * unit.SellRefundRatio)
end

return UnitData
