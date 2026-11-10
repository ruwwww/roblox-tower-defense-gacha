--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local MapService = require(script:WaitForChild("Services"):WaitForChild("MapService"))
local GachaService = require(script:WaitForChild("Services"):WaitForChild("GachaService"))
local WaveService = require(script:WaitForChild("Services"):WaitForChild("WaveService"))
local CombatService = require(script:WaitForChild("Services"):WaitForChild("CombatService"))

-- Create RemoteEvents container
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local remotes: { [string]: RemoteEvent } = {}
for _, eventName in pairs(Network.Events) do
	local existing = remotesFolder:FindFirstChild(eventName)
	if not existing then
		local ev = Instance.new("RemoteEvent")
		ev.Name = eventName
		ev.Parent = remotesFolder
		remotes[eventName] = ev
	else
		remotes[eventName] = existing :: RemoteEvent
	end
end

-- Initialize Services
MapService.SetupMap()
GachaService.Init(remotes)
WaveService.Init(remotes)
CombatService.Init(remotes)

-- Connect Inbound Client Remotes
remotes.ClientReady.OnServerEvent:Connect(function(player)
	GachaService.SyncState(player)
	WaveService.BroadcastWaveState()
end)

remotes.PlaceTower.OnServerEvent:Connect(function(player, unitId: any, position: any)
	if typeof(unitId) == "string" and typeof(position) == "Vector3" then
		CombatService.PlaceTower(player, unitId, position)
	end
end)

remotes.UpgradeTower.OnServerEvent:Connect(function(player, towerId: any)
	if typeof(towerId) == "string" then
		CombatService.UpgradeTower(player, towerId)
	end
end)

remotes.SellTower.OnServerEvent:Connect(function(player, towerId: any)
	if typeof(towerId) == "string" then
		CombatService.SellTower(player, towerId)
	end
end)

remotes.SetTargetMode.OnServerEvent:Connect(function(player, towerId: any, mode: any)
	if typeof(towerId) == "string" and typeof(mode) == "string" then
		CombatService.SetTargetMode(player, towerId, mode)
	end
end)

remotes.RollGacha.OnServerEvent:Connect(function(player, bannerId: any, isMulti: any)
	if typeof(bannerId) == "string" and typeof(isMulti) == "boolean" then
		GachaService.RollGacha(player, bannerId, isMulti)
	end
end)

remotes.EquipUnit.OnServerEvent:Connect(function(player, unitId: any, slotIndex: any)
	if typeof(unitId) == "string" and typeof(slotIndex) == "number" then
		GachaService.EquipUnit(player, unitId, slotIndex)
	end
end)

remotes.StartWaveVote.OnServerEvent:Connect(function(_player)
	WaveService.StartNextWave()
end)

print("[Server] Tower Defense x Gacha Systems fully initialized.")
