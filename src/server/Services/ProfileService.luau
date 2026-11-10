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

export type MailItem = {
	Id: string,
	Title: string,
	Content: string,
	Sender: string,
	Items: {
		Gold: number?,
		Diamonds: number?,
		Elixir: number?,
		BasicScrolls: number?,
		EliteScrolls: number?,
		EquipmentId: string?,
		HeroId: string?,
	}?,
	Claimed: boolean,
	CreatedAt: number,
}

export type DailyMissionsData = {
	LastResetDate: string,
	Points: number,
	ClaimedChests: { [number]: boolean },
	Progress: { [string]: number },
	ClaimedMissions: { [string]: boolean },
}

export type PlayerProfile = {
	Gold: number,
	Diamonds: number,
	Elixir: number,
	BasicScrolls: number,
	EliteScrolls: number,
	LastFreeBasicSummon: number,
	HighestClearedStage: string,
	CurrentStage: string,
	AfkLastClaimTime: number,
	Heroes: { [string]: HeroInstance },
	Formation: { string }, -- List of up to 6 Hero Uids
	EquipmentInventory: { { Uid: string, EquipmentId: string, EnhanceLevel: number } },
	Mailbox: { [string]: MailItem },
	DailyMissions: DailyMissionsData,
	StarterPackPurchased: boolean,
}

local ProfileService = {
	Profiles = {} :: { [Player]: PlayerProfile },
	Remotes = {} :: { [string]: RemoteEvent },
}

local function GetCurrentDateString(): string
	local d = os.date("!*t")
	return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

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

function ProfileService.CheckDailyMissionReset(profile: PlayerProfile)
	local today = GetCurrentDateString()
	if profile.DailyMissions.LastResetDate ~= today then
		profile.DailyMissions.LastResetDate = today
		profile.DailyMissions.Points = 0
		profile.DailyMissions.ClaimedChests = {}
		profile.DailyMissions.Progress = {
			battle_3 = 0,
			summon_1 = 0,
			claim_afk_1 = 0,
			upgrade_hero_1 = 0,
			equip_gear_1 = 0,
		}
		profile.DailyMissions.ClaimedMissions = {}
	end
end

function ProfileService.SetupPlayer(player: Player)
	local u1 = HttpService:GenerateGUID(false)
	local u2 = HttpService:GenerateGUID(false)
	local u3 = HttpService:GenerateGUID(false)
	local u4 = HttpService:GenerateGUID(false)

	local welcomeMailId = HttpService:GenerateGUID(false)
	local welcomeMail: MailItem = {
		Id = welcomeMailId,
		Title = "Welcome to Arknights x Idle RPG!",
		Content = "Commander, welcome to your outpost! Here is your official deployment package with scrolls and resources.",
		Sender = "Headquarters",
		Items = {
			Gold = 5000,
			Diamonds = 500,
			Elixir = 2000,
			BasicScrolls = 5,
			EliteScrolls = 2,
		},
		Claimed = false,
		CreatedAt = os.time(),
	}

	local profile: PlayerProfile = {
		Gold = 10000,
		Diamonds = 1200,
		Elixir = 5000,
		BasicScrolls = 10,
		EliteScrolls = 3,
		LastFreeBasicSummon = 0, -- Immediately available for 1x Free Daily Summon!
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
		Mailbox = {
			[welcomeMailId] = welcomeMail,
		},
		DailyMissions = {
			LastResetDate = GetCurrentDateString(),
			Points = 0,
			ClaimedChests = {},
			Progress = {
				battle_3 = 0,
				summon_1 = 0,
				claim_afk_1 = 0,
				upgrade_hero_1 = 0,
				equip_gear_1 = 0,
			},
			ClaimedMissions = {},
		},
		StarterPackPurchased = false,
	}

	ProfileService.Profiles[player] = profile
	ProfileService.SyncProfile(player)
end

function ProfileService.Get(player: Player): PlayerProfile?
	local prof = ProfileService.Profiles[player]
	if prof then
		ProfileService.CheckDailyMissionReset(prof)
	end
	return prof
end

function ProfileService.AddMail(player: Player, mail: MailItem)
	local prof = ProfileService.Get(player)
	if not prof then return end
	prof.Mailbox[mail.Id] = mail
	ProfileService.SyncProfile(player)
	if ProfileService.Remotes.NotifyMessage then
		ProfileService.Remotes.NotifyMessage:FireClient(player, "📬 New Mail received in your Mailbox!", Color3.fromRGB(100, 220, 255))
	end
