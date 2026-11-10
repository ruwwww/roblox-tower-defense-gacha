--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitData = require(Shared:WaitForChild("Data"):WaitForChild("UnitData"))
local BannerData = require(Shared:WaitForChild("Data"):WaitForChild("BannerData"))
local MathUtil = require(Shared:WaitForChild("Utils"):WaitForChild("MathUtil"))

local PlacementController = require(script.Parent:WaitForChild("PlacementController"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local UIController = {
	Remotes = {} :: { [string]: RemoteEvent },
	ScreenGui = nil :: ScreenGui?,
	State = {
		Gold = 0,
		Gems = 0,
		PityEpic = 0,
		PityLegendary = 0,
		Inventory = {} :: { any },
		Equipped = {} :: { string },
		CurrentWave = 0,
		WaveStatus = "Intermission",
		IntermissionTimer = 0,
		BaseHealth = 100,
		BaseMaxHealth = 100,
		EnemiesAlive = 0,
	},
	SelectedTowerId = nil :: string?,
	Elements = {} :: { [string]: any },
}

local function GetRarityColor(rarity: number): Color3
	if rarity == 3 then
		return Color3.fromRGB(100, 160, 240) -- Blue
	elseif rarity == 4 then
		return Color3.fromRGB(180, 80, 240) -- Purple
	elseif rarity == 5 then
		return Color3.fromRGB(255, 170, 30) -- Gold/Orange
	else
		return Color3.fromRGB(255, 60, 90) -- Red/Crimson
	end
end

local function GetRarityStars(rarity: number): string
	local s = ""
	for _ = 1, rarity do
		s ..= "★"
	end
	return s
end

function UIController.Init(remotes: { [string]: RemoteEvent })
	UIController.Remotes = remotes
	UIController.BuildUI()

	-- Click to inspect placed towers
	local mouse = LocalPlayer:GetMouse()
	mouse.Button1Down:Connect(function()
		if PlacementController.IsPlacing then
			return
		end

		local target = mouse.Target
		if not target then
			return
		end

		local model = target:FindFirstAncestorOfClass("Model")
		if model and model.Parent and model.Parent.Name == "Towers" then
			local towerId = model:GetAttribute("TowerId") :: string?
			local unitId = model:GetAttribute("UnitId") :: string?
			if towerId and unitId then
				UIController.OpenTowerInspect(towerId, unitId, model)
			end
		end
	end)
end

function UIController.BuildUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TowerDefenseGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = PlayerGui
	UIController.ScreenGui = screenGui

	-- 1. TOP BAR CONTAINER
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(0.9, 0, 0, 56)
	topBar.Position = UDim2.new(0.05, 0, 0, 14)
	topBar.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	topBar.BackgroundTransparency = 0.2
	topBar.BorderSizePixel = 0
	topBar.Parent = screenGui

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 10)
	topCorner.Parent = topBar

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = Color3.fromRGB(60, 65, 80)
	topStroke.Thickness = 1.5
	topStroke.Parent = topBar

	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.SpaceBetween
	topLayout.Padding = UDim.new(0, 16)
	topLayout.Parent = topBar

	local topPadding = Instance.new("UIPadding")
	topPadding.PaddingLeft = UDim.new(0, 20)
	topPadding.PaddingRight = UDim.new(0, 20)
	topPadding.Parent = topBar

	-- Crystal Health
	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HpLabel"
	hpLabel.Size = UDim2.new(0.24, 0, 0.75, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3 = Color3.fromRGB(80, 220, 255)
	hpLabel.TextScaled = true
	hpLabel.Font = Enum.Font.GothamBold
	hpLabel.Text = "💎 Crystal: 100/100"
	hpLabel.Parent = topBar
	UIController.Elements.HpLabel = hpLabel

	-- Wave Info & Next Wave Button
	local waveContainer = Instance.new("Frame")
	waveContainer.Name = "WaveContainer"
	waveContainer.Size = UDim2.new(0.38, 0, 0.85, 0)
	waveContainer.BackgroundTransparency = 1
	waveContainer.Parent = topBar

	local waveLayout = Instance.new("UIListLayout")
	waveLayout.FillDirection = Enum.FillDirection.Horizontal
	waveLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	waveLayout.Padding = UDim.new(0, 12)
	waveLayout.Parent = waveContainer

	local waveLabel = Instance.new("TextLabel")
	waveLabel.Name = "WaveLabel"
	waveLabel.Size = UDim2.new(0.65, 0, 1, 0)
	waveLabel.BackgroundTransparency = 1
	waveLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	waveLabel.TextScaled = true
	waveLabel.Font = Enum.Font.GothamBold
	waveLabel.Text = "Wave 1 - Intermission 15s"
	waveLabel.Parent = waveContainer
	UIController.Elements.WaveLabel = waveLabel

	local startWaveBtn = Instance.new("TextButton")
	startWaveBtn.Name = "StartWaveBtn"
	startWaveBtn.Size = UDim2.new(0.32, 0, 0.85, 0)
	startWaveBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 90)
	startWaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	startWaveBtn.TextScaled = true
	startWaveBtn.Font = Enum.Font.GothamBold
	startWaveBtn.Text = "▶ Start"
	startWaveBtn.Parent = waveContainer
	UIController.Elements.StartWaveBtn = startWaveBtn

	local startCorner = Instance.new("UICorner")
	startCorner.CornerRadius = UDim.new(0, 8)
	startCorner.Parent = startWaveBtn

	startWaveBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.StartWaveVote then
			UIController.Remotes.StartWaveVote:FireServer()
		end
	end)

	-- Currencies (Gold & Gems)
	local curContainer = Instance.new("Frame")
	curContainer.Name = "CurrencyContainer"
	curContainer.Size = UDim2.new(0.28, 0, 0.85, 0)
	curContainer.BackgroundTransparency = 1
	curContainer.Parent = topBar

	local curLayout = Instance.new("UIListLayout")
	curLayout.FillDirection = Enum.FillDirection.Horizontal
	curLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	curLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	curLayout.Padding = UDim.new(0, 14)
	curLayout.Parent = curContainer

	local goldLabel = Instance.new("TextLabel")
	goldLabel.Name = "GoldLabel"
	goldLabel.Size = UDim2.new(0.48, 0, 1, 0)
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	goldLabel.TextScaled = true
	goldLabel.Font = Enum.Font.GothamBold
	goldLabel.Text = "💰 0"
	goldLabel.Parent = curContainer
	UIController.Elements.GoldLabel = goldLabel

	local gemsLabel = Instance.new("TextLabel")
	gemsLabel.Name = "GemsLabel"
	gemsLabel.Size = UDim2.new(0.48, 0, 1, 0)
	gemsLabel.BackgroundTransparency = 1
	gemsLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
	gemsLabel.TextScaled = true
	gemsLabel.Font = Enum.Font.GothamBold
	gemsLabel.Text = "💎 0"
	gemsLabel.Parent = curContainer
	UIController.Elements.GemsLabel = gemsLabel

	-- 2. BOTTOM HOTBAR CONTAINER
	local hotbar = Instance.new("Frame")
	hotbar.Name = "Hotbar"
	hotbar.Size = UDim2.new(0.7, 0, 0, 95)
	hotbar.Position = UDim2.new(0.15, 0, 1, -115)
	hotbar.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	hotbar.BackgroundTransparency = 0.25
	hotbar.BorderSizePixel = 0
	hotbar.Parent = screenGui
	UIController.Elements.Hotbar = hotbar

	local hotbarCorner = Instance.new("UICorner")
	hotbarCorner.CornerRadius = UDim.new(0, 12)
	hotbarCorner.Parent = hotbar

	local hotbarStroke = Instance.new("UIStroke")
	hotbarStroke.Color = Color3.fromRGB(55, 60, 75)
	hotbarStroke.Thickness = 1.5
	hotbarStroke.Parent = hotbar

	local hotbarLayout = Instance.new("UIListLayout")
	hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
	hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hotbarLayout.Padding = UDim.new(0, 12)
	hotbarLayout.Parent = hotbar

	-- 3. RIGHT SIDE ACTION BUTTONS (Gacha & Inventory)
	local rightActions = Instance.new("Frame")
	rightActions.Name = "RightActions"
	rightActions.Size = UDim2.new(0, 130, 0, 140)
	rightActions.Position = UDim2.new(1, -150, 0.5, -70)
	rightActions.BackgroundTransparency = 1
	rightActions.Parent = screenGui

	local rightLayout = Instance.new("UIListLayout")
	rightLayout.FillDirection = Enum.FillDirection.Vertical
	rightLayout.Padding = UDim.new(0, 12)
	rightLayout.Parent = rightActions

	local gachaBtn = Instance.new("TextButton")
	gachaBtn.Name = "GachaButton"
	gachaBtn.Size = UDim2.new(1, 0, 0, 60)
	gachaBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 220)
	gachaBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	gachaBtn.TextScaled = true
	gachaBtn.Font = Enum.Font.GothamBold
	gachaBtn.Text = "✨ GACHA"
	gachaBtn.Parent = rightActions

	local gachaCorner = Instance.new("UICorner")
	gachaCorner.CornerRadius = UDim.new(0, 10)
	gachaCorner.Parent = gachaBtn

	local gachaStroke = Instance.new("UIStroke")
	gachaStroke.Color = Color3.fromRGB(255, 210, 80)
	gachaStroke.Thickness = 2
	gachaStroke.Parent = gachaBtn

	gachaBtn.MouseButton1Click:Connect(function()
		UIController.ToggleGachaModal()
	end)

	local invBtn = Instance.new("TextButton")
	invBtn.Name = "InvButton"
	invBtn.Size = UDim2.new(1, 0, 0, 50)
	invBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
	invBtn.TextColor3 = Color3.fromRGB(220, 230, 255)
	invBtn.TextScaled = true
	invBtn.Font = Enum.Font.GothamBold
	invBtn.Text = "🎒 UNITS"
	invBtn.Parent = rightActions

	local invCorner = Instance.new("UICorner")
	invCorner.CornerRadius = UDim.new(0, 10)
	invCorner.Parent = invBtn

	invBtn.MouseButton1Click:Connect(function()
		UIController.ToggleInventoryModal()
	end)

	-- 4. BUILD MODALS
	UIController.BuildGachaModal(screenGui)
	UIController.BuildGachaRevealModal(screenGui)
	UIController.BuildInventoryModal(screenGui)
	UIController.BuildTowerInspectModal(screenGui)
