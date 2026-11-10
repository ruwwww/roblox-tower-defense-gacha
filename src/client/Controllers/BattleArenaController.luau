--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StageData = require(Shared:WaitForChild("Data"):WaitForChild("StageData"))
local HeroData = require(Shared:WaitForChild("Data"):WaitForChild("HeroData"))

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local ARENA_ORIGIN = Vector3.new(0, 300, 0)
local TILE_SIZE = 10
local GRID_W = 10
local GRID_H = 8

local BattleArenaController = {
	ArenaFolder = nil :: Folder?,
	IsPlaying = false,
	Speed = 1,
	ActiveTweens = {} :: { Tween },
	ActiveConnections = {} :: { RBXScriptConnection },
}

local function GridToWorld(gridX: number?, gridY: number?, heightOffset: number): Vector3
	local gx = gridX or 5
	local gy = gridY or 4
	local localX = (gx - (GRID_W + 1) / 2) * TILE_SIZE
	local localZ = (gy - (GRID_H + 1) / 2) * TILE_SIZE
	return ARENA_ORIGIN + Vector3.new(localX, heightOffset, localZ)
end

function BattleArenaController.Init()
	print("[BattleArenaController] 3D World Battle View initialized.")
end

function BattleArenaController.Start3DBattle(data: any, onComplete: () -> ())
	if BattleArenaController.IsPlaying then
		BattleArenaController.Stop()
	end

	BattleArenaController.IsPlaying = true
	BattleArenaController.Speed = 1

	-- Clean up previous arena if any
	if BattleArenaController.ArenaFolder then
		BattleArenaController.ArenaFolder:Destroy()
	end

	local arena = Instance.new("Folder")
	arena.Name = "ActiveBattleArena"
	arena.Parent = Workspace
	BattleArenaController.ArenaFolder = arena

	local stageDef = StageData.Get(data.StageId)
	local tilesMap = stageDef and stageDef.Tiles or {}
	local pathCoords = (stageDef and stageDef.PathCoords and #stageDef.PathCoords > 0) and stageDef.PathCoords or {
		Vector2.new(1, 4),
		Vector2.new(3, 4),
		Vector2.new(3, 2),
		Vector2.new(6, 2),
		Vector2.new(6, 6),
		Vector2.new(8, 6),
		Vector2.new(8, 4),
		Vector2.new(10, 4),
	}

	-- 1. Build Physical 3D Tile Board (2D Grid rendered with 3D parts)
	local floorBase = Instance.new("Part")
	floorBase.Name = "ArenaFloorBase"
	floorBase.Size = Vector3.new(GRID_W * TILE_SIZE + 8, 2, GRID_H * TILE_SIZE + 8)
	floorBase.Position = ARENA_ORIGIN - Vector3.new(0, 1.5, 0)
	floorBase.Anchored = true
	floorBase.Material = Enum.Material.Concrete
	floorBase.Color = Color3.fromRGB(25, 28, 35)
	floorBase.Parent = arena

	for y = 1, GRID_H do
		for x = 1, GRID_W do
			local tileType = tilesMap[x .. "," .. y] or "Ground"
			local tilePart = Instance.new("Part")
			tilePart.Name = string.format("Tile_%d_%d", x, y)
			tilePart.Anchored = true

			if tileType == "Path" then
				tilePart.Size = Vector3.new(TILE_SIZE - 0.4, 0.8, TILE_SIZE - 0.4)
				tilePart.Position = GridToWorld(x, y, 0.2)
				tilePart.Material = Enum.Material.Slate
				tilePart.Color = Color3.fromRGB(115, 95, 75)
			elseif tileType == "HighGround" then
				tilePart.Size = Vector3.new(TILE_SIZE - 0.4, 4.5, TILE_SIZE - 0.4)
				tilePart.Position = GridToWorld(x, y, 2.25)
				tilePart.Material = Enum.Material.Cobblestone
				tilePart.Color = Color3.fromRGB(55, 60, 75)
			else
				tilePart.Size = Vector3.new(TILE_SIZE - 0.4, 1.2, TILE_SIZE - 0.4)
				tilePart.Position = GridToWorld(x, y, 0.4)
				tilePart.Material = Enum.Material.Grass
				tilePart.Color = Color3.fromRGB(45, 95, 50)
			end

			tilePart.Parent = arena
		end
	end

	-- Spawn Portal (1, 4)
	local spawnPos = GridToWorld(1, 4, 1.0)
	local spawnGate = Instance.new("Part")
	spawnGate.Name = "EnemySpawnPortal"
	spawnGate.Size = Vector3.new(4, 7, 4)
	spawnGate.Position = spawnPos + Vector3.new(0, 3.5, 0)
	spawnGate.Anchored = true
	spawnGate.CanCollide = false
	spawnGate.Material = Enum.Material.Neon
	spawnGate.Color = Color3.fromRGB(220, 50, 40)
	spawnGate.Transparency = 0.3
	spawnGate.Parent = arena

	-- Base Crystal (10, 4)
	local crystalPos = GridToWorld(10, 4, 1.0)
	local crystalBase = Instance.new("Part")
	crystalBase.Name = "BaseCrystal"
	crystalBase.Size = Vector3.new(3, 6, 3)
	crystalBase.Position = crystalPos + Vector3.new(0, 3.5, 0)
	crystalBase.Anchored = true
	crystalBase.CanCollide = false
	crystalBase.Material = Enum.Material.Neon
	crystalBase.Color = Color3.fromRGB(60, 220, 255)
	crystalBase.Parent = arena

	-- 2. Setup Top-Down Isometric Camera
	local prevCameraType = Camera.CameraType
	local prevCameraCFrame = Camera.CFrame
	Camera.CameraType = Enum.CameraType.Scriptable

	local camTarget = ARENA_ORIGIN + Vector3.new(0, 0, 0)
	local camOffset = Vector3.new(0, 75, -55)
	Camera.CFrame = CFrame.lookAt(ARENA_ORIGIN + camOffset, camTarget)

	-- 3. In-Game Battle HUD Overlay
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local battleGui = Instance.new("ScreenGui")
	battleGui.Name = "Battle3DOverlay"
	battleGui.ResetOnSpawn = false
	battleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	battleGui.Parent = playerGui

	-- Header Info Bar
	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(0.6, 0, 0, 50)
	headerBar.Position = UDim2.new(0.2, 0, 0, 15)
	headerBar.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	headerBar.BackgroundTransparency = 0.2
	headerBar.Parent = battleGui

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 10)
	hCorner.Parent = headerBar

	local hStroke = Instance.new("UIStroke")
	hStroke.Color = Color3.fromRGB(70, 120, 220)
	hStroke.Thickness = 2
	hStroke.Parent = headerBar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.6, 0, 1, 0)
	titleLbl.Position = UDim2.new(0.04, 0, 0, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3 = Color3.fromRGB(255, 230, 90)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Text = string.format("⚔️ %s [%s]", data.StageName or "Battle", data.StageId or "1-1")
	titleLbl.Parent = headerBar

	local crystalHpLbl = Instance.new("TextLabel")
	crystalHpLbl.Size = UDim2.new(0.32, 0, 1, 0)
	crystalHpLbl.Position = UDim2.new(0.64, 0, 0, 0)
	crystalHpLbl.BackgroundTransparency = 1
	crystalHpLbl.TextColor3 = Color3.fromRGB(100, 230, 255)
	crystalHpLbl.TextScaled = true
	crystalHpLbl.Font = Enum.Font.GothamBold
	crystalHpLbl.Text = string.format("💎 Crystal: %d/%d", data.CrystalHp or 20, data.MaxCrystalHp or 20)
	crystalHpLbl.Parent = headerBar

	-- Bottom-Right Control Panel
	local ctrlPanel = Instance.new("Frame")
	ctrlPanel.Size = UDim2.new(0, 240, 0, 50)
	ctrlPanel.Position = UDim2.new(1, -260, 1, -70)
	ctrlPanel.BackgroundTransparency = 1
	ctrlPanel.Parent = battleGui

	local speedBtn = Instance.new("TextButton")
	speedBtn.Size = UDim2.new(0, 105, 0, 44)
	speedBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
	speedBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	speedBtn.TextScaled = true
	speedBtn.Font = Enum.Font.GothamBold
	speedBtn.Text = "▶ Speed: 1x"
	speedBtn.Parent = ctrlPanel

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = speedBtn

	local skipBtn = Instance.new("TextButton")
	skipBtn.Size = UDim2.new(0, 115, 0, 44)
	skipBtn.Position = UDim2.new(0, 120, 0, 0)
	skipBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	skipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	skipBtn.TextScaled = true
	skipBtn.Font = Enum.Font.GothamBlack
	skipBtn.Text = "⚡ SKIP"
	skipBtn.Parent = ctrlPanel

	local skCorner = Instance.new("UICorner")
	skCorner.CornerRadius = UDim.new(0, 8)
	skCorner.Parent = skipBtn

	speedBtn.MouseButton1Click:Connect(function()
		if BattleArenaController.Speed == 1 then
			BattleArenaController.Speed = 2
			speedBtn.Text = "⏩ Speed: 2x"
			speedBtn.BackgroundColor3 = Color3.fromRGB(45, 110, 180)
		elseif BattleArenaController.Speed == 2 then
			BattleArenaController.Speed = 4
			speedBtn.Text = "⚡ Speed: 4x"
			speedBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 220)
		else
			BattleArenaController.Speed = 1
			speedBtn.Text = "▶ Speed: 1x"
			speedBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 65)
		end
	end)

	local isFinished = false
	local function FinishBattle()
		if isFinished then return end
		isFinished = true
		BattleArenaController.IsPlaying = false

		if battleGui then
			battleGui:Destroy()
		end
		if arena then
			arena:Destroy()
		end
		Camera.CameraType = prevCameraType
		Camera.CFrame = prevCameraCFrame

		onComplete()
	end

	skipBtn.MouseButton1Click:Connect(function()
		FinishBattle()
	end)

	-- 4. Deploy 3D Hero Tokens on Tiles from Formation
	local heroParts: { [string]: Part } = {}
	if data.Formation then
		for _, heroUnit in ipairs(data.Formation) do
			local gx = (heroUnit.GridPos and heroUnit.GridPos.X) or heroUnit.GridX or 5
			local gy = (heroUnit.GridPos and heroUnit.GridPos.Y) or heroUnit.GridY or 4
			local hY = (heroUnit.PlacementType == "Ground") and 2.0 or 5.5
			local hPos = GridToWorld(gx, gy, hY)

			local heroPart = Instance.new("Part")
			heroPart.Name = "Hero_" .. heroUnit.HeroId
			heroPart.Size = Vector3.new(2.8, 4.0, 2.8)
			heroPart.Position = hPos
			heroPart.Anchored = true
			heroPart.CanCollide = false
			heroPart.Material = Enum.Material.SmoothPlastic

			local def = HeroData.Get(heroUnit.HeroId)
			heroPart.Color = def and def.Color or Color3.fromRGB(70, 140, 220)
			heroPart.Parent = arena

			-- Hero Overhead Billboard
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.new(4, 0, 2, 0)
			bb.StudsOffset = Vector3.new(0, 3.2, 0)
			bb.AlwaysOnTop = true
			bb.Parent = heroPart

			local roleIcon = "🛡️"
			if heroUnit.Role == "Guard" then roleIcon = "⚔️"
			elseif heroUnit.Role == "Sniper" then roleIcon = "🏹"
			elseif heroUnit.Role == "Caster" then roleIcon = "🔥"
			elseif heroUnit.Role == "Medic" then roleIcon = "🌿"
			end

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, 0, 0.5, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLbl.TextScaled = true
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.Text = roleIcon .. " " .. (def and def.Name or heroUnit.HeroId)
			nameLbl.Parent = bb

			local hpBarBack = Instance.new("Frame")
			hpBarBack.Size = UDim2.new(0.8, 0, 0.25, 0)
			hpBarBack.Position = UDim2.new(0.1, 0, 0.6, 0)
			hpBarBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			hpBarBack.BorderSizePixel = 0
			hpBarBack.Parent = bb

			local hpBarFill = Instance.new("Frame")
			hpBarFill.Size = UDim2.new(1, 0, 1, 0)
			hpBarFill.BackgroundColor3 = Color3.fromRGB(60, 220, 80)
			hpBarFill.BorderSizePixel = 0
			hpBarFill.Parent = hpBarBack

			heroParts[gx .. "_" .. gy] = heroPart
		end
	end

	-- 5. Animated Enemy Wave along Path
	task.spawn(function()
		local enemyCount = 8
		local enemySpacing = 1.0

		for eIdx = 1, enemyCount do
			if isFinished then break end

			task.spawn(function()
				local enemyPart = Instance.new("Part")
				enemyPart.Name = "Enemy_" .. eIdx
				enemyPart.Size = Vector3.new(2.4, 3.2, 2.4)
				enemyPart.Anchored = true
				enemyPart.CanCollide = false
				enemyPart.Material = Enum.Material.Neon
				enemyPart.Color = Color3.fromRGB(230, 60, 40)
				local startCoord = pathCoords[1] or Vector2.new(1, 4)
				enemyPart.Position = GridToWorld(startCoord.X, startCoord.Y, 2.0)
				enemyPart.Parent = arena

				-- Move enemy along path waypoints
				for wIdx = 2, #pathCoords do
					if isFinished then break end
					local targetCoord = pathCoords[wIdx]
					if not targetCoord then continue end
					local targetPos = GridToWorld(targetCoord.X, targetCoord.Y, 2.0)
					local dist = (targetPos - enemyPart.Position).Magnitude
					local moveTime = (dist / 14) / BattleArenaController.Speed

					local tween = TweenService:Create(enemyPart, TweenInfo.new(moveTime, Enum.EasingStyle.Linear), {
						Position = targetPos,
					})
					tween:Play()
					tween.Completed:Wait()

					-- Trigger attack effects if close to any hero
					for _, heroPart in pairs(heroParts) do
						if (heroPart.Position - enemyPart.Position).Magnitude < 14 then
							-- Beam attack effect
							local beam = Instance.new("Part")
							beam.Size = Vector3.new(0.4, 0.4, (heroPart.Position - enemyPart.Position).Magnitude)
							beam.CFrame = CFrame.lookAt((heroPart.Position + enemyPart.Position) / 2, enemyPart.Position)
							beam.Material = Enum.Material.Neon
							beam.Color = Color3.fromRGB(255, 230, 80)
							beam.Anchored = true
							beam.CanCollide = false
							beam.Parent = arena

							task.delay(0.15, function()
								beam:Destroy()
							end)
							break
						end
					end
				end

				-- Enemy reaches base or dies
				if enemyPart and enemyPart.Parent then
					enemyPart:Destroy()
				end
			end)

			task.wait(enemySpacing / BattleArenaController.Speed)
		end

		task.wait(4.0 / BattleArenaController.Speed)
		FinishBattle()
	end)
end

function BattleArenaController.Stop()
	BattleArenaController.IsPlaying = false
	if BattleArenaController.ArenaFolder then
		BattleArenaController.ArenaFolder:Destroy()
		BattleArenaController.ArenaFolder = nil
	end
	for _, c in ipairs(BattleArenaController.ActiveConnections) do
		c:Disconnect()
	end
	table.clear(BattleArenaController.ActiveConnections)
end

return BattleArenaController
