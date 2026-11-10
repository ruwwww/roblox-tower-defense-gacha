--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroData = require(Shared:WaitForChild("Data"):WaitForChild("HeroData"))
local EquipmentData = require(Shared:WaitForChild("Data"):WaitForChild("EquipmentData"))
local StageData = require(Shared:WaitForChild("Data"):WaitForChild("StageData"))
local MathUtil = require(Shared:WaitForChild("Utils"):WaitForChild("MathUtil"))

local BattleArenaController = require(script.Parent:WaitForChild("BattleArenaController"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local UIController = {
	Remotes = {} :: { [string]: RemoteEvent },
	ScreenGui = nil :: ScreenGui?,
	State = {
		Gold = 0,
		Diamonds = 0,
		Elixir = 0,
		Scrolls = 0,
		HighestClearedStage = "1-0",
		CurrentStage = "1-1",
		AfkLastClaimTime = 0,
		Heroes = {} :: { [string]: any },
		Formation = {} :: { string },
		EquipmentInventory = {} :: { any },
	},
	SelectedHeroUid = nil :: string?,
	SelectedStageId = "1-1",
	Elements = {} :: { [string]: any },
}

local function GetStarColor(star: number): Color3
	if star <= 3 then
		return Color3.fromRGB(100, 160, 240)
	elseif star == 4 then
		return Color3.fromRGB(180, 80, 240)
	elseif star == 5 then
		return Color3.fromRGB(255, 180, 30)
	else
		return Color3.fromRGB(255, 60, 90)
	end
end

local function GetStars(star: number): string
	local s = ""
	for _ = 1, star do
		s ..= "★"
	end
	return s
end

function UIController.Init(remotes: { [string]: RemoteEvent })
	UIController.Remotes = remotes
	BattleArenaController.Init()

	UIController.BuildHUD()
	UIController.BuildCampaignModal()
	UIController.BuildBackpackModal()
	UIController.BuildFormationModal()
	UIController.BuildSummonModal()
	UIController.BuildGachaRevealModal()
	UIController.BuildBattleResultModal()
end

function UIController.BuildHUD()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "IdleArknightsGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = PlayerGui
	UIController.ScreenGui = screenGui

	-- TOP RESOURCE BAR
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(0.92, 0, 0, 52)
	topBar.Position = UDim2.new(0.04, 0, 0, 12)
	topBar.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	topBar.BackgroundTransparency = 0.2
	topBar.BorderSizePixel = 0
	topBar.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = topBar

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(65, 70, 85)
	stroke.Thickness = 1.5
	stroke.Parent = topBar

	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLayout.Padding = UDim.new(0, 18)
	topLayout.Parent = topBar

	local function CreateResourceTag(name: string, icon: string, color: Color3): TextLabel
		local lbl = Instance.new("TextLabel")
		lbl.Name = name
		lbl.Size = UDim2.new(0, 130, 0, 36)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = color
		lbl.TextScaled = true
		lbl.Font = Enum.Font.GothamBold
		lbl.Text = icon .. " 0"
		lbl.Parent = topBar
		return lbl
	end

	UIController.Elements.GoldLabel = CreateResourceTag("Gold", "💰", Color3.fromRGB(255, 215, 60))
	UIController.Elements.ElixirLabel = CreateResourceTag("Elixir", "🧪", Color3.fromRGB(180, 100, 255))
	UIController.Elements.DiamondLabel = CreateResourceTag("Diamonds", "💎", Color3.fromRGB(100, 220, 255))
	UIController.Elements.ScrollLabel = CreateResourceTag("Scrolls", "📜", Color3.fromRGB(255, 140, 100))

	-- Fast AFK button on Top Bar
	local fastAfkBtn = Instance.new("TextButton")
	fastAfkBtn.Name = "FastAfkBtn"
	fastAfkBtn.Size = UDim2.new(0, 120, 0, 36)
	fastAfkBtn.BackgroundColor3 = Color3.fromRGB(45, 130, 220)
	fastAfkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	fastAfkBtn.TextScaled = true
	fastAfkBtn.Font = Enum.Font.GothamBold
	fastAfkBtn.Text = "⚡ Fast 120m"
	fastAfkBtn.Parent = topBar

	local fastCorner = Instance.new("UICorner")
	fastCorner.CornerRadius = UDim.new(0, 8)
	fastCorner.Parent = fastAfkBtn

	fastAfkBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.FastAfkClaim then
			UIController.Remotes.FastAfkClaim:FireServer()
		end
	end)

	-- RIGHT ACTION MENU
	local rightMenu = Instance.new("Frame")
	rightMenu.Name = "RightMenu"
	rightMenu.Size = UDim2.new(0, 150, 0, 340)
	rightMenu.Position = UDim2.new(1, -165, 0.5, -170)
	rightMenu.BackgroundTransparency = 1
	rightMenu.Parent = screenGui

	local menuLayout = Instance.new("UIListLayout")
	menuLayout.FillDirection = Enum.FillDirection.Vertical
	menuLayout.Padding = UDim.new(0, 10)
	menuLayout.Parent = rightMenu

	local function CreateMenuBtn(name: string, text: string, color: Color3, callback: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(1, 0, 0, 48)
		btn.BackgroundColor3 = color
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Text = text
		btn.Parent = rightMenu

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 10)
		btnCorner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 215, 80)
		stroke.Thickness = 1.5
		stroke.Parent = btn

		btn.MouseButton1Click:Connect(callback)
		return btn
	end

	CreateMenuBtn("CampaignBtn", "⚔️ CAMPAIGN", Color3.fromRGB(200, 60, 60), function()
		UIController.ToggleModal("CampaignModal")
	end)

	CreateMenuBtn("FormationBtn", "🛡️ SQUAD", Color3.fromRGB(40, 150, 110), function()
		UIController.ToggleModal("FormationModal")
	end)

	CreateMenuBtn("HeroesBtn", "🎒 HEROES", Color3.fromRGB(50, 100, 180), function()
		UIController.ToggleModal("BackpackModal")
	end)

	CreateMenuBtn("SummonBtn", "✨ SUMMON", Color3.fromRGB(140, 60, 200), function()
		UIController.ToggleModal("SummonModal")
	end)

	CreateMenuBtn("ClaimAfkBtn", "🎁 CLAIM AFK", Color3.fromRGB(220, 160, 30), function()
		if UIController.Remotes.ClaimAfkLoot then
			UIController.Remotes.ClaimAfkLoot:FireServer()
		end
	end)
end

