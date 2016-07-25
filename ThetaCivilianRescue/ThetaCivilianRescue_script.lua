-- ****************************************************************************
-- **
-- **  File     : /maps/ThetaCivilianRescue/ThetaCivilianRescue_script.lua
-- **  Author(s): KeyBlue
-- **
-- **  Summary  : Main mission flow script for ThetaCivilianRescue
-- **
-- ****************************************************************************
local Cinematics = import('/lua/cinematics.lua')
local M1CybranAI = import('/maps/ThetaCivilianRescue/ThetaCivilianRescue_m1cybranai.lua')
local M2CybranAI = import('/maps/ThetaCivilianRescue/ThetaCivilianRescue_m2cybranai.lua')
local Objectives = import('/lua/ScenarioFramework.lua').Objectives
local ScenarioFramework = import('/lua/ScenarioFramework.lua')
local ScenarioPlatoonAI = import('/lua/ScenarioPlatoonAI.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local Utilities = import('/lua/Utilities.lua')
local OpStrings = import('/maps/ThetaCivilianRescue/ThetaCivilianRescue_strings.lua')
local TCRUtil = import('/maps/ThetaCivilianRescue/ThetaCivilianRescue_CustomFunctions.lua')

----------
-- Globals
----------
ScenarioInfo.Player = 1
ScenarioInfo.Cybran = 2
ScenarioInfo.Coop1 = 3
ScenarioInfo.Coop2 = 4
ScenarioInfo.Coop3 = 5

ScenarioInfo.hasMonkeylordSpawned = false

---------
-- Locals
---------
local Player = ScenarioInfo.Player
local Cybran = ScenarioInfo.Cybran
local Coop1 = ScenarioInfo.Coop1
local Coop2 = ScenarioInfo.Coop2
local Coop3 = ScenarioInfo.Coop3


local AssignedObjectives = {}
local Difficulty = ScenarioInfo.Options.Difficulty

local M1MapExpandDelay = {30*60, 25*60, 20*60} --30*60, 25*60, 20*60
local M2SpawnMonkeylordTime = {60*60, 45*60, 35*60} --60*60, 45*60, 35*60
local M2SpawnExperimentalsTime = {20*60, 10*60, 5*60} --20*60, 10*60, 5*60
local prematureMonkeyUnitCount = {125,100,75,50} --{125,100,75,50}
local killedExp = 0
local prematureMonkeylordPreparationTime = 60 --60

--------------
-- Debug only!
--------------
local Debug = false
local SkipNIS1 = false
local SkipMission1 = false

---------
-- Startup
---------
function OnPopulate(scenario)
    ScenarioUtils.InitializeScenarioArmies()
	
    -- Sets Army Colors
    ScenarioFramework.SetUEFPlayerColor(Player)
    ScenarioFramework.SetCybranPlayerColor(Cybran)
	local colors = {
		['Coop1'] = {81, 82, 241}, --SetUEFAlly1Color
		['Coop2'] = {133, 148, 255}, --SetUEFAlly2Color
		['Coop3'] = {71, 114, 148} --SetUEFAllyColor
		}	
    local tblArmy = ListArmies()
    for army, color in colors do
        if tblArmy[ScenarioInfo[army]] then
            ScenarioFramework.SetArmyColor(ScenarioInfo[army], unpack(color))
        end
    end
	
	for index,_ in ScenarioInfo.HumanPlayers do
		ScenarioInfo.NumberOfPlayers = index
	end
	
	
end



function OnStart(self)
	ScenarioUtils.CreateArmyGroup('Player', 'signature', true)

	for _, player in ScenarioInfo.HumanPlayers do
	-- Build Restrictions
		ScenarioFramework.AddRestriction(player, mainRestrictions())
		
		ScenarioFramework.AddRestriction(player, cybranRestrictions())
    
	end
	
	-- Lock off cdr upgrades
	ScenarioFramework.RestrictEnhancements({'ResourceAllocation',
											'DamageStablization',
											'T3Engineering',
											'LeftPod',
											'RightPod',
											'Shield',
											'ShieldGeneratorField',
											'TacticalMissile',
											'TacticalNukeMissile',
											'Teleporter'})
	
	
	
	-- Create Restriction Removal building
	--[[ScenarioInfo.RestrictionRemoval = ScenarioUtils.CreateArmyUnit('Neutral', 'RestrictionRemoval')
    ScenarioInfo.RestrictionRemoval:SetDoNotTarget(true)
    ScenarioInfo.RestrictionRemoval:SetCanTakeDamage(false)
    ScenarioInfo.RestrictionRemoval:SetCanBeKilled(false)
    ScenarioInfo.RestrictionRemoval:SetReclaimable(false)
    ScenarioInfo.RestrictionRemoval:SetCustomName("Remove Restrictions")
	
	ScenarioFramework.CreateUnitCapturedTrigger( RemoveAllRestrictions, nil, ScenarioInfo.RestrictionRemoval ) ]]--
	
	
	
    if Debug then
        Utilities.UserConRequest('SallyShears')
	end
	
	if not SkipMission1 then
		InitializeMission1()
	else
		ForkThread(SpawnAllACUs)
		InitializeMission2()
	end
end


function RemoveAllRestrictions()
	-- Build Restrictions

	for _, player in ScenarioInfo.HumanPlayers do
	-- Build Restrictions
		ScenarioFramework.RemoveRestriction(player, mainRestrictions())
		
		ScenarioFramework.RemoveRestriction(player, cybranRestrictions())
    
	end
	
	-- Lock off cdr upgrades
	ScenarioFramework.RestrictEnhancements({})
	
end

function mainRestrictions()
	return (categories.TECH2 
				+ categories.TECH3 
				+ categories.EXPERIMENTAL
				+ categories.NAVAL
				+ categories.TRANSPORTATION -- no transports
				- (categories.TECH2 * categories.LAND)
				-- - categories.uel0202 -- T2 tank
				-- - categories.uel0203 -- T2 amphibious tank
				-- - categories.del0204 -- T2 gatling bot
				-- - categories.uel0205 -- T2 mobile flak
				-- - categories.uel0307 -- T2 Mobile Shield Generator
				-- - categories.uel0111 -- T2 Mobile Missile Launcher
				-- - categories.ueb0201 -- T2 land HQ
				-- - categories.zeb9502 -- T2 support land
				-- - categories.uel0208 -- T2 Engineer
				-- - categories.xel0209 -- Sparky
				- categories.ueb1202 -- T2 mass
				- categories.ueb1201 -- T2 power
				- categories.ueb5202 -- T2 airstaging
				- categories.ueb3201) -- T2 radar
end

function cybranRestrictions()
	return (categories.Cybran * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL))
