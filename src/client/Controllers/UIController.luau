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
		BasicScrolls = 0,
		EliteScrolls = 0,
		Scrolls = 0,
		LastFreeBasicSummon = 0,
		HighestClearedStage = "1-0",
		CurrentStage = "1-1",
		AfkLastClaimTime = 0,
		Heroes = {} :: { [string]: any },
		Formation = {} :: { string },
		EquipmentInventory = {} :: { any },
		Mailbox = {} :: { [string]: any },
		DailyMissions = {
			Points = 0,
			ClaimedChests = {} :: { [number]: boolean },
			Progress = {} :: { [string]: number },
			ClaimedMissions = {} :: { [string]: boolean },
		},
		StarterPackPurchased = false,
	},
	SelectedHeroUid = nil :: string?,
	SelectedChapter = 1,
	SelectedStageId = "1-1",
	CurrentBattleData = nil :: any,
	CurrentCampaignView = "Stages" :: "Stages" | "Chapters",
	SelectedMailId = nil :: string?,
	Elements = {} :: { [string]: any },
}

local function GetStarColor(star: number): Color3
	if star <= 2 then
		return Color3.fromRGB(130, 140, 155)
	elseif star == 3 then
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
	UIController.BuildSummonRatesModal()
	UIController.BuildMailboxModal()
	UIController.BuildMissionsModal()
	UIController.BuildEventsModal()
	UIController.BuildGachaRevealModal()
	UIController.BuildBattleResultModal()
end

function UIController.SetLobbyVisible(visible: boolean)
	local topBar = UIController.Elements.TopBar
	local rightMenu = UIController.Elements.RightMenu
	if topBar then topBar.Visible = visible end
	if rightMenu then rightMenu.Visible = visible end
	if not visible then
		UIController.ToggleModal("")
	end
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
	topBar.Size = UDim2.new(0.94, 0, 0, 52)
	topBar.Position = UDim2.new(0.03, 0, 0, 10)
	topBar.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	topBar.BackgroundTransparency = 0.15
	topBar.BorderSizePixel = 0
	topBar.Parent = screenGui
	UIController.Elements.TopBar = topBar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = topBar

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 65, 80)
	stroke.Thickness = 1.5
	stroke.Parent = topBar

	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLayout.Padding = UDim.new(0, 14)
	topLayout.Parent = topBar

	local function CreateResourceTag(name: string, icon: string, color: Color3): TextLabel
		local lbl = Instance.new("TextLabel")
		lbl.Name = name
		lbl.Size = UDim2.new(0, 115, 0, 36)
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
	UIController.Elements.BasicScrollLabel = CreateResourceTag("BasicScrolls", "📜", Color3.fromRGB(255, 140, 90))
	UIController.Elements.EliteScrollLabel = CreateResourceTag("EliteScrolls", "🔮", Color3.fromRGB(220, 90, 255))

	-- Fast AFK button on Top Bar
	local fastAfkBtn = Instance.new("TextButton")
	fastAfkBtn.Name = "FastAfkBtn"
	fastAfkBtn.Size = UDim2.new(0, 110, 0, 36)
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
	rightMenu.Size = UDim2.new(0, 155, 0, 480)
	rightMenu.Position = UDim2.new(1, -170, 0.5, -230)
	rightMenu.BackgroundTransparency = 1
	rightMenu.Parent = screenGui
	UIController.Elements.RightMenu = rightMenu

	local menuLayout = Instance.new("UIListLayout")
	menuLayout.FillDirection = Enum.FillDirection.Vertical
	menuLayout.Padding = UDim.new(0, 8)
	menuLayout.Parent = rightMenu

	local function CreateMenuBtn(name: string, text: string, color: Color3, callback: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(1, 0, 0, 46)
		btn.BackgroundColor3 = color
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Text = text
		btn.Parent = rightMenu

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 9)
		btnCorner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 215, 80)
		stroke.Thickness = 1.2
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

	local mailBtn = CreateMenuBtn("MailboxBtn", "📬 MAILBOX", Color3.fromRGB(70, 130, 180), function()
		UIController.ToggleModal("MailboxModal")
	end)
	UIController.Elements.MailboxBtn = mailBtn

	CreateMenuBtn("EventsBtn", "🎉 EVENTS", Color3.fromRGB(220, 80, 140), function()
		UIController.ToggleModal("EventsModal")
	end)

	CreateMenuBtn("MissionsBtn", "📋 MISSIONS", Color3.fromRGB(60, 160, 160), function()
		UIController.ToggleModal("MissionsModal")
	end)
end

function UIController.BuildCampaignModal()
	local modal = Instance.new("Frame")
	modal.Name = "CampaignModal"
	modal.Size = UDim2.new(0.76, 0, 0.82, 0)
	modal.Position = UDim2.new(0.12, 0, 0.09, 0)
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

	-- Header with Navigation Tabs (Stages vs Chapters)
	local headerBar = Instance.new("Frame")
	headerBar.Size = UDim2.new(1, 0, 0, 52)
	headerBar.BackgroundTransparency = 1
	headerBar.ZIndex = 11
	headerBar.Parent = modal

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "HeaderTitle"
	headerTitle.Size = UDim2.new(0.45, 0, 1, 0)
	headerTitle.Position = UDim2.new(0.04, 0, 0, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.TextColor3 = Color3.fromRGB(255, 220, 90)
	headerTitle.TextScaled = true
	headerTitle.Font = Enum.Font.GothamBlack
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Text = "⚔️ CHAPTER 1: THE OUTSKIRTS"
	headerTitle.ZIndex = 11
	headerTitle.Parent = headerBar
	UIController.Elements.CampaignHeaderTitle = headerTitle

	local tabContainer = Instance.new("Frame")
	tabContainer.Size = UDim2.new(0.32, 0, 0, 36)
	tabContainer.Position = UDim2.new(0.5, 0, 0, 8)
	tabContainer.BackgroundTransparency = 1
	tabContainer.ZIndex = 11
	tabContainer.Parent = headerBar

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.Parent = tabContainer

	local btnStagesTab = Instance.new("TextButton")
	btnStagesTab.Size = UDim2.new(0, 100, 1, 0)
	btnStagesTab.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	btnStagesTab.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnStagesTab.TextScaled = true
	btnStagesTab.Font = Enum.Font.GothamBold
	btnStagesTab.Text = "🗺️ Stages"
	btnStagesTab.ZIndex = 12
	btnStagesTab.Parent = tabContainer
	UIController.Elements.BtnStagesTab = btnStagesTab

	local bstCorner = Instance.new("UICorner")
	bstCorner.CornerRadius = UDim.new(0, 8)
	bstCorner.Parent = btnStagesTab

	local btnChaptersTab = Instance.new("TextButton")
	btnChaptersTab.Size = UDim2.new(0, 110, 1, 0)
	btnChaptersTab.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
	btnChaptersTab.TextColor3 = Color3.fromRGB(200, 210, 225)
	btnChaptersTab.TextScaled = true
	btnChaptersTab.Font = Enum.Font.GothamBold
	btnChaptersTab.Text = "📖 Chapters"
	btnChaptersTab.ZIndex = 12
	btnChaptersTab.Parent = tabContainer
	UIController.Elements.BtnChaptersTab = btnChaptersTab

	local bchCorner = Instance.new("UICorner")
	bchCorner.CornerRadius = UDim.new(0, 8)
	bchCorner.Parent = btnChaptersTab

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 12
	closeBtn.Parent = headerBar

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	-- 1. STAGES VIEW CONTAINER
	local stagesContainer = Instance.new("Frame")
	stagesContainer.Name = "StagesContainer"
	stagesContainer.Size = UDim2.new(0.94, 0, 0.85, 0)
	stagesContainer.Position = UDim2.new(0.03, 0, 0, 60)
	stagesContainer.BackgroundTransparency = 1
	stagesContainer.ZIndex = 11
	stagesContainer.Parent = modal
	UIController.Elements.StagesContainer = stagesContainer

	local stageScroll = Instance.new("ScrollingFrame")
	stageScroll.Name = "StageScroll"
	stageScroll.Size = UDim2.new(0.58, 0, 1, 0)
	stageScroll.BackgroundTransparency = 1
	stageScroll.BorderSizePixel = 0
	stageScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	stageScroll.ZIndex = 11
	stageScroll.Parent = stagesContainer
	UIController.Elements.StageScroll = stageScroll

	local sLayout = Instance.new("UIGridLayout")
	sLayout.CellSize = UDim2.new(0, 95, 0, 95)
	sLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	sLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sLayout.Parent = stageScroll

	-- Stage Detail Panel (Right side)
	local detail = Instance.new("Frame")
	detail.Name = "DetailPanel"
	detail.Size = UDim2.new(0.39, 0, 1, 0)
	detail.Position = UDim2.new(0.61, 0, 0, 0)
	detail.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
	detail.BorderSizePixel = 0
	detail.ZIndex = 11
	detail.Parent = stagesContainer
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
	stageDescLbl.Text = "Standard stage."
	stageDescLbl.ZIndex = 12
	stageDescLbl.Parent = detail
	UIController.Elements.StageDesc = stageDescLbl

	-- Skip Battle Checkbox Toggle
	local isSkipEnabled = false
	local skipToggle = Instance.new("TextButton")
	skipToggle.Name = "SkipToggle"
	skipToggle.Size = UDim2.new(0.9, 0, 0.10, 0)
	skipToggle.Position = UDim2.new(0.05, 0, 0.56, 0)
	skipToggle.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
	skipToggle.TextColor3 = Color3.fromRGB(100, 230, 255)
	skipToggle.TextScaled = true
	skipToggle.Font = Enum.Font.GothamBold
	skipToggle.Text = "▶ Watch Battle: [ON]"
	skipToggle.ZIndex = 12
	skipToggle.Parent = detail
	UIController.Elements.SkipToggle = skipToggle

	skipToggle.MouseButton1Click:Connect(function()
		local isSkipUnlocked = StageData.IsMilestoneReached(UIController.State.HighestClearedStage, "5-10")
		if not isSkipUnlocked and not isSkipEnabled then
			UIController.ShowNotification("🔒 Instant Skip unlocks after clearing Chapter 5-10!", Color3.fromRGB(255, 180, 50))
			return
		end
		isSkipEnabled = not isSkipEnabled
		skipToggle.Text = isSkipEnabled and "⚡ Instant Skip: [ON]" or "▶ Watch Battle: [ON]"
	end)

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

	-- Battle / Advance Button
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
		if battleBtn.Text:find("Proceed to Chapter") then
			-- Switch to next chapter
			local nextChap = UIController.SelectedChapter + 1
			if StageData.Chapters[nextChap] then
				UIController.SelectedChapter = nextChap
				UIController.SelectedStageId = string.format("%d-1", nextChap)
				UIController.RefreshCampaignCards()
			end
			return
		end

		if battleBtn.Active and UIController.Remotes.StartBattle then
			UIController.Remotes.StartBattle:FireServer(UIController.SelectedStageId, isSkipEnabled)
		end
	end)

	-- 2. CHAPTERS VIEW CONTAINER
	local chaptersContainer = Instance.new("ScrollingFrame")
	chaptersContainer.Name = "ChaptersContainer"
	chaptersContainer.Size = UDim2.new(0.94, 0, 0.85, 0)
	chaptersContainer.Position = UDim2.new(0.03, 0, 0, 60)
	chaptersContainer.BackgroundTransparency = 1
	chaptersContainer.BorderSizePixel = 0
	chaptersContainer.Visible = false
	chaptersContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chaptersContainer.ZIndex = 11
	chaptersContainer.Parent = modal
	UIController.Elements.ChaptersContainer = chaptersContainer

	local cListLayout = Instance.new("UIListLayout")
	cListLayout.Padding = UDim.new(0, 14)
	cListLayout.Parent = chaptersContainer

	-- Tab Buttons Switching Logic
	local function SwitchCampaignView(view: "Stages" | "Chapters")
		UIController.CurrentCampaignView = view
		if view == "Stages" then
			btnStagesTab.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
			btnStagesTab.TextColor3 = Color3.fromRGB(255, 255, 255)
			btnChaptersTab.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
			btnChaptersTab.TextColor3 = Color3.fromRGB(200, 210, 225)
			stagesContainer.Visible = true
			chaptersContainer.Visible = false
			UIController.RefreshCampaignCards()
		else
			btnChaptersTab.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
			btnChaptersTab.TextColor3 = Color3.fromRGB(255, 255, 255)
			btnStagesTab.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
			btnStagesTab.TextColor3 = Color3.fromRGB(200, 210, 225)
			stagesContainer.Visible = false
			chaptersContainer.Visible = true
			UIController.RefreshChaptersList()
		end
	end

	btnStagesTab.MouseButton1Click:Connect(function()
		SwitchCampaignView("Stages")
	end)
	btnChaptersTab.MouseButton1Click:Connect(function()
		SwitchCampaignView("Chapters")
	end)

	UIController.RefreshCampaignCards()
end

function UIController.RefreshChaptersList()
	local scroll = UIController.Elements.ChaptersContainer
	if not scroll then return end

	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local highest = UIController.State.HighestClearedStage
	local clearedKey = StageData.ParseStageKey(highest)

	for chapNum = 1, 5 do
		local chapDef = StageData.Chapters[chapNum]
		if not chapDef then continue end

		local reqStage = chapDef.RequiredClearedStage
		local isUnlocked = true
		if reqStage then
			local reqKey = StageData.ParseStageKey(reqStage)
			isUnlocked = clearedKey >= reqKey
		end

		local card = Instance.new("Frame")
		card.Name = "ChapterCard_" .. chapNum
		card.Size = UDim2.new(1, 0, 0, 95)
		card.BackgroundColor3 = isUnlocked and Color3.fromRGB(28, 32, 45) or Color3.fromRGB(20, 22, 28)
		card.ZIndex = 12
		card.Parent = scroll

		local cCorn = Instance.new("UICorner")
		cCorn.CornerRadius = UDim.new(0, 12)
		cCorn.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = isUnlocked and chapDef.ThemeColor or Color3.fromRGB(50, 55, 65)
		cStroke.Thickness = 2
		cStroke.Parent = card

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.65, 0, 0.45, 0)
		title.Position = UDim2.new(0.04, 0, 0.12, 0)
		title.BackgroundTransparency = 1
		title.TextColor3 = isUnlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 150)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = chapDef.Name .. (isUnlocked and "" or " 🔒 (Locked)")
		title.ZIndex = 13
		title.Parent = card

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(0.65, 0, 0.35, 0)
		sub.Position = UDim2.new(0.04, 0, 0.52, 0)
		sub.BackgroundTransparency = 1
		sub.TextColor3 = isUnlocked and Color3.fromRGB(180, 200, 220) or Color3.fromRGB(110, 110, 120)
		sub.TextScaled = true
		sub.Font = Enum.Font.Gotham
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Text = string.format("Subtitle: %s | 10 Stages", chapDef.Subtitle)
		sub.ZIndex = 13
		sub.Parent = card

		local selectBtn = Instance.new("TextButton")
		selectBtn.Size = UDim2.new(0.24, 0, 0.6, 0)
		selectBtn.Position = UDim2.new(0.72, 0, 0.2, 0)
		selectBtn.BackgroundColor3 = isUnlocked and Color3.fromRGB(45, 130, 220) or Color3.fromRGB(50, 50, 60)
		selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		selectBtn.TextScaled = true
		selectBtn.Font = Enum.Font.GothamBold
		selectBtn.Text = isUnlocked and "ENTER ➔" or "LOCKED 🔒"
		selectBtn.Active = isUnlocked
		selectBtn.ZIndex = 13
		selectBtn.Parent = card

		local sCorn = Instance.new("UICorner")
		sCorn.CornerRadius = UDim.new(0, 8)
		sCorn.Parent = selectBtn

		selectBtn.MouseButton1Click:Connect(function()
			if isUnlocked then
				UIController.SelectedChapter = chapNum
				UIController.SelectedStageId = string.format("%d-1", chapNum)
				UIController.CurrentCampaignView = "Stages"

				local bStages = UIController.Elements.BtnStagesTab
				local bChaps = UIController.Elements.BtnChaptersTab
				if bStages and bChaps then
					bStages.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
					bStages.TextColor3 = Color3.fromRGB(255, 255, 255)
					bChaps.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
					bChaps.TextColor3 = Color3.fromRGB(200, 210, 225)
				end

				if UIController.Elements.StagesContainer then
					UIController.Elements.StagesContainer.Visible = true
				end
				if UIController.Elements.ChaptersContainer then
					UIController.Elements.ChaptersContainer.Visible = false
				end

				UIController.RefreshCampaignCards()
			end
		end)
	end
end

