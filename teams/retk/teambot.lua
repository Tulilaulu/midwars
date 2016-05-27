local _G = getfenv(0)
local object = _G.object

runfile 'bots/teams/retk/teambotbrain.lua'
runfile "bots/teams/retk/utils.lua"

local core, metadata = object.core, object.metadata

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, asin, min, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.asin, _G.math.min, _G.math.max, _G.math.random

object.myName = 'RETK'

local legionA = Vector3.Create(6125, 7747)
local legionB = Vector3.Create(7365, 6450)
local legionDir = Vector3.Normalize(legionB - legionA)
local legionK = legionDir.y / legionDir.x
local legionLineA = legionA - legionA.x * legionDir
local legionLineB = legionLineA + legionDir * (15000 / legionDir.x)

local hellbourneA = Vector3.Create(8060, 8650)
local hellbourneB = Vector3.Create(9280, 7600)
local hellbourneDir = Vector3.Normalize(hellbourneB - hellbourneA)
local hellbourneK = hellbourneDir.y / hellbourneDir.x
local hellbourneLineA = hellbourneA - hellbourneA.x * hellbourneDir
local hellbourneLineB = hellbourneLineA + hellbourneDir * (15000 / hellbourneDir.x)

local function InEnemyTerritory(pos)
    local ret
    if core.myTeam == HoN.GetLegionTeam() then
        local ny = hellbourneLineA.y + hellbourneK * (pos.x - legionLineA.x)
        ret = pos.y > ny
        -- drawLine(pos, Vector3.Create(pos.x, ny), 'white')
    else
        local ny = legionLineA.y + legionK * (pos.x - legionLineA.x)
        ret = pos.y < ny
        -- drawLine(pos, Vector3.Create(pos.x, ny), 'white')
    end
    return ret
end

local function FindClosestHeroToEnemyBaseExcept(heroes)
    local basePos = core.enemyMainBaseStructure:GetPosition()
    local closestDist = 30000 * 30000
    local closestHero = nil
    for i, unit in pairs(object.tAllyHeroes) do
        local already = not unit:IsAlive()
        for _, existingUnit in pairs(heroes) do
            if existingUnit:GetUniqueID() == unit:GetUniqueID() then
                already = true
                break
            end
        end

        if not already then
            local dist = Vector3.Distance2D(basePos, unit:GetPosition())
            if dist < closestDist then
                closestDist = dist
                closestHero = unit
            end
        end
    end
    return closestHero
end

function object:ClusterHeroes()
    local center = nil
    local cluster = {}
    local madeChanges = true
    while madeChanges do
        local closestHero = FindClosestHeroToEnemyBaseExcept(cluster)
        if not closestHero then
            return cluster, center
        end

        madeChanges = false
        if not center then
            tinsert(cluster, closestHero)
            center = closestHero:GetPosition()
            madeChanges = true
        else
            local newCluster = core.CopyTable(cluster)
            tinsert(newCluster, closestHero)
            local newCenter = core.FindCenterOfMass(newCluster)
            local ok = true
            for _, other in pairs(newCluster) do
                if Vector3.Distance2D(newCenter, other:GetPosition()) > 1000 then
                    ok = false
                    break
                end
            end
            if ok then
                cluster = newCluster
                center = newCenter
                madeChanges = true
            end
        end
    end
    return cluster, center
end

function object:GetRallyPosition()
    local aliveHeroes = {}
    for k, unit in pairs(object.tAllyHeroes) do
        if unit:IsAlive() then
            aliveHeroes[k] = unit
        end
    end
    return core.FindCenterOfMass(aliveHeroes)
end

------------------------------------------------------
--            onthink override                      --
-- Called every bot tick, custom onthink code here  --
------------------------------------------------------
-- @param: tGameVariables
-- @return: none
function object:onthinkOverride(tGameVariables)
    self:onthinkOld(tGameVariables)

    drawLine(legionLineA, legionLineB)
    drawLine(hellbourneLineA, hellbourneLineB)
    local cluster, center = object:ClusterHeroes()
    local nearEnemies = false
    if InEnemyTerritory(center) then
        nearEnemies = true
        drawCross(center, 'red')
    else
        drawCross(center, 'yellow')
    end
    local ownLevelSum = 0
    local ownCount = 0
    for _, unit in pairs(cluster) do
        drawLine(center, unit:GetPosition(), 'green')
        ownLevelSum = ownLevelSum + unit:GetLevel()
        ownCount = ownCount + 1
    end

    local enemyLevelSum = 0
    local enemyCount = 0
    for _, unit in pairs(object.tEnemyHeroes) do
        if unit:IsAlive() then
            enemyLevelSum = enemyLevelSum + unit:GetLevel()
            enemyCount = enemyCount + 1
        end
    end
    --Echo("Own cluster: " .. ownCount .. ", enemies alive: " .. enemyCount .. ", in enemy territory: " .. tostring(nearEnemies) .. ", group: " .. tostring(shouldGroup))
    local shouldGroup = nearEnemies and ownCount < enemyCount
    object.ourCluster = cluster
    object.ourClusterCount = ownCount
    object.ourClusterCenter = center
    object.ourClusterInEnemyTerritory = nearEnemies
    object.enemiesAlive = enemyCount
    if shouldGroup then
        -- Echo("grouping")
        object.plzGroup = true
    else
        -- Echo("not grouping")
        object.plzGroup = false
    end
end
object.onthinkOld = object.onthink
object.onthink = object.onthinkOverride