end

------------
-- Mission 1
------------

function InitializeMission1()
	ScenarioInfo.MissionNumber = 1
    -------------------
    -- Cybran West Base
    -------------------
	M1CybranAI.CybranM1WestBaseAI()
	
	-- Create Objective building
	ScenarioInfo.M1_Cybran_Prison = ScenarioUtils.CreateArmyUnit('Cybran', 'M1_Cybran_Prison')
    ScenarioInfo.M1_Cybran_Prison:SetDoNotTarget(true)
    ScenarioInfo.M1_Cybran_Prison:SetCanTakeDamage(false)
    ScenarioInfo.M1_Cybran_Prison:SetCanBeKilled(false)
    ScenarioInfo.M1_Cybran_Prison:SetReclaimable(false)
    ScenarioInfo.M1_Cybran_Prison:SetCustomName("Cybran Prison")
	
	
	ForkThread(IntroMission1NIS)
end

function IntroMission1NIS()

	ScenarioFramework.SetPlayableArea('M1_Area', false)
	

    if not SkipNIS1 then
	
        WaitSeconds(2)
		
        Cinematics.EnterNISMode()

        local VisMarker_West_Base = ScenarioFramework.CreateVisibleAreaLocation(500, ScenarioUtils.MarkerToPosition('NIS_M1_Vis_West_Base'), 0, ArmyBrains[Player])
		
        Cinematics.CameraMoveToMarker(ScenarioUtils.GetMarker('Cam_Start_Location'), 0)
		
        WaitSeconds(3)
		
		ScenarioFramework.Dialogue(OpStrings.M1_West_Base_View, nil, true)
		
        Cinematics.CameraMoveToMarker(ScenarioUtils.GetMarker('Cam_Cybran_West_Base'), 5)
		
		
        WaitSeconds(2)
		
		ScenarioFramework.Dialogue(OpStrings.M1_Main_Objective, nil, true)
		
        Cinematics.CameraMoveToMarker(ScenarioUtils.GetMarker('Cam_Cybran_Prison_1'), 5)
		
		
        WaitSeconds(5)
		
        Cinematics.CameraMoveToMarker(ScenarioUtils.GetMarker('Cam_ACU_Spawn'), 3)
		
		
		
		WaitSeconds(0.5)
		VisMarker_West_Base:Destroy()
		WaitSeconds(0.5)
		ScenarioFramework.ClearIntel(ScenarioUtils.MarkerToPosition('NIS_M1_Vis_West_Base'), 500)
		WaitSeconds(0.5)

		
        Cinematics.ExitNISMode()
				
	end
	
	SpawnAllACUs()
	
	StartMission1()
