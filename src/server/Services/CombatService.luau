--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitData = require(Shared:WaitForChild("Data"):WaitForChild("UnitData"))
local MathUtil = require(Shared:WaitForChild("Utils"):WaitForChild("MathUtil"))

local MapService = require(script.Parent:WaitForChild("MapService"))
local GachaService = require(script.Parent:WaitForChild("GachaService"))
local WaveService = require(script.Parent:WaitForChild("WaveService"))

export type PlacedTower = {
	Id: string,
	Owner: Player,
	UnitId: string,
	Level: number,
	Position: Vector3,
	TargetMode: "First" | "Last" | "Strongest" | "Weakest" | "Closest",
	LastFiredTime: number,
	Model: Model,
}

local TARGET_MODES = { "First", "Last", "Strongest", "Weakest", "Closest" }

local CombatService = {
	PlacedTowers = {} :: { [string]: PlacedTower },
	Remotes = {} :: { [string]: RemoteEvent },
}

local function GetRarityStars(rarity: number): string
	local stars = ""
	for _ = 1, rarity do
		stars ..= "★"
	end
	return stars
end

local function UpdateTowerBillboard(tower: PlacedTower)
	local unit = UnitData.Get(tower.UnitId)
	if not unit then
		return
	end

	local head = tower.Model:FindFirstChild("WeaponCore") or tower.Model.PrimaryPart
	if not head then
		return
	end

	local billboard = head:FindFirstChild("TowerGui") :: BillboardGui?
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "TowerGui"
		billboard.Size = UDim2.new(4.5, 0, 1.8, 0)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = head

		local bg = Instance.new("Frame")
		bg.Name = "Bg"
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
		bg.BackgroundTransparency = 0.25
		bg.BorderSizePixel = 0
		bg.Parent = billboard

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = bg

		local stroke = Instance.new("UIStroke")
		stroke.Color = unit.Color
		stroke.Thickness = 1.5
		stroke.Parent = bg

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0.45, 0)
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = bg

		local sub = Instance.new("TextLabel")
		sub.Name = "Sub"
		sub.Size = UDim2.new(1, 0, 0.35, 0)
		sub.Position = UDim2.new(0, 0, 0.45, 0)
		sub.BackgroundTransparency = 1
		sub.TextColor3 = Color3.fromRGB(200, 210, 230)
		sub.TextScaled = true
		sub.Font = Enum.Font.Gotham
		sub.Parent = bg

		local targetLabel = Instance.new("TextLabel")
		targetLabel.Name = "Target"
		targetLabel.Size = UDim2.new(1, 0, 0.2, 0)
		targetLabel.Position = UDim2.new(0, 0, 0.8, 0)
		targetLabel.BackgroundTransparency = 1
		targetLabel.TextColor3 = Color3.fromRGB(130, 220, 255)
		targetLabel.TextScaled = true
		targetLabel.Font = Enum.Font.GothamMedium
		targetLabel.Parent = bg
	end

	local bg = billboard:FindFirstChild("Bg")
	if bg then
		local title = bg:FindFirstChild("Title") :: TextLabel?
		local sub = bg:FindFirstChild("Sub") :: TextLabel?
		local targetLabel = bg:FindFirstChild("Target") :: TextLabel?

		if title then
			title.Text = unit.Name
		end
		if sub then
			sub.Text = GetRarityStars(unit.Rarity) .. " Lv." .. tostring(tower.Level)
		end
		if targetLabel then
			targetLabel.Text = "[" .. tower.TargetMode .. "]"
		end
	end
end

