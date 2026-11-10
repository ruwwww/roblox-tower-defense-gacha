--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroData = require(Shared:WaitForChild("Data"):WaitForChild("HeroData"))
local EquipmentData = require(Shared:WaitForChild("Data"):WaitForChild("EquipmentData"))
local StageData = require(Shared:WaitForChild("Data"):WaitForChild("StageData"))
local AutoFormation = require(Shared:WaitForChild("Formation"):WaitForChild("AutoFormation"))

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
	IsBoss: boolean,
}

export type ActionEvent = {
	Type: string,
	[string]: any,
}

export type BattleResult = {
	Success: boolean,
	Stars: number,
	CrystalHp: number,
	MaxCrystalHp: number,
	DurationSeconds: number,
	Events: { ActionEvent },
}

export type BattleSession = {
	Tick: number,
	MaxTicks: number,
	CrystalHp: number,
	MaxCrystalHp: number,
	Heroes: { [string]: SimHero },
	ActiveEnemies: { [string]: SimEnemy },
	SpawnQueue: { any },
	Path: { Vector2 },
	EnemyCounter: number,
	AllEvents: { ActionEvent },
	Step: (self: BattleSession, dt: number) -> { ActionEvent },
	IsFinished: (self: BattleSession) -> boolean,
	GetResult: (self: BattleSession) -> BattleResult,
}

local BattleSimulation = {}

local function Dist(a: Vector2, b: Vector2): number
	local dx = a.X - b.X
	local dy = a.Y - b.Y
	return math.sqrt(dx * dx + dy * dy)
end

