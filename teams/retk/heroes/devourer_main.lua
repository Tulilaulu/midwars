local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic = true
object.bRunBehaviors = true
object.bUpdates = true
object.bUseShop = true

object.bRunCommands = true
object.bMoveCommands = true
object.bAttackCommands = true
object.bAbilityCommands = true
object.bOtherCommands = true

object.bReportBehavior = true
object.bDebugUtility = false
object.bDebugExecute = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core = {}
object.eventsLib = {}
object.metadata = {}
object.behaviorLib = {}
object.skills = {}

runfile "bots/teams/retk/core.lua"
runfile "bots/teams/retk/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/teams/retk/behaviorLib.lua"
runfile "bots/teams/retk/utils.lua"
runfile "bots/teams/retk/courier.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
  = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
  = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading devourer_main...')

object.heroName = 'Hero_Devourer'

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 0, LongSolo = 0, ShortSupport = 0, LongSupport = 0, ShortCarry = 0, LongCarry = 0}

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
  local unitSelf = self.core.unitSelf

  if not bSkillsValid then
    skills.hook = unitSelf:GetAbility(0)
    skills.rot = unitSelf:GetAbility(1)
    skills.skin = unitSelf:GetAbility(2)
    skills.ulti = unitSelf:GetAbility(3)
    skills.attributeBoost = unitSelf:GetAbility(4)
    skills.taunt = unitSelf:GetAbility(8)
    skills.courier = unitSelf:GetAbility(12)

    if skills.hook and skills.rot and skills.skin and skills.ulti and skills.attributeBoost then
      bSkillsValid = true
    else
      return
    end
  end

  if unitSelf:GetAbilityPointsAvailable() <= 0 then
    return
  end

  if skills.ulti:CanLevelUp() then
    skills.ulti:LevelUp()
  elseif skills.hook:CanLevelUp() then
    skills.hook:LevelUp()
  elseif skills.rot:CanLevelUp() then
    skills.rot:LevelUp()
  elseif skills.skin:CanLevelUp() then
    skills.skin:LevelUp()
  else
    skills.attributeBoost:LevelUp()
  end
end

behaviorLib.StartingItems = {"Item_MerricksBounty", "Item_LoggersHatchet", "2 Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_Steamboots", "Item_MysticVestments"}
behaviorLib.MidItems = {"Item_PortalKey", "Item_Excruciator", "Item_HealthMana2", "Item_MagicArmor2"}
behaviorLib.LateItems = {"Item_BehemothsHeart", "Item_BarrierIdol"}

behaviorLib.healAtWellHealthFactor = 1.3
behaviorLib.healAtWellProximityFactor = 0.5

behaviorLib.debugHarassUtility = true
behaviorLib.debugHarassExecute = false


local function creepsInWay(unitTarget, drawLines)
    local selfPos = core.unitSelf:GetPosition()
    local targetPos = unitTarget:GetPosition()
    local diff = Vector3.Distance(targetPos, selfPos)

    if drawLines then drawLine(selfPos, targetPos, "red") end

    local ok = true
    for i, creep in pairs(core.localUnits["EnemyCreeps"]) do
        local name = creep:GetTypeName()
        local creepPos = creep:GetPosition()
        local d = Vector3.Length(Vector3.Cross(creepPos - selfPos, creepPos - targetPos)) / diff
        local color
        -- p(d)
        if d > 120 or (name == "Creep_LegionSiege" or name == "Creep_HellbourneSiege") then
            color = "green"
        else
            color ="red"
            ok = false
        end
        if drawLines then drawCross(creep:GetPosition(), color) end
    end

    for i, creep in pairs(core.localUnits["AllyCreeps"]) do
        local name = creep:GetTypeName()
        local creepPos = creep:GetPosition()
        local d = Vector3.Length(Vector3.Cross(creepPos - selfPos, creepPos - targetPos)) / diff
        local color
        -- p(d)
        if d > 120 or (name == "Creep_LegionSiege" or name == "Creep_HellbourneSiege") then
            color = "green"
        else
            color ="red"
            ok = false
        end
        if drawLines then drawCross(creep:GetPosition(), color) end
    end

    if ok then
        if drawLines then drawCross(targetPos, "green") end
    else
        if drawLines then drawCross(targetPos, "red") end
    end
    return not ok
