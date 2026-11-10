--!strict

export type HeroRole = "Defender" | "Guard" | "Sniper" | "Caster" | "Medic" | "Support"
export type PlacementType = "Ground" | "HighGround"

export type ActiveSkillDefinition = {
	Name: string,
	Description: string,
	EnergyCost: number, -- typically 100
	Multiplier: number,
	Duration: number?,
	Radius: number?,
}

export type PassiveSkillDefinition = {
	Name: string,
	Description: string,
	RequiredStar: number, -- 4 or 6
	StatBonus: { [string]: number }?,
	EffectType: string?,
}

export type HeroDefinition = {
	Id: string,
	Name: string,
	Title: string,
	Role: HeroRole,
	PlacementType: PlacementType,
	BaseStar: number, -- 3, 4, 5
	BlockCount: number, -- 3 for Defender, 1-2 for Guard, 0 for HighGround
	BaseHp: number,
	BaseAtk: number,
	BaseDef: number,
	Range: number, -- In grid tiles
	AttackSpeed: number, -- Attacks per second
	HealingPower: number?,
	ActiveSkill: ActiveSkillDefinition,
	PassiveSkills: { PassiveSkillDefinition },
	Color: Color3,
	AccentColor: Color3,
}

local STAR_LEVEL_CAPS: { [number]: number } = {
	[1] = 20,
	[2] = 30,
	[3] = 40,
	[4] = 60,
	[5] = 100,
	[6] = 140,
	[7] = 170,
	[8] = 200,
	[9] = 225,
	[10] = 250,
}