function UIController.RefreshCampaignCards()
	local scroll = UIController.Elements.StageScroll
	if not scroll then return end

	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local chapNum = UIController.SelectedChapter
	local chapDef = StageData.Chapters[chapNum]
	if UIController.Elements.CampaignHeaderTitle and chapDef then
		UIController.Elements.CampaignHeaderTitle.Text = string.format("⚔️ %s", chapDef.Name:upper())
	end

	local highest = UIController.State.HighestClearedStage
	local clearedKey = StageData.ParseStageKey(highest)

	for idx = 1, 10 do
		local stageId = string.format("%d-%d", chapNum, idx)
		local stageKey = chapNum * 100 + idx
		local isMiniBoss = (idx == 5)
		local isBoss = (idx == 10)

		local card = Instance.new("TextButton")
		card.Name = "StageCard_" .. idx
		card.LayoutOrder = idx
		card.ZIndex = 12
		card.Parent = scroll

		local cCorn = Instance.new("UICorner")
		cCorn.CornerRadius = UDim.new(0, 10)
		cCorn.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Thickness = 2
		cStroke.Parent = card

		if stageKey <= clearedKey then
			-- Cleared stage
			card.BackgroundColor3 = isBoss and Color3.fromRGB(110, 30, 50) or (isMiniBoss and Color3.fromRGB(90, 50, 30) or Color3.fromRGB(30, 45, 60))
			card.TextColor3 = Color3.fromRGB(160, 240, 180)
			card.Text = string.format("%d-%d\n★★★ CLEARED", chapNum, idx)
			cStroke.Color = Color3.fromRGB(60, 200, 120)
		elseif StageData.IsStageUnlocked(highest, stageId) then
			-- Current active stage
			card.BackgroundColor3 = isBoss and Color3.fromRGB(190, 40, 70) or (isMiniBoss and Color3.fromRGB(170, 70, 30) or Color3.fromRGB(45, 60, 95))
			card.TextColor3 = Color3.fromRGB(255, 255, 255)
			card.Text = isBoss and string.format("%d-10\n👑 BOSS", chapNum) or (isMiniBoss and string.format("%d-5\n👹 MINI-BOSS", chapNum) or string.format("%d-%d\n⚔️ ACTIVE", chapNum, idx))
			cStroke.Color = Color3.fromRGB(255, 220, 60)
		else
			-- Future locked stage
			card.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
			card.TextColor3 = Color3.fromRGB(130, 130, 140)
			card.Text = string.format("%d-%d\n🔒 LOCKED", chapNum, idx)
			cStroke.Color = Color3.fromRGB(50, 55, 65)
		end

		card.TextScaled = true
		card.Font = Enum.Font.GothamBold

		card.MouseButton1Click:Connect(function()
			UIController.SelectedStageId = stageId
			UIController.UpdateSelectedStageDetail(stageId)
		end)
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

	local highest = UIController.State.HighestClearedStage
	local clearedKey = StageData.ParseStageKey(highest)
	local targetKey = StageData.ParseStageKey(stageId)
	local isUnlocked = StageData.IsStageUnlocked(highest, stageId)
	local isCleared = (targetKey <= clearedKey and clearedKey > 0)

	-- Check if current chapter is fully conquered (e.g. 1-10 is beaten)
	local chapNum = sDef.Chapter
	local chapBossKey = chapNum * 100 + 10
	local isChapterConquered = (clearedKey >= chapBossKey)

	stageNameLbl.Text = sDef.Name .. (isCleared and " [CLEARED]" or (isUnlocked and " [ACTIVE]" or " [LOCKED]"))
	stageDescLbl.Text = string.format(
		"Chapter %d - Stage %d\n%s\n\nFirst Clear Rewards:\n💎 %d Diamonds\n📜 %d Basic Scrolls%s\n🧪 %d Elixir\n%s\n\nAFK Loot Rate:\n💰 +%d/m  🧪 +%d/m",
		sDef.Chapter, sDef.StageIndex,
		(sDef.IsBoss and "⚠️ CHAPTER BOSS FIGHT!" or (sDef.IsMiniBoss and "⚠️ MINI-BOSS ENCOUNTER!" or (not isUnlocked and "🔒 Stage locked. Clear prior stages to access." or "Ready for battle!"))),
		sDef.FirstClearRewards.Diamonds,
		sDef.FirstClearRewards.BasicScrolls or 1,
		(sDef.FirstClearRewards.EliteScrolls and sDef.FirstClearRewards.EliteScrolls > 0) and string.format("\n🔮 %d Elite Scrolls", sDef.FirstClearRewards.EliteScrolls) or "",
		sDef.FirstClearRewards.Elixir,
		(sDef.FirstClearRewards.GuaranteedEquipment and ("🎁 Guaranteed: " .. sDef.FirstClearRewards.GuaranteedEquipment) or ""),
		sDef.AfkRates.GoldPerMin,
		sDef.AfkRates.ElixirPerMin
	)

	if isChapterConquered and sDef.StageIndex == 10 then
		-- Entire chapter finished! Offer clean button to proceed to next chapter
		local nextChap = chapNum + 1
		battleBtn.Text = string.format("PROCEED TO CHAPTER %d ➔", nextChap)
		battleBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 220)
		battleBtn.Active = true
	elseif isCleared then
		-- No repeat battle!
		battleBtn.Text = "★ STAGE CLEARED"
		battleBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 65)
		battleBtn.Active = false
	elseif isUnlocked then
		battleBtn.Text = "⚔️ BATTLE"
		battleBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
		battleBtn.Active = true
	else
		battleBtn.Text = "🔒 LOCKED"
		battleBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
		battleBtn.Active = false
	end
end

function UIController.BuildSummonModal()
	local modal = Instance.new("Frame")
	modal.Name = "SummonModal"
	modal.Size = UDim2.new(0.78, 0, 0.82, 0)
	modal.Position = UDim2.new(0.11, 0, 0.09, 0)
	modal.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
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
	header.Text = "✨ SUMMON ALTAR: HERO SUMMONS"
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

	local cardsContainer = Instance.new("Frame")
	cardsContainer.Size = UDim2.new(0.92, 0, 0.82, 0)
	cardsContainer.Position = UDim2.new(0.04, 0, 0.14, 0)
	cardsContainer.BackgroundTransparency = 1
	cardsContainer.ZIndex = 11
	cardsContainer.Parent = modal

	local cLayout = Instance.new("UIListLayout")
	cLayout.FillDirection = Enum.FillDirection.Horizontal
	cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cLayout.Padding = UDim.new(0, 22)
	cLayout.Parent = cardsContainer

	-- ========================================================
	-- COLUMN 1: BASIC SUMMON ALTAR (1-4★, 1x Free Daily)
	-- ========================================================
	local basicCard = Instance.new("Frame")
	basicCard.Name = "BasicAltarCard"
	basicCard.Size = UDim2.new(0.48, 0, 0.96, 0)
	basicCard.BackgroundColor3 = Color3.fromRGB(26, 24, 38)
	basicCard.ZIndex = 12
	basicCard.Parent = cardsContainer

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 12)
	bCorner.Parent = basicCard

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(100, 160, 240)
	bStroke.Thickness = 2
	bStroke.Parent = basicCard

	local bTitle = Instance.new("TextLabel")
	bTitle.Size = UDim2.new(0.7, 0, 0.12, 0)
	bTitle.Position = UDim2.new(0.05, 0, 0.04, 0)
	bTitle.BackgroundTransparency = 1
	bTitle.TextColor3 = Color3.fromRGB(150, 200, 255)
	bTitle.TextScaled = true
	bTitle.Font = Enum.Font.GothamBlack
	bTitle.TextXAlignment = Enum.TextXAlignment.Left
	bTitle.Text = "📜 BASIC SUMMON"
	bTitle.ZIndex = 13
	bTitle.Parent = basicCard

	local bRatesBtn = Instance.new("TextButton")
	bRatesBtn.Size = UDim2.new(0.22, 0, 0.1, 0)
	bRatesBtn.Position = UDim2.new(0.73, 0, 0.04, 0)
	bRatesBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
	bRatesBtn.TextColor3 = Color3.fromRGB(180, 220, 255)
	bRatesBtn.TextScaled = true
	bRatesBtn.Font = Enum.Font.GothamBold
	bRatesBtn.Text = "ℹ️ Rates"
	bRatesBtn.ZIndex = 13
	bRatesBtn.Parent = basicCard

	local brCorn = Instance.new("UICorner")
	brCorn.CornerRadius = UDim.new(0, 6)
	brCorn.Parent = bRatesBtn

	bRatesBtn.MouseButton1Click:Connect(function()
		UIController.ShowRatesModal("Basic")
	end)

	local bDesc = Instance.new("TextLabel")
	bDesc.Size = UDim2.new(0.9, 0, 0.16, 0)
	bDesc.Position = UDim2.new(0.05, 0, 0.18, 0)
	bDesc.BackgroundTransparency = 1
	bDesc.TextColor3 = Color3.fromRGB(190, 205, 220)
	bDesc.TextScaled = true
	bDesc.Font = Enum.Font.Gotham
	bDesc.Text = "Summon common to rare allies!\nPool: 1★ to 4★ Heroes.\nIncludes 1x Free Daily Summon!"
	bDesc.ZIndex = 13
	bDesc.Parent = basicCard

	-- Row 1: 1x Basic Summon Button
	local btnBasic1x = Instance.new("TextButton")
	btnBasic1x.Name = "BtnBasic1x"
	btnBasic1x.Size = UDim2.new(0.9, 0, 0.22, 0)
	btnBasic1x.Position = UDim2.new(0.05, 0, 0.44, 0)
	btnBasic1x.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
	btnBasic1x.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnBasic1x.TextScaled = true
	btnBasic1x.Font = Enum.Font.GothamBold
	btnBasic1x.Text = "1x SUMMON"
	btnBasic1x.ZIndex = 13
	btnBasic1x.Parent = basicCard
	UIController.Elements.BtnBasic1x = btnBasic1x

	local b1Corn = Instance.new("UICorner")
	b1Corn.CornerRadius = UDim.new(0, 10)
	b1Corn.Parent = btnBasic1x

	btnBasic1x.MouseButton1Click:Connect(function()
		if UIController.Remotes.RollGacha then
			UIController.Remotes.RollGacha:FireServer(1, "Basic", "Scrolls")
		end
	end)

	-- Row 2: 10x Basic Summon Button
	local btnBasic10x = Instance.new("TextButton")
	btnBasic10x.Name = "BtnBasic10x"
	btnBasic10x.Size = UDim2.new(0.9, 0, 0.22, 0)
	btnBasic10x.Position = UDim2.new(0.05, 0, 0.71, 0)
	btnBasic10x.BackgroundColor3 = Color3.fromRGB(35, 100, 180)
	btnBasic10x.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnBasic10x.TextScaled = true
	btnBasic10x.Font = Enum.Font.GothamBold
	btnBasic10x.Text = "10x SUMMON"
	btnBasic10x.ZIndex = 13
	btnBasic10x.Parent = basicCard
	UIController.Elements.BtnBasic10x = btnBasic10x

	local b10Corn = Instance.new("UICorner")
	b10Corn.CornerRadius = UDim.new(0, 10)
	b10Corn.Parent = btnBasic10x

	btnBasic10x.MouseButton1Click:Connect(function()
		if UIController.Remotes.RollGacha then
			UIController.Remotes.RollGacha:FireServer(10, "Basic", "Scrolls")
		end
	end)

	-- ========================================================
	-- COLUMN 2: ELITE / GACOR SUMMON ALTAR (3-5★ GACOR!)
	-- ========================================================
	local eliteCard = Instance.new("Frame")
	eliteCard.Name = "EliteAltarCard"
	eliteCard.Size = UDim2.new(0.48, 0, 0.96, 0)
	eliteCard.BackgroundColor3 = Color3.fromRGB(34, 22, 42)
	eliteCard.ZIndex = 12
	eliteCard.Parent = cardsContainer

	local eCorner = Instance.new("UICorner")
	eCorner.CornerRadius = UDim.new(0, 12)
	eCorner.Parent = eliteCard

	local eStroke = Instance.new("UIStroke")
	eStroke.Color = Color3.fromRGB(255, 180, 50)
	eStroke.Thickness = 2.5
	eStroke.Parent = eliteCard

	local eTitle = Instance.new("TextLabel")
	eTitle.Size = UDim2.new(0.7, 0, 0.12, 0)
	eTitle.Position = UDim2.new(0.05, 0, 0.04, 0)
	eTitle.BackgroundTransparency = 1
	eTitle.TextColor3 = Color3.fromRGB(255, 215, 60)
	eTitle.TextScaled = true
	eTitle.Font = Enum.Font.GothamBlack
	eTitle.TextXAlignment = Enum.TextXAlignment.Left
	eTitle.Text = "🔮 ELITE ALTAR (GACOR)"
	eTitle.ZIndex = 13
	eTitle.Parent = eliteCard

	local eRatesBtn = Instance.new("TextButton")
	eRatesBtn.Size = UDim2.new(0.22, 0, 0.1, 0)
	eRatesBtn.Position = UDim2.new(0.73, 0, 0.04, 0)
	eRatesBtn.BackgroundColor3 = Color3.fromRGB(70, 45, 60)
	eRatesBtn.TextColor3 = Color3.fromRGB(255, 220, 120)
	eRatesBtn.TextScaled = true
	eRatesBtn.Font = Enum.Font.GothamBold
	eRatesBtn.Text = "ℹ️ Rates"
	eRatesBtn.ZIndex = 13
	eRatesBtn.Parent = eliteCard

	local erCorn = Instance.new("UICorner")
	erCorn.CornerRadius = UDim.new(0, 6)
	erCorn.Parent = eRatesBtn

	eRatesBtn.MouseButton1Click:Connect(function()
		UIController.ShowRatesModal("Elite")
	end)

	local eDesc = Instance.new("TextLabel")
	eDesc.Size = UDim2.new(0.9, 0, 0.16, 0)
	eDesc.Position = UDim2.new(0.05, 0, 0.18, 0)
	eDesc.BackgroundTransparency = 1
	eDesc.TextColor3 = Color3.fromRGB(230, 205, 220)
	eDesc.TextScaled = true
	eDesc.Font = Enum.Font.Gotham
	eDesc.Text = "High-tier sacred summon!\nGuaranteed 3★ or above!\n5% chance for legendary 5★ Heroes!"
	eDesc.ZIndex = 13
	eDesc.Parent = eliteCard

	-- Row 1: 1x Elite Summon Button
	local btnElite1x = Instance.new("TextButton")
	btnElite1x.Name = "BtnElite1x"
	btnElite1x.Size = UDim2.new(0.9, 0, 0.22, 0)
	btnElite1x.Position = UDim2.new(0.05, 0, 0.44, 0)
	btnElite1x.BackgroundColor3 = Color3.fromRGB(180, 70, 200)
	btnElite1x.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnElite1x.TextScaled = true
	btnElite1x.Font = Enum.Font.GothamBold
	btnElite1x.Text = "1x ELITE SUMMON"
	btnElite1x.ZIndex = 13
	btnElite1x.Parent = eliteCard
	UIController.Elements.BtnElite1x = btnElite1x

	local e1Corn = Instance.new("UICorner")
	e1Corn.CornerRadius = UDim.new(0, 10)
	e1Corn.Parent = btnElite1x

	btnElite1x.MouseButton1Click:Connect(function()
		if UIController.Remotes.RollGacha then
			UIController.Remotes.RollGacha:FireServer(1, "Elite", "Scrolls")
		end
	end)

	-- Row 2: 10x Elite Summon Button
	local btnElite10x = Instance.new("TextButton")
	btnElite10x.Name = "BtnElite10x"
	btnElite10x.Size = UDim2.new(0.9, 0, 0.22, 0)
	btnElite10x.Position = UDim2.new(0.05, 0, 0.71, 0)
	btnElite10x.BackgroundColor3 = Color3.fromRGB(210, 130, 30)
	btnElite10x.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnElite10x.TextScaled = true
	btnElite10x.Font = Enum.Font.GothamBlack
	btnElite10x.Text = "10x ELITE SUMMON"
	btnElite10x.ZIndex = 13
	btnElite10x.Parent = eliteCard
	UIController.Elements.BtnElite10x = btnElite10x

	local e10Corn = Instance.new("UICorner")
	e10Corn.CornerRadius = UDim.new(0, 10)
	e10Corn.Parent = btnElite10x

	btnElite10x.MouseButton1Click:Connect(function()
		if UIController.Remotes.RollGacha then
			UIController.Remotes.RollGacha:FireServer(10, "Elite", "Scrolls")
		end
	end)

	UIController.RefreshSummonButtons()
end

