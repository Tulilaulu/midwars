local _G = getfenv(0)
local object = _G.object

local arrowThrown = 0

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

object.debugArrow = false -- whether to debug arrow targeting
object.debugCall = false -- whether to debug call of the valkyrie targeting

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
	{"Item_MerricksBounty", "2 Item_MinorTotem", "Item_ManaBattery", "Item_DuckBoots" }
behaviorLib.LaneItems =
	{ "Item_PowerSupply", "Item_Marchers", "Item_Soulscream", "Item_GlovesOfHaste", "Item_Steamboots", "Item_MajorTotem", "Item_Energizer" } -- Items: Marchers,Helm Of The Black Legion, upg Marchers to Plated Greaves
behaviorLib.MidItems =
	{"Item_Voltstone", "Item_Warhammer", "Item_Pierce", "2 Item_Warpcleft", "Item_ArclightCrown", "Item_Wingbow" } -- Warhammer -> Shieldbreaker, Item_Wingbow NOT Winbow but the +25 agi item
behaviorLib.LateItems =
	{"Item_Pierce 3", "Item_Evasion", "Item_AxeOfTheMalphai", "Item_BehemothsHeart"} -- Item_Evasion == Real Wingbow

behaviorLib.healAtWellHealthFactor = 1.3
behaviorLib.healAtWellProximityFactor = 0.5

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
  local unitSelf = self.core.unitSelf

  if not bSkillsValid then
    skills.call = unitSelf:GetAbility(0)
    skills.arrow = unitSelf:GetAbility(1)
    skills.leap = unitSelf:GetAbility(2)
    skills.ulti = unitSelf:GetAbility(3)
    skills.attributeBoost = unitSelf:GetAbility(4)
    skills.taunt = unitSelf:GetAbility(8)
    skills.courier = unitSelf:GetAbility(12)

    if skills.call and skills.arrow and skills.leap and skills.ulti and skills.attributeBoost and skills.taunt and skills.courier then
      bSkillsValid = true
    else
      return
    end
  end

  if unitSelf:GetAbilityPointsAvailable() <= 0 then
    return
  end

  if skills.leap:GetLevel() == 0 and skills.arrow:GetLevel() == 1 and skills.call:GetLevel() == 1 then
    skills.leap:LevelUp()
  elseif skills.ulti:CanLevelUp() then
    skills.ulti:LevelUp()
  elseif skills.arrow:CanLevelUp() then
    skills.arrow:LevelUp()
  elseif skills.call:CanLevelUp() then
    skills.call:LevelUp()
  elseif skills.leap:CanLevelUp() then
    skills.leap:LevelUp()
  else
    skills.attributeBoost:LevelUp()
  end
end

-- utility agression points if a skill/item is available for use
object.nArrowUp = 30
object.nCallUp = 10
object.nStunUtil = 10 -- extra aggression if target stunned

-- utility agression points that are applied to the bot upon successfully using a skill/item
object.nCallUse = 14
object.nArrowUse = 20

--thresholds of aggression the bot must reach to use these abilities
object.nArrowThreshold = 17
object.nCallThreshold = 10

local function To2D(vec)
    return Vector3.Create(vec.x, vec.y, 0)
end

local function creepsInWay(unitTarget, drawLines)
    local selfPos = To2D(core.unitSelf:GetPosition())
    local targetPos = To2D(unitTarget:GetPosition())
    local distanceToTarget = Vector3.Distance(targetPos, selfPos)
    local sub = Vector3.Normalize(targetPos - selfPos)
    local ortho = Vector3.Create(-sub.y, sub.x)

    if drawLines then drawLine(selfPos, targetPos, "red") end

    local ok = true
    for i, creep in pairs(core.localUnits["EnemyCreeps"]) do
        local name = creep:GetTypeName()
        local creepPos = To2D(creep:GetPosition())
        local d = Vector3.Length(Vector3.Cross(creepPos - selfPos, creepPos - targetPos)) / distanceToTarget

        local projectedPos = creepPos + d * ortho
        local projectedDistToSelf = Vector3.Distance(selfPos, projectedPos)
        local projectedDistToTarget = Vector3.Distance(targetPos, projectedPos)

        local color
        local isSiege = name == "Creep_LegionSiege" or name == "Creep_HellbourneSiege"
        if d > 120 or isSiege or projectedDistToSelf > distanceToTarget or projectedDistToTarget > distanceToTarget then
            color = "green"
        else
            color ="red"
            ok = false
        end
        if drawLines then drawCross(creepPos, color) end

        -- if drawLines then drawCross(projected, "yellow") end
        -- if drawLines then drawLine(creepPos, projected, color) end
    end

    if ok then
        if drawLines then drawCross(targetPos, "green") end
    else
        if drawLines then drawCross(targetPos, "red") end
    end
    return not ok