function BattleSimulation.CreateSession(
	stage: StageData.StageDefinition,
	formation: { AutoFormation.PlacedSlot },
	heroInstances: { [string]: any }
): BattleSession
	local crystalHp = 100
	local maxCrystalHp = 100

	-- 1. Initialize Deployed Heroes
	local heroes: { [string]: SimHero } = {}
	if formation then
		for _, slot in ipairs(formation) do
			local inst = heroInstances[slot.HeroUid]
			local star = inst and inst.Star or 3
			local level = inst and inst.Level or 1
			local baseStats = HeroData.GetStats(slot.HeroId, level, star)
			if baseStats then
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
				local gx = (slot.GridPos and slot.GridPos.X) or 5
				local gy = (slot.GridPos and slot.GridPos.Y) or 4

				heroes[slot.HeroUid] = {
					Uid = slot.HeroUid,
					HeroId = slot.HeroId,
					GridPos = Vector2.new(gx, gy),
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
	end

	-- 2. Build Enemy Spawn Timeline
	local spawnQueue = {}
	local currentDelay = 0
	if stage and stage.Enemies then
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
	end

	local path = (stage and stage.PathCoords and #stage.PathCoords > 0) and stage.PathCoords or {
		Vector2.new(1, 4),
		Vector2.new(3, 4),
		Vector2.new(3, 2),
		Vector2.new(6, 2),
		Vector2.new(6, 6),
		Vector2.new(8, 6),
		Vector2.new(8, 4),
		Vector2.new(10, 4),
	}

	local session: BattleSession
	session = {
		Tick = 0,
		MaxTicks = 1200, -- 120 seconds max
		CrystalHp = crystalHp,
		MaxCrystalHp = maxCrystalHp,
		Heroes = heroes,
		ActiveEnemies = {},
		SpawnQueue = spawnQueue,
		Path = path,
		EnemyCounter = 0,
		AllEvents = {},

		Step = function(self: BattleSession, dt: number): { ActionEvent }
			self.Tick += 1
			local stepEvents: { ActionEvent } = {}

			-- A. Spawn Enemies
			for i = #self.SpawnQueue, 1, -1 do
				local s = self.SpawnQueue[i]
				if s.SpawnTick <= self.Tick then
					self.EnemyCounter += 1
					local enemyId = "e_" .. tostring(self.EnemyCounter)
					local startPos = self.Path[1] or Vector2.new(1, 4)

					local simEnemy: SimEnemy = {
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
						IsBoss = s.IsBoss,
					}
					self.ActiveEnemies[enemyId] = simEnemy
					table.remove(self.SpawnQueue, i)

					local ev: ActionEvent = {
						Type = "EnemySpawned",
						EnemyId = enemyId,
						Archetype = s.Archetype,
						Hp = s.Hp,
						MaxHp = s.Hp,
						Atk = s.Atk,
						Speed = s.Speed,
						IsBoss = s.IsBoss,
						GridPos = startPos,
					}
					table.insert(stepEvents, ev)
					table.insert(self.AllEvents, ev)
				end
			end

			-- B. Process Enemy Movement and Blocking
			for enemyId, enemy in pairs(self.ActiveEnemies) do
				if enemy.IsDead then continue end

				if enemy.BlockedByHeroUid then
					local blocker = self.Heroes[enemy.BlockedByHeroUid]
					if not blocker or blocker.IsDead then
						enemy.BlockedByHeroUid = nil
						local unblockEv: ActionEvent = {
							Type = "EnemyUnblocked",
							EnemyId = enemyId,
						}
						table.insert(stepEvents, unblockEv)
						table.insert(self.AllEvents, unblockEv)
					else
						-- Attack blocker
						enemy.AttackTimer += dt
						if enemy.AttackTimer >= 1.2 then
							enemy.AttackTimer = 0
							local dmg = math.max(5, enemy.Atk - (blocker.Def * 0.4))
							blocker.Hp = math.max(0, blocker.Hp - dmg)
							blocker.Energy = math.min(100, blocker.Energy + 8)

							local atkEv: ActionEvent = {
								Type = "EnemyAttackedBlocker",
								EnemyId = enemyId,
								BlockerUid = enemy.BlockedByHeroUid,
								Damage = dmg,
								BlockerRemainingHp = blocker.Hp,
								BlockerMaxHp = blocker.MaxHp,
							}
							table.insert(stepEvents, atkEv)
							table.insert(self.AllEvents, atkEv)

							if blocker.Hp <= 0 then
								blocker.IsDead = true
								enemy.BlockedByHeroUid = nil

								local heroDieEv: ActionEvent = {
									Type = "HeroDied",
									HeroUid = blocker.Uid,
								}
								table.insert(stepEvents, heroDieEv)
								table.insert(self.AllEvents, heroDieEv)
							end
						end
					end
				else
					-- Move along waypoints
					local targetWp = self.Path[enemy.WaypointIdx]
					if targetWp then
						local dir = targetWp - enemy.GridPos
						local dist = dir.Magnitude
						local step = enemy.Speed * dt

						if dist <= step then
							enemy.GridPos = targetWp
							enemy.WaypointIdx += 1
							if enemy.WaypointIdx > #self.Path then
								-- Leaked to crystal!
								local leakDamage = (enemy.Archetype == "boss") and 25 or 5
								self.CrystalHp = math.max(0, self.CrystalHp - leakDamage)
								enemy.IsDead = true
								self.ActiveEnemies[enemyId] = nil

								local leakEv: ActionEvent = {
									Type = "CrystalDamaged",
									EnemyId = enemyId,
									LeakDamage = leakDamage,
									CurrentCrystalHp = self.CrystalHp,
									MaxCrystalHp = self.MaxCrystalHp,
								}
								table.insert(stepEvents, leakEv)
								table.insert(self.AllEvents, leakEv)
								continue
							end
						else
							enemy.GridPos += (dir.Unit * step)
							enemy.Progress += step
						end

						local moveEv: ActionEvent = {
							Type = "EnemyMoved",
							EnemyId = enemyId,
							GridPos = enemy.GridPos,
							Progress = enemy.Progress,
						}
						table.insert(stepEvents, moveEv)

						-- Check for adjacent Ground blocker to block enemy
						for heroUid, hero in pairs(self.Heroes) do
							if hero.PlacementType == "Ground" and not hero.IsDead and #hero.BlockedEnemyIds < hero.BlockCount then
								if Dist(hero.GridPos, enemy.GridPos) <= 0.85 then
									enemy.BlockedByHeroUid = heroUid
									table.insert(hero.BlockedEnemyIds, enemyId)

									local blockEv: ActionEvent = {
										Type = "EnemyBlocked",
										EnemyId = enemyId,
										BlockerUid = heroUid,
										BlockerGridPos = hero.GridPos,
									}
									table.insert(stepEvents, blockEv)
									table.insert(self.AllEvents, blockEv)
									break
								end
							end
						end
					else
						enemy.IsDead = true
						self.ActiveEnemies[enemyId] = nil
					end
				end
			end

			-- C. Process Heroes (Actions, Healing, Skills)
			for heroUid, hero in pairs(self.Heroes) do
				if hero.IsDead then continue end

				hero.CooldownTimer += dt
				local attackInterval = 1.0 / math.max(0.2, hero.AttackSpeed)

				if hero.Role == "Medic" then
					if hero.CooldownTimer >= attackInterval then
						hero.CooldownTimer = 0
						local lowestAlly: SimHero? = nil
						local lowestPct = 1.0

						for _, ally in pairs(self.Heroes) do
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
							local isUltimate = false
							if hero.Energy >= 100 then
								healAmount *= 2.5
								hero.Energy = 0
								isUltimate = true
							else
								hero.Energy = math.min(100, hero.Energy + 15)
							end
							lowestAlly.Hp = math.min(lowestAlly.MaxHp, lowestAlly.Hp + healAmount)

							local healEv: ActionEvent = {
								Type = "MedicHealedHero",
								MedicUid = heroUid,
								TargetUid = lowestAlly.Uid,
								Amount = healAmount,
								IsUltimate = isUltimate,
								TargetRemainingHp = lowestAlly.Hp,
								TargetMaxHp = lowestAlly.MaxHp,
							}
							table.insert(stepEvents, healEv)
							table.insert(self.AllEvents, healEv)
						end
					end
				else
					if hero.CooldownTimer >= attackInterval then
						hero.CooldownTimer = 0
						local target: SimEnemy? = nil
						local highestProg = -1

						for _, enemy in pairs(self.ActiveEnemies) do
							if not enemy.IsDead and Dist(hero.GridPos, enemy.GridPos) <= hero.Range then
								if enemy.Progress > highestProg then
									highestProg = enemy.Progress
									target = enemy
								end
							end
						end

						if target then
							local dmg = math.max(10, hero.Atk - (target.Def * 0.3))
							local isUltimate = false
							if hero.Energy >= 100 then
								dmg *= 2.8
								hero.Energy = 0
								isUltimate = true
							else
								hero.Energy = math.min(100, hero.Energy + 12)
							end

							target.Hp = math.max(0, target.Hp - dmg)

							local heroAtkEv: ActionEvent = {
								Type = "HeroAttackedEnemy",
								HeroUid = heroUid,
								EnemyId = target.Id,
								Damage = dmg,
								IsUltimate = isUltimate,
								EnemyRemainingHp = target.Hp,
								EnemyMaxHp = target.MaxHp,
							}
							table.insert(stepEvents, heroAtkEv)
							table.insert(self.AllEvents, heroAtkEv)

							if target.Hp <= 0 then
								target.IsDead = true
								self.ActiveEnemies[target.Id] = nil

								local enemyDieEv: ActionEvent = {
									Type = "EnemyDied",
									EnemyId = target.Id,
								}
								table.insert(stepEvents, enemyDieEv)
								table.insert(self.AllEvents, enemyDieEv)

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

			return stepEvents
		end,

		IsFinished = function(self: BattleSession): boolean
			if self.CrystalHp <= 0 then return true end
			if self.Tick >= self.MaxTicks then return true end

			local activeCount = 0
			for _ in pairs(self.ActiveEnemies) do
				activeCount += 1
			end
			return (#self.SpawnQueue == 0 and activeCount == 0)
		end,

		GetResult = function(self: BattleSession): BattleResult
			local success = self.CrystalHp > 0
			local stars = 0
			if success then
				if self.CrystalHp >= self.MaxCrystalHp then
					stars = 3
				elseif self.CrystalHp >= 50 then
					stars = 2
				else
					stars = 1
				end
			end

			return {
				Success = success,
				Stars = stars,
				CrystalHp = self.CrystalHp,
				MaxCrystalHp = self.MaxCrystalHp,
				DurationSeconds = self.Tick / 10,
				Events = self.AllEvents,
			}
		end,
	}

	return session
end

function BattleSimulation.Run(
	stage: StageData.StageDefinition,
	formation: { AutoFormation.PlacedSlot },
	heroInstances: { [string]: any }
): BattleResult
	local session = BattleSimulation.CreateSession(stage, formation, heroInstances)
	while not session:IsFinished() do
		session:Step(0.1)
	end
	return session:GetResult()
end

return BattleSimulation