function UIController.BuildCampaignModal()
	local modal = Instance.new("Frame")
	modal.Name = "CampaignModal"
	modal.Size = UDim2.new(0.72, 0, 0.78, 0)
	modal.Position = UDim2.new(0.14, 0, 0.11, 0)
	modal.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 10
	modal.Parent = UIController.ScreenGui
	UIController.Elements.CampaignModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 70, 70)
	stroke.Thickness = 2.5
	stroke.Parent = modal

	-- Header
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(255, 220, 90)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.Text = "⚔️ CHAPTER 1: VERDANT OUTSKIRTS"
	header.ZIndex = 11
	header.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 12
	closeBtn.Parent = modal

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	-- Stages Grid (Stages 1 to 10 sorted by LayoutOrder!)
	local stageScroll = Instance.new("ScrollingFrame")
	stageScroll.Name = "StageScroll"
	stageScroll.Size = UDim2.new(0.55, 0, 0.8, 0)
	stageScroll.Position = UDim2.new(0.04, 0, 0, 60)
	stageScroll.BackgroundTransparency = 1
	stageScroll.BorderSizePixel = 0
	stageScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	stageScroll.ZIndex = 11
	stageScroll.Parent = modal
	UIController.Elements.StageScroll = stageScroll

	local sLayout = Instance.new("UIGridLayout")
	sLayout.CellSize = UDim2.new(0, 95, 0, 95)
	sLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	sLayout.SortOrder = Enum.SortOrder.LayoutOrder -- Strict numeric order
	sLayout.Parent = stageScroll

	-- Stage Detail Panel (Right side)
	local detail = Instance.new("Frame")
	detail.Name = "DetailPanel"
	detail.Size = UDim2.new(0.35, 0, 0.8, 0)
	detail.Position = UDim2.new(0.61, 0, 0, 60)
	detail.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
	detail.BorderSizePixel = 0
	detail.ZIndex = 11
	detail.Parent = modal
	UIController.Elements.StageDetail = detail

	local dCorner = Instance.new("UICorner")
	dCorner.CornerRadius = UDim.new(0, 12)
	dCorner.Parent = detail

	local stageNameLbl = Instance.new("TextLabel")
	stageNameLbl.Name = "Title"
	stageNameLbl.Size = UDim2.new(0.9, 0, 0.12, 0)
	stageNameLbl.Position = UDim2.new(0.05, 0, 0.03, 0)
	stageNameLbl.BackgroundTransparency = 1
	stageNameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	stageNameLbl.TextScaled = true
	stageNameLbl.Font = Enum.Font.GothamBold
	stageNameLbl.Text = "Stage 1-1"
	stageNameLbl.ZIndex = 12
	stageNameLbl.Parent = detail
	UIController.Elements.StageTitle = stageNameLbl

	local stageDescLbl = Instance.new("TextLabel")
	stageDescLbl.Name = "Desc"
	stageDescLbl.Size = UDim2.new(0.9, 0, 0.38, 0)
	stageDescLbl.Position = UDim2.new(0.05, 0, 0.16, 0)
	stageDescLbl.BackgroundTransparency = 1
	stageDescLbl.TextColor3 = Color3.fromRGB(190, 205, 225)
	stageDescLbl.TextScaled = true
	stageDescLbl.Font = Enum.Font.Gotham
	stageDescLbl.TextXAlignment = Enum.TextXAlignment.Left
	stageDescLbl.Text = "Standard patrol stage.\nFirst Clear: 50 💎, 1 📜, 1,000 🧪"
	stageDescLbl.ZIndex = 12
	stageDescLbl.Parent = detail
	UIController.Elements.StageDesc = stageDescLbl

	-- Skip Battle Checkbox Toggle
	local skipToggle = Instance.new("TextButton")
	skipToggle.Name = "SkipToggle"
	skipToggle.Size = UDim2.new(0.9, 0, 0.10, 0)
	skipToggle.Position = UDim2.new(0.05, 0, 0.56, 0)
	skipToggle.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
	skipToggle.TextColor3 = Color3.fromRGB(100, 230, 255)
	skipToggle.TextScaled = true
	skipToggle.Font = Enum.Font.GothamBold
	skipToggle.Text = "⚡ Instant Skip: [ON]"
	skipToggle.ZIndex = 12
	skipToggle.Parent = detail

	local isSkipEnabled = true
	skipToggle.MouseButton1Click:Connect(function()
		isSkipEnabled = not isSkipEnabled
		skipToggle.Text = isSkipEnabled and "⚡ Instant Skip: [ON]" or "▶ Watch Battle: [OFF]"
	end)

	-- Edit Formation Button inside Campaign Detail
	local editFormBtn = Instance.new("TextButton")
	editFormBtn.Name = "EditFormationBtn"
	editFormBtn.Size = UDim2.new(0.9, 0, 0.11, 0)
	editFormBtn.Position = UDim2.new(0.05, 0, 0.68, 0)
	editFormBtn.BackgroundColor3 = Color3.fromRGB(35, 140, 95)
	editFormBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	editFormBtn.TextScaled = true
	editFormBtn.Font = Enum.Font.GothamBold
	editFormBtn.Text = "🛡️ SQUAD FORMATION"
	editFormBtn.ZIndex = 12
	editFormBtn.Parent = detail

	local efCorner = Instance.new("UICorner")
	efCorner.CornerRadius = UDim.new(0, 8)
	efCorner.Parent = editFormBtn

	editFormBtn.MouseButton1Click:Connect(function()
		UIController.ToggleModal("FormationModal")
	end)

	-- Battle Button
	local battleBtn = Instance.new("TextButton")
	battleBtn.Name = "BattleBtn"
	battleBtn.Size = UDim2.new(0.9, 0, 0.15, 0)
	battleBtn.Position = UDim2.new(0.05, 0, 0.81, 0)
	battleBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	battleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	battleBtn.TextScaled = true
	battleBtn.Font = Enum.Font.GothamBlack
	battleBtn.Text = "⚔️ BATTLE"
	battleBtn.ZIndex = 12
	battleBtn.Parent = detail
	UIController.Elements.BattleBtn = battleBtn

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 8)
	bCorner.Parent = battleBtn

	battleBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.StartBattle then
			UIController.Remotes.StartBattle:FireServer(UIController.SelectedStageId, isSkipEnabled)
		end
	end)

	-- Populate 10 stage cards with numeric LayoutOrder
	for idx = 1, 10 do
		local stageId = "1-" .. tostring(idx)
		local card = Instance.new("TextButton")
		card.Name = "StageCard_" .. idx
		card.LayoutOrder = idx
		card.BackgroundColor3 = (idx == 5) and Color3.fromRGB(150, 60, 30) or ((idx == 10) and Color3.fromRGB(160, 30, 60) or Color3.fromRGB(35, 40, 55))
		card.TextColor3 = Color3.fromRGB(255, 255, 255)
		card.TextScaled = true
		card.Font = Enum.Font.GothamBold
		card.Text = (idx == 5) and ("1-5\n👹 MINI-BOSS") or ((idx == 10) and ("1-10\n👑 BOSS") or ("1-" .. idx))
		card.ZIndex = 12
		card.Parent = stageScroll

		local cCorn = Instance.new("UICorner")
		cCorn.CornerRadius = UDim.new(0, 10)
		cCorn.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = (idx == 10 or idx == 5) and Color3.fromRGB(255, 215, 60) or Color3.fromRGB(70, 80, 100)
		cStroke.Thickness = 2
		cStroke.Parent = card

		card.MouseButton1Click:Connect(function()
			UIController.SelectedStageId = stageId
			UIController.UpdateSelectedStageDetail(stageId)
		end)
	end

	UIController.RefreshCampaignCards()
end

