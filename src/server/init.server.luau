--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

-- 1. Create RemoteEvents container
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

-- 2. Setup 3D Town Hub in Workspace
local LobbyService = require(script:WaitForChild("Services"):WaitForChild("LobbyService"))
LobbyService.SetupLobby()

-- 3. Load & Initialize Game Services
local ProfileService = require(script:WaitForChild("Services"):WaitForChild("ProfileService"))
local IdleRewardService = require(script:WaitForChild("Services"):WaitForChild("IdleRewardService"))
local HeroService = require(script:WaitForChild("Services"):WaitForChild("HeroService"))
local SummonService = require(script:WaitForChild("Services"):WaitForChild("SummonService"))
local CampaignService = require(script:WaitForChild("Services"):WaitForChild("CampaignService"))

ProfileService.Init(remotes)
IdleRewardService.Init(remotes)
HeroService.Init(remotes)
SummonService.Init(remotes)
CampaignService.Init(remotes)

-- 4. Connect ClickDetectors on 3D Lobby Buildings
task.defer(function()
	local town = Workspace:WaitForChild("LobbyTown", 5)
	if not town then
		return
	end

	-- Chest Click -> Claim AFK Loot
	local chest = town:WaitForChild("AfkLootChest", 5) :: Part?
	if chest then
		local click = chest:FindFirstChildOfClass("ClickDetector")
		if click then
			click.MouseClick:Connect(function(player)
				IdleRewardService.ClaimAfkLoot(player)
			end)
		end
	end

	-- Altar / Gate Clicks -> Open UI on Client
	local buildingMap = {
		SummonAltar = "Gacha",
		CampaignGate = "Campaign",
		HeroAltar = "Backpack",
		BlacksmithForge = "Blacksmith",
		ArenaGate = "Arena",
	}

	for modelName, modalType in pairs(buildingMap) do
		local m = town:FindFirstChild(modelName)
		if m and m:IsA("Model") and m.PrimaryPart then
			local click = m.PrimaryPart:FindFirstChildOfClass("ClickDetector")
			if click then
				click.MouseClick:Connect(function(player)
					if remotes.OpenLobbyModal then
						remotes.OpenLobbyModal:FireClient(player, modalType)
					end
				end)
			end
		end
	end
end)

-- 5. Connect Inbound Client Remotes
remotes.ClientReady.OnServerEvent:Connect(function(player)
	ProfileService.SyncProfile(player)
end)

remotes.ClaimAfkLoot.OnServerEvent:Connect(function(player)
	IdleRewardService.ClaimAfkLoot(player)
end)

remotes.UpdateFormation.OnServerEvent:Connect(function(player: Player, heroUids: unknown)
	if typeof(heroUids) == "table" then
		HeroService.UpdateFormation(player, heroUids :: { string })
	end
end)

remotes.RollGacha.OnServerEvent:Connect(function(player: Player, rollCount: unknown, paymentMethod: unknown)
	if typeof(rollCount) == "number" and (paymentMethod == "Scrolls" or paymentMethod == "Diamonds") then
		SummonService.RollGacha(player, rollCount, paymentMethod)
	end
end)

remotes.FastAfkClaim.OnServerEvent:Connect(function(player)
	IdleRewardService.FastAfkClaim(player)
end)

remotes.LevelUpHero.OnServerEvent:Connect(function(player, heroUid: any)
	if typeof(heroUid) == "string" then
		HeroService.LevelUpHero(player, heroUid)
	end
end)

remotes.StarUpHero.OnServerEvent:Connect(function(player, targetUid: any, sacrificeUids: any)
	if typeof(targetUid) == "string" and typeof(sacrificeUids) == "table" then
		HeroService.StarUpHero(player, targetUid, sacrificeUids)
	end
end)

remotes.EquipGear.OnServerEvent:Connect(function(player, heroUid: any, slot: any, gearUid: any)
	if typeof(heroUid) == "string" and typeof(slot) == "string" and typeof(gearUid) == "string" then
		HeroService.EquipGear(player, heroUid, slot, gearUid)
	end
end)

remotes.UnequipGear.OnServerEvent:Connect(function(player, heroUid: any, slot: any)
	if typeof(heroUid) == "string" and typeof(slot) == "string" then
		HeroService.UnequipGear(player, heroUid, slot)
	end
end)

remotes.StartBattle.OnServerEvent:Connect(function(player, stageId: any, isSkip: any)
	if typeof(stageId) == "string" and typeof(isSkip) == "boolean" then
		CampaignService.StartBattle(player, stageId, isSkip)
	end
end)

print("[Server] Arknights x Idle RPG Hybrid Systems fully initialized.")