end

function SpawnAllACUs()
	ScenarioInfo.PlayerCDR = ScenarioFramework.SpawnCommander('Player', 'Commander', 'Warp', true, true, PlayerDies)
	
    ScenarioInfo.CoopCDR = {}
	local tblArmy = ListArmies()
	local coopDies = {Coop1Dies, Coop2Dies, Coop3Dies}
	coop = 1
	for iArmy, strArmy in pairs(tblArmy) do
		if iArmy >= ScenarioInfo.Coop1 then
				ScenarioInfo.CoopCDR[coop] = ScenarioFramework.SpawnCommander(strArmy, 'Commander', 'Warp', true, true, coopDies[coop])
			coop = coop + 1
			WaitSeconds(0.5)
		end
	end

end

function StartMission1()
    -----------------------------------------
    -- Primary Objective 1 - Rescue Civilians
    -----------------------------------------
	
	ScenarioInfo.M1P1 = Objectives.Capture(
        'primary',                      -- type
        'incomplete',                   -- complete
        'Rescue Civilians',  -- title
        'Capture this Cybran prison to free the kidnapped civilians.',  -- description
        {
            Units = {ScenarioInfo.M1_Cybran_Prison},
            FlashVisible = true,
			Category = categories.urc1101,
        }
    )
    ScenarioInfo.M1P1:AddResultCallback(
        function(result)
            if(result) then
                if ScenarioInfo.MissionNumber == 1 then
                    ScenarioFramework.Dialogue(OpStrings.M1_Prison_Captured, InitializeMission2, true)
                end
            end
        end
    )
    table.insert(AssignedObjectives, ScenarioInfo.M1P1)
    --ScenarioFramework.CreateTimerTrigger(M1P1Reminder1, 600)

    -- Expand map even if objective isn't finished yet
    ScenarioFramework.CreateTimerTrigger(PrematureMission2, M1MapExpandDelay[Difficulty])
	
    ----------------------------------------
    -- Secondary Objective 1 - Destroy Base
    ----------------------------------------
	ScenarioInfo.M1S1 = Objectives.CategoriesInArea(
		'secondary',                      -- type
		'incomplete',                   -- complete
		'Destroy Cybran Base',                 -- title
		'Eliminate the marked Cybran structures to open your path to the prison.',  -- description
		'kill',                         -- action
		{                               -- target
			MarkUnits = true,
			Requirements = {
				{   
					Area = 'M1_Cybran_Base_Area',
					Category = categories.FACTORY - categories.EXPERIMENTAL,
					CompareOp = '<=',
					Value = 0,
					ArmyIndex = Cybran,
				},
			},
		}
	)
    ScenarioInfo.M1S1:AddResultCallback(
        function(result)
            if(result) then
				ScenarioFramework.Dialogue(OpStrings.M1_Base_Destroyed, nil, true)
            end
        end
    )
    table.insert(AssignedObjectives, ScenarioInfo.M1S1)
	
	
    ---------------------------------------------------
    -- Secondary Objective 2 - Destroy Forward Defenses
    ---------------------------------------------------
	if ScenarioInfo.NumberOfPlayers >= 3 then -- only if >=3 players are there forward defenses
		ScenarioFramework.Dialogue(OpStrings.M1_Destroy_Forward_Defenses, nil, true)
		ScenarioInfo.M1S2 = Objectives.CategoriesInArea(
			'secondary',                      -- type
			'incomplete',                   -- complete
			'Destroy Forward Defenses',                 -- title
			'Eliminate the marked Cybran defense structures to open the area for your expansion.',  -- description
			'kill',                         -- action
			{                               -- target
				MarkUnits = true,
				Requirements = {
					{   
						Area = 'M1_Forward_Defenses',
						Category = categories.DEFENSE - categories.WALL,
						CompareOp = '<=',
						Value = 0,
						ArmyIndex = Cybran,
					},
				},
			}
		)
		ScenarioInfo.M1S2:AddResultCallback(
			function(result)
				if(result) then
					ScenarioFramework.Dialogue(OpStrings.M1_Forward_Defenses_Destroyed, nil, true)
				end
			end
		)
		table.insert(AssignedObjectives, ScenarioInfo.M1S2)
	end
	