end

local CallDamage = { [0] = 0, [1] = 75, [2] = 150, [3] = 225, [4] = 300 }
local LeapRange = { [0] = 0, [1] = 630, [2] = 710, [3] = 790, [4] = 870 }

local function scaleMagicDamage(unitTarget, dmg)
    return (1 - unitTarget:GetMagicResistance()) * dmg
end

local function countCreepsForCallOfValkyrie(unitTarget, drawLines)
    local selfPos = core.unitSelf:GetPosition()

    local range = 200
    local count = 0
    local skillDamage = CallDamage[skills.call:GetLevel()]

    if unitTarget then
        local targetPos = unitTarget:GetPosition()
        local diff = Vector3.Distance2DSq(targetPos, selfPos)
        if diff < range * range then
            if drawLines then drawCross(targetPos, "green") end
            count = count + 1
        else
            if drawLines then drawCross(targetPos, "red") end
        end
    end

    for i, creep in pairs(core.localUnits["EnemyCreeps"]) do
        local name = creep:GetTypeName()
        local creepPos = creep:GetPosition()
        local d = Vector3.Distance2DSq(selfPos, creepPos)

        if d > range * range or (name == "Creep_LegionSiege" or name == "Creep_HellbourneSiege") then
            color ="red"
        else
            color = "yellow"
            local creepDamage = scaleMagicDamage(creep, skillDamage)
            if creepDamage >= creep:GetHealth() then
                count = count + 1
                color = "green"
            end
        end
        if drawLines then drawCross(creepPos, color) end
    end

    return count
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
    if unitTarget and unitTarget:IsValid() and core.CanSeeUnit(object, unitTarget) then
        creepsInWay(unitTarget, object.debugArrow)
        countCreepsForCallOfValkyrie(unitTarget, object.debugCall)
    end


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
    local addBonus = 0
    -- p(EventData)

    -- Valk arrow thrown by an ally hit an enemy
    if EventData.InflictorName == "Projectile_Valkyrie_Ability2" and EventData.SourcePlayerName == "RETK_ValkyrieBot" then
        if not object.arrowHit then
            object.arrowHit = true
            core.AllChat("LOL NOOB RETK")
        end
        addBonus = object.nArrowUse
    elseif EventData.InflictorName == "Ability_Valkyrie1" and EventData.SourcePlayerName == "RETK_ValkyrieBot" then
        -- p("Used call of valkyrie")
        addBonus = object.nCallUse
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

    local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200

    local utility = 0
    if (not creepsInWay(unitTarget, false)) and skills.arrow:CanActivate() then
        utility = utility + object.nArrowUp
    end
    if skills.call:CanActivate() then
        utility = utility + object.nCallUp
    end
    if bTargetRooted then
        utility = utility + object.nStunUtil
    end
    local mp = core.unitSelf:GetManaPercent()
    local manaThresh = 0.7
    if mp > manaThresh then
        utility = utility + (mp - manaThresh) * 20
    end

    return utility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