end

function ProfileService.ClaimMail(player: Player, mailId: string)
	local prof = ProfileService.Get(player)
	if not prof then return end
	local mail = prof.Mailbox[mailId]
	if not mail or mail.Claimed then return end

	mail.Claimed = true
	local items = mail.Items
	if items then
		if items.Gold then prof.Gold += items.Gold end
		if items.Diamonds then prof.Diamonds += items.Diamonds end
		if items.Elixir then prof.Elixir += items.Elixir end
		if items.BasicScrolls then prof.BasicScrolls += items.BasicScrolls end
		if items.EliteScrolls then prof.EliteScrolls += items.EliteScrolls end
		if items.EquipmentId then
			table.insert(prof.EquipmentInventory, {
				Uid = HttpService:GenerateGUID(false),
				EquipmentId = items.EquipmentId,
				EnhanceLevel = 0,
			})
		end
		if items.HeroId then
			local newUid = HttpService:GenerateGUID(false)
			prof.Heroes[newUid] = {
				Uid = newUid,
				HeroId = items.HeroId,
				Level = 1,
				Star = 5,
				Equipment = {},
			}
		end
	end

	ProfileService.SyncProfile(player)
	if ProfileService.Remotes.NotifyMessage then
		ProfileService.Remotes.NotifyMessage:FireClient(player, "🎁 Mail rewards claimed successfully!", Color3.fromRGB(100, 255, 120))
	end
end

function ProfileService.ClaimAllMails(player: Player)
	local prof = ProfileService.Get(player)
	if not prof then return end

	local claimedCount = 0
	for _, mail in pairs(prof.Mailbox) do
		if not mail.Claimed then
			mail.Claimed = true
			claimedCount += 1
			local items = mail.Items
			if items then
				if items.Gold then prof.Gold += items.Gold end
				if items.Diamonds then prof.Diamonds += items.Diamonds end
				if items.Elixir then prof.Elixir += items.Elixir end
				if items.BasicScrolls then prof.BasicScrolls += items.BasicScrolls end
				if items.EliteScrolls then prof.EliteScrolls += items.EliteScrolls end
				if items.EquipmentId then
					table.insert(prof.EquipmentInventory, {
						Uid = HttpService:GenerateGUID(false),
						EquipmentId = items.EquipmentId,
						EnhanceLevel = 0,
					})
				end
				if items.HeroId then
					local newUid = HttpService:GenerateGUID(false)
					prof.Heroes[newUid] = {
						Uid = newUid,
						HeroId = items.HeroId,
						Level = 1,
						Star = 5,
						Equipment = {},
					}
				end
			end
		end
	end

	if claimedCount > 0 then
		ProfileService.SyncProfile(player)
		if ProfileService.Remotes.NotifyMessage then
			ProfileService.Remotes.NotifyMessage:FireClient(player, string.format("🎁 Claimed rewards from %d mails!", claimedCount), Color3.fromRGB(100, 255, 120))
		end
	end
end

function ProfileService.RecordDailyProgress(player: Player, missionKey: string, amount: number)
	local prof = ProfileService.Get(player)
	if not prof then return end
	local cur = prof.DailyMissions.Progress[missionKey] or 0
	prof.DailyMissions.Progress[missionKey] = cur + (amount or 1)
	ProfileService.SyncProfile(player)
end

