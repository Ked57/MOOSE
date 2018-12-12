--- **AI** -- Models the process of air to ground engagement for airplanes and helicopters.
--
-- This is a class used in the @{AI_A2G_Dispatcher}.
-- 
-- ===
-- 
-- ### Author: **FlightControl**
-- 
-- ===       
--
-- @module AI.AI_A2G_CAS
-- @image AI_Air_To_Ground_Engage.JPG



--- @type AI_A2G_CAS
-- @extends AI.AI_A2G_Engage#AI_A2G_Engage


--- Implements the core functions to intercept intruders. Use the Engage trigger to intercept intruders.
-- 
-- ===
-- 
-- @field #AI_A2G_CAS
AI_A2G_CAS = {
  ClassName = "AI_A2G_CAS",
}



--- Creates a new AI_A2G_CAS object
-- @param #AI_A2G_CAS self
-- @param Wrapper.Group#GROUP AIGroup
-- @return #AI_A2G_CAS
function AI_A2G_CAS:New( AIGroup, EngageMinSpeed, EngageMaxSpeed )

  -- Inherits from BASE
  local self = BASE:Inherit( self, AI_A2G_ENGAGE:New( AIGroup, EngageMinSpeed, EngageMaxSpeed ) ) -- #AI_A2G_CAS

  return self
end


--- @param #AI_A2G_CAS self
-- @param Wrapper.Group#GROUP DefenderGroup The GroupGroup managed by the FSM.
-- @param #string From The From State string.
-- @param #string Event The Event string.
-- @param #string To The To State string.
function AI_A2G_CAS:onafterEngage( DefenderGroup, From, Event, To, AttackSetUnit )

  self:F( { DefenderGroup, From, Event, To, AttackSetUnit} )
  
  local DefenderGroupName = DefenderGroup:GetName()

  self.AttackSetUnit = AttackSetUnit or self.AttackSetUnit -- Core.Set#SET_UNIT
  
  local AttackCount = self.AttackSetUnit:Count()
  
  if AttackCount > 0 then

    if DefenderGroup:IsAlive() then

      -- Determine the distance to the target.
      -- If it is less than 10km, then attack without a route.
      -- Otherwise perform a route attack.

      local DefenderCoord = DefenderGroup:GetCoordinate()
      local TargetCoord = self.AttackSetUnit:GetFirst():GetCoordinate()
      
      local TargetDistance = DefenderCoord:Get2DDistance( TargetCoord )
      
      local EngageRoute = {}

      local ToTargetSpeed = math.random( self.EngageMinSpeed, self.EngageMaxSpeed )
      
      --- Calculate the target route point.
      
      local FromWP = DefenderCoord:WaypointAir( 
        self.PatrolAltType, 
        POINT_VEC3.RoutePointType.TurningPoint, 
        POINT_VEC3.RoutePointAction.TurningPoint, 
        ToTargetSpeed, 
        true 
      )
      
      EngageRoute[#EngageRoute+1] = FromWP

      local ToCoord = self.AttackSetUnit:GetFirst():GetCoordinate()
      self:SetTargetDistance( ToCoord ) -- For RTB status check
      
      local FromEngageAngle = ToCoord:GetAngleDegrees( ToCoord:GetDirectionVec3( DefenderCoord ) )
      
      --- Create a route point of type air.
      local ToWP = ToCoord:Translate( 10000, FromEngageAngle ):WaypointAir( 
        self.PatrolAltType, 
        POINT_VEC3.RoutePointType.TurningPoint, 
        POINT_VEC3.RoutePointAction.TurningPoint, 
        ToTargetSpeed, 
        true 
      )
  
      self:F( { Angle = FromEngageAngle, ToTargetSpeed = ToTargetSpeed } )
      self:F( { self.EngageMinSpeed, self.EngageMaxSpeed, ToTargetSpeed } )
      
      EngageRoute[#EngageRoute+1] = ToWP
      
      local AttackTasks = {}
  
      for AttackUnitID, AttackUnit in pairs( self.AttackSetUnit:GetSet() ) do
        if AttackUnit:IsAlive() and AttackUnit:IsGround() then
          self:T( { "Eliminating Unit:", AttackUnit:GetName() } )
          AttackTasks[#AttackTasks+1] = DefenderGroup:TaskAttackUnit( AttackUnit )
        end
      end
        
      if #AttackTasks == 0 then
        self:E( DefenderGroupName .. ": No targets found -> Going RTB")
        self:Return()
        self:__RTB( 0.5 )
      else
        DefenderGroup:OptionROEOpenFire()
        DefenderGroup:OptionROTEvadeFire()

        AttackTasks[#AttackTasks+1] = DefenderGroup:TaskFunction( "AI_A2G_ENGAGE.EngageRoute", self )
        EngageRoute[#EngageRoute].task = DefenderGroup:TaskCombo( AttackTasks )
      end
      
      DefenderGroup:Route( EngageRoute, 0.5 )
    end
  else
    self:E( DefenderGroupName .. ": No targets found -> Going RTB")
    self:Return()
    self:__RTB( 0.5 )
  end
end

