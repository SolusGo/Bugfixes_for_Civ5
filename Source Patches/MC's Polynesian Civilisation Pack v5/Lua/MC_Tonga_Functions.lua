--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ /// Tonga functions \\\ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ///                   \\\ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--~~~ UA: The Friendly Isles - Earn more influence for completing city state quests. Whenever you first ~~~
--~~~                          meet a civilisation or city state, earn a random faith, culture, gold    ~~~
--~~~                          or science bonus.                                                        ~~~
--~~~           UU: Tongiaki - Replaces Trireme. Can enter ocean tiles. When an embarked unit starts on ~~~
--~~~                          the same tile as a Tongiaki, it too can cross ocean tiles.               ~~~
--~~~             UB: Mala'e - Replaces the Granary. For every sea tile adjacent to the city, receive   ~~~
--~~~                          +1 food in the city. Fish and Crab resources provide +1 food when worked ~~~
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\\\ ///~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--=====================================================================================================
-- UA: The Friendly Isles
-- Author: JFD
--=====================================================================================================

    function GetRandom(lower, upper)
        return Game.Rand((upper + 1) - lower, "") + lower
    end
     
    function JFD_Tonga(playerMetID, playerID)
            local player = Players[playerID]
            local playerMet = Players[playerMetID]
            local majorsMet = Teams[playerMet:GetTeam()]:GetHasMetCivCount(true)
            local reward
            if player:GetCivilizationType() == GameInfoTypes["CIVILIZATION_MC_TONGA"] then
                    if playerMet:IsMinorCiv() then reward = 15 else reward = 30 end
                    if majorsMet == 1 then reward = reward * 2 end
           
                    local random = GetRandom(1, 4)
                    if random == 1 then
                            player:ChangeFaith(reward)
                            if player:IsHuman() then
                                    Events.GameplayAlertMessage(Locale.ConvertTextKey("You receive {1_Num} [ICON_PEACE] Faith from meeting {2_CivName}", reward, playerMet:GetName()))
                            end
                    elseif random == 2 then
                            player:ChangeJONSCulture(reward)
                            if player:IsHuman() then
                                    Events.GameplayAlertMessage(Locale.ConvertTextKey("You receive {1_Num} [ICON_CULTURE] Culture from meeting {2_CivName}", reward, playerMet:GetName()))
                            end
                    elseif random == 3 then
                            local researchID = player:GetCurrentResearch()
                            if researchID and researchID >= 0 then
                                Teams[player:GetTeam()]:GetTeamTechs():ChangeResearchProgress(researchID, reward, playerID)
                            else
                                player:ChangeOverflowResearch(reward)
                            end
                            if player:IsHuman() then
                                    Events.GameplayAlertMessage(Locale.ConvertTextKey("You receive {1_Num} [ICON_RESEARCH] Science from meeting {2_CivName}", reward, playerMet:GetName()))
                            end
                    else
                            player:ChangeGold(reward)
                            if player:IsHuman() then
                                    Events.GameplayAlertMessage(Locale.ConvertTextKey("You receive {1_Num} [ICON_GOLD] Gold from meeting {2_CivName}", reward, playerMet:GetName()))
                            end
                    end
            end
    end
    GameEvents.TeamMeet.Add(JFD_Tonga)

function InitTonga(player)
	for playerID, player in pairs(Players) do
		local player = Players[playerID];
		 if player:GetCivilizationType() == GameInfoTypes["POLICY_TONGA_UA"] then
			if not player:HasPolicy(GameInfoTypes["POLICY_TONGA_UA"]) then
				player:SetNumFreePolicies(1)
				player:SetNumFreePolicies(0)
				player:SetHasPolicy(GameInfoTypes["POLICY_TONGA_UA"], true)	
			end
			
		end
	end 
end


	Events.LoadScreenClose.Add(InitTonga)

--=====================================================================================================
-- UU: Tongiaki (Embarked units on the same tile can also embark over ocean)
-- Author: JFD
--=====================================================================================================

function JFD_OutriggerEmbarkation(playerID)
	local player = Players[playerID]
	for unit in player:Units() do
		if unit:IsEmbarked() then
			local sameTile = false
			local plot = unit:GetPlot()
			for iVal = 0,(plot:GetNumUnits() - 1) do
				local outrigger = plot:GetUnit(iVal)
				if outrigger:IsHasPromotion(GameInfoTypes["PROMOTION_MC_OUTRIGGER"]) then
					sameTile = true
				end
			end
			
			if sameTile then
				if not unit:IsHasPromotion(GameInfoTypes["PROMOTION_MC_ALLWATER_EMBARKATION"]) then
					unit:SetHasPromotion(GameInfoTypes["PROMOTION_MC_ALLWATER_EMBARKATION"], true)
				end
			else
				if unit:IsHasPromotion(GameInfoTypes["PROMOTION_MC_ALLWATER_EMBARKATION"]) then
					unit:SetHasPromotion(GameInfoTypes["PROMOTION_MC_ALLWATER_EMBARKATION"], false)
				end
			end
		end
	end
end
GameEvents.PlayerDoTurn.Add(JFD_OutriggerEmbarkation)



--=====================================================================================================
-- UB: Mala'e (Adjacent ocean tiles generate food)
-- Author: JFD
--=====================================================================================================

	local direction_types = {
            DirectionTypes["DIRECTION_NORTHEAST"],
            DirectionTypes["DIRECTION_NORTHWEST"],
            DirectionTypes["DIRECTION_EAST"],
            DirectionTypes["DIRECTION_SOUTHEAST"],
            DirectionTypes["DIRECTION_SOUTHWEST"],
            DirectionTypes["DIRECTION_WEST"]
            }
     
    function JFD_GetNumAdjacentSeaTiles(city)
            local numAdjacentSeaTiles = 0
            if Map.GetPlot(city:GetX(), city:GetY()) then
                    for loop, direction in ipairs(direction_types) do
                            local adjPlot = Map.PlotDirection(city:GetX(), city:GetY(), direction)
                            if adjPlot:GetTerrainType() == GameInfoTypes["TERRAIN_COAST"] then     
                                    numAdjacentSeaTiles = numAdjacentSeaTiles + 1
                            end
                    end
            end
           
            return numAdjacentSeaTiles     
    end
     
    function JFD_MalaeFood(playerID, unitID, unitX, unitY)
            local player = Players[playerID]
            if player:IsAlive() then
                    for city in player:Cities() do
                            if city:IsHasBuilding(GameInfoTypes["BUILDING_MC_TONGAN_MALAE"]) and JFD_GetNumAdjacentSeaTiles(city) >= 2 then
                                    city:SetNumRealBuilding(GameInfoTypes["BUILDING_MC_MALAE_FOOD"], 1)
                            end
                    end
            end
    end
    GameEvents.PlayerDoTurn.Add(JFD_MalaeFood)