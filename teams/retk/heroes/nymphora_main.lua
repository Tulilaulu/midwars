
local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic 		= true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true
object.bMoveCommands 	= true
object.bAttackCommands 	= true
object.bAbilityCommands = true
object.bOtherCommands 	= true

object.bReportBehavior = false
object.bDebugUtility = false
object.bDebugExecute = false


object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core 		= {}
object.eventsLib 	= {}
object.metadata 	= {}
object.behaviorLib 	= {}
object.skills 		= {}

object.heroName = 'Hero_Fairy'

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

local illusionLib = object.illusionLib

local sqrtTwo = math.sqrt(2)

BotEcho('loading nymphora_main...')

---------------
--  Globals  --
---------------
-- Constants --
---------------
--   items   --
---------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 5, LongSupport = 5, ShortCarry = 1, LongCarry = 1}

--behaviorLib.StartingItems =	{"Item_MerricksBounty", "Item_TrinketOfRestoration", "Item_MinorTotem", "Item_CrushingClaws"}
behaviorLib.StartingItems = {"Item_MerricksBounty", "Item_ManaBattery", "Item_GuardianRing", "Item_MinorTotem", "Item_ManaRegen3"}  --Item: Bounty, mana battery, guardian ring->ring of the teacher, minor totem
behaviorLib.LaneItems =
	{"Item_Marchers", "Item_TrinketOfRestoration", "Item_MysticPotpourri", "Item_MysticVestments", "Item_NomesWisdom", "Item_MinorTotem",  "Item_PlatedGreaves", "Item_Strength5"} --boots, trinket -> refreshing ornament, push boots, Fortified Bracer
behaviorLib.MidItems =
	{"Item_Astrolabe", "Item_Beastheart", "Item_Glowstone", "Item_HealthMana2", "Item_Morph"}
behaviorLib.LateItems =
	{"Item_AxeOfTheMalphai", "Item_BehemothsHeart"} 


behaviorLib.printShopDebug = false

-- Thresholds --
object.nStunThreshold = 35
object.nHealThreshold = 35

object.nSheepstickThreshold = 30
object.nFrostfieldThreshold = 40
object.nPuzzleThreshold = 30

-- Ability up bonuses --
object.nStunUp = 10
object.nHealUp = 5

object.nSheepstickUp = 15
object.nFrostfieldUp = 5

--------------------
-- For skillbuild --
--------------------
object.nManaNeeded = 0
object.nHealNeeded = 0

--------------
-- For heal --
--------------
object.vecHealPos = nil
object.nHealLastCastTime = -20000

-- misc --
behaviorLib.bTPWithNymph = false -- Don't try to tp with yourself

local function AbilitiesUpUtility(hero)
	local nUtility = 0
        local unitTarget = behaviorLib.heroTarget
        if not unitTarget or not unitTarget:IsValid() or not bSkillsValid then
            return 0 --can not execute, move on to the next behavior
        end
        local ms = unitTarget:GetMoveSpeed() or 0
        local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or ms < 200
	
	if skills.heal:CanActivate() then
		nUtility = nUtility + object.nHealUp
	end
	
	if skills.stun:CanActivate() then
		nUtility = nUtility + object.nStunUp
	end
	
	local itemSheepstick = core.GetItem("Item_Morph")
	if itemSheepstick ~= nil and itemSheepstick:CanActivate() and not bTargetRooted then
		nUtility = nUtility + object.nSheepstickUp
	end

	local itemFrostfieldPlate = core.GetItem("Item_FrostfieldPlate")
	if itemFrostfieldPlate ~= nil and itemFrostfieldPlate:CanActivate() then
		nUtility = nUtility + object.nFrostfieldUp
	end
	
	return nUtility
