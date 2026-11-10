--!strict

local HeroData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("HeroData"))
local EquipmentData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("EquipmentData"))
local StageData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("StageData"))
local AutoFormation = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Formation"):WaitForChild("AutoFormation"))

export type SimHero = {
	Uid: string,
	HeroId: string,
	GridPos: Vector2,
	Role: string,
	PlacementType: string,
	Hp: number,
	MaxHp: number,
	Atk: number,
	Def: number,
	Range: number,
	AttackSpeed: number,
	HealingPower: number?,
	BlockCount: number,
	Energy: number,
	CooldownTimer: number,
	BlockedEnemyIds: { string },
	IsDead: boolean,
}

export type SimEnemy = {
	Id: string,
	Archetype: string,
	Hp: number,
	MaxHp: number,
	Atk: number,
	Def: number,
	Speed: number,
	GridPos: Vector2,
	WaypointIdx: number,
	Progress: number,
	BlockedByHeroUid: string?,
	AttackTimer: number,
	IsDead: boolean,
}

export type BattleResult = {
	Success: boolean,
	Stars: number,
	CrystalHp: number,
	MaxCrystalHp: number,
	DurationSeconds: number,
	Events: { any },
}

local BattleSimulation = {}

local function Dist(a: Vector2, b: Vector2): number
	local dx = a.X - b.X
	local dy = a.Y - b.Y
	return math.sqrt(dx * dx + dy * dy)
end