function UIController.RefreshSummonButtons()
	local btnB1 = UIController.Elements.BtnBasic1x
	local btnB10 = UIController.Elements.BtnBasic10x
	local btnE1 = UIController.Elements.BtnElite1x
	local btnE10 = UIController.Elements.BtnElite10x
	if not btnB1 or not btnB10 or not btnE1 or not btnE10 then return end

	local basicScrolls = UIController.State.BasicScrolls or 0
	local eliteScrolls = UIController.State.EliteScrolls or 0
	local lastFree = UIController.State.LastFreeBasicSummon or 0
	local isFreeAvailable = (lastFree == 0) or ((os.time() - lastFree) >= 86400)

	-- Basic 1x: Free > Scroll > Diamonds
	if isFreeAvailable then
		btnB1.Text = "🎁 1x SUMMON [FREE TODAY]"
		btnB1.BackgroundColor3 = Color3.fromRGB(45, 175, 75)
	elseif basicScrolls >= 1 then
		btnB1.Text = string.format("📜 1x SUMMON (1 Scroll | Have: %d)", basicScrolls)
		btnB1.BackgroundColor3 = Color3.fromRGB(210, 110, 40)
	else
		btnB1.Text = "💎 1x SUMMON (50 💎)"
		btnB1.BackgroundColor3 = Color3.fromRGB(40, 110, 190)
	end

	-- Basic 10x: Scroll > Diamonds
	if basicScrolls >= 10 then
		btnB10.Text = string.format("📜 10x SUMMON (10 Scrolls | Have: %d)", basicScrolls)
		btnB10.BackgroundColor3 = Color3.fromRGB(210, 110, 40)
	else
		btnB10.Text = "💎 10x SUMMON (450 💎)"
		btnB10.BackgroundColor3 = Color3.fromRGB(40, 110, 190)
	end

	-- Elite 1x: Scroll > Diamonds
	if eliteScrolls >= 1 then
		btnE1.Text = string.format("🔮 1x ELITE (1 Scroll | Have: %d)", eliteScrolls)
		btnE1.BackgroundColor3 = Color3.fromRGB(160, 60, 210)
	else
		btnE1.Text = "💎 1x ELITE (220 💎)"
		btnE1.BackgroundColor3 = Color3.fromRGB(60, 130, 210)
	end

	-- Elite 10x: Scroll > Diamonds
	if eliteScrolls >= 10 then
		btnE10.Text = string.format("🔮 10x ELITE (10 Scrolls | Have: %d)", eliteScrolls)
		btnE10.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
	else
		btnE10.Text = "💎 10x ELITE (2,000 💎)"
		btnE10.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
	end
end

function UIController.BuildSummonRatesModal()
	local modal = Instance.new("Frame")
	modal.Name = "SummonRatesModal"
	modal.Size = UDim2.new(0.46, 0, 0.52, 0)
	modal.Position = UDim2.new(0.27, 0, 0.24, 0)
	modal.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 20
	modal.Parent = UIController.ScreenGui
	UIController.Elements.SummonRatesModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 140, 200)
	stroke.Thickness = 2
	stroke.Parent = modal

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.8, 0, 0, 44)
	titleLbl.Position = UDim2.new(0.06, 0, 0, 6)
	titleLbl.BackgroundTransparency = 1
	titleLbl.TextColor3 = Color3.fromRGB(255, 230, 90)
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Text = "ℹ️ SUMMON DROP RATES & POOL"
	titleLbl.ZIndex = 21
	titleLbl.Parent = modal
	UIController.Elements.RatesTitle = titleLbl

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -38, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 22
	closeBtn.Parent = modal

	local cCorn = Instance.new("UICorner")
	cCorn.CornerRadius = UDim.new(0, 8)
	cCorn.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	local bodyLbl = Instance.new("TextLabel")
	bodyLbl.Size = UDim2.new(0.88, 0, 0.72, 0)
	bodyLbl.Position = UDim2.new(0.06, 0, 0, 52)
	bodyLbl.BackgroundTransparency = 1
	bodyLbl.TextColor3 = Color3.fromRGB(210, 220, 235)
	bodyLbl.TextScaled = true
	bodyLbl.Font = Enum.Font.Gotham
	bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
	bodyLbl.ZIndex = 21
	bodyLbl.Parent = modal
	UIController.Elements.RatesBody = bodyLbl
end

function UIController.ShowRatesModal(altarType: "Basic" | "Elite")
	local modal = UIController.Elements.SummonRatesModal
	local title = UIController.Elements.RatesTitle
	local body = UIController.Elements.RatesBody
	if not modal or not title or not body then return end

	if altarType == "Basic" then
		title.Text = "ℹ️ BASIC ALTAR DROP RATES"
		body.Text = "✦ 4★ Elite Heroes:  3.00%\n   (Garrick, Ember, Vane)\n\n✦ 3★ Rare Heroes:   12.00%\n   (Bastian, Silas, Verdant, Crimson)\n\n✦ 2★ Soldiers:        35.00%\n   (Veteran Guard, Village Healer, Iron Sentry)\n\n✦ 1★ Recruits:        50.00%\n   (Town Militia, Frontier Scout, Novice Mage)\n\n🎁 1x Free Daily Summon resets every 24 hours!"
	else
		title.Text = "ℹ️ ELITE ALTAR (GACOR) DROP RATES"
		body.Text = "✦ 5★ Legendary (GACOR):  5.00%\n   (Brunhilda, Lyra, Aurelia, Ignis, Seraphina)\n\n✦ 4★ Elite Heroes:           25.00%\n   (Garrick, Ember, Vane)\n\n✦ 3★ Rare Heroes:            70.00%\n   (Bastian, Silas, Verdant, Crimson)\n\n✨ Guaranteed 3★ or higher on every single roll!"
	end

	modal.Visible = true
end

function UIController.BuildMailboxModal()
	local modal = Instance.new("Frame")
	modal.Name = "MailboxModal"
	modal.Size = UDim2.new(0.68, 0, 0.76, 0)
	modal.Position = UDim2.new(0.16, 0, 0.12, 0)
	modal.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 15
	modal.Parent = UIController.ScreenGui
	UIController.Elements.MailboxModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 140, 220)
	stroke.Thickness = 2
	stroke.Parent = modal

	-- Header
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(220, 240, 255)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.Text = "📬 INGAME MAILBOX & REWARD INBOX"
	header.ZIndex = 16
	header.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 34, 0, 34)
	closeBtn.Position = UDim2.new(1, -40, 0, 7)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 17
	closeBtn.Parent = modal

	local cCorn = Instance.new("UICorner")
	cCorn.CornerRadius = UDim.new(0, 8)
	cCorn.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	-- Left Mails List
	local mailList = Instance.new("ScrollingFrame")
	mailList.Size = UDim2.new(0.42, 0, 0.76, 0)
	mailList.Position = UDim2.new(0.04, 0, 0, 56)
	mailList.BackgroundTransparency = 1
	mailList.BorderSizePixel = 0
	mailList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	mailList.ZIndex = 16
	mailList.Parent = modal
	UIController.Elements.MailList = mailList

	local mLayout = Instance.new("UIListLayout")
	mLayout.Padding = UDim.new(0, 8)
	mLayout.Parent = mailList

	-- Right Mail Content Reader
	local reader = Instance.new("Frame")
	reader.Size = UDim2.new(0.48, 0, 0.76, 0)
	reader.Position = UDim2.new(0.48, 0, 0, 56)
	reader.BackgroundColor3 = Color3.fromRGB(25, 30, 44)
	reader.ZIndex = 16
	reader.Parent = modal

	local rCorn = Instance.new("UICorner")
	rCorn.CornerRadius = UDim.new(0, 10)
	rCorn.Parent = reader

	local mailTitleLbl = Instance.new("TextLabel")
	mailTitleLbl.Size = UDim2.new(0.9, 0, 0.14, 0)
	mailTitleLbl.Position = UDim2.new(0.05, 0, 0.04, 0)
	mailTitleLbl.BackgroundTransparency = 1
	mailTitleLbl.TextColor3 = Color3.fromRGB(255, 230, 90)
	mailTitleLbl.TextScaled = true
	mailTitleLbl.Font = Enum.Font.GothamBold
	mailTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
	mailTitleLbl.Text = "Select a mail"
	mailTitleLbl.ZIndex = 17
	mailTitleLbl.Parent = reader
	UIController.Elements.MailTitleLbl = mailTitleLbl

	local mailBodyLbl = Instance.new("TextLabel")
	mailBodyLbl.Size = UDim2.new(0.9, 0, 0.44, 0)
	mailBodyLbl.Position = UDim2.new(0.05, 0, 0.18, 0)
	mailBodyLbl.BackgroundTransparency = 1
	mailBodyLbl.TextColor3 = Color3.fromRGB(200, 215, 230)
	mailBodyLbl.TextScaled = true
	mailBodyLbl.Font = Enum.Font.Gotham
	mailBodyLbl.TextXAlignment = Enum.TextXAlignment.Left
	mailBodyLbl.ZIndex = 17
	mailBodyLbl.Parent = reader
	UIController.Elements.MailBodyLbl = mailBodyLbl

	local mailItemsLbl = Instance.new("TextLabel")
	mailItemsLbl.Size = UDim2.new(0.9, 0, 0.16, 0)
	mailItemsLbl.Position = UDim2.new(0.05, 0, 0.63, 0)
	mailItemsLbl.BackgroundTransparency = 1
	mailItemsLbl.TextColor3 = Color3.fromRGB(120, 255, 160)
	mailItemsLbl.TextScaled = true
	mailItemsLbl.Font = Enum.Font.GothamBold
	mailItemsLbl.TextXAlignment = Enum.TextXAlignment.Left
	mailItemsLbl.ZIndex = 17
	mailItemsLbl.Parent = reader
	UIController.Elements.MailItemsLbl = mailItemsLbl

	local claimSingleBtn = Instance.new("TextButton")
	claimSingleBtn.Size = UDim2.new(0.9, 0, 0.14, 0)
	claimSingleBtn.Position = UDim2.new(0.05, 0, 0.82, 0)
	claimSingleBtn.BackgroundColor3 = Color3.fromRGB(45, 160, 85)
	claimSingleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	claimSingleBtn.TextScaled = true
	claimSingleBtn.Font = Enum.Font.GothamBold
	claimSingleBtn.Text = "🎁 CLAIM MAIL REWARD"
	claimSingleBtn.ZIndex = 17
	claimSingleBtn.Parent = reader
	UIController.Elements.ClaimSingleMailBtn = claimSingleBtn

	local csCorn = Instance.new("UICorner")
	csCorn.CornerRadius = UDim.new(0, 8)
	csCorn.Parent = claimSingleBtn

	claimSingleBtn.MouseButton1Click:Connect(function()
		if UIController.SelectedMailId and UIController.Remotes.ClaimMail then
			UIController.Remotes.ClaimMail:FireServer(UIController.SelectedMailId)
		end
	end)

	-- Bottom Left Claim All Button
	local claimAllBtn = Instance.new("TextButton")
	claimAllBtn.Size = UDim2.new(0.42, 0, 0, 42)
	claimAllBtn.Position = UDim2.new(0.04, 0, 0.88, 0)
	claimAllBtn.BackgroundColor3 = Color3.fromRGB(45, 130, 210)
	claimAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	claimAllBtn.TextScaled = true
	claimAllBtn.Font = Enum.Font.GothamBold
	claimAllBtn.Text = "🎁 CLAIM ALL MAILS"
	claimAllBtn.ZIndex = 16
	claimAllBtn.Parent = modal

	local caCorn = Instance.new("UICorner")
	caCorn.CornerRadius = UDim.new(0, 8)
	caCorn.Parent = claimAllBtn

	claimAllBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.ClaimAllMails then
			UIController.Remotes.ClaimAllMails:FireServer()
		end
	end)
end

function UIController.RefreshMailboxUI()
	local list = UIController.Elements.MailList
	if not list then return end

	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local mails = UIController.State.Mailbox or {}
	local firstMailId = nil

	for id, mail in pairs(mails) do
		if not firstMailId then firstMailId = id end

		local card = Instance.new("TextButton")
		card.Name = "MailCard_" .. id
		card.Size = UDim2.new(1, 0, 0, 56)
		card.BackgroundColor3 = mail.Claimed and Color3.fromRGB(25, 28, 38) or Color3.fromRGB(36, 44, 62)
		card.ZIndex = 17
		card.Parent = list

		local cCorn = Instance.new("UICorner")
		cCorn.CornerRadius = UDim.new(0, 8)
		cCorn.Parent = card

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(0.72, 0, 0.5, 0)
		title.Position = UDim2.new(0.05, 0, 0.1, 0)
		title.BackgroundTransparency = 1
		title.TextColor3 = mail.Claimed and Color3.fromRGB(160, 165, 175) or Color3.fromRGB(255, 255, 255)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = mail.Title
		title.ZIndex = 18
		title.Parent = card

		local status = Instance.new("TextLabel")
		status.Size = UDim2.new(0.2, 0, 0.4, 0)
		status.Position = UDim2.new(0.76, 0, 0.3, 0)
		status.BackgroundTransparency = 1
		status.TextColor3 = mail.Claimed and Color3.fromRGB(120, 130, 140) or Color3.fromRGB(255, 215, 60)
		status.TextScaled = true
		status.Font = Enum.Font.GothamBold
		status.Text = mail.Claimed and "Claimed" or "NEW!"
		status.ZIndex = 18
		status.Parent = card

		card.MouseButton1Click:Connect(function()
			UIController.SelectMail(id)
		end)
	end

	if not UIController.SelectedMailId and firstMailId then
		UIController.SelectMail(firstMailId)
	elseif UIController.SelectedMailId then
		UIController.SelectMail(UIController.SelectedMailId)
	end
end

function UIController.SelectMail(mailId: string)
	UIController.SelectedMailId = mailId
	local mail = (UIController.State.Mailbox or {})[mailId]
	local titleLbl = UIController.Elements.MailTitleLbl
	local bodyLbl = UIController.Elements.MailBodyLbl
	local itemsLbl = UIController.Elements.MailItemsLbl
	local claimBtn = UIController.Elements.ClaimSingleMailBtn
	if not titleLbl or not bodyLbl or not itemsLbl or not claimBtn then return end

	if not mail then
		titleLbl.Text = "No mail selected"
		bodyLbl.Text = ""
		itemsLbl.Text = ""
		claimBtn.Visible = false
		return
	end

	titleLbl.Text = mail.Title
	bodyLbl.Text = string.format("From: %s\n\n%s", mail.Sender or "HQ", mail.Content or "")

	local itemText = "Attachments: "
	local items = mail.Items or {}
	local parts = {}
	if items.Gold then table.insert(parts, string.format("💰 %d Gold", items.Gold)) end
	if items.Diamonds then table.insert(parts, string.format("💎 %d Diamonds", items.Diamonds)) end
	if items.Elixir then table.insert(parts, string.format("🧪 %d Elixir", items.Elixir)) end
	if items.BasicScrolls then table.insert(parts, string.format("📜 %d Basic Scrolls", items.BasicScrolls)) end
	if items.EliteScrolls then table.insert(parts, string.format("🔮 %d Elite Scrolls", items.EliteScrolls)) end
	if items.EquipmentId then table.insert(parts, string.format("🗡️ Equipment: %s", items.EquipmentId)) end
	if items.HeroId then table.insert(parts, string.format("⭐ Hero: %s", items.HeroId)) end

	if #parts == 0 then
		itemsLbl.Text = "No attachments (Notice only)"
		claimBtn.Visible = false
	else
		itemsLbl.Text = "Attachments: " .. table.concat(parts, " | ")
		claimBtn.Visible = not mail.Claimed
		claimBtn.Active = not mail.Claimed
		claimBtn.Text = mail.Claimed and "ALREADY CLAIMED" or "🎁 CLAIM MAIL REWARD"
		claimBtn.BackgroundColor3 = mail.Claimed and Color3.fromRGB(50, 55, 65) or Color3.fromRGB(45, 160, 85)
	end
end