end

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)


	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		-- No use bonuses. Add up bonuses to not drop aggro as skills are no longer 'up'
		if EventData.InflictorName == "Ability_Fairy1" then
			nAddBonus = nAddBonus + object.nHealUp
		elseif EventData.InflictorName == "Ability_Fairy3" then
			nAddBonus = nAddBonus + object.nStunUp
		end
	elseif EventData.Type == "Item" then
		if EventData.SourceUnit == core.unitSelf:GetUniqueID() then
			if EventData.InflictorName == "Item_Morph" then
				nAddBonus = nAddBonus + object.nSheepstickUp
			elseif EventData.InflictorName == "Item_FrostfieldPlate" then
				nAddBonus = nAddBonus + object.nFrostfieldUp
			end
		end
	end
	
	if nAddBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	if skills.heal == nil then
		skills.heal		= unitSelf:GetAbility(0)
		skills.mana		= unitSelf:GetAbility(1)
		skills.stun		= unitSelf:GetAbility(2)
		skills.teleport	= unitSelf:GetAbility(3)
		skills.recall	= unitSelf:GetAbility(5)
                skills.taunt = unitSelf:GetAbility(8)
                skills.courier = unitSelf:GetAbility(12)
	end

	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end

	for i = 0, unitSelf:GetAbilityPointsAvailable(), 1 do
		local bAbilityLeveled = false
		--if skills.teleport:CanLevelUp() then
		--	skills.teleport:LevelUp()
		--	bAbilityLeveled = true
		--else
		if (self.nHealNeeded > 1 and skills.heal:CanLevelUp()) or (self.nManaNeeded > 1 and skills.mana:CanLevelUp()) or
			(not skills.stun:CanLevelUp() and (skills.heal:CanLevelUp() or skills.mana:CanLevelUp())) then
			if self.nHealNeeded >= self.nManaNeeded and skills.heal:CanLevelUp() or not skills.mana:CanLevelUp() then
				skills.heal:LevelUp()
				self.nHealNeeded = self.nHealNeeded - 1
				--self.nHealNeeded = 0
			else
				skills.mana:LevelUp()
				self.nManaNeeded = self.nManaNeeded - 1
				--self.nManaNeeded = 0
			end
			bAbilityLeveled = true
		elseif skills.stun:CanLevelUp() then
			skills.stun:LevelUp()
			bAbilityLeveled = true
		end
		if not bAbilityLeveled then
			unitSelf:GetAbility(4):LevelUp()
			bAbilityLeveled = true
		end
		if not bAbilityLeveled and skills.teleport:CanLevelUp() then
			skills.teleport:LevelUp()
		end
	end
end

function useHeal(botBrain, vecPosition)
	object.nHealLastCastTime = HoN.GetGameTime()
	object.vecHealPos = vecPosition
	return core.OrderAbilityPosition(botBrain, skills.heal, vecPosition)
end

behaviorLib.SupportBehavior = {}

-- Base 10
-- 0.5 for every missing % of hp or mana
-- Max 60 at 0% of hp or mana
function behaviorLib.SupportUtility(botBrain)
	local unitSelf = core.unitSelf

	local allyHeroes = core.CopyTable(core.localUnits.AllyHeroes)
	allyHeroes[unitSelf:GetUniqueID()] = unitSelf

	local sType = ""
	local nUtility = 0
	local unitTarget = nil

	local bCanGiveMana = skills.mana:CanActivate()
	local bCanHeal = skills.heal:CanActivate()

	for _, hero in pairs(allyHeroes) do
		local mana = hero:GetManaPercent()
		object.nManaNeeded = object.nManaNeeded + (1 - mana) / 150
		local newUtility = 10 + (1 - mana) * 100 / 2
		if bCanGiveMana and newUtility > nUtility then
			nUtility = newUtility
			sType = "mana"
			unitTarget = hero
		end

		local hp = hero:GetHealthPercent()
		object.nHealNeeded = object.nHealNeeded + (1 - hp) / 140
		local newUtility = 10 + (1 - hp) * 100 / 2
		if bCanHeal and newUtility > nUtility then
			nUtility = newUtility
			sType = "heal"
			unitTarget = hero
		end
	end
	behaviorLib.SupportBehavior.sType = sType
	behaviorLib.SupportBehavior.unitTarget = unitTarget
	return nUtility