end

function UIController.BuildGachaModal(screenGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "GachaModal"
	modal.Size = UDim2.new(0.65, 0, 0.72, 0)
	modal.Position = UDim2.new(0.175, 0, 0.14, 0)
	modal.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = screenGui
	UIController.Elements.GachaModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 80, 240)
	stroke.Thickness = 2.5
	stroke.Parent = modal

	-- Banner Header
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(255, 220, 80)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.Text = "✨ HEROIC LEGENDS SUMMON ✨"
	header.Parent = modal

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(240, 60, 70)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = modal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	-- Rates Info
	local ratesLabel = Instance.new("TextLabel")
	ratesLabel.Name = "Rates"
	ratesLabel.Size = UDim2.new(0.9, 0, 0, 36)
	ratesLabel.Position = UDim2.new(0.05, 0, 0, 54)
	ratesLabel.BackgroundTransparency = 1
	ratesLabel.TextColor3 = Color3.fromRGB(190, 200, 220)
	ratesLabel.TextScaled = true
	ratesLabel.Font = Enum.Font.GothamMedium
	ratesLabel.Text = "Rates: 3★ Common: 70% | 4★ Rare: 25% | 5★ Epic: 4.5% | 6★ Legendary: 0.5%"
	ratesLabel.Parent = modal

	-- Pity Display
	local pityLabel = Instance.new("TextLabel")
	pityLabel.Name = "PityLabel"
	pityLabel.Size = UDim2.new(0.9, 0, 0, 32)
	pityLabel.Position = UDim2.new(0.05, 0, 0, 92)
	pityLabel.BackgroundTransparency = 1
	pityLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
	pityLabel.TextScaled = true
	pityLabel.Font = Enum.Font.GothamBold
	pityLabel.Text = "Guaranteed 5★ in 10 pulls | Guaranteed 6★ in 50 pulls"
	pityLabel.Parent = modal
	UIController.Elements.PityLabel = pityLabel

	-- Featured Showcase Cards Container
	local showcase = Instance.new("Frame")
	showcase.Name = "Showcase"
	showcase.Size = UDim2.new(0.92, 0, 0.44, 0)
	showcase.Position = UDim2.new(0.04, 0, 0, 130)
	showcase.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
	showcase.BorderSizePixel = 0
	showcase.Parent = modal

	local showCorner = Instance.new("UICorner")
	showCorner.CornerRadius = UDim.new(0, 12)
	showCorner.Parent = showcase

	local showLayout = Instance.new("UIListLayout")
	showLayout.FillDirection = Enum.FillDirection.Horizontal
	showLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	showLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	showLayout.Padding = UDim.new(0, 16)
	showLayout.Parent = showcase

	-- Featured Units cards
	local featuredList = { "solar_paladin", "chrono_overlord", "sniper_assassin" }
	for _, unitId in ipairs(featuredList) do
		local uDef = UnitData.Get(unitId)
		if uDef then
			local card = Instance.new("Frame")
			card.Size = UDim2.new(0.28, 0, 0.85, 0)
			card.BackgroundColor3 = Color3.fromRGB(38, 42, 56)
			card.BorderSizePixel = 0
			card.Parent = showcase

			local cardCorner = Instance.new("UICorner")
			cardCorner.CornerRadius = UDim.new(0, 10)
			cardCorner.Parent = card

			local cardStroke = Instance.new("UIStroke")
			cardStroke.Color = GetRarityColor(uDef.Rarity)
			cardStroke.Thickness = 2
			cardStroke.Parent = card

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(0.9, 0, 0.3, 0)
			name.Position = UDim2.new(0.05, 0, 0.05, 0)
			name.BackgroundTransparency = 1
			name.TextColor3 = Color3.fromRGB(255, 255, 255)
			name.TextScaled = true
			name.Font = Enum.Font.GothamBold
			name.Text = uDef.Name
			name.Parent = card

			local stars = Instance.new("TextLabel")
			stars.Size = UDim2.new(0.9, 0, 0.22, 0)
			stars.Position = UDim2.new(0.05, 0, 0.35, 0)
			stars.BackgroundTransparency = 1
			stars.TextColor3 = GetRarityColor(uDef.Rarity)
			stars.TextScaled = true
			stars.Font = Enum.Font.GothamBlack
			stars.Text = GetRarityStars(uDef.Rarity)
			stars.Parent = card

			local desc = Instance.new("TextLabel")
			desc.Size = UDim2.new(0.9, 0, 0.38, 0)
			desc.Position = UDim2.new(0.05, 0, 0.58, 0)
			desc.BackgroundTransparency = 1
			desc.TextColor3 = Color3.fromRGB(180, 190, 210)
			desc.TextScaled = true
			desc.Font = Enum.Font.Gotham
			desc.Text = uDef.Description
			desc.Parent = card
		end
	end

	-- Summon Action Buttons
	local btnContainer = Instance.new("Frame")
	btnContainer.Name = "ButtonContainer"
	btnContainer.Size = UDim2.new(0.8, 0, 0, 60)
	btnContainer.Position = UDim2.new(0.1, 0, 1, -75)
	btnContainer.BackgroundTransparency = 1
	btnContainer.Parent = modal

	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	btnLayout.Padding = UDim.new(0, 24)
	btnLayout.Parent = btnContainer

	local pull1Btn = Instance.new("TextButton")
	pull1Btn.Name = "Pull1"
	pull1Btn.Size = UDim2.new(0.45, 0, 1, 0)
	pull1Btn.BackgroundColor3 = Color3.fromRGB(45, 110, 210)
	pull1Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	pull1Btn.TextScaled = true
	pull1Btn.Font = Enum.Font.GothamBold
	pull1Btn.Text = "Summon 1x\n100 💎"
	pull1Btn.Parent = btnContainer

	local pull1Corner = Instance.new("UICorner")
	pull1Corner.CornerRadius = UDim.new(0, 10)
	pull1Corner.Parent = pull1Btn

	pull1Btn.MouseButton1Click:Connect(function()
		if UIController.Remotes.RollGacha then
			UIController.Remotes.RollGacha:FireServer("standard", false)
		end
	end)

	local pull10Btn = Instance.new("TextButton")
	pull10Btn.Name = "Pull10"
	pull10Btn.Size = UDim2.new(0.45, 0, 1, 0)
	pull10Btn.BackgroundColor3 = Color3.fromRGB(190, 50, 160)
	pull10Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	pull10Btn.TextScaled = true
	pull10Btn.Font = Enum.Font.GothamBold
	pull10Btn.Text = "Summon 10x\n900 💎 (10% OFF!)"
	pull10Btn.Parent = btnContainer

	local pull10Corner = Instance.new("UICorner")
	pull10Corner.CornerRadius = UDim.new(0, 10)
	pull10Corner.Parent = pull10Btn

	local pull10Stroke = Instance.new("UIStroke")
	pull10Stroke.Color = Color3.fromRGB(255, 215, 60)
	pull10Stroke.Thickness = 2
	pull10Stroke.Parent = pull10Btn

	pull10Btn.MouseButton1Click:Connect(function()
		if UIController.Remotes.RollGacha then
			UIController.Remotes.RollGacha:FireServer("standard", true)
		end
	end)
