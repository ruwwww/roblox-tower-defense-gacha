--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EnemyData = require(Shared:WaitForChild("Data"):WaitForChild("EnemyData"))
local WaveData = require(Shared:WaitForChild("Data"):WaitForChild("WaveData"))
local MathUtil = require(Shared:WaitForChild("Utils"):WaitForChild("MathUtil"))

local MapService = require(script.Parent:WaitForChild("MapService"))
local GachaService = require(script.Parent:WaitForChild("GachaService"))

export type ActiveEnemy = {
	Id: string,
	ArchetypeId: string,
	Name: string,
	Hp: number,
	MaxHp: number,
	Speed: number,
	BaseSpeed: number,
	WaypointIndex: number,
	Position: Vector3,
	Progress: number,
	BountyGold: number,
	BountyGems: number,
	Model: Model,
	SlowPercent: number,
	SlowDuration: number,
	BurnDps: number,
	BurnDuration: number,
}

local WaveService = {
	CurrentWave = 0,
	WaveStatus = "Intermission" :: "Intermission" | "Spawning" | "InCombat" | "GameOver",
	BaseHealth = Config.BaseMaxHealth,
	IntermissionTimer = Config.IntermissionTime,
	Enemies = {} :: { [string]: ActiveEnemy },
	Remotes = {} :: { [string]: RemoteEvent },
	Waypoints = {} :: { Vector3 },
	TotalTrackLength = 0,
	SpawnQueue = {} :: { { Archetype: string, Delay: number } },
	SpawnTimer = 0,
	IsSpawning = false,
}

