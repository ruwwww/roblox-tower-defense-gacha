--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitData = require(Shared:WaitForChild("Data"):WaitForChild("UnitData"))
local MathUtil = require(Shared:WaitForChild("Utils"):WaitForChild("MathUtil"))

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local PlacementController = {
	IsPlacing = false,
	SelectedUnitId = nil :: string?,
	PreviewModel = nil :: Model?,
	RangeCircle = nil :: Part?,
	Remotes = {} :: { [string]: RemoteEvent },
	RenderConnection = nil :: RBXScriptConnection?,
	InputConnection = nil :: RBXScriptConnection?,
}

local function CreatePreviewModel(unit: UnitData.UnitDefinition): Model
	local model = Instance.new("Model")
	model.Name = "PlacementPreview"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(4, 1.2, 4)
	base.Anchored = true
	base.CanCollide = false
	base.Transparency = 0.5
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(100, 255, 120)
	base.Parent = model

	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Size = Vector3.new(2.4, 4.0, 2.4)
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Transparency = 0.5
	pillar.Material = Enum.Material.SmoothPlastic
	pillar.Color = unit.Color
	pillar.Parent = model

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(2, 2, 2)
	core.Shape = Enum.PartType.Ball
	core.Anchored = true
	core.CanCollide = false
	core.Transparency = 0.3
	core.Material = Enum.Material.Neon
	core.Color = unit.AccentColor
	core.Parent = model

	model.PrimaryPart = base
	return model
end

local function CreateRangeCircle(rangeRadius: number): Part
	local circle = Instance.new("Part")
	circle.Name = "RangePreview"
	circle.Shape = Enum.PartType.Cylinder
	circle.Size = Vector3.new(0.2, rangeRadius * 2, rangeRadius * 2)
	circle.Anchored = true
	circle.CanCollide = false
	circle.Transparency = 0.75
	circle.Material = Enum.Material.Neon
	circle.Color = Color3.fromRGB(100, 220, 255)
	circle.Orientation = Vector3.new(0, 0, 90) -- Orient flat on ground
	return circle
end

function PlacementController.Init(remotes: { [string]: RemoteEvent })
	PlacementController.Remotes = remotes

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not PlacementController.IsPlacing then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			PlacementController.ConfirmPlacement()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
			PlacementController.CancelPlacement()
		end
	end)
end

function PlacementController.StartPlacement(unitId: string)
	local unit = UnitData.Get(unitId)
	if not unit then
		return
	end

	PlacementController.CancelPlacement()

	PlacementController.IsPlacing = true
	PlacementController.SelectedUnitId = unitId

	local preview = CreatePreviewModel(unit)
	preview.Parent = Workspace
	PlacementController.PreviewModel = preview

	local rangeCircle = CreateRangeCircle(unit.Stats.Range)
	rangeCircle.Parent = Workspace
	PlacementController.RangeCircle = rangeCircle

	PlacementController.RenderConnection = RunService.RenderStepped:Connect(function()
		PlacementController.UpdatePreview()
	end)
end

function PlacementController.CancelPlacement()
	PlacementController.IsPlacing = false
	PlacementController.SelectedUnitId = nil

	if PlacementController.RenderConnection then
		PlacementController.RenderConnection:Disconnect()
		PlacementController.RenderConnection = nil
	end

	if PlacementController.PreviewModel then
		PlacementController.PreviewModel:Destroy()
		PlacementController.PreviewModel = nil
	end

	if PlacementController.RangeCircle then
		PlacementController.RangeCircle:Destroy()
		PlacementController.RangeCircle = nil
	end
end

function PlacementController.UpdatePreview()
	if not PlacementController.IsPlacing or not PlacementController.PreviewModel then
		return
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local ignoreList = { PlacementController.PreviewModel, PlacementController.RangeCircle }
	if LocalPlayer.Character then
		table.insert(ignoreList, LocalPlayer.Character)
	end
	local mapFolder = Workspace:FindFirstChild("Map")
	if mapFolder then
		local enemies = mapFolder:FindFirstChild("Enemies")
		if enemies then
			table.insert(ignoreList, enemies)
		end
	end
	rayParams.FilterDescendantsInstances = ignoreList

	local mouseRay = Workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
	local hit = Workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 500, rayParams)

	if hit and hit.Instance then
		local rawPos = hit.Position
		local snappedPos = MathUtil.SnapToGrid(rawPos, 4, 0)

		local base = PlacementController.PreviewModel:FindFirstChild("Base") :: Part?
		local pillar = PlacementController.PreviewModel:FindFirstChild("Pillar") :: Part?
		local core = PlacementController.PreviewModel:FindFirstChild("Core") :: Part?

		if base then
			base.Position = snappedPos + Vector3.new(0, 0.6, 0)
		end
		if pillar then
			pillar.Position = snappedPos + Vector3.new(0, 3.2, 0)
		end
		if core then
			core.Position = snappedPos + Vector3.new(0, 6.0, 0)
		end

		if PlacementController.RangeCircle then
			PlacementController.RangeCircle.CFrame = CFrame.new(snappedPos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		end

		-- Validate placement location
		local isValid = true

		-- Check track collision
		local trackFolder = mapFolder and mapFolder:FindFirstChild("Track")
		if trackFolder then
			for _, part in ipairs(trackFolder:GetChildren()) do
				if part:IsA("BasePart") and MathUtil.DistanceXZ(part.Position, snappedPos) < 10 then
					isValid = false
					break
				end
			end
		end

		-- Check distance to existing towers
		local towersFolder = mapFolder and mapFolder:FindFirstChild("Towers")
		if towersFolder then
			for _, towerModel in ipairs(towersFolder:GetChildren()) do
				if towerModel:IsA("Model") and towerModel.PrimaryPart then
					if MathUtil.DistanceXZ(towerModel.PrimaryPart.Position, snappedPos) < 3.8 then
						isValid = false
						break
					end
				end
			end
		end

		local tint = isValid and Color3.fromRGB(100, 255, 120) or Color3.fromRGB(255, 60, 60)
		if base then
			base.Color = tint
		end
		if PlacementController.RangeCircle then
			PlacementController.RangeCircle.Color = isValid and Color3.fromRGB(100, 220, 255) or Color3.fromRGB(255, 60, 60)
		end
	end
end

function PlacementController.ConfirmPlacement()
	if not PlacementController.IsPlacing or not PlacementController.SelectedUnitId or not PlacementController.PreviewModel then
		return
	end

	local base = PlacementController.PreviewModel:FindFirstChild("Base") :: Part?
	if not base then
		return
	end

	local pos = MathUtil.SnapToGrid(base.Position, 4, 0)

	if PlacementController.Remotes.PlaceTower then
		PlacementController.Remotes.PlaceTower:FireServer(PlacementController.SelectedUnitId, pos)
	end

	PlacementController.CancelPlacement()
end

return PlacementController