end

------------------------------------------------------
--            onthink override                      --
-- Called every bot tick, custom onthink code here  --
------------------------------------------------------
-- @param: tGameVariables
-- @return: none
function object:onthinkOverride(tGameVariables)
  self:onthinkOld(tGameVariables)

  -- custom code here
end
object.onthinkOld = object.onthink
object.onthink = object.onthinkOverride

----------------------------------------------
--            oncombatevent override        --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
-- @param: eventdata
-- @return: none
function object:oncombateventOverride(EventData)
  self:oncombateventOld(EventData)

  -- custom code here
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride


-- Harass
local function CustomHarassUtilityOverride(target)
    if object:IsPoolDiving() then
        return -500
    end
    return 0
    -- local nUtility = 0

    -- if skills.hook:CanActivate() then
    --     nUtility = nUtility + 10
    -- end

    -- if skills.ulti:CanActivate() then
    --     nUtility = nUtility + 40
    -- end

    -- return behaviorLib.CustomHarassUtility(target) + nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride

local itemPK = nil
local itemBarbed = nil
local FindItemsOld = core.FindItems
local function FindItemsFn(botBrain)
  FindItemsOld(botBrain)
  if itemPK and itemBarbed then
    return
  end
  local unitSelf = core.unitSelf
  local inventory = unitSelf:GetInventory(false)
  if inventory ~= nil then
    for slot = 1, 6, 1 do
      local curItem = inventory[slot]
      if curItem and not curItem:IsRecipe() then
        if not itemPK and curItem:GetName() == "Item_PortalKey" then
          itemPK = core.WrapInTable(curItem)
        end
        if not itemBarbed and curItem:GetName() == "Item_Excruciator" then
          itemBarbed = core.WrapInTable(curItem)
        end
      end
    end
  end
end
core.FindItems = FindItemsFn

local function HarassHeroExecuteOverride(botBrain)
  local unitTarget = behaviorLib.heroTarget
  if unitTarget == nil or not unitTarget:IsValid() then
    return false --can not execute, move on to the next behavior
  end

  local unitSelf = core.unitSelf

  if unitSelf:IsChanneling() then
    return
  end

  local bActionTaken = false

  --since we are using an old pointer, ensure we can still see the target for entity targeting
  if core.CanSeeUnit(botBrain, unitTarget) then
    local dist = Vector3.Distance2D(unitSelf:GetPosition(), unitTarget:GetPosition())
    local attkRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget);

    local itemGhostMarchers = core.itemGhostMarchers

    local ulti = skills.ulti
    local ultiRange = ulti and (ulti:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(unitTarget)) or 0

    local bUseUlti = true

    if ulti and ulti:CanActivate() and bUseUlti and dist < ultiRange then
      bActionTaken = core.OrderAbilityEntity(botBrain, ulti, unitTarget)
    elseif (ulti and ulti:CanActivate() and bUseUlti and dist > ultiRange) then
      --move in when we want to ult
      local desiredPos = unitTarget:GetPosition()

      if itemPK and itemPK:CanActivate() then
        bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPK, desiredPos)
      end

      if not bActionTaken and itemGhostMarchers and itemGhostMarchers:CanActivate() then
        bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
      end

      if not bActionTaken and behaviorLib.lastHarassUtil < behaviorLib.diveThreshold then
        desiredPos = core.AdjustMovementForTowerLogic(desiredPos)
      end
      core.OrderMoveToPosClamp(botBrain, unitSelf, desiredPos, false)
      bActionTaken = true
    end
  end

  if not bActionTaken then
    return object.harassExecuteOld(botBrain)
  end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