function UIController.RefreshCampaignCards()
	local scroll = UIController.Elements.StageScroll
	if not scroll then return end

	local clearedIdx = tonumber(UIController.State.HighestClearedStage:match("-(%d+)")) or 0

	for idx = 1, 10 do
		local card = scroll:FindFirstChild("StageCard_" .. idx) :: TextButton?
		if card then
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if idx <= clearedIdx then
				-- Cleared stage
				card.BackgroundColor3 = (idx == 10) and Color3.fromRGB(120, 30, 50) or ((idx == 5) and Color3.fromRGB(110, 50, 30) or Color3.fromRGB(30, 45, 60))
				card.Text = string.format("1-%d\n★ CLEARED", idx)
				if stroke then stroke.Color = Color3.fromRGB(60, 200, 120) end
			elseif idx == clearedIdx + 1 then
				-- Current unlocked active stage
				card.BackgroundColor3 = (idx == 10) and Color3.fromRGB(180, 40, 70) or ((idx == 5) and Color3.fromRGB(170, 70, 30) or Color3.fromRGB(45, 60, 95))
				card.Text = (idx == 10) and "1-10\n👑 BOSS" or ((idx == 5) and "1-5\n👹 MINI-BOSS" or string.format("1-%d\n⚔️ ACTIVE", idx))
				if stroke then stroke.Color = Color3.fromRGB(255, 220, 60) end
			else
				-- Locked future stage (viewable preview)
				card.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
				card.Text = string.format("1-%d\n🔒 LOCKED", idx)
				if stroke then stroke.Color = Color3.fromRGB(50, 55, 65) end
			end
		end
	end

	UIController.UpdateSelectedStageDetail(UIController.SelectedStageId)
end

function UIController.UpdateSelectedStageDetail(stageId: string)
	local stageNameLbl = UIController.Elements.StageTitle
	local stageDescLbl = UIController.Elements.StageDesc
	local battleBtn = UIController.Elements.BattleBtn
	if not stageNameLbl or not stageDescLbl or not battleBtn then return end

	local sDef = StageData.Get(stageId)
	if not sDef then return end

	local selIdx = sDef.StageIndex
	local clearedIdx = tonumber(UIController.State.HighestClearedStage:match("-(%d+)")) or 0
	local isLocked = selIdx > (clearedIdx + 1)

	stageNameLbl.Text = sDef.Name .. (isLocked and " [LOCKED]" or "")
	stageDescLbl.Text = string.format(
		"Chapter %d - Stage %d\n%s\n\nFirst Clear Rewards:\n💎 %d Diamonds\n📜 %d Scrolls\n🧪 %d Elixir\n%s\n\nAFK Loot Rate:\n💰 +%d/m  🧪 +%d/m",
		sDef.Chapter, sDef.StageIndex,
		(sDef.IsBoss and "⚠️ CHAPTER BOSS FIGHT!" or (sDef.IsMiniBoss and "⚠️ MINI-BOSS ENCOUNTER!" or (isLocked and "🔒 Stage locked. Clear prior stages to access." or "Ready for combat!"))),
		sDef.FirstClearRewards.Diamonds,
		sDef.FirstClearRewards.Scrolls,
		sDef.FirstClearRewards.Elixir,
		(sDef.FirstClearRewards.GuaranteedEquipment and ("🎁 Guaranteed: " .. sDef.FirstClearRewards.GuaranteedEquipment) or ""),
		sDef.AfkRates.GoldPerMin,
		sDef.AfkRates.ElixirPerMin
	)

	if isLocked then
		battleBtn.Text = string.format("🔒 LOCKED (Clear 1-%d first)", clearedIdx + 1)
		battleBtn.BackgroundColor3 = Color3.fromRGB(55, 60, 70)
		battleBtn.Active = false
	else
		battleBtn.Text = (selIdx <= clearedIdx) and "⚔️ REPEAT BATTLE" or "⚔️ BATTLE"
		battleBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
		battleBtn.Active = true
	end
end

function UIController.BuildFormationModal()
	local modal = Instance.new("Frame")
	modal.Name = "FormationModal"
	modal.Size = UDim2.new(0.8, 0, 0.82, 0)
	modal.Position = UDim2.new(0.1, 0, 0.09, 0)
	modal.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 15
	modal.Parent = UIController.ScreenGui
	UIController.Elements.FormationModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 170, 110)
	stroke.Thickness = 2.5
	stroke.Parent = modal

	-- Header
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(0.6, 0, 0, 45)
	header.Position = UDim2.new(0.04, 0, 0, 10)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(100, 255, 180)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "🛡️ SQUAD FORMATION SETUP (Max 6 Heroes)"
	header.ZIndex = 16
	header.Parent = modal

	-- Auto Formation Button
	local autoBtn = Instance.new("TextButton")
	autoBtn.Size = UDim2.new(0, 180, 0, 38)
	autoBtn.Position = UDim2.new(1, -240, 0, 14)
	autoBtn.BackgroundColor3 = Color3.fromRGB(30, 140, 90)
	autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoBtn.TextScaled = true
	autoBtn.Font = Enum.Font.GothamBold
	autoBtn.Text = "⚡ AUTO FORMATION"
	autoBtn.ZIndex = 16
	autoBtn.Parent = modal

	local aCorn = Instance.new("UICorner")
	aCorn.CornerRadius = UDim.new(0, 8)
	aCorn.Parent = autoBtn

	autoBtn.MouseButton1Click:Connect(function()
		UIController.AutoFormSquad()
	end)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 14)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 16
	closeBtn.Parent = modal

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	-- Upper: Active 6 Squad Slots
	local slotsFrame = Instance.new("Frame")
	slotsFrame.Name = "SlotsFrame"
	slotsFrame.Size = UDim2.new(0.92, 0, 0.35, 0)
	slotsFrame.Position = UDim2.new(0.04, 0, 0.12, 0)
	slotsFrame.BackgroundColor3 = Color3.fromRGB(22, 25, 36)
	slotsFrame.ZIndex = 16
	slotsFrame.Parent = modal
	UIController.Elements.FormationSlotsFrame = slotsFrame

	local sCorn = Instance.new("UICorner")
	sCorn.CornerRadius = UDim.new(0, 12)
	sCorn.Parent = slotsFrame

	local sLayout = Instance.new("UIGridLayout")
	sLayout.CellSize = UDim2.new(0.155, 0, 0.88, 0)
	sLayout.CellPadding = UDim2.new(0.012, 0, 0, 0)
	sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	sLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sLayout.Parent = slotsFrame

	-- Lower: Available Heroes Backpack
	local lowerTitle = Instance.new("TextLabel")
	lowerTitle.Size = UDim2.new(0.92, 0, 0, 28)
	lowerTitle.Position = UDim2.new(0.04, 0, 0.49, 0)
	lowerTitle.BackgroundTransparency = 1
	lowerTitle.TextColor3 = Color3.fromRGB(200, 215, 235)
	lowerTitle.TextScaled = true
	lowerTitle.Font = Enum.Font.GothamBold
	lowerTitle.TextXAlignment = Enum.TextXAlignment.Left
	lowerTitle.Text = "📦 AVAILABLE HEROES (Click to Add / Swap into Squad):"
	lowerTitle.ZIndex = 16
	lowerTitle.Parent = modal

	local pickerScroll = Instance.new("ScrollingFrame")
	pickerScroll.Name = "PickerScroll"
	pickerScroll.Size = UDim2.new(0.92, 0, 0.44, 0)
	pickerScroll.Position = UDim2.new(0.04, 0, 0.53, 0)
	pickerScroll.BackgroundTransparency = 1
	pickerScroll.BorderSizePixel = 0
	pickerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pickerScroll.ZIndex = 16
	pickerScroll.Parent = modal
	UIController.Elements.FormationPickerScroll = pickerScroll

	local pLayout = Instance.new("UIGridLayout")
	pLayout.CellSize = UDim2.new(0, 105, 0, 120)
	pLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	pLayout.Parent = pickerScroll
end