end

function UIController.BuildGachaRevealModal(screenGui: ScreenGui)
	local revealModal = Instance.new("Frame")
	revealModal.Name = "GachaRevealModal"
	revealModal.Size = UDim2.new(0.85, 0, 0.85, 0)
	revealModal.Position = UDim2.new(0.075, 0, 0.075, 0)
	revealModal.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	revealModal.BorderSizePixel = 0
	revealModal.Visible = false
	revealModal.ZIndex = 20
	revealModal.Parent = screenGui
	UIController.Elements.GachaRevealModal = revealModal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = revealModal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 60)
	stroke.Thickness = 3
	stroke.Parent = revealModal

	local title = Instance.new("TextLabel")
	title.Name = "RevealTitle"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 225, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Text = "✨ SUMMON RESULTS ✨"
	title.ZIndex = 21
	title.Parent = revealModal

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "ResultsGrid"
	grid.Size = UDim2.new(0.9, 0, 0.72, 0)
	grid.Position = UDim2.new(0.05, 0, 0, 70)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ZIndex = 21
	grid.Parent = revealModal
	UIController.Elements.ResultsGrid = grid

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 150, 0, 150)
	gridLayout.CellPadding = UDim2.new(0, 14, 0, 14)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.Parent = grid

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "ConfirmBtn"
	closeBtn.Size = UDim2.new(0, 200, 0, 50)
	closeBtn.Position = UDim2.new(0.5, -100, 1, -65)
	closeBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 100)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "CLAIM ALL"
	closeBtn.ZIndex = 21
	closeBtn.Parent = revealModal

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		revealModal.Visible = false
	end)
