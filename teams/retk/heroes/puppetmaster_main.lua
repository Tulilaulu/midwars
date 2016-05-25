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

object.debugPuppetShowCreeps = false

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

BotEcho('loading puppetmaster_main...')

object.heroName = 'Hero_PuppetMaster'

object.nUltiUp = 30
object.nShowUp = 10
object.nHoldUp = 19
object.nSheepstickUp = 15
object.nStunUtil = 20 -- extra aggression if target stunned

object.nUltiUse = 19
object.nShowUse = 9
object.nHoldUse = 22

object.nUltiThreshold = 21
object.nShowThreshold = 11
object.nHoldThreshold = 13
object.nSheepstickThreshold = 30

behaviorLib.debugHarassUtility = false
behaviorLib.debugHarassExecute = false

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 4, LongSolo = 0, ShortSupport = 0, LongSupport = 0, ShortCarry = 4, LongCarry = 3}

behaviorLib.StartingItems =
	{"Item_MerricksBounty", "2 Item_MinorTotem", "Item_ManaBattery", "Item_MarkOfTheNovice" }
behaviorLib.LaneItems =
	{ "Item_PowerSupply", "Item_Marchers", "Item_PretendersCrown", "Item_Intelligence5", "Item_GraveLocket", "Item_ApprenticesRobe", "Item_Steamboots"}
behaviorLib.MidItems =
	{"Item_Shield2", "Item_WhisperingHelm", "Item_Glowstone", "Item_Beastheart", "Item_HealthMana2",  "Item_AcolytesStaff", "Item_LuminousPrism", "Item_Morph" } -- Items: Shaman's Headress, Daemonic Breastplate, Icebrand
behaviorLib.LateItems =
	{"Item_BehemothsHeart"} -- Items: Behemoth's Heart, Upg Icebrang into Frostwolf Skull

behaviorLib.healAtWellHealthFactor = 1.3
behaviorLib.healAtWellProximityFactor = 0.5
--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
  local unitSelf = self.core.unitSelf

  if not bSkillsValid then
    skills.hold = unitSelf:GetAbility(0)
    skills.show = unitSelf:GetAbility(1)
    skills.whip = unitSelf:GetAbility(2)
    skills.ulti = unitSelf:GetAbility(3)
    skills.attributeBoost = unitSelf:GetAbility(4)
    skills.taunt = unitSelf:GetAbility(8)
    skills.courier = unitSelf:GetAbility(12)

    if skills.hold and skills.show and skills.whip and skills.ulti and skills.attributeBoost and skills.taunt and skills.courier then
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
  elseif skills.whip:GetLevel() == 0 then
    skills.whip:LevelUp()
  elseif skills.hold:CanLevelUp() then
    skills.hold:LevelUp()
  elseif skills.show:GetLevel() == 0 then
    skills.show:LevelUp()
  elseif skills.whip:CanLevelUp() then
    skills.whip:LevelUp()
  elseif skills.show:CanLevelUp() then
    skills.show:LevelUp()
  else
    skills.attributeBoost:LevelUp()
  end
end

local ShowRange = { [0] = 0, [1] = 250, [2] = 300, [3] = 350, [4] = 400 }

local function creepsNearbyForPuppetShow(unitTarget, drawLines)
    -- p("here")
    local selfPos = core.unitSelf:GetPosition()
    local targetPos = unitTarget:GetPosition()

    local range = ShowRange[skills.show:GetLevel()]

    local tables = { core.localUnits["EnemyCreeps"], core.localUnits["AllyCreeps"], core.localUnits["EnemyHeroes"] }
    local ok = false
    for _, table in ipairs(tables) do
        for i, creep in pairs(table) do
            if creep ~= unitTarget then
                local name = creep:GetTypeName()
                local creepPos = creep:GetPosition()
                local d = Vector3.Distance2DSq(targetPos, creepPos)

                if d > range * range then
                    color ="red"
                else
                    color = "green"
                    ok = true
                end
                if drawLines then drawCross(creepPos, color) end
            end
        end
    end

    if ok then
        if drawLines then drawCross(targetPos, "yellow") end
    else
        if drawLines then drawCross(targetPos, "black") end
    end

    return ok
end

------------------------------------------------------
--            onthink override                      --
-- Called every bot tick, custom onthink code here  --
------------------------------------------------------
-- @param: tGameVariables
-- @return: none
function object:onthinkOverride(tGameVariables)
    self:onthinkOld(tGameVariables)

    local unitTarget = behaviorLib.heroTarget
    if unitTarget and unitTarget:IsValid() then
        creepsNearbyForPuppetShow(unitTarget, object.debugPuppetShowCreeps)
    end
    --for _, e in pairs(core.localUnits["Enemies"]) do
    --    p(e:GetTypeName())
    --end
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
    local addBonus = 0
    -- p(EventData)
    if EventData.InflictorName == "Ability_PuppetMaster1" and EventData.SourcePlayerName == "RETK_PuppetMasterBot" then
        -- core.AllChat("Used hold successfully")
        addBonus = addBonus + object.nHoldUse
    elseif EventData.InflictorName == "Ability_PuppetMaster2" and EventData.SourcePlayerName == "RETK_PuppetMasterBot" then
        -- core.AllChat("Used show successfully")
        addBonus = addBonus + object.nShowUse
    elseif EventData.InflictorName == "Ability_PuppetMaster4" and EventData.SourcePlayerName == "RETK_PuppetMasterBot" then
        -- core.AllChat("Used ulti successfully")
        addBonus = addBonus + object.nUltiUse
    end

    if addBonus > 0 then
        --decay before we add
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + addBonus
    end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

