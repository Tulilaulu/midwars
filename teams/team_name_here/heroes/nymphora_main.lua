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
runfile "bots/teams/team_name_here/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/teams/team_name_here/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
  = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
  = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading nymphora_main...')

local illusionLib = object.illusionLib

local sqrtTwo = math.sqrt(2)

object.heroName = 'Hero_Fairy'

--------------
-- For heal --
--------------
object.vecHealPos = nil
object.nHealLastCastTime = -20000

function useHeal(botBrain, vecPosition)
	object.nHealLastCastTime = HoN.GetGameTime()
	object.vecHealPos = vecPosition
	return core.OrderAbilityPosition(botBrain, skills.heal, vecPosition)
end

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 0, ShortSolo = 0, LongSolo = 0, ShortSupport = 5, LongSupport = 5, ShortCarry = 0, LongCarry = 0}

--------------------------------
-- Items
--------------------------------

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)

	--Alternate item wasn't checked, so you don't need to look for new items.
	if core.bCheckForAlternateItems then return end

--	funcRemoveInvalidItems()

	--We only need to know about our current inventory. Stash items are not important.
	local inventory = core.unitSelf:GetInventory(true)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem and not curItem:IsRecipe() then
			if core.itemPostHaste == nil and curItem:GetName() == "Item_PostHaste" then
				core.itemPostHaste = core.WrapInTable(curItem)
			elseif core.itemTablet == nil and curItem:GetName() == "Item_PushStaff" then
				core.itemTablet = core.WrapInTable(curItem)
			elseif core.itemPortalKey == nil and curItem:GetName() == "Item_PortalKey" then
				core.itemPortalKey = core.WrapInTable(curItem)
			elseif core.itemFrostfieldPlate == nil and curItem:GetName() == "Item_FrostfieldPlate" then
				core.itemFrostfieldPlate = core.WrapInTable(curItem)
			elseif core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
				core.itemSheepstick = core.WrapInTable(curItem)
			elseif core.itemHellFlower == nil and curItem:GetName() == "Item_Silence" then
				core.itemHellFlower = core.WrapInTable(curItem)
			elseif core.itemSteamboots == nil and curItem:GetName() == "Item_Steamboots" then
				core.itemSteamboots = core.WrapInTable(curItem)
			elseif core.itemGhostMarchers == nil and curItem:GetName() == "Item_EnhancedMarchers" then
				core.itemGhostMarchers = core.WrapInTable(curItem)
				core.itemGhostMarchers.expireTime = 0
				core.itemGhostMarchers.duration = 6000
				core.itemGhostMarchers.msMult = 0.12
			end
		end
		
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

--Check for alternate items before shopping
local function funcCheckforAlternateItemBuild(botbrain)

	--no further check till next shopping round
	core.bCheckForAlternateItems = false

	local unitSelf = core.unitSelf

	--initialize item choices
	if unitSelf.getPK == nil then
		--BotEcho("Initialize item choices")
		unitSelf.getSteamboots = false
		unitSelf.getPushStaff = false
		unitSelf.getPK = false
	end


	local nGPM = botbrain:GetGPM()
	local nXPM = unitSelf:GetXPM()
	local nMatchTime = HoN.GetMatchTime()
	local bBuyStateLow = behaviorLib.buyState < behaviorLib.BuyStateMidItems

	--Bad early game: skip GhostMarchers and go for more defensive items
	if bBuyStateLow and nXPM < 170 and nMatchTime > core.MinToMS(5) and not unitSelf.getSteamboots then
		--BotEcho("My early Game sucked. I will go for a defensive Build.")
		unitSelf.getSteamboots = true
		behaviorLib.MidItems =
		{"Item_Steamboots", "Item_MysticVestments", "Item_Scarab",  "Item_SacrificialStone", "Item_Silence"}

	--Boots finished
	elseif core.itemGhostMarchers or core.itemSteamboots then

		--Mid game: Bad farm, so go for a tablet
		if unitSelf:GetLevel() > 10 and nGPM < 240 and not unitSelf.getPushStaff then
			--BotEcho("Well, it's not going as expected. Let's try a Tablet!")
			unitSelf.getPushStaff = true
			tinsert(behaviorLib.curItemList, 1, "Item_PushStaff")

		--Good farm and you finished your Boots. Now it is time to pick a portal key
		elseif nGPM >= 300 and not unitSelf.getPK then
			--BotEcho("The Game is going good. Soon I will kill them with a fresh PK!")
			unitSelf.getPK = true
			tinsert(behaviorLib.curItemList, 1, "Item_PortalKey")
		end
	end
end

behaviorLib.StartingItems =
	{"Item_TrinketOfRestoration", "Item_MinorTotem", "Item_ManaPotion", "Item_CrushingClaws"}
behaviorLib.LaneItems =
	{"Item_Marchers", "Item_MysticPotpourri", "Item_EnhancedMarchers"}
behaviorLib.MidItems =
	{"Item_Astrolabe", "Item_Morph", "Item_FrostfieldPlate"}
behaviorLib.LateItems =
	{"Item_Intelligence7", "Item_Summon"} --Intelligence7 is Staff of the Master
	
-- SHOPPING OVERRIDE FROM https://github.com/honteam/Heroes-of-Newerth-Bots/blob/Community/bots/heroes/gravekeeper_main.lua

core.bCheckForAlternateItems = true
local function funcShopExecuteOverride(botBrain)
	--check item choices
	if core.bCheckForAlternateItems then
		--BotEcho("Checking Alternate Builds")
		funcCheckforAlternateItemBuild(botBrain)
	end

	local bOldShopping = object.ShopExecuteOld (botBrain)

	--update item links and reset the check
	if behaviorLib.finishedBuying then
		core.FindItems()
		core.bCheckForAlternateItems = true
		--BotEcho("FindItems")
	end

	return bOldShopping
end
object.ShopExecuteOld = behaviorLib.ShopExecute
behaviorLib.ShopBehavior["Execute"] = funcShopExecuteOverride

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
  local unitSelf = self.core.unitSelf

  if not bSkillsValid then
    skills.heal = unitSelf:GetAbility(0)
    skills.mana = unitSelf:GetAbility(1)
    skills.stun = unitSelf:GetAbility(2)
    skills.ulti = unitSelf:GetAbility(3)
    skills.attributeBoost = unitSelf:GetAbility(4)

    if skills.heal and skills.mana and skills.stun and skills.ulti and skills.attributeBoost then
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
  elseif skills.heal:CanLevelUp() then
    skills.heal:LevelUp()
  elseif skills.mana:CanLevelUp() then
    skills.mana:LevelUp()
  elseif skills.stun:CanLevelUp() then
    skills.stun:LevelUp()
  else
    skills.attributeBoost:LevelUp()
  end
end


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

  -- custom code here
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

BotEcho('finished loading nymphora_main')
