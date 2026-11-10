--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UnitData = require(Shared:WaitForChild("Data"):WaitForChild("UnitData"))
local BannerData = require(Shared:WaitForChild("Data"):WaitForChild("BannerData"))

export type PlayerUnitInstance = {
	Uid: string,
	UnitId: string,
	ObtainedAt: number,
}

export type PlayerEconomyState = {
	Gold: number,
	Gems: number,
	PityEpic: number,
	PityLegendary: number,
	Inventory: { PlayerUnitInstance },
	Equipped: { string }, -- List of UnitIds equipped in hotbar (1-5)
}

local GachaService = {
	PlayerStates = {} :: { [Player]: PlayerEconomyState },
	Remotes = {} :: { [string]: RemoteEvent },
}

local RNG = Random.new()

function GachaService.Init(remotes: { [string]: RemoteEvent })
	GachaService.Remotes = remotes

	Players.PlayerAdded:Connect(function(player)
		GachaService.SetupPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		GachaService.PlayerStates[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		GachaService.SetupPlayer(player)
	end
end

function GachaService.SetupPlayer(player: Player)
	local state: PlayerEconomyState = {
		Gold = Config.StartingGold,
		Gems = Config.StartingGems,
		PityEpic = 0,
		PityLegendary = 0,
		Inventory = {},
		Equipped = { "archer", "rock_slinger" },
	}

	-- Add starter units
	local starter1: PlayerUnitInstance = {
		Uid = HttpService:GenerateGUID(false),
		UnitId = "archer",
		ObtainedAt = os.time(),
	}
	local starter2: PlayerUnitInstance = {
		Uid = HttpService:GenerateGUID(false),
		UnitId = "rock_slinger",
		ObtainedAt = os.time(),
	}
	table.insert(state.Inventory, starter1)
	table.insert(state.Inventory, starter2)

	GachaService.PlayerStates[player] = state
	GachaService.SyncState(player)
end

function GachaService.GetState(player: Player): PlayerEconomyState?
	return GachaService.PlayerStates[player]
end

function GachaService.AddGold(player: Player, amount: number)
	local state = GachaService.PlayerStates[player]
	if state then
		state.Gold = math.max(0, state.Gold + amount)
		GachaService.SyncState(player)
	end
end

function GachaService.AddGems(player: Player, amount: number)
	local state = GachaService.PlayerStates[player]
	if state then
		state.Gems = math.max(0, state.Gems + amount)
		GachaService.SyncState(player)
	end
end

function GachaService.SpendGold(player: Player, amount: number): boolean
	local state = GachaService.PlayerStates[player]
	if not state or state.Gold < amount then
		return false
	end
	state.Gold -= amount
	GachaService.SyncState(player)
	return true
end

function GachaService.RollGacha(player: Player, bannerId: string, isMulti: boolean)
	local state = GachaService.PlayerStates[player]
	if not state then
		return
	end

	local banner = BannerData.Get(bannerId)
	if not banner then
		return
	end

	local pullCount = isMulti and 10 or 1
	local totalCost = isMulti and Config.MultiPullCost or Config.SinglePullCost

	if state.Gems < totalCost then
		if GachaService.Remotes.NotifyMessage then
			GachaService.Remotes.NotifyMessage:FireClient(player, "Not enough Gems! Needed: " .. tostring(totalCost), Color3.fromRGB(255, 80, 80))
		end
		return
	end

	state.Gems -= totalCost
	local rolledUnits = {}

	for _ = 1, pullCount do
		state.PityEpic += 1
		state.PityLegendary += 1

		local rolledRarity: number = 3

		-- Check Pity thresholds
		if state.PityLegendary >= banner.PityLegendaryThreshold then
			rolledRarity = 6
			state.PityLegendary = 0
			state.PityEpic = 0
		elseif state.PityEpic >= banner.PityEpicThreshold then
			-- Guaranteed at least 5★, small chance for 6★
			local roll = RNG:NextNumber()
			if roll <= (banner.Rates[6] / (banner.Rates[5] + banner.Rates[6])) then
				rolledRarity = 6
				state.PityLegendary = 0
				state.PityEpic = 0
			else
				rolledRarity = 5
				state.PityEpic = 0
			end
		else
			-- Standard roll
			local roll = RNG:NextNumber()
			if roll <= banner.Rates[6] then
				rolledRarity = 6
				state.PityLegendary = 0
				state.PityEpic = 0
			elseif roll <= (banner.Rates[6] + banner.Rates[5]) then
				rolledRarity = 5
				state.PityEpic = 0
			elseif roll <= (banner.Rates[6] + banner.Rates[5] + banner.Rates[4]) then
				rolledRarity = 4
			else
				rolledRarity = 3
			end
		end

		-- Pick unit from pool
		local pool = BannerData.RarityUnits[rolledRarity] or BannerData.RarityUnits[3]
		local pickedUnitId = pool[RNG:NextInteger(1, #pool)]
		local unitDef = UnitData.Get(pickedUnitId)

		local newUnitInstance: PlayerUnitInstance = {
			Uid = HttpService:GenerateGUID(false),
			UnitId = pickedUnitId,
			ObtainedAt = os.time(),
		}

		table.insert(state.Inventory, newUnitInstance)
		table.insert(rolledUnits, {
			UnitId = pickedUnitId,
			Rarity = rolledRarity,
			Name = unitDef and unitDef.Name or pickedUnitId,
			Color = unitDef and unitDef.Color or Color3.new(1, 1, 1),
		})

		-- Auto equip into empty slot if available
		if #state.Equipped < Config.MaxEquippedUnits and not table.find(state.Equipped, pickedUnitId) then
			table.insert(state.Equipped, pickedUnitId)
		end
	end

	if GachaService.Remotes.GachaResult then
		GachaService.Remotes.GachaResult:FireClient(player, rolledUnits)
	end

	GachaService.SyncState(player)
end

function GachaService.EquipUnit(player: Player, unitId: string, slotIndex: number)
	local state = GachaService.PlayerStates[player]
	if not state then
		return
	end

	if not UnitData.Get(unitId) then
		return
	end

	-- Check ownership
	local owns = false
	for _, inst in ipairs(state.Inventory) do
		if inst.UnitId == unitId then
			owns = true
			break
		end
	end

	if not owns then
		return
	end

	slotIndex = math.clamp(slotIndex, 1, Config.MaxEquippedUnits)

	-- Remove from existing slot if present
	local existingIndex = table.find(state.Equipped, unitId)
	if existingIndex then
		table.remove(state.Equipped, existingIndex)
	end

	if slotIndex > #state.Equipped + 1 then
		slotIndex = #state.Equipped + 1
	end

	table.insert(state.Equipped, slotIndex, unitId)

	-- Trim overflow
	while #state.Equipped > Config.MaxEquippedUnits do
		table.remove(state.Equipped)
	end

	GachaService.SyncState(player)
end

function GachaService.SyncState(player: Player)
	local state = GachaService.PlayerStates[player]
	if not state or not GachaService.Remotes.StateSync then
		return
	end

	GachaService.Remotes.StateSync:FireClient(player, {
		Gold = state.Gold,
		Gems = state.Gems,
		PityEpic = state.PityEpic,
		PityLegendary = state.PityLegendary,
		Inventory = state.Inventory,
		Equipped = state.Equipped,
	})
end

return GachaService