local function DetermineHookTarget(hook)
  local tLocalEnemies = core.CopyTable(core.localUnits["EnemyHeroes"])
  local maxDistance = hook:GetRange()
  local maxDistanceSq = maxDistance * maxDistance
  local myPos = core.unitSelf:GetPosition()
  local unitTarget = nil
  local distanceTarget = 999999999
  for _, unitEnemy in pairs(tLocalEnemies) do
    local enemyPos = unitEnemy:GetPosition()
    local distanceEnemy = Vector3.Distance2DSq(myPos, enemyPos)
    if distanceEnemy < maxDistanceSq then
      if distanceEnemy < distanceTarget and not creepsInWay(unitEnemy, false) then
        unitTarget = unitEnemy
        distanceTarget = distanceEnemy
      end
    end
  end
  return unitTarget
end

local function DetermineUltiTarget(ulti)
  local tLocalEnemies = core.CopyTable(core.localUnits["EnemyHeroes"])
  local maxDistance = ulti:GetRange()
  local maxDistanceSq = maxDistance * maxDistance
  local myPos = core.unitSelf:GetPosition()
  local unitTarget = nil
  local distanceTarget = 999999999
  for _, unitEnemy in pairs(tLocalEnemies) do
    local enemyPos = unitEnemy:GetPosition()
    local distanceEnemy = Vector3.Distance2DSq(myPos, enemyPos)
    if distanceEnemy < maxDistanceSq then
      if distanceEnemy < distanceTarget and not creepsInWay(unitEnemy, false) then
        unitTarget = unitEnemy
        distanceTarget = distanceEnemy
      end
    end
  end
  return unitTarget
end

local hookTarget = nil
local function HookUtility(botBrain)
  local hook = skills.hook
  if hook and hook:CanActivate() then
    local unitTarget = DetermineHookTarget(hook)
    if unitTarget then
      hookTarget = unitTarget:GetPosition()
      local hookTargetHp = unitTarget:GetHealthPercent()
      if hookTargetHp < 0.32 or (core.unitSelf:GetManaPercent() > 0.95 and hookTargetHp < 0.8) then
        return 90
      end
    end
  end
  hookTarget = nil
  return 0
end
local function HookExecute(botBrain)
  local hook = skills.hook
  if hook and hook:CanActivate() and hookTarget then
    return core.OrderAbilityPosition(botBrain, hook, hookTarget)
  end
  return false
end
local HookBehavior = {}
HookBehavior["Utility"] = HookUtility
HookBehavior["Execute"] = HookExecute
HookBehavior["Name"] = "Hooking"
tinsert(behaviorLib.tBehaviors, HookBehavior)

local RotEnableBehavior = {}
local function HasEnemyHeroesInRange(unit, range)
  local enemyHeroes = core.CopyTable(core.localUnits["EnemyHeroes"])
  local rangeSq = range * range
  local myPos = unit:GetPosition()
  for _, enemy in pairs(enemyHeroes) do
    if Vector3.Distance2DSq(enemy:GetPosition(), myPos) < rangeSq then
      return true
    end
  end
  return false
end
local function HowManyEnemyCreepsInRange(unit, range)
  local enemyCreeps = core.CopyTable(core.localUnits["EnemyCreeps"])
  local rangeSq = range * range
  local myPos = unit:GetPosition()
  local creeps = 0
  for _, enemy in pairs(enemyCreeps) do
    if Vector3.Distance2DSq(enemy:GetPosition(), myPos) < rangeSq then
      creeps = creeps + 1
    end
  end
  return creeps
