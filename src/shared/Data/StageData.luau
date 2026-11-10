--!strict

export type TileType = "Path" | "Ground" | "HighGround" | "Obstacle" | "Empty"

export type StageEnemySpawn = {
	Archetype: string,
	Count: number,
	Interval: number,
	Delay: number,
	IsBoss: boolean?,
	HpMult: number?,
	AtkMult: number?,
}

export type StageDefinition = {
	Id: string,
	Chapter: number,
	StageIndex: number,
	Name: string,
	IsMiniBoss: boolean,
	IsBoss: boolean,
	GridWidth: number,
	GridHeight: number,
	Tiles: { [string]: TileType }, -- "X,Y" -> TileType
	PathCoords: { Vector2 }, -- Ordered path coordinates from spawn to crystal goal
	Enemies: { StageEnemySpawn },
	FirstClearRewards: {
		Diamonds: number,
		BasicScrolls: number,
		EliteScrolls: number,
		Elixir: number,
		Gold: number,
		GuaranteedEquipment: string?,
	},
	AfkRates: {
		GoldPerMin: number,
		ElixirPerMin: number,
		ExpPerMin: number,
	},
}

export type ChapterDefinition = {
	Chapter: number,
	Name: string,
	Subtitle: string,
	RequiredClearedStage: string?, -- Nil for Chapter 1, "1-10" for Chapter 2, etc.
	TotalStages: number,
	ThemeColor: Color3,
}

local Chapters: { [number]: ChapterDefinition } = {
	[1] = {
		Chapter = 1,
		Name = "Chapter 1: The Outskirts",
		Subtitle = "The Ancient Colossus",
		RequiredClearedStage = nil,
		TotalStages = 10,
		ThemeColor = Color3.fromRGB(80, 160, 90),
	},
	[2] = {
		Chapter = 2,
		Name = "Chapter 2: Whispering Canyon",
		Subtitle = "Canyon Ambush",
		RequiredClearedStage = "1-10",
		TotalStages = 10,
		ThemeColor = Color3.fromRGB(220, 140, 50),
	},
	[3] = {
		Chapter = 3,
		Name = "Chapter 3: Molten Stronghold",
		Subtitle = "Volcanic Fort",
		RequiredClearedStage = "2-10",
		TotalStages = 10,
		ThemeColor = Color3.fromRGB(210, 60, 50),
	},
	[4] = {
		Chapter = 4,
		Name = "Chapter 4: Glacial Pass",
		Subtitle = "Frostbite Peaks",
		RequiredClearedStage = "3-10",
		TotalStages = 10,
		ThemeColor = Color3.fromRGB(70, 180, 220),
	},
	[5] = {
		Chapter = 5,
		Name = "Chapter 5: Abyssal Citadel",
		Subtitle = "The Void Throne",
		RequiredClearedStage = "4-10",
		TotalStages = 10,
		ThemeColor = Color3.fromRGB(150, 60, 200),
	},
}

-- Helper to generate clean, deterministic 10x8 tile layouts
local function BuildChapter1Map(): ({ [string]: TileType }, { Vector2 })
	local tiles: { [string]: TileType } = {}
	local path = {
		Vector2.new(1, 4),
		Vector2.new(3, 4),
		Vector2.new(3, 2),
		Vector2.new(6, 2),
		Vector2.new(6, 6),
		Vector2.new(8, 6),
		Vector2.new(8, 4),
		Vector2.new(10, 4),
	}

	-- 1. Initialize base grid
	for x = 1, 10 do
		for y = 1, 8 do
			local key = x .. "," .. y
			if x == 1 or x == 10 or y == 1 or y == 8 or (x % 3 == 0 and y % 3 == 0) then
				tiles[key] = "HighGround"
			else
				tiles[key] = "Ground"
			end
		end
	end

	-- 2. Carve path segments (guaranteed Path tiles!)
	for i = 1, #path - 1 do
		local p1 = path[i]
		local p2 = path[i + 1]
		local minX, maxX = math.min(p1.X, p2.X), math.max(p1.X, p2.X)
		local minY, maxY = math.min(p1.Y, p2.Y), math.max(p1.Y, p2.Y)
		for x = minX, maxX do
			for y = minY, maxY do
				tiles[x .. "," .. y] = "Path"
			end
		end
	end

	-- 3. Dedicated HighGround tower perches overlooking path
	tiles["4,3"] = "HighGround"
	tiles["5,3"] = "HighGround"
	tiles["7,3"] = "HighGround"
	tiles["5,5"] = "HighGround"
	tiles["7,5"] = "HighGround"

	-- 4. Dedicated Ground deployment spots adjacent to path (NOT on path)
	tiles["2,5"] = "Ground"
	tiles["4,2"] = "Ground"
	tiles["5,1"] = "Ground"
	tiles["7,7"] = "Ground"
	tiles["9,5"] = "Ground"

	return tiles, path