function UIController.RefreshFormationUI()
	local slotsFrame = UIController.Elements.FormationSlotsFrame
	local pickerScroll = UIController.Elements.FormationPickerScroll
	if not slotsFrame or not pickerScroll then return end

	-- 1. Render 6 Formation Slots
	for _, child in ipairs(slotsFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for slotIdx = 1, 6 do
		local heroUid = UIController.State.Formation[slotIdx]
		local inst = heroUid and UIController.State.Heroes[heroUid]
		local def = inst and HeroData.Get(inst.HeroId)

		local slotBox = Instance.new("Frame")
		slotBox.Name = "Slot_" .. slotIdx
		slotBox.LayoutOrder = slotIdx
		slotBox.BackgroundColor3 = inst and Color3.fromRGB(30, 35, 50) or Color3.fromRGB(24, 26, 32)
		slotBox.ZIndex = 17
		slotBox.Parent = slotsFrame

		local bCorn = Instance.new("UICorner")
		bCorn.CornerRadius = UDim.new(0, 10)
		bCorn.Parent = slotBox

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = inst and GetStarColor(inst.Star) or Color3.fromRGB(50, 55, 70)
		bStroke.Thickness = inst and 2 or 1
		bStroke.Parent = slotBox

		if inst and def then
			local roleIcon = "🛡️"
			if def.Role == "Guard" then roleIcon = "⚔️"
			elseif def.Role == "Sniper" then roleIcon = "🏹"
			elseif def.Role == "Caster" then roleIcon = "🔥"
			elseif def.Role == "Medic" then roleIcon = "🌿"
			end

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.9, 0, 0.45, 0)
			nameLbl.Position = UDim2.new(0.05, 0, 0.05, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLbl.TextScaled = true
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.Text = roleIcon .. "\n" .. def.Name
			nameLbl.ZIndex = 18
			nameLbl.Parent = slotBox

			local lvlLbl = Instance.new("TextLabel")
			lylLbl.Size = UDim2.new(0.9, 0, 0.25, 0)
			lylLbl.Position = UDim2.new(0.05, 0, 0.48, 0)
			lylLbl.BackgroundTransparency = 1
			lylLbl.TextColor3 = Color3.fromRGB(100, 220, 255)
			lylLbl.TextScaled = true
			lylLbl.Font = Enum.Font.GothamBold
			lylLbl.Text = "Lv." .. inst.Level .. " " .. GetStars(inst.Star)
			lylLbl.ZIndex = 18
			lylLbl.Parent = slotBox

			local removeBtn = Instance.new("TextButton")
			removeBtn.Size = UDim2.new(0.85, 0, 0.22, 0)
			removeBtn.Position = UDim2.new(0.075, 0, 0.74, 0)
			removeBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
			removeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			removeBtn.TextScaled = true
			removeBtn.Font = Enum.Font.GothamBold
			removeBtn.Text = "REMOVE"
			removeBtn.ZIndex = 18
			removeBtn.Parent = slotBox

			local rCorn = Instance.new("UICorner")
			rCorn.CornerRadius = UDim.new(0, 6)
			rCorn.Parent = removeBtn

			removeBtn.MouseButton1Click:Connect(function()
				local newFormation = {}
				for _, uid in ipairs(UIController.State.Formation) do
					if uid ~= heroUid then
						table.insert(newFormation, uid)
					end
				end
				if #newFormation > 0 and UIController.Remotes.UpdateFormation then
					UIController.Remotes.UpdateFormation:FireServer(newFormation)
				end
			end)
		else
			local emptyLbl = Instance.new("TextLabel")
			emptyLbl.Size = UDim2.new(0.9, 0, 0.6, 0)
			emptyLbl.Position = UDim2.new(0.05, 0, 0.2, 0)
			emptyLbl.BackgroundTransparency = 1
			emptyLbl.TextColor3 = Color3.fromRGB(90, 100, 120)
			emptyLbl.TextScaled = true
			emptyLbl.Font = Enum.Font.GothamBold
			emptyLbl.Text = string.format("[Slot %d]\n+ Empty", slotIdx)
			emptyLbl.ZIndex = 18
			emptyLbl.Parent = slotBox
		end
	end

	-- 2. Render Backpack Heroes Picker
	for _, child in ipairs(pickerScroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for uid, inst in pairs(UIController.State.Heroes) do
		local def = HeroData.Get(inst.HeroId)
		if def then
			local inSquad = table.find(UIController.State.Formation, uid) ~= nil

			local btn = Instance.new("TextButton")
			btn.Name = "HeroPick_" .. uid
			btn.BackgroundColor3 = inSquad and Color3.fromRGB(24, 26, 32) or Color3.fromRGB(32, 38, 52)
			btn.ZIndex = 17
			btn.Parent = pickerScroll

			local bCorn = Instance.new("UICorner")
			bCorn.CornerRadius = UDim.new(0, 8)
			bCorn.Parent = btn

			local bStroke = Instance.new("UIStroke")
			bStroke.Color = inSquad and Color3.fromRGB(60, 65, 75) or GetStarColor(inst.Star)
			bStroke.Thickness = 2
			bStroke.Parent = btn

			local roleIcon = "🛡️"
			if def.Role == "Guard" then roleIcon = "⚔️"
			elseif def.Role == "Sniper" then roleIcon = "🏹"
			elseif def.Role == "Caster" then roleIcon = "🔥"
			elseif def.Role == "Medic" then roleIcon = "🌿"
			end

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.9, 0, 0.45, 0)
			nameLbl.Position = UDim2.new(0.05, 0, 0.05, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.TextColor3 = inSquad and Color3.fromRGB(120, 130, 140) or Color3.fromRGB(255, 255, 255)
			nameLbl.TextScaled = true
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.Text = roleIcon .. "\n" .. def.Name
			nameLbl.ZIndex = 18
			nameLbl.Parent = btn

			local statusLbl = Instance.new("TextLabel")
			statusLbl.Size = UDim2.new(0.9, 0, 0.35, 0)
			statusLbl.Position = UDim2.new(0.05, 0, 0.55, 0)
			statusLbl.BackgroundTransparency = 1
			statusLbl.TextColor3 = inSquad and Color3.fromRGB(80, 180, 120) or Color3.fromRGB(100, 220, 255)
			statusLbl.TextScaled = true
			statusLbl.Font = Enum.Font.GothamBold
			statusLbl.Text = inSquad and "✓ IN SQUAD" or ("Lv." .. inst.Level .. "\n[+ ADD]")
			statusLbl.ZIndex = 18
			statusLbl.Parent = btn

			btn.MouseButton1Click:Connect(function()
				if inSquad then
					-- Remove from squad
					local newFormation = {}
					for _, fUid in ipairs(UIController.State.Formation) do
						if fUid ~= uid then
							table.insert(newFormation, fUid)
						end
					end
					if #newFormation > 0 and UIController.Remotes.UpdateFormation then
						UIController.Remotes.UpdateFormation:FireServer(newFormation)
					end
				else
					-- Add to squad if < 6
					if #UIController.State.Formation >= 6 then
						UIController.ShowNotification("Squad is full! Remove a hero first.", Color3.fromRGB(255, 100, 100))
						return
					end
					local newFormation = table.clone(UIController.State.Formation)
					table.insert(newFormation, uid)
					if UIController.Remotes.UpdateFormation then
						UIController.Remotes.UpdateFormation:FireServer(newFormation)
					end
				end
			end)
		end
	end
end

function UIController.AutoFormSquad()
	local allHeroes = {}
	for uid, inst in pairs(UIController.State.Heroes) do
		local def = HeroData.Get(inst.HeroId)
		if def then
			table.insert(allHeroes, { Uid = uid, Inst = inst, Def = def })
		end
	end

	if #allHeroes == 0 then return end

	-- Sort by Level desc, Star desc
	table.sort(allHeroes, function(a, b)
		if a.Inst.Star ~= b.Inst.Star then
			return a.Inst.Star > b.Inst.Star
		end
		return a.Inst.Level > b.Inst.Level
	end)

	local selectedUids = {}
	local hasRole = {}

	-- 1. Try pick 1 best Defender
	for _, h in ipairs(allHeroes) do
		if h.Def.Role == "Defender" and not hasRole["Defender"] then
			table.insert(selectedUids, h.Uid)
			hasRole["Defender"] = true
			break
		end
	end

	-- 2. Try pick 1 best Guard
	for _, h in ipairs(allHeroes) do
		if h.Def.Role == "Guard" and not hasRole["Guard"] and not table.find(selectedUids, h.Uid) then
			table.insert(selectedUids, h.Uid)
			hasRole["Guard"] = true
			break
		end
	end

	-- 3. Try pick 1 best Medic
	for _, h in ipairs(allHeroes) do
		if h.Def.Role == "Medic" and not hasRole["Medic"] and not table.find(selectedUids, h.Uid) then
			table.insert(selectedUids, h.Uid)
			hasRole["Medic"] = true
			break
		end
	end

	-- 4. Fill remaining slots up to 6 with highest level/star heroes
	for _, h in ipairs(allHeroes) do
		if #selectedUids >= 6 then break end
		if not table.find(selectedUids, h.Uid) then
			table.insert(selectedUids, h.Uid)
		end
	end

	if #selectedUids > 0 and UIController.Remotes.UpdateFormation then
		UIController.Remotes.UpdateFormation:FireServer(selectedUids)
		UIController.ShowNotification(string.format("⚡ Auto Formation: %d Heroes deployed!", #selectedUids), Color3.fromRGB(100, 255, 150))
	end
end

function UIController.BuildBackpackModal()
	local modal = Instance.new("Frame")
	modal.Name = "BackpackModal"
	modal.Size = UDim2.new(0.8, 0, 0.8, 0)
	modal.Position = UDim2.new(0.1, 0, 0.1, 0)
	modal.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 10
	modal.Parent = UIController.ScreenGui
	UIController.Elements.BackpackModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 120, 220)
	stroke.Thickness = 2.5
	stroke.Parent = modal

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBold
	header.Text = "🎒 HERO CITADEL & BACKPACK"
	header.ZIndex = 11
	header.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 12
	closeBtn.Parent = modal

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	-- Hero List Grid (Left)
	local heroScroll = Instance.new("ScrollingFrame")
	heroScroll.Name = "HeroScroll"
	heroScroll.Size = UDim2.new(0.48, 0, 0.82, 0)
	heroScroll.Position = UDim2.new(0.03, 0, 0, 60)
	heroScroll.BackgroundTransparency = 1
	heroScroll.BorderSizePixel = 0
	heroScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	heroScroll.ZIndex = 11
	heroScroll.Parent = modal
	UIController.Elements.HeroScroll = heroScroll

	local hLayout = Instance.new("UIGridLayout")
	hLayout.CellSize = UDim2.new(0, 110, 0, 130)
	hLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	hLayout.Parent = heroScroll

	-- Hero Detail Panel (Right)
	local detail = Instance.new("Frame")
	detail.Name = "HeroDetail"
	detail.Size = UDim2.new(0.44, 0, 0.82, 0)
	detail.Position = UDim2.new(0.53, 0, 0, 60)
	detail.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	detail.BorderSizePixel = 0
	detail.ZIndex = 11
	detail.Parent = modal
	UIController.Elements.HeroDetail = detail

	local dCorner = Instance.new("UICorner")
	dCorner.CornerRadius = UDim.new(0, 12)
	dCorner.Parent = detail

	local hName = Instance.new("TextLabel")
	hName.Name = "HeroName"
	hName.Size = UDim2.new(0.9, 0, 0.12, 0)
	hName.Position = UDim2.new(0.05, 0, 0.04, 0)
	hName.BackgroundTransparency = 1
	hName.TextColor3 = Color3.fromRGB(255, 255, 255)
	hName.TextScaled = true
	hName.Font = Enum.Font.GothamBold
	hName.ZIndex = 12
	hName.Parent = detail
	UIController.Elements.HeroDetailName = hName

	local hStats = Instance.new("TextLabel")
	hStats.Name = "HeroStats"
	hStats.Size = UDim2.new(0.9, 0, 0.42, 0)
	hStats.Position = UDim2.new(0.05, 0, 0.18, 0)
	hStats.BackgroundTransparency = 1
	hStats.TextColor3 = Color3.fromRGB(190, 205, 225)
	hStats.TextScaled = true
	hStats.Font = Enum.Font.Gotham
	hStats.TextXAlignment = Enum.TextXAlignment.Left
	hStats.ZIndex = 12
	hStats.Parent = detail
	UIController.Elements.HeroDetailStats = hStats

	-- LEVEL UP / STAR UP BUTTON
	local levelUpBtn = Instance.new("TextButton")
	levelUpBtn.Name = "LevelUpBtn"
	levelUpBtn.Size = UDim2.new(0.9, 0, 0.15, 0)
	levelUpBtn.Position = UDim2.new(0.05, 0, 0.78, 0)
	levelUpBtn.BackgroundColor3 = Color3.fromRGB(45, 160, 80)
	levelUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelUpBtn.TextScaled = true
	levelUpBtn.Font = Enum.Font.GothamBold
	levelUpBtn.Text = "LEVEL UP"
	levelUpBtn.ZIndex = 12
	levelUpBtn.Parent = detail
	UIController.Elements.LevelUpBtn = levelUpBtn

	local lCorner = Instance.new("UICorner")
	lCorner.CornerRadius = UDim.new(0, 10)
	lCorner.Parent = levelUpBtn

	levelUpBtn.MouseButton1Click:Connect(function()
		local uid = UIController.SelectedHeroUid
		if not uid then return end

		local inst = UIController.State.Heroes[uid]
		if not inst then return end

		local cap = HeroData.GetLevelCap(inst.Star)
		if inst.Level >= cap then
			-- Trigger Star Up
			if UIController.Remotes.StarUpHero then
				local sacrifices = {}
				for otherUid, otherHero in pairs(UIController.State.Heroes) do
					if otherUid ~= uid and otherHero.Star == inst.Star and not table.find(UIController.State.Formation, otherUid) then
						table.insert(sacrifices, otherUid)
						if #sacrifices >= 2 then break end
					end
				end
				UIController.Remotes.StarUpHero:FireServer(uid, sacrifices)
			end
		else
			-- Trigger Level Up
			if UIController.Remotes.LevelUpHero then
				UIController.Remotes.LevelUpHero:FireServer(uid)
			end
		end
	end)
end

function UIController.BuildSummonModal()
	local modal = Instance.new("Frame")
	modal.Name = "SummonModal"
	modal.Size = UDim2.new(0.72, 0, 0.78, 0)
	modal.Position = UDim2.new(0.14, 0, 0.11, 0)
	modal.BackgroundColor3 = Color3.fromRGB(20, 16, 32)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 10
	modal.Parent = UIController.ScreenGui
	UIController.Elements.SummonModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 80, 240)
	stroke.Thickness = 2.5
	stroke.Parent = modal

	-- Header
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(240, 210, 255)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.Text = "✨ SUMMON ALTAR: HERO SUMMON"
	header.ZIndex = 11
	header.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 12
	closeBtn.Parent = modal

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	local subTitle = Instance.new("TextLabel")
	subTitle.Size = UDim2.new(0.9, 0, 0.08, 0)
	subTitle.Position = UDim2.new(0.05, 0, 0.09, 0)
	subTitle.BackgroundTransparency = 1
	subTitle.TextColor3 = Color3.fromRGB(255, 225, 120)
	subTitle.TextScaled = true
	subTitle.Font = Enum.Font.GothamMedium
	subTitle.Text = "Rates: 5★ (4.0%) | 4★ (20.0%) | 3★ (76.0%)\nSummon duplicates to Ascend & Star-Up your heroes!"
	subTitle.ZIndex = 11
	subTitle.Parent = modal

	local cardsContainer = Instance.new("Frame")
	cardsContainer.Size = UDim2.new(0.9, 0, 0.72, 0)
	cardsContainer.Position = UDim2.new(0.05, 0, 0.22, 0)
	cardsContainer.BackgroundTransparency = 1
	cardsContainer.ZIndex = 11
	cardsContainer.Parent = modal

	local cLayout = Instance.new("UIListLayout")
	cLayout.FillDirection = Enum.FillDirection.Horizontal
	cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cLayout.Padding = UDim.new(0, 24)
	cLayout.Parent = cardsContainer

	-- 1x Summon Card
	local card1x = Instance.new("Frame")
	card1x.Name = "Card1x"
	card1x.Size = UDim2.new(0.46, 0, 0.95, 0)
	card1x.BackgroundColor3 = Color3.fromRGB(28, 24, 44)
	card1x.ZIndex = 12
	card1x.Parent = cardsContainer

	local card1Corner = Instance.new("UICorner")
	card1Corner.CornerRadius = UDim.new(0, 12)
	card1Corner.Parent = card1x

	local card1Stroke = Instance.new("UIStroke")
	card1Stroke.Color = Color3.fromRGB(100, 160, 240)
	card1Stroke.Thickness = 2
	card1Stroke.Parent = card1x

	local card1Title = Instance.new("TextLabel")
	card1Title.Size = UDim2.new(0.9, 0, 0.2, 0)
	card1Title.Position = UDim2.new(0.05, 0, 0.06, 0)
	card1Title.BackgroundTransparency = 1
	card1Title.TextColor3 = Color3.fromRGB(255, 255, 255)
	card1Title.TextScaled = true
	card1Title.Font = Enum.Font.GothamBold
	card1Title.Text = "SINGLE SUMMON\n(1 Hero)"
	card1Title.ZIndex = 13
	card1Title.Parent = card1x

	local btnScroll1 = Instance.new("TextButton")
	btnScroll1.Size = UDim2.new(0.85, 0, 0.25, 0)
	btnScroll1.Position = UDim2.new(0.075, 0, 0.38, 0)
	btnScroll1.BackgroundColor3 = Color3.fromRGB(220, 120, 40)
	btnScroll1.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnScroll1.TextScaled = true
	btnScroll1.Font = Enum.Font.GothamBold
	btnScroll1.Text = "📜 1 Scroll"
	btnScroll1.ZIndex = 13
	btnScroll1.Parent = card1x

	local bCorn1 = Instance.new("UICorner")
	bCorn1.CornerRadius = UDim.new(0, 8)
	bCorn1.Parent = btnScroll1

	btnScroll1.MouseButton1Click:Connect(function()
		if UIController.Remotes.RollGacha then
			UIController.Remotes.RollGacha:FireServer(1, "Scrolls")
		end
	end)

	local btnDia1 = Instance.new("TextButton")
	btnDia1.Size = UDim2.new(0.85, 0, 0.25, 0)
	btnDia1.Position = UDim2.new(0.075, 0, 0.68, 0)
	btnDia1.BackgroundColor3 = Color3.fromRGB(45, 120, 210)
	btnDia1.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnDia1.TextScaled = true
	btnDia1.Font = Enum.Font.GothamBold
	btnDia1.Text = "💎 200 Diamonds"
	btnDia1.ZIndex = 13
	btnDia1.Parent = card1x

	local bCorn2 = Instance.new("UICorner")
	bCorn2.CornerRadius = UDim.new(0, 8)
	bCorn2.Parent = btnDia1

	btnDia1.MouseButton1Click:Connect(function()
		if UIController.Remotes.RollGacha then
			UIController.Remotes.RollGacha:FireServer(1, "Diamonds")
		end
	end)

	-- 10x Summon Card
	local card10x = Instance.new("Frame")
	card10x.Name = "Card10x"
	card10x.Size = UDim2.new(0.46, 0, 0.95, 0)
	card10x.BackgroundColor3 = Color3.fromRGB(36, 26, 56)
	card10x.ZIndex = 12
	card10x.Parent = cardsContainer

	local card10Corner = Instance.new("UICorner")
	card10Corner.CornerRadius = UDim.new(0, 12)
	card10Corner.Parent = card10x

	local card10Stroke = Instance.new("UIStroke")
	card10Stroke.Color = Color3.fromRGB(255, 215, 60)
	card10Stroke.Thickness = 2.5
	card10Stroke.Parent = card10x

	local card10Title = Instance.new("TextLabel")
	card10Title.Size = UDim2.new(0.9, 0, 0.2, 0)
	card10Title.Position = UDim2.new(0.05, 0, 0.06, 0)
	card10Title.BackgroundTransparency = 1
	card10Title.TextColor3 = Color3.fromRGB(255, 220, 80)
	card10Title.TextScaled = true
	card10Title.Font = Enum.Font.GothamBlack
	card10Title.Text = "10x SUMMON\n(Guaranteed 4★+)"
	card10Title.ZIndex = 13
	card10Title.Parent = card10x

	local btnScroll10 = Instance.new("TextButton")
	btnScroll10.Size = UDim2.new(0.85, 0, 0.25, 0)
	btnScroll10.Position = UDim2.new(0.075, 0, 0.38, 0)
	btnScroll10.BackgroundColor3 = Color3.fromRGB(230, 100, 30)
	btnScroll10.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnScroll10.TextScaled = true
	btnScroll10.Font = Enum.Font.GothamBold
	btnScroll10.Text = "📜 10 Scrolls"
	btnScroll10.ZIndex = 13
	btnScroll10.Parent = card10x

	local bCorn3 = Instance.new("UICorner")
	bCorn3.CornerRadius = UDim.new(0, 8)
	bCorn3.Parent = btnScroll10

	btnScroll10.MouseButton1Click:Connect(function()
		if UIController.Remotes.RollGacha then
			UIController.Remotes.RollGacha:FireServer(10, "Scrolls")
		end
	end)

	local btnDia10 = Instance.new("TextButton")
	btnDia10.Size = UDim2.new(0.85, 0, 0.25, 0)
	btnDia10.Position = UDim2.new(0.075, 0, 0.68, 0)
	btnDia10.BackgroundColor3 = Color3.fromRGB(160, 40, 200)
	btnDia10.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnDia10.TextScaled = true
	btnDia10.Font = Enum.Font.GothamBold
	btnDia10.Text = "💎 1,800 Diamonds (10% OFF)"
	btnDia10.ZIndex = 13
	btnDia10.Parent = card10x

	local bCorn4 = Instance.new("UICorner")
	bCorn4.CornerRadius = UDim.new(0, 8)
	bCorn4.Parent = btnDia10

	btnDia10.MouseButton1Click:Connect(function()
		if UIController.Remotes.RollGacha then
			UIController.Remotes.RollGacha:FireServer(10, "Diamonds")
		end
	end)
end

function UIController.BuildGachaRevealModal()
	local modal = Instance.new("Frame")
	modal.Name = "GachaRevealModal"
	modal.Size = UDim2.new(0.8, 0, 0.8, 0)
	modal.Position = UDim2.new(0.1, 0, 0.1, 0)
	modal.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 40
	modal.Parent = UIController.ScreenGui
	UIController.Elements.GachaRevealModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 60)
	stroke.Thickness = 3
	stroke.Parent = modal

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 60)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Text = "✨ SUMMON RESULTS ✨"
	title.ZIndex = 41
	title.Parent = modal

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "RevealScroll"
	scroll.Size = UDim2.new(0.9, 0, 0.72, 0)
	scroll.Position = UDim2.new(0.05, 0, 0.12, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 41
	scroll.Parent = modal
	UIController.Elements.GachaRevealScroll = scroll

	local rLayout = Instance.new("UIGridLayout")
	rLayout.CellSize = UDim2.new(0, 120, 0, 150)
	rLayout.CellPadding = UDim2.new(0, 14, 0, 14)
	rLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rLayout.Parent = scroll

	local okBtn = Instance.new("TextButton")
	okBtn.Size = UDim2.new(0.35, 0, 0, 48)
	okBtn.Position = UDim2.new(0.325, 0, 1, -62)
	okBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 90)
	okBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	okBtn.TextScaled = true
	okBtn.Font = Enum.Font.GothamBold
	okBtn.Text = "CLAIM HEROES"
	okBtn.ZIndex = 42
	okBtn.Parent = modal

	local oCorner = Instance.new("UICorner")
	oCorner.CornerRadius = UDim.new(0, 10)
	oCorner.Parent = okBtn

	okBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)
