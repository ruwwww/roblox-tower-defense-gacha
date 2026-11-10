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

local ARENA_ORIGIN = Vector3.new(0, 300, 0)
local TILE_SIZE = 10
local GRID_W = 10
local GRID_H = 8

local BattleArenaController = {
	ArenaFolder = nil :: Folder?,
	IsPlaying = false,
	Speed = 1,
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
	bb.Size = UDim2.new(3, 0, 1.2, 0)
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

	local tween = TweenService:Create(bb, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = bb.StudsOffset + Vector3.new(0, 3, 0),
	})
	tween:Play()
	task.delay(0.65, function()
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
		BattleArenaController.Stop()
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

	-- 1. Build Physical 3D Tile Board (2D Grid in 3D Workspace)
	local floorBase = Instance.new("Part")
	floorBase.Name = "ArenaFloorBase"
	floorBase.Size = Vector3.new(GRID_W * TILE_SIZE + 8, 2, GRID_H * TILE_SIZE + 8)
	floorBase.Position = ARENA_ORIGIN - Vector3.new(0, 1.5, 0)
	floorBase.Anchored = true
	floorBase.Material = Enum.Material.Concrete
	floorBase.Color = Color3.fromRGB(22, 25, 32)
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
	spawnGate.Transparency = 0.25
	spawnGate.Parent = arena

	-- Base Crystal (10, 4)
	local crystalPos = GridToWorld(10, 4, 1.0)
	local crystalBase = Instance.new("Part")
	crystalBase.Name = "BaseCrystal"
	crystalBase.Size = Vector3.new(3.5, 6.5, 3.5)
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
	titleLbl.Text = string.format("⚔️ %s [%s]", data.StageName or stageDef.Name, data.StageId)
	titleLbl.Parent = headerBar

	local crystalHpLbl = Instance.new("TextLabel")
	crystalHpLbl.Size = UDim2.new(0.32, 0, 1, 0)
	crystalHpLbl.Position = UDim2.new(0.64, 0, 0, 0)
	crystalHpLbl.BackgroundTransparency = 1
	crystalHpLbl.TextColor3 = Color3.fromRGB(100, 230, 255)
	crystalHpLbl.TextScaled = true
	crystalHpLbl.Font = Enum.Font.GothamBold
	crystalHpLbl.Text = "💎 Crystal: 100/100"
	crystalHpLbl.Parent = headerBar

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
			nameLbl.Text = roleIcon .. " " .. (def and def.Name or heroUnit.HeroId)
			nameLbl.Parent = bb

			local hpBarBack = Instance.new("Frame")
			hpBarBack.Size = UDim2.new(0.85, 0, 0.22, 0)
			hpBarBack.Position = UDim2.new(0.075, 0, 0.6, 0)
			hpBarBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			hpBarBack.BorderSizePixel = 0
			hpBarBack.Parent = bb

			local hpBarFill = Instance.new("Frame")
			hpBarFill.Size = UDim2.new(1, 0, 1, 0)
			hpBarFill.BackgroundColor3 = Color3.fromRGB(60, 220, 80)
			hpBarFill.BorderSizePixel = 0
			hpBarFill.Parent = hpBarBack

			local maxHp = (def and def.BaseHp) or 1000
			heroVisuals[heroUnit.HeroUid] = {
				Part = heroPart,
				HpFill = hpBarFill,
				Role = heroUnit.Role,
				MaxHp = maxHp,
			}
		end
	end

	-- 5. Create Deterministic Client Simulation Session (100% Matching Ground-Truth!)
	-- Retrieve heroes inventory from UIController
	local UIController = require(script.Parent:WaitForChild("UIController"))
	local heroInventory = UIController.State.Heroes or {}

	local session = BattleSimulation.CreateSession(stageDef, data.Formation, heroInventory)

	type EnemyVisual = {
		Part: Part,
		HpFill: Frame,
		MaxHp: number,
	}
	local enemyVisuals: { [string]: EnemyVisual } = {}

	-- 6. Execute Deterministic Simulation Tick-by-Tick to drive 3D Visual Playback
	task.spawn(function()
		while BattleArenaController.IsPlaying and not session:IsFinished() do
			local dt = 0.1
			local stepEvents = session:Step(dt)

			for _, ev in ipairs(stepEvents) do
				if ev.Type == "EnemySpawned" then
					local enemyPart = Instance.new("Part")
					enemyPart.Name = ev.EnemyId
					enemyPart.Anchored = true
					enemyPart.CanCollide = false

					if ev.IsBoss or ev.Archetype == "boss" then
						enemyPart.Size = Vector3.new(4.5, 6.0, 4.5)
						enemyPart.Material = Enum.Material.Neon
						enemyPart.Color = Color3.fromRGB(180, 20, 40)
					elseif ev.Archetype == "golem" then
						enemyPart.Size = Vector3.new(3.8, 4.6, 3.8)
						enemyPart.Material = Enum.Material.Cobblestone
						enemyPart.Color = Color3.fromRGB(110, 80, 60)
					elseif ev.Archetype == "tank" then
						enemyPart.Size = Vector3.new(3.2, 4.0, 3.2)
						enemyPart.Material = Enum.Material.Slate
						enemyPart.Color = Color3.fromRGB(90, 45, 45)
					elseif ev.Archetype == "runner" then
						enemyPart.Size = Vector3.new(2.0, 2.8, 2.0)
						enemyPart.Material = Enum.Material.Neon
						enemyPart.Color = Color3.fromRGB(255, 120, 30)
					else
						enemyPart.Size = Vector3.new(2.4, 3.2, 2.4)
						enemyPart.Material = Enum.Material.SmoothPlastic
						enemyPart.Color = Color3.fromRGB(220, 50, 40)
					end

					enemyPart.Position = GridToWorld(ev.GridPos.X, ev.GridPos.Y, enemyPart.Size.Y / 2)
					enemyPart.Parent = arena

					-- Enemy Overhead Billboard
					local bb = Instance.new("BillboardGui")
					bb.Size = UDim2.new(3.5, 0, 1.8, 0)
					bb.StudsOffset = Vector3.new(0, enemyPart.Size.Y / 2 + 1.6, 0)
					bb.AlwaysOnTop = true
					bb.Parent = enemyPart

					local nameLbl = Instance.new("TextLabel")
					nameLbl.Size = UDim2.new(1, 0, 0.5, 0)
					nameLbl.BackgroundTransparency = 1
					nameLbl.TextColor3 = (ev.IsBoss or ev.Archetype == "boss") and Color3.fromRGB(255, 215, 60) or Color3.fromRGB(255, 180, 180)
					nameLbl.TextScaled = true
					nameLbl.Font = Enum.Font.GothamBold
					nameLbl.Text = (ev.IsBoss or ev.Archetype == "boss") and ("👑 " .. string.upper(ev.Archetype)) or string.upper(ev.Archetype)
					nameLbl.Parent = bb

					local hpBack = Instance.new("Frame")
					hpBack.Size = UDim2.new(0.85, 0, 0.25, 0)
					hpBack.Position = UDim2.new(0.075, 0, 0.55, 0)
					hpBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
					hpBack.BorderSizePixel = 0
					hpBack.Parent = bb

					local hpFill = Instance.new("Frame")
					hpFill.Size = UDim2.new(1, 0, 1, 0)
					hpFill.BackgroundColor3 = Color3.fromRGB(240, 50, 60)
					hpFill.BorderSizePixel = 0
					hpFill.Parent = hpBack

					enemyVisuals[ev.EnemyId] = {
						Part = enemyPart,
						HpFill = hpFill,
						MaxHp = ev.MaxHp,
					}

				elseif ev.Type == "EnemyMoved" then
					local evis = enemyVisuals[ev.EnemyId]
					if evis and evis.Part and evis.Part.Parent then
						local targetPos = GridToWorld(ev.GridPos.X, ev.GridPos.Y, evis.Part.Size.Y / 2)
						local tweenTime = (0.1 / BattleArenaController.Speed)
						local tween = TweenService:Create(evis.Part, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
							Position = targetPos,
						})
						tween:Play()
					end

				elseif ev.Type == "EnemyBlocked" then
					local evis = enemyVisuals[ev.EnemyId]
					if evis and evis.Part and evis.Part.Parent then
						CreateDamagePopup(evis.Part, "🛑 BLOCKED!", Color3.fromRGB(255, 220, 60))
					end

				elseif ev.Type == "EnemyAttackedBlocker" then
					local hvis = heroVisuals[ev.BlockerUid]
					if hvis and hvis.Part and hvis.Part.Parent then
						local pct = math.clamp(ev.BlockerRemainingHp / ev.BlockerMaxHp, 0, 1)
						hvis.HpFill.Size = UDim2.new(pct, 0, 1, 0)
						CreateDamagePopup(hvis.Part, "-" .. tostring(math.floor(ev.Damage)), Color3.fromRGB(255, 70, 70))
					end

				elseif ev.Type == "HeroAttackedEnemy" then
					local evis = enemyVisuals[ev.EnemyId]
					local hvis = heroVisuals[ev.HeroUid]

					if evis and evis.Part and evis.Part.Parent then
						local pct = math.clamp(ev.EnemyRemainingHp / ev.EnemyMaxHp, 0, 1)
						evis.HpFill.Size = UDim2.new(pct, 0, 1, 0)

						local popupText = "-" .. tostring(math.floor(ev.Damage))
						local popupColor = Color3.fromRGB(255, 255, 255)
						if ev.IsUltimate then
							popupText = "💥 ULTIMATE! -" .. tostring(math.floor(ev.Damage))
							popupColor = Color3.fromRGB(255, 220, 30)
						end
						CreateDamagePopup(evis.Part, popupText, popupColor)

						-- Visual Beam from Hero to Enemy
						if hvis and hvis.Part and hvis.Part.Parent then
							local beam = Instance.new("Part")
							local dist = (hvis.Part.Position - evis.Part.Position).Magnitude
							beam.Size = Vector3.new(0.4, 0.4, dist)
							beam.CFrame = CFrame.lookAt((hvis.Part.Position + evis.Part.Position) / 2, evis.Part.Position)
							beam.Material = Enum.Material.Neon
							beam.Color = ev.IsUltimate and Color3.fromRGB(255, 220, 50) or (hvis.Role == "Caster" and Color3.fromRGB(255, 100, 40) or Color3.fromRGB(255, 255, 120))
							beam.Anchored = true
							beam.CanCollide = false
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
						local pct = math.clamp(ev.TargetRemainingHp / ev.TargetMaxHp, 0, 1)
						targetVis.HpFill.Size = UDim2.new(pct, 0, 1, 0)
						CreateDamagePopup(targetVis.Part, "+" .. tostring(math.floor(ev.Amount)) .. " 💚", Color3.fromRGB(80, 255, 120))

						-- Green healing ring from Medic to Target
						if medicVis and medicVis.Part and medicVis.Part.Parent then
							local healBeam = Instance.new("Part")
							local dist = (medicVis.Part.Position - targetVis.Part.Position).Magnitude
							healBeam.Size = Vector3.new(0.5, 0.5, dist)
							healBeam.CFrame = CFrame.lookAt((medicVis.Part.Position + targetVis.Part.Position) / 2, targetVis.Part.Position)
							healBeam.Material = Enum.Material.Neon
							healBeam.Color = Color3.fromRGB(60, 240, 100)
							healBeam.Anchored = true
							healBeam.CanCollide = false
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
		FinishBattle()
	end)
end

function BattleArenaController.Stop()
	BattleArenaController.IsPlaying = false
	if BattleArenaController.ArenaFolder then
		BattleArenaController.ArenaFolder:Destroy()
		BattleArenaController.ArenaFolder = nil
	end
end

return BattleArenaController
