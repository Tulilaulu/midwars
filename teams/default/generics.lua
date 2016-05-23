local _G = getfenv(0)
local object = _G.object

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
  = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
  = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog

object.generics = {}
local generics = object.generics

BotEcho("loading default generics ..")

local oncombateventOld = object.oncombatevent
local function oncombateventCustom(botBrain, EventData)
  oncombateventOld(botBrain, EventData)
  local source = EventData.SourceUnit
  local target = EventData.TargetUnit
  local teamBotBrain = core.teamBotBrain
  local unitSelf = core.unitSelf
  if teamBotBrain and teamBotBrain.SetTeamTarget then
    if source and source:IsHero() and source:IsAlive() and source:GetTeam() == core.enemyTeam and unitSelf and unitSelf:GetPosition() and source:GetPosition() and Vector3.Distance2D(unitSelf:GetPosition(), source:GetPosition()) < 500 then
      teamBotBrain:SetTeamTarget(source)
    end
    if target and target:IsHero() and target:IsAlive() and target:GetTeam() == core.enemyTeam and unitSelf and unitSelf:GetPosition() and target:GetPosition() and Vector3.Distance2D(unitSelf:GetPosition(), target:GetPosition()) < 500 then
      teamBotBrain:SetTeamTarget(target)
    end
  end
end
-- override combat event trigger function.

object.oncombatevent = oncombateventCustom

behaviorLib.nPathEnemyTowerMul = 100

local function PassiveState()
  local tLane = core.tMyLane
  if tLane then
    local creepPos = core.GetFurthestCreepWavePos(tLane, core.bTraverseForward)
    local enemyBasePos = core.enemyMainBaseStructure:GetPosition()
    local myTower = core.GetClosestAllyTower(enemyBasePos)
    local towerPos = myTower:GetPosition()
    local enemyTower = core.GetClosestEnemyTower(towerPos)
    local otherTowerPos = enemyTower:GetPosition()
    local distanceAlly = Vector3.Distance2D(creepPos, towerPos)
    local distanceEnemy = Vector3.Distance2D(creepPos, otherTowerPos)
    --BotEcho("DA:"..distanceAlly..";DE:"..distanceEnemy)
    if (distanceAlly < distanceEnemy and distanceEnemy < 2500) or (distanceAlly > distanceEnemy and distanceAlly < 2500) then
      return true
    end
  end
  return false
end

function generics.IsFreeLine(pos1, pos2, ignoreAllies)
  local tAllies = core.CopyTable(core.localUnits["AllyUnits"])
  local tEnemies = core.CopyTable(core.localUnits["EnemyCreeps"])
  local distanceLine = Vector3.Distance2DSq(pos1, pos2)
  local x1, x2, y1, y2 = pos1.x, pos2.x, pos1.y, pos2.y
  local spaceBetween = 50 * 50
  if not ignoreAllies then
    for _, ally in pairs(tAllies) do
      local posAlly = ally:GetPosition()
      local x3, y3 = posAlly.x, posAlly.y
      local calc = x1*y2 - x2*y1 + x2*y3 - x3*y2 + x3*y1 - x1*y3
      local calc2 = calc * calc
      local actual = calc2 / distanceLine
      if actual < spaceBetween then
        return false
      end
    end
  end
  for _, creep in pairs(tEnemies) do
    local posCreep = creep:GetPosition()
    local x3, y3 = posCreep.x, posCreep.y
    local calc = x1*y2 - x2*y1 + x2*y3 - x3*y2 + x3*y1 - x1*y3
    local calc2 = calc * calc
    local actual = calc2 / distanceLine
    if actual < spaceBetween then
      return false
    end
  end
  return true
end

function generics.CustomHarassUtility(target)
  local nUtil = 0
  local creepLane = core.GetFurthestCreepWavePos(core.tMyLane, core.bTraverseForward)
  local unitSelf = core.unitSelf
  local myPos = unitSelf:GetPosition()

  nUtil = nUtil - (1 - unitSelf:GetHealthPercent()) * 100

  if unitSelf:GetHealth() > target:GetHealth() then
     nUtil = nUtil + 10
  end

  if target:IsChanneling() or target:IsDisarmed() or target:IsImmobilized() or target:IsPerplexed() or target:IsSilenced() or target:IsStunned() or unitSelf:IsStealth() then
    nUtil = nUtil + 50
  end

  local unitsNearby = core.AssessLocalUnits(object, myPos,100)


  if core.NumberElements(unitsNearby.AllyHeroes) == 0 then

    if core.GetClosestEnemyTower(myPos, 720) then
      nUtil = nUtil - 100
    end

    for id, creep in pairs(unitsNearby.EnemyCreeps) do
      local creepPos = creep:GetPosition()
      if(creep:GetAttackType() == "ranged" or Vector3.Distance2D(myPos, creepPos) < 20) then
        nUtil = nUtil - 20
      end
    end
  end

  return nUtil