function UIController.BuildMissionsModal()
	local modal = Instance.new("Frame")
	modal.Name = "MissionsModal"
	modal.Size = UDim2.new(0.68, 0, 0.78, 0)
	modal.Position = UDim2.new(0.16, 0, 0.11, 0)
	modal.BackgroundColor3 = Color3.fromRGB(18, 24, 28)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 15
	modal.Parent = UIController.ScreenGui
	UIController.Elements.MissionsModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 180, 160)
	stroke.Thickness = 2
	stroke.Parent = modal

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(220, 255, 240)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.Text = "📋 DAILY MISSIONS & CHEST REWARDS"
	header.ZIndex = 16
	header.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 34, 0, 34)
	closeBtn.Position = UDim2.new(1, -40, 0, 7)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 17
	closeBtn.Parent = modal

	local cCorn = Instance.new("UICorner")
	cCorn.CornerRadius = UDim.new(0, 8)
	cCorn.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	-- Top Point Progress Bar with Chests (20, 40, 60, 80, 100)
	local chestBar = Instance.new("Frame")
	chestBar.Size = UDim2.new(0.92, 0, 0, 70)
	chestBar.Position = UDim2.new(0.04, 0, 0, 54)
	chestBar.BackgroundColor3 = Color3.fromRGB(25, 34, 40)
	chestBar.ZIndex = 16
	chestBar.Parent = modal

	local cbCorn = Instance.new("UICorner")
	cbCorn.CornerRadius = UDim.new(0, 10)
	cbCorn.Parent = chestBar

	local pointsLbl = Instance.new("TextLabel")
	pointsLbl.Size = UDim2.new(0.24, 0, 0.4, 0)
	pointsLbl.Position = UDim2.new(0.03, 0, 0.1, 0)
	pointsLbl.BackgroundTransparency = 1
	pointsLbl.TextColor3 = Color3.fromRGB(255, 220, 90)
	pointsLbl.TextScaled = true
	pointsLbl.Font = Enum.Font.GothamBold
	pointsLbl.Text = "Points: 0/100"
	pointsLbl.ZIndex = 17
	pointsLbl.Parent = chestBar
	UIController.Elements.MissionPointsLbl = pointsLbl

	local chestsContainer = Instance.new("Frame")
	chestsContainer.Size = UDim2.new(0.7, 0, 0.8, 0)
	chestsContainer.Position = UDim2.new(0.28, 0, 0.1, 0)
	chestsContainer.BackgroundTransparency = 1
	chestsContainer.ZIndex = 17
	chestsContainer.Parent = chestBar
	UIController.Elements.ChestsContainer = chestsContainer

	local chLayout = Instance.new("UIListLayout")
	chLayout.FillDirection = Enum.FillDirection.Horizontal
	chLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	chLayout.Padding = UDim.new(0, 10)
	chLayout.Parent = chestsContainer

	local TIERS = { 20, 40, 60, 80, 100 }
	for _, tier in ipairs(TIERS) do
		local chBtn = Instance.new("TextButton")
		chBtn.Name = "Chest_" .. tier
		chBtn.Size = UDim2.new(0, 72, 0, 48)
		chBtn.BackgroundColor3 = Color3.fromRGB(40, 55, 65)
		chBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		chBtn.TextScaled = true
		chBtn.Font = Enum.Font.GothamBold
		chBtn.Text = string.format("🎁\n%d Pts", tier)
		chBtn.ZIndex = 18
		chBtn.Parent = chestsContainer

		local cCorn = Instance.new("UICorner")
		cCorn.CornerRadius = UDim.new(0, 8)
		cCorn.Parent = chBtn

		chBtn.MouseButton1Click:Connect(function()
			if UIController.Remotes.ClaimDailyChest then
				UIController.Remotes.ClaimDailyChest:FireServer(tier)
			end
		end)
	end

	-- Missions List
	local missionsScroll = Instance.new("ScrollingFrame")
	missionsScroll.Size = UDim2.new(0.92, 0, 0.62, 0)
	missionsScroll.Position = UDim2.new(0.04, 0, 0, 136)
	missionsScroll.BackgroundTransparency = 1
	missionsScroll.BorderSizePixel = 0
	missionsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	missionsScroll.ZIndex = 16
	missionsScroll.Parent = modal
	UIController.Elements.MissionsScroll = missionsScroll

	local msLayout = Instance.new("UIListLayout")
	msLayout.Padding = UDim.new(0, 10)
	msLayout.Parent = missionsScroll
end

function UIController.RefreshMissionsUI()
	local scroll = UIController.Elements.MissionsScroll
	local pLbl = UIController.Elements.MissionPointsLbl
	local chContainer = UIController.Elements.ChestsContainer
	if not scroll or not pLbl or not chContainer then return end

	local dData = UIController.State.DailyMissions or {}
	local points = dData.Points or 0
	pLbl.Text = string.format("Points: %d/100", points)

	-- Update Chest Buttons
	local claimedChests = dData.ClaimedChests or {}
	for _, tier in ipairs({ 20, 40, 60, 80, 100 }) do
		local btn = chContainer:FindFirstChild("Chest_" .. tier) :: TextButton?
		if btn then
			if claimedChests[tier] then
				btn.Text = string.format("✓\n%d Pts", tier)
				btn.BackgroundColor3 = Color3.fromRGB(30, 40, 45)
				btn.TextColor3 = Color3.fromRGB(120, 200, 140)
			elseif points >= tier then
				btn.Text = string.format("CLAIM!\n%d Pts", tier)
				btn.BackgroundColor3 = Color3.fromRGB(220, 150, 40)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				btn.Text = string.format("🎁\n%d Pts", tier)
				btn.BackgroundColor3 = Color3.fromRGB(40, 55, 65)
				btn.TextColor3 = Color3.fromRGB(170, 180, 190)
			end
		end
	end

	-- Clear and rebuild mission items
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local MISSIONS = {
		{ Id = "battle_3", Title = "Clear 3 Campaign Battles", Req = 3, Pts = 30, Reward = "1,500 Gold, 50 💎" },
		{ Id = "summon_1", Title = "Summon 1 Hero at the Altar", Req = 1, Pts = 25, Reward = "1,000 Gold, 30 💎" },
		{ Id = "claim_afk_1", Title = "Claim AFK Chest 1 Time", Req = 1, Pts = 20, Reward = "1,000 Gold, 20 💎" },
		{ Id = "upgrade_hero_1", Title = "Level Up Any Hero 1 Time", Req = 1, Pts = 15, Reward = "800 Gold, 20 💎" },
		{ Id = "equip_gear_1", Title = "Equip 1 Item on a Hero", Req = 1, Pts = 10, Reward = "500 Gold, 10 💎" },
	}

	local progress = dData.Progress or {}
	local claimed = dData.ClaimedMissions or {}

	for _, m in ipairs(MISSIONS) do
		local cur = progress[m.Id] or 0
		local isDone = cur >= m.Req
		local isClaimed = claimed[m.Id] or false

		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 62)
		card.BackgroundColor3 = Color3.fromRGB(26, 32, 42)
		card.ZIndex = 17
		card.Parent = scroll

		local cCorn = Instance.new("UICorner")
		cCorn.CornerRadius = UDim.new(0, 8)
		cCorn.Parent = card

		local mTitle = Instance.new("TextLabel")
		mTitle.Size = UDim2.new(0.65, 0, 0.45, 0)
		mTitle.Position = UDim2.new(0.04, 0, 0.12, 0)
		mTitle.BackgroundTransparency = 1
		mTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
		mTitle.TextScaled = true
		mTitle.Font = Enum.Font.GothamBold
		mTitle.TextXAlignment = Enum.TextXAlignment.Left
		mTitle.Text = string.format("%s (%d/%d)", m.Title, math.min(cur, m.Req), m.Req)
		mTitle.ZIndex = 18
		mTitle.Parent = card

		local mSub = Instance.new("TextLabel")
		mSub.Size = UDim2.new(0.65, 0, 0.35, 0)
		mSub.Position = UDim2.new(0.04, 0, 0.55, 0)
		mSub.BackgroundTransparency = 1
		mSub.TextColor3 = Color3.fromRGB(150, 220, 180)
		mSub.TextScaled = true
		mSub.Font = Enum.Font.Gotham
		mSub.TextXAlignment = Enum.TextXAlignment.Left
		mSub.Text = string.format("+%d Points | Reward: %s", m.Pts, m.Reward)
		mSub.ZIndex = 18
		mSub.Parent = card

		local actBtn = Instance.new("TextButton")
		actBtn.Size = UDim2.new(0.24, 0, 0.65, 0)
		actBtn.Position = UDim2.new(0.72, 0, 0.18, 0)
		actBtn.TextScaled = true
		actBtn.Font = Enum.Font.GothamBold
		actBtn.ZIndex = 18
		actBtn.Parent = card

		local aCorn = Instance.new("UICorner")
		aCorn.CornerRadius = UDim.new(0, 8)
		aCorn.Parent = actBtn

		if isClaimed then
			actBtn.Text = "CLAIMED ✓"
			actBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 55)
			actBtn.TextColor3 = Color3.fromRGB(130, 180, 140)
			actBtn.Active = false
		elseif isDone then
			actBtn.Text = "CLAIM REWARD"
			actBtn.BackgroundColor3 = Color3.fromRGB(45, 175, 80)
			actBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			actBtn.Active = true
			actBtn.MouseButton1Click:Connect(function()
				if UIController.Remotes.ClaimDailyMission then
					UIController.Remotes.ClaimDailyMission:FireServer(m.Id)
				end
			end)
		else
			actBtn.Text = string.format("%d/%d", cur, m.Req)
			actBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
			actBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
			actBtn.Active = false
		end
	end
end

