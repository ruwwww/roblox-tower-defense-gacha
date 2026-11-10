--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroData = require(Shared:WaitForChild("Data"):WaitForChild("HeroData"))
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))

type HeroDefinition = HeroData.HeroDefinition
type PaymentMethod = "Scrolls" | "Diamonds"
type RarityRate = {
	Star: number,
	Rate: number,
}

export type SummonResult = {
	Uid: string,
	HeroId: string,
	Name: string,
	Star: number,
	Role: HeroData.HeroRole,
}

local RARITY_RATES: { RarityRate } = {
	{ Star = 5, Rate = 0.04 },
	{ Star = 4, Rate = 0.20 },
	{ Star = 3, Rate = 0.76 },
}

local DIAMOND_COSTS: { [number]: number } = {
	[1] = 200,
	[10] = 1800,
}

local REQUEST_COOLDOWN = 0.5
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
	local exactPool = HeroPools[star]
	if exactPool and #exactPool > 0 then
		return exactPool
	end

	-- If a rarity has no exact HeroData tier, use the nearest lower base tier
	-- and award the instance at the rolled star. HeroData currently has no 4★ tier.
	local nearestLowerStar = -math.huge
	local nearestLowerPool: { HeroDefinition }? = nil
	for baseStar, pool in pairs(HeroPools) do
		if baseStar < star and baseStar > nearestLowerStar and #pool > 0 then
			nearestLowerStar = baseStar
			nearestLowerPool = pool
		end
	end

	return nearestLowerPool
end

local function RollStar(): number
	local roll = RNG:NextNumber()
	local cumulativeRate = 0

	for _, entry in ipairs(RARITY_RATES) do
		cumulativeRate += entry.Rate
		if roll < cumulativeRate then
			return entry.Star
		end
	end

	return 3
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

function SummonService.RollGacha(player: Player, rollCount: number, paymentMethod: PaymentMethod)
	if rollCount ~= 1 and rollCount ~= 10 then
		return
	end
	if paymentMethod ~= "Scrolls" and paymentMethod ~= "Diamonds" then
		return
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

	local diamondCost = DIAMOND_COSTS[rollCount]
	if not diamondCost then
		return
	end

	if paymentMethod == "Scrolls" then
		if profile.Scrolls < rollCount then
			Notify(player, "Not enough Summon Scrolls.", Color3.fromRGB(255, 80, 80))
			return
		end
	else
		if profile.Diamonds < diamondCost then
			Notify(player, "Not enough Diamonds.", Color3.fromRGB(255, 80, 80))
			return
		end
	end

	for _, entry in ipairs(RARITY_RATES) do
		if not GetPoolForStar(entry.Star) then
			warn(string.format("[SummonService] No hero pool available for %d★ summons.", entry.Star))
			Notify(player, "Summoning is temporarily unavailable.", Color3.fromRGB(255, 80, 80))
			return
		end
	end

	-- Charge once before rolling; this handler does not yield between validation and debit.
	if paymentMethod == "Scrolls" then
		profile.Scrolls -= rollCount
	else
		profile.Diamonds -= diamondCost
	end

	local results: { SummonResult } = {}
	for _ = 1, rollCount do
		local star = RollStar()
		local pool = GetPoolForStar(star)
		if not pool then
			-- Catalogs are validated above, so this is only a defensive guard.
			warn(string.format("[SummonService] Hero pool disappeared for %d★ roll.", star))
			continue
		end

		local heroDefinition = pool[RNG:NextInteger(1, #pool)]
		local heroUid = HttpService:GenerateGUID(false)
		profile.Heroes[heroUid] = {
			Uid = heroUid,
			HeroId = heroDefinition.Id,
			Level = 1,
			Star = star,
			Equipment = {},
		}

		table.insert(results, {
			Uid = heroUid,
			HeroId = heroDefinition.Id,
			Name = heroDefinition.Name,
			Star = star,
			Role = heroDefinition.Role,
		})
	end

	ProfileService.SyncProfile(player)
	local resultRemote = SummonService.Remotes.GachaResult
	if resultRemote then
		resultRemote:FireClient(player, results)
	end
end

return SummonService