end

local function BuildChapter2Map(): ({ [string]: TileType }, { Vector2 })
	local tiles: { [string]: TileType } = {}
	-- S-curve canyon path
	local path = {
		Vector2.new(1, 2),
		Vector2.new(4, 2),
		Vector2.new(4, 5),
		Vector2.new(7, 5),
		Vector2.new(7, 3),
		Vector2.new(10, 3),
	}

	for x = 1, 10 do
		for y = 1, 8 do
			local key = x .. "," .. y
			if y <= 1 or y >= 7 or (x == 5 and (y == 3 or y == 4)) then
				tiles[key] = "HighGround"
			else
				tiles[key] = "Ground"
			end
		end
	end

	for i = 1, #path - 1 do
		local p1 = path[i]
		local p2 = path[i + 1]
		local minX, maxX = math.min(p1.X, p2.X), math.max(p1.X, p2.X)
		local minY, maxY = math.min(p1.Y, p2.Y), math.max(p1.Y, p2.Y)
		for x = minX, maxX do
			for y = minY, maxY do
				tiles[x .. "," .. y] = "Path"
			end
		end
	end

	tiles["3,3"] = "HighGround"
	tiles["5,2"] = "HighGround"
	tiles["8,2"] = "HighGround"
	tiles["6,6"] = "HighGround"

	tiles["3,1"] = "Ground"
	tiles["5,6"] = "Ground"
	tiles["8,4"] = "Ground"

	return tiles, path
end

local ch1Tiles, ch1Path = BuildChapter1Map()
local ch2Tiles, ch2Path = BuildChapter2Map()

local Stages: { [string]: StageDefinition } = {}

-- Helper to create stages
local function RegisterChapterStages(chapNum: number, tiles: { [string]: TileType }, path: { Vector2 })
	for idx = 1, 10 do
		local stageId = chapNum .. "-" .. tostring(idx)
		local isMiniBoss = (idx == 5)
		local isBoss = (idx == 10)

		local enemyList: { StageEnemySpawn } = {}
		local statScale = 1 + ((chapNum - 1) * 0.8) + (idx * 0.08)

		if isBoss then
			table.insert(enemyList, { Archetype = "grunt", Count = 12 + (chapNum * 4), Interval = 0.9, Delay = 0, HpMult = statScale, AtkMult = statScale })
			table.insert(enemyList, { Archetype = "runner", Count = 8 + (chapNum * 2), Interval = 0.7, Delay = 2, HpMult = statScale, AtkMult = statScale })
			table.insert(enemyList, { Archetype = "tank", Count = 6 + (chapNum * 2), Interval = 1.4, Delay = 5, HpMult = statScale, AtkMult = statScale })
			table.insert(enemyList, { Archetype = "boss", Count = 1, Interval = 0, Delay = 10, IsBoss = true, HpMult = statScale * 1.6, AtkMult = statScale * 1.4 })
		elseif isMiniBoss then
			table.insert(enemyList, { Archetype = "grunt", Count = 10 + (chapNum * 3), Interval = 1.1, Delay = 0, HpMult = statScale, AtkMult = statScale })
			table.insert(enemyList, { Archetype = "runner", Count = 6 + (chapNum * 2), Interval = 0.8, Delay = 2, HpMult = statScale, AtkMult = statScale })
			table.insert(enemyList, { Archetype = "golem", Count = 2, Interval = 3.5, Delay = 6, IsBoss = true, HpMult = statScale * 1.3, AtkMult = statScale * 1.2 })
		else
			local gruntCount = 6 + (idx * 2) + (chapNum * 2)
			local runnerCount = math.max(0, (idx - 1) * 2)
			local tankCount = math.max(0, math.floor(idx / 3))

			table.insert(enemyList, { Archetype = "grunt", Count = gruntCount, Interval = 1.1, Delay = 0, HpMult = statScale, AtkMult = statScale })
			if runnerCount > 0 then
				table.insert(enemyList, { Archetype = "runner", Count = runnerCount, Interval = 0.8, Delay = 2, HpMult = statScale, AtkMult = statScale })
			end
			if tankCount > 0 then
				table.insert(enemyList, { Archetype = "tank", Count = tankCount, Interval = 1.8, Delay = 5, HpMult = statScale, AtkMult = statScale })
			end
		end

		local stageTitle = string.format("Stage %d-%d", chapNum, idx)
		if isBoss then
			stageTitle = string.format("Chapter %d Climax: %s", chapNum, (chapNum == 1) and "The Ancient Colossus" or "Canyon Behemoth")
		elseif isMiniBoss then
			stageTitle = string.format("Stage %d-5: %s", chapNum, (chapNum == 1) and "Hobgoblin Stronghold" or "Gorge Ambush")
		end

		Stages[stageId] = {
			Id = stageId,
			Chapter = chapNum,
			StageIndex = idx,
			Name = stageTitle,
			IsMiniBoss = isMiniBoss,
			IsBoss = isBoss,
			GridWidth = 10,
			GridHeight = 8,
			Tiles = tiles,
			PathCoords = path,
			Enemies = enemyList,
			FirstClearRewards = {
				Diamonds = isBoss and (200 + chapNum * 100) or (isMiniBoss and 120 or 50),
				BasicScrolls = (isBoss or isMiniBoss) and 3 or 1,
				EliteScrolls = isBoss and 1 or 0,
				Elixir = 1000 + (chapNum * 1200) + (idx * 250),
				Gold = 2500 + (chapNum * 2000) + (idx * 500),
				GuaranteedEquipment = isBoss and "dragon_fang_spear" or (isMiniBoss and "knight_plate" or nil),
			},
			AfkRates = {
				GoldPerMin = 40 + (chapNum * 30) + (idx * 12),
				ElixirPerMin = 25 + (chapNum * 20) + (idx * 8),
				ExpPerMin = 15 + (chapNum * 12) + (idx * 5),
			},
		}
	end
