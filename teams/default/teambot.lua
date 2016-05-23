local _G = getfenv(0)
local object = _G.object

runfile 'bots/teambot/teambotbrain.lua'

local core = object.core

object.myName = 'Default Team'

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

local unitTeamTarget = nil

function object:GetTeamTarget()
  if unitTeamTarget and unitTeamTarget:IsValid() then
    if self:CanSeeUnit(unitTeamTarget) then
      return self:GetMemoryUnit(unitTeamTarget)
    else
      unitTeamTarget = nil
    end
  end
  return nil
end

function object:SetTeamTarget(target)
  local old = self:GetTeamTarget()
  if old then
    local basePos = core.allyMainBaseStructure:GetPosition()
    if Vector3.Distance2D(basePos, old:GetPosition()) < Vector3.Distance2D(basePos, target:GetPosition()) then
      return
    end
  end
  unitTeamTarget = target
end

local STATE_IDLE      = 0
local STATE_GROUPING  = 1
local STATE_PUSHING   = 2
object.nPushState = STATE_IDLE
function object:GroupAndPushLogic()
  self:BuildLanes()
  self.nPushState = STATE_PUSHING
  self.unitPushTarget = core.enemyMainBaseStructure
end