end

function UIController.BuildBattleResultModal()
	local modal = Instance.new("Frame")
	modal.Name = "BattleResultModal"
	modal.Size = UDim2.new(0.6, 0, 0.65, 0)
	modal.Position = UDim2.new(0.2, 0, 0.175, 0)
	modal.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 30
	modal.Parent = UIController.ScreenGui
	UIController.Elements.BattleResultModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 60)
	stroke.Thickness = 3
	stroke.Parent = modal

	local title = Instance.new("TextLabel")
	title.Name = "ResultTitle"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 60)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Text = "🎉 VICTORY! 🎉"
	title.ZIndex = 31
	title.Parent = modal
	UIController.Elements.ResultTitle = title

	local body = Instance.new("TextLabel")
	body.Name = "ResultBody"
	body.Size = UDim2.new(0.85, 0, 0.5, 0)
	body.Position = UDim2.new(0.075, 0, 0.25, 0)
	body.BackgroundTransparency = 1
	body.TextColor3 = Color3.fromRGB(220, 230, 255)
	body.TextScaled = true
	body.Font = Enum.Font.GothamMedium
	body.ZIndex = 31
	body.Parent = modal
	UIController.Elements.ResultBody = body

	local claimBtn = Instance.new("TextButton")
	claimBtn.Size = UDim2.new(0.5, 0, 0, 50)
	claimBtn.Position = UDim2.new(0.25, 0, 1, -70)
	claimBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 90)
	claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	claimBtn.TextScaled = true
	claimBtn.Font = Enum.Font.GothamBold
	claimBtn.Text = "CONTINUE"
	claimBtn.ZIndex = 31
	claimBtn.Parent = modal

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 10)
	bCorner.Parent = claimBtn

	claimBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)