end


local function PositionSelfExecuteFix(botBrain)
	local nCurrentTimeMS = HoN.GetGameTime()
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()

	if core.unitSelf:IsChanneling() then
		return
	end

	local vecDesiredPos = vecMyPosition
	local unitTarget = nil
	vecDesiredPos, unitTarget = behaviorLib.PositionSelfLogic(botBrain)

	if vecDesiredPos then
		behaviorLib.MoveExecute(botBrain, vecDesiredPos)
	else
		BotEcho("PositionSelfExecute - nil desired position")
		return false
	end

end
behaviorLib.PositionSelfBehavior["Execute"] = PositionSelfExecuteFix

local function PushExecuteFix(botBrain)
	if core.unitSelf:IsChanneling() then
		return
	end

	local unitSelf = core.unitSelf
	local bActionTaken = false

	--Attack creeps if we're in range
	if bActionTaken == false then
		local unitTarget = core.unitEnemyCreepTarget
		if unitTarget then
			local nRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
			if unitSelf:GetAttackType() == "melee" then
				--override melee so they don't stand *just* out of range
				nRange = 250
			end

			if unitSelf:IsAttackReady() and core.IsUnitInRange(unitSelf, unitTarget, nRange) then
				bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitTarget)
			end

		end
	end

	if bActionTaken == false then
		local vecDesiredPos = behaviorLib.PositionSelfLogic(botBrain)
		if vecDesiredPos then
			bActionTaken = behaviorLib.MoveExecute(botBrain, vecDesiredPos)

		end
	end

	if bActionTaken == false then
		return false
	end
end
behaviorLib.PushBehavior["Execute"] = PushExecuteFix


local HarassHeroUtilityOld = behaviorLib.HarassHeroBehavior["Utility"]
local function TeamHarassHeroUtility(botBrain)
  local teamBotBrain = core.teamBotBrain
  if teamBotBrain.GetTeamTarget then
    local target = teamBotBrain:GetTeamTarget()
    if target then
      local util = 40
      util = util + behaviorLib.CustomHarassUtility(target)
      behaviorLib.lastHarassUtil = util
      behaviorLib.heroTarget = target
      return util
    end
  end
  if PassiveState() then
    return 0
  end
  return HarassHeroUtilityOld(botBrain)
end
behaviorLib.HarassHeroBehavior["Utility"] = TeamHarassHeroUtility

local ProcessKillOld = behaviorLib.ProcessKill
local function ProcessKillOverride(unit)
  ProcessKillOld(unit)
  local teamBotBrain = core.teamBotBrain
  if teamBotBrain.GetTeamTarget then
    teamBotBrain:SetTeamTarget(nil)
  end
end
behaviorLib.ProcessKill = ProcessKillOverride

local function FurthestPositionEarlyAdjust(position)
  if PassiveState() then
    local enemyBasePos = core.enemyMainBaseStructure:GetPosition()
    local myTower = core.GetClosestAllyTower(enemyBasePos)
    local towerPos = myTower:GetPosition()
    local offset = Vector3.Normalize(enemyBasePos - towerPos) * 1000
    local middlePos = towerPos + offset
    local vector = middlePos - towerPos
    local pos1 = towerPos + core.RotateVec2D(vector, -45)
    local pos2 = towerPos + core.RotateVec2D(vector, 45)
    local wantedVec = pos1 - pos2
    local wantedPos = pos2 + wantedVec * core.RandomReal()
    return wantedPos
  end
  return position
end

local PositionSelfLogicOld = behaviorLib.PositionSelfLogic
local function PositionSelfLogicOverride(botBrain)
  return FurthestPositionEarlyAdjust(PositionSelfLogicOld(botBrain))
end
behaviorLib.PositionSelfLogic = PositionSelfLogicOverride


local ReturnToPoolOld = behaviorLib.HealAtWellBehavior["Utility"]
local function ReturnToPool(botBrain)
  if core.unitSelf:GetHealthPercent() < 20 then
    return ReturnToPoolOld(botBrain)
  end
  return 0
end
behaviorLib.HealAtWellBehavior["Utility"] = ReturnToPool

BotEcho("default generics done.")