function UIController.BuildEventsModal()
	local modal = Instance.new("Frame")
	modal.Name = "EventsModal"
	modal.Size = UDim2.new(0.74, 0, 0.82, 0)
	modal.Position = UDim2.new(0.13, 0, 0.09, 0)
	modal.BackgroundColor3 = Color3.fromRGB(22, 18, 28)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 15
	modal.Parent = UIController.ScreenGui
	UIController.Elements.EventsModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = modal

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(220, 80, 140)
	stroke.Thickness = 2.5
	stroke.Parent = modal

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 44)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(255, 215, 235)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.Text = "🎉 GRAND LAUNCH EVENTS & PRIVILEGE OFFERS"
	header.ZIndex = 16
	header.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -38, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 17
	closeBtn.Parent = modal

	local cCorn = Instance.new("UICorner")
	cCorn.CornerRadius = UDim.new(0, 8)
	cCorn.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	-- Subtabs: [ 🌟 Bundles ] [ 👑 Monthly VIP ] [ 📈 Growth Fund ] [ 📅 7-Day ]
	local tabNav = Instance.new("Frame")
	tabNav.Size = UDim2.new(0.92, 0, 0, 36)
	tabNav.Position = UDim2.new(0.04, 0, 0, 48)
	tabNav.BackgroundTransparency = 1
	tabNav.ZIndex = 16
	tabNav.Parent = modal

	local tLayout = Instance.new("UIListLayout")
	tLayout.FillDirection = Enum.FillDirection.Horizontal
	tLayout.Padding = UDim.new(0, 8)
	tLayout.Parent = tabNav

	local function CreateSubTab(text: string, isActive: boolean): TextButton
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 130, 1, 0)
		btn.BackgroundColor3 = isActive and Color3.fromRGB(200, 60, 120) or Color3.fromRGB(36, 40, 55)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextScaled = true
		btn.Font = Enum.Font.GothamBold
		btn.Text = text
		btn.ZIndex = 17
		btn.Parent = tabNav

		local tc = Instance.new("UICorner")
		tc.CornerRadius = UDim.new(0, 8)
		tc.Parent = btn
		return btn
	end

	local tabBundlesBtn = CreateSubTab("🌟 Bundles", true)
	local tabVipBtn = CreateSubTab("👑 Monthly VIP", false)
	local tabFundBtn = CreateSubTab("📈 Growth Fund", false)
	local tabCarnivalBtn = CreateSubTab("📅 7-Day", false)

	-- 1. BUNDLES CONTAINER
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "BundlesScroll"
	scroll.Size = UDim2.new(0.92, 0, 0.82, 0)
	scroll.Position = UDim2.new(0.04, 0, 0, 92)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 16
	scroll.Parent = modal
	UIController.Elements.EventBundlesScroll = scroll

	local sLayout = Instance.new("UIListLayout")
	sLayout.Padding = UDim.new(0, 12)
	sLayout.Parent = scroll

	-- Banner 1: Novice Headstart Bundle (Monetization Offer)
	local starterCard = Instance.new("Frame")
	starterCard.Name = "StarterBundleCard"
	starterCard.Size = UDim2.new(1, 0, 0, 140)
	starterCard.BackgroundColor3 = Color3.fromRGB(36, 26, 44)
	starterCard.ZIndex = 17
	starterCard.Parent = scroll

	local scCorn = Instance.new("UICorner")
	scCorn.CornerRadius = UDim.new(0, 12)
	scCorn.Parent = starterCard

	local scStroke = Instance.new("UIStroke")
	scStroke.Color = Color3.fromRGB(255, 215, 60)
	scStroke.Thickness = 2
	scStroke.Parent = starterCard

	local bTitle = Instance.new("TextLabel")
	bTitle.Size = UDim2.new(0.65, 0, 0.22, 0)
	bTitle.Position = UDim2.new(0.04, 0, 0.08, 0)
	bTitle.BackgroundTransparency = 1
	bTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
	bTitle.TextScaled = true
	bTitle.Font = Enum.Font.GothamBlack
	bTitle.TextXAlignment = Enum.TextXAlignment.Left
	bTitle.Text = "🌟 NOVICE HEADSTART BUNDLE (LIMITED 1x)"
	bTitle.ZIndex = 18
	bTitle.Parent = starterCard
	UIController.Elements.StarterTitle = bTitle

	local bContent = Instance.new("TextLabel")
	bContent.Size = UDim2.new(0.65, 0, 0.6, 0)
	bContent.Position = UDim2.new(0.04, 0, 0.32, 0)
	bContent.BackgroundTransparency = 1
	bContent.TextColor3 = Color3.fromRGB(230, 230, 240)
	bContent.TextScaled = true
	bContent.Font = Enum.Font.Gotham
	bContent.TextXAlignment = Enum.TextXAlignment.Left
	bContent.Text = "Instant Commander Power Surge:\n✦ Guaranteed 5★ Hero: Brunhilda Shieldmaiden\n✦ 10x Elite Summon Scrolls (Gacor Altar!)\n✦ 50,000 Gold + 20,000 Elixir"
	bContent.ZIndex = 18
	bContent.Parent = starterCard

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.26, 0, 0.45, 0)
	buyBtn.Position = UDim2.new(0.70, 0, 0.28, 0)
	buyBtn.BackgroundColor3 = Color3.fromRGB(45, 175, 75)
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.TextScaled = true
	buyBtn.Font = Enum.Font.GothamBlack
	buyBtn.Text = "🛒 BUY FOR R$ 99"
	buyBtn.ZIndex = 18
	buyBtn.Parent = starterCard
	UIController.Elements.BuyStarterBtn = buyBtn

	local bbCorn = Instance.new("UICorner")
	bbCorn.CornerRadius = UDim.new(0, 10)
	bbCorn.Parent = buyBtn

	buyBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.PurchaseEventOffer then
			UIController.Remotes.PurchaseEventOffer:FireServer("starter_pack")
		end
	end)

	-- Banner 2: Elite Commander Supply (Diamond Purchase)
	local scrollCard = Instance.new("Frame")
	scrollCard.Name = "ScrollBundleCard"
	scrollCard.Size = UDim2.new(1, 0, 0, 140)
	scrollCard.BackgroundColor3 = Color3.fromRGB(32, 24, 45)
	scrollCard.ZIndex = 17
	scrollCard.Parent = scroll

	local spCorn = Instance.new("UICorner")
	spCorn.CornerRadius = UDim.new(0, 12)
	spCorn.Parent = scrollCard

	local spStroke = Instance.new("UIStroke")
	spStroke.Color = Color3.fromRGB(200, 80, 255)
	spStroke.Thickness = 2
	spStroke.Parent = scrollCard

	local spTitle = Instance.new("TextLabel")
	spTitle.Size = UDim2.new(0.65, 0, 0.22, 0)
	spTitle.Position = UDim2.new(0.04, 0, 0.08, 0)
	spTitle.BackgroundTransparency = 1
	spTitle.TextColor3 = Color3.fromRGB(220, 140, 255)
	spTitle.TextScaled = true
	spTitle.Font = Enum.Font.GothamBlack
	spTitle.TextXAlignment = Enum.TextXAlignment.Left
	spTitle.Text = "🔮 ELITE COMMANDER SUPPLY"
	spTitle.ZIndex = 18
	spTitle.Parent = scrollCard
	UIController.Elements.ScrollPackTitle = spTitle

	local spContent = Instance.new("TextLabel")
	spContent.Size = UDim2.new(0.65, 0, 0.6, 0)
	spContent.Position = UDim2.new(0.04, 0, 0.32, 0)
	spContent.BackgroundTransparency = 1
	spContent.TextColor3 = Color3.fromRGB(230, 220, 245)
	spContent.TextScaled = true
	spContent.Font = Enum.Font.Gotham
	spContent.TextXAlignment = Enum.TextXAlignment.Left
	spContent.Text = "Special Discounted Summon Crate:\n✦ 10x Elite Summon Scrolls (Worth 2,200 💎)\n✦ +30,000 Gold\nSave 400 💎 Diamonds!"
	spContent.ZIndex = 18
	spContent.Parent = scrollCard

	local spBtn = Instance.new("TextButton")
	spBtn.Size = UDim2.new(0.26, 0, 0.45, 0)
	spBtn.Position = UDim2.new(0.70, 0, 0.28, 0)
	spBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 210)
	spBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	spBtn.TextScaled = true
	spBtn.Font = Enum.Font.GothamBlack
	spBtn.Text = "💎 BUY (1,800 💎)"
	spBtn.ZIndex = 18
	spBtn.Parent = scrollCard
	UIController.Elements.BuyScrollPackBtn = spBtn

	local spbCorn = Instance.new("UICorner")
	spbCorn.CornerRadius = UDim.new(0, 10)
	spbCorn.Parent = spBtn

	spBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.PurchaseEventOffer then
			UIController.Remotes.PurchaseEventOffer:FireServer("diamond_scroll_pack")
		end
	end)

	-- Banner 3: Blacksmith Arsenal Pack (Diamond Purchase)
	local arsenalCard = Instance.new("Frame")
	arsenalCard.Name = "ArsenalBundleCard"
	arsenalCard.Size = UDim2.new(1, 0, 0, 140)
	arsenalCard.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
	arsenalCard.ZIndex = 17
	arsenalCard.Parent = scroll

	local baCorn = Instance.new("UICorner")
	baCorn.CornerRadius = UDim.new(0, 12)
	baCorn.Parent = arsenalCard

	local baStroke = Instance.new("UIStroke")
	baStroke.Color = Color3.fromRGB(60, 140, 240)
	baStroke.Thickness = 2
	baStroke.Parent = arsenalCard

	local baTitle = Instance.new("TextLabel")
	baTitle.Size = UDim2.new(0.65, 0, 0.22, 0)
	baTitle.Position = UDim2.new(0.04, 0, 0.08, 0)
	baTitle.BackgroundTransparency = 1
	baTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
	baTitle.TextScaled = true
	baTitle.Font = Enum.Font.GothamBlack
	baTitle.TextXAlignment = Enum.TextXAlignment.Left
	baTitle.Text = "🗡️ BLACKSMITH ARSENAL PACK"
	baTitle.ZIndex = 18
	baTitle.Parent = arsenalCard
	UIController.Elements.ArsenalTitle = baTitle

	local baContent = Instance.new("TextLabel")
	baContent.Size = UDim2.new(0.65, 0, 0.6, 0)
	baContent.Position = UDim2.new(0.04, 0, 0.32, 0)
	baContent.BackgroundTransparency = 1
	baContent.TextColor3 = Color3.fromRGB(215, 230, 245)
	baContent.TextScaled = true
	baContent.Font = Enum.Font.Gotham
	baContent.TextXAlignment = Enum.TextXAlignment.Left
	baContent.Text = "Warrior Combat Gear Starter Set:\n✦ 1x Guaranteed Epic Dragon Fang Spear\n✦ 1x Heavy Knight Plate\n✦ +20,000 Hero Elixir"
	baContent.ZIndex = 18
	baContent.Parent = arsenalCard

	local baBtn = Instance.new("TextButton")
	baBtn.Size = UDim2.new(0.26, 0, 0.45, 0)
	baBtn.Position = UDim2.new(0.70, 0, 0.28, 0)
	baBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 210)
	baBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	baBtn.TextScaled = true
	baBtn.Font = Enum.Font.GothamBlack
	baBtn.Text = "💎 BUY (800 💎)"
	baBtn.ZIndex = 18
	baBtn.Parent = arsenalCard
	UIController.Elements.BuyArsenalBtn = baBtn

	local babCorn = Instance.new("UICorner")
	babCorn.CornerRadius = UDim.new(0, 10)
	babCorn.Parent = baBtn

	baBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.PurchaseEventOffer then
			UIController.Remotes.PurchaseEventOffer:FireServer("blacksmith_pack")
		end
	end)

	-- Banner 4: AFK Time-Warp Hourglass
	local timeWarpCard = Instance.new("Frame")
	timeWarpCard.Name = "TimeWarpCard"
	timeWarpCard.Size = UDim2.new(1, 0, 0, 135)
	timeWarpCard.BackgroundColor3 = Color3.fromRGB(30, 36, 40)
	timeWarpCard.ZIndex = 17
	timeWarpCard.Parent = scroll

	local twcCorn = Instance.new("UICorner")
	twcCorn.CornerRadius = UDim.new(0, 12)
	twcCorn.Parent = timeWarpCard

	local twcStroke = Instance.new("UIStroke")
	twcStroke.Color = Color3.fromRGB(80, 200, 140)
	twcStroke.Thickness = 2
	twcStroke.Parent = timeWarpCard

	local twTitle = Instance.new("TextLabel")
	twTitle.Size = UDim2.new(0.65, 0, 0.22, 0)
	twTitle.Position = UDim2.new(0.04, 0, 0.08, 0)
	twTitle.BackgroundTransparency = 1
	twTitle.TextColor3 = Color3.fromRGB(120, 240, 180)
	twTitle.TextScaled = true
	twTitle.Font = Enum.Font.GothamBlack
	twTitle.TextXAlignment = Enum.TextXAlignment.Left
	twTitle.Text = "⏳ AFK TIME-WARP HOURGLASS (240 MINS)"
	twTitle.ZIndex = 18
	twTitle.Parent = timeWarpCard

	local twContent = Instance.new("TextLabel")
	twContent.Size = UDim2.new(0.65, 0, 0.6, 0)
	twContent.Position = UDim2.new(0.04, 0, 0.32, 0)
	twContent.BackgroundTransparency = 1
	twContent.TextColor3 = Color3.fromRGB(215, 235, 225)
	twContent.TextScaled = true
	twContent.Font = Enum.Font.Gotham
	twContent.TextXAlignment = Enum.TextXAlignment.Left
	twContent.Text = "Instantly Fast-Forward Time:\n✦ Claim 4 Hours (240 mins) of AFK Gold & Elixir loot instantly!\n✦ Multiplied by your current cleared stage rates"
	twContent.ZIndex = 18
	twContent.Parent = timeWarpCard

	local twBtn = Instance.new("TextButton")
	twBtn.Size = UDim2.new(0.26, 0, 0.45, 0)
	twBtn.Position = UDim2.new(0.70, 0, 0.28, 0)
	twBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 110)
	twBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	twBtn.TextScaled = true
	twBtn.Font = Enum.Font.GothamBlack
	twBtn.Text = "💎 BUY (250 💎)"
	twBtn.ZIndex = 18
	twBtn.Parent = timeWarpCard

	local twbCorn = Instance.new("UICorner")
	twbCorn.CornerRadius = UDim.new(0, 10)
	twbCorn.Parent = twBtn

	twBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.PurchaseEventOffer then
			UIController.Remotes.PurchaseEventOffer:FireServer("time_warp")
		end
	end)

	-- Banner 5: Hero Awakening Shard Chest
	local shardCard = Instance.new("Frame")
	shardCard.Name = "ShardCard"
	shardCard.Size = UDim2.new(1, 0, 0, 135)
	shardCard.BackgroundColor3 = Color3.fromRGB(38, 30, 26)
	shardCard.ZIndex = 17
	shardCard.Parent = scroll

	local shcCorn = Instance.new("UICorner")
	shcCorn.CornerRadius = UDim.new(0, 12)
	shcCorn.Parent = shardCard

	local shcStroke = Instance.new("UIStroke")
	shcStroke.Color = Color3.fromRGB(240, 140, 40)
	shcStroke.Thickness = 2
	shcStroke.Parent = shardCard

	local shTitle = Instance.new("TextLabel")
	shTitle.Size = UDim2.new(0.65, 0, 0.22, 0)
	shTitle.Position = UDim2.new(0.04, 0, 0.08, 0)
	shTitle.BackgroundTransparency = 1
	shTitle.TextColor3 = Color3.fromRGB(255, 180, 80)
	shTitle.TextScaled = true
	shTitle.Font = Enum.Font.GothamBlack
	shTitle.TextXAlignment = Enum.TextXAlignment.Left
	shTitle.Text = "⭐ HERO AWAKENING & ASCENSION CHEST"
	shTitle.ZIndex = 18
	shTitle.Parent = shardCard

	local shContent = Instance.new("TextLabel")
	shContent.Size = UDim2.new(0.65, 0, 0.6, 0)
	shContent.Position = UDim2.new(0.04, 0, 0.32, 0)
	shContent.BackgroundTransparency = 1
	shContent.TextColor3 = Color3.fromRGB(245, 225, 215)
	shContent.TextScaled = true
	shContent.Font = Enum.Font.Gotham
	shContent.TextXAlignment = Enum.TextXAlignment.Left
	shContent.Text = "Rapid Ascension Material Pack:\n✦ 2x Guaranteed 3★ Duplicates (Bastian & Crimson)\n✦ +50,000 Hero Elixir for immediate Star-Up!"
	shContent.ZIndex = 18
	shContent.Parent = shardCard

	local shBtn = Instance.new("TextButton")
	shBtn.Size = UDim2.new(0.26, 0, 0.45, 0)
	shBtn.Position = UDim2.new(0.70, 0, 0.28, 0)
	shBtn.BackgroundColor3 = Color3.fromRGB(210, 110, 30)
	shBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	shBtn.TextScaled = true
	shBtn.Font = Enum.Font.GothamBlack
	shBtn.Text = "💎 BUY (1,200 💎)"
	shBtn.ZIndex = 18
	shBtn.Parent = shardCard

	local shbCorn = Instance.new("UICorner")
	shbCorn.CornerRadius = UDim.new(0, 10)
	shbCorn.Parent = shBtn

	shBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.PurchaseEventOffer then
			UIController.Remotes.PurchaseEventOffer:FireServer("shard_chest")
		end
	end)

	-- 2. MONTHLY VIP CONTAINER
	local vipFrame = Instance.new("Frame")
	vipFrame.Name = "VipFrame"
	vipFrame.Size = UDim2.new(0.92, 0, 0.82, 0)
	vipFrame.Position = UDim2.new(0.04, 0, 0, 92)
	vipFrame.BackgroundColor3 = Color3.fromRGB(28, 22, 38)
	vipFrame.Visible = false
	vipFrame.ZIndex = 16
	vipFrame.Parent = modal
	UIController.Elements.EventVipFrame = vipFrame

	local vfc = Instance.new("UICorner")
	vfc.CornerRadius = UDim.new(0, 14)
	vfc.Parent = vipFrame

	local vfs = Instance.new("UIStroke")
	vfs.Color = Color3.fromRGB(255, 215, 60)
	vfs.Thickness = 2.5
	vfs.Parent = vipFrame

	local vipTitle = Instance.new("TextLabel")
	vipTitle.Size = UDim2.new(0.9, 0, 0.12, 0)
	vipTitle.Position = UDim2.new(0.05, 0, 0.05, 0)
	vipTitle.BackgroundTransparency = 1
	vipTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
	vipTitle.TextScaled = true
	vipTitle.Font = Enum.Font.GothamBlack
	vipTitle.Text = "👑 30-DAY MONTHLY PRIVILEGE CARD"
	vipTitle.ZIndex = 17
	vipTitle.Parent = vipFrame

	local vipStatusLbl = Instance.new("TextLabel")
	vipStatusLbl.Size = UDim2.new(0.9, 0, 0.08, 0)
	vipStatusLbl.Position = UDim2.new(0.05, 0, 0.18, 0)
	vipStatusLbl.BackgroundTransparency = 1
	vipStatusLbl.TextColor3 = Color3.fromRGB(150, 240, 180)
	vipStatusLbl.TextScaled = true
	vipStatusLbl.Font = Enum.Font.GothamBold
	vipStatusLbl.Text = "Status: Inactive"
	vipStatusLbl.ZIndex = 17
	vipStatusLbl.Parent = vipFrame
	UIController.Elements.VipStatusLbl = vipStatusLbl

	local vipDesc = Instance.new("TextLabel")
	vipDesc.Size = UDim2.new(0.9, 0, 0.42, 0)
	vipDesc.Position = UDim2.new(0.05, 0, 0.28, 0)
	vipDesc.BackgroundTransparency = 1
	vipDesc.TextColor3 = Color3.fromRGB(230, 235, 245)
	vipDesc.TextScaled = true
	vipDesc.Font = Enum.Font.Gotham
	vipDesc.Text = "Exclusive Commander Benefits:\n✦ 100 💎 Diamonds + 1x Elite Summon Scroll sent to Mailbox daily!\n✦ Total value over 30 days: 3,000 💎 + 30x Elite Summon Scrolls!\n✦ Permanent +15% Boost to all AFK Gold & Elixir loot!"
	vipDesc.ZIndex = 17
	vipDesc.Parent = vipFrame

	local buyVipBtn = Instance.new("TextButton")
	buyVipBtn.Size = UDim2.new(0.42, 0, 0, 48)
	buyVipBtn.Position = UDim2.new(0.05, 0, 0.78, 0)
	buyVipBtn.BackgroundColor3 = Color3.fromRGB(220, 150, 40)
	buyVipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyVipBtn.TextScaled = true
	buyVipBtn.Font = Enum.Font.GothamBlack
	buyVipBtn.Text = "👑 ACTIVATE (R$ 199)"
	buyVipBtn.ZIndex = 18
	buyVipBtn.Parent = vipFrame
	UIController.Elements.BuyVipBtn = buyVipBtn

	local bvc = Instance.new("UICorner")
	bvc.CornerRadius = UDim.new(0, 10)
	bvc.Parent = buyVipBtn

	buyVipBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.PurchaseMonthlyCard then
			UIController.Remotes.PurchaseMonthlyCard:FireServer()
		end
	end)

	local claimVipDailyBtn = Instance.new("TextButton")
	claimVipDailyBtn.Size = UDim2.new(0.42, 0, 0, 48)
	claimVipDailyBtn.Position = UDim2.new(0.53, 0, 0.78, 0)
	claimVipDailyBtn.BackgroundColor3 = Color3.fromRGB(45, 175, 75)
	claimVipDailyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	claimVipDailyBtn.TextScaled = true
	claimVipDailyBtn.Font = Enum.Font.GothamBold
	claimVipDailyBtn.Text = "🎁 CLAIM DAILY VIP"
	claimVipDailyBtn.ZIndex = 18
	claimVipDailyBtn.Parent = vipFrame
	UIController.Elements.ClaimVipDailyBtn = claimVipDailyBtn

	local cvc = Instance.new("UICorner")
	cvc.CornerRadius = UDim.new(0, 10)
	cvc.Parent = claimVipDailyBtn

	claimVipDailyBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.ClaimMonthlyCardDaily then
			UIController.Remotes.ClaimMonthlyCardDaily:FireServer()
		end
	end)

	-- 3. GROWTH FUND CONTAINER
	local fundFrame = Instance.new("ScrollingFrame")
	fundFrame.Name = "GrowthFundFrame"
	fundFrame.Size = UDim2.new(0.92, 0, 0.82, 0)
	fundFrame.Position = UDim2.new(0.04, 0, 0, 92)
	fundFrame.BackgroundTransparency = 1
	fundFrame.BorderSizePixel = 0
	fundFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	fundFrame.Visible = false
	fundFrame.ZIndex = 16
	fundFrame.Parent = modal
	UIController.Elements.EventFundFrame = fundFrame

	local fLayout = Instance.new("UIListLayout")
	fLayout.Padding = UDim.new(0, 12)
	fLayout.Parent = fundFrame

	-- Growth Fund Header Card
	local fundHeaderCard = Instance.new("Frame")
	fundHeaderCard.Size = UDim2.new(1, 0, 0, 110)
	fundHeaderCard.BackgroundColor3 = Color3.fromRGB(28, 35, 52)
	fundHeaderCard.ZIndex = 17
	fundHeaderCard.Parent = fundFrame

	local fhc = Instance.new("UICorner")
	fhc.CornerRadius = UDim.new(0, 12)
	fhc.Parent = fundHeaderCard

	local fhs = Instance.new("UIStroke")
	fhs.Color = Color3.fromRGB(100, 200, 255)
	fhs.Thickness = 2
	fhs.Parent = fundHeaderCard

	local fht = Instance.new("TextLabel")
	fht.Size = UDim2.new(0.65, 0, 0.35, 0)
	fht.Position = UDim2.new(0.04, 0, 0.12, 0)
	fht.BackgroundTransparency = 1
	fht.TextColor3 = Color3.fromRGB(255, 220, 90)
	fht.TextScaled = true
	fht.Font = Enum.Font.GothamBlack
	fht.TextXAlignment = Enum.TextXAlignment.Left
	fht.Text = "📈 CHAPTER GROWTH FUND (UP TO 12,500 💎)"
	fht.ZIndex = 18
	fht.Parent = fundHeaderCard
	UIController.Elements.FundHeaderTitle = fht

	local fhd = Instance.new("TextLabel")
	fhd.Size = UDim2.new(0.65, 0, 0.45, 0)
	fhd.Position = UDim2.new(0.04, 0, 0.48, 0)
	fhd.BackgroundTransparency = 1
	fhd.TextColor3 = Color3.fromRGB(210, 230, 255)
	fhd.TextScaled = true
	fhd.Font = Enum.Font.Gotham
	fhd.TextXAlignment = Enum.TextXAlignment.Left
	fhd.Text = "Conquer chapter climaxes to claim massive Diamond bundles!"
	fhd.ZIndex = 18
	fhd.Parent = fundHeaderCard

	local unlockFundBtn = Instance.new("TextButton")
	unlockFundBtn.Size = UDim2.new(0.26, 0, 0.55, 0)
	unlockFundBtn.Position = UDim2.new(0.70, 0, 0.22, 0)
	unlockFundBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 220)
	unlockFundBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	unlockFundBtn.TextScaled = true
	unlockFundBtn.Font = Enum.Font.GothamBlack
	unlockFundBtn.Text = "UNLOCK (R$ 249)"
	unlockFundBtn.ZIndex = 18
	unlockFundBtn.Parent = fundHeaderCard
	UIController.Elements.UnlockFundBtn = unlockFundBtn

	local ufc = Instance.new("UICorner")
	ufc.CornerRadius = UDim.new(0, 10)
	ufc.Parent = unlockFundBtn

	unlockFundBtn.MouseButton1Click:Connect(function()
		if UIController.Remotes.PurchaseGrowthFund then
			UIController.Remotes.PurchaseGrowthFund:FireServer()
		end
	end)

	-- Chapter Fund Milestones 1 to 5
	local FUND_TIERS = {
		{ Chap = 1, Diamonds = 1500, Title = "Chapter 1: The Outskirts (Stage 1-10)" },
		{ Chap = 2, Diamonds = 2000, Title = "Chapter 2: Whispering Canyon (Stage 2-10)" },
		{ Chap = 3, Diamonds = 2500, Title = "Chapter 3: Molten Stronghold (Stage 3-10)" },
		{ Chap = 4, Diamonds = 3000, Title = "Chapter 4: Glacial Pass (Stage 4-10)" },
		{ Chap = 5, Diamonds = 3500, Title = "Chapter 5: Abyssal Citadel (Stage 5-10)" },
	}

	for _, tier in ipairs(FUND_TIERS) do
		local mCard = Instance.new("Frame")
		mCard.Name = "FundTier_" .. tier.Chap
		mCard.Size = UDim2.new(1, 0, 0, 75)
		mCard.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
		mCard.ZIndex = 17
		mCard.Parent = fundFrame

		local mcCorn = Instance.new("UICorner")
		mcCorn.CornerRadius = UDim.new(0, 10)
		mcCorn.Parent = mCard

		local mt = Instance.new("TextLabel")
		mt.Size = UDim2.new(0.65, 0, 0.45, 0)
		mt.Position = UDim2.new(0.04, 0, 0.12, 0)
		mt.BackgroundTransparency = 1
		mt.TextColor3 = Color3.fromRGB(255, 255, 255)
		mt.TextScaled = true
		mt.Font = Enum.Font.GothamBold
		mt.TextXAlignment = Enum.TextXAlignment.Left
		mt.Text = tier.Title
		mt.ZIndex = 18
		mt.Parent = mCard

		local md = Instance.new("TextLabel")
		md.Size = UDim2.new(0.65, 0, 0.35, 0)
		md.Position = UDim2.new(0.04, 0, 0.55, 0)
		md.BackgroundTransparency = 1
		md.TextColor3 = Color3.fromRGB(100, 220, 255)
		md.TextScaled = true
		md.Font = Enum.Font.GothamBold
		md.TextXAlignment = Enum.TextXAlignment.Left
		md.Text = string.format("Reward: +%d 💎 Diamonds", tier.Diamonds)
		md.ZIndex = 18
		md.Parent = mCard

		local clBtn = Instance.new("TextButton")
		clBtn.Name = "ClaimFundBtn"
		clBtn.Size = UDim2.new(0.24, 0, 0.6, 0)
		clBtn.Position = UDim2.new(0.72, 0, 0.2, 0)
		clBtn.BackgroundColor3 = Color3.fromRGB(45, 175, 75)
		clBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		clBtn.TextScaled = true
		clBtn.Font = Enum.Font.GothamBold
		clBtn.Text = "CLAIM 💎"
		clBtn.ZIndex = 18
		clBtn.Parent = mCard

		local clc = Instance.new("UICorner")
		clc.CornerRadius = UDim.new(0, 8)
		clc.Parent = clBtn

		clBtn.MouseButton1Click:Connect(function()
			if UIController.Remotes.ClaimGrowthFund then
				UIController.Remotes.ClaimGrowthFund:FireServer(tier.Chap)
			end
		end)
	end

	-- 4. CARNIVAL CONTAINER
	local carnivalFrame = Instance.new("ScrollingFrame")
	carnivalFrame.Name = "CarnivalFrame"
	carnivalFrame.Size = UDim2.new(0.92, 0, 0.82, 0)
	carnivalFrame.Position = UDim2.new(0.04, 0, 0, 92)
	carnivalFrame.BackgroundTransparency = 1
	carnivalFrame.BorderSizePixel = 0
	carnivalFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	carnivalFrame.Visible = false
	carnivalFrame.ZIndex = 16
	carnivalFrame.Parent = modal
	UIController.Elements.EventCarnivalFrame = carnivalFrame

	local cnLayout = Instance.new("UIListLayout")
	cnLayout.Padding = UDim.new(0, 10)
	cnLayout.Parent = carnivalFrame

	for day = 1, 7 do
		local cCard = Instance.new("Frame")
		cCard.Size = UDim2.new(1, 0, 0, 68)
		cCard.BackgroundColor3 = (day == 7) and Color3.fromRGB(44, 28, 48) or Color3.fromRGB(26, 30, 42)
		cCard.ZIndex = 17
		cCard.Parent = carnivalFrame

		local ccCorn = Instance.new("UICorner")
		ccCorn.CornerRadius = UDim.new(0, 10)
		ccCorn.Parent = cCard

		local ccStroke = Instance.new("UIStroke")
		ccStroke.Color = (day == 7) and Color3.fromRGB(255, 215, 60) or Color3.fromRGB(60, 70, 90)
		ccStroke.Thickness = 1.5
		ccStroke.Parent = cCard

		local dTitle = Instance.new("TextLabel")
		dTitle.Size = UDim2.new(0.4, 0, 0.45, 0)
		dTitle.Position = UDim2.new(0.04, 0, 0.12, 0)
		dTitle.BackgroundTransparency = 1
		dTitle.TextColor3 = (day == 7) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 255, 255)
		dTitle.TextScaled = true
		dTitle.Font = Enum.Font.GothamBlack
		dTitle.TextXAlignment = Enum.TextXAlignment.Left
		dTitle.Text = string.format("DAY %d LOGIN REWARD", day)
		dTitle.ZIndex = 18
		dTitle.Parent = cCard

		local dRew = Instance.new("TextLabel")
		dRew.Size = UDim2.new(0.5, 0, 0.35, 0)
		dRew.Position = UDim2.new(0.04, 0, 0.55, 0)
		dRew.BackgroundTransparency = 1
		dRew.TextColor3 = Color3.fromRGB(120, 240, 180)
		dRew.TextScaled = true
		dRew.Font = Enum.Font.GothamBold
		dRew.TextXAlignment = Enum.TextXAlignment.Left
		dRew.Text = (day == 7) and "🌟 5★ Legendary Hero Selector!" or string.format("+%d 💎, +%d Scrolls", day * 50, math.clamp(day, 1, 3))
		dRew.ZIndex = 18
		dRew.Parent = cCard
	end

	-- Subtab Click Handler
	local function SwitchEventTab(tab: "Bundles" | "Vip" | "Fund" | "Carnival")
		tabBundlesBtn.BackgroundColor3 = (tab == "Bundles") and Color3.fromRGB(200, 60, 120) or Color3.fromRGB(36, 40, 55)
		tabVipBtn.BackgroundColor3 = (tab == "Vip") and Color3.fromRGB(200, 60, 120) or Color3.fromRGB(36, 40, 55)
		tabFundBtn.BackgroundColor3 = (tab == "Fund") and Color3.fromRGB(200, 60, 120) or Color3.fromRGB(36, 40, 55)
		tabCarnivalBtn.BackgroundColor3 = (tab == "Carnival") and Color3.fromRGB(200, 60, 120) or Color3.fromRGB(36, 40, 55)

		scroll.Visible = (tab == "Bundles")
		vipFrame.Visible = (tab == "Vip")
		fundFrame.Visible = (tab == "Fund")
		carnivalFrame.Visible = (tab == "Carnival")

		UIController.RefreshEventsUI()
	end

	tabBundlesBtn.MouseButton1Click:Connect(function() SwitchEventTab("Bundles") end)
	tabVipBtn.MouseButton1Click:Connect(function() SwitchEventTab("Vip") end)
	tabFundBtn.MouseButton1Click:Connect(function() SwitchEventTab("Fund") end)
	tabCarnivalBtn.MouseButton1Click:Connect(function() SwitchEventTab("Carnival") end)

	UIController.RefreshEventsUI()
