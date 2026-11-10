--!strict

export type EnemyArchetype = {
	Id: string,
	Name: string,
	BaseHp: number,
	BaseSpeed: number,
	BaseBountyGold: number,
	BaseBountyGems: number,
	Scale: number,
	Color: Color3,
	Material: Enum.Material,
}

local Archetypes: { [string]: EnemyArchetype } = {
	grunt = {
		Id = "grunt",
		Name = "Goblin Scout",
		BaseHp = 100,
		BaseSpeed = 8.5,
		BaseBountyGold = 14,
		BaseBountyGems = 1,
		Scale = 1.0,
		Color = Color3.fromRGB(75, 120, 60),
		Material = Enum.Material.Plastic,
	},
	runner = {
		Id = "runner",
		Name = "Shadow Sprinter",
		BaseHp = 65,
		BaseSpeed = 12.5,
		BaseBountyGold = 18,
		BaseBountyGems = 1,
		Scale = 0.85,
		Color = Color3.fromRGB(220, 130, 30),
		Material = Enum.Material.Neon,
	},
	tank = {
		Id = "tank",
		Name = "Armored Orc",
		BaseHp = 320,
		BaseSpeed = 5.8,
		BaseBountyGold = 38,
		BaseBountyGems = 2,
		Scale = 1.4,
		Color = Color3.fromRGB(80, 95, 120),
		Material = Enum.Material.DiamondPlate,
	},
	golem = {
		Id = "golem",
		Name = "Magma Golem",
		BaseHp = 650,
		BaseSpeed = 5.0,
		BaseBountyGold = 85,
		BaseBountyGems = 4,
		Scale = 1.8,
		Color = Color3.fromRGB(160, 50, 30),
		Material = Enum.Material.CrackedLava,
	},
	boss = {
		Id = "boss",
		Name = "Dread Sovereign",
		BaseHp = 1500,
		BaseSpeed = 6.0,
		BaseBountyGold = 300,
		BaseBountyGems = 25,
		Scale = 2.4,
		Color = Color3.fromRGB(50, 20, 60),
		Material = Enum.Material.ForceField,
	},
}

local EnemyData = {
	Archetypes = Archetypes,
}

function EnemyData.Get(archetypeId: string): EnemyArchetype?
	return Archetypes[archetypeId]
end

function EnemyData.CalculateStatsForWave(archetypeId: string, wave: number)
	local arch = Archetypes[archetypeId] or Archetypes.grunt
	wave = math.max(1, wave)

	local hpMultiplier = (1.15) ^ (wave - 1)
	local speedMultiplier = math.min(1.35, 1 + (0.008 * (wave - 1)))
	local goldMultiplier = 1 + (0.05 * (wave - 1))

	local finalHp = math.floor(arch.BaseHp * hpMultiplier + 0.5)
	local finalSpeed = arch.BaseSpeed * speedMultiplier
	local finalGold = math.floor(arch.BaseBountyGold * goldMultiplier + 0.5)
	local finalGems = arch.BaseBountyGems

	return {
		Hp = finalHp,
		MaxHp = finalHp,
		Speed = finalSpeed,
		BountyGold = finalGold,
		BountyGems = finalGems,
		Scale = arch.Scale,
		Color = arch.Color,
		Material = arch.Material,
		Name = arch.Name,
		ArchetypeId = arch.Id,
	}
end

return EnemyData