function BattleSimulation.Run(
	stage: StageData.StageDefinition,
	formation: { AutoFormation.PlacedSlot },
	heroInstances: { [string]: any }
): BattleResult
	local crystalHp = 100
	local maxCrystalHp = 100
	local events = {}

	-- 1. Initialize Deployed Heroes
	local heroes: { [string]: SimHero } = {}
	for _, slot in ipairs(formation) do
		local inst = heroInstances[slot.HeroUid]
		local star = inst and inst.Star or 3
		local level = inst and inst.Level or 1
		local baseStats = HeroData.GetStats(slot.HeroId, level, star)
		if baseStats then
			-- Calculate gear bonuses
			local bonusAtk = 0
			local bonusHp = 0
			local bonusDef = 0
			if inst and inst.Equipment then
				for _, eqId in pairs(inst.Equipment) do
					local eqDef = EquipmentData.Get(eqId)
					if eqDef and eqDef.BaseStats then
						bonusAtk += eqDef.BaseStats.Atk or 0
						bonusHp += eqDef.BaseStats.Hp or 0
						bonusDef += eqDef.BaseStats.Def or 0
					end
				end
			end

			local finalHp = baseStats.Hp + bonusHp
			heroes[slot.HeroUid] = {
				Uid = slot.HeroUid,
				HeroId = slot.HeroId,
				GridPos = slot.GridPos,
				Role = slot.Role,
				PlacementType = slot.PlacementType,
				Hp = finalHp,
				MaxHp = finalHp,
				Atk = baseStats.Atk + bonusAtk,
				Def = baseStats.Def + bonusDef,
				Range = baseStats.Range,
				AttackSpeed = baseStats.AttackSpeed,
				HealingPower = baseStats.HealingPower and (baseStats.HealingPower + math.floor(bonusAtk * 0.5)) or nil,
				BlockCount = baseStats.BlockCount,
				Energy = 0,
				CooldownTimer = 0,
				BlockedEnemyIds = {},
				IsDead = false,
			}
		end
	end

	-- 2. Build Enemy Spawn Timeline
	local spawnQueue = {}
	local currentDelay = 0
	for _, group in ipairs(stage.Enemies) do
		currentDelay += group.Delay
		local hp = 100 * (group.HpMult or 1.0)
		local atk = 25 * (group.AtkMult or 1.0)
		local speed = 1.2
		if group.Archetype == "runner" then
			hp = 65
			speed = 2.0
		elseif group.Archetype == "tank" then
			hp = 350
			speed = 0.8
			atk = 45
		elseif group.Archetype == "boss" then
			hp = 1400
			speed = 0.7
			atk = 90
		elseif group.Archetype == "golem" then
			hp = 650
			speed = 0.75
			atk = 60
		end

		for i = 1, group.Count do
			table.insert(spawnQueue, {
				SpawnTick = math.floor((currentDelay + ((i - 1) * group.Interval)) * 10),
				Archetype = group.Archetype,
				Hp = hp,
				MaxHp = hp,
				Atk = atk,
				Speed = speed,
				IsBoss = group.IsBoss or false,
			})
		end
	end

	local activeEnemies: { [string]: SimEnemy } = {}
	local path = stage.PathCoords
	local startPos = path[1] or Vector2.new(1, 1)

	local tickCount = 0
	local maxTicks = 1200 -- 120 seconds max
	local enemyCounter = 0

	-- 3. Deterministic 10 Hz Simulation Loop
	while tickCount < maxTicks do
		tickCount += 1
		local dt = 0.1

		-- A. Spawn Enemies
		for i = #spawnQueue, 1, -1 do
			local s = spawnQueue[i]
			if s.SpawnTick <= tickCount then
				enemyCounter += 1
				local enemyId = "e_" .. tostring(enemyCounter)
				activeEnemies[enemyId] = {
					Id = enemyId,
					Archetype = s.Archetype,
					Hp = s.Hp,
					MaxHp = s.Hp,
					Atk = s.Atk,
					Def = 10,
					Speed = s.Speed,
					GridPos = startPos,
					WaypointIdx = 2,
					Progress = 0,
					BlockedByHeroUid = nil,
					AttackTimer = 0,
					IsDead = false,
				}
				table.remove(spawnQueue, i)
			end
		end

		-- B. Process Enemy Movement and Blocking
		for enemyId, enemy in pairs(activeEnemies) do
			if enemy.IsDead then
				continue
			end

			-- Check if blocked
			if enemy.BlockedByHeroUid then
				local blocker = heroes[enemy.BlockedByHeroUid]
				if not blocker or blocker.IsDead then
					enemy.BlockedByHeroUid = nil
				else
					-- Attack blocker
					enemy.AttackTimer += dt
					if enemy.AttackTimer >= 1.2 then
						enemy.AttackTimer = 0
						local dmg = math.max(5, enemy.Atk - (blocker.Def * 0.4))
						blocker.Hp = math.max(0, blocker.Hp - dmg)
						blocker.Energy = math.min(100, blocker.Energy + 8)

						if blocker.Hp <= 0 then
							blocker.IsDead = true
							enemy.BlockedByHeroUid = nil
						end
					end
				end
			else
				-- Move along waypoints
				local targetWp = path[enemy.WaypointIdx]
				if targetWp then
					local dir = targetWp - enemy.GridPos
					local dist = dir.Magnitude
					local step = enemy.Speed * dt

					if dist <= step then
						enemy.GridPos = targetWp
						enemy.WaypointIdx += 1
						if enemy.WaypointIdx > #path then
							-- Leaked to crystal!
							local leakDamage = enemy.Archetype == "boss" and 25 or 5
							crystalHp = math.max(0, crystalHp - leakDamage)
							enemy.IsDead = true
							activeEnemies[enemyId] = nil
							continue
						end
					else
						enemy.GridPos += (dir.Unit * step)
						enemy.Progress += step
					end

					-- Check for adjacent Ground blocker to block enemy
					for heroUid, hero in pairs(heroes) do
						if hero.PlacementType == "Ground" and not hero.IsDead and #hero.BlockedEnemyIds < hero.BlockCount then
							if Dist(hero.GridPos, enemy.GridPos) <= 0.85 then
								enemy.BlockedByHeroUid = heroUid
								table.insert(hero.BlockedEnemyIds, enemyId)
								break
							end
						end
					end
				else
					enemy.IsDead = true
					activeEnemies[enemyId] = nil
				end
			end
		end

		-- C. Process Heroes (Actions, Healing, Skills)
		for heroUid, hero in pairs(heroes) do
			if hero.IsDead then
				continue
			end

			hero.CooldownTimer += dt
			local attackInterval = 1.0 / math.max(0.2, hero.AttackSpeed)

			if hero.Role == "Medic" then
				-- Medic heals lowest HP% ally in range
				if hero.CooldownTimer >= attackInterval then
					hero.CooldownTimer = 0
					local lowestAlly: SimHero? = nil
					local lowestPct = 1.0

					for _, ally in pairs(heroes) do
						if not ally.IsDead and ally.Hp < ally.MaxHp then
							if Dist(hero.GridPos, ally.GridPos) <= hero.Range then
								local pct = ally.Hp / ally.MaxHp
								if pct < lowestPct then
									lowestPct = pct
									lowestAlly = ally
								end
							end
						end
					end

					if lowestAlly then
						local healAmount = hero.HealingPower or 100
						if hero.Energy >= 100 then
							-- Trigger Ultimate Sanctuary!
							healAmount *= 2.5
							hero.Energy = 0
						else
							hero.Energy = math.min(100, hero.Energy + 15)
						end
						lowestAlly.Hp = math.min(lowestAlly.MaxHp, lowestAlly.Hp + healAmount)
					end
				end
			else
				-- Combatant attacks enemies in range
				if hero.CooldownTimer >= attackInterval then
					hero.CooldownTimer = 0

					-- Find enemy in range
					local target: SimEnemy? = nil
					local highestProg = -1

					for _, enemy in pairs(activeEnemies) do
						if not enemy.IsDead and Dist(hero.GridPos, enemy.GridPos) <= hero.Range then
							if enemy.Progress > highestProg then
								highestProg = enemy.Progress
								target = enemy
							end
						end
					end

					if target then
						local dmg = math.max(10, hero.Atk - (target.Def * 0.3))
						if hero.Energy >= 100 then
							-- Trigger Ultimate!
							dmg *= 2.8
							hero.Energy = 0
						else
							hero.Energy = math.min(100, hero.Energy + 12)
						end

						target.Hp = math.max(0, target.Hp - dmg)
						if target.Hp <= 0 then
							target.IsDead = true
							activeEnemies[target.Id] = nil
							-- Remove from blocker's list
							for i = #hero.BlockedEnemyIds, 1, -1 do
								if hero.BlockedEnemyIds[i] == target.Id then
									table.remove(hero.BlockedEnemyIds, i)
								end
							end
						end
					end
				end
			end
		end

		-- D. Check Termination Conditions
		if crystalHp <= 0 then
			break
		end

		local remainingEnemies = 0
		for _ in pairs(activeEnemies) do
			remainingEnemies += 1
		end
		if #spawnQueue == 0 and remainingEnemies == 0 then
			break
		end
	end

	local success = crystalHp > 0
	local stars = 0
	if success then
		if crystalHp == maxCrystalHp then
			stars = 3
		elseif crystalHp >= 50 then
			stars = 2
		else
			stars = 1
		end
	end

	return {
		Success = success,
		Stars = stars,
		CrystalHp = crystalHp,
		MaxCrystalHp = maxCrystalHp,
		DurationSeconds = tickCount / 10,
		Events = events,
	}
end

return BattleSimulation
