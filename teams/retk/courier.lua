local _G = getfenv(0)
local object = _G.object

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
  = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
  = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp
local courierFound = -999999

local function CourierUtility(botBrain)
    if HoN:GetMatchTime() <= 0 then
        return 0
    end

    behaviorLib.foundBird = false
    for i, unit in pairs(HoN.GetUnitsInRadius(core.unitSelf:GetPosition(), 9999999, 0xff)) do
        if unit:GetTypeName() == "Pet_AutomatedCourier" and unit:GetTeam() == core.unitSelf:GetTeam() and unit:GetOwnerPlayerID() == core.unitSelf:GetOwnerPlayerID() then
            drawCross(unit:GetPosition(), "red")
            behaviorLib.foundBird = true
            if courierFound < 0 then
                courierFound = HoN:GetMatchTime()
            end
            break
        end
    end

    if not behaviorLib.foundBird then
        courierFound = -99999
    end

    local bugged = false
    if courierFound > 0 and HoN:GetMatchTime() - courierFound > 40000 then
        bugged = true
        core.AllChat("Courier is bugged :(")
    end


    if bugged or (not behaviorLib.foundBird and skills.courier:CanActivate()) then
        return 100
    end
    return 0
end

local function CourierExecute(botBrain)
    courierFound = -99999
    return core.OrderAbility(botBrain, skills.courier)
end

behaviorLib.CourierBehavior = {}
behaviorLib.CourierBehavior["Execute"] = CourierExecute
behaviorLib.CourierBehavior["Utility"] = CourierUtility
behaviorLib.CourierBehavior["Name"] = "Courier"
tinsert(behaviorLib.tBehaviors, behaviorLib.CourierBehavior)

object.illusionLib.tIllusionBehaviors["NoBehavior"] = object.illusionLib.Push

function object:IsPoolDiving()
    local unitTarget = behaviorLib.heroTarget
    if not unitTarget or not unitTarget:IsValid() then
        return false
    end

    local myPos = core.unitSelf:GetPosition()
    local targetPos = unitTarget:GetPosition()

    local poolDivin = false
    if core.myTeam == HoN.GetHellbourneTeam() then
        local xlim = 4156
        local ylim = 7064
        drawLine(Vector3.Create(xlim, 0), Vector3.Create(xlim, ylim))
        drawLine(Vector3.Create(xlim, ylim), Vector3.Create(0, ylim))
        poolDivin = (targetPos.x < xlim and targetPos.y < ylim) or (myPos.x < xlim and myPos.y < ylim)
    else
        local xlim = 8000
        local ylim = 11250
        drawLine(Vector3.Create(xlim, 99999), Vector3.Create(xlim, ylim))
        drawLine(Vector3.Create(xlim, ylim), Vector3.Create(99999, ylim))
        poolDivin = (targetPos.x > xlim and targetPos.y > ylim) or (myPos.x > xlim and myPos.y > ylim)
    end

    -- if poolDivin then
    --     p(object.heroName .. " is avoiding pool diving!")
    -- end
    return poolDivin
end

local function TowerDenyUtility(botBrain)
    for _, tower in pairs(core.localUnits["AllyTowers"]) do
        if tower:IsDeniable() and tower:GetHealthPercent() < 0.005 then
            return 100
        end
        if tower:IsDeniable() and tower:GetHealthPercent() < 0.01 then
            return 85
        end
        if tower:IsDeniable() and tower:GetHealthPercent() < 0.03 then
            return 65
        end
    end
    return 0
end

function TowerDeny(botBrain)
    for _, tower in pairs(core.localUnits["AllyTowers"]) do
        if tower:IsDeniable() then
            return core.OrderAttack(botBrain, core.unitSelf, tower)
        end
    end
    p("Want to deny but no tower nearby?")
    return false
end

local TowerDenyBehavior = {}
TowerDenyBehavior["Utility"] = TowerDenyUtility
TowerDenyBehavior["Execute"] = TowerDeny
TowerDenyBehavior["Name"] = "TowerDeny"
tinsert(behaviorLib.tBehaviors, TowerDenyBehavior)

function object:CheckMerricks()
    local merricks = core.GetItem("Item_MerricksBounty")
    if merricks == nil then
        return
    end
    local lastCharges = object.lastMerricksCharges
    if lastCharges == nil then
        lastCharges = 0
    end
    local nowCharges = merricks:GetCharges()
    if nowCharges == 0 and lastCharges > 0 then
        if object.totalMerricksCharges == nil then
            object.totalMerricksCharges = 0
        end
        object.totalMerricksCharges = object.totalMerricksCharges + lastCharges
        core.AllChat("Used merricks charges: " .. tostring(lastCharges) .. " total charges: " .. tostring(object.totalMerricksCharges) .. " total gold: " .. tostring(object.totalMerricksCharges * 9))
    end
    object.lastMerricksCharges = nowCharges
end
