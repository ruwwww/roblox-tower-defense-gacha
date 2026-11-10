--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StageData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("StageData"))
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))

local IdleRewardService = {
	Remotes = {} :: { [string]: RemoteEvent },
}

type AfkRates = {
	GoldPerMin: number,
	ElixirPerMin: number,
	ExpPerMin: number,
}

local STARTER_AFK_RATES: AfkRates = {
	GoldPerMin = 25,
	ElixirPerMin = 15,
	ExpPerMin = 10,
}

local RNG = Random.new()

local function GetAfkRates(highestClearedStage: string): AfkRates
	if highestClearedStage == "1-0" then
		return STARTER_AFK_RATES
	end

	local stage = StageData.Get(highestClearedStage)
	if stage then
		return stage.AfkRates
	end

	return STARTER_AFK_RATES
end

local GEAR_DROPS_BY_CHAPTER: { [number]: { string } } = {
	[1] = { "iron_sword", "leather_tunic", "bronze_pendant", "leather_boots", "steel_saber", "chainmail_vest" },
}

function IdleRewardService.Init(remotes: { [string]: RemoteEvent })
	IdleRewardService.Remotes = remotes
end

function IdleRewardService.CalculatePendingRewards(player: Player)
	local prof = ProfileService.Get(player)
	if not prof then
		return nil
	end

	local now = os.time()
	local elapsedSec = math.clamp(now - prof.AfkLastClaimTime, 0, 43200) -- Max 12 hours
	local elapsedMins = elapsedSec / 60

	local rates = GetAfkRates(prof.HighestClearedStage)

	local goldEarned = math.floor(rates.GoldPerMin * elapsedMins)
	local elixirEarned = math.floor(rates.ElixirPerMin * elapsedMins)
	local expEarned = math.floor(rates.ExpPerMin * elapsedMins)

	-- Check for equipment drop chances (approx 1 drop chance per 15 minutes)
	local possibleDrops = math.floor(elapsedMins / 15)
	local droppedGearIds: { string } = {}
	local chapterGear = GEAR_DROPS_BY_CHAPTER[1] or {}

	for _ = 1, math.min(10, possibleDrops) do
		if RNG:NextNumber() <= 0.35 and #chapterGear > 0 then
			local picked = chapterGear[RNG:NextInteger(1, #chapterGear)]
			table.insert(droppedGearIds, picked)
		end
	end

	return {
		ElapsedSeconds = elapsedSec,
		Gold = goldEarned,
		Elixir = elixirEarned,
		Exp = expEarned,
		EquipmentIds = droppedGearIds,
	}
end

function IdleRewardService.ClaimAfkLoot(player: Player)
	local prof = ProfileService.Get(player)
	if not prof then
		return
	end

	local pending = IdleRewardService.CalculatePendingRewards(player)
	if not pending or pending.ElapsedSeconds < 10 then
		if IdleRewardService.Remotes.NotifyMessage then
			IdleRewardService.Remotes.NotifyMessage:FireClient(player, "Chest is gathering more loot! Check back soon.", Color3.fromRGB(255, 200, 60))
		end
		return
	end

	prof.Gold += pending.Gold
	prof.Elixir += pending.Elixir
	prof.AfkLastClaimTime = os.time()

	for _, gearId in ipairs(pending.EquipmentIds) do
		table.insert(prof.EquipmentInventory, {
			Uid = HttpService:GenerateGUID(false),
			EquipmentId = gearId,
			EnhanceLevel = 0,
		})
	end

	ProfileService.RecordDailyProgress(player, "claim_afk_1", 1)
	ProfileService.SyncProfile(player)

	if IdleRewardService.Remotes.NotifyMessage then
		IdleRewardService.Remotes.NotifyMessage:FireClient(
			player,
			string.format("Claimed AFK Loot: +%d Gold, +%d Elixir, %d Items!", pending.Gold, pending.Elixir, #pending.EquipmentIds),
			Color3.fromRGB(100, 255, 120)
		)
	end
end

function IdleRewardService.FastAfkClaim(player: Player)
	local prof = ProfileService.Get(player)
	if not prof then
		return
	end

	local rates = GetAfkRates(prof.HighestClearedStage)

	-- 120 Minutes instan!
	local goldBonus = math.floor(rates.GoldPerMin * 120)
	local elixirBonus = math.floor(rates.ElixirPerMin * 120)

	prof.Gold += goldBonus
	prof.Elixir += elixirBonus

	ProfileService.SyncProfile(player)

	if IdleRewardService.Remotes.NotifyMessage then
		IdleRewardService.Remotes.NotifyMessage:FireClient(
			player,
			string.format("⚡ FAST REWARDS (120 Mins): +%d Gold, +%d Elixir!", goldBonus, elixirBonus),
			Color3.fromRGB(255, 220, 60)
		)
	end
end

return IdleRewardService
