local ScenarioFramework = import('/lua/ScenarioFramework.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local ThisFile = '/maps/NovaxStationAssault/NovaxStationAssault_m1orderai.lua'

---------
-- Locals
---------
local Order = 3
local Difficulty = ScenarioInfo.Options.Difficulty

----------
-- Carrier
----------
function OrderCarrierFactory()
    -- Adding build location for AI
	ArmyBrains[Order]:PBMAddBuildLocation('M1_Order_Carrier_Start_Marker', 150, 'AircraftCarrier1')

	local Carrier = ScenarioInfo.M1_Order_Carrier
	local location
    for num, loc in ArmyBrains[Order].PBM.Locations do
        if loc.LocationType == 'AircraftCarrier1' then
            location = loc
            OrderCarrierAttacks()
            break
        end
    end
	location.PrimaryFactories.Air = Carrier
	
	while (ScenarioInfo.MissionNumber == 1 and Carrier and not Carrier:IsDead()) do
        if  table.getn(Carrier:GetCargo()) > 0 and Carrier:IsIdleState() then
            IssueClearCommands({Carrier})
            IssueTransportUnload({Carrier}, Carrier:GetPosition())
        end
        WaitSeconds(1)
    end
end

-- Platoons built by carrier
function OrderCarrierAttacks()
	local torpBomberNum = {6, 4, 3}
    local swiftWindNum = {7, 5, 4}
    local gunshipNum = {8, 6, 5}

    local Temp = {
        'M1_Order_Carrier_Air_Attack_1',
        'NoPlan',
        { 'uaa0204', 1, torpBomberNum[Difficulty], 'Attack', 'AttackFormation' }, -- T2 Torp Bomber
        { 'xaa0202', 1, swiftWindNum[Difficulty], 'Attack', 'AttackFormation' }, -- Swift Wind
        { 'uaa0203', 1, gunshipNum[Difficulty], 'Attack', 'AttackFormation' }, -- T2 Gunship
        { 'uaa0101', 1, 6, 'Attack', 'AttackFormation' }, -- T1 Scout
    }
    local Builder = {
        BuilderName = 'M1_Order_Carrier_Air_Builder_1',
        PlatoonTemplate = Temp,
        InstanceCount = 1,
        Priority = 100,
        PlatoonType = 'Air',
        RequiresConstruction = true,
        LocationType = 'AircraftCarrier1',
        PlatoonAIFunction = {ThisFile, 'GivePlatoonToPlayer'},
        PlatoonData = {
            PatrolChain = 'M1_Oder_Naval_Def_Chain',
        },      
    }
    ArmyBrains[Order]:PBMAddPlatoon( Builder )
end

----------
-- Tempest
----------
function OrderTempestFactory()
    ArmyBrains[Order]:PBMAddBuildLocation('M1_Order_Tempest_Start_Marker', 150, 'Tempest1')

    local Tempest = ScenarioInfo.M1_Order_Tempest
    local location
    for num, loc in ArmyBrains[Order].PBM.Locations do
        if loc.LocationType == 'Tempest1' then
            location = loc
            OrderTempestAttacks()
            break
        end
    end
    location.PrimaryFactories.Sea = Tempest
end

function OrderTempestAttacks()
    local destroyerNum = {3, 2, 1}
    local frigateNum = {7, 5, 3}
    local aaBoatNum = {8, 6, 2}

    local Temp = {
        'M1_Order_Tempest_Naval_Attack_1',
        'NoPlan',
        { 'uas0201', 1, 1, 'Attack', 'AttackFormation' },  -- Destroyer
        { 'uas0103', 1, 3, 'Attack', 'AttackFormation' },  -- Frigate
        { 'uas0102', 1, 1, 'Attack', 'AttackFormation' },  -- AA Boat
    }
    local Builder = {
        BuilderName = 'M1_Order_Tempest_Naval_Builder_1',
        PlatoonTemplate = Temp,
        InstanceCount = 1,
        Priority = 100,
        PlatoonType = 'Sea',
        RequiresConstruction = true,
        LocationType = 'Tempest1',
        PlatoonAIFunction = {ThisFile, 'MoveAndGivePlatoonToPlayer'},
        PlatoonData = {
            MoveRoute = {'Rally Point 05'},
            PatrolChain = 'M1_Oder_Naval_Def_Chain',
        },    
    }
    ArmyBrains[Order]:PBMAddPlatoon( Builder )
end

-----------------------
-- Platoon AI Functions
-----------------------
function GivePlatoonToPlayer(platoon)
    local givenUnits = {}
    local data = platoon.PlatoonData

	for _, unit in platoon:GetPlatoonUnits() do
        while (not unit:IsDead() and unit:IsUnitState('Attached')) do
            WaitSeconds(1)
        end
        local tempUnit
        if ScenarioInfo.HumanPlayers[2] then
            tempUnit = ScenarioFramework.GiveUnitToArmy(unit, 'Player2')
        else
            tempUnit = ScenarioFramework.GiveUnitToArmy(unit, 'Player1')
        end
        table.insert(givenUnits, tempUnit)
    end

    if data.PatrolChain then
        ScenarioFramework.GroupPatrolChain(givenUnits, data.PatrolChain)
    end
end

function MoveAndGivePlatoonToPlayer(platoon)
    local givenUnits = {}
    local data = platoon.PlatoonData

    if(data) then
        if(data.MoveRoute or data.MoveChain) then
            local movePositions = {}
            if data.MoveChain then
                movePositions = ScenarioUtils.ChainToPositions(data.MoveChain)
            else
                for k, v in data.MoveRoute do
                    if type(v) == 'string' then
                        table.insert(movePositions, ScenarioUtils.MarkerToPosition(v))
                    else
                        table.insert(movePositions, v)
                    end
                end
            end
            if(data.UseTransports) then
                for k, v in movePositions do
                    platoon:MoveToLocation(v, data.UseTransports)
                end
            else
                for k, v in movePositions do
                    platoon:MoveToLocation(v, false)
                end
            end
        else
            error('*SCENARIO PLATOON AI ERROR: MoveToRoute or MoveChain not defined', 2)
        end
    else
        error('*SCENARIO PLATOON AI ERROR: PlatoonData not defined', 2)
    end

    WaitSeconds(1)

    for _, unit in platoon:GetPlatoonUnits() do
        while (not unit:IsDead() and unit:IsUnitState('Moving')) do
            WaitSeconds(1)
        end
        local tempUnit = ScenarioFramework.GiveUnitToArmy(unit, 'Player1')
        table.insert(givenUnits, tempUnit)
    end

    if data.PatrolChain then
        ScenarioFramework.GroupPatrolChain(givenUnits, data.PatrolChain)
    end
end