local function HarassHeroExecuteOverride(botBrain)
    local unitTarget = behaviorLib.heroTarget
    if not unitTarget or not unitTarget:IsValid() or not bSkillsValid then
        return false --can not execute, move on to the next behavior
    end

    local unitSelf = core.unitSelf

    local vecMyPosition = unitSelf:GetPosition()
    local vecAfterLeap = vecMyPosition + unitSelf:GetHeading() * LeapRange[skills.leap:GetLevel()]
    local towersNearTarget  = core.GetTowersThreateningPosition(vecAfterLeap, 0, unitSelf:GetTeam())
    local leapPosInTowerRange = core.NumberElements(towersNearTarget) > 0

    local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
    nAttackRangeSq = nAttackRangeSq * nAttackRangeSq

    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
    local nTargetDistanceSqAfterLeap = Vector3.Distance2DSq(vecAfterLeap, vecTargetPosition)
    local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
    local bCanSeeUnit = core.CanSeeUnit(botBrain, unitTarget)

    local nLastHarassUtility = behaviorLib.lastHarassUtil

    local bActionTaken = false

    local nNow = HoN.GetGameTime()
    local abilTaunt = skills.taunt
    local abilArrow = skills.arrow
    local abilCall = skills.call

    --Taunt
    if not bActionTaken and bCanSeeUnit then
        if abilTaunt:CanActivate() then
            local nRange = 1200
            if nTargetDistanceSq < (nRange * nRange) then
                bActionTaken = core.OrderAbilityEntity(botBrain, abilTaunt, unitTarget)
            end
        end
    end

    -- Leap
    local leapHealthPercent
    if leapPosInTowerRange then
        leapHealthPercent = 0.10
    elseif not bTargetRooted then
        leapHealthPercent = 0.20
    else
        leapHealthPercent = 0.50
    end

    if bCanSeeUnit and skills.leap:CanActivate() and (unitTarget:GetHealthPercent() < leapHealthPercent) then
        if math.sqrt(nTargetDistanceSqAfterLeap) < 0.8 * math.sqrt(nTargetDistanceSq) then
            bActionTaken = core.OrderAbility(botBrain, skills.leap)
        end
    end

    --Arrow
    if bCanSeeUnit and not bActionTaken and not creepsInWay(unitTarget, false) and abilArrow:CanActivate() and nLastHarassUtility >= object.nArrowThreshold then
        local nRange = abilArrow:GetRange()
        if nTargetDistanceSq < (nRange * nRange) then
            if nLastHarassUtility > object.nArrowThreshold then
                bActionTaken = core.OrderAbilityPosition(botBrain, abilArrow, unitTarget:GetPosition())
            end
        end
    end

    --Call of the Valkyrie
    local numCallTargets = countCreepsForCallOfValkyrie(unitTarget, false)
    if bCanSeeUnit and not bActionTaken and abilCall:CanActivate() and nLastHarassUtility >= object.nCallThreshold then
        local nRange = 180
        if nTargetDistanceSq < (nRange * nRange) or numCallTargets >= 2 then
            bActionTaken = core.OrderAbility(botBrain, abilCall)
            -- p("Doing call of valkyrie, hero dist: " .. tostring(math.sqrt(nTargetDistanceSq)) .. " creeps: " .. tostring(numCallTargets))
        end
    end


    if not bActionTaken then
        return object.harassExecuteOld(botBrain)
    end

end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

local function PreGameExecuteOverride(botBrain)
    if core.teamBotBrain.myName ~= "RETK" then
        core.AllChat("Wrong teambot is loaded :( Human please fix!")
    end

    if arrowThrown >= 20 then
        return object.preGameExecuteOld(botBrain)
    end

    if skills.arrow == nil then
        -- p("Skill is null :(")
        return object.preGameExecuteOld(botBrain)
    end

    if not skills.arrow:CanActivate() then
        -- p("Skill is null :(")
        return object.preGameExecuteOld(botBrain)
    end

    local enemyPool
    if core.myTeam == HoN.GetHellbourneTeam() then
        -- p("I am hellbourne")
        enemyPool = Vector3.Create(3144.3381, 6972.4937, 256.0000)
    else
        -- p("I am legion")
        enemyPool = Vector3.Create(8588.3457, 11719.2256, 259.2413)
    end

    if core.OrderAbilityPosition(botBrain, skills.arrow, enemyPool) then
        -- p("Arrow thrown!")
        arrowThrown = arrowThrown + 1
    end

