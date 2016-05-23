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

object.bReportBehavior = false
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

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"
runfile "bots/teams/default/generics.lua"

local core, eventsLib, behaviorLib, metadata, skills, generics = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills, object.generics

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

behaviorLib.StartingItems = {"Item_ManaBattery", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_EnhancedMarchers", "Item_PowerSupply"}
behaviorLib.MidItems = {"Item_PortalKey", "Item_MagicArmor2"}
behaviorLib.LateItems = {"Item_BehemothsHeart"}


local unitHooked = nil
function object:oncombateventOverride(EventData)
  self:oncombateventOld(EventData)

  if EventData.InflictorName == "Projectile_Devourer_Ability1" and EventData.SourceUnit:GetUniqueID() == core.unitSelf:GetUniqueID() then
    if EventData.Type == "Attack" then
      local victim = EventData.TargetUnit
      if victim:IsHero() then
        core.AllChat("YOU'RE MINE!")
        unitHooked = victim
      end
    elseif EventData.Type == "Projectile_Target" and EventData.TargetUnit:GetUniqueID() == core.unitSelf:GetUniqueID() then
      if unitHooked then
        local teamBotBrain = core.teamBotBrain
        if teamBotBrain.SetTeamTarget then
          teamBotBrain:SetTeamTarget(unitHooked)
        end
      end
      unitHooked = nil
    end
  end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

-- Harass
local function CustomHarassUtilityOverride(target)
  local nUtility = 0

  if skills.hook:CanActivate() then
    nUtility = nUtility + 10
  end

  if skills.ulti:CanActivate() then
    nUtility = nUtility + 40
  end

  return generics.CustomHarassUtility(target) + nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride

local itemPK = nil
local FindItemsOld = core.FindItems
local function FindItemsFn(botBrain)
  FindItemsOld(botBrain)
  if itemPK then
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
  local teamBotBrain = core.teamBotBrain
  if teamBotBrain.GetTeamTarget then
    local teamTarget = teamBotBrain:GetTeamTarget()
    if teamTarget then
      if generics.IsFreeLine(myPos, teamTarget:GetPosition()) then
        return teamTarget
      end
    end
  end
  local unitTarget = nil
  local distanceTarget = 999999999
  for _, unitEnemy in pairs(tLocalEnemies) do
    local enemyPos = unitEnemy:GetPosition()
    local distanceEnemy = Vector3.Distance2DSq(myPos, enemyPos)
    if distanceEnemy < maxDistanceSq then
      if distanceEnemy < distanceTarget and generics.IsFreeLine(myPos, enemyPos) then
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
      return 60
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
local function HasEnemiesInRange(unit, range)
  local enemies = core.CopyTable(core.localUnits["EnemyHeroes"])
  local rangeSq = range * range
  local myPos = unit:GetPosition()
  for _, enemy in pairs(enemies) do
    if not enemy:IsMagicImmune() and Vector3.Distance2DSq(enemy:GetPosition(), myPos) < rangeSq then
      return true
    end
  end
  return false
end
local function RotEnableUtility(botBrain)
  local rot = skills.rot
  local rotRange = rot:GetTargetRadius()
  local hasEffect = core.unitSelf:HasState("State_Devourer_Ability2_Self")
  local hasEnemiesClose = HasEnemiesInRange(core.unitSelf, rotRange)
  if rot:CanActivate() and hasEnemiesClose and not hasEffect then
    return 50
  end
  return 0
end
local function RotEnableExecute(botBrain)
  local rot = skills.rot
  if rot and rot:CanActivate() then
    return core.OrderAbility(botBrain, rot)
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
  local hasEnemiesClose = HasEnemiesInRange(core.unitSelf, rotRange)
  if rot:CanActivate() and hasEffect and not hasEnemiesClose then
    return 1000
  end
  return 0
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

BotEcho('finished loading devourer_main')
