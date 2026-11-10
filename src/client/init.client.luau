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

local VisualsController = require(script:WaitForChild("Controllers"):WaitForChild("VisualsController"))
local PlacementController = require(script:WaitForChild("Controllers"):WaitForChild("PlacementController"))
local UIController = require(script:WaitForChild("Controllers"):WaitForChild("UIController"))

-- Initialize controllers
VisualsController.Init()
PlacementController.Init(remotes)
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

if remotes.TowerFired then
	remotes.TowerFired.OnClientEvent:Connect(function(towerId, origin, target, role, color)
		VisualsController.OnTowerFired(towerId, origin, target, role, color)
	end)
end

if remotes.EnemyDamaged then
	remotes.EnemyDamaged.OnClientEvent:Connect(function(enemyId, damage, currentHp, maxHp, isCritical)
		VisualsController.OnEnemyDamaged(enemyId, damage, currentHp, maxHp, isCritical)
	end)
end

if remotes.EnemyDied then
	remotes.EnemyDied.OnClientEvent:Connect(function(enemyId, position)
		VisualsController.OnEnemyDied(enemyId, position)
	end)
end

-- Notify Server that client is ready to receive state
if remotes.ClientReady then
	remotes.ClientReady:FireServer()
end

print("[Client] Tower Defense x Gacha Client Controllers loaded successfully.")
