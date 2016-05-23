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

BotEcho('loading monkeyking_main...')

object.heroName = 'Hero_MonkeyKing'


behaviorLib.StartingItems = {"Item_ManaBattery", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_EnhancedMarchers", "Item_PowerSupply"}
behaviorLib.MidItems = {"Item_SolsBulwark", "Item_Regen", "Item_Protect"}
behaviorLib.LateItems = {"Item_Immunity", "Item_DaemonicBreastplate", "Item_BehemothsHeart"}


--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 0, LongSolo = 0, ShortSupport = 0, LongSupport = 0, ShortCarry = 0, LongCarry = 0}

--------------------------------
-- Skills
--------------------------------
-- Skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
  0, 1, 2, 0, 0,
  3, 0, 2, 2, 2,
  3, 1, 1, 1, 4,
  3, 4, 4, 4, 4,
  4, 4, 4, 4, 4
}
local bSkillsValid = false
function object:SkillBuild()
  local unitSelf = self.core.unitSelf

  if not bSkillsValid then
    skills.dash = unitSelf:GetAbility(0)
    skills.pole = unitSelf:GetAbility(1)
    skills.rock = unitSelf:GetAbility(2)
    skills.ulti = unitSelf:GetAbility(3)
    skills.attributeBoost = unitSelf:GetAbility(4)

    if skills.dash and skills.pole and skills.rock and skills.ulti and skills.attributeBoost then
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

  local bActionTaken = false

  --since we are using an old pointer, ensure we can still see the target for entity targeting
  if core.CanSeeUnit(botBrain, unitTarget) then
    local dist = Vector3.Distance2D(unitSelf:GetPosition(), unitTarget:GetPosition())
    local attkRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)

    local dash = skills.dash
    local facing = core.HeadingDifference(unitSelf, unitTarget:GetPosition())

    if dash and dash:CanActivate() and Vector3.Distance2D(unitSelf:GetPosition(), unitTarget:GetPosition()) < dash:GetRange() and facing < 0.3 then
      bActionTaken = core.OrderAbility(botBrain, dash)
    end

    local stun = skills.rock
    if not bActionTaken and not unitTarget:IsStunned() and not unitTarget:IsMagicImmune() and stun and stun:CanActivate() and Vector3.Distance2D(unitSelf:GetPosition(), unitTarget:GetPosition()) < 200 and facing < 0.3 then
      bActionTaken = core.OrderAbility(botBrain, stun)
    end

  end

  if not bActionTaken then
    return object.harassExecuteOld(botBrain)
  end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

local function PoleTarget(botBrain)
  local pole = skills.pole
  local target = nil
  local distance = 0
  local myPos = core.unitSelf:GetPosition()
  local mainPos = core.allyMainBaseStructure:GetPosition()
  local unitsNearby = core.AssessLocalUnits(botBrain, myPos, pole:GetRange())
  local fromMain = Vector3.Distance2DSq(myPos, mainPos)
    for id, obj in pairs(unitsNearby.Allies) do
    local fromMainObj = Vector3.Distance2DSq(mainPos, obj:GetPosition())
    if(fromMainObj < fromMain and fromMainObj > distance and Vector3.Distance2D(myPos, obj:GetPosition()) > 150) then
      distance = fromMainObj
      target = obj
    end
  end
  return target
end
function behaviorLib.CustomRetreatExecute(botBrain)
  local pole = skills.pole
  local target = PoleTarget(botBrain)
  if core.unitSelf:GetHealthPercent() < 0.40 and pole and pole:CanActivate() and target and Vector3.Distance2D(target:GetPosition(), core.allyWell:GetPosition()) > 2000 then
    return core.OrderAbilityEntity(botBrain, pole, target)
  end
  return false
end

local function CustomHarassUtilityOverride(target)
  local nUtility = 0

  if skills.dash:CanActivate() then
    nUtility = nUtility + skills.dash:GetLevel() * 10
  end

  if skills.rock:CanActivate() then
    nUtility = nUtility + 20
  end

  return generics.CustomHarassUtility(target) + nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride

BotEcho('finished loading monkeyking_main')
