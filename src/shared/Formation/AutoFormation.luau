--!strict

local HeroData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("HeroData"))
local StageData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("StageData"))

export type PlacedSlot = {
	HeroUid: string,
	HeroId: string,
	GridPos: Vector2,
	Role: string,
	PlacementType: string,
}

local AutoFormation = {}

local function ManhattanDist(p1: Vector2, p2: Vector2): number
	return math.abs(p1.X - p2.X) + math.abs(p1.Y - p2.Y)
end

local function EuclideanDist(p1: Vector2, p2: Vector2): number
	local dx = p1.X - p2.X
	local dy = p1.Y - p2.Y
	return math.sqrt(dx * dx + dy * dy)
end

function AutoFormation.Generate(heroes: { any }, stage: StageData.StageDefinition): { PlacedSlot }
	local result: { PlacedSlot } = {}
	local occupiedTiles: { [string]: boolean } = {}

	if #heroes == 0 or not stage then
		return result
	end

	-- 1. Identify Killzone Choke Anchor along path
	local pathCoords = stage.PathCoords
	local anchorIdx = math.clamp(math.floor(#pathCoords * 0.70), 1, #pathCoords)
	local chokeAnchor = pathCoords[anchorIdx] or pathCoords[#pathCoords]

	-- Separate heroes by PlacementType
	local groundHeroes = {}
	local towerDpsHeroes = {}
	local medicHeroes = {}

	for _, hero in ipairs(heroes) do
		local def = HeroData.Get(hero.HeroId)
		if def then
			local entry = {
				Uid = hero.Uid,
				HeroId = hero.HeroId,
				Def = def,
				Level = hero.Level or 1,
				Star = hero.Star or 3,
			}
			if def.PlacementType == "Ground" then
				table.insert(groundHeroes, entry)
			elseif def.Role == "Medic" then
				table.insert(medicHeroes, entry)
			else
				table.insert(towerDpsHeroes, entry)
			end
		end
	end

	-- Sort Ground: Defenders first (block 3), then Guards (block 1-2)
	table.sort(groundHeroes, function(a, b)
		if a.Def.BlockCount ~= b.Def.BlockCount then
			return a.Def.BlockCount > b.Def.BlockCount
		end
		return a.Def.BaseDef > b.Def.BaseDef
	end)

	-- 2. Place Ground Blockers
	local groundCandidates = {}
	for key, tileType in pairs(stage.Tiles) do
		if tileType == "Ground" then
			local parts = key:split(",")
			local pos = Vector2.new(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0)

			-- Check adjacency to path
			local nearPath = false
			for _, wp in ipairs(pathCoords) do
				if ManhattanDist(pos, wp) <= 1 then
					nearPath = true
					break
				end
			end

			if nearPath then
				local distToChoke = EuclideanDist(pos, chokeAnchor)
				table.insert(groundCandidates, { Pos = pos, Score = -distToChoke })
			end
		end
	end

	table.sort(groundCandidates, function(a, b)
		return a.Score > b.Score
	end)

	local placedBlockerPositions: { Vector2 } = {}

	for _, hero in ipairs(groundHeroes) do
		local chosenPos: Vector2? = nil
		for _, cand in ipairs(groundCandidates) do
			local key = cand.Pos.X .. "," .. cand.Pos.Y
			if not occupiedTiles[key] then
				chosenPos = cand.Pos
				occupiedTiles[key] = true
				break
			end
		end

		if chosenPos then
			table.insert(placedBlockerPositions, chosenPos)
			table.insert(result, {
				HeroUid = hero.Uid,
				HeroId = hero.HeroId,
				GridPos = chosenPos,
				Role = hero.Def.Role,
				PlacementType = "Ground",
			})
		end
	end

	-- 3. Place High-Ground DPS (Snipers / Casters / Support)
	local highGroundCandidates = {}
	for key, tileType in pairs(stage.Tiles) do
		if tileType == "HighGround" then
			local parts = key:split(",")
			local pos = Vector2.new(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0)

			-- Score based on coverage of path tiles and overlap with blockers
			local coverageScore = 0
			for _, wp in ipairs(pathCoords) do
				local d = EuclideanDist(pos, wp)
				if d <= 4.0 then
					coverageScore += 1.0
				end
			end

			for _, blockerPos in ipairs(placedBlockerPositions) do
				local d = EuclideanDist(pos, blockerPos)
				if d <= 3.5 then
					coverageScore += 4.0 -- Heavy bonus for covering blocked chokepoint
				end
			end

			table.insert(highGroundCandidates, { Pos = pos, Score = coverageScore })
		end
	end

	table.sort(highGroundCandidates, function(a, b)
		return a.Score > b.Score
	end)

	for _, hero in ipairs(towerDpsHeroes) do
		local chosenPos: Vector2? = nil
		for _, cand in ipairs(highGroundCandidates) do
			local key = cand.Pos.X .. "," .. cand.Pos.Y
			if not occupiedTiles[key] then
				chosenPos = cand.Pos
				occupiedTiles[key] = true
				break
			end
		end

		if chosenPos then
			table.insert(result, {
				HeroUid = hero.Uid,
				HeroId = hero.HeroId,
				GridPos = chosenPos,
				Role = hero.Def.Role,
				PlacementType = "HighGround",
			})
		end
	end

	-- 4. Place Medics (Prioritize maximum blocker coverage)
	local medicCandidates = {}
	for key, tileType in pairs(stage.Tiles) do
		if tileType == "HighGround" and not occupiedTiles[key] then
			local parts = key:split(",")
			local pos = Vector2.new(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0)

			local healScore = 0
			for _, blockerPos in ipairs(placedBlockerPositions) do
				local d = EuclideanDist(pos, blockerPos)
				if d <= 3.2 then
					healScore += 10.0
				end
			end

			table.insert(medicCandidates, { Pos = pos, Score = healScore })
		end
	end

	table.sort(medicCandidates, function(a, b)
		return a.Score > b.Score
	end)

	for _, hero in ipairs(medicHeroes) do
		local chosenPos: Vector2? = nil
		for _, cand in ipairs(medicCandidates) do
			local key = cand.Pos.X .. "," .. cand.Pos.Y
			if not occupiedTiles[key] then
				chosenPos = cand.Pos
				occupiedTiles[key] = true
				break
			end
		end

		if chosenPos then
			table.insert(result, {
				HeroUid = hero.Uid,
				HeroId = hero.HeroId,
				GridPos = chosenPos,
				Role = hero.Def.Role,
				PlacementType = "HighGround",
			})
		end
	end

	return result
end

return AutoFormation
