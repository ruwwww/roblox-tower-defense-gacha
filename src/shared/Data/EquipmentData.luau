--!strict

export type EquipmentSlot = "Weapon" | "Armor" | "Accessory" | "Boots"

export type EquipmentDefinition = {
	Id: string,
	Name: string,
	Slot: EquipmentSlot,
	Rarity: number, -- 1 to 5
	RarityName: string,
	Color: Color3,
	BaseStats: {
		Atk: number?,
		Hp: number?,
		Def: number?,
		EnergyRecharge: number?,
		AttackSpeedBonus: number?,
		DodgeRate: number?,
	},
}

local Equipments: { [string]: EquipmentDefinition } = {
	-- WEAPONS
	iron_sword = {
		Id = "iron_sword",
		Name = "Iron Broadsword",
		Slot = "Weapon",
		Rarity = 1,
		RarityName = "Common",
		Color = Color3.fromRGB(160, 165, 175),
		BaseStats = { Atk = 20 },
	},
	steel_saber = {
		Id = "steel_saber",
		Name = "Refined Steel Saber",
		Slot = "Weapon",
		Rarity = 2,
		RarityName = "Rare",
		Color = Color3.fromRGB(60, 180, 80),
		BaseStats = { Atk = 45 },
	},
	runic_blade = {
		Id = "runic_blade",
		Name = "Runic Longsword",
		Slot = "Weapon",
		Rarity = 3,
		RarityName = "Elite",
		Color = Color3.fromRGB(60, 130, 240),
		BaseStats = { Atk = 100 },
	},
	dragon_fang_spear = {
		Id = "dragon_fang_spear",
		Name = "Dragon Fang Spear",
		Slot = "Weapon",
		Rarity = 4,
		RarityName = "Epic",
		Color = Color3.fromRGB(170, 70, 230),
		BaseStats = { Atk = 240 },
	},
	excalibur_radiance = {
		Id = "excalibur_radiance",
		Name = "Excalibur of Radiance",
		Slot = "Weapon",
		Rarity = 5,
		RarityName = "Legendary",
		Color = Color3.fromRGB(255, 200, 30),
		BaseStats = { Atk = 550 },
	},

	-- ARMOR
	leather_tunic = {
		Id = "leather_tunic",
		Name = "Sturdy Leather Tunic",
		Slot = "Armor",
		Rarity = 1,
		RarityName = "Common",
		Color = Color3.fromRGB(160, 165, 175),
		BaseStats = { Hp = 150, Def = 12 },
	},
	chainmail_vest = {
		Id = "chainmail_vest",
		Name = "Reinforced Chainmail",
		Slot = "Armor",
		Rarity = 2,
		RarityName = "Rare",
		Color = Color3.fromRGB(60, 180, 80),
		BaseStats = { Hp = 350, Def = 30 },
	},
	knight_plate = {
		Id = "knight_plate",
		Name = "Silver Knight Plate",
		Slot = "Armor",
		Rarity = 3,
		RarityName = "Elite",
		Color = Color3.fromRGB(60, 130, 240),
		BaseStats = { Hp = 800, Def = 75 },
	},
	titan_carapace = {
		Id = "titan_carapace",
		Name = "Titan's Carapace",
		Slot = "Armor",
		Rarity = 4,
		RarityName = "Epic",
		Color = Color3.fromRGB(170, 70, 230),
		BaseStats = { Hp = 1800, Def = 160 },
	},
	aegis_divine_mail = {
		Id = "aegis_divine_mail",
		Name = "Divine Aegis Mail",
		Slot = "Armor",
		Rarity = 5,
		RarityName = "Legendary",
		Color = Color3.fromRGB(255, 200, 30),
		BaseStats = { Hp = 4200, Def = 350 },
	},

	-- ACCESSORIES
	bronze_pendant = {
		Id = "bronze_pendant",
		Name = "Bronze Talisman",
		Slot = "Accessory",
		Rarity = 1,
		RarityName = "Common",
		Color = Color3.fromRGB(160, 165, 175),
		BaseStats = { EnergyRecharge = 0.05 },
	},
	amethyst_amulet = {
		Id = "amethyst_amulet",
		Name = "Amethyst Ward Pendant",
		Slot = "Accessory",
		Rarity = 2,
		RarityName = "Rare",
		Color = Color3.fromRGB(60, 180, 80),
		BaseStats = { EnergyRecharge = 0.10 },
	},
	sapphire_ring = {
		Id = "sapphire_ring",
		Name = "Sapphire Mind Ring",
		Slot = "Accessory",
		Rarity = 3,
		RarityName = "Elite",
		Color = Color3.fromRGB(60, 130, 240),
		BaseStats = { EnergyRecharge = 0.16 },
	},
	celestial_locket = {
		Id = "celestial_locket",
		Name = "Celestial Locket",
		Slot = "Accessory",
		Rarity = 4,
		RarityName = "Epic",
		Color = Color3.fromRGB(170, 70, 230),
		BaseStats = { EnergyRecharge = 0.24 },
	},
	eye_of_eternity = {
		Id = "eye_of_eternity",
		Name = "Eye of Eternity",
		Slot = "Accessory",
		Rarity = 5,
		RarityName = "Legendary",
		Color = Color3.fromRGB(255, 200, 30),
		BaseStats = { EnergyRecharge = 0.35 },
	},

	-- BOOTS
	leather_boots = {
		Id = "leather_boots",
		Name = "Traveler's Boots",
		Slot = "Boots",
		Rarity = 1,
		RarityName = "Common",
		Color = Color3.fromRGB(160, 165, 175),
		BaseStats = { AttackSpeedBonus = 0.04, DodgeRate = 0.03 },
	},
	iron_greaves = {
		Id = "iron_greaves",
		Name = "Ironbound Greaves",
		Slot = "Boots",
		Rarity = 2,
		RarityName = "Rare",
		Color = Color3.fromRGB(60, 180, 80),
		BaseStats = { AttackSpeedBonus = 0.08, DodgeRate = 0.06 },
	},
	wind_treaders = {
		Id = "wind_treaders",
		Name = "Windrunner Sabatons",
		Slot = "Boots",
		Rarity = 3,
		RarityName = "Elite",
		Color = Color3.fromRGB(60, 130, 240),
		BaseStats = { AttackSpeedBonus = 0.14, DodgeRate = 0.10 },
	},
	shadow_striders = {
		Id = "shadow_striders",
		Name = "Shadowveil Striders",
		Slot = "Boots",
		Rarity = 4,
		RarityName = "Epic",
		Color = Color3.fromRGB(170, 70, 230),
		BaseStats = { AttackSpeedBonus = 0.20, DodgeRate = 0.15 },
	},
	hermes_winged_boots = {
		Id = "hermes_winged_boots",
		Name = "Hermes' Winged Soles",
		Slot = "Boots",
		Rarity = 5,
		RarityName = "Legendary",
		Color = Color3.fromRGB(255, 200, 30),
		BaseStats = { AttackSpeedBonus = 0.28, DodgeRate = 0.22 },
	},
}

local EquipmentData = {
	Equipments = Equipments,
}

function EquipmentData.Get(id: string): EquipmentDefinition?
	return Equipments[id]
end

function EquipmentData.GetEnhancedStats(id: string, enhanceLevel: number)
	local def = Equipments[id]
	if not def then
		return nil
	end

	enhanceLevel = math.clamp(enhanceLevel, 0, 10)
	local mult = 1.0 + (enhanceLevel * 0.10)

	local s = def.BaseStats
	return {
		Atk = s.Atk and math.floor(s.Atk * mult + 0.5) or 0,
		Hp = s.Hp and math.floor(s.Hp * mult + 0.5) or 0,
		Def = s.Def and math.floor(s.Def * mult + 0.5) or 0,
		EnergyRecharge = s.EnergyRecharge and (s.EnergyRecharge * mult) or 0,
		AttackSpeedBonus = s.AttackSpeedBonus and (s.AttackSpeedBonus * mult) or 0,
		DodgeRate = s.DodgeRate and (s.DodgeRate * mult) or 0,
	}
end

return EquipmentData
