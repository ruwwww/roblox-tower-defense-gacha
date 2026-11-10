--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StageData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("StageData"))
local AutoFormation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Formation"):WaitForChild("AutoFormation"))
local BattleSimulation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Simulation"):WaitForChild("BattleSimulation"))

local ProfileService = require(script.Parent:WaitForChild("ProfileService"))

local CampaignService = {
	Remotes = {} :: { [string]: RemoteEvent },
}

function CampaignService.Init(remotes: { [string]: RemoteEvent })
	CampaignService.Remotes = remotes
end

function CampaignService.StartBattle(player: Player, stageId: string, isSkip: boolean)
	local prof = ProfileService.Get(player)
	if not prof then
		return
	end

	local stage = StageData.Get(stageId)
	if not stage then
		return
	end

	local targetKey = StageData.ParseStageKey(stageId)
	local clearedKey = StageData.ParseStageKey(prof.HighestClearedStage)

	-- 1. Disallow repeat battles!
	if targetKey <= clearedKey and clearedKey > 0 then
		if CampaignService.Remotes.NotifyMessage then
			CampaignService.Remotes.NotifyMessage:FireClient(
				player,
				"Stage already cleared! Repeat battle is disabled. Please challenge the next stage.",
				Color3.fromRGB(255, 140, 60)
			)
		end
		return
	end

	-- 2. Lock check: cannot skip past current stage
	if not StageData.IsStageUnlocked(prof.HighestClearedStage, stageId) then
		if CampaignService.Remotes.NotifyMessage then
			CampaignService.Remotes.NotifyMessage:FireClient(
				player,
				"Stage is locked! Clear prior stages first.",
				Color3.fromRGB(255, 80, 80)
			)
		end
		return
	end

	-- 3. Milestone check for Skip battle
	if isSkip then
		local hasSkipMilestone = StageData.IsMilestoneReached(prof.HighestClearedStage, "5-10")
		if not hasSkipMilestone then
			if CampaignService.Remotes.NotifyMessage then
				CampaignService.Remotes.NotifyMessage:FireClient(
					player,
					"🔒 Skip Autobattle unlocks after clearing Stage 5-10!",
					Color3.fromRGB(255, 180, 50)
				)
			end
			return
		end
	end

	-- 4. Gather formation heroes
	local squad = {}
	for _, heroUid in ipairs(prof.Formation) do
		local inst = prof.Heroes[heroUid]
		if inst then
			table.insert(squad, inst)
		end
	end

	if #squad == 0 then
		if CampaignService.Remotes.NotifyMessage then
			CampaignService.Remotes.NotifyMessage:FireClient(player, "Your battle formation is empty! Equip heroes first.", Color3.fromRGB(255, 80, 80))
		end
		return
	end

	-- Run Auto-Formation heuristic
	local formation = AutoFormation.Generate(squad, stage)

	-- Run Headless Deterministic Battle Simulation (ground-truth!)
	local result = BattleSimulation.Run(stage, formation, prof.Heroes)

	local earnedRewards = {
		Gold = 0,
		Elixir = 0,
		Diamonds = 0,
		BasicScrolls = 0,
		EliteScrolls = 0,
		Equipment = nil :: string?,
		IsFirstClear = false,
	}

	if result.Success then
		earnedRewards.IsFirstClear = true
		earnedRewards.Diamonds = stage.FirstClearRewards.Diamonds
		earnedRewards.BasicScrolls = stage.FirstClearRewards.BasicScrolls or 1
		earnedRewards.EliteScrolls = stage.FirstClearRewards.EliteScrolls or 0
		earnedRewards.Elixir = stage.FirstClearRewards.Elixir
		earnedRewards.Gold = stage.FirstClearRewards.Gold
		earnedRewards.Equipment = stage.FirstClearRewards.GuaranteedEquipment

		prof.Diamonds += earnedRewards.Diamonds
		prof.BasicScrolls += earnedRewards.BasicScrolls
		prof.EliteScrolls += earnedRewards.EliteScrolls
		prof.Elixir += earnedRewards.Elixir
		prof.Gold += earnedRewards.Gold
		prof.HighestClearedStage = stageId

		local nextStage = StageData.GetNextStageId(stageId)
		if nextStage then
			prof.CurrentStage = nextStage
		end

		if earnedRewards.Equipment then
			table.insert(prof.EquipmentInventory, {
				Uid = HttpService:GenerateGUID(false),
				EquipmentId = earnedRewards.Equipment,
				EnhanceLevel = 0,
			})
		end

		-- Record daily battle progress
		ProfileService.RecordDailyProgress(player, "battle_3", 1)
		ProfileService.SyncProfile(player)
	end

	if CampaignService.Remotes.BattleFinished then
		CampaignService.Remotes.BattleFinished:FireClient(player, {
			Success = result.Success,
			Stars = result.Stars,
			CrystalHp = result.CrystalHp,
			MaxCrystalHp = result.MaxCrystalHp,
			StageId = stageId,
			StageName = stage.Name,
			IsSkip = isSkip,
			Rewards = earnedRewards,
			Formation = formation,
			DurationSeconds = result.DurationSeconds,
		})
	end
end

return CampaignService