end

function UIController.RefreshEventsUI()
	local sTitle = UIController.Elements.StarterTitle
	local sBtn = UIController.Elements.BuyStarterBtn
	local spTitle = UIController.Elements.ScrollPackTitle
	local spBtn = UIController.Elements.BuyScrollPackBtn
	local baTitle = UIController.Elements.ArsenalTitle
	local baBtn = UIController.Elements.BuyArsenalBtn

	local claimed = UIController.State.EventOffersClaimed or {}
	local isStarterClaimed = UIController.State.StarterPackPurchased or claimed["starter_pack"]

	-- Starter Pack
	if sTitle and sBtn then
		if isStarterClaimed then
			sTitle.Text = "🌟 NOVICE HEADSTART BUNDLE [TERBELI / CLAIMED ✓]"
			sTitle.TextColor3 = Color3.fromRGB(160, 230, 180)
			sBtn.Text = "TERBELI ✓"
			sBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 60)
			sBtn.TextColor3 = Color3.fromRGB(130, 180, 140)
			sBtn.Active = false
		else
			sTitle.Text = "🌟 NOVICE HEADSTART BUNDLE (LIMITED 1x)"
			sTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
			sBtn.Text = "🛒 BUY FOR R$ 99"
			sBtn.BackgroundColor3 = Color3.fromRGB(45, 175, 75)
			sBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			sBtn.Active = true
		end
	end

	-- Elite Commander Supply
	if spTitle and spBtn then
		if claimed["diamond_scroll_pack"] then
			spTitle.Text = "🔮 ELITE COMMANDER SUPPLY [TERBELI / CLAIMED ✓]"
			spTitle.TextColor3 = Color3.fromRGB(160, 230, 180)
			spBtn.Text = "TERBELI ✓"
			spBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 60)
			spBtn.TextColor3 = Color3.fromRGB(130, 180, 140)
			spBtn.Active = false
		else
			spTitle.Text = "🔮 ELITE COMMANDER SUPPLY (10x SCROLLS)"
			spTitle.TextColor3 = Color3.fromRGB(220, 140, 255)
			spBtn.Text = "💎 BUY (1,800 💎)"
			spBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 210)
			spBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			spBtn.Active = true
		end
	end

	-- Blacksmith Arsenal Pack
	if baTitle and baBtn then
		if claimed["blacksmith_pack"] then
			baTitle.Text = "🗡️ BLACKSMITH ARSENAL [TERBELI / CLAIMED ✓]"
			baTitle.TextColor3 = Color3.fromRGB(160, 230, 180)
			baBtn.Text = "TERBELI ✓"
			baBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 60)
			baBtn.TextColor3 = Color3.fromRGB(130, 180, 140)
			baBtn.Active = false
		else
			baTitle.Text = "🗡️ BLACKSMITH ARSENAL (DRAGON SPEAR + PLATE)"
			baTitle.TextColor3 = Color3.fromRGB(100, 200, 255)
			baBtn.Text = "💎 BUY (800 💎)"
			baBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 210)
			baBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			baBtn.Active = true
		end
	end

	-- Monthly Card VIP Status
	local vipStatusLbl = UIController.Elements.VipStatusLbl
	local buyVipBtn = UIController.Elements.BuyVipBtn
	local claimVipBtn = UIController.Elements.ClaimVipDailyBtn
	local vipExpiry = UIController.State.MonthlyCardExpiry or 0
	local isVipActive = vipExpiry > os.time()

	if vipStatusLbl and buyVipBtn and claimVipBtn then
		if isVipActive then
			local daysLeft = math.ceil((vipExpiry - os.time()) / 86400)
			vipStatusLbl.Text = string.format("Status: 👑 ACTIVE (%d Days Remaining) | +15%% AFK Boost", daysLeft)
			vipStatusLbl.TextColor3 = Color3.fromRGB(255, 220, 90)
			buyVipBtn.Text = "👑 RENEW (R$ 199)"
			buyVipBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 75)

			local lastClaim = UIController.State.LastMonthlyCardClaim or 0
			local isDailyClaimable = (os.time() - lastClaim) >= 86400
			claimVipBtn.Active = isDailyClaimable
			claimVipBtn.Text = isDailyClaimable and "🎁 CLAIM 100 💎 + 1 SCROLL" or "CLAIMED TODAY ✓"
			claimVipBtn.BackgroundColor3 = isDailyClaimable and Color3.fromRGB(45, 175, 75) or Color3.fromRGB(45, 52, 60)
		else
			vipStatusLbl.Text = "Status: Inactive (Purchase to activate 30-day VIP)"
			vipStatusLbl.TextColor3 = Color3.fromRGB(160, 170, 180)
			buyVipBtn.Text = "👑 ACTIVATE (R$ 199)"
			buyVipBtn.BackgroundColor3 = Color3.fromRGB(220, 150, 40)
			claimVipBtn.Active = false
			claimVipBtn.Text = "VIP INACTIVE"
			claimVipBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
		end
	end

	-- Growth Fund Status
	local fundTitle = UIController.Elements.FundHeaderTitle
	local unlockFundBtn = UIController.Elements.UnlockFundBtn
	local fundFrame = UIController.Elements.EventFundFrame
	local isFundUnlocked = UIController.State.GrowthFundPurchased
	local fundClaimed = UIController.State.GrowthFundClaimed or {}
	local highest = UIController.State.HighestClearedStage

	if fundTitle and unlockFundBtn then
		if isFundUnlocked then
			fundTitle.Text = "📈 CHAPTER GROWTH FUND [UNLOCKED / ACTIVE ✓]"
			fundTitle.TextColor3 = Color3.fromRGB(160, 240, 180)
			unlockFundBtn.Text = "UNLOCKED ✓"
			unlockFundBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 60)
			unlockFundBtn.TextColor3 = Color3.fromRGB(130, 180, 140)
			unlockFundBtn.Active = false
		else
			fundTitle.Text = "📈 CHAPTER GROWTH FUND (UP TO 12,500 💎)"
			fundTitle.TextColor3 = Color3.fromRGB(255, 220, 90)
			unlockFundBtn.Text = "UNLOCK (R$ 249)"
			unlockFundBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 220)
			unlockFundBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			unlockFundBtn.Active = true
		end
	end

	if fundFrame then
		for chap = 1, 5 do
			local card = fundFrame:FindFirstChild("FundTier_" .. chap) :: Frame?
			if card then
				local clBtn = card:FindFirstChild("ClaimFundBtn") :: TextButton?
				if clBtn then
					local reqStage = string.format("%d-10", chap)
					local isStageCleared = StageData.IsMilestoneReached(highest, reqStage)
					local isTierClaimed = fundClaimed[chap]

					if isTierClaimed then
						clBtn.Text = "CLAIMED ✓"
						clBtn.BackgroundColor3 = Color3.fromRGB(40, 48, 55)
						clBtn.TextColor3 = Color3.fromRGB(130, 180, 140)
						clBtn.Active = false
					elseif not isFundUnlocked then
						clBtn.Text = "🔒 FUND LOCKED"
						clBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
						clBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
						clBtn.Active = false
					elseif isStageCleared then
						clBtn.Text = "CLAIM 💎"
						clBtn.BackgroundColor3 = Color3.fromRGB(45, 175, 75)
						clBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
						clBtn.Active = true
					else
						clBtn.Text = string.format("Clear %d-10 🔒", chap)
						clBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
						clBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
						clBtn.Active = false
					end
				end
			end
		end
	end
end