end

function UIController.BuildInventoryModal(screenGui: ScreenGui)
	local invModal = Instance.new("Frame")
	invModal.Name = "InventoryModal"
	invModal.Size = UDim2.new(0.7, 0, 0.75, 0)
	invModal.Position = UDim2.new(0.15, 0, 0.125, 0)
	invModal.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	invModal.BorderSizePixel = 0
	invModal.Visible = false
	invModal.ZIndex = 15
	invModal.Parent = screenGui
	UIController.Elements.InventoryModal = invModal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = invModal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 120, 200)
	stroke.Thickness = 2
	stroke.Parent = invModal

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Text = "🎒 UNIT INVENTORY & LOADOUT"
	title.ZIndex = 16
	title.Parent = invModal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(240, 60, 70)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 16
	closeBtn.Parent = invModal

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		invModal.Visible = false
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "InvScroll"
	scroll.Size = UDim2.new(0.92, 0, 0.8, 0)
	scroll.Position = UDim2.new(0.04, 0, 0, 60)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 16
	scroll.Parent = invModal
	UIController.Elements.InvScroll = scroll

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 140, 0, 160)
	grid.CellPadding = UDim2.new(0, 12, 0, 12)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
end

function UIController.BuildTowerInspectModal(screenGui: ScreenGui)
	local inspectFrame = Instance.new("Frame")
	inspectFrame.Name = "InspectModal"
	inspectFrame.Size = UDim2.new(0, 280, 0, 310)
	inspectFrame.Position = UDim2.new(0, 20, 0.5, -155)
	inspectFrame.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
	inspectFrame.BorderSizePixel = 0
	inspectFrame.Visible = false
	inspectFrame.Parent = screenGui
	UIController.Elements.InspectModal = inspectFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = inspectFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 140, 230)
	stroke.Thickness = 2
	stroke.Parent = inspectFrame

	local name = Instance.new("TextLabel")
	name.Name = "TowerName"
	name.Size = UDim2.new(1, 0, 0, 36)
	name.Position = UDim2.new(0, 0, 0, 6)
	name.BackgroundTransparency = 1
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextScaled = true
	name.Font = Enum.Font.GothamBold
	name.Parent = inspectFrame
	UIController.Elements.InspectName = name

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.new(0.9, 0, 0, 80)
	statsLabel.Position = UDim2.new(0.05, 0, 0, 44)
	statsLabel.BackgroundTransparency = 1
	statsLabel.TextColor3 = Color3.fromRGB(190, 205, 225)
	statsLabel.TextScaled = true
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.Parent = inspectFrame
	UIController.Elements.InspectStats = statsLabel

	-- Target Mode Toggle Button
	local targetBtn = Instance.new("TextButton")
	targetBtn.Name = "TargetBtn"
	targetBtn.Size = UDim2.new(0.9, 0, 0, 36)
	targetBtn.Position = UDim2.new(0.05, 0, 0, 130)
	targetBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
	targetBtn.TextColor3 = Color3.fromRGB(130, 220, 255)
	targetBtn.TextScaled = true
	targetBtn.Font = Enum.Font.GothamBold
	targetBtn.Text = "Target: [First]"
	targetBtn.Parent = inspectFrame
	UIController.Elements.InspectTarget = targetBtn

	local targetCorner = Instance.new("UICorner")
	targetCorner.CornerRadius = UDim.new(0, 8)
	targetCorner.Parent = targetBtn

	local targetModes = { "First", "Last", "Strongest", "Weakest", "Closest" }
	targetBtn.MouseButton1Click:Connect(function()
		if not UIController.SelectedTowerId then
			return
		end
		local currentText = targetBtn.Text
		local curMode = currentText:match("%[(.-)%]") or "First"
		local nextIdx = 1
		for i, m in ipairs(targetModes) do
			if m == curMode then
				nextIdx = (i % #targetModes) + 1
				break
			end
		end
		local newMode = targetModes[nextIdx]
		targetBtn.Text = "Target: [" .. newMode .. "]"
		if UIController.Remotes.SetTargetMode then
			UIController.Remotes.SetTargetMode:FireServer(UIController.SelectedTowerId, newMode)
		end
	end)

	-- Upgrade Button
	local upgradeBtn = Instance.new("TextButton")
	upgradeBtn.Name = "UpgradeBtn"
	upgradeBtn.Size = UDim2.new(0.9, 0, 0, 42)
	upgradeBtn.Position = UDim2.new(0.05, 0, 0, 175)
	upgradeBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
	upgradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgradeBtn.TextScaled = true
	upgradeBtn.Font = Enum.Font.GothamBold
	upgradeBtn.Text = "UPGRADE (+Stats) - $150"
	upgradeBtn.Parent = inspectFrame
	UIController.Elements.InspectUpgrade = upgradeBtn

	local upCorner = Instance.new("UICorner")
	upCorner.CornerRadius = UDim.new(0, 8)
	upCorner.Parent = upgradeBtn

	upgradeBtn.MouseButton1Click:Connect(function()
		if UIController.SelectedTowerId and UIController.Remotes.UpgradeTower then
			UIController.Remotes.UpgradeTower:FireServer(UIController.SelectedTowerId)
		end
	end)

	-- Sell Button
	local sellBtn = Instance.new("TextButton")
	sellBtn.Name = "SellBtn"
	sellBtn.Size = UDim2.new(0.9, 0, 0, 36)
	sellBtn.Position = UDim2.new(0.05, 0, 0, 225)
	sellBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
	sellBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	sellBtn.TextScaled = true
	sellBtn.Font = Enum.Font.GothamBold
	sellBtn.Text = "SELL (Refund 70%)"
	sellBtn.Parent = inspectFrame
	UIController.Elements.InspectSell = sellBtn

	local sellCorner = Instance.new("UICorner")
	sellCorner.CornerRadius = UDim.new(0, 8)
	sellCorner.Parent = sellBtn

	sellBtn.MouseButton1Click:Connect(function()
		if UIController.SelectedTowerId and UIController.Remotes.SellTower then
			UIController.Remotes.SellTower:FireServer(UIController.SelectedTowerId)
			inspectFrame.Visible = false
			UIController.SelectedTowerId = nil
		end
	end)

	-- Close
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0.9, 0, 0, 28)
	closeBtn.Position = UDim2.new(0.05, 0, 0, 270)
	closeBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
	closeBtn.TextColor3 = Color3.fromRGB(160, 170, 190)
	closeBtn.Text = "Close"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamMedium
	closeBtn.Parent = inspectFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		inspectFrame.Visible = false
		UIController.SelectedTowerId = nil
	end)