end

RegisterChapterStages(1, ch1Tiles, ch1Path)
RegisterChapterStages(2, ch2Tiles, ch2Path)
RegisterChapterStages(3, ch1Tiles, ch1Path)
RegisterChapterStages(4, ch2Tiles, ch2Path)
RegisterChapterStages(5, ch1Tiles, ch1Path)

local StageData = {
	Chapters = Chapters,
	Stages = Stages,
}

function StageData.Get(stageId: string): StageDefinition?
	return Stages[stageId]
end

-- Convert "1-5" to number index for comparison: Chapter * 100 + StageIndex
function StageData.ParseStageKey(stageId: string?): number
	if not stageId or stageId == "1-0" or stageId == "0-0" or stageId == "" then
		return 0
	end
	local c, s = stageId:match("(%d+)%-(%d+)")
	if c and s then
		return (tonumber(c) or 0) * 100 + (tonumber(s) or 0)
	end
	return 0
end

function StageData.IsStageUnlocked(highestClearedStage: string?, stageId: string): boolean
	local targetKey = StageData.ParseStageKey(stageId)
	local clearedKey = StageData.ParseStageKey(highestClearedStage)

	-- Next playable stage is exactly the one after highest cleared
	local c, s = stageId:match("(%d+)%-(%d+)")
	local cNum = tonumber(c) or 1
	local sNum = tonumber(s) or 1

	if clearedKey == 0 then
		return (stageId == "1-1")
	end

	-- Current active next stage is unlocked
	local clearedChapter = math.floor(clearedKey / 100)
	local clearedStage = clearedKey % 100

	local nextChapter = clearedChapter
	local nextStage = clearedStage + 1
	if nextStage > 10 then
		nextChapter += 1
		nextStage = 1
	end

	local nextKey = nextChapter * 100 + nextStage
	return targetKey <= nextKey
end

function StageData.IsMilestoneReached(highestClearedStage: string?, milestoneStageId: string): boolean
	local clearedKey = StageData.ParseStageKey(highestClearedStage)
	local milestoneKey = StageData.ParseStageKey(milestoneStageId)
	return clearedKey >= milestoneKey
end

function StageData.GetNextStageId(currentStageId: string): string?
	local current = Stages[currentStageId]
	if not current then
		return "1-1"
	end
	local nextIdx = current.StageIndex + 1
	local nextChapter = current.Chapter

	if nextIdx > 10 then
		nextChapter += 1
		nextIdx = 1
	end

	local nextId = string.format("%d-%d", nextChapter, nextIdx)
	if Stages[nextId] then
		return nextId
	end
	return nil
end

function StageData.GetStagesForChapter(chapterNum: number): { StageDefinition }
	local result = {}
	for idx = 1, 10 do
		local sId = string.format("%d-%d", chapterNum, idx)
		local s = Stages[sId]
		if s then
			table.insert(result, s)
		end
	end
	return result
end

return StageData