end

function UIController.ToggleModal(modalName: string)
	local modals = { "CampaignModal", "BackpackModal", "FormationModal", "SummonModal", "BattleResultModal" }
	local target = UIController.Elements[modalName]

	if modalName == "" or not target then
		for _, name in ipairs(modals) do
			local m = UIController.Elements[name]
			if m then
				m.Visible = false
			end
		end
		return
	end

	local willBeVisible = not target.Visible
	for _, name in ipairs(modals) do
		local m = UIController.Elements[name]
		if m then
			m.Visible = false
		end
	end

	target.Visible = willBeVisible
	if modalName == "BackpackModal" and willBeVisible then
		UIController.RefreshHeroGrid()
	elseif modalName == "FormationModal" and willBeVisible then
		UIController.RefreshFormationUI()
	elseif modalName == "CampaignModal" and willBeVisible then
		UIController.RefreshCampaignCards()
	end
end

function UIController.RefreshHeroGrid()
	local scroll = UIController.Elements.HeroScroll
	if not scroll then return end

	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for uid, inst in pairs(UIController.State.Heroes) do
		local def = HeroData.Get(inst.HeroId)
		if def then
			local card = Instance.new("TextButton")
			card.Name = "HeroCard_" .. uid
			card.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
			card.BorderSizePixel = 0
			card.ZIndex = 12
			card.Parent = scroll

			local cCorner = Instance.new("UICorner")
			cCorner.CornerRadius = UDim.new(0, 10)
			cCorner.Parent = card

			local cStroke = Instance.new("UIStroke")
			cStroke.Color = GetStarColor(inst.Star)
			cStroke.Thickness = 2
			cStroke.Parent = card

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(0.9, 0, 0.35, 0)
			name.Position = UDim2.new(0.05, 0, 0.05, 0)
			name.BackgroundTransparency = 1
			name.TextColor3 = Color3.fromRGB(255, 255, 255)
			name.TextScaled = true
			name.Font = Enum.Font.GothamBold
			name.Text = def.Name
			name.ZIndex = 13
			name.Parent = card

			local stars = Instance.new("TextLabel")
			stars.Size = UDim2.new(0.9, 0, 0.25, 0)
			stars.Position = UDim2.new(0.05, 0, 0.42, 0)
			stars.BackgroundTransparency = 1
			stars.TextColor3 = GetStarColor(inst.Star)
			stars.TextScaled = true
			stars.Font = Enum.Font.GothamBlack
			stars.Text = GetStars(inst.Star)
			stars.ZIndex = 13
			stars.Parent = card

			local lvl = Instance.new("TextLabel")
			lvl.Size = UDim2.new(0.9, 0, 0.25, 0)
			lvl.Position = UDim2.new(0.05, 0, 0.70, 0)
			lvl.BackgroundTransparency = 1
			lvl.TextColor3 = Color3.fromRGB(100, 220, 255)
			lvl.TextScaled = true
			lvl.Font = Enum.Font.GothamBold
			lvl.Text = "Lv. " .. tostring(inst.Level)
			lvl.ZIndex = 13
			lvl.Parent = card

			card.MouseButton1Click:Connect(function()
				UIController.SelectHero(uid)
			end)
		end
	end

	if not UIController.SelectedHeroUid then
		for uid in pairs(UIController.State.Heroes) do
			UIController.SelectHero(uid)
			break
		end
	end
