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

BotEcho('loading nymphora_main...')

object.heroName = 'Hero_Fairy'


behaviorLib.StartingItems = {"Item_ManaBattery", "Item_MinorTotem", "Item_GuardianRing", "Item_CrushingClaws"}
behaviorLib.LaneItems = {"Item_ManaRegen3", "Item_Marchers", "Item_EnhancedMarchers", "Item_MysticVestments"}
behaviorLib.MidItems = {"Item_Astrolabe", "Item_MagicArmor2"}
behaviorLib.LateItems = {"Item_BehemothsHeart"}


--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 0, ShortSolo = 0, LongSolo = 0, ShortSupport = 5, LongSupport = 5, ShortCarry = 0, LongCarry = 0}

--------------------------------
-- Skills
--------------------------------
-- Skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
  2, 1, 0, 1, 1,
  0, 1, 0, 0, 2,
  2, 2, 4, 4, 4,
  4, 4, 4, 4, 4,
  4, 4, 3, 3, 3
}
local bSkillsValid = false
function object:SkillBuild()
  local unitSelf = self.core.unitSelf

  if not bSkillsValid then
    skills.heal = unitSelf:GetAbility(0)
    skills.mana = unitSelf:GetAbility(1)
    skills.stun = unitSelf:GetAbility(2)
    skills.ulti = unitSelf:GetAbility(3)
    skills.attributeBoost = unitSelf:GetAbility(4)

    if skills.heal and skills.mana and skills.stun and skills.ulti and skills.attributeBoost then
      bSkillsValid = true
    else
      return
    end
  end

  local nPoints = unitSelf:GetAbilityPointsAvailable()
  if nPoints <= 0 then
    return
  end

  local nLevel = unitSelf:GetLevel()
  for i = nLevel, (nLevel + nPoints) do
    unitSelf:GetAbility( self.tSkills[i] ):LevelUp()
  end
end


local function HarassHeroExecuteOverride(botBrain)
  local unitTarget = behaviorLib.heroTarget
  if unitTarget == nil or not unitTarget:IsValid() then
    return false --can not execute, move on to the next behavior
  end

  local unitSelf = core.unitSelf
  local nTargetDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())

  local bActionTaken = false

  if core.CanSeeUnit(botBrain, unitTarget) then
    local stun = skills.stun
    if stun:CanActivate() and core.unitSelf:GetMana() > 50 then
      local nRange = stun:GetRange()
      if not unitTarget:IsStunned() and nTargetDistanceSq < (nRange * nRange) then
        bActionTaken = core.OrderAbilityPosition(botBrain, stun, unitTarget:GetPosition())
      else
        bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
      end
    end
  end

  if not bActionTaken then
    return core.harassExecuteOld(botBrain)
  end
end
core.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

local function CustomHarassUtilityFnOverride(target)
  local nUtility = 0

  return generics.CustomHarassUtility(target) + nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

local manaTarget = nil
local function FindManaTarget(botBrain, mana)
  if core.unitSelf:GetManaPercent() < 0.6 then
    return core.unitSelf
  end
  local range = mana:GetRange()
  local unitsNearby = core.AssessLocalUnits(botBrain, core.unitSelf, range)
  local heroes = unitsNearby.AllyHeroes
  local target = nil
  local missing = 0
  for _, hero in pairs(heroes) do
    local curMissing = 1 - hero:GetManaPercent()
    if curMissing > missing then
      missing = curMissing
      target = hero
    end
  end
  return target
end
local function ManaUtility(botBrain)
  local mana = skills.mana
  manaTarget = FindManaTarget(botBrain, mana)
  if mana:CanActivate() and manaTarget then
     return 50
  end
  return 0
end

local function ManaExecute(botBrain)
  local mana = skills.mana
  if mana and mana:CanActivate() then
    return core.OrderAbilityEntity(botBrain, mana, manaTarget)
  end
  return false
end
local ManaBehavior = {}
ManaBehavior["Utility"] = ManaUtility
ManaBehavior["Execute"] = ManaExecute
ManaBehavior["Name"] = "Mana"
tinsert(behaviorLib.tBehaviors, ManaBehavior)


local healTarget = nil
local function FindHealTarget(botBrain, heal)
  local range = heal:GetRange()
  local unitsNearby = core.AssessLocalUnits(botBrain, core.unitSelf, range)
  local heroes = unitsNearby.AllyHeroes
  tinsert(heroes, core.unitSelf)
  local target = nil
  local missing = 0
  for _, hero in pairs(heroes) do
    local curMissing = 1 - hero:GetHealthPercent()
    if curMissing > missing then
      missing = curMissing
      target = hero
    end
  end
  return target
end
local function HealUtility(botBrain)
  local heal = skills.heal
  healTarget = FindHealTarget(botBrain, heal)
  if heal:CanActivate() and healTarget and core.unitSelf:GetManaPercent() > 0.2 then
     return 50
  end
  return 0
end

local function HealExecute(botBrain)
  local heal = skills.heal
  if heal and heal:CanActivate() then
    return core.OrderAbilityPosition(botBrain, heal, healTarget:GetPosition())
  end
  return false
end
local HealBehavior = {}
HealBehavior["Utility"] = HealUtility
HealBehavior["Execute"] = HealExecute
HealBehavior["Name"] = "Mana"
tinsert(behaviorLib.tBehaviors, HealBehavior)

BotEcho('finished loading nymphora_main')