local function CreateEnemyModel(stats: any, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = stats.Name .. "_" .. stats.ArchetypeId

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2.4 * stats.Scale, 3.2 * stats.Scale, 2.4 * stats.Scale)
	root.Position = position + Vector3.new(0, 1.6 * stats.Scale, 0)
	root.Anchored = true
	root.CanCollide = false
	root.Material = stats.Material
	root.Color = stats.Color
	root.Parent = model

	-- Visual head / eye
	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Size = Vector3.new(1.2 * stats.Scale, 0.8 * stats.Scale, 0.6 * stats.Scale)
	eye.CFrame = root.CFrame * CFrame.new(0, 0.8 * stats.Scale, -1.2 * stats.Scale)
	eye.Anchored = true
	eye.CanCollide = false
	eye.Material = Enum.Material.Neon
	eye.Color = Color3.fromRGB(255, 60, 60)
	eye.Parent = model

	-- Billboard health bar
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthGui"
	billboard.Size = UDim2.new(4 * stats.Scale, 0, 0.8 * stats.Scale, 0)
	billboard.StudsOffset = Vector3.new(0, 2.5 * stats.Scale, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = root

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local cornerFill = Instance.new("UICorner")
	cornerFill.CornerRadius = UDim.new(0, 4)
	cornerFill.Parent = fill

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Text = stats.Name .. " [" .. tostring(stats.Hp) .. "]"
	text.Parent = bg

	model.PrimaryPart = root
	return model
end

function WaveService.Init(remotes: { [string]: RemoteEvent })
	WaveService.Remotes = remotes
	WaveService.Waypoints = MapService.GetWaypoints()

	-- Calculate total track length
	WaveService.TotalTrackLength = 0
	for i = 1, #WaveService.Waypoints - 1 do
		WaveService.TotalTrackLength += (WaveService.Waypoints[i + 1] - WaveService.Waypoints[i]).Magnitude
	end

	RunService.Heartbeat:Connect(function(dt)
		WaveService.Update(dt)
	end)
end

function WaveService.StartNextWave()
	if WaveService.WaveStatus == "GameOver" then
		return
	end
	if WaveService.WaveStatus == "Spawning" or WaveService.WaveStatus == "InCombat" then
		return
	end

	WaveService.CurrentWave += 1
	WaveService.WaveStatus = "Spawning"
	WaveService.IsSpawning = true

	local waveDef = WaveData.GetWave(WaveService.CurrentWave)
	WaveService.SpawnQueue = {}

	for _, group in ipairs(waveDef.Groups) do
		for i = 1, group.Count do
			local delay = (i == 1) and group.DelayBefore or group.Interval
			table.insert(WaveService.SpawnQueue, {
				Archetype = group.Archetype,
				Delay = delay,
			})
		end
	end

	WaveService.BroadcastWaveState()
end

function WaveService.SpawnEnemy(archetypeId: string)
	local waypoints = WaveService.Waypoints
	if #waypoints < 2 then
		return
	end

	local startPos = waypoints[1]
	local stats = EnemyData.CalculateStatsForWave(archetypeId, WaveService.CurrentWave)
	local model = CreateEnemyModel(stats, startPos)

	local enemiesFolder = MapService.Folders.Enemies
	model.Parent = enemiesFolder

	local enemyId = HttpService:GenerateGUID(false)
	local enemy: ActiveEnemy = {
		Id = enemyId,
		ArchetypeId = archetypeId,
		Name = stats.Name,
		Hp = stats.Hp,
		MaxHp = stats.MaxHp,
		Speed = stats.Speed,
		BaseSpeed = stats.Speed,
		WaypointIndex = 2,
		Position = startPos,
		Progress = 0,
		BountyGold = stats.BountyGold,
		BountyGems = stats.BountyGems,
		Model = model,
		SlowPercent = 0,
		SlowDuration = 0,
		BurnDps = 0,
		BurnDuration = 0,
	}

	WaveService.Enemies[enemyId] = enemy

	if WaveService.Remotes.EnemySpawned then
		WaveService.Remotes.EnemySpawned:FireAllClients({
			Id = enemyId,
			ArchetypeId = archetypeId,
			Name = stats.Name,
			Position = startPos,
			Hp = stats.Hp,
			MaxHp = stats.MaxHp,
		})
	end
end

function WaveService.DamageEnemy(enemyId: string, damage: number, dealerPlayer: Player?, statusEffects: any?)
	local enemy = WaveService.Enemies[enemyId]
	if not enemy then
		return
	end

	enemy.Hp = math.max(0, enemy.Hp - damage)

	-- Apply status effects
	if statusEffects then
		if statusEffects.SlowPercent and statusEffects.SlowPercent > enemy.SlowPercent then
			enemy.SlowPercent = statusEffects.SlowPercent
			enemy.SlowDuration = 2.5
		end
		if statusEffects.BurnDps and statusEffects.BurnDps > enemy.BurnDps then
			enemy.BurnDps = statusEffects.BurnDps
			enemy.BurnDuration = 3.0
		end
	end

	-- Update model health bar
	local root = enemy.Model.PrimaryPart
	if root then
		local billboard = root:FindFirstChild("HealthGui")
		if billboard then
			local bg = billboard:FindFirstChild("Background")
			if bg then
				local fill = bg:FindFirstChild("Fill") :: Frame?
				local label = bg:FindFirstChild("Label") :: TextLabel?
				local ratio = enemy.Hp / enemy.MaxHp
				if fill then
					fill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
				end
				if label then
					label.Text = enemy.Name .. " [" .. tostring(math.ceil(enemy.Hp)) .. "]"
				end
			end
		end
	end

	if WaveService.Remotes.EnemyDamaged then
		WaveService.Remotes.EnemyDamaged:FireAllClients(enemyId, damage, enemy.Hp, enemy.MaxHp, damage > 100)
	end

	if enemy.Hp <= 0 then
		WaveService.KillEnemy(enemyId, dealerPlayer)
	end
end

function WaveService.KillEnemy(enemyId: string, killer: Player?)
	local enemy = WaveService.Enemies[enemyId]
	if not enemy then
		return
	end

	-- Award bounty to all players (cooperative TD!)
	for _, player in ipairs(Players:GetPlayers()) do
		GachaService.AddGold(player, enemy.BountyGold)
		if enemy.BountyGems > 0 then
			GachaService.AddGems(player, enemy.BountyGems)
		end
	end

	if WaveService.Remotes.EnemyDied then
		WaveService.Remotes.EnemyDied:FireAllClients(enemyId, enemy.Position)
	end

	enemy.Model:Destroy()
	WaveService.Enemies[enemyId] = nil
end

function WaveService.LeakEnemy(enemyId: string)
	local enemy = WaveService.Enemies[enemyId]
	if not enemy then
		return
	end

	local leakDamage = 1
	if enemy.ArchetypeId == "tank" then
		leakDamage = 3
	elseif enemy.ArchetypeId == "golem" then
		leakDamage = 6
	elseif enemy.ArchetypeId == "boss" then
		leakDamage = 20
	end

	WaveService.BaseHealth = math.max(0, WaveService.BaseHealth - leakDamage)

	if WaveService.Remotes.NotifyMessage then
		WaveService.Remotes.NotifyMessage:FireAllClients(
			enemy.Name .. " reached the Base! Lost " .. tostring(leakDamage) .. " HP!",
			Color3.fromRGB(255, 70, 70)
		)
	end

	enemy.Model:Destroy()
	WaveService.Enemies[enemyId] = nil

	if WaveService.BaseHealth <= 0 then
		WaveService.WaveStatus = "GameOver"
		if WaveService.Remotes.NotifyMessage then
			WaveService.Remotes.NotifyMessage:FireAllClients("DEFENSE COLLAPSED! GAME OVER!", Color3.fromRGB(255, 0, 0))
		end
	end

	WaveService.BroadcastWaveState()
end

function WaveService.Update(dt: number)
	if WaveService.WaveStatus == "GameOver" then
		return
	end

	-- Handle Intermission Countdown
	if WaveService.WaveStatus == "Intermission" then
		WaveService.IntermissionTimer -= dt
		if WaveService.IntermissionTimer <= 0 then
			WaveService.StartNextWave()
		else
			WaveService.BroadcastWaveState()
		end
		return
	end

	-- Handle Spawning queue
	if WaveService.IsSpawning then
		WaveService.SpawnTimer -= dt
		if WaveService.SpawnTimer <= 0 then
			if #WaveService.SpawnQueue > 0 then
				local nextSpawn = table.remove(WaveService.SpawnQueue, 1)
				if nextSpawn then
					WaveService.SpawnEnemy(nextSpawn.Archetype)
					WaveService.SpawnTimer = nextSpawn.Delay
				end
			else
				WaveService.IsSpawning = false
				WaveService.WaveStatus = "InCombat"
			end
		end
	end

	-- Update Active Enemies Movement & Status Effects
	local waypoints = WaveService.Waypoints
	for enemyId, enemy in pairs(WaveService.Enemies) do
		-- Status effects tick
		if enemy.SlowDuration > 0 then
			enemy.SlowDuration -= dt
			if enemy.SlowDuration <= 0 then
				enemy.SlowPercent = 0
			end
		end

		if enemy.BurnDuration > 0 then
			enemy.BurnDuration -= dt
			enemy.Hp = math.max(0, enemy.Hp - (enemy.BurnDps * dt))
			if enemy.Hp <= 0 then
				WaveService.KillEnemy(enemyId)
				continue
			end
		end

		local effectiveSpeed = enemy.BaseSpeed * (1 - enemy.SlowPercent)
		local targetWp = waypoints[enemy.WaypointIndex]

		if targetWp then
			local dir = targetWp - enemy.Position
			local dist = Vector3.new(dir.X, 0, dir.Z).Magnitude
			local moveDist = effectiveSpeed * dt

			if dist <= moveDist then
				-- Reached waypoint
				enemy.Position = targetWp
				enemy.WaypointIndex += 1
				if enemy.WaypointIndex > #waypoints then
					-- Reached Base Crystal!
					WaveService.LeakEnemy(enemyId)
					continue
				end
			else
				local stepVec = (dir.Unit) * moveDist
				enemy.Position += stepVec
				enemy.Progress += moveDist
			end

			-- Update model transform
			local nextWp = waypoints[enemy.WaypointIndex] or targetWp
			local root = enemy.Model.PrimaryPart
			if root then
				local lookPos = Vector3.new(nextWp.X, root.Position.Y, nextWp.Z)
				root.CFrame = CFrame.lookAt(Vector3.new(enemy.Position.X, root.Position.Y, enemy.Position.Z), lookPos)
				local eye = enemy.Model:FindFirstChild("Eye") :: Part?
				if eye then
					eye.CFrame = root.CFrame * CFrame.new(0, 0.8 * (root.Size.Y / 3.2), -1.2 * (root.Size.Z / 2.4))
				end
			end
		else
			WaveService.LeakEnemy(enemyId)
		end
	end

	-- Check if wave cleared
	local enemyCount = 0
	for _ in pairs(WaveService.Enemies) do
		enemyCount += 1
	end

	if not WaveService.IsSpawning and enemyCount == 0 and WaveService.WaveStatus == "InCombat" then
		WaveService.WaveCleared()
	end
end

function WaveService.WaveCleared()
	local waveDef = WaveData.GetWave(WaveService.CurrentWave)
	for _, player in ipairs(Players:GetPlayers()) do
		GachaService.AddGold(player, waveDef.RewardGold)
		GachaService.AddGems(player, waveDef.RewardGems)
	end

	if WaveService.Remotes.NotifyMessage then
		WaveService.Remotes.NotifyMessage:FireAllClients(
			"WAVE " .. tostring(WaveService.CurrentWave) .. " CLEARED! +" .. tostring(waveDef.RewardGold) .. " Gold, +" .. tostring(waveDef.RewardGems) .. " Gems!",
			Color3.fromRGB(80, 255, 120)
		)
	end

	WaveService.WaveStatus = "Intermission"
	WaveService.IntermissionTimer = Config.IntermissionTime
	WaveService.BroadcastWaveState()
end

function WaveService.BroadcastWaveState()
	if not WaveService.Remotes.StateSync then
		return
	end

	local enemyCount = 0
	for _ in pairs(WaveService.Enemies) do
		enemyCount += 1
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local pState = GachaService.GetState(player)
		if pState then
			WaveService.Remotes.StateSync:FireClient(player, {
				Gold = pState.Gold,
				Gems = pState.Gems,
				PityEpic = pState.PityEpic,
				PityLegendary = pState.PityLegendary,
				Inventory = pState.Inventory,
				Equipped = pState.Equipped,
				CurrentWave = WaveService.CurrentWave,
				WaveStatus = WaveService.WaveStatus,
				IntermissionTimer = math.ceil(WaveService.IntermissionTimer),
				BaseHealth = WaveService.BaseHealth,
				BaseMaxHealth = Config.BaseMaxHealth,
				EnemiesAlive = enemyCount,
			})
		end
	end
end

function WaveService.GetEnemies(): { [string]: ActiveEnemy }
	return WaveService.Enemies
end

return WaveService