end

function UIController.SelectHero(uid: string)
	UIController.SelectedHeroUid = uid
	local inst = UIController.State.Heroes[uid]
	if not inst then return end

	local def = HeroData.Get(inst.HeroId)
	if not def then return end

	local hName = UIController.Elements.HeroDetailName
	local hStats = UIController.Elements.HeroDetailStats
	local levelUpBtn = UIController.Elements.LevelUpBtn

	local cap = HeroData.GetLevelCap(inst.Star)
	local curStats = HeroData.GetStats(inst.HeroId, inst.Level, inst.Star)

	if hName then
		hName.Text = string.format("%s %s [Lv.%d / %d]", def.Name, GetStars(inst.Star), inst.Level, cap)
		hName.TextColor3 = GetStarColor(inst.Star)
	end

	if hStats and curStats then
		local passivesText = ""
		for _, p in ipairs(def.PassiveSkills) do
			local unlocked = inst.Star >= p.RequiredStar
			passivesText ..= string.format("\n• [%s] %s (%s)", unlocked and "UNLOCKED" or (p.RequiredStar .. "★ REQUIREMENT"), p.Name, p.Description)
		end

		hStats.Text = string.format(
			"Role: %s (%s) | Block: %d foes\nHP: %d | ATK: %d | DEF: %d\nRange: %.1f tiles | Speed: %.2f/s\n\nActive Skill: %s (100 Energy)\n%s\n\nPassive Talents:%s",
			def.Role, def.PlacementType, curStats.BlockCount,
			curStats.Hp, curStats.Atk, curStats.Def,
			curStats.Range, curStats.AttackSpeed,
			def.ActiveSkill.Name, def.ActiveSkill.Description,
			passivesText
		)
	end

	if levelUpBtn then
		if inst.Level >= cap then
			levelUpBtn.Text = string.format("⭐ ASCEND / STAR UP (Unlock Lv.%d)", HeroData.GetLevelCap(inst.Star + 1))
			levelUpBtn.BackgroundColor3 = Color3.fromRGB(220, 160, 30)
		else
			local cost = HeroData.GetLevelUpCost(inst.Level)
			levelUpBtn.Text = string.format("LEVEL UP (%d Gold, %d 🧪)", cost.Gold, cost.Elixir)
			levelUpBtn.BackgroundColor3 = Color3.fromRGB(45, 160, 80)
		end
	end