end

function PrematureMission2()
	if ScenarioInfo.MissionNumber == 1 then
		ScenarioInfo.M1P1:ManualResult(false)
		ScenarioFramework.Dialogue(OpStrings.M1_Too_Slow, InitializeMission2, true)
	end
end

function InitializeMission2()
	ScenarioInfo.MissionNumber = 2
	
	ScenarioFramework.SetPlayableArea('M2_Area', true)
	
    -------------------
    -- Cybran East Base
    -------------------
	M2CybranAI.CybranM2EastBaseAI()
	
	----------------------------
	-- Create Objective building
	----------------------------
	ScenarioInfo.M2_Cybran_Prison = ScenarioUtils.CreateArmyUnit('Cybran', 'M2_Cybran_Prison')
    ScenarioInfo.M2_Cybran_Prison:SetDoNotTarget(true)
    ScenarioInfo.M2_Cybran_Prison:SetCanTakeDamage(false)
    ScenarioInfo.M2_Cybran_Prison:SetCanBeKilled(false)
    ScenarioInfo.M2_Cybran_Prison:SetReclaimable(false)
    ScenarioInfo.M2_Cybran_Prison:SetCustomName("Cybran Prison")
	
	
	ForkThread(StartMission2)
end

function StartMission2()
	--Wait for everything to be build
	WaitSeconds(2)
    -----------------------------------------
    -- Primary Objective 1 - Rescue Civilians
    -----------------------------------------
	ScenarioFramework.Dialogue(OpStrings.M2_Main_Objective, nil, true)
	
	ScenarioInfo.M2P1 = Objectives.Capture(
        'primary',                      -- type
        'incomplete',                   -- complete
        'Rescue Civilians',  -- title
        'Capture this Cybran prison to free the kidnapped civilians.',  -- description
        {
            Units = {ScenarioInfo.M2_Cybran_Prison},
			Category = categories.urc1901,
        }
    )
    ScenarioInfo.M2P1:AddResultCallback(
        function(result)
            if(result) then
                if ScenarioInfo.MissionNumber == 2 and result then
                    ScenarioFramework.Dialogue(OpStrings.M2_Prison_Captured, PlayerWin, true)
				end
            end
        end
    )
	
    table.insert(AssignedObjectives, ScenarioInfo.M1P1)
    --ScenarioFramework.CreateTimerTrigger(M1P1Reminder1, 600)
	
    ---------------------------------------
    -- Secondary Objective 1 - Destroy Base
    ---------------------------------------
	ScenarioInfo.M2S1 = Objectives.CategoriesInArea(
		'secondary',                      -- type
		'incomplete',                   -- complete
		'Destroy Cybran Base',                 -- title
		'Eliminate the marked Cybran structures to open your path to the prison.',  -- description
		'kill',                         -- action
		{                               -- target
			MarkUnits = true,
			Requirements = {
				{   
					Area = 'M2_Cybran_Base_Area',
					Category = categories.FACTORY + categories.DEFENSE - categories.SHIELD - categories.WALL - categories.TECH1 - categories.EXPERIMENTAL,
					CompareOp = '<=',
					Value = 0,
					ArmyIndex = Cybran,
				},
			},
		}
	)
    ScenarioInfo.M2S1:AddResultCallback(
        function(result)
            if(result) then
				ScenarioFramework.Dialogue(OpStrings.M2_Base_Destroyed, nil, true)
            end
        end
    )
    table.insert(AssignedObjectives, ScenarioInfo.M2S1)
	
	
	ScenarioFramework.CreateArmyIntelTrigger(M2S2MonkeylordObjective, ArmyBrains[Player], 'LOSNow', nil, true, categories.urc1901, true, ArmyBrains[Cybran])
	
	-- Make TimeTrigger in case the player never scouts
	secondsUntilMonkeylord = M2SpawnMonkeylordTime[Difficulty] - math.floor(GetGameTimeSeconds()) + 2 -- add 2 just to make sure there are no race issues, possibly unnecessary
    ScenarioFramework.CreateTimerTrigger(SpawnExperimental, secondsUntilMonkeylord)
	
	if Difficulty >= 3 then
		planPrematureMonkeyLord()
	end
	
	
    -----------------------------------------------------
    -- Secondary Objective 3+4 - Destroy Forward Defenses
    -----------------------------------------------------
	if ScenarioInfo.NumberOfPlayers >= 3 then -- only if >=3 players are there forward defenses
		ScenarioFramework.Dialogue(OpStrings.M2_Destroy_Forward_Defenses, nil, true)
		ScenarioInfo.M2S3 = Objectives.CategoriesInArea(
			'secondary',                      -- type
			'incomplete',                   -- complete
			'Destroy Forward Defenses 1',                 -- title
			'Eliminate the marked Cybran defense structures to clear the path to the base.',  -- description
			'kill',                         -- action
			{                               -- target
				MarkUnits = true,
				Requirements = {
					{   
						Area = 'M2_Forward_Defenses_1',
						Category = categories.DEFENSE * categories.DIRECTFIRE,
						CompareOp = '<=',
						Value = 0,
						ArmyIndex = Cybran,
					},
				},
			}
		)
		ScenarioInfo.M2S3:AddResultCallback(
			function(result)
				if(result) then
					ScenarioFramework.Dialogue(OpStrings.M2_Forward_Defenses_1_Destroyed, nil, true)
				end
			end
		)
		table.insert(AssignedObjectives, ScenarioInfo.M2S3)
		
		if Difficulty >= 3 then
			ScenarioInfo.M2S4 = Objectives.CategoriesInArea(
				'secondary',                      -- type
				'incomplete',                   -- complete
				'Destroy Forward Defenses 2',                 -- title
				'Eliminate the marked Cybran defense structures to clear the path to the base.',  -- description
				'kill',                         -- action
				{                               -- target
					MarkUnits = true,
					Requirements = {
						{   
							Area = 'M2_Forward_Defenses_2',
							Category = categories.DEFENSE * categories.DIRECTFIRE,
							CompareOp = '<=',
							Value = 0,
							ArmyIndex = Cybran,
						},
					},
				}
			)
			ScenarioInfo.M2S4:AddResultCallback(
				function(result)
					if(result) then
						ScenarioFramework.Dialogue(OpStrings.M2_Forward_Defenses_2_Destroyed, nil, true)
					end
				end
			)
			table.insert(AssignedObjectives, ScenarioInfo.M2S4)
		end
	end
	
