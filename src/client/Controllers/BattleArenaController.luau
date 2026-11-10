--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StageData = require(Shared:WaitForChild("Data"):WaitForChild("StageData"))
local HeroData = require(Shared:WaitForChild("Data"):WaitForChild("HeroData"))
local BattleSimulation = require(Shared:WaitForChild("Simulation"):WaitForChild("BattleSimulation"))

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local ARENA_ORIGIN = Vector3.new(0, 100, 200)
local TILE_SIZE = 8
local GRID_W = 10
local GRID_H = 8

local BattleArenaController = {
	ArenaFolder = nil :: Folder?,
	IsPlaying = false,
	Speed = 1,
	LobbyCFrame = nil :: CFrame?,
}

local function GridToWorld(gridX: number?, gridY: number?, heightOffset: number): Vector3
	local gx = gridX or 5
	local gy = gridY or 4
	local localX = (gx - (GRID_W + 1) / 2) * TILE_SIZE
	local localZ = (gy - (GRID_H + 1) / 2) * TILE_SIZE
	return ARENA_ORIGIN + Vector3.new(localX, heightOffset, localZ)
end

local function CreateDamagePopup(parentPart: Part, text: string, color: Color3)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(3.5, 0, 1.4, 0)
	bb.StudsOffset = Vector3.new(math.random(-1, 1), 3.5, math.random(-1, 1))
	bb.AlwaysOnTop = true
	bb.Parent = parentPart

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.Text = text
	lbl.Parent = bb

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent = lbl

	local tween = TweenService:Create(bb, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = bb.StudsOffset + Vector3.new(0, 3.2, 0),
	})
	tween:Play()
	task.delay(0.7, function()
		if bb and bb.Parent then
			bb:Destroy()
		end
	end)
end

function BattleArenaController.Init()
	print("[BattleArenaController] 3D Deterministic Battle Arena initialized.")
end

