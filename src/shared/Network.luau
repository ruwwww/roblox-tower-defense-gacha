--!strict
local Network = {
	Events = {
		ClientReady = "ClientReady",
		StateSync = "StateSync",
		NotifyMessage = "NotifyMessage",

		-- Gacha / Summon
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

		-- Mailbox
		ClaimMail = "ClaimMail",
		ClaimAllMails = "ClaimAllMails",

		-- Daily Missions
		ClaimDailyMission = "ClaimDailyMission",
		ClaimDailyChest = "ClaimDailyChest",

		-- Events & Monetization
		PurchaseStarterPack = "PurchaseStarterPack",
		PurchaseEventOffer = "PurchaseEventOffer",

		-- World Interaction
		OpenLobbyModal = "OpenLobbyModal",
	}
}

return Network