end
local ultiTarget = nil
local function RotEnableUtility(botBrain)
  local rot = skills.rot
  local ulti = skills.ulti
  local rotRange = rot:GetTargetRadius()
  local ultiRange = ulti:GetTargetRadius()
  local hasEffect = core.unitSelf:HasState("State_Devourer_Ability2_Self")
  local hasEnemyHeroesClose = HasEnemyHeroesInRange(core.unitSelf, rotRange)
  local hasEnemyHeroesUltiRange = HasEnemyHeroesInRange(core.unitSelf, ultiRange)
  local hasEnemyCreepsClose = HowManyEnemyCreepsInRange(core.unitSelf, rotRange)
  if ulti and ulti:CanActivate() then
    ultiTarget = DetermineUltiTarget(ulti)
  end
  local rotting = 0
  if ulti:CanActivate() and not core.unitSelf:IsChanneling() and ultiTarget then
    if hasEnemyHeroesUltiRang then
      rotting = rotting + 50
    end
  end
  if rot:CanActivate() and not hasEffect then
    if hasEnemyHeroesClose then
      rotting = rotting + 50
    end
    if hasEnemyCreepsClose > 2 then
      rotting = rotting + 50
    end
    rotting = rotting * core.unitSelf:GetHealthPercent() 
    if core.unitSelf:IsChanneling()  then
      rotting = rotting + 100
    end
  end
  return rotting
  
end
local function RotEnableExecute(botBrain)
  local rot = skills.rot
  if rot and rot:CanActivate() then
    return core.OrderAbility(botBrain, rot)
  end
  local ulti = skills.ulti
  if ulti and ulti:CanActivate() then
    ultiTarget = DetermineUltiTarget(ulti)
    core.OrderAbilityEntity(botBrain, ulti, ultiTarget)
  end
  return false
end
RotEnableBehavior["Utility"] = RotEnableUtility
RotEnableBehavior["Execute"] = RotEnableExecute
RotEnableBehavior["Name"] = "Rot enable"
tinsert(behaviorLib.tBehaviors, RotEnableBehavior)

local RotDisableBehavior = {}
local function RotDisableUtility(botBrain)
  local rot = skills.rot
  local rotRange = rot:GetTargetRadius()
  local hasEffect = core.unitSelf:HasState("State_Devourer_Ability2_Self")
  local hasEnemyHeroesClose = HasEnemyHeroesInRange(core.unitSelf, rotRange)
  local hasEnemyCreepsClose = HowManyEnemyCreepsInRange(core.unitSelf, rotRange)
  local rotting = 0
  if rot:CanActivate() and hasEffect then
    rotting = 100
    if hasEnemyHeroesClose and hasEnemyCreepsClose > 2 then
      rotting = rotting - 90
    elseif hasEnemyHeroesClose then
      rotting = rotting - 50
    elseif hasEnemyCreepsClose > 2 then
      rotting = rotting - 40
    else
      return 100
    end
    rotting = rotting * core.unitSelf:GetHealthPercent() 
    --rotting = (100 - rotting)
    rotting = Clamp(rotting, 0, 100)
  end
  return rotting
end
local function RotDisableExecute(botBrain)
  local rot = skills.rot
  if rot and rot:CanActivate() then
    return core.OrderAbility(botBrain, rot)
  end
  return false
end
RotDisableBehavior["Utility"] = RotDisableUtility
RotDisableBehavior["Execute"] = RotDisableExecute
RotDisableBehavior["Name"] = "Rot disable"
tinsert(behaviorLib.tBehaviors, RotDisableBehavior)

local BarbedUseBehavior = {}
local function BarbedUseUtility(botBrain)
  local hpVelo = core.unitSelf:GetHealthVelocity() 
  if itemBarbed and itemBarbed:CanActivate() and hpVelo < -200 then
    p(hpVelo)
    return 93
  end
  return 0
end
local function BarbedUseExecute(botBrain)
  p("USING BARBED ARMOR!")
  if itemBarbed and itemBarbed:CanActivate() then
    core.OrderItemClamp(botBrain, unitSelf, itemBarbed)
    return true
  end
  return false
end
BarbedUseBehavior["Utility"] = BarbedUseUtility
BarbedUseBehavior["Execute"] = BarbedUseExecute
BarbedUseBehavior["Name"] = "Barbed Use"
tinsert(behaviorLib.tBehaviors, BarbedUseBehavior)

BotEcho('finished loading devourer_main')