function ProfileService.ClaimDailyMission(player: Player, missionId: string)
	local prof = ProfileService.Get(player)
	if not prof then return end
	if prof.DailyMissions.ClaimedMissions[missionId] then return end

	local MISSION_DEFS: { [string]: { Req: number, Pts: number, Gold: number, Diamonds: number } } = {
		battle_3 = { Req = 3, Pts = 30, Gold = 1500, Diamonds = 50 },
		summon_1 = { Req = 1, Pts = 25, Gold = 1000, Diamonds = 30 },
		claim_afk_1 = { Req = 1, Pts = 20, Gold = 1000, Diamonds = 20 },
		upgrade_hero_1 = { Req = 1, Pts = 15, Gold = 800, Diamonds = 20 },
		equip_gear_1 = { Req = 1, Pts = 10, Gold = 500, Diamonds = 10 },
	}

	local def = MISSION_DEFS[missionId]
	if not def then return end

	local prog = prof.DailyMissions.Progress[missionId] or 0
	if prog < def.Req then
		if ProfileService.Remotes.NotifyMessage then
			ProfileService.Remotes.NotifyMessage:FireClient(player, "Mission not completed yet!", Color3.fromRGB(255, 100, 100))
		end
		return
	end

	prof.DailyMissions.ClaimedMissions[missionId] = true
	prof.DailyMissions.Points += def.Pts
	prof.Gold += def.Gold
	prof.Diamonds += def.Diamonds

	ProfileService.SyncProfile(player)
	if ProfileService.Remotes.NotifyMessage then
		ProfileService.Remotes.NotifyMessage:FireClient(player, string.format("Mission completed! +%d Points, +%d 💎", def.Pts, def.Diamonds), Color3.fromRGB(100, 255, 120))
	end
end

function ProfileService.ClaimDailyChest(player: Player, tier: number)
	local prof = ProfileService.Get(player)
	if not prof then return end
	if prof.DailyMissions.ClaimedChests[tier] then return end

	if prof.DailyMissions.Points < tier then
		if ProfileService.Remotes.NotifyMessage then
			ProfileService.Remotes.NotifyMessage:FireClient(player, string.format("You need %d Points to unlock this chest!", tier), Color3.fromRGB(255, 100, 100))
		end
		return
	end

	prof.DailyMissions.ClaimedChests[tier] = true

	if tier == 20 then
		prof.Gold += 2000
		prof.Diamonds += 50
	elseif tier == 40 then
		prof.Elixir += 1500
		prof.BasicScrolls += 1
	elseif tier == 60 then
		prof.Diamonds += 100
		prof.BasicScrolls += 2
	elseif tier == 80 then
		prof.Elixir += 3000
		prof.EliteScrolls += 1
	elseif tier == 100 then
		prof.Diamonds += 250
		prof.EliteScrolls += 2
	end

	ProfileService.SyncProfile(player)
	if ProfileService.Remotes.NotifyMessage then
		ProfileService.Remotes.NotifyMessage:FireClient(player, string.format("Daily Chest (%d pts) claimed!", tier), Color3.fromRGB(255, 220, 80))
	end
end

function ProfileService.PurchaseStarterPack(player: Player)
	local prof = ProfileService.Get(player)
	if not prof then return end
	if prof.StarterPackPurchased then
		if ProfileService.Remotes.NotifyMessage then
			ProfileService.Remotes.NotifyMessage:FireClient(player, "Novice Headstart Bundle already purchased!", Color3.fromRGB(255, 120, 120))
		end
		return
	end

	prof.StarterPackPurchased = true
	prof.Gold += 50000
	prof.Elixir += 20000
	prof.EliteScrolls += 10

	-- Award 5★ Hero Brunhilda Shieldmaiden
	local heroUid = HttpService:GenerateGUID(false)
	prof.Heroes[heroUid] = {
		Uid = heroUid,
		HeroId = "valkyrie_aegis",
		Level = 1,
		Star = 5,
		Equipment = {},
	}

	ProfileService.SyncProfile(player)
	if ProfileService.Remotes.NotifyMessage then
		ProfileService.Remotes.NotifyMessage:FireClient(player, "🎉 Congratulations! Novice Headstart Bundle unlocked: 5★ Brunhilda + 10x Elite Scrolls!", Color3.fromRGB(255, 215, 60))
	end
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
		BasicScrolls = prof.BasicScrolls,
		EliteScrolls = prof.EliteScrolls,
		Scrolls = prof.BasicScrolls, -- Backward compatibility
		LastFreeBasicSummon = prof.LastFreeBasicSummon,
		HighestClearedStage = prof.HighestClearedStage,
		CurrentStage = prof.CurrentStage,
		AfkLastClaimTime = prof.AfkLastClaimTime,
		Heroes = prof.Heroes,
		Formation = prof.Formation,
		EquipmentInventory = prof.EquipmentInventory,
		Mailbox = prof.Mailbox,
		DailyMissions = prof.DailyMissions,
		StarterPackPurchased = prof.StarterPackPurchased,
	})
end

return ProfileService
