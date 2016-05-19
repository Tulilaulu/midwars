local _G = getfenv(0)
local object = _G.object

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
  = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
  = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

local function CourierUtility(botBrain)
    if HoN:GetMatchTime() <= 0 then
        return 0
    end

    behaviorLib.foundBird = false
    for i, unit in pairs(HoN.GetUnitsInRadius(core.unitSelf:GetPosition(), 9999999, 0xff)) do
        if unit:GetTypeName() == "Pet_AutomatedCourier" and unit:GetTeam() == core.unitSelf:GetTeam() then
            drawCross(unit:GetPosition(), "red")
            behaviorLib.foundBird = true
            break
        end
    end

    if not behaviorLib.foundBird and skills.courier:CanActivate() then
        return 100
    end
    return 0
end

local function CourierExecute(botBrain)
    return core.OrderAbility(botBrain, skills.courier)
end

behaviorLib.CourierBehavior = {}
behaviorLib.CourierBehavior["Execute"] = CourierExecute
behaviorLib.CourierBehavior["Utility"] = CourierUtility
behaviorLib.CourierBehavior["Name"] = "Courier"
tinsert(behaviorLib.tBehaviors, behaviorLib.CourierBehavior)

object.illusionLib.tIllusionBehaviors["NoBehavior"] = object.illusionLib.Push
