--!strict

export type TileType = "Path" | "Ground" | "HighGround" | "Empty"

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
	PathCoords: { Vector2 }, -- Ordered path coordinates from spawn to goal
	Enemies: { StageEnemySpawn },
	FirstClearRewards: {
		Diamonds: number,
		Scrolls: number,
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

-- Helper to generate standard 10x8 tile layout with winding path
local function GenerateStandardMap(chokeX: number, chokeY: number): ({ [string]: TileType }, { Vector2 })
	local tiles = {}
	local path = {
		Vector2.new(1, 4),
		Vector2.new(3, 4),
		Vector2.new(3, 2),
		Vector2.new(6, 2),
		Vector2.new(6, 6),
		Vector2.new(8, 6),
		Vector2.new(8, 4),
		Vector2.new(10, 4), -- Base Crystal Goal
	}

	-- Default fill: HighGround on perimeter, Ground inside, Path on waypoints
	for x = 1, 10 do
		for y = 1, 8 do
			local key = x .. "," .. y
			if x == 1 or x == 10 or y == 1 or y == 8 or (x % 3 == 0 and y % 3 == 0) then
				tiles[key] = "HighGround" :: TileType
			else
				tiles[key] = "Ground" :: TileType
			end
		end
	end

	-- Mark path
	for i = 1, #path - 1 do
		local p1 = path[i]
		local p2 = path[i + 1]
		local minX, maxX = math.min(p1.X, p2.X), math.max(p1.X, p2.X)
		local minY, maxY = math.min(p1.Y, p2.Y), math.max(p1.Y, p2.Y)
		for x = minX, maxX do
			for y = minY, maxY do
				tiles[x .. "," .. y] = "Path" :: TileType
			end
		end
	end

	-- Ensure Ground tiles adjacent to choke points for blockers
	tiles[(chokeX or 6) .. "," .. (chokeY or 3)] = "Ground"
	tiles[(chokeX or 6) .. "," .. (chokeY or 5)] = "Ground"
	tiles["7,6"] = "Ground"

	-- Ensure HighGround tiles overlooking choke
	tiles["5,3"] = "HighGround"
	tiles["7,3"] = "HighGround"
	tiles["5,5"] = "HighGround"
	tiles["7,5"] = "HighGround"

	return tiles, path
end

local defaultTiles, defaultPath = GenerateStandardMap(6, 4)

local Stages: { [string]: StageDefinition } = {}

-- Generate Chapter 1 (10 Stages)
for idx = 1, 10 do
	local stageId = "1-" .. tostring(idx)
	local isMiniBoss = (idx == 5)
	local isBoss = (idx == 10)

	local enemyList: { StageEnemySpawn } = {}
	if isBoss then
		table.insert(enemyList, { Archetype = "grunt", Count = 12, Interval = 1.0, Delay = 0 })
		table.insert(enemyList, { Archetype = "runner", Count = 8, Interval = 0.8, Delay = 3 })
		table.insert(enemyList, { Archetype = "tank", Count = 6, Interval = 1.5, Delay = 6 })
		table.insert(enemyList, { Archetype = "boss", Count = 1, Interval = 0, Delay = 12, IsBoss = true, HpMult = 1.5, AtkMult = 1.3 })
	elseif isMiniBoss then
		table.insert(enemyList, { Archetype = "grunt", Count = 10, Interval = 1.2, Delay = 0 })
		table.insert(enemyList, { Archetype = "runner", Count = 6, Interval = 0.9, Delay = 3 })
		table.insert(enemyList, { Archetype = "golem", Count = 2, Interval = 4.0, Delay = 8, IsBoss = true, HpMult = 1.2 })
	else
		local gruntCount = 6 + (idx * 2)
		local runnerCount = math.max(0, (idx - 1) * 2)
		local tankCount = math.max(0, math.floor(idx / 3))

		table.insert(enemyList, { Archetype = "grunt", Count = gruntCount, Interval = 1.2, Delay = 0 })
		if runnerCount > 0 then
			table.insert(enemyList, { Archetype = "runner", Count = runnerCount, Interval = 0.9, Delay = 3 })
		end
		if tankCount > 0 then
			table.insert(enemyList, { Archetype = "tank", Count = tankCount, Interval = 2.0, Delay = 6 })
		end
	end

	Stages[stageId] = {
		Id = stageId,
		Chapter = 1,
		StageIndex = idx,
		Name = isBoss and "Chapter 1 Climax: The Ancient Colossus" or (isMiniBoss and "Stage 1-5: Hobgoblin Stronghold" or ("Stage 1-" .. idx .. ": Outskirts Patrol")),
		IsMiniBoss = isMiniBoss,
		IsBoss = isBoss,
		GridWidth = 10,
		GridHeight = 8,
		Tiles = defaultTiles,
		PathCoords = defaultPath,
		Enemies = enemyList,
		FirstClearRewards = {
			Diamonds = isBoss and 300 or (isMiniBoss and 150 or 50),
			Scrolls = (isBoss or isMiniBoss) and 2 or 1,
			Elixir = 1000 + (idx * 300),
			Gold = 2500 + (idx * 600),
			GuaranteedEquipment = isBoss and "dragon_fang_spear" or (isMiniBoss and "knight_plate" or nil),
		},
		AfkRates = {
			GoldPerMin = 50 + (idx * 14),
			ElixirPerMin = 30 + (idx * 10),
			ExpPerMin = 20 + (idx * 6),
		},
	}
end

local StageData = {
	Stages = Stages,
}

function StageData.Get(stageId: string): StageDefinition?
	return Stages[stageId]
end

function StageData.GetNextStageId(currentStageId: string): string?
	local current = Stages[currentStageId]
	if not current then
		return "1-1"
	end
	local nextIdx = current.StageIndex + 1
	local nextId = current.Chapter .. "-" .. tostring(nextIdx)
	if Stages[nextId] then
		return nextId
	end
	return nil -- End of available content
end

return StageData
