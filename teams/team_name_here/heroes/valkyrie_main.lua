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

runfile "bots/utils.lua"
runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
  = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
  = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading valkyrie_main...')

object.heroName = 'Hero_Valkyrie'

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 4, LongSolo = 2, ShortSupport = 0, LongSupport = 0, ShortCarry = 4, LongCarry = 3}

----------------------------------
--      Valk items
----------------------------------
behaviorLib.StartingItems =
	{"Item_RunesOfTheBlight", "2 Item_MinorTotem", "Item_ManaBattery", "Item_DuckBoots" }
behaviorLib.LaneItems =
	{ "Item_Marchers", "Item_Energizer", "Item_Steamboots"} -- Items: Marchers,Helm Of The Black Legion, upg Marchers to Plated Greaves
behaviorLib.MidItems =
	{"Item_MagicArmor2","Item_DaemonicBreastplate", "Item_Strength6"} -- Items: Shaman's Headress, Daemonic Breastplate, Icebrand
behaviorLib.LateItems =
	{"Item_BehemothsHeart", "Item_Freeze"} -- Items: Behemoth's Heart, Upg Icebrang into Frostwolf Skull

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
  local unitSelf = self.core.unitSelf

  if not bSkillsValid then
    skills.call = unitSelf:GetAbility(0)
    skills.javelin = unitSelf:GetAbility(1)
    skills.leap = unitSelf:GetAbility(2)
    skills.ulti = unitSelf:GetAbility(3)
    skills.attributeBoost = unitSelf:GetAbility(4)
    skills.taunt = unitSelf:GetAbility(8)
    skills.courier = unitSelf:GetAbility(12)

    if skills.call and skills.javelin and skills.leap and skills.ulti and skills.attributeBoost and skills.taunt and skills.courier then
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
  elseif skills.javelin:CanLevelUp() then
    skills.javelin:LevelUp()
  elseif skills.leap:CanLevelUp() then
    skills.leap:LevelUp()
  elseif skills.call:CanLevelUp() then
    skills.call:LevelUp()
  else
    skills.attributeBoost:LevelUp()
  end
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

    -- Valk arrow thrown by an ally hit an enemy
    if EventData.InflictorName == "Projectile_Valkyrie_Ability2" and EventData.SourcePlayerName == "RETK_ValkyrieBot" then
        if not object.arrowHit then
            object.arrowHit = true
            core.AllChat("LOL NOOB RETK")
        end
    end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

------------------------
--CustomHarassUtility
------------------------
local function CustomHarassUtilityFnOverride(hero)
    local abilTaunt = skills.taunt
    if abilTaunt:CanActivate() then
        return 100
    end

    return 0 -- The default
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if not unitTarget or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end

	local unitSelf = core.unitSelf

	local vecMyPosition = unitSelf:GetPosition()
	local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	nAttackRangeSq = nAttackRangeSq * nAttackRangeSq

	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	local bCanSeeUnit = core.CanSeeUnit(botBrain, unitTarget)

	local nLastHarassUtility = behaviorLib.lastHarassUtil

	local bActionTaken = false

	local nNow = HoN.GetGameTime()
	
	--Taunting!!!
	if not bActionTaken and bCanSeeUnit then		
		local abilTaunt = skills.taunt
		if abilTaunt:CanActivate() then
			local nRange = 1200
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilTaunt, unitTarget)
			end
		end
	end

	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end

end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

local function PreGameExecuteOverride(botBrain)
    if object.arrowThrown then
        return object.preGameExecuteOld(botBrain)
    end

    if skills.javelin == nil then
        p("Skill is null :(")
        return object.preGameExecuteOld(botBrain)
    end

    if not skills.javelin:CanActivate() then
        p("Skill is null :(")
        return object.preGameExecuteOld(botBrain)
    end

    local enemyPool
    if core.myTeam == HoN.GetHellbourneTeam() then
        p("I am hellbourne")
        enemyPool = Vector3.Create(3144.3381, 6972.4937, 256.0000)
    else
        p("I am legion")
        enemyPool = Vector3.Create(8588.3457, 11719.2256, 259.2413)
    end

    if core.OrderAbilityPosition(botBrain, skills.javelin, enemyPool) then
        p("Arrow thrown!")
        object.arrowThrown = true
    end

end
object.preGameExecuteOld = behaviorLib.PreGameBehavior["Execute"]
behaviorLib.PreGameBehavior["Execute"] = PreGameExecuteOverride