end

function behaviorLib.SupportExecute(botBrain)
	if behaviorLib.SupportBehavior.sType == "mana" then
		return core.OrderAbilityEntity(botBrain, skills.mana, behaviorLib.SupportBehavior.unitTarget)
	end
	if behaviorLib.SupportBehavior.sType == "heal" then
		local unitTarget = behaviorLib.SupportBehavior.unitTarget
		local vecTargetPos = unitTarget:GetPosition() + unitTarget:GetHeading() * unitTarget:GetMoveSpeed() * 3 / 4
		return useHeal(botBrain, behaviorLib.SupportBehavior.unitTarget:GetPosition())
	end

	return false
end

behaviorLib.SupportBehavior["Utility"] = behaviorLib.SupportUtility
behaviorLib.SupportBehavior["Execute"] = behaviorLib.SupportExecute
behaviorLib.SupportBehavior["Name"] = "Nymphora supprot"
tinsert(behaviorLib.tBehaviors, behaviorLib.SupportBehavior)


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

    return 0
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

-----------
-- Fight --
-----------
function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end

	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()

	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)

	local nLastHarassUtil = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)
        local ms = unitTarget:GetMoveSpeed() or 0
        local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or ms < 200

	local vecPosInHalfSec = vecTargetPosition
	if bCanSee then
		local vecPosInHalfSec = vecTargetPosition + unitTarget:GetHeading() * unitTarget:GetMoveSpeed() / 2
	end

	local bActionTaken = false

	if nLastHarassUtil > object.nStunThreshold and skills.stun:CanActivate() then
		if nTargetDistanceSq < 900 * 900 then
			bActionTaken = core.OrderAbilityPosition(botBrain, skills.stun, vecPosInHalfSec)
		end
	end
	if not bActionTaken then
		if nLastHarassUtil > object.nHealThreshold and skills.heal:CanActivate() then
			if nTargetDistanceSq < 750 * 750 then
				bActionTaken = useHeal(botBrain, vecPosInHalfSec)
			end
		end
	end
	if not bActionTaken then
		if bCanSee then
			local itemSheepstick = core.GetItem("Item_Morph")
			if itemSheepstick then
				local nRange = itemSheepstick:GetRange()
				if itemSheepstick:CanActivate() and nLastHarassUtil > object.nSheepstickThreshold and not bTargetRooted and unitTarget:GetHealthPercent() > 0.3 then
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
					end
				end
			end
		end
	end
	if not bActionTaken then
		local itemFreeze = core.GetItem("Item_Freeze")
		if itemFreeze ~= nil and itemFreeze:CanActivate() then
			if nLastHarassUtil > object.nFrostfieldThreshold then
				local nRangeSQ = 700 * 700
				if nRangeSQ > nTargetDistanceSq then
					botBrain:OrderItem(itemFreeze.object, "None")
					bActionTaken = true
				end
			end
		end
	end
	if not bActionTaken then
		local itemPuzzleBox = core.GetItem("Item_Summon")
		if itemPuzzleBox and itemPuzzleBox:CanActivate() then
			if nLastHarassUtil > object.nPuzzleThreshold then
				botBrain:OrderItem(itemPuzzleBox.object, "None")
				bActionTaken = true
			end
		end
	end
	--- Plated Greaves use here
	if not bActionTaken then
		local itemGreaves = core.GetItem("Item_PlatedGreaves")
		if itemGreaves and itemGreaves:CanActivate() then
			--p(core.NumberElements(core.localUnits["AllyHeroes"]))
			if (core.NumberElements(core.localUnits["AllyHeroes"]) ~= 0 and core.NumberElements(core.localUnits["EnemyHeroes"])) or core.NumberElements(core.localUnits["AllyCreeps"]) > 3 then
				botBrain:OrderItem(itemGreaves.object, "None")
				--p(core.NumberElements(core.localUnits["AllyCreeps"]))
				bActionTaken = true
			end
		end
	end
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