------------------------
--CustomHarassUtility
------------------------


local function CustomHarassUtilityFnOverride(hero)
    local unitTarget = behaviorLib.heroTarget
    if not unitTarget or not unitTarget:IsValid() or not bSkillsValid then
        return 0 --can not execute, move on to the next behavior
    end

    if object:IsPoolDiving() then
        return -500
    end

    local ms = unitTarget:GetMoveSpeed() or 0
    local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or ms < 200

    local utility = 0
    if skills.ulti:CanActivate() then
        utility = utility + object.nUltiUp
    end
    if skills.show:CanActivate() and creepsNearbyForPuppetShow(unitTarget, false) then
        utility = utility + object.nShowUp
    end
    if skills.hold:CanActivate() then
        utility = utility + object.nHoldUp
    end
    if skills.hold:CanActivate() then
        utility = utility + object.nHoldUp
    end
    if bTargetRooted then
        utility = utility + object.nStunUtil
    end
    local itemSheepstick = core.GetItem("Item_Morph")
    if itemSheepstick ~= nil and itemSheepstick:CanActivate() and not bTargetRooted then
            utility = utility + object.nSheepstickUp
    end

    if unitTarget:GetTypeName() == "Pet_PuppetMaster_Ability4" then
        -- p("Targeted puppet ult")
        utility = utility + 50
    end

    local mp = core.unitSelf:GetManaPercent()
    local manaThresh = 0.7
    if mp > manaThresh then
        utility = utility + (mp - manaThresh) * 20
    end

    -- p("Harass utility: " .. tostring(utility))
    return utility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

local function HarassHeroExecuteOverride(botBrain)
    local unitTarget = behaviorLib.heroTarget
    if not unitTarget or not unitTarget:IsValid() or not bSkillsValid then
        -- p("Can't harass :(")
        return false --can not execute, move on to the next behavior
    end

    local unitSelf = core.unitSelf

    local vecMyPosition = unitSelf:GetPosition()
    local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
    nAttackRangeSq = nAttackRangeSq * nAttackRangeSq

    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
    local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
    local bCanSeeUnit = unitTarget:IsHero() and core.CanSeeUnit(botBrain, unitTarget)

    local nLastHarassUtility = behaviorLib.lastHarassUtil

    local bActionTaken = false

    local nNow = HoN.GetGameTime()
    local abilTaunt = skills.taunt

    --Taunt
    if not bActionTaken and bCanSeeUnit then
        if abilTaunt:CanActivate() then
            local nRange = 1200
            if nTargetDistanceSq < (nRange * nRange) then
                -- p("using taunt")
                bActionTaken = core.OrderAbilityEntity(botBrain, abilTaunt, unitTarget)
            end
        end
    end

    if not bActionTaken and bCanSeeUnit then
        local itemSheepstick = core.GetItem("Item_Morph")
        if itemSheepstick then
            local nRange = itemSheepstick:GetRange()
            if itemSheepstick:CanActivate() and nLastHarassUtility > object.nSheepstickThreshold and not bTargetRooted and unitTarget:GetHealthPercent() > 0.3 then
                if nTargetDistanceSq < (nRange * nRange) then
                        bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
                end
            end
        end
    end

    -- Ult
    if not bActionTaken and bCanSeeUnit and skills.ulti:CanActivate() and nLastHarassUtility >= object.nUltiThreshold then
        local nRange = skills.ulti:GetRange()
        -- p("ulti range is: " .. tostring(nRange))
        if nTargetDistanceSq < (nRange * nRange)  then
            -- core.AllChat("using ult")
            bActionTaken = core.OrderAbilityEntity(botBrain, skills.ulti, unitTarget)
        end
    end

    -- Show
    if not bActionTaken and bCanSeeUnit and creepsNearbyForPuppetShow(unitTarget, false) and skills.show:CanActivate() and nLastHarassUtility >= object.nShowThreshold then
        local nRange = skills.show:GetRange()
        -- p("show range is: " .. tostring(nRange))
        if nTargetDistanceSq < (nRange * nRange) then
            if nLastHarassUtility > object.nShowThreshold then
                -- core.AllChat("using show")
                bActionTaken = core.OrderAbilityEntity(botBrain, skills.show, unitTarget)
            end
        end
    end

    -- Hold
    if not bActionTaken and bCanSeeUnit and skills.hold:CanActivate() and nLastHarassUtility >= object.nHoldThreshold then
        local nRange = skills.hold:GetRange()
        -- p("hold range is: " .. tostring(nRange))
        if nTargetDistanceSq < (nRange * nRange)  then
            -- core.AllChat("using hold")
            bActionTaken = core.OrderAbilityEntity(botBrain, skills.hold, unitTarget)
        end
    end


    if not bActionTaken then
        return object.harassExecuteOld(botBrain)
    end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

BotEcho('finished loading puppetmaster_main')