end

function UIController.OpenTowerInspect(towerId: string, unitId: string, model: Model)
	local uDef = UnitData.Get(unitId)
	if not uDef then
		return
	end

	UIController.SelectedTowerId = towerId
	local inspect = UIController.Elements.InspectModal
	inspect.Visible = true

	local name = UIController.Elements.InspectName
	local stats = UIController.Elements.InspectStats
	local upgrade = UIController.Elements.InspectUpgrade

	name.Text = uDef.Name .. " " .. GetRarityStars(uDef.Rarity)
	stats.Text = string.format("Role: %s\nDamage: %d\nRange: %d studs\nCooldown: %.2fs",
		uDef.Role, uDef.Stats.Damage, uDef.Stats.Range, uDef.Stats.Cooldown)

	local upCost = UnitData.GetUpgradeCost(unitId, 0)
	if upCost then
		upgrade.Text = "UPGRADE - $" .. tostring(upCost)
	else
		upgrade.Text = "MAX LEVEL"
	end
end

function UIController.ToggleGachaModal()
	local modal = UIController.Elements.GachaModal
	modal.Visible = not modal.Visible
end

function UIController.ToggleInventoryModal()
	local modal = UIController.Elements.InventoryModal
	modal.Visible = not modal.Visible
	if modal.Visible then
		UIController.RefreshInventoryGrid()
	end