end
object.preGameExecuteOld = behaviorLib.PreGameBehavior["Execute"]
behaviorLib.PreGameBehavior["Execute"] = PreGameExecuteOverride

function behaviorLib.CustomReturnToWellExecute(botBrain)
    if not skills.leap:CanActivate() then
        return false
    end
    local startPos = core.unitSelf:GetPosition()
    local endPos = core.allyMainBaseStructure:GetPosition()
    local dist = Vector3.Distance2D(startPos, endPos)
    local angle = core.HeadingDifference(core.unitSelf, endPos) * 180.0 / math.pi

    -- drawLine(startPos, endPos)
    --BotEcho(tostring(dist))
    --BotEcho(tostring(angle))

    if dist >= 2500 or dist <= 700 or angle > 16 or angle < -16 then
        return
    end

    return core.OrderAbility(botBrain, skills.leap)
end

local function GetRangeToClosestEnemy(ally)
    local dist = 999999999
    for _, enemy in pairs(core.teamBotBrain.tEnemyHeroes) do
        if enemy:IsValid() and enemy:IsAlive() and core.CanSeeUnit(object, enemy) then
            local nd = Vector3.Distance2D(enemy:GetPosition(), ally:GetPosition())
            if nd < dist then
                dist = nd
            end
        end
    end
    return dist
end

local function EnergizerUtility(botBrain)
    local item = core.GetItem("Item_Energizer")

    local use = false
    for _, ally in pairs(core.teamBotBrain.tAllyHeroes) do
        if not ally:IsAlive() or Vector3.Distance2D(core.unitSelf:GetPosition(), ally:GetPosition()) >= 600 then
            -- drawCross(ally:GetPosition(), 'red')
        else
            if ally:GetHealthPercent() < 0.4 then
                use = true
                -- drawCross(ally:GetPosition(), 'green')
            elseif GetRangeToClosestEnemy(ally) < 700 and ally:GetHealthPercent() < 0.6 then
                use = true
                -- drawCross(ally:GetPosition(), 'yellow')
            else
                for _, enemy in pairs(core.teamBotBrain.tEnemyHeroes) do
                    if enemy:IsValid() and enemy:IsAlive() and core.CanSeeUnit(object, enemy) and Vector3.Distance2D(enemy:GetPosition(), ally:GetPosition())
 < 1200 and enemy:GetHealthPercent() < 0.5 then
                        use = true
                        -- drawCross(enemy:GetPosition(), 'blue')
                        break
                    end
                end
            end
        end
    end

    if not item or not item:CanActivate() then
        return 0
    end
    if use then
        return 998
    end
    return 0
end

local function EnergizerExecute(botBrain)
    local item = core.GetItem("Item_Energizer")
    return core.OrderItemClamp(botBrain, core.unitSelf, item)
end

behaviorLib.EnergizerBehavior = {}
behaviorLib.EnergizerBehavior["Execute"] = EnergizerExecute
behaviorLib.EnergizerBehavior["Utility"] = EnergizerUtility
behaviorLib.EnergizerBehavior["Name"] = "Energizer"
tinsert(behaviorLib.tBehaviors, behaviorLib.EnergizerBehavior)

local function DefensiveUltiUtility(botBrain)

    local use = false
    for _, ally in pairs(core.teamBotBrain.tAllyHeroes) do
        if ally:IsAlive() and ally:GetHealthPercent() < 0.35 and GetRangeToClosestEnemy(ally) < 1200  then
            -- drawCross(ally:GetPosition(), 'white')
            use = true
        end
    end

    if use and skills.ulti:CanActivate() then
        return 999
    end
    return 0
end

local function DefensiveUltiExecute(botBrain)
    return core.OrderAbility(botBrain, skills.ulti)
end

behaviorLib.DefensiveUltiBehavior = {}
behaviorLib.DefensiveUltiBehavior["Execute"] = DefensiveUltiExecute
behaviorLib.DefensiveUltiBehavior["Utility"] = DefensiveUltiUtility
behaviorLib.DefensiveUltiBehavior["Name"] = "DefensiveUlti"
tinsert(behaviorLib.tBehaviors, behaviorLib.DefensiveUltiBehavior)
