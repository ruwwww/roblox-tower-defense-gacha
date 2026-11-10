--!strict
local Workspace = game:GetService("Workspace")

local LobbyService = {
	TownFolder = nil :: Folder?,
}

local function CreateBuilding(name: string, pos: Vector3, size: Vector3, color: Color3, labelText: string): Model
	local model = Instance.new("Model")
	model.Name = name

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = size
	base.Position = pos + Vector3.new(0, size.Y / 2, 0)
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.Cobblestone
	base.Color = color
	base.Parent = model

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(size.X * 0.6, 3, size.Z * 0.6)
	core.Position = base.Position + Vector3.new(0, size.Y / 2 + 1.5, 0)
	core.Anchored = true
	core.CanCollide = false
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(255, 230, 100)
	core.Parent = model

	-- Floating interaction billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LabelGui"
	billboard.Size = UDim2.new(5, 0, 1.8, 0)
	billboard.StudsOffset = Vector3.new(0, size.Y / 2 + 4.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = base

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 60)
	stroke.Thickness = 2
	stroke.Parent = frame

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Text = labelText
	text.Parent = frame

	-- Interaction ClickDetector
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 32
	click.Parent = base

	model.PrimaryPart = base
	return model
end

function LobbyService.SetupLobby()
	local existing = Workspace:FindFirstChild("LobbyTown")
	if existing then
		existing:Destroy()
	end

	local townFolder = Instance.new("Folder")
	townFolder.Name = "LobbyTown"
	townFolder.Parent = Workspace
	LobbyService.TownFolder = townFolder

	-- Spawn Location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0, 0)
	spawn.Anchored = true
	spawn.Material = Enum.Material.Marble
	spawn.Color = Color3.fromRGB(220, 225, 235)
	spawn.Duration = 0
	spawn.Parent = townFolder

	-- 1. Campaign Gate with AFK Loot Chest (North)
	local campaignGate = CreateBuilding("CampaignGate", Vector3.new(0, 0, -50), Vector3.new(20, 12, 10), Color3.fromRGB(60, 70, 95), "⚔️ CAMPAIGN EXPEDITION\n(PVE Stages)")
	campaignGate.Parent = townFolder

	-- Floating AFK Chest right in front of the gate
	local chest = Instance.new("Part")
	chest.Name = "AfkLootChest"
	chest.Size = Vector3.new(4, 3, 3)
	chest.Position = Vector3.new(0, 2.5, -36)
	chest.Anchored = true
	chest.CanCollide = true
	chest.Material = Enum.Material.Neon
	chest.Color = Color3.fromRGB(255, 200, 30)
	chest.Parent = townFolder

	local chestGui = Instance.new("BillboardGui")
	chestGui.Size = UDim2.new(4.5, 0, 1.4, 0)
	chestGui.StudsOffset = Vector3.new(0, 3, 0)
	chestGui.AlwaysOnTop = true
	chestGui.Parent = chest

	local chestLabel = Instance.new("TextLabel")
	chestLabel.Size = UDim2.new(1, 0, 1, 0)
	chestLabel.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	chestLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	chestLabel.TextScaled = true
	chestLabel.Font = Enum.Font.GothamBlack
	chestLabel.Text = "🎁 AFK LOOT CHEST\n[Click to Claim]"
	chestLabel.Parent = chestGui

	local chestCorner = Instance.new("UICorner")
	chestCorner.CornerRadius = UDim.new(0, 8)
	chestCorner.Parent = chestLabel

	local chestClick = Instance.new("ClickDetector")
	chestClick.MaxActivationDistance = 28
	chestClick.Parent = chest

	-- 2. Summon Altar (East)
	local summonAltar = CreateBuilding("SummonAltar", Vector3.new(50, 0, 0), Vector3.new(14, 6, 14), Color3.fromRGB(90, 45, 120), "✨ SUMMON ALTAR\n(Hero Gacha)")
	summonAltar.Parent = townFolder

	-- 3. Hero Citadel & Backpack (West)
	local heroAltar = CreateBuilding("HeroAltar", Vector3.new(-50, 0, 0), Vector3.new(16, 8, 14), Color3.fromRGB(45, 80, 120), "🎒 HERO CITADEL\n(Backpack & Level Up)")
	heroAltar.Parent = townFolder

	-- 4. Blacksmith Forge (South-East)
	local forge = CreateBuilding("BlacksmithForge", Vector3.new(35, 0, 40), Vector3.new(12, 6, 12), Color3.fromRGB(110, 50, 40), "🔨 BLACKSMITH\n(Equipment & Crafting)")
	forge.Parent = townFolder

	-- 5. Arena Gate / PVP (South-West)
	local arenaGate = CreateBuilding("ArenaGate", Vector3.new(-35, 0, 40), Vector3.new(14, 8, 10), Color3.fromRGB(80, 50, 50), "🏆 PVP ARENA\n(Coming Soon)")
	arenaGate.Parent = townFolder

	print("[LobbyService] 3D Town Hub, Stands, and AFK Chest successfully built in Workspace.")
end

return LobbyService