end

function M2S2MonkeylordObjective(MonkeylordTime)
    ------------------------------------------------------------------------------
    -- Secondary Objective 2 - Complete Primary Objectives before spawn Monkeylord
    ------------------------------------------------------------------------------
	ScenarioFramework.Dialogue(OpStrings.M2_Monkeylord_Detected, nil, true)
	
	secondsUntilMonkeylord = M2SpawnMonkeylordTime[Difficulty] - math.floor(GetGameTimeSeconds())
	ScenarioInfo.M2S2 = Objectives.Timer(
		'secondary',                      -- type
		'incomplete',                   -- complete
		'Beware of the Monkeylord!',                 -- title
		'Rescue the civilians before the Monkeylord spawns.',  -- description
		{                               -- target
			Timer = secondsUntilMonkeylord,
			ExpireResult = 'failed',
		}
	)
	
    ScenarioInfo.M2S2:AddResultCallback(
        function(result)
            if (not result) then
				SpawnExperimental()
            end
        end
    )
    table.insert(AssignedObjectives, ScenarioInfo.M2S2)
end

function planPrematureMonkeyLord()
	if ScenarioInfo.NumberOfPlayers >= 3 then
		TCRUtil.CreateMultipleAreaTrigger(prematureMonkeylord, {'M2_Forward_Defenses_1', 'M2_Forward_Defenses_2'} , categories.DEFENSE * categories.CYBRAN - categories.WALL, true, true, 0)
	else
		TCRUtil.CreateMultipleAreaTrigger(prematureMonkeylord, {'M2_InFronOfBase_1', 'M2_InFronOfBase_2'} , categories.DEFENSE * categories.CYBRAN - categories.WALL, true, true, 10)
		--TCRUtil.CreateAreaTrigger(prematureMonkeylord, 'M2_Area', categories.MOBILE * categories.TECH2 * categories.UEF - categories.ENGINEER, true, false, prematureMonkeyUnitCount[ScenarioInfo.NumberOfPlayers])
	end