local Heroes: { [string]: HeroDefinition } = {
	-- 1-STAR HEROES (Common Recruits)
	militia_recruit = {
		Id = "militia_recruit",
		Name = "Town Militia",
		Title = "Town Guard Recruit",
		Role = "Defender",
		PlacementType = "Ground",
		BaseStar = 1,
		BlockCount = 2,
		BaseHp = 500,
		BaseAtk = 30,
		BaseDef = 40,
		Range = 1.0,
		AttackSpeed = 0.7,
		ActiveSkill = {
			Name = "Shield Raise",
			Description = "Increases DEF by 20% for 5s.",
			EnergyCost = 100,
			Multiplier = 1.2,
			Duration = 5.0,
		},
		PassiveSkills = {},
		Color = Color3.fromRGB(90, 95, 105),
		AccentColor = Color3.fromRGB(150, 155, 165),
	},

	scout_bowman = {
		Id = "scout_bowman",
		Name = "Frontier Scout",
		Title = "Rookie Bowman",
		Role = "Sniper",
		PlacementType = "HighGround",
		BaseStar = 1,
		BlockCount = 0,
		BaseHp = 260,
		BaseAtk = 70,
		BaseDef = 15,
		Range = 3.2,
		AttackSpeed = 0.9,
		ActiveSkill = {
			Name = "Quick Draw",
			Description = "Fires a swift arrow dealing 140% damage.",
			EnergyCost = 100,
			Multiplier = 1.4,
		},
		PassiveSkills = {},
		Color = Color3.fromRGB(80, 110, 80),
		AccentColor = Color3.fromRGB(140, 180, 140),
	},

	apprentice_mage = {
		Id = "apprentice_mage",
		Name = "Novice Mage",
		Title = "Academy Dropout",
		Role = "Caster",
		PlacementType = "HighGround",
		BaseStar = 1,
		BlockCount = 0,
		BaseHp = 240,
		BaseAtk = 65,
		BaseDef = 15,
		Range = 3.0,
		AttackSpeed = 0.8,
		ActiveSkill = {
			Name = "Spark Bolt",
			Description = "Casts a spark dealing 150% Magic damage.",
			EnergyCost = 100,
			Multiplier = 1.5,
		},
		PassiveSkills = {},
		Color = Color3.fromRGB(100, 70, 120),
		AccentColor = Color3.fromRGB(170, 140, 190),
	},

	-- 2-STAR HEROES (Trained Soldiers)
	veteran_infantry = {
		Id = "veteran_infantry",
		Name = "Veteran Guard",
		Title = "Frontline Soldier",
		Role = "Guard",
		PlacementType = "Ground",
		BaseStar = 2,
		BlockCount = 2,
		BaseHp = 680,
		BaseAtk = 90,
		BaseDef = 35,
		Range = 1.1,
		AttackSpeed = 1.0,
		ActiveSkill = {
			Name = "Slash",
			Description = "Heavy slash dealing 160% damage.",
			EnergyCost = 100,
			Multiplier = 1.6,
		},
		PassiveSkills = {},
		Color = Color3.fromRGB(110, 80, 70),
		AccentColor = Color3.fromRGB(180, 140, 120),
	},

	temple_medic = {
		Id = "temple_medic",
		Name = "Village Healer",
		Title = "Herbalist",
		Role = "Medic",
		PlacementType = "HighGround",
		BaseStar = 2,
		BlockCount = 0,
		BaseHp = 320,
		BaseAtk = 30,
		BaseDef = 20,
		Range = 2.8,
		AttackSpeed = 0.85,
		HealingPower = 70,
		ActiveSkill = {
			Name = "Herbal Salve",
			Description = "Heals an ally for 180% Healing Power.",
			EnergyCost = 100,
			Multiplier = 1.8,
		},
		PassiveSkills = {},
		Color = Color3.fromRGB(60, 120, 90),
		AccentColor = Color3.fromRGB(120, 200, 160),
	},

	iron_shield = {
		Id = "iron_shield",
		Name = "Iron Sentry",
		Title = "Gatekeeper",
		Role = "Defender",
		PlacementType = "Ground",
		BaseStar = 2,
		BlockCount = 3,
		BaseHp = 850,
		BaseAtk = 45,
		BaseDef = 60,
		Range = 1.1,
		AttackSpeed = 0.75,
		ActiveSkill = {
			Name = "Lockdown",
			Description = "Increases DEF by 30% for 6s.",
			EnergyCost = 100,
			Multiplier = 1.3,
			Duration = 6.0,
		},
		PassiveSkills = {},
		Color = Color3.fromRGB(75, 85, 95),
		AccentColor = Color3.fromRGB(130, 145, 160),
	},

	-- 4-STAR HEROES (Elite Specialists)
	storm_warden = {
		Id = "storm_warden",
		Name = "Garrick Thunderforge",
		Title = "The Storm Shield",
		Role = "Defender",
		PlacementType = "Ground",
		BaseStar = 4,
		BlockCount = 3,
		BaseHp = 1650,
		BaseAtk = 85,
		BaseDef = 110,
		Range = 1.2,
		AttackSpeed = 0.85,
		ActiveSkill = {
			Name = "Thunder Clap",
			Description = "Slams the ground with electric force, stunning blocked enemies for 1.5s and dealing 180% damage.",
			EnergyCost = 100,
			Multiplier = 1.8,
			Radius = 1.5,
		},
		PassiveSkills = {
			{
				Name = "Static Armor",
				Description = "+20% DEF and shocks attackers for 10% damage.",
				RequiredStar = 4,
				StatBonus = { Def = 0.20 },
			},
		},
		Color = Color3.fromRGB(40, 90, 140),
		AccentColor = Color3.fromRGB(120, 200, 255),
	},

	flame_alchemist = {
		Id = "flame_alchemist",
		Name = "Ember Pyre",
		Title = "Blaze Alchemist",
		Role = "Caster",
		PlacementType = "HighGround",
		BaseStar = 4,
		BlockCount = 0,
		BaseHp = 820,
		BaseAtk = 280,
		BaseDef = 45,
		Range = 3.4,
		AttackSpeed = 0.95,
		ActiveSkill = {
			Name = "Incineration Field",
			Description = "Ignites the ground beneath target, dealing 260% Magic AoE damage.",
			EnergyCost = 100,
			Multiplier = 2.6,
			Radius = 2.0,
		},
		PassiveSkills = {
			{
				Name = "Scorched Earth",
				Description = "+15% Magic ATK.",
				RequiredStar = 4,
				StatBonus = { Atk = 0.15 },
			},
		},
		Color = Color3.fromRGB(180, 70, 30),
		AccentColor = Color3.fromRGB(255, 140, 60),
	},

	shadow_assassin = {
		Id = "shadow_assassin",
		Name = "Vane Daggerfall",
		Title = "Silent Blade",
		Role = "Guard",
		PlacementType = "Ground",
		BaseStar = 4,
		BlockCount = 2,
		BaseHp = 1100,
		BaseAtk = 210,
		BaseDef = 55,
		Range = 1.3,
		AttackSpeed = 1.3,
		ActiveSkill = {
			Name = "Shadow Thrust",
			Description = "Strikes vital point dealing 300% critical damage.",
			EnergyCost = 100,
			Multiplier = 3.0,
		},
		PassiveSkills = {
			{
				Name = "Lethal Edge",
				Description = "+20% Critical Rate.",
				RequiredStar = 4,
				StatBonus = { CritRate = 0.20 },
			},
		},
		Color = Color3.fromRGB(60, 45, 80),
		AccentColor = Color3.fromRGB(160, 110, 210),
	},
	-- DEFENDERS (Ground / Land, Block 3)
	iron_garrison = {
		Id = "iron_garrison",
		Name = "Bastian Ironclad",
		Title = "The Unbroken Wall",
		Role = "Defender",
		PlacementType = "Ground",
		BaseStar = 3,
		BlockCount = 3,
		BaseHp = 1200,
		BaseAtk = 65,
		BaseDef = 85,
		Range = 1.2,
		AttackSpeed = 0.8,
		ActiveSkill = {
			Name = "Fortress Bulwark",
			Description = "Raises shield, gaining +50% DEF and taunting nearby enemies for 6s.",
			EnergyCost = 100,
			Multiplier = 1.5,
			Duration = 6.0,
		},
		PassiveSkills = {
			{
				Name = "Dense Armor",
				Description = "+20% Max HP.",
				RequiredStar = 4,
				StatBonus = { Hp = 0.20 },
			},
			{
				Name = "Impenetrable Bastion",
				Description = "Reflects 15% of incoming physical damage back to attackers.",
				RequiredStar = 6,
				EffectType = "ReflectDamage",
			},
		},
		Color = Color3.fromRGB(70, 85, 110),
		AccentColor = Color3.fromRGB(180, 200, 230),
	},

	valkyrie_aegis = {
		Id = "valkyrie_aegis",
		Name = "Brunhilda Shieldmaiden",
		Title = "Dawn's Protector",
		Role = "Defender",
		PlacementType = "Ground",
		BaseStar = 5,
		BlockCount = 3,
		BaseHp = 2200,
		BaseAtk = 110,
		BaseDef = 140,
		Range = 1.2,
		AttackSpeed = 0.85,
		ActiveSkill = {
			Name = "Aegis of Radiance",
			Description = "Creates a divine light dome, absorbing up to 800 damage and healing allies in 2-tile radius for 15% Max HP.",
			EnergyCost = 100,
			Multiplier = 2.0,
			Duration = 8.0,
			Radius = 2.0,
		},
		PassiveSkills = {
			{
				Name = "Holy Grace",
				Description = "+25% DEF and +10% healing received.",
				RequiredStar = 4,
				StatBonus = { Def = 0.25 },
			},
			{
				Name = "Resplendent Retribution",
				Description = "When blocking 3 enemies, gains +35% ATK and heals for 5% HP on each attack.",
				RequiredStar = 6,
				EffectType = "BlockBuff",
			},
		},
		Color = Color3.fromRGB(220, 180, 50),
		AccentColor = Color3.fromRGB(255, 245, 180),
	},

	-- GUARDS (Ground / Land, Block 2, Melee DPS)
	crimson_duelist = {
		Id = "crimson_duelist",
		Name = "Kaelen Bloodedge",
		Title = "Crimson Blade",
		Role = "Guard",
		PlacementType = "Ground",
		BaseStar = 3,
		BlockCount = 2,
		BaseHp = 850,
		BaseAtk = 140,
		BaseDef = 45,
		Range = 1.2,
		AttackSpeed = 1.2,
		ActiveSkill = {
			Name = "Cross Slash",
			Description = "Delivers two rapid slashes dealing 220% Physical ATK to all blocked foes.",
			EnergyCost = 100,
			Multiplier = 2.2,
		},
		PassiveSkills = {
			{
				Name = "Razor Focus",
				Description = "+15% Critical Strike Chance.",
				RequiredStar = 4,
				StatBonus = { CritRate = 0.15 },
			},
			{
				Name = "Bloodlust Aura",
				Description = "Each enemy killed grants +8% ATK for 8s (stacks up to 4 times).",
				RequiredStar = 6,
				EffectType = "KillStackAtk",
			},
		},
		Color = Color3.fromRGB(180, 45, 45),
		AccentColor = Color3.fromRGB(255, 100, 100),
	},

	shadow_reaper = {
		Id = "shadow_reaper",
		Name = "Lyra Nightshade",
		Title = "Phantom Slayer",
		Role = "Guard",
		PlacementType = "Ground",
		BaseStar = 5,
		BlockCount = 2,
		BaseHp = 1500,
		BaseAtk = 260,
		BaseDef = 70,
		Range = 1.4,
		AttackSpeed = 1.35,
		ActiveSkill = {
			Name = "Dance of Shadows",
			Description = "Flashes across up to 4 nearby enemies, dealing 340% ATK damage and ignoring 30% armor.",
			EnergyCost = 100,
			Multiplier = 3.4,
		},
		PassiveSkills = {
			{
				Name = "Armor Penetration",
				Description = "+20% ATK and attacks ignore 25% target DEF.",
				RequiredStar = 4,
				StatBonus = { Atk = 0.20 },
			},
			{
				Name = "Shadow Step",
				Description = "Dodges 20% of incoming attacks; successful dodges restore 20 Energy.",
				RequiredStar = 6,
				EffectType = "DodgeEnergy",
			},
		},
		Color = Color3.fromRGB(90, 40, 120),
		AccentColor = Color3.fromRGB(190, 100, 240),
	},

	-- SNIPERS (HighGround, Anti-Air / Single-Target Burst)
	hawk_archer = {
		Id = "hawk_archer",
		Name = "Silas Swiftflight",
		Title = "Windstrider",
		Role = "Sniper",
		PlacementType = "HighGround",
		BaseStar = 3,
		BlockCount = 0,
		BaseHp = 550,
		BaseAtk = 160,
		BaseDef = 30,
		Range = 3.8,
		AttackSpeed = 1.0,
		ActiveSkill = {
			Name = "Volley of Gales",
			Description = "Fires a rapid 3-arrow barrage at the furthest target along the path, dealing 280% damage.",
			EnergyCost = 100,
			Multiplier = 2.8,
		},
		PassiveSkills = {
			{
				Name = "High Ground Advantage",
				Description = "+15% Damage against enemies not currently blocked.",
				RequiredStar = 4,
				StatBonus = { Damage = 0.15 },
			},
			{
				Name = "Eagle Eye",
				Description = "+1 Tile Attack Range and +20% Critical Damage.",
				RequiredStar = 6,
				StatBonus = { Range = 1.0, CritDamage = 0.20 },
			},
		},
		Color = Color3.fromRGB(50, 130, 200),
		AccentColor = Color3.fromRGB(150, 220, 255),
	},

	celestial_ballista = {
		Id = "celestial_ballista",
		Name = "Aurelia Sunstrike",
		Title = "Solar Deadeye",
		Role = "Sniper",
		PlacementType = "HighGround",
		BaseStar = 5,
		BlockCount = 0,
		BaseHp = 950,
		BaseAtk = 340,
		BaseDef = 45,
		Range = 4.8,
		AttackSpeed = 0.75,
		ActiveSkill = {
			Name = "Supernova Bolt",
			Description = "Charges a colossal light spear dealing 550% ATK to the highest-HP target in range.",
			EnergyCost = 100,
			Multiplier = 5.5,
		},
		PassiveSkills = {
			{
				Name = "Solar Focus",
				Description = "+25% ATK against Bosses and Mini-Bosses.",
				RequiredStar = 4,
				StatBonus = { BossDamage = 0.25 },
			},
			{
				Name = "Radiant Pierce",
				Description = "Critical hits cause a solar blast dealing 100% splash damage to adjacent enemies.",
				RequiredStar = 6,
				EffectType = "CritSplash",
			},
		},
		Color = Color3.fromRGB(240, 150, 30),
		AccentColor = Color3.fromRGB(255, 230, 120),
	},

	-- CASTERS (HighGround, Magic AoE)
	pyro_magus = {
		Id = "pyro_magus",
		Name = "Ignis Hearthfire",
		Title = "Flame Conjurer",
		Role = "Caster",
		PlacementType = "HighGround",
		BaseStar = 3,
		BlockCount = 0,
		BaseHp = 520,
		BaseAtk = 175,
		BaseDef = 28,
		Range = 3.2,
		AttackSpeed = 0.65,
		ActiveSkill = {
			Name = "Inferno Burst",
			Description = "Hurls a blazing fireball exploding in a 1.8-tile radius for 260% Magic Damage.",
			EnergyCost = 100,
			Multiplier = 2.6,
			Radius = 1.8,
		},
		PassiveSkills = {
			{
				Name = "Ignition",
				Description = "Attacks apply burn dealing 20% ATK every second for 3s.",
				RequiredStar = 4,
				EffectType = "BurnDoT",
			},
			{
				Name = "Pyromancy Mastery",
				Description = "+25% AoE Explosion Radius and +15% Magic ATK.",
				RequiredStar = 6,
				StatBonus = { Atk = 0.15 },
			},
		},
		Color = Color3.fromRGB(210, 60, 40),
		AccentColor = Color3.fromRGB(255, 170, 70),
	},

	void_arcanist = {
		Id = "void_arcanist",
		Name = "Morrigan Netherwhisper",
		Title = "Void Sovereign",
		Role = "Caster",
		PlacementType = "HighGround",
		BaseStar = 5,
		BlockCount = 0,
		BaseHp = 920,
		BaseAtk = 320,
		BaseDef = 40,
		Range = 3.5,
		AttackSpeed = 0.70,
		ActiveSkill = {
			Name = "Black Hole Singularity",
			Description = "Summons a gravitational collapse for 5s, pulling enemies toward center and dealing 400% total damage.",
			EnergyCost = 100,
			Multiplier = 4.0,
			Duration = 5.0,
			Radius = 2.4,
		},
		PassiveSkills = {
			{
				Name = "Nether Resonance",
				Description = "Attacks bypass 40% of target Magic Resistance.",
				RequiredStar = 4,
				StatBonus = { MagicPen = 0.40 },
			},
			{
				Name = "Dark Matter Decay",
				Description = "Enemies inside Singularity take 20% increased damage from all sources.",
				RequiredStar = 6,
				EffectType = "DamageAmpAura",
			},
		},
		Color = Color3.fromRGB(120, 30, 160),
		AccentColor = Color3.fromRGB(220, 120, 255),
	},

	-- MEDICS (HighGround, Heals Allies on Ground/Tower)
	verdant_cleric = {
		Id = "verdant_cleric",
		Name = "Flora Dewbloom",
		Title = "Grove Priestess",
		Role = "Medic",
		PlacementType = "HighGround",
		BaseStar = 3,
		BlockCount = 0,
		BaseHp = 600,
		BaseAtk = 0,
		BaseDef = 35,
		Range = 3.0,
		AttackSpeed = 0.8,
		HealingPower = 150,
		ActiveSkill = {
			Name = "Vital Spring",
			Description = "Instantly heals the ally with lowest HP percentage for 320% Healing Power, granting +20% DEF for 5s.",
			EnergyCost = 100,
			Multiplier = 3.2,
		},
		PassiveSkills = {
			{
				Name = "Gentle Care",
				Description = "+20% Healing output on allies below 50% HP.",
				RequiredStar = 4,
				EffectType = "LowHpHealBoost",
			},
			{
				Name = "Grove's Blessing",
				Description = "Allies healed gain 10 Energy immediately.",
				RequiredStar = 6,
				EffectType = "HealEnergyGrant",
			},
		},
		Color = Color3.fromRGB(50, 180, 90),
		AccentColor = Color3.fromRGB(170, 245, 180),
	},

	luminous_high_priest = {
		Id = "luminous_high_priest",
		Name = "Elyse Sunhallow",
		Title = "Seraphic Herald",
		Role = "Medic",
		PlacementType = "HighGround",
		BaseStar = 5,
		BlockCount = 0,
		BaseHp = 1050,
		BaseAtk = 0,
		BaseDef = 55,
		Range = 3.6,
		AttackSpeed = 0.9,
		HealingPower = 280,
		ActiveSkill = {
			Name = "Benediction of Dawn",
			Description = "Unleashes a tidal wave of light healing ALL deployed allies for 250% Healing Power and cleansing debuffs.",
			EnergyCost = 100,
			Multiplier = 2.5,
			Radius = 99.0, -- Map wide!
		},
		PassiveSkills = {
			{
				Name = "Guardian Angel",
				Description = "When an ally would take fatal damage, grants an immunity shield for 2s (once per battle).",
				RequiredStar = 4,
				EffectType = "DeathSaveShield",
			},
			{
				Name = "Continuous Aura",
				Description = "Passively regenerates 2% Max HP every second for all allies within 3 tiles.",
				RequiredStar = 6,
				EffectType = "PassiveRegenAura",
			},
		},
		Color = Color3.fromRGB(240, 220, 80),
		AccentColor = Color3.fromRGB(255, 255, 220),
	},
}