end

function UIController.RefreshInventoryGrid()
	local scroll = UIController.Elements.InvScroll
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, item in ipairs(UIController.State.Inventory) do
		local uDef = UnitData.Get(item.UnitId)
		if uDef then
			local card = Instance.new("Frame")
			card.Name = "InvCard_" .. tostring(index)
			card.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
			card.BorderSizePixel = 0
			card.Parent = scroll

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 10)
			corner.Parent = card

			local stroke = Instance.new("UIStroke")
			stroke.Color = GetRarityColor(uDef.Rarity)
			stroke.Thickness = 2
			stroke.Parent = card

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(0.9, 0, 0.25, 0)
			name.Position = UDim2.new(0.05, 0, 0.05, 0)
			name.BackgroundTransparency = 1
			name.TextColor3 = Color3.fromRGB(255, 255, 255)
			name.TextScaled = true
			name.Font = Enum.Font.GothamBold
			name.Text = uDef.Name
			name.Parent = card

			local stars = Instance.new("TextLabel")
			stars.Size = UDim2.new(0.9, 0, 0.18, 0)
			stars.Position = UDim2.new(0.05, 0, 0.32, 0)
			stars.BackgroundTransparency = 1
			stars.TextColor3 = GetRarityColor(uDef.Rarity)
			stars.TextScaled = true
			stars.Font = Enum.Font.GothamBlack
			stars.Text = GetRarityStars(uDef.Rarity)
			stars.Parent = card

			local role = Instance.new("TextLabel")
			role.Size = UDim2.new(0.9, 0, 0.18, 0)
			role.Position = UDim2.new(0.05, 0, 0.52, 0)
			role.BackgroundTransparency = 1
			role.TextColor3 = Color3.fromRGB(150, 170, 200)
			role.TextScaled = true
			role.Font = Enum.Font.Gotham
			role.Text = uDef.Role
			role.Parent = card

			local isEquipped = table.find(UIController.State.Equipped, item.UnitId) ~= nil
			local equipBtn = Instance.new("TextButton")
			equipBtn.Size = UDim2.new(0.9, 0, 0.22, 0)
			equipBtn.Position = UDim2.new(0.05, 0, 0.72, 0)
			equipBtn.BackgroundColor3 = isEquipped and Color3.fromRGB(60, 70, 90) or Color3.fromRGB(40, 160, 90)
			equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			equipBtn.TextScaled = true
			equipBtn.Font = Enum.Font.GothamBold
			equipBtn.Text = isEquipped and "EQUIPPED" or "EQUIP"
			equipBtn.Parent = card

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0, 6)
			btnCorner.Parent = equipBtn

			if not isEquipped then
				equipBtn.MouseButton1Click:Connect(function()
					if UIController.Remotes.EquipUnit then
						UIController.Remotes.EquipUnit:FireServer(item.UnitId, #UIController.State.Equipped + 1)
						task.wait(0.2)
						UIController.RefreshInventoryGrid()
					end
				end)
			end
		end
	end
end

function UIController.UpdateHotbar()
	local hotbar = UIController.Elements.Hotbar
	for _, child in ipairs(hotbar:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for index, unitId in ipairs(UIController.State.Equipped) do
		local uDef = UnitData.Get(unitId)
		if uDef then
			local slotBtn = Instance.new("TextButton")
			slotBtn.Name = "Slot_" .. tostring(index)
			slotBtn.Size = UDim2.new(0, 110, 0, 80)
			slotBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
			slotBtn.BorderSizePixel = 0
			slotBtn.Text = ""
			slotBtn.Parent = hotbar

			local slotCorner = Instance.new("UICorner")
			slotCorner.CornerRadius = UDim.new(0, 10)
			slotCorner.Parent = slotBtn

			local slotStroke = Instance.new("UIStroke")
			slotStroke.Color = GetRarityColor(uDef.Rarity)
			slotStroke.Thickness = 2
			slotStroke.Parent = slotBtn

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(0.9, 0, 0.3, 0)
			name.Position = UDim2.new(0.05, 0, 0.05, 0)
			name.BackgroundTransparency = 1
			name.TextColor3 = Color3.fromRGB(255, 255, 255)
			name.TextScaled = true
			name.Font = Enum.Font.GothamBold
			name.Text = uDef.Name
			name.Parent = slotBtn

			local stars = Instance.new("TextLabel")
			stars.Size = UDim2.new(0.9, 0, 0.22, 0)
			stars.Position = UDim2.new(0.05, 0, 0.36, 0)
			stars.BackgroundTransparency = 1
			stars.TextColor3 = GetRarityColor(uDef.Rarity)
			stars.TextScaled = true
			stars.Font = Enum.Font.GothamBlack
			stars.Text = GetRarityStars(uDef.Rarity)
			stars.Parent = slotBtn

			local cost = Instance.new("TextLabel")
			cost.Size = UDim2.new(0.9, 0, 0.32, 0)
			cost.Position = UDim2.new(0.05, 0, 0.62, 0)
			cost.BackgroundTransparency = 1
			cost.TextColor3 = Color3.fromRGB(255, 215, 60)
			cost.TextScaled = true
			cost.Font = Enum.Font.GothamBold
			cost.Text = "$" .. tostring(uDef.PlacementCost)
			cost.Parent = slotBtn

			slotBtn.MouseButton1Click:Connect(function()
				PlacementController.StartPlacement(unitId)
			end)
		end
	end
end

function UIController.OnStateSync(data: any)
	for key, val in pairs(data) do
		UIController.State[key] = val
	end

	-- Update Top Bar labels
	local hpLabel = UIController.Elements.HpLabel
	if hpLabel then
		hpLabel.Text = string.format("💎 Crystal: %d/%d HP", UIController.State.BaseHealth, UIController.State.BaseMaxHealth)
		if UIController.State.BaseHealth <= 30 then
			hpLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
		else
			hpLabel.TextColor3 = Color3.fromRGB(80, 220, 255)
		end
	end

	local waveLabel = UIController.Elements.WaveLabel
	local startWaveBtn = UIController.Elements.StartWaveBtn
	if waveLabel then
		if UIController.State.WaveStatus == "Intermission" then
			waveLabel.Text = string.format("Wave %d - Intermission (%ds)", UIController.State.CurrentWave + 1, UIController.State.IntermissionTimer)
			if startWaveBtn then
				startWaveBtn.Visible = true
			end
		elseif UIController.State.WaveStatus == "GameOver" then
			waveLabel.Text = "GAME OVER!"
			if startWaveBtn then
				startWaveBtn.Visible = false
			end
		else
			waveLabel.Text = string.format("Wave %d - In Combat [%d foes]", UIController.State.CurrentWave, UIController.State.EnemiesAlive or 0)
			if startWaveBtn then
				startWaveBtn.Visible = false
			end
		end
	end

	local goldLabel = UIController.Elements.GoldLabel
	if goldLabel then
		goldLabel.Text = "💰 " .. MathUtil.FormatNumber(UIController.State.Gold)
	end

	local gemsLabel = UIController.Elements.GemsLabel
	if gemsLabel then
		gemsLabel.Text = "💎 " .. MathUtil.FormatNumber(UIController.State.Gems)
	end

	local pityLabel = UIController.Elements.PityLabel
	if pityLabel then
		local epicPityRem = math.max(0, 10 - UIController.State.PityEpic)
		local legPityRem = math.max(0, 50 - UIController.State.PityLegendary)
		pityLabel.Text = string.format("Guaranteed 5★ in %d pulls | Guaranteed 6★ in %d pulls", epicPityRem, legPityRem)
	end

	UIController.UpdateHotbar()
end

function UIController.OnGachaResult(rolledUnits: { any })
	local reveal = UIController.Elements.GachaRevealModal
	local grid = UIController.Elements.ResultsGrid
	if not reveal or not grid then
		return
	end

	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	reveal.Visible = true

	for i, unit in ipairs(rolledUnits) do
		local card = Instance.new("Frame")
		card.Name = "ResultCard_" .. tostring(i)
		card.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
		card.BorderSizePixel = 0
		card.Parent = grid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = card

		local stroke = Instance.new("UIStroke")
		stroke.Color = GetRarityColor(unit.Rarity)
		stroke.Thickness = (unit.Rarity >= 5) and 3 or 1.5
		stroke.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0.9, 0, 0.35, 0)
		name.Position = UDim2.new(0.05, 0, 0.1, 0)
		name.BackgroundTransparency = 1
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.TextScaled = true
		name.Font = Enum.Font.GothamBold
		name.Text = unit.Name
		name.Parent = card

		local stars = Instance.new("TextLabel")
		stars.Size = UDim2.new(0.9, 0, 0.3, 0)
		stars.Position = UDim2.new(0.05, 0, 0.5, 0)
		stars.BackgroundTransparency = 1
		stars.TextColor3 = GetRarityColor(unit.Rarity)
		stars.TextScaled = true
		stars.Font = Enum.Font.GothamBlack
		stars.Text = GetRarityStars(unit.Rarity)
		stars.Parent = card
	end
end

function UIController.ShowNotification(message: string, color: Color3?)
	local screenGui = UIController.ScreenGui
	if not screenGui then
		return
	end

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(0, 360, 0, 46)
	toast.Position = UDim2.new(0.5, -180, 0, 80)
	toast.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
	toast.BorderSizePixel = 0
	toast.ZIndex = 50
	toast.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast

	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(100, 200, 255)
	stroke.Thickness = 1.5
	stroke.Parent = toast

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.92, 0, 0.8, 0)
	label.Position = UDim2.new(0.04, 0, 0.1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = message
	label.ZIndex = 51
	label.Parent = toast

	task.delay(3.0, function()
		if toast and toast.Parent then
			local fade = TweenService:Create(toast, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			})
			fade:Play()
			task.wait(0.5)
			toast:Destroy()
		end
	end)
end

return UIController
