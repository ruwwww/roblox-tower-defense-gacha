--!strict
local Network = {
	Events = {
		ClientReady = "ClientReady",
		StateSync = "StateSync",
		NotifyMessage = "NotifyMessage",

		-- Gacha
		RollGacha = "RollGacha",
		GachaResult = "GachaResult",

		-- AFK Loot
		ClaimAfkLoot = "ClaimAfkLoot",
		FastAfkClaim = "FastAfkClaim",

		-- Hero & Equipment
		LevelUpHero = "LevelUpHero",
		StarUpHero = "StarUpHero",
		EquipGear = "EquipGear",
		UnequipGear = "UnequipGear",
		UpdateFormation = "UpdateFormation",

		-- Campaign & Battle
		StartBattle = "StartBattle",
		BattleFinished = "BattleFinished",

		-- World Interaction
		OpenLobbyModal = "OpenLobbyModal",
	}
}

return Network