local HeroData = {
	Heroes = Heroes,
	StarLevelCaps = STAR_LEVEL_CAPS,
}

function HeroData.Get(heroId: string): HeroDefinition?
	return Heroes[heroId]
end

function HeroData.GetLevelCap(star: number): number
	return STAR_LEVEL_CAPS[star] or 40
end

-- Level up stat scaling (uses Elixir + Gold)
function HeroData.GetStats(heroId: string, level: number, star: number)
	local def = Heroes[heroId]
	if not def then
		return nil
	end

	local cap = HeroData.GetLevelCap(star)
	level = math.clamp(level, 1, cap)

	-- Base star multiplier (e.g. 5★ starts higher than 3★)
	local starMultiplier = 1.0 + ((star - 3) * 0.25)

	-- Linear growth per level
	local levelGrowth = 1.0 + ((level - 1) * 0.055)
	local totalMult = starMultiplier * levelGrowth

	return {
		Hp = math.floor(def.BaseHp * totalMult + 0.5),
		MaxHp = math.floor(def.BaseHp * totalMult + 0.5),
		Atk = math.floor(def.BaseAtk * totalMult + 0.5),
		Def = math.floor(def.BaseDef * totalMult + 0.5),
		HealingPower = def.HealingPower and math.floor(def.HealingPower * totalMult + 0.5) or nil,
		Range = def.Range,
		AttackSpeed = def.AttackSpeed,
		BlockCount = def.BlockCount,
		Role = def.Role,
		PlacementType = def.PlacementType,
	}
end

-- Cost to level up from currentLevel to currentLevel + 1
function HeroData.GetLevelUpCost(currentLevel: number): { Gold: number, Elixir: number }
	local baseGold = 60
	local baseElixir = 40
	local goldCost = math.floor(baseGold * (1.08 ^ (currentLevel - 1)) + 0.5)
	local elixirCost = math.floor(baseElixir * (1.10 ^ (currentLevel - 1)) + 0.5)
	return { Gold = goldCost, Elixir = elixirCost }
end

return HeroData