local function BuildTowerModel(unit: UnitData.UnitDefinition, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Tower_" .. unit.Id

	-- Base pedestal
	local base = Instance.new("Part")
	base.Name = "BasePedestal"
	base.Size = Vector3.new(4, 1.2, 4)
	base.Position = position + Vector3.new(0, 0.6, 0)
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.Pavement
	base.Color = Color3.fromRGB(45, 48, 55)
	base.Parent = model

	-- Body pillar
	local body = Instance.new("Part")
	body.Name = "BodyPillar"
	body.Size = Vector3.new(2.4, 4.0, 2.4)
	body.Position = position + Vector3.new(0, 3.2, 0)
	body.Anchored = true
	body.CanCollide = true
	body.Material = Enum.Material.SmoothPlastic
	body.Color = unit.Color
	body.Parent = model

	-- Glowing Weapon / Orb
	local core = Instance.new("Part")
	core.Name = "WeaponCore"
	core.Size = Vector3.new(2, 2, 2)
	core.Position = position + Vector3.new(0, 6.0, 0)
	core.Anchored = true
	core.CanCollide = false
	core.Material = Enum.Material.Neon
	core.Color = unit.AccentColor
	core.Shape = Enum.PartType.Ball
	core.Parent = model

	local light = Instance.new("PointLight")
	light.Color = unit.Color
	light.Range = 14
	light.Brightness = 2
	light.Parent = core

	model.PrimaryPart = base
	return model
end

function CombatService.Init(remotes: { [string]: RemoteEvent })
	CombatService.Remotes = remotes

	RunService.Heartbeat:Connect(function()
		CombatService.UpdateTowers()
	end)
end

function CombatService.PlaceTower(player: Player, unitId: string, position: Vector3)
	local unit = UnitData.Get(unitId)
	if not unit then
		return
	end

	-- Check ownership
	local pState = GachaService.GetState(player)
	if not pState then
		return
	end

	local owns = false
	for _, inst in ipairs(pState.Inventory) do
		if inst.UnitId == unitId then
			owns = true
			break
		end
	end
	if not owns then
		return
	end

	-- Snap to grid
	position = MathUtil.SnapToGrid(position, 4, 0)

	-- Check collision with track
	if MapService.IsPositionOnTrack(position, 2) then
		if CombatService.Remotes.NotifyMessage then
			CombatService.Remotes.NotifyMessage:FireClient(player, "Cannot place tower on the path!", Color3.fromRGB(255, 80, 80))
		end
		return
	end

	-- Check collision with existing towers
	for _, tower in pairs(CombatService.PlacedTowers) do
		if MathUtil.DistanceXZ(tower.Position, position) < 3.8 then
			if CombatService.Remotes.NotifyMessage then
				CombatService.Remotes.NotifyMessage:FireClient(player, "Position already occupied!", Color3.fromRGB(255, 80, 80))
			end
			return
		end
	end

	-- Check and spend gold
	if not GachaService.SpendGold(player, unit.PlacementCost) then
		if CombatService.Remotes.NotifyMessage then
			CombatService.Remotes.NotifyMessage:FireClient(player, "Not enough Gold! Cost: " .. tostring(unit.PlacementCost), Color3.fromRGB(255, 80, 80))
		end
		return
	end

	local towerId = HttpService:GenerateGUID(false)
	local model = BuildTowerModel(unit, position)
	model.Parent = MapService.Folders.Towers

	local tower: PlacedTower = {
		Id = towerId,
		Owner = player,
		UnitId = unitId,
		Level = 0,
		Position = position,
		TargetMode = (unit.Role == "Sniper") and "Strongest" or "First",
		LastFiredTime = 0,
		Model = model,
	}

	model:SetAttribute("TowerId", towerId)
	model:SetAttribute("UnitId", unitId)
	model:SetAttribute("OwnerName", player.Name)

	CombatService.PlacedTowers[towerId] = tower
	UpdateTowerBillboard(tower)

	if CombatService.Remotes.NotifyMessage then
		CombatService.Remotes.NotifyMessage:FireClient(player, "Placed " .. unit.Name .. "!", Color3.fromRGB(100, 255, 120))
	end
end

function CombatService.UpgradeTower(player: Player, towerId: string)
	local tower = CombatService.PlacedTowers[towerId]
	if not tower or tower.Owner ~= player then
		return
	end

	if tower.Level >= UnitData.MaxLevel then
		if CombatService.Remotes.NotifyMessage then
			CombatService.Remotes.NotifyMessage:FireClient(player, "Tower is already at Max Level!", Color3.fromRGB(255, 200, 50))
		end
		return
	end

	local cost = UnitData.GetUpgradeCost(tower.UnitId, tower.Level)
	if not cost then
		return
	end

	if not GachaService.SpendGold(player, cost) then
		if CombatService.Remotes.NotifyMessage then
			CombatService.Remotes.NotifyMessage:FireClient(player, "Not enough Gold to upgrade! Cost: " .. tostring(cost), Color3.fromRGB(255, 80, 80))
		end
		return
	end

	tower.Level += 1
	UpdateTowerBillboard(tower)

	-- Visual upgrade flash
	local core = tower.Model:FindFirstChild("WeaponCore") :: Part?
	if core then
		local origColor = core.Color
		core.Color = Color3.fromRGB(255, 255, 255)
		task.delay(0.2, function()
			if core and core.Parent then
				core.Color = origColor
			end
		end)
	end

	if CombatService.Remotes.NotifyMessage then
		CombatService.Remotes.NotifyMessage:FireClient(player, "Upgraded to Level " .. tostring(tower.Level) .. "!", Color3.fromRGB(120, 220, 255))
	end
end

function CombatService.SellTower(player: Player, towerId: string)
	local tower = CombatService.PlacedTowers[towerId]
	if not tower or tower.Owner ~= player then
		return
	end

	local refund = UnitData.GetSellValue(tower.UnitId, tower.Level)
	GachaService.AddGold(player, refund)

	tower.Model:Destroy()
	CombatService.PlacedTowers[towerId] = nil

	if CombatService.Remotes.NotifyMessage then
		CombatService.Remotes.NotifyMessage:FireClient(player, "Sold tower for +" .. tostring(refund) .. " Gold", Color3.fromRGB(255, 220, 100))
	end
end

function CombatService.SetTargetMode(player: Player, towerId: string, mode: string)
	local tower = CombatService.PlacedTowers[towerId]
	if not tower or tower.Owner ~= player then
		return
	end

	if table.find(TARGET_MODES, mode) then
		tower.TargetMode = mode :: any
		UpdateTowerBillboard(tower)
	end
end

function CombatService.UpdateTowers()
	local now = os.clock()
	local allEnemies = WaveService.GetEnemies()

	for towerId, tower in pairs(CombatService.PlacedTowers) do
		local stats = UnitData.GetStatsAtLevel(tower.UnitId, tower.Level)
		if not stats then
			continue
		end

		if now - tower.LastFiredTime < stats.Cooldown then
			continue
		end

		-- Find enemies in range
		local inRange = {}
		for _, enemy in pairs(allEnemies) do
			if enemy.Hp > 0 then
				local dist = MathUtil.DistanceXZ(tower.Position, enemy.Position)
				if dist <= stats.Range then
					table.insert(inRange, enemy)
				end
			end
		end

		if #inRange == 0 then
			continue
		end

		-- Pick target based on TargetMode
		local targetEnemy = inRange[1]
		local mode = tower.TargetMode

		if mode == "First" then
			local highestProg = -1
			for _, e in ipairs(inRange) do
				if e.Progress > highestProg then
					highestProg = e.Progress
					targetEnemy = e
				end
			end
		elseif mode == "Last" then
			local lowestProg = 9999999
			for _, e in ipairs(inRange) do
				if e.Progress < lowestProg then
					lowestProg = e.Progress
					targetEnemy = e
				end
			end
		elseif mode == "Strongest" then
			local highestHp = -1
			for _, e in ipairs(inRange) do
				if e.Hp > highestHp then
					highestHp = e.Hp
					targetEnemy = e
				end
			end
		elseif mode == "Weakest" then
			local lowestHp = 9999999
			for _, e in ipairs(inRange) do
				if e.Hp < lowestHp then
					lowestHp = e.Hp
					targetEnemy = e
				end
			end
		elseif mode == "Closest" then
			local closestDist = 9999999
			for _, e in ipairs(inRange) do
				local d = MathUtil.DistanceXZ(tower.Position, e.Position)
				if d < closestDist then
					closestDist = d
					targetEnemy = e
				end
			end
		end

		if not targetEnemy then
			continue
		end

		tower.LastFiredTime = now

		-- Apply damage to primary target
		WaveService.DamageEnemy(targetEnemy.Id, stats.Damage, tower.Owner, {
			SlowPercent = stats.SlowPercent,
			BurnDps = stats.BurnDps,
		})

		-- Splash damage
		if stats.SplashRadius and stats.SplashRadius > 0 then
			for _, other in pairs(allEnemies) do
				if other.Id ~= targetEnemy.Id and other.Hp > 0 then
					if MathUtil.DistanceXZ(targetEnemy.Position, other.Position) <= stats.SplashRadius then
						WaveService.DamageEnemy(other.Id, math.floor(stats.Damage * 0.7 + 0.5), tower.Owner, {
							SlowPercent = stats.SlowPercent,
							BurnDps = stats.BurnDps,
						})
					end
				end
			end
		end

		-- Chain Lightning damage
		if stats.ChainTargets and stats.ChainTargets > 0 then
			local chainHit = 0
			local lastPos = targetEnemy.Position
			for _, other in pairs(allEnemies) do
				if other.Id ~= targetEnemy.Id and other.Hp > 0 and chainHit < stats.ChainTargets then
					if MathUtil.DistanceXZ(lastPos, other.Position) <= 16 then
						chainHit += 1
						WaveService.DamageEnemy(other.Id, math.floor(stats.Damage * 0.8 + 0.5), tower.Owner, nil)
						lastPos = other.Position
					end
				end
			end
		end

		-- Replicate firing visual event
		local unitDef = UnitData.Get(tower.UnitId)
		if CombatService.Remotes.TowerFired and unitDef then
			CombatService.Remotes.TowerFired:FireAllClients(
				towerId,
				tower.Position + Vector3.new(0, 6, 0),
				targetEnemy.Position + Vector3.new(0, 1.5, 0),
				unitDef.Role,
				unitDef.Color
			)
		end
	end
end

return CombatService
