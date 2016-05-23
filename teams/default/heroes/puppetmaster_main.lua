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

BotEcho('loading puppetmaster_main...')

object.heroName = 'Hero_PuppetMaster'


behaviorLib.StartingItems = {"Item_ManaBattery", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_PowerSupply", "Item_Steamboots"}
behaviorLib.MidItems = {"Item_Stealth", "Item_ElderParasite", "Item_Weapon3"}
behaviorLib.LateItems = {"Item_BehemothsHeart"}


--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 4, LongSolo = 0, ShortSupport = 0, LongSupport = 0, ShortCarry = 4, LongCarry = 3}

--------------------------------
-- Skills
--------------------------------
-- Skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
  0, 1, 2, 0, 0,
  3, 0, 1, 1, 1,
  3, 2, 2, 2, 4,
  3, 4, 4, 4, 4,
  4, 4, 4, 4, 4
}
local bSkillsValid = false
function object:SkillBuild()
  local unitSelf = self.core.unitSelf

  if not bSkillsValid then
    skills.hold = unitSelf:GetAbility(0)
    skills.show = unitSelf:GetAbility(1)
    skills.whip = unitSelf:GetAbility(2)
    skills.ulti = unitSelf:GetAbility(3)
    skills.attributeBoost = unitSelf:GetAbility(4)

    if skills.hold and skills.show and skills.whip and skills.ulti and skills.attributeBoost then
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


----------------------------------------------
--            oncombatevent override        --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
-- @param: eventdata
-- @return: none
function object:oncombateventOverride(EventData)
  self:oncombateventOld(EventData)

  local addBonus = 0

  if EventData.Type == "Ability" then
    if EventData.InflictorName == "Ability_PuppetMaster1" and EventData.SourceUnit:GetUniqueID() == core.unitSelf:GetUniqueID() then
      addBonus = addBonus + 30
    elseif EventData.InflictorName == "Ability_PuppetMaster2" and EventData.SourceUnit:GetUniqueID() == core.unitSelf:GetUniqueID() then
      addBonus = addBonus + 30
    end
  end

  if addBonus > 0 then
    core.nHarassBonus = core.nHarassBonus + addBonus
  end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

local function CustomHarassUtilityFnOverride(target)
  local nUtility = 0

  if skills.show:CanActivate() then
    nUtility = nUtility + 10
  end

  if skills.hold:CanActivate() then
    nUtility = nUtility + 10
  end

  return generics.CustomHarassUtility(target) + nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

local function HarassHeroExecuteOverride(botBrain)
  local unitTarget = behaviorLib.heroTarget
  if unitTarget == nil or not unitTarget:IsValid() then
    return false --can not execute, move on to the next behavior
  end

  local unitSelf = core.unitSelf
  local bActionTaken = false

  if core.CanSeeUnit(botBrain, unitTarget) then

    local nTargetDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())

    local ulti = skills.ulti
    local nRange = ulti:GetRange()
    if not unitTarget:IsMagicImmune() and ulti:CanActivate() and nTargetDistanceSq < (nRange * nRange) then
      bActionTaken = core.OrderAbilityEntity(botBrain, ulti, unitTarget)
    end

    local hold = skills.hold
    nRange = hold:GetRange()
    if not bActionTaken and not unitTarget:IsStunned() and not unitTarget:IsMagicImmune() and hold:CanActivate() and not unitTarget:HasState("State_PuppetMaster_Ability2") and nTargetDistanceSq < (nRange * nRange) then
      bActionTaken = core.OrderAbilityEntity(botBrain, hold, unitTarget)
    end

    local show = skills.show
    nRange = show:GetRange()
    local unitsNearby = core.AssessLocalUnits(botBrain, unitTarget, 400)

    local nEnemies = core.NumberElements(unitsNearby.Enemies)

    if not bActionTaken and not unitTarget:IsStunned() and not unitTarget:IsMagicImmune() and not unitTarget:HasState("State_PuppetMaster_Ability1") and show:CanActivate() and nTargetDistanceSq < (nRange * nRange) and nEnemies > 0 then
      bActionTaken = core.OrderAbilityEntity(botBrain, show, unitTarget)
    end
  end

  if not bActionTaken then
    return core.harassExecuteOld(botBrain)
  end
end
core.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

BotEcho('finished loading puppetmaster_main')