end

function prematureMonkeylord()
	local secondsUntilMonkeylord = M2SpawnMonkeylordTime[Difficulty] - math.floor(GetGameTimeSeconds())
	if ScenarioInfo.hasMonkeylordSpawned or secondsUntilMonkeylord < prematureMonkeylordPreparationTime + 1 then
		return
	end
	
	ScenarioFramework.Dialogue(OpStrings.M2_Scared_Cybran, nil, true)
	if not (ScenarioInfo.M2S2 == nil) then
		ScenarioInfo.M2S2:ManualResult(true)
	end
	
	
    ------------------------------------------------------------------------------
    -- Secondary Objective 2.1 - Complete Primary Objectives before spawn Monkeylord
    ------------------------------------------------------------------------------
	secondsUntilMonkeylord = M2SpawnMonkeylordTime[Difficulty] - math.floor(GetGameTimeSeconds())
	ScenarioInfo.M2S2_1 = Objectives.Timer(
		'secondary',                      -- type
		'incomplete',                   -- complete
		'Beware of the Monkeylord!',                 -- title
		'Rescue the civilians before the Monkeylord spawns.',  -- description
		{                               -- target
			Timer = prematureMonkeylordPreparationTime,
			ExpireResult = 'failed',
		}
	)
	
    ScenarioInfo.M2S2_1:AddResultCallback(
        function(result)
            if (not result) then
				SpawnExperimental()
            end
        end
    )
    table.insert(AssignedObjectives, ScenarioInfo.M2S2_1)
	
end

function SpawnExperimental()

	if (not ScenarioInfo.hasMonkeylordSpawned) and (math.floor(GetGameTimeSeconds()) >= M2SpawnMonkeylordTime[Difficulty]) then
		ScenarioFramework.Dialogue(OpStrings.M2_Monkeylord_Is_Coming, nil, true)
		M2CybranAI.DropExperimental(KilledExperimentals)
		ScenarioInfo.hasMonkeylordSpawned = true
	else
		M2CybranAI.DropExperimental(KilledExperimentals)
	end

end