end

function UIController.OnStateSync(data: any)
	for k, v in pairs(data) do
		UIController.State[k] = v
	end

	if UIController.Elements.GoldLabel then
		UIController.Elements.GoldLabel.Text = "💰 " .. MathUtil.FormatNumber(UIController.State.Gold)
	end
	if UIController.Elements.ElixirLabel then
		UIController.Elements.ElixirLabel.Text = "🧪 " .. MathUtil.FormatNumber(UIController.State.Elixir)
	end
	if UIController.Elements.DiamondLabel then
		UIController.Elements.DiamondLabel.Text = "💎 " .. MathUtil.FormatNumber(UIController.State.Diamonds)
	end
	if UIController.Elements.ScrollLabel then
		UIController.Elements.ScrollLabel.Text = "📜 " .. tostring(UIController.State.Scrolls)
	end

	if UIController.SelectedHeroUid then
		UIController.SelectHero(UIController.SelectedHeroUid)
	end

	if UIController.Elements.CampaignModal and UIController.Elements.CampaignModal.Visible then
		UIController.RefreshCampaignCards()
	end
	if UIController.Elements.FormationModal and UIController.Elements.FormationModal.Visible then
		UIController.RefreshFormationUI()
	end
end

function UIController.OnGachaResult(results: { any })
	local modal = UIController.Elements.GachaRevealModal
	local scroll = UIController.Elements.GachaRevealScroll
	if not modal or not scroll then return end

	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, res in ipairs(results) do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
		card.ZIndex = 42
		card.Parent = scroll

		local cCorn = Instance.new("UICorner")
		cCorn.CornerRadius = UDim.new(0, 10)
		cCorn.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = GetStarColor(res.Star)
		cStroke.Thickness = 2.5
		cStroke.Parent = card

		local roleIcon = "🛡️"
		if res.Role == "Guard" then roleIcon = "⚔️"
		elseif res.Role == "Sniper" then roleIcon = "🏹"
		elseif res.Role == "Caster" then roleIcon = "🔥"
		elseif res.Role == "Medic" then roleIcon = "🌿"
		elseif res.Role == "Support" then roleIcon = "✨"
		end

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.9, 0, 0.4, 0)
		nameLbl.Position = UDim2.new(0.05, 0, 0.08, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextScaled = true
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.Text = roleIcon .. "\n" .. res.Name
		nameLbl.ZIndex = 43
		nameLbl.Parent = card

		local starLbl = Instance.new("TextLabel")
		starLbl.Size = UDim2.new(0.9, 0, 0.25, 0)
		starLbl.Position = UDim2.new(0.05, 0, 0.52, 0)
		starLbl.BackgroundTransparency = 1
		starLbl.TextColor3 = GetStarColor(res.Star)
		starLbl.TextScaled = true
		starLbl.Font = Enum.Font.GothamBlack
		starLbl.Text = GetStars(res.Star)
		starLbl.ZIndex = 43
		starLbl.Parent = card

		local roleLbl = Instance.new("TextLabel")
		roleLbl.Size = UDim2.new(0.9, 0, 0.18, 0)
		roleLbl.Position = UDim2.new(0.05, 0, 0.78, 0)
		roleLbl.BackgroundTransparency = 1
		roleLbl.TextColor3 = Color3.fromRGB(180, 200, 230)
		roleLbl.TextScaled = true
		roleLbl.Font = Enum.Font.GothamMedium
		roleLbl.Text = res.Role
		roleLbl.ZIndex = 43
		roleLbl.Parent = card
	end

	modal.Visible = true
end

function UIController.OnBattleFinished(data: any)
	if data.IsSkip then
		UIController.OnBattleFinishedDirect(data)
	else
		-- Close all UI modals and enter 3D Scene World Replay!
		UIController.ToggleModal("")
		BattleArenaController.Start3DBattle(data, function()
			UIController.OnBattleFinishedDirect(data)
		end)
	end
end

function UIController.OnBattleFinishedDirect(data: any)
	local modal = UIController.Elements.BattleResultModal
	local title = UIController.Elements.ResultTitle
	local body = UIController.Elements.ResultBody
	if not modal or not title or not body then return end

	modal.Visible = true

	if data.Success then
		title.Text = "🎉 STAGE CLEARED! 🎉"
		title.TextColor3 = Color3.fromRGB(100, 255, 120)
		local stars = GetStars(data.Stars)
		body.Text = string.format(
			"%s [%s]\nRating: %s\nCrystal Health: %d/%d\n\nRewards Claimed:\n💰 +%d Gold\n🧪 +%d Elixir\n💎 +%d Diamonds%s",
			data.StageName, data.StageId,
			stars,
			data.CrystalHp, data.MaxCrystalHp,
			data.Rewards.Gold, data.Rewards.Elixir, data.Rewards.Diamonds,
			(data.Rewards.Equipment and ("\n🎁 Gear Looted: " .. data.Rewards.Equipment) or "")
		)
	else
		title.Text = "💀 DEFEAT! 💀"
		title.TextColor3 = Color3.fromRGB(255, 60, 60)
		body.Text = string.format(
			"%s [%s]\n\nYour defenses were breached!\nUpgrade your heroes' level in the Backpack,\nadjust squad formation, or Star-Up your blockers!",
			data.StageName, data.StageId
		)
	end
end

function UIController.ShowNotification(message: string, color: Color3?)
	local screenGui = UIController.ScreenGui
	if not screenGui then return end

	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 380, 0, 48)
	toast.Position = UDim2.new(0.5, -190, 0, 75)
	toast.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
	toast.BorderSizePixel = 0
	toast.ZIndex = 50
	toast.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = toast

	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(100, 220, 255)
	stroke.Thickness = 2
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

	task.delay(3.5, function()
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
