--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

export type HeroInstance = {
	Uid: string,
	HeroId: string,
	Level: number,
	Star: number,
	Equipment: {
		Weapon: string?,
		Armor: string?,
		Accessory: string?,
		Boots: string?,
	},
}

export type PlayerProfile = {
	Gold: number,
	Diamonds: number,
	Elixir: number,
	Scrolls: number,
	HighestClearedStage: string,
	CurrentStage: string,
	AfkLastClaimTime: number,
	Heroes: { [string]: HeroInstance },
	Formation: { string }, -- List of up to 6 Hero Uids
	EquipmentInventory: { { Uid: string, EquipmentId: string, EnhanceLevel: number } },
}

local ProfileService = {
	Profiles = {} :: { [Player]: PlayerProfile },
	Remotes = {} :: { [string]: RemoteEvent },
}

function ProfileService.Init(remotes: { [string]: RemoteEvent })
	ProfileService.Remotes = remotes

	Players.PlayerAdded:Connect(function(player)
		ProfileService.SetupPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ProfileService.Profiles[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		ProfileService.SetupPlayer(player)
	end
end

function ProfileService.SetupPlayer(player: Player)
	local u1 = HttpService:GenerateGUID(false)
	local u2 = HttpService:GenerateGUID(false)
	local u3 = HttpService:GenerateGUID(false)
	local u4 = HttpService:GenerateGUID(false)

	local profile: PlayerProfile = {
		Gold = 10000,
		Diamonds = 1200,
		Elixir = 5000,
		Scrolls = 10,
		HighestClearedStage = "1-0",
		CurrentStage = "1-1",
		AfkLastClaimTime = os.time(),
		Heroes = {
			[u1] = {
				Uid = u1,
				HeroId = "iron_garrison", -- 3★ Defender
				Level = 1,
				Star = 3,
				Equipment = {},
			},
			[u2] = {
				Uid = u2,
				HeroId = "hawk_archer", -- 3★ Sniper
				Level = 1,
				Star = 3,
				Equipment = {},
			},
			[u3] = {
				Uid = u3,
				HeroId = "verdant_cleric", -- 3★ Medic
				Level = 1,
				Star = 3,
				Equipment = {},
			},
			[u4] = {
				Uid = u4,
				HeroId = "crimson_duelist", -- 3★ Guard
				Level = 1,
				Star = 3,
				Equipment = {},
			},
		},
		Formation = { u1, u2, u3, u4 },
		EquipmentInventory = {
			{ Uid = HttpService:GenerateGUID(false), EquipmentId = "iron_sword", EnhanceLevel = 0 },
			{ Uid = HttpService:GenerateGUID(false), EquipmentId = "leather_tunic", EnhanceLevel = 0 },
			{ Uid = HttpService:GenerateGUID(false), EquipmentId = "leather_boots", EnhanceLevel = 0 },
		},
	}

	ProfileService.Profiles[player] = profile
	ProfileService.SyncProfile(player)
end

function ProfileService.Get(player: Player): PlayerProfile?
	return ProfileService.Profiles[player]
end

function ProfileService.SyncProfile(player: Player)
	local prof = ProfileService.Profiles[player]
	if not prof or not ProfileService.Remotes.StateSync then
		return
	end

	ProfileService.Remotes.StateSync:FireClient(player, {
		Gold = prof.Gold,
		Diamonds = prof.Diamonds,
		Elixir = prof.Elixir,
		Scrolls = prof.Scrolls,
		HighestClearedStage = prof.HighestClearedStage,
		CurrentStage = prof.CurrentStage,
		AfkLastClaimTime = prof.AfkLastClaimTime,
		Heroes = prof.Heroes,
		Formation = prof.Formation,
		EquipmentInventory = prof.EquipmentInventory,
	})
end

return ProfileService