function KilledExperimentals()

	--Check if all experimentals are dead
	local exps = TCRUtil.GetAllCatUnitsInArea(categories.EXPERIMENTAL, 'M2_Area')
	for _,unit in exps do
		if not unit:IsDead() then
			return
		end
	end
	
	ForkThread(M2CybranAI.AfterExperimentalDrops)
	ForkThread(M2CybranAI.SnipeACUs)
	
	killedExp = killedExp + 1 
	if killedExp <= 2 then
		ScenarioFramework.Dialogue(OpStrings.M2_Experimental_Destroyed, nil, true)
	else
		ScenarioFramework.Dialogue(OpStrings.M2_Experimentals_Destroyed, nil, true)
	end
	
	--Make new TimerObjective for next wave of experimentals
	secondsUntilExperimentals = M2SpawnExperimentalsTime[Difficulty] + math.max( 0, M2SpawnMonkeylordTime[Difficulty] - math.floor(GetGameTimeSeconds()))
	ScenarioInfo.M2SX = Objectives.Timer(
		'secondary',                      -- type
		'incomplete',                   -- complete
		'Beware of the Experimentals!',                 -- title
		'Rescue the civilians before the Experimentals spawn.',  -- description
		{                               -- target
			Timer = secondsUntilExperimentals,
			ExpireResult = 'failed',
		}
	)
	
    ScenarioInfo.M2SX:AddResultCallback(
        function(result)
            if (not result) then
				SpawnExperimental()
            end
        end
    )
    table.insert(AssignedObjectives, ScenarioInfo.M2SX)
end

-----------
-- End Game
-----------
function PlayerWin()
    if(not ScenarioInfo.OpEnded) then
        ScenarioInfo.OpComplete = true
		makeCDRImmortal()
        ScenarioFramework.CDRDeathNISCamera(ScenarioInfo.PlayerCDR)
        ScenarioFramework.Dialogue(OpStrings.PlayerWin, KillGame, true)
    end
end

function makeCDRImmortal()
	local units = TCRUtil.GetAllCatUnitsInArea(categories.COMMAND, 'M2_Area')
	for _,cdr in units do
		cdr:SetCanTakeDamage(false)
		cdr:SetCanBeKilled(false)
	end
end

function PlayerDies()
	PlayerDeath(0)
end
function Coop1Dies()
	PlayerDeath(1)
end
function Coop2Dies()
	PlayerDeath(2)
end
function Coop3Dies()
	PlayerDeath(3)
end

function PlayerDeath(playerThatDied)
	local player
	if playerThatDied == 0 then
		player = ScenarioInfo.PlayerCDR
	else
		player = ScenarioInfo.CoopCDR[playerThatDied]
	end
    if(not ScenarioInfo.OpEnded) then
        ScenarioFramework.CDRDeathNISCamera(player)
        ScenarioFramework.EndOperationSafety()
        ScenarioInfo.OpComplete = false
        for k, v in AssignedObjectives do
            if(v and v.Active) then
                v:ManualResult(false)
            end
        end
        ForkThread(
            function()
                WaitSeconds(3)
                UnlockInput()
                KillGame()
            end
		)
    end
end

function PlayerLose()
    if(not ScenarioInfo.OpEnded) then
        ScenarioFramework.CDRDeathNISCamera(ScenarioInfo.Monkeylord)
        ScenarioFramework.EndOperationSafety()
        ScenarioInfo.OpComplete = false
        for k, v in AssignedObjectives do
            if(v and v.Active) then
                v:ManualResult(false)
            end
        end
        -- WaitSeconds(3) -- error?
        ScenarioFramework.Dialogue(OpStrings.DeadMonkeylord, KillGame, true)
    end
end

function KillGame()
    UnlockInput()
	
	local allPrimaryCompleted = true
	local allSecondaryCompleted = true
	
	for _, v in AssignedObjectives do
		if (v == ScenarioInfo.M1P1 or v == ScenarioInfo.M2P1) then
			allPrimaryCompleted = allPrimaryCompleted and v.Complete
			-- LOG("*DEBUG: primary",v.Complete)
		else
			allSecondaryCompleted = allSecondaryCompleted and v.Complete
			-- LOG("*DEBUG: secondary",v.Complete)
		end
	end
	
    ScenarioFramework.EndOperation(ScenarioInfo.OpComplete, allPrimaryCompleted, allSecondaryCompleted)
end