-- =========================================================================
-- BACKPACK & FORMATION MODALS
-- =========================================================================
function UIController.BuildBackpackModal()
	local modal = Instance.new("Frame")
	modal.Name = "BackpackModal"
	modal.Size = UDim2.new(0.8, 0, 0.82, 0)
	modal.Position = UDim2.new(0.1, 0, 0.09, 0)
	modal.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
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
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(220, 235, 255)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.Text = "🎒 HERO BARRACKS & EQUIPMENT"
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

	local heroScroll = Instance.new("ScrollingFrame")
	heroScroll.Name = "HeroScroll"
	heroScroll.Size = UDim2.new(0.55, 0, 0.82, 0)
	heroScroll.Position = UDim2.new(0.04, 0, 0, 60)
	heroScroll.BackgroundTransparency = 1
	heroScroll.BorderSizePixel = 0
	heroScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	heroScroll.ZIndex = 11
	heroScroll.Parent = modal
	UIController.Elements.HeroScroll = heroScroll

	local hLayout = Instance.new("UIGridLayout")
	hLayout.CellSize = UDim2.new(0, 100, 0, 120)
	hLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	hLayout.Parent = heroScroll

	local detail = Instance.new("Frame")
	detail.Name = "HeroDetail"
	detail.Size = UDim2.new(0.35, 0, 0.82, 0)
	detail.Position = UDim2.new(0.61, 0, 0, 60)
	detail.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
	detail.BorderSizePixel = 0
	detail.ZIndex = 11
	detail.Parent = modal
	UIController.Elements.HeroDetail = detail

	local dCorner = Instance.new("UICorner")
	dCorner.CornerRadius = UDim.new(0, 12)
	dCorner.Parent = detail

	local heroName = Instance.new("TextLabel")
	heroName.Name = "Name"
	heroName.Size = UDim2.new(0.9, 0, 0.1, 0)
	heroName.Position = UDim2.new(0.05, 0, 0.03, 0)
	heroName.BackgroundTransparency = 1
	heroName.TextColor3 = Color3.fromRGB(255, 255, 255)
	heroName.TextScaled = true
	heroName.Font = Enum.Font.GothamBold
	heroName.Text = "Select a Hero"
	heroName.ZIndex = 12
	heroName.Parent = detail
	UIController.Elements.HeroDetailName = heroName

	local heroStats = Instance.new("TextLabel")
	heroStats.Name = "Stats"
	heroStats.Size = UDim2.new(0.9, 0, 0.42, 0)
	heroStats.Position = UDim2.new(0.05, 0, 0.15, 0)
	heroStats.BackgroundTransparency = 1
	heroStats.TextColor3 = Color3.fromRGB(190, 205, 225)
	heroStats.TextScaled = true
	heroStats.Font = Enum.Font.Gotham
	heroStats.TextXAlignment = Enum.TextXAlignment.Left
	heroStats.Text = ""
	heroStats.ZIndex = 12
	heroStats.Parent = detail
	UIController.Elements.HeroDetailStats = heroStats

	local levelUpBtn = Instance.new("TextButton")
	levelUpBtn.Name = "LevelUpBtn"
	levelUpBtn.Size = UDim2.new(0.9, 0, 0.12, 0)
	levelUpBtn.Position = UDim2.new(0.05, 0, 0.60, 0)
	levelUpBtn.BackgroundColor3 = Color3.fromRGB(50, 140, 220)
	levelUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelUpBtn.TextScaled = true
	levelUpBtn.Font = Enum.Font.GothamBold
	levelUpBtn.Text = "LEVEL UP (Elixir)"
	levelUpBtn.ZIndex = 12
	levelUpBtn.Parent = detail
	UIController.Elements.LevelUpBtn = levelUpBtn

	local lCorner = Instance.new("UICorner")
	lCorner.CornerRadius = UDim.new(0, 8)
	lCorner.Parent = levelUpBtn

	levelUpBtn.MouseButton1Click:Connect(function()
		if UIController.SelectedHeroUid and UIController.Remotes.LevelUpHero then
			UIController.Remotes.LevelUpHero:FireServer(UIController.SelectedHeroUid)
		end
	end)

	local starUpBtn = Instance.new("TextButton")
	starUpBtn.Name = "StarUpBtn"
	starUpBtn.Size = UDim2.new(0.9, 0, 0.12, 0)
	starUpBtn.Position = UDim2.new(0.05, 0, 0.74, 0)
	starUpBtn.BackgroundColor3 = Color3.fromRGB(220, 160, 40)
	starUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	starUpBtn.TextScaled = true
	starUpBtn.Font = Enum.Font.GothamBold
	starUpBtn.Text = "⭐ ASCEND / STAR-UP"
	starUpBtn.ZIndex = 12
	starUpBtn.Parent = detail
	UIController.Elements.StarUpBtn = starUpBtn

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 8)
	sCorner.Parent = starUpBtn

	starUpBtn.MouseButton1Click:Connect(function()
		local targetUid = UIController.SelectedHeroUid
		if not targetUid then return end

		local targetHero = UIController.State.Heroes[targetUid]
		if not targetHero then return end

		local activeSet: { [string]: boolean } = {}
		for _, uid in ipairs(UIController.State.Formation) do
			activeSet[uid] = true
		end

		local sacrifices: { string } = {}
		for uid, hero in pairs(UIController.State.Heroes) do
			if uid ~= targetUid and not activeSet[uid] and hero.HeroId == targetHero.HeroId then
				table.insert(sacrifices, uid)
				if #sacrifices >= 2 then
					break
				end
			end
		end

		if #sacrifices < 2 then
			UIController.ShowNotification("Need 2 duplicate heroes (not in active squad) to Ascend!", Color3.fromRGB(255, 80, 80))
			return
		end

		if UIController.Remotes.StarUpHero then
			UIController.Remotes.StarUpHero:FireServer(targetUid, sacrifices)
		end
	end)
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

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundTransparency = 1
	header.TextColor3 = Color3.fromRGB(200, 255, 230)
	header.TextScaled = true
	header.Font = Enum.Font.GothamBlack
	header.Text = "🛡️ SQUAD DEPLOYMENT FORMATION (MAX 6 HEROES)"
	header.ZIndex = 16
	header.Parent = modal

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 17
	closeBtn.Parent = modal

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	local autoBtn = Instance.new("TextButton")
	autoBtn.Size = UDim2.new(0, 180, 0, 36)
	autoBtn.Position = UDim2.new(1, -240, 0, 8)
	autoBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 220)
	autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoBtn.TextScaled = true
	autoBtn.Font = Enum.Font.GothamBold
	autoBtn.Text = "⚡ AUTO FORMATION"
	autoBtn.ZIndex = 17
	autoBtn.Parent = modal

	local aCorner = Instance.new("UICorner")
	aCorner.CornerRadius = UDim.new(0, 8)
	aCorner.Parent = autoBtn

	autoBtn.MouseButton1Click:Connect(function()
		UIController.AutoFormSquad()
	end)

	local squadFrame = Instance.new("Frame")
	squadFrame.Size = UDim2.new(0.92, 0, 0.40, 0)
	squadFrame.Position = UDim2.new(0.04, 0, 0, 58)
	squadFrame.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	squadFrame.BorderSizePixel = 0
	squadFrame.ZIndex = 16
	squadFrame.Parent = modal
	UIController.Elements.SquadSlotsFrame = squadFrame

	local sfCorner = Instance.new("UICorner")
	sfCorner.CornerRadius = UDim.new(0, 12)
	sfCorner.Parent = squadFrame

	local sLayout = Instance.new("UIGridLayout")
	sLayout.CellSize = UDim2.new(0, 110, 0, 135)
	sLayout.CellPadding = UDim2.new(0, 12, 0, 12)
	sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	sLayout.Parent = squadFrame

	local pickerTitle = Instance.new("TextLabel")
	pickerTitle.Size = UDim2.new(0.92, 0, 0, 24)
	pickerTitle.Position = UDim2.new(0.04, 0, 0, 215)
	pickerTitle.BackgroundTransparency = 1
	pickerTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	pickerTitle.TextScaled = true
	pickerTitle.Font = Enum.Font.GothamBold
	pickerTitle.TextXAlignment = Enum.TextXAlignment.Left
	pickerTitle.Text = "RESERVE HEROES (Tap to equip into squad):"
	pickerTitle.ZIndex = 16
	pickerTitle.Parent = modal

	local heroScroll = Instance.new("ScrollingFrame")
	heroScroll.Size = UDim2.new(0.92, 0, 0.42, 0)
	heroScroll.Position = UDim2.new(0.04, 0, 0, 244)
	heroScroll.BackgroundTransparency = 1
	heroScroll.BorderSizePixel = 0
	heroScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	heroScroll.ZIndex = 16
	heroScroll.Parent = modal
	UIController.Elements.FormationHeroScroll = heroScroll

	local fLayout = Instance.new("UIGridLayout")
	fLayout.CellSize = UDim2.new(0, 100, 0, 115)
	fLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	fLayout.Parent = heroScroll
end

function UIController.RefreshFormationUI()
	local squadFrame = UIController.Elements.SquadSlotsFrame
	local heroScroll = UIController.Elements.FormationHeroScroll
	if not squadFrame or not heroScroll then return end

	for _, child in ipairs(squadFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for _, child in ipairs(heroScroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local curFormation = UIController.State.Formation or {}
	local activeSet: { [string]: boolean } = {}

	for slotIdx = 1, 6 do
		local heroUid = curFormation[slotIdx]
		local inst = heroUid and UIController.State.Heroes[heroUid]
		local def = inst and HeroData.Get(inst.HeroId)

		local slotBox = Instance.new("Frame")
		slotBox.Name = "Slot_" .. slotIdx
		slotBox.BackgroundColor3 = inst and Color3.fromRGB(30, 38, 55) or Color3.fromRGB(24, 26, 34)
		slotBox.ZIndex = 17
		slotBox.Parent = squadFrame

		local sbCorn = Instance.new("UICorner")
		sbCorn.CornerRadius = UDim.new(0, 10)
		sbCorn.Parent = slotBox

		local sbStroke = Instance.new("UIStroke")
		sbStroke.Color = inst and GetStarColor(inst.Star) or Color3.fromRGB(55, 60, 75)
		sbStroke.Thickness = 2
		sbStroke.Parent = slotBox

		if inst and def then
			activeSet[heroUid] = true

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(0.9, 0, 0.35, 0)
			nameLbl.Position = UDim2.new(0.05, 0, 0.05, 0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLbl.TextScaled = true
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.Text = string.format("%s\n%s", def.Name, def.Role)
			nameLbl.ZIndex = 18
			nameLbl.Parent = slotBox

			local lvlLbl = Instance.new("TextLabel")
			lvlLbl.Size = UDim2.new(0.9, 0, 0.25, 0)
			lvlLbl.Position = UDim2.new(0.05, 0, 0.42, 0)
			lvlLbl.BackgroundTransparency = 1
			lvlLbl.TextColor3 = Color3.fromRGB(255, 215, 60)
			lvlLbl.TextScaled = true
			lvlLbl.Font = Enum.Font.GothamMedium
			lvlLbl.Text = string.format("Lv.%d %s", inst.Level, GetStars(inst.Star))
			lvlLbl.ZIndex = 18
			lvlLbl.Parent = slotBox

			local unequipBtn = Instance.new("TextButton")
			unequipBtn.Size = UDim2.new(0.8, 0, 0.25, 0)
			unequipBtn.Position = UDim2.new(0.1, 0, 0.70, 0)
			unequipBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			unequipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			unequipBtn.TextScaled = true
			unequipBtn.Font = Enum.Font.GothamBold
			unequipBtn.Text = "UNEQUIP"
			unequipBtn.ZIndex = 19
			unequipBtn.Parent = slotBox

			local ueCorn = Instance.new("UICorner")
			ueCorn.CornerRadius = UDim.new(0, 6)
			ueCorn.Parent = unequipBtn

			unequipBtn.MouseButton1Click:Connect(function()
				local newFormation = {}
				for _, u in ipairs(curFormation) do
					if u ~= heroUid then
						table.insert(newFormation, u)
					end
				end
				if UIController.Remotes.UpdateFormation then
					UIController.Remotes.UpdateFormation:FireServer(newFormation)
				end
			end)
		else
			local emptyLbl = Instance.new("TextLabel")
			emptyLbl.Size = UDim2.new(0.9, 0, 0.9, 0)
			emptyLbl.Position = UDim2.new(0.05, 0, 0.05, 0)
			emptyLbl.BackgroundTransparency = 1
			emptyLbl.TextColor3 = Color3.fromRGB(90, 95, 110)
			emptyLbl.TextScaled = true
			emptyLbl.Font = Enum.Font.GothamBold
			emptyLbl.Text = string.format("SLOT %d\n[EMPTY]", slotIdx)
			emptyLbl.ZIndex = 18
			emptyLbl.Parent = slotBox
		end
	end

	-- Populate Reserve Heroes
	for uid, inst in pairs(UIController.State.Heroes) do
		local def = HeroData.Get(inst.HeroId)
		if def and not activeSet[uid] then
			local card = Instance.new("TextButton")
			card.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
			card.ZIndex = 17
			card.Parent = heroScroll

			local cCorn = Instance.new("UICorner")
			cCorn.CornerRadius = UDim.new(0, 8)
			cCorn.Parent = card

			local cStroke = Instance.new("UIStroke")
			cStroke.Color = GetStarColor(inst.Star)
			cStroke.Thickness = 1.5
			cStroke.Parent = card

			local cName = Instance.new("TextLabel")
			cName.Size = UDim2.new(0.9, 0, 0.45, 0)
			cName.Position = UDim2.new(0.05, 0, 0.08, 0)
			cName.BackgroundTransparency = 1
			cName.TextColor3 = Color3.fromRGB(255, 255, 255)
			cName.TextScaled = true
			cName.Font = Enum.Font.GothamBold
			cName.Text = string.format("%s\n%s", def.Name, def.Role)
			cName.ZIndex = 18
			cName.Parent = card

			local cLvl = Instance.new("TextLabel")
			cLvl.Size = UDim2.new(0.9, 0, 0.35, 0)
			cLvl.Position = UDim2.new(0.05, 0, 0.58, 0)
			cLvl.BackgroundTransparency = 1
			cLvl.TextColor3 = Color3.fromRGB(255, 215, 60)
			cLvl.TextScaled = true
			cLvl.Font = Enum.Font.GothamMedium
			cLvl.Text = string.format("Lv.%d %s", inst.Level, GetStars(inst.Star))
			cLvl.ZIndex = 18
			cLvl.Parent = card

			card.MouseButton1Click:Connect(function()
				if #curFormation >= 6 then
					UIController.ShowNotification("Squad is full! Unequip a hero first.", Color3.fromRGB(255, 180, 50))
					return
				end
				local newFormation = table.clone(curFormation)
				table.insert(newFormation, uid)
				if UIController.Remotes.UpdateFormation then
					UIController.Remotes.UpdateFormation:FireServer(newFormation)
				end
			end)
		end
	end
end

function UIController.AutoFormSquad()
	local all = {}
	for uid, inst in pairs(UIController.State.Heroes) do
		local def = HeroData.Get(inst.HeroId)
		if def then
			table.insert(all, { Uid = uid, Inst = inst, Def = def })
		end
	end

	table.sort(all, function(a, b)
		if a.Inst.Star ~= b.Inst.Star then
			return a.Inst.Star > b.Inst.Star
		end
		return a.Inst.Level > b.Inst.Level
	end)

	local picked = {}
	for _, entry in ipairs(all) do
		table.insert(picked, entry.Uid)
		if #picked >= 6 then break end
	end

	if #picked > 0 and UIController.Remotes.UpdateFormation then
		UIController.Remotes.UpdateFormation:FireServer(picked)
	end
end

function UIController.BuildGachaRevealModal()
	local modal = Instance.new("Frame")
	modal.Name = "GachaRevealModal"
	modal.Size = UDim2.new(0.75, 0, 0.75, 0)
	modal.Position = UDim2.new(0.125, 0, 0.125, 0)
	modal.BackgroundColor3 = Color3.fromRGB(15, 12, 25)
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.ZIndex = 25
	modal.Parent = UIController.ScreenGui
	UIController.Elements.GachaRevealModal = modal

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = modal

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 230, 100)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Text = "🎉 SUMMON RESULTS"
	title.ZIndex = 26
	title.Parent = modal

	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(0.9, 0, 0.7, 0)
	grid.Position = UDim2.new(0.05, 0, 0.15, 0)
	grid.BackgroundTransparency = 1
	grid.ZIndex = 26
	grid.Parent = modal
	UIController.Elements.GachaGrid = grid

	local gLayout = Instance.new("UIGridLayout")
	gLayout.CellSize = UDim2.new(0, 110, 0, 130)
	gLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gLayout.Parent = grid

	local okBtn = Instance.new("TextButton")
	okBtn.Size = UDim2.new(0.3, 0, 0, 44)
	okBtn.Position = UDim2.new(0.35, 0, 0.88, 0)
	okBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 220)
	okBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	okBtn.TextScaled = true
	okBtn.Font = Enum.Font.GothamBold
	okBtn.Text = "CONFIRM"
	okBtn.ZIndex = 26
	okBtn.Parent = modal

	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = UDim.new(0, 8)
	okCorner.Parent = okBtn

	okBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)
end

