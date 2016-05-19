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

BotEcho('loading monkeyking_main...')

object.heroName = 'Hero_MonkeyKing'

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 0, LongSolo = 0, ShortSupport = 0, LongSupport = 0, ShortCarry = 0, LongCarry = 0}

----------------------------------
--      MK items
----------------------------------
behaviorLib.StartingItems =
	{"Item_LoggersHatchet", "2 Item_MinorTotem", "Item_ManaBattery"}
behaviorLib.LaneItems =
	{ "Item_PowerSupply", "Item_Marchers", "Item_Punchdagger", "Item_EnhancedMarchers"} -- Items: power supply, ghost marchers
behaviorLib.MidItems =
	{"Item_Manatube", "Item_Lifetube", "Item_Glowstone", "Item_Protect", "Item_GuardianRing", "Item_Ringmail", "Item_SolsBulwark"} -- Items: nullstone, sols bulwark
behaviorLib.LateItems =
	{"Item_Warhammer", "Item_Pierce", "Item_Voulge", "Item_Weapon3"} -- Items: shieldbreaker, savage mace

behaviorLib.healAtWellHealthFactor = 1.3
behaviorLib.healAtWellProximityFactor = 0.5

--------------------------------
-- Skills
--------------------------------

--order of leveling
object.tSkills = {
   0, 1, 2, 1, 1,
   3, 2, 2, 0, 0,
   1, 2, 0, 3, 3,
   4, 4, 4, 4, 4,
   4, 4, 4, 4, 4,
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
    skills.taunt = unitSelf:GetAbility(8)
    skills.courier = unitSelf:GetAbility(12)	

    if skills.dash and skills.pole and skills.rock and skills.ulti and skills.attributeBoost then
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
  elseif skills.dash:CanLevelUp() then
    skills.dash:LevelUp()
  elseif skills.pole:CanLevelUp() then
    skills.pole:LevelUp()
  elseif skills.rock:CanLevelUp() then
    skills.rock:LevelUp()
  else
    skills.attributeBoost:LevelUp()
  end
end

-- These are bonus agression points if a skill/item is available for use
object.nDashUp = 10
object.nPoleUp = 12 
object.nRockUp = 8
 
-- These are bonus agression points that are applied to the bot upon successfully using a skill/item
object.nDashUse = 15
object.nPoleUse = 20
object.nRockUse = 12
 
--These are thresholds of aggression the bot must reach to use these abilities
object.nDashThreshold = 15
object.nPoleThreshold = 16
object.nRockThreshold = 12

------------------------------------------------------
--            CustomHarassUtility Override          --
-- Change Utility according to usable spells here   --
------------------------------------------------------
-- @param: IunitEntity hero
-- @return: number
local function CustomHarassUtilityFnOverride(hero)
    local nUtil = 0
     
    if skills.dash:CanActivate() then
        nUtil = nUtil + object.nDashUp
    end
 
    if skills.pole:CanActivate() then
        nUtil = nUtil + object.nPoleUp
    end
 
    if skills.rock:CanActivate() then
        nUtil = nUtil + object.nRockUp
    end
    local mp = core.unitSelf:GetManaPercent()
    local manaThresh = 0.7
    if mp > manaThresh then
        nUtil = nUtil + (mp - manaThresh) * 20
    end
    return nUtil
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride  


----------------------------------------------
--            OncombatEvent Override        --
-- Use to check for Infilictors (fe. Buffs) --
----------------------------------------------
-- @param: EventData
-- @return: none 
function object:oncombateventOverride(EventData)
    self:oncombateventOld(EventData)
    local nAddBonus = 0

    if EventData.Type == "Ability" then
        if EventData.InflictorName == "Ability_MonkeyKing2" then
            nAddBonus = nAddBonus + object.nDashUse
        elseif EventData.InflictorName == "Ability_MonkeyKing1" then
            nAddBonus = nAddBonus + object.nPoleUse
        elseif EventData.InflictorName == "Ability_MonkeyKing3" then
            nAddBonus = nAddBonus + object.nRockUse
        end
    end
 
   if nAddBonus > 0 then
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + nAddBonus
    end
 
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent    = object.oncombateventOverride


--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--
local function HarassHeroExecuteOverride(botBrain)
     
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return object.harassExecuteOld(botBrain)  --Target is invalid, move on to the next behavior
    end
     
     
    local unitSelf = core.unitSelf
    local vecMyPosition = unitSelf:GetPosition() 
    local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
    local nMyExtraRange = core.GetExtraRange(unitSelf)
     
    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetExtraRange = core.GetExtraRange(unitTarget)
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
 
     
    local nLastHarassUtility = behaviorLib.lastHarassUtil
    local bCanSee = core.CanSeeUnit(botBrain, unitTarget)    
    local bActionTaken = false
 
    --since we are using an old pointer, ensure we can still see the target for entity targeting
    if core.CanSeeUnit(botBrain, unitTarget) then
        local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:IsPerplexed()
        -- Dash
        if not bActionTaken and not bTargetVuln then
            if skills.dash:CanActivate() and nLastHarassUtility > botBrain.nDashThreshold then
                local nRange = skills.dash:GetRange()
                if nTargetDistanceSq < (nRange * nRange) then
                    bActionTaken = core.OrderAbility(botBrain, skills.dash)
                end          
            end
        end
    end
 
 
     -- pole
    if not bActionTaken then
        if skills.pole:CanActivate() and nLastHarassUtility > botBrain.nPoleThreshold then
            local nRange = skills.pole:GetRange()
            if nTargetDistanceSq < (nRange * nRange) then
                bActionTaken = core.OrderAbilityEntity(botBrain, skills.pole, unitTarget)
            else
                bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
            end
        end
    end
 
     -- rock
    if core.CanSeeUnit(botBrain, unitTarget) then
        if not bActionTaken then --and bTargetVuln then
            if skills.rock:CanActivate() and nLastHarassUtility > botBrain.nRockThreshold then
                local nRange = 100 -- FIXME
                if nTargetDistanceSq < (nRange * nRange) then
                    bActionTaken = core.OrderAbility(botBrain, skills.rock)
                else
                    bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
                end
            end
        end 
    end 
     
    if not bActionTaken then
        return object.harassExecuteOld(botBrain) 
    end

end
 
 
 
-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


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

BotEcho('finished loading monkeyking_main')