function BattleArenaController.Start3DBattle(data: any, onComplete: () -> ())
	if BattleArenaController.IsPlaying then
		return
	end

	BattleArenaController.IsPlaying = true
	BattleArenaController.Speed = 1

	if BattleArenaController.ArenaFolder then
		BattleArenaController.ArenaFolder:Destroy()
	end

	local arena = Instance.new("Folder")
	arena.Name = "ActiveBattleArena"
	arena.Parent = Workspace
	BattleArenaController.ArenaFolder = arena

	local stageDef = StageData.Get(data.StageId)
	if not stageDef then
		onComplete()
		return
	end

	local tilesMap = stageDef.Tiles or {}

	-- 1. Build Physical 3D Tile Board (Unmistakable Visual Differentiation)
	local floorBase = Instance.new("Part")
	floorBase.Name = "ArenaFloorBase"
	floorBase.Size = Vector3.new(GRID_W * TILE_SIZE + 24, 2, GRID_H * TILE_SIZE + 24)
	floorBase.Position = ARENA_ORIGIN - Vector3.new(0, 1.5, 0)
	floorBase.Anchored = true
	floorBase.Material = Enum.Material.Concrete
	floorBase.Color = Color3.fromRGB(18, 20, 26)
	floorBase.Parent = arena

	-- Perimeter safety railings so player can explore without falling
	local function CreateRail(size: Vector3, pos: Vector3)
		local rail = Instance.new("Part")
		rail.Size = size
		rail.Position = pos
		rail.Anchored = true
		rail.Material = Enum.Material.Glass
		rail.Transparency = 0.5
		rail.Color = Color3.fromRGB(80, 130, 180)
		rail.Parent = arena
	end
	local halfW = (GRID_W * TILE_SIZE + 24) / 2
	local halfH = (GRID_H * TILE_SIZE + 24) / 2
	CreateRail(Vector3.new(halfW * 2, 4, 1.5), ARENA_ORIGIN + Vector3.new(0, 1.5, halfH))
	CreateRail(Vector3.new(halfW * 2, 4, 1.5), ARENA_ORIGIN + Vector3.new(0, 1.5, -halfH))
	CreateRail(Vector3.new(1.5, 4, halfH * 2), ARENA_ORIGIN + Vector3.new(halfW, 1.5, 0))
	CreateRail(Vector3.new(1.5, 4, halfH * 2), ARENA_ORIGIN + Vector3.new(-halfW, 1.5, 0))

	for y = 1, GRID_H do
		for x = 1, GRID_W do
			local tileType = tilesMap[x .. "," .. y] or "Ground"
			local tilePart = Instance.new("Part")
			tilePart.Name = string.format("Tile_%d_%d", x, y)
			tilePart.Anchored = true
			tilePart.CanCollide = true

			if tileType == "Path" then
				-- Enemy Highway: Dark pavement with glowing orange guide stripe
				tilePart.Size = Vector3.new(TILE_SIZE - 0.2, 0.6, TILE_SIZE - 0.2)
				tilePart.Position = GridToWorld(x, y, 0.1)
				tilePart.Material = Enum.Material.Pavement
				tilePart.Color = Color3.fromRGB(36, 38, 48)

				-- Center guide stripe
				local stripe = Instance.new("Part")
				stripe.Name = "PathStripe"
				stripe.Size = Vector3.new(TILE_SIZE * 0.45, 0.64, TILE_SIZE * 0.45)
				stripe.Position = GridToWorld(x, y, 0.12)
				stripe.Anchored = true
				stripe.CanCollide = false
				stripe.Material = Enum.Material.Neon
				stripe.Color = Color3.fromRGB(240, 95, 30)
				stripe.Transparency = 0.45
				stripe.Parent = arena

			elseif tileType == "HighGround" then
				-- Tower: 3.8-stud high stone tower with cyan rune top
				tilePart.Size = Vector3.new(TILE_SIZE - 0.4, 3.8, TILE_SIZE - 0.4)
				tilePart.Position = GridToWorld(x, y, 1.9)
				tilePart.Material = Enum.Material.Cobblestone
				tilePart.Color = Color3.fromRGB(48, 55, 70)

				local runeCap = Instance.new("Part")
				runeCap.Name = "TowerCap"
				runeCap.Size = Vector3.new(TILE_SIZE - 1.2, 0.2, TILE_SIZE - 1.2)
				runeCap.Position = GridToWorld(x, y, 3.85)
				runeCap.Anchored = true
				runeCap.CanCollide = false
				runeCap.Material = Enum.Material.Neon
				runeCap.Color = Color3.fromRGB(0, 190, 255)
				runeCap.Transparency = 0.35
				runeCap.Parent = arena

			elseif tileType == "Obstacle" then
				-- Crag / Boulder
				tilePart.Size = Vector3.new(TILE_SIZE - 0.5, 3.0, TILE_SIZE - 0.5)
				tilePart.Position = GridToWorld(x, y, 1.5)
				tilePart.Material = Enum.Material.Slate
				tilePart.Color = Color3.fromRGB(65, 68, 75)

			else
				-- Lush green meadow terrain (Ground Deployable for Melee)
				tilePart.Size = Vector3.new(TILE_SIZE - 0.3, 1.0, TILE_SIZE - 0.3)
				tilePart.Position = GridToWorld(x, y, 0.3)
				tilePart.Material = Enum.Material.Grass
				tilePart.Color = Color3.fromRGB(40, 105, 48)
			end

			tilePart.Parent = arena
		end
	end

	-- Spawn Portal (1st waypoint)
	local startWp = (stageDef.PathCoords and stageDef.PathCoords[1]) or Vector2.new(1, 4)
	local spawnPos = GridToWorld(startWp.X, startWp.Y, 1.0)
	local spawnGate = Instance.new("Part")
	spawnGate.Name = "EnemySpawnPortal"
	spawnGate.Size = Vector3.new(4, 7, 4)
	spawnGate.Position = spawnPos + Vector3.new(0, 3.5, 0)
	spawnGate.Anchored = true
	spawnGate.CanCollide = false
	spawnGate.Material = Enum.Material.Neon
	spawnGate.Color = Color3.fromRGB(220, 50, 40)
	spawnGate.Transparency = 0.25
	spawnGate.Parent = arena

	-- Base Crystal (Last waypoint)
	local endWp = (stageDef.PathCoords and stageDef.PathCoords[#stageDef.PathCoords]) or Vector2.new(10, 4)
	local crystalPos = GridToWorld(endWp.X, endWp.Y, 1.0)
	local crystalBase = Instance.new("Part")
	crystalBase.Name = "BaseCrystal"
	crystalBase.Size = Vector3.new(3.5, 6.5, 3.5)
	crystalBase.Position = crystalPos + Vector3.new(0, 3.5, 0)
	crystalBase.Anchored = true
	crystalBase.CanCollide = false
	crystalBase.Material = Enum.Material.Neon
	crystalBase.Color = Color3.fromRGB(60, 220, 255)
	crystalBase.Parent = arena

	-- 2. Teleport Player to Arena & Unlock Free Camera / Exploration Movement
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and not BattleArenaController.LobbyCFrame then
		BattleArenaController.LobbyCFrame = hrp.CFrame
	end
	if hrp then
		local startSpawnPos = ARENA_ORIGIN + Vector3.new(0, 3, -(GRID_H * TILE_SIZE / 2 + 7))
		hrp.CFrame = CFrame.lookAt(startSpawnPos, ARENA_ORIGIN)
	end

	Camera.CameraType = Enum.CameraType.Custom
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		Camera.CameraSubject = humanoid
	end

	-- 3. In-Game Battle HUD Overlay
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local battleGui = Instance.new("ScreenGui")
	battleGui.Name = "Battle3DOverlay"
	battleGui.ResetOnSpawn = false
	battleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	battleGui.Parent = playerGui

	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(0.65, 0, 0, 52)
	headerBar.Position = UDim2.new(0.175, 0, 0, 15)
	headerBar.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	headerBar.BackgroundTransparency = 0.15
	headerBar.Parent = battleGui

	local hCorner = Instance.new("UICorner")
	hCorner.CornerRadius = UDim.new(0, 10)
	hCorner.Parent = headerBar

	local hStroke = Instance.new("UIStroke")
	hStroke.Color = Color3.fromRGB(70, 120, 220)
	hStroke.Thickness = 2
	hStroke.Parent = headerBar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.62, 0, 1, 0)
	titleLbl.Position = UDim2.new(0.03, 0, 0, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3 = Color3.fromRGB(255, 230, 90)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Text = string.format("⚔️ %s [%s]", data.StageName or stageDef.Name, data.StageId)
	titleLbl.Parent = headerBar

	local crystalHpLbl = Instance.new("TextLabel")
	crystalHpLbl.Size = UDim2.new(0.32, 0, 1, 0)
	crystalHpLbl.Position = UDim2.new(0.65, 0, 0, 0)
	crystalHpLbl.BackgroundTransparency = 1
	crystalHpLbl.TextColor3 = Color3.fromRGB(100, 230, 255)
	crystalHpLbl.TextScaled = true
	crystalHpLbl.Font = Enum.Font.GothamBold
	crystalHpLbl.Text = "💎 Crystal: 100/100"
	crystalHpLbl.Parent = headerBar

	-- Bottom Right Action Panel (Speed, Skip, Exit)
	local ctrlPanel = Instance.new("Frame")
	ctrlPanel.Size = UDim2.new(0, 360, 0, 50)
	ctrlPanel.Position = UDim2.new(1, -380, 1, -70)
	ctrlPanel.BackgroundTransparency = 1
	ctrlPanel.Parent = battleGui

	local ctrlLayout = Instance.new("UIListLayout")
	ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
	ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	ctrlLayout.Padding = UDim.new(0, 10)
	ctrlLayout.Parent = ctrlPanel

	-- Exit Battle Button
	local exitBtn = Instance.new("TextButton")
	exitBtn.Size = UDim2.new(0, 105, 0, 44)
	exitBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	exitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	exitBtn.TextScaled = true
	exitBtn.Font = Enum.Font.GothamBold
	exitBtn.Text = "🚪 EXIT"
	exitBtn.Parent = ctrlPanel

	local exCorner = Instance.new("UICorner")
	exCorner.CornerRadius = UDim.new(0, 8)
	exCorner.Parent = exitBtn

	-- Speed Up Button (Milestone: Chapter 2-10)
	local highestStage = data.HighestClearedStage or "1-0"
	local isSpeedUnlocked = StageData.IsMilestoneReached(highestStage, "2-10")

	local speedBtn = Instance.new("TextButton")
	speedBtn.Size = UDim2.new(0, 115, 0, 44)
	speedBtn.BackgroundColor3 = isSpeedUnlocked and Color3.fromRGB(35, 45, 65) or Color3.fromRGB(50, 50, 60)
	speedBtn.TextColor3 = isSpeedUnlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 170)
	speedBtn.TextScaled = true
	speedBtn.Font = Enum.Font.GothamBold
	speedBtn.Text = isSpeedUnlocked and "▶ Speed: 1x" or "🔒 2x (2-10)"
	speedBtn.Parent = ctrlPanel

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = speedBtn

	-- Skip Button (Milestone: Chapter 5-10)
	local isSkipUnlocked = StageData.IsMilestoneReached(highestStage, "5-10")

	local skipBtn = Instance.new("TextButton")
	skipBtn.Size = UDim2.new(0, 110, 0, 44)
	skipBtn.BackgroundColor3 = isSkipUnlocked and Color3.fromRGB(220, 150, 40) or Color3.fromRGB(50, 50, 60)
	skipBtn.TextColor3 = isSkipUnlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 160, 170)
	skipBtn.TextScaled = true
	skipBtn.Font = Enum.Font.GothamBlack
	skipBtn.Text = isSkipUnlocked and "⚡ SKIP" or "🔒 Skip (5-10)"
	skipBtn.Parent = ctrlPanel

	local skCorner = Instance.new("UICorner")
	skCorner.CornerRadius = UDim.new(0, 8)
	skCorner.Parent = skipBtn

	speedBtn.MouseButton1Click:Connect(function()
		if not isSpeedUnlocked then
			CreateDamagePopup(floorBase, "Speed 2x unlocks after Stage 2-10!", Color3.fromRGB(255, 200, 60))
			return
		end

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
	local function FinishBattle(isManualExit: boolean?)
		if isFinished then return end
		isFinished = true
		BattleArenaController.IsPlaying = false

		if battleGui then
			battleGui:Destroy()
		end

		if isManualExit then
			BattleArenaController.ReturnToLobby()
			local UIController = require(script.Parent:WaitForChild("UIController"))
			UIController.SetLobbyVisible(true)
		else
			onComplete()
		end
	end

	exitBtn.MouseButton1Click:Connect(function()
		FinishBattle(true)
	end)

	skipBtn.MouseButton1Click:Connect(function()
		if not isSkipUnlocked then
			CreateDamagePopup(floorBase, "Skip Autobattle unlocks after Stage 5-10!", Color3.fromRGB(255, 200, 60))
			return
		end
		FinishBattle(false)
	end)

	-- 4. Deploy 3D Hero Tokens on Tiles from Formation
	type HeroVisual = {
		Part: Part,
		HpFill: Frame,
		Role: string,
		MaxHp: number,
	}
	local heroVisuals: { [string]: HeroVisual } = {}

	if data.Formation then
		for _, heroUnit in ipairs(data.Formation) do
			local gx = (heroUnit.GridPos and heroUnit.GridPos.X) or heroUnit.GridX or 5
			local gy = (heroUnit.GridPos and heroUnit.GridPos.Y) or heroUnit.GridY or 4
			local hY = (heroUnit.PlacementType == "Ground") and 2.0 or 5.2
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

			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.new(4.2, 0, 2.2, 0)
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
			nameLbl.Text = string.format("%s %s", roleIcon, def and def.Name or heroUnit.HeroId)
			nameLbl.Parent = bb

			local hpBg = Instance.new("Frame")
			hpBg.Size = UDim2.new(0.9, 0, 0.28, 0)
			hpBg.Position = UDim2.new(0.05, 0, 0.58, 0)
			hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			hpBg.BorderSizePixel = 0
			hpBg.Parent = bb

			local hpFill = Instance.new("Frame")
			hpFill.Size = UDim2.new(1, 0, 1, 0)
			hpFill.BackgroundColor3 = Color3.fromRGB(50, 220, 80)
			hpFill.BorderSizePixel = 0
			hpFill.Parent = hpBg

			heroVisuals[heroUnit.HeroUid] = {
				Part = heroPart,
				HpFill = hpFill,
				Role = heroUnit.Role,
				MaxHp = def and def.BaseHp or 1000,
			}
		end
	end

	-- 5. Start Deterministic Simulation Session
	local heroInstancesMap = {}
	if data.HeroInstances then
		heroInstancesMap = data.HeroInstances
	else
		for _, h in ipairs(data.Formation or {}) do
			heroInstancesMap[h.HeroUid] = {
				Uid = h.HeroUid,
				HeroId = h.HeroId,
				Level = 1,
				Star = 3,
			}
		end
	end

	local session = BattleSimulation.CreateSession(stageDef, data.Formation, heroInstancesMap)

	-- Active Visual Models for Enemies
	type EnemyVisual = {
		Part: Part,
		HpFill: Frame,
		MaxHp: number,
		CurHp: number,
	}
	local enemyVisuals: { [string]: EnemyVisual } = {}

	task.spawn(function()
		while BattleArenaController.IsPlaying and not session:IsFinished() do
			local events = session:Step(0.1)

			for _, ev in ipairs(events) do
				if ev.Type == "EnemySpawned" then
					local ePart = Instance.new("Part")
					ePart.Name = "Enemy_" .. ev.EnemyId
					ePart.Position = GridToWorld(ev.GridPos.X, ev.GridPos.Y, 2.0)
					ePart.Anchored = true
					ePart.CanCollide = false

					if ev.IsBoss then
						ePart.Size = Vector3.new(4.5, 6.0, 4.5)
						ePart.Material = Enum.Material.Neon
						ePart.Color = Color3.fromRGB(180, 20, 20)

						local crown = Instance.new("Part")
						crown.Name = "BossCrown"
						crown.Size = Vector3.new(3, 1.2, 3)
						crown.Position = ePart.Position + Vector3.new(0, 3.8, 0)
						crown.Material = Enum.Material.Neon
						crown.Color = Color3.fromRGB(255, 215, 0)
						crown.Anchored = true
						crown.CanCollide = false
						crown.Parent = ePart
					elseif ev.Archetype == "runner" then
						ePart.Size = Vector3.new(2.2, 3.0, 2.2)
						ePart.Material = Enum.Material.SmoothPlastic
						ePart.Color = Color3.fromRGB(230, 110, 30)
					elseif ev.Archetype == "tank" then
						ePart.Size = Vector3.new(3.5, 4.8, 3.5)
						ePart.Material = Enum.Material.DiamondPlate
						ePart.Color = Color3.fromRGB(60, 65, 75)
					elseif ev.Archetype == "golem" then
						ePart.Size = Vector3.new(4.0, 5.5, 4.0)
						ePart.Material = Enum.Material.Cobblestone
						ePart.Color = Color3.fromRGB(100, 95, 90)
					else
						ePart.Size = Vector3.new(2.5, 3.5, 2.5)
						ePart.Material = Enum.Material.SmoothPlastic
						ePart.Color = Color3.fromRGB(160, 40, 40)
					end
					ePart.Parent = arena

					local ebb = Instance.new("BillboardGui")
					ebb.Size = UDim2.new(3.5, 0, 1.8, 0)
					ebb.StudsOffset = Vector3.new(0, ePart.Size.Y / 2 + 1.2, 0)
					ebb.AlwaysOnTop = true
					ebb.Parent = ePart

					local ehpBg = Instance.new("Frame")
					ehpBg.Size = UDim2.new(0.9, 0, 0.35, 0)
					ehpBg.Position = UDim2.new(0.05, 0, 0.4, 0)
					ehpBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
					ehpBg.BorderSizePixel = 0
					ehpBg.Parent = ebb

					local ehpFill = Instance.new("Frame")
					ehpFill.Size = UDim2.new(1, 0, 1, 0)
					ehpFill.BackgroundColor3 = Color3.fromRGB(230, 40, 40)
					ehpFill.BorderSizePixel = 0
					ehpFill.Parent = ehpBg

					enemyVisuals[ev.EnemyId] = {
						Part = ePart,
						HpFill = ehpFill,
						MaxHp = ev.MaxHp,
						CurHp = ev.Hp,
					}

				elseif ev.Type == "EnemyMoved" then
					local evis = enemyVisuals[ev.EnemyId]
					if evis and evis.Part and evis.Part.Parent then
						local targetPos = GridToWorld(ev.GridPos.X, ev.GridPos.Y, evis.Part.Size.Y / 2 + 0.5)
						evis.Part.Position = targetPos
						local crown = evis.Part:FindFirstChild("BossCrown") :: Part?
						if crown then
							crown.Position = targetPos + Vector3.new(0, evis.Part.Size.Y / 2 + 0.8, 0)
						end
					end

				elseif ev.Type == "EnemyBlocked" then
					local evis = enemyVisuals[ev.EnemyId]
					local hvis = heroVisuals[ev.BlockerUid]
					if evis and hvis and evis.Part and hvis.Part then
						CreateDamagePopup(evis.Part, "⛔ ENGAGED", Color3.fromRGB(255, 200, 50))
					end

				elseif ev.Type == "EnemyAttackedBlocker" then
					local hvis = heroVisuals[ev.BlockerUid]
					if hvis and hvis.Part and hvis.Part.Parent then
						local pct = math.clamp(ev.BlockerRemainingHp / ev.BlockerMaxHp, 0, 1)
						hvis.HpFill.Size = UDim2.new(pct, 0, 1, 0)
						CreateDamagePopup(hvis.Part, "-" .. tostring(math.floor(ev.Damage)), Color3.fromRGB(255, 60, 60))
					end

				elseif ev.Type == "HeroAttackedEnemy" then
					local evis = enemyVisuals[ev.EnemyId]
					local hvis = heroVisuals[ev.HeroUid]
					if evis and evis.Part and evis.Part.Parent then
						local pct = math.clamp(ev.EnemyRemainingHp / ev.EnemyMaxHp, 0, 1)
						evis.HpFill.Size = UDim2.new(pct, 0, 1, 0)

						local dmgText = tostring(math.floor(ev.Damage))
						local dmgColor = Color3.fromRGB(255, 230, 80)
						if ev.IsUltimate then
							dmgText = "💥 " .. dmgText .. " (ULTIMATE!)"
							dmgColor = Color3.fromRGB(255, 60, 220)
						end
						CreateDamagePopup(evis.Part, dmgText, dmgColor)

						if hvis and (hvis.Role == "Sniper" or hvis.Role == "Caster") then
							local beam = Instance.new("Part")
							beam.Size = Vector3.new(0.4, 0.4, (hvis.Part.Position - evis.Part.Position).Magnitude)
							beam.CFrame = CFrame.lookAt((hvis.Part.Position + evis.Part.Position) / 2, evis.Part.Position)
							beam.Anchored = true
							beam.CanCollide = false
							beam.Material = Enum.Material.Neon
							beam.Color = (hvis.Role == "Caster") and Color3.fromRGB(255, 100, 50) or Color3.fromRGB(100, 200, 255)
							beam.Parent = arena

							task.delay(0.12 / BattleArenaController.Speed, function()
								if beam and beam.Parent then
									beam:Destroy()
								end
							end)
						end
					end

				elseif ev.Type == "MedicHealedHero" then
					local targetVis = heroVisuals[ev.TargetUid]
					local medicVis = heroVisuals[ev.MedicUid]
					if targetVis and targetVis.Part and targetVis.Part.Parent then
						local pct = math.clamp(ev.TargetRemainingHp / targetVis.MaxHp, 0, 1)
						targetVis.HpFill.Size = UDim2.new(pct, 0, 1, 0)
						CreateDamagePopup(targetVis.Part, "+" .. tostring(math.floor(ev.HealAmount)) .. " HP", Color3.fromRGB(80, 255, 120))

						if medicVis and medicVis.Part then
							local healBeam = Instance.new("Part")
							healBeam.Size = Vector3.new(0.5, 0.5, (medicVis.Part.Position - targetVis.Part.Position).Magnitude)
							healBeam.CFrame = CFrame.lookAt((medicVis.Part.Position + targetVis.Part.Position) / 2, targetVis.Part.Position)
							healBeam.Anchored = true
							healBeam.CanCollide = false
							healBeam.Material = Enum.Material.Neon
							healBeam.Color = Color3.fromRGB(60, 255, 140)
							healBeam.Transparency = 0.25
							healBeam.Parent = arena

							task.delay(0.18 / BattleArenaController.Speed, function()
								if healBeam and healBeam.Parent then
									healBeam:Destroy()
								end
							end)
						end
					end

				elseif ev.Type == "HeroDied" then
					local hvis = heroVisuals[ev.HeroUid]
					if hvis and hvis.Part and hvis.Part.Parent then
						hvis.Part.Transparency = 0.6
						hvis.HpFill.Size = UDim2.new(0, 0, 1, 0)
						CreateDamagePopup(hvis.Part, "💀 DEFEATED", Color3.fromRGB(255, 50, 50))
					end

				elseif ev.Type == "EnemyDied" then
					local evis = enemyVisuals[ev.EnemyId]
					if evis and evis.Part and evis.Part.Parent then
						evis.HpFill.Size = UDim2.new(0, 0, 1, 0)
						task.delay(0.1, function()
							if evis.Part and evis.Part.Parent then
								evis.Part:Destroy()
							end
						end)
					end

				elseif ev.Type == "CrystalDamaged" then
					crystalHpLbl.Text = string.format("💎 Crystal: %d/%d", ev.CurrentCrystalHp, ev.MaxCrystalHp)
					crystalBase.Color = Color3.fromRGB(255, 50, 50)
					CreateDamagePopup(crystalBase, "-" .. tostring(ev.LeakDamage) .. " LEAK!", Color3.fromRGB(255, 40, 40))
					task.delay(0.2, function()
						if crystalBase and crystalBase.Parent then
							crystalBase.Color = Color3.fromRGB(60, 220, 255)
						end
					end)
				end
			end

			task.wait(0.1 / BattleArenaController.Speed)
		end

		task.wait(1.0 / BattleArenaController.Speed)
		FinishBattle(false)
	end)
end

function BattleArenaController.ReturnToLobby()
	BattleArenaController.IsPlaying = false
	if BattleArenaController.ArenaFolder then
		BattleArenaController.ArenaFolder:Destroy()
		BattleArenaController.ArenaFolder = nil
	end

	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and BattleArenaController.LobbyCFrame then
		hrp.CFrame = BattleArenaController.LobbyCFrame
	end
	BattleArenaController.LobbyCFrame = nil

	Camera.CameraType = Enum.CameraType.Custom
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		Camera.CameraSubject = humanoid
	end
end

function BattleArenaController.Stop()
	BattleArenaController.ReturnToLobby()
end

return BattleArenaController