function UIController.BuildBattleResultModal()
	local modal = Instance.new("Frame")
	modal.Name = "BattleResultModal"
	modal.Size = UDim2.new(0.55, 0, 0.65, 0)
	modal.Position = UDim2.new(0.225, 0, 0.175, 0)
	modal.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
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
	stroke.Thickness = 2.5
	stroke.Parent = modal
	UIController.Elements.BattleResultStroke = stroke

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.9, 0, 0.18, 0)
	title.Position = UDim2.new(0.05, 0, 0.05, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 60)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Text = "OPERATION SUCCESS"
	title.ZIndex = 31
	title.Parent = modal
	UIController.Elements.BattleResultTitle = title

	local starsLbl = Instance.new("TextLabel")
	starsLbl.Size = UDim2.new(0.9, 0, 0.12, 0)
	starsLbl.Position = UDim2.new(0.05, 0, 0.24, 0)
	starsLbl.BackgroundTransparency = 1
	starsLbl.TextColor3 = Color3.fromRGB(255, 215, 60)
	starsLbl.TextScaled = true
	starsLbl.Font = Enum.Font.GothamBold
	starsLbl.Text = "★★★"
	starsLbl.ZIndex = 31
	starsLbl.Parent = modal
	UIController.Elements.BattleResultStars = starsLbl

	local rewardsLbl = Instance.new("TextLabel")
	rewardsLbl.Size = UDim2.new(0.9, 0, 0.35, 0)
	rewardsLbl.Position = UDim2.new(0.05, 0, 0.38, 0)
	rewardsLbl.BackgroundTransparency = 1
	rewardsLbl.TextColor3 = Color3.fromRGB(220, 235, 255)
	rewardsLbl.TextScaled = true
	rewardsLbl.Font = Enum.Font.Gotham
	rewardsLbl.Text = "+50 Diamonds\n+10,000 Gold"
	rewardsLbl.ZIndex = 31
	rewardsLbl.Parent = modal
	UIController.Elements.BattleResultRewards = rewardsLbl

	local lobbyBtn = Instance.new("TextButton")
	lobbyBtn.Name = "LobbyBtn"
	lobbyBtn.Size = UDim2.new(0.42, 0, 0, 46)
	lobbyBtn.Position = UDim2.new(0.06, 0, 0.81, 0)
	lobbyBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
	lobbyBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
	lobbyBtn.TextScaled = true
	lobbyBtn.Font = Enum.Font.GothamBold
	lobbyBtn.Text = "🏠 RETURN TO LOBBY"
	lobbyBtn.ZIndex = 32
	lobbyBtn.Parent = modal
	UIController.Elements.BattleResultLobbyBtn = lobbyBtn

	local lCorner = Instance.new("UICorner")
	lCorner.CornerRadius = UDim.new(0, 10)
	lCorner.Parent = lobbyBtn

	local lStroke = Instance.new("UIStroke")
	lStroke.Color = Color3.fromRGB(75, 90, 115)
	lStroke.Thickness = 1.5
	lStroke.Parent = lobbyBtn

	lobbyBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
		BattleArenaController.ReturnToLobby()
		UIController.SetLobbyVisible(true)
	end)

	local nextBtn = Instance.new("TextButton")
	nextBtn.Name = "NextStageBtn"
	nextBtn.Size = UDim2.new(0.44, 0, 0, 46)
	nextBtn.Position = UDim2.new(0.50, 0, 0.81, 0)
	nextBtn.BackgroundColor3 = Color3.fromRGB(35, 175, 85)
	nextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	nextBtn.TextScaled = true
	nextBtn.Font = Enum.Font.GothamBlack
	nextBtn.Text = "NEXT LEVEL ➔"
	nextBtn.ZIndex = 32
	nextBtn.Parent = modal
	UIController.Elements.BattleResultNextBtn = nextBtn

	local nCorner = Instance.new("UICorner")
	nCorner.CornerRadius = UDim.new(0, 10)
	nCorner.Parent = nextBtn

	local nStroke = Instance.new("UIStroke")
	nStroke.Name = "NextStroke"
	nStroke.Color = Color3.fromRGB(110, 240, 150)
	nStroke.Thickness = 2
	nStroke.Parent = nextBtn
	UIController.Elements.BattleResultNextBtnStroke = nStroke

	nextBtn.MouseButton1Click:Connect(function()
		if not UIController.CurrentBattleData then return end
		local currentStageId = UIController.CurrentBattleData.StageId
		local isSuccess = UIController.CurrentBattleData.Success

		modal.Visible = false

		local targetStageId: string? = currentStageId
		if isSuccess then
			targetStageId = StageData.GetNextStageId(currentStageId)
		end

		if not targetStageId then
			UIController.ShowNotification("All chapters and stages cleared! 🎉", Color3.fromRGB(255, 215, 60))
			BattleArenaController.ReturnToLobby()
			UIController.SetLobbyVisible(true)
			return
		end

		local isSkipUnlocked = StageData.IsMilestoneReached(UIController.State.HighestClearedStage, "5-10")
		local isSkip = isSkipUnlocked and (UIController.IsSkipAutobattle == true)

		UIController.SelectedStageId = targetStageId
		local nextChap = tonumber(targetStageId:match("(%d+)-")) or 1
		UIController.SelectedChapter = nextChap
		UIController.RefreshCampaignCards()

		if UIController.Remotes.StartBattle then
			UIController.Remotes.StartBattle:FireServer(targetStageId, isSkip)
		end
	end)
end

function UIController.ToggleModal(modalName: string)
	local modals = { "CampaignModal", "BackpackModal", "FormationModal", "SummonModal", "BattleResultModal", "MailboxModal", "MissionsModal", "EventsModal" }
	local target = UIController.Elements[modalName]

	if modalName == "" or not target then
		for _, name in ipairs(modals) do
			local m = UIController.Elements[name]
			if m then m.Visible = false end
		end
		return
	end

	local willBeVisible = not target.Visible
	for _, name in ipairs(modals) do
		local m = UIController.Elements[name]
		if m then m.Visible = false end
	end

	target.Visible = willBeVisible
	if modalName == "BackpackModal" and willBeVisible then
		UIController.RefreshHeroGrid()
	elseif modalName == "FormationModal" and willBeVisible then
		UIController.RefreshFormationUI()
	elseif modalName == "CampaignModal" and willBeVisible then
		UIController.RefreshCampaignCards()
	elseif modalName == "SummonModal" and willBeVisible then
		UIController.RefreshSummonButtons()
	elseif modalName == "MailboxModal" and willBeVisible then
		UIController.RefreshMailboxUI()
	elseif modalName == "MissionsModal" and willBeVisible then
		UIController.RefreshMissionsUI()
	elseif modalName == "EventsModal" and willBeVisible then
		UIController.RefreshEventsUI()
	end
end

function UIController.RefreshHeroGrid()
	local scroll = UIController.Elements.HeroScroll
	if not scroll then return end

	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
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

			local role = Instance.new("TextLabel")
			role.Size = UDim2.new(0.9, 0, 0.25, 0)
			role.Position = UDim2.new(0.05, 0, 0.42, 0)
			role.BackgroundTransparency = 1
			role.TextColor3 = Color3.fromRGB(150, 180, 220)
			role.TextScaled = true
			role.Font = Enum.Font.Gotham
			role.Text = def.Role
			role.ZIndex = 13
			role.Parent = card

			local lvl = Instance.new("TextLabel")
			lvl.Size = UDim2.new(0.9, 0, 0.25, 0)
			lvl.Position = UDim2.new(0.05, 0, 0.70, 0)
			lvl.BackgroundTransparency = 1
			lvl.TextColor3 = Color3.fromRGB(255, 215, 60)
			lvl.TextScaled = true
			lvl.Font = Enum.Font.GothamMedium
			lvl.Text = string.format("Lv.%d %s", inst.Level, GetStars(inst.Star))
			lvl.ZIndex = 13
			lvl.Parent = card

			card.MouseButton1Click:Connect(function()
				UIController.SelectHero(uid)
			end)
		end
	end
end

function UIController.SelectHero(uid: string)
	UIController.SelectedHeroUid = uid
	local inst = UIController.State.Heroes[uid]
	if not inst then return end
	local def = HeroData.Get(inst.HeroId)
	if not def then return end

	local nameLbl = UIController.Elements.HeroDetailName
	local statsLbl = UIController.Elements.HeroDetailStats
	local starBtn = UIController.Elements.StarUpBtn
	if not nameLbl or not statsLbl or not starBtn then return end

	nameLbl.Text = string.format("%s (%s)", def.Name, def.Role)
	nameLbl.TextColor3 = def.Color

	local cap = HeroData.GetLevelCap(inst.Star)
	local cost = HeroData.GetLevelUpCost(inst.Level)
	local isCapped = inst.Level >= cap

	statsLbl.Text = string.format(
		"Rank: %s\nLevel: %d / %d %s\n\nHP: %d\nATK: %d\nDEF: %d\nRange: %.1f tiles\nBlock Count: %d\nPlacement: %s\n\nUpgrade Cost: %d 💰, %d 🧪",
		GetStars(inst.Star),
		inst.Level, cap,
		(isCapped and "[MAX - ASCEND REQUIRED]" or ""),
		math.floor(def.BaseHp * (1 + (inst.Level - 1) * 0.12)),
		math.floor(def.BaseAtk * (1 + (inst.Level - 1) * 0.10)),
		math.floor(def.BaseDef * (1 + (inst.Level - 1) * 0.08)),
		def.Range,
		def.BlockCount,
		def.PlacementType,
		cost.Gold,
		cost.Elixir
	)

	starBtn.Text = (inst.Star >= 10) and "⭐ MAX ASCENSION (10★)" or string.format("⭐ ASCEND TO %d★ (Sacrifice 2 dupes)", inst.Star + 1)
	starBtn.Active = inst.Star < 10
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
	if UIController.Elements.BasicScrollLabel then
		UIController.Elements.BasicScrollLabel.Text = "📜 " .. tostring(UIController.State.BasicScrolls or 0)
	end
	if UIController.Elements.EliteScrollLabel then
		UIController.Elements.EliteScrollLabel.Text = "🔮 " .. tostring(UIController.State.EliteScrolls or 0)
	end

	-- Check unclaimed mail badge
	local hasUnclaimedMail = false
	for _, m in pairs(UIController.State.Mailbox or {}) do
		if not m.Claimed then
			hasUnclaimedMail = true
			break
		end
	end
	if UIController.Elements.MailboxBtn then
		UIController.Elements.MailboxBtn.Text = hasUnclaimedMail and "📬 MAILBOX (!)" or "📬 MAILBOX"
	end

	if UIController.SelectedHeroUid then
		UIController.SelectHero(UIController.SelectedHeroUid)
	end

	if UIController.Elements.CampaignModal and UIController.Elements.CampaignModal.Visible then
		if UIController.CurrentCampaignView == "Stages" then
			UIController.RefreshCampaignCards()
		else
			UIController.RefreshChaptersList()
		end
	end
	if UIController.Elements.FormationModal and UIController.Elements.FormationModal.Visible then
		UIController.RefreshFormationUI()
	end
	if UIController.Elements.SummonModal and UIController.Elements.SummonModal.Visible then
		UIController.RefreshSummonButtons()
	end
	if UIController.Elements.MailboxModal and UIController.Elements.MailboxModal.Visible then
		UIController.RefreshMailboxUI()
	end
	if UIController.Elements.MissionsModal and UIController.Elements.MissionsModal.Visible then
		UIController.RefreshMissionsUI()
	end
	if UIController.Elements.EventsModal and UIController.Elements.EventsModal.Visible then
		UIController.RefreshEventsUI()
	end
end

function UIController.OnGachaResult(results: { any })
	local modal = UIController.Elements.GachaRevealModal
	local grid = UIController.Elements.GachaGrid
	if not modal or not grid then return end

	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for _, res in ipairs(results) do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Color3.fromRGB(28, 22, 42)
		card.ZIndex = 27
		card.Parent = grid

		local cCorn = Instance.new("UICorner")
		cCorn.CornerRadius = UDim.new(0, 10)
		cCorn.Parent = card

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = GetStarColor(res.Star)
		cStroke.Thickness = 2.5
		cStroke.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0.9, 0, 0.45, 0)
		name.Position = UDim2.new(0.05, 0, 0.08, 0)
		name.BackgroundTransparency = 1
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.TextScaled = true
		name.Font = Enum.Font.GothamBold
		name.Text = res.Name
		name.ZIndex = 28
		name.Parent = card

		local stars = Instance.new("TextLabel")
		stars.Size = UDim2.new(0.9, 0, 0.35, 0)
		stars.Position = UDim2.new(0.05, 0, 0.58, 0)
		stars.BackgroundTransparency = 1
		stars.TextColor3 = GetStarColor(res.Star)
		stars.TextScaled = true
		stars.Font = Enum.Font.GothamBlack
		stars.Text = GetStars(res.Star)
		stars.ZIndex = 28
		stars.Parent = card
	end

	modal.Visible = true
	UIController.RefreshSummonButtons()
end

function UIController.OnBattleFinished(data: any)
	if data.IsSkip == false then
		-- Hide lobby UI and start 3D World Battle View
		UIController.SetLobbyVisible(false)
		data.HighestClearedStage = UIController.State.HighestClearedStage

		BattleArenaController.Start3DBattle(data, function()
			UIController.OnBattleFinishedDirect(data)
		end)
	else
		UIController.OnBattleFinishedDirect(data)
	end
end

function UIController.OnBattleFinishedDirect(data: any)
	UIController.CurrentBattleData = data

	local modal = UIController.Elements.BattleResultModal
	local title = UIController.Elements.BattleResultTitle
	local starsLbl = UIController.Elements.BattleResultStars
	local rewardsLbl = UIController.Elements.BattleResultRewards
	local stroke = UIController.Elements.BattleResultStroke
	local lobbyBtn = UIController.Elements.BattleResultLobbyBtn
	local nextBtn = UIController.Elements.BattleResultNextBtn
	local nextBtnStroke = UIController.Elements.BattleResultNextBtnStroke
	if not modal or not title or not starsLbl or not rewardsLbl or not stroke or not lobbyBtn or not nextBtn then return end

	if data.Success then
		title.Text = "OPERATION SUCCESS"
		title.TextColor3 = Color3.fromRGB(255, 220, 60)
		starsLbl.Text = GetStars(data.Stars or 3)
		starsLbl.TextColor3 = Color3.fromRGB(255, 215, 60)
		stroke.Color = Color3.fromRGB(255, 215, 60)

		local rew = data.Rewards or {}
		rewardsLbl.Text = string.format(
			"+%s Gold\n+%s Elixir%s%s%s",
			MathUtil.FormatNumber(rew.Gold or 0),
			MathUtil.FormatNumber(rew.Elixir or 0),
			(rew.Diamonds and rew.Diamonds > 0) and string.format("\n+%d Diamonds", rew.Diamonds) or "",
			(rew.BasicScrolls and rew.BasicScrolls > 0) and string.format("\n+%d Basic Scrolls", rew.BasicScrolls) or "",
			(rew.Equipment) and string.format("\n🎁 Gear Loot: %s", rew.Equipment) or ""
		)

		-- Advance next stage
		local nextStage = StageData.GetNextStageId(data.StageId)
		if nextStage then
			UIController.SelectedStageId = nextStage
			local nextChap = tonumber(nextStage:match("(%d+)-")) or 1
			UIController.SelectedChapter = nextChap

			nextBtn.Visible = true
			nextBtn.Text = string.format("NEXT LEVEL (%s) ➔", nextStage)
			nextBtn.BackgroundColor3 = Color3.fromRGB(35, 175, 85)
			if nextBtnStroke then
				nextBtnStroke.Color = Color3.fromRGB(110, 240, 150)
			end
			lobbyBtn.Size = UDim2.new(0.42, 0, 0, 46)
			lobbyBtn.Position = UDim2.new(0.06, 0, 0.81, 0)
			lobbyBtn.Text = "🏠 RETURN TO LOBBY"
		else
			nextBtn.Visible = false
			lobbyBtn.Size = UDim2.new(0.55, 0, 0, 46)
			lobbyBtn.Position = UDim2.new(0.225, 0, 0.81, 0)
			lobbyBtn.Text = "🏠 RETURN TO LOBBY (CLEARED)"
		end
	else
		title.Text = "OPERATION FAILED"
		title.TextColor3 = Color3.fromRGB(255, 60, 60)
		starsLbl.Text = "BASE CRYSTAL DESTROYED"
		starsLbl.TextColor3 = Color3.fromRGB(200, 70, 70)
		stroke.Color = Color3.fromRGB(200, 50, 50)
		rewardsLbl.Text = "Strengthen your hero squad,\nascend your defenders, and try again!"

		nextBtn.Visible = true
		nextBtn.Text = string.format("RETRY STAGE (%s) 🔄", data.StageId)
		nextBtn.BackgroundColor3 = Color3.fromRGB(220, 75, 55)
		if nextBtnStroke then
			nextBtnStroke.Color = Color3.fromRGB(255, 130, 110)
		end
		lobbyBtn.Size = UDim2.new(0.42, 0, 0, 46)
		lobbyBtn.Position = UDim2.new(0.06, 0, 0.81, 0)
		lobbyBtn.Text = "🏠 RETURN TO LOBBY"
	end

	modal.Visible = true
	UIController.RefreshCampaignCards()
end

function UIController.ShowNotification(message: string, color: Color3?)
	local screenGui = UIController.ScreenGui
	if not screenGui then return end

	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(0.4, 0, 0, 48)
	notif.Position = UDim2.new(0.3, 0, 0.15, 0)
	notif.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	notif.BorderSizePixel = 0
	notif.ZIndex = 50
	notif.Parent = screenGui

	local nCorner = Instance.new("UICorner")
	nCorner.CornerRadius = UDim.new(0, 10)
	nCorner.Parent = notif

	local nStroke = Instance.new("UIStroke")
	nStroke.Color = color or Color3.fromRGB(255, 215, 60)
	nStroke.Thickness = 2
	nStroke.Parent = notif

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.92, 0, 0.9, 0)
	lbl.Position = UDim2.new(0.04, 0, 0.05, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = message
	lbl.ZIndex = 51
	lbl.Parent = notif

	task.delay(2.6, function()
		local tween = TweenService:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		tween:Play()
		task.delay(0.42, function()
			if notif and notif.Parent then
				notif:Destroy()
			end
		end)
	end)
end

return UIController