------------
-- Escape --
------------
function behaviorLib.CustomRetreatExecute(botBrain)
	local unitSelf = core.unitSelf
	local vecMyPos = unitSelf:GetPosition()

	local bActionTaken = false

	if behaviorLib.lastRetreatUtil > object.nStunThreshold and skills.stun:CanActivate() then
		if core.NumberElements(core.localUnits.EnemyHeroes) > 0 then
			local unitTarget = nil
			local nClosestDistance = 999999999
			for _, unit in pairs(core.localUnits.EnemyHeroes) do
				local nDistance2DSq = Vector3.Distance2DSq(vecMyPos, unit:GetPosition())
				if nDistance2DSq < nClosestDistance then
					unitTarget = unit
					nClosestDistance = nDistance2DSq
				end
			end

			bActionTaken = core.OrderAbilityPosition(botBrain, skills.stun, unitTarget:GetPosition())
		end
	end

	return bActionTaken
end

----------
-- Push --
----------
function behaviorLib.customPushExecute(botBrain)
	local unitSelf = core.unitSelf

	bActionTaken = false

	if unitSelf:GetManaPercent() > 0.7 then
		local tCreeps = core.CopyTable(core.localUnits["EnemyCreeps"])
		core.InsertToTable(tCreeps, core.localUnits["AllyCreeps"])

		local vecCenterOfCreeps, nCreeps = core.GetGroupCenter(tCreeps)
		--local centerOfCreeps = core.AoETargeting(unitSelf, skills.heal:GetRange(), 300, true, nil, nil, nil)
		if nCreeps > 4 and vecCenterOfCreeps ~= nil then
			if skills.heal:CanActivate() then
				bActionTaken = useHeal(botBrain, vecCenterOfCreeps)
			end
			if not bActionTaken then
				if skills.stun:CanActivate() then
					bActionTaken = core.OrderAbilityPosition(botBrain, skills.stun, vecCenterOfCreeps)
				end
			end
		end
	end

	return bActionTaken
end

--heal
function behaviorLib.getHealedUtility(botBrain)
	local nTime = HoN.GetGameTime()
	if nTime - 1100 < object.nHealLastCastTime then
		local unitSelf = core.unitSelf
		local teammembers = core.localUnits["AllyHeroes"]
		local isTeamLowHealth = false
		for _, hero in pairs(teammembers) do
			if hero.GetHealthPercent() < 0.7 then
				isTeamLowHealth = true
			end
		end
	--	p(teammembers)	
		if unitSelf:GetHealthPercent() < 0.7 or isTeamLowHealth then
			local nDistance = Vector3.Distance2D(unitSelf:GetPosition(), object.vecHealPos) - 300
			if nDistance < unitSelf:GetMoveSpeed() * (nTime - object.nHealLastCastTime) / 1000 then
				return 40
			end
		end
	end
	return 0
end

function behaviorLib.getHealedExecute(botBrain)
	return core.OrderMoveToPos(botBrain, core.unitSelf, object.vecHealPos)
end

behaviorLib.getHealedBehavior = {}
behaviorLib.getHealedBehavior["Utility"] = behaviorLib.getHealedUtility
behaviorLib.getHealedBehavior["Execute"] = behaviorLib.getHealedExecute
behaviorLib.getHealedBehavior["Name"] = "Nymphora get healed"
tinsert(behaviorLib.tBehaviors, behaviorLib.getHealedBehavior)

---------------
-- PuzzleBox --
---------------

-- IllusionLib orders it to attack and move around
function illusionLib.updateIllusions(botBrain)
	illusionLib.tIllusions = {}
	local tPossibleIllusions = core.tControllableUnits["AllUnits"]
	if tPossibleIllusions ~= nil then
		for nUID, unit in pairs(tPossibleIllusions) do
			local sTypeName = unit:GetTypeName()
			if sTypeName ~= "Pet_GroundFamiliar" and sTypeName ~= "Pet_FlyngCourier" then
				tinsert(illusionLib.tIllusions, unit)
			end
		end
	end
end
