--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("HeroData"))
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))

local HeroService = {
	Remotes = {} :: { [string]: RemoteEvent },
}

function HeroService.Init(remotes: { [string]: RemoteEvent })
	HeroService.Remotes = remotes
end

function HeroService.UpdateFormation(player: Player, heroUids: { string })
	local prof = ProfileService.Get(player)
	if not prof then
		return
	end

	local selectedUids: { string } = {}
	local seenUids: { [string]: boolean } = {}
	local entryCount = 0

	for index, heroUid in pairs(heroUids) do
		if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > 6 then
			return
		end
		if typeof(heroUid) ~= "string" or heroUid == "" or seenUids[heroUid] then
			return
		end
		if not prof.Heroes[heroUid] then
			return
		end

		seenUids[heroUid] = true
		entryCount += 1
	end

	if entryCount < 1 or entryCount > 6 then
		return
	end

	for index = 1, entryCount do
		local heroUid = heroUids[index]
		if not heroUid then
			return
		end
		selectedUids[index] = heroUid
	end

	prof.Formation = selectedUids
	ProfileService.SyncProfile(player)
end

function HeroService.LevelUpHero(player: Player, heroUid: string)
	local prof = ProfileService.Get(player)
	if not prof then
		return
	end

	local hero = prof.Heroes[heroUid]
	if not hero then
		return
	end

	local cap = HeroData.GetLevelCap(hero.Star)
	if hero.Level >= cap then
		if HeroService.Remotes.NotifyMessage then
			HeroService.Remotes.NotifyMessage:FireClient(
				player,
				string.format("Level Cap reached (Lv.%d)! Star-Up/Ascend hero to unlock higher levels!", cap),
				Color3.fromRGB(255, 180, 50)
			)
		end
		return
	end

	local cost = HeroData.GetLevelUpCost(hero.Level)
	if prof.Gold < cost.Gold or prof.Elixir < cost.Elixir then
		if HeroService.Remotes.NotifyMessage then
			HeroService.Remotes.NotifyMessage:FireClient(
				player,
				string.format("Not enough resources! Needed: %d Gold, %d Elixir", cost.Gold, cost.Elixir),
				Color3.fromRGB(255, 80, 80)
			)
		end
		return
	end

	prof.Gold -= cost.Gold
	prof.Elixir -= cost.Elixir
	hero.Level += 1

	ProfileService.SyncProfile(player)

	if HeroService.Remotes.NotifyMessage then
		HeroService.Remotes.NotifyMessage:FireClient(
			player,
			string.format("Level Up! Lv.%d reached!", hero.Level),
			Color3.fromRGB(100, 255, 120)
		)
	end
end

function HeroService.StarUpHero(player: Player, targetHeroUid: string, sacrificeUids: { string })
	local prof = ProfileService.Get(player)
	if not prof then
		return
	end

	local target = prof.Heroes[targetHeroUid]
	if not target then
		return
	end

	local currentStar = target.Star
	if currentStar >= 10 then
		return
	end

	-- Check Star-Up conditions
	local reqCount = 2
	if currentStar >= 5 then
		reqCount = 2
	end

	if #sacrificeUids < reqCount then
		if HeroService.Remotes.NotifyMessage then
			HeroService.Remotes.NotifyMessage:FireClient(player, "Not enough sacrifice heroes selected!", Color3.fromRGB(255, 80, 80))
		end
		return
	end

	-- Validate sacrifices exist and are not in active formation
	for _, sUid in ipairs(sacrificeUids) do
		if sUid == targetHeroUid then
			return
		end
		if not prof.Heroes[sUid] then
			return
		end
		if table.find(prof.Formation, sUid) then
			if HeroService.Remotes.NotifyMessage then
				HeroService.Remotes.NotifyMessage:FireClient(player, "Cannot sacrifice a hero currently in battle formation!", Color3.fromRGB(255, 80, 80))
			end
			return
		end
	end

	local starUpGoldCost = currentStar * 5000
	if prof.Gold < starUpGoldCost then
		if HeroService.Remotes.NotifyMessage then
			HeroService.Remotes.NotifyMessage:FireClient(player, "Not enough Gold for Star-Up Ascension!", Color3.fromRGB(255, 80, 80))
		end
		return
	end

	-- Consume fodder
	prof.Gold -= starUpGoldCost
	for _, sUid in ipairs(sacrificeUids) do
		prof.Heroes[sUid] = nil
	end

	target.Star += 1
	local newCap = HeroData.GetLevelCap(target.Star)

	ProfileService.SyncProfile(player)

	if HeroService.Remotes.NotifyMessage then
		HeroService.Remotes.NotifyMessage:FireClient(
			player,
			string.format("⭐ ASCENSION SUCCESS! %s is now %d★ (Level Cap: %d)!", target.HeroId, target.Star, newCap),
			Color3.fromRGB(255, 215, 60)
		)
	end
end

function HeroService.EquipGear(player: Player, heroUid: string, slot: string, equipmentUid: string)
	local prof = ProfileService.Get(player)
	if not prof then
		return
	end

	local hero = prof.Heroes[heroUid]
	if not hero then
		return
	end

	-- Find equipment in inventory
	local gearItem = nil
	for _, item in ipairs(prof.EquipmentInventory) do
		if item.Uid == equipmentUid then
			gearItem = item
			break
		end
	end

	if not gearItem then
		return
	end

	hero.Equipment[slot] = gearItem.EquipmentId
	ProfileService.SyncProfile(player)
end

function HeroService.UnequipGear(player: Player, heroUid: string, slot: string)
	local prof = ProfileService.Get(player)
	if not prof then
		return
	end

	local hero = prof.Heroes[heroUid]
	if not hero then
		return
	end

	hero.Equipment[slot] = nil
	ProfileService.SyncProfile(player)
end

return HeroService
