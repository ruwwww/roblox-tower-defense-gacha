--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroData = require(Shared:WaitForChild("Data"):WaitForChild("HeroData"))
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))

type HeroDefinition = HeroData.HeroDefinition
type SummonType = "Basic" | "Elite"
type PaymentMethod = "Scrolls" | "Diamonds" | "Free"

export type SummonResult = {
	Uid: string,
	HeroId: string,
	Name: string,
	Star: number,
	Role: HeroData.HeroRole,
}

local BASIC_RATES = {
	{ Star = 4, Rate = 0.03 },
	{ Star = 3, Rate = 0.12 },
	{ Star = 2, Rate = 0.35 },
	{ Star = 1, Rate = 0.50 },
}

local ELITE_RATES = {
	{ Star = 5, Rate = 0.05 },
	{ Star = 4, Rate = 0.25 },
	{ Star = 3, Rate = 0.70 },
}

local BASIC_DIAMOND_COSTS: { [number]: number } = {
	[1] = 50,
	[10] = 450,
}

local ELITE_DIAMOND_COSTS: { [number]: number } = {
	[1] = 220,
	[10] = 2000,
}

local REQUEST_COOLDOWN = 0.3
local RNG = Random.new()

local HeroPools: { [number]: { HeroDefinition } } = {}
for _, heroDefinition in pairs(HeroData.Heroes) do
	local pool = HeroPools[heroDefinition.BaseStar]
	if not pool then
		pool = {}
		HeroPools[heroDefinition.BaseStar] = pool
	end
	table.insert(pool, heroDefinition)
end

for _, pool in pairs(HeroPools) do
	table.sort(pool, function(a: HeroDefinition, b: HeroDefinition): boolean
		return a.Id < b.Id
	end)
end

local SummonService = {
	Remotes = {} :: { [string]: RemoteEvent },
	LastRequestAt = {} :: { [Player]: number },
}

local function GetPoolForStar(star: number): { HeroDefinition }?
	local pool = HeroPools[star]
	if pool and #pool > 0 then
		return pool
	end

	-- Fallback to closest available star
	for s = star - 1, 1, -1 do
		if HeroPools[s] and #HeroPools[s] > 0 then
			return HeroPools[s]
		end
	end
	for s = star + 1, 5 do
		if HeroPools[s] and #HeroPools[s] > 0 then
			return HeroPools[s]
		end
	end
	return nil
end

local function RollStar(summonType: SummonType): number
	local rates = (summonType == "Elite") and ELITE_RATES or BASIC_RATES
	local roll = RNG:NextNumber()
	local cumulativeRate = 0

	for _, entry in ipairs(rates) do
		cumulativeRate += entry.Rate
		if roll < cumulativeRate then
			return entry.Star
		end
	end

	return (summonType == "Elite") and 3 or 1
end

local function Notify(player: Player, message: string, color: Color3)
	local notifyRemote = SummonService.Remotes.NotifyMessage
	if notifyRemote then
		notifyRemote:FireClient(player, message, color)
	end
end

function SummonService.Init(remotes: { [string]: RemoteEvent })
	SummonService.Remotes = remotes

	Players.PlayerRemoving:Connect(function(player: Player)
		SummonService.LastRequestAt[player] = nil
	end)
end

function SummonService.IsDailyFreeAvailable(profile: ProfileService.PlayerProfile): boolean
	if profile.LastFreeBasicSummon == 0 then
		return true
	end
	-- 24 hours cooldown or calendar day reset
	return (os.time() - profile.LastFreeBasicSummon) >= 86400
end

function SummonService.RollGacha(player: Player, rollCount: number, summonType: SummonType, preferredPayment: string?)
	if rollCount ~= 1 and rollCount ~= 10 then
		return
	end
	if summonType ~= "Basic" and summonType ~= "Elite" then
		summonType = "Basic"
	end

	local now = os.clock()
	local lastRequestAt = SummonService.LastRequestAt[player]
	if lastRequestAt and now - lastRequestAt < REQUEST_COOLDOWN then
		return
	end
	SummonService.LastRequestAt[player] = now

	local profile = ProfileService.Get(player)
	if not profile then
		return
	end

	-- Check 1x Free Basic Summon
	local isFreeSummon = false
	if summonType == "Basic" and rollCount == 1 and SummonService.IsDailyFreeAvailable(profile) then
		isFreeSummon = true
	end

	if not isFreeSummon then
		if summonType == "Basic" then
			if profile.BasicScrolls >= rollCount then
				profile.BasicScrolls -= rollCount
			else
				local cost = BASIC_DIAMOND_COSTS[rollCount] or 50
				if profile.Diamonds < cost then
					Notify(player, string.format("Not enough Basic Scrolls or Diamonds! Need %d 💎", cost), Color3.fromRGB(255, 80, 80))
					return
				end
				profile.Diamonds -= cost
			end
		else
			-- Elite Summon
			if profile.EliteScrolls >= rollCount then
				profile.EliteScrolls -= rollCount
			else
				local cost = ELITE_DIAMOND_COSTS[rollCount] or 220
				if profile.Diamonds < cost then
					Notify(player, string.format("Not enough Elite Scrolls or Diamonds! Need %d 💎", cost), Color3.fromRGB(255, 80, 80))
					return
				end
				profile.Diamonds -= cost
			end
		end
	else
		profile.LastFreeBasicSummon = os.time()
	end

	-- Execute Rolls
	local results: { SummonResult } = {}
	for _ = 1, rollCount do
		local rolledStar = RollStar(summonType)
		local pool = GetPoolForStar(rolledStar)
		if not pool or #pool == 0 then
			continue
		end

		local chosenHero = pool[RNG:NextInteger(1, #pool)]
		local heroUid = HttpService:GenerateGUID(false)

		profile.Heroes[heroUid] = {
			Uid = heroUid,
			HeroId = chosenHero.Id,
			Level = 1,
			Star = rolledStar,
			Equipment = {},
		}

		table.insert(results, {
			Uid = heroUid,
			HeroId = chosenHero.Id,
			Name = chosenHero.Name,
			Star = rolledStar,
			Role = chosenHero.Role,
		})
	end

	-- Record daily progress
	ProfileService.RecordDailyProgress(player, "summon_1", rollCount)
	ProfileService.SyncProfile(player)

	local gachaRemote = SummonService.Remotes.GachaResult
	if gachaRemote then
		gachaRemote:FireClient(player, results)
	end
end

return SummonService
