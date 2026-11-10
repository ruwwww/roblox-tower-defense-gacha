--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 15)
if not RemotesFolder then
	warn("[Client] Could not locate Remotes folder in ReplicatedStorage!")
	return
end

local remotes: { [string]: RemoteEvent } = {}
for _, child in ipairs(RemotesFolder:GetChildren()) do
	if child:IsA("RemoteEvent") then
		remotes[child.Name] = child
	end
end

local UIController = require(script:WaitForChild("Controllers"):WaitForChild("UIController"))

-- Initialize UIController
UIController.Init(remotes)

-- Wire Remote Listeners
if remotes.StateSync then
	remotes.StateSync.OnClientEvent:Connect(function(data)
		UIController.OnStateSync(data)
	end)
end

if remotes.GachaResult then
	remotes.GachaResult.OnClientEvent:Connect(function(results)
		UIController.OnGachaResult(results)
	end)
end

if remotes.NotifyMessage then
	remotes.NotifyMessage.OnClientEvent:Connect(function(message, color)
		UIController.ShowNotification(message, color)
	end)
end

if remotes.BattleFinished then
	remotes.BattleFinished.OnClientEvent:Connect(function(data)
		UIController.OnBattleFinished(data)
	end)
end

if remotes.OpenLobbyModal then
	remotes.OpenLobbyModal.OnClientEvent:Connect(function(modalType)
		if modalType == "Campaign" then
			UIController.ToggleModal("CampaignModal")
		elseif modalType == "Backpack" then
			UIController.ToggleModal("BackpackModal")
		elseif modalType == "Gacha" then
			UIController.ToggleModal("SummonModal")
		elseif modalType == "Blacksmith" then
			UIController.ShowNotification("🔨 Blacksmith Forge: Equipment Enhancement unlocks at Chapter 2!", Color3.fromRGB(255, 180, 50))
		elseif modalType == "Arena" then
			UIController.ShowNotification("🏆 PvP Arena: Unlocks at Chapter 3!", Color3.fromRGB(255, 180, 50))
		end
	end)
end

-- Notify Server that client is ready to receive state
if remotes.ClientReady then
	remotes.ClientReady:FireServer()
end

print("[Client] Arknights x Idle RPG Client loaded successfully.")
