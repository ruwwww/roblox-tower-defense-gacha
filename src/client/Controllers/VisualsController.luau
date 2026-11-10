--!strict
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local VisualsController = {
	EffectsFolder = nil :: Folder?,
}

function VisualsController.Init()
	local mapFolder = Workspace:WaitForChild("Map", 10)
	if mapFolder then
		VisualsController.EffectsFolder = mapFolder:WaitForChild("Effects", 5) :: Folder?
	end
end

function VisualsController.OnTowerFired(towerId: string, origin: Vector3, target: Vector3, role: string, color: Color3)
	local container = VisualsController.EffectsFolder or Workspace

	-- Create tracer beam
	local beamPart = Instance.new("Part")
	beamPart.Name = "LaserTracer"
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = color
	beamPart.Transparency = 0.1

	local distance = (target - origin).Magnitude
	beamPart.Size = Vector3.new(0.4, 0.4, distance)
	beamPart.CFrame = CFrame.lookAt((origin + target) / 2, target)
	beamPart.Parent = container

	-- Animate beam fade
	local tween = TweenService:Create(beamPart, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0.1, 0.1, distance),
	})
	tween:Play()
	Debris:AddItem(beamPart, 0.25)

	-- Impact flash at target
	local impact = Instance.new("Part")
	impact.Name = "ImpactFlash"
	impact.Shape = Enum.PartType.Ball
	impact.Size = Vector3.new(1.8, 1.8, 1.8)
	impact.Position = target
	impact.Anchored = true
	impact.CanCollide = false
	impact.Material = Enum.Material.Neon
	impact.Color = color
	impact.Parent = container

	local impactTween = TweenService:Create(impact, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(4, 4, 4),
		Transparency = 1,
	})
	impactTween:Play()
	Debris:AddItem(impact, 0.28)
end

function VisualsController.OnEnemyDamaged(enemyId: string, damage: number, currentHp: number, maxHp: number, isCritical: boolean)
	local container = VisualsController.EffectsFolder or Workspace

	-- Find enemy model in Workspace
	local enemiesFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Enemies")
	if not enemiesFolder then
		return
	end

	local targetModel: Model? = nil
	for _, child in ipairs(enemiesFolder:GetChildren()) do
		if child:IsA("Model") and child.PrimaryPart then
			targetModel = child
			break
		end
	end

	-- Spawn floating damage text
	local popPart = Instance.new("Part")
	popPart.Size = Vector3.new(1, 1, 1)
	popPart.Transparency = 1
	popPart.CanCollide = false
	popPart.Anchored = true
	if targetModel and targetModel.PrimaryPart then
		popPart.Position = targetModel.PrimaryPart.Position + Vector3.new(math.random(-2, 2), 3, math.random(-2, 2))
	else
		return
	end
	popPart.Parent = container

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(3, 0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = popPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "-" .. tostring(math.floor(damage))
	label.TextColor3 = isCritical and Color3.fromRGB(255, 220, 50) or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = billboard

	local floatTween = TweenService:Create(popPart, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popPart.Position + Vector3.new(0, 3.5, 0),
	})
	local textTween = TweenService:Create(label, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	floatTween:Play()
	textTween:Play()
	Debris:AddItem(popPart, 0.7)
end

function VisualsController.OnEnemyDied(enemyId: string, position: Vector3)
	local container = VisualsController.EffectsFolder or Workspace

	local deathBurst = Instance.new("Part")
	deathBurst.Shape = Enum.PartType.Ball
	deathBurst.Size = Vector3.new(2, 2, 2)
	deathBurst.Position = position + Vector3.new(0, 1.5, 0)
	deathBurst.Anchored = true
	deathBurst.CanCollide = false
	deathBurst.Material = Enum.Material.Neon
	deathBurst.Color = Color3.fromRGB(255, 120, 40)
	deathBurst.Parent = container

	local tween = TweenService:Create(deathBurst, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(6, 6, 6),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(deathBurst, 0.4)
end

return VisualsController
