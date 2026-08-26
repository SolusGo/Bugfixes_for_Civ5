local iJGRCiv = GameInfoTypes.CIVILIZATION_JGR
local iJGRBuildingSchool = GameInfoTypes.BUILDING_JGR_SCHOOL
local iJGRBuildingOurs = GameInfoTypes.BUILDING_JGR_SELF_CULTURE
local iJGRBuildingTheirs = GameInfoTypes.BUILDING_JGR_OTHER_CULTURE
local iJGRBuildingHappiness = GameInfoTypes.BUILDING_JGR_HAPPINESS
local iJGRMutantMessiah = GameInfoTypes.PROMOTION_JGR_MUTANT_MESSIAH
local iJGRHope = GameInfoTypes.PROMOTION_JGR_HOPE
local iJGRDummy1 = GameInfoTypes.BUILDING_JGR_DUMMY_TOURISM_1;
local iJGRDummy2 = GameInfoTypes.BUILDING_JGR_DUMMY_TOURISM_2;
local iJGRDummy4 = GameInfoTypes.BUILDING_JGR_DUMMY_TOURISM_4;
local iJGRDummy8 = GameInfoTypes.BUILDING_JGR_DUMMY_TOURISM_8;
local iJGRDummy16 = GameInfoTypes.BUILDING_JGR_DUMMY_TOURISM_16;
local iJGRDummy32 = GameInfoTypes.BUILDING_JGR_DUMMY_TOURISM_32;
local iJGRDummy64 = GameInfoTypes.BUILDING_JGR_DUMMY_TOURISM_64;
local iJGRDummy128 = GameInfoTypes.BUILDING_JGR_DUMMY_TOURISM_128;

--Jean Grey trait start, dynamic tourism adding courtesy of UltimatePotato on the civfanatics forums.
function toBits(num)
    -- returns a table of bits, least significant first.
	local t = {} -- will contain the bits
    while num>0 do
        local rest=math.fmod(num,2)
        t[#t+1]=rest
        num=(num-rest)/2
    end
    return t
end

function JGRTrait(iPlayer)
	local pPlayer = Players[iPlayer];
	if not pPlayer or not pPlayer:IsAlive() or pPlayer:GetCivilizationType() ~= iJGRCiv then return end
	--Jean Grey trait
	local pCapital = pPlayer:GetCapitalCity()
	if not pCapital then return end
	local bonus = 0
	-- Tourism influence only exists between major civilizations. Iterating the
	-- whole Players table includes city-states and barbarians; passing one of
	-- those IDs to GetInfluenceLevel triggers VP's fatal player-index guard.
	for iOtherPlayer = 0, GameDefines.MAX_MAJOR_CIVS - 1 do
		local otherPlayer = Players[iOtherPlayer]
		if otherPlayer and otherPlayer:IsAlive() and iOtherPlayer ~= iPlayer then
			local otherCapital = otherPlayer:GetCapitalCity()
			if otherCapital then
				otherCapital:SetNumRealBuilding(iJGRBuildingTheirs,0)
				otherCapital:SetNumRealBuilding(iJGRBuildingHappiness,0)
				local influence = pPlayer:GetInfluenceLevel(iOtherPlayer)
				--print("Player: "..otherPlayer:GetID()..", Influence: "..influence)
				if influence >= InfluenceLevelTypes.INFLUENCE_LEVEL_POPULAR then
					local ibonus = (otherPlayer:GetNumGreatWorks() + otherPlayer:GetNumWorldWonders()) / 2
					if influence == InfluenceLevelTypes.INFLUENCE_LEVEL_INFLUENTIAL then ibonus = ibonus * 2
					elseif influence == InfluenceLevelTypes.INFLUENCE_LEVEL_DOMINANT then ibonus = ibonus * 3 end
					--print("Bonus: "..ibonus..", Works: "..otherPlayer:GetNumGreatWorks()..", Wonders: "..otherPlayer:GetNumWorldWonders())
					bonus = bonus + math.floor(ibonus)
					if otherPlayer:IsDoF(pPlayer) then
						local otherBonus = (pPlayer:GetNumGreatWorks() + pPlayer:GetNumWorldWonders()) / 4
						if influence == InfluenceLevelTypes.INFLUENCE_LEVEL_INFLUENTIAL then
							otherBonus = otherBonus * 2
							otherCapital:SetNumRealBuilding(iJGRBuildingHappiness,2)
						elseif influence == InfluenceLevelTypes.INFLUENCE_LEVEL_DOMINANT then
							otherBonus = otherBonus * 3
							otherCapital:SetNumRealBuilding(iJGRBuildingHappiness,3)
						else
							otherCapital:SetNumRealBuilding(iJGRBuildingHappiness,1)
						end
						--print("Other: "..otherBonus..", Works: "..pPlayer:GetNumGreatWorks()..", Wonders: "..pPlayer:GetNumWorldWonders())
						otherCapital:SetNumRealBuilding(iJGRBuildingTheirs,math.floor(otherBonus))
					end
				end
			end
		end
	end
	--print("Total: "..bonus)
	local t = toBits(bonus)
	pCapital:SetNumRealBuilding(iJGRDummy1, t[1] or 0);
	pCapital:SetNumRealBuilding(iJGRDummy2, t[2] or 0);
	pCapital:SetNumRealBuilding(iJGRDummy4, t[3] or 0);
	pCapital:SetNumRealBuilding(iJGRDummy8, t[4] or 0);
	pCapital:SetNumRealBuilding(iJGRDummy16, t[5] or 0);
	pCapital:SetNumRealBuilding(iJGRDummy32, t[6] or 0);
	pCapital:SetNumRealBuilding(iJGRDummy64, t[7] or 0);
	pCapital:SetNumRealBuilding(iJGRDummy128, t[8] or 0);
	pCapital:SetNumRealBuilding(iJGRBuildingOurs,bonus)
end
GameEvents.PlayerDoTurn.Add(JGRTrait)

function JGRMessiah(iPlayer)
	local pPlayer = Players[iPlayer];
	--X-Force Movement bonuses
	for pUnit in pPlayer:Units() do
		pUnit:SetHasPromotion(iJGRHope,false)
		if pUnit:IsHasPromotion(iJGRMutantMessiah) then
			local owner = Players[pUnit:GetPlot():GetOwner()]
			if owner and (owner:GetID() == iPlayer or (owner and (owner:IsDoF(pPlayer) or (owner:IsMinorCiv() and owner:IsAllies(pPlayer))))) then
				pUnit:SetHasPromotion(iJGRHope,true)
			end
		end
		pUnit:SetMoves(pUnit:MaxMoves())
	end
end
GameEvents.PlayerDoTurn.Add(JGRMessiah)

--Xavier Institute effect, taken from Teddyk's The Good, the Bad, and the Ugly mod
local SpecT = {}
local OverT = {}
for row in GameInfo.Specialists() do
	if row.GreatPeopleUnitClass then
		SpecT[row.ID] = GameInfo.UnitClasses[row.GreatPeopleUnitClass].ID;
	end
end

GameEvents.PlayerDoTurn.Add(function(iPlayer)
	local pPlayer = Players[iPlayer];
	if pPlayer:GetCivilizationType() ~= iJGRCiv then return end
	for pCity in pPlayer:Cities() do
		local exists = false
		for k,v in pairs(OverT) do
			if k == pCity then
				exists = true
				break
			end
		end
		if not exists then
			JGRNewCity(iPlayer, pCity)
		end
		for specID, gpc in pairs(SpecT) do
			--[[print("Specialist: "..specID)
			print("Last Turn: "..OverT[pCity][specID][1])
			print("This Turn: "..pCity:GetSpecialistGreatPersonProgress(specID))]]
			if OverT[pCity][specID][1] > pCity:GetSpecialistGreatPersonProgress(specID) then
				if pCity:IsHasBuilding(iJGRBuildingSchool) then
					pCity:ChangeSpecialistGreatPersonProgressTimes100(specID, math.floor(30 * OverT[pCity][specID][2]))
				end
			end
			OverT[pCity][specID] = {pCity:GetSpecialistGreatPersonProgress(specID), pCity:GetSpecialistUpgradeThreshold(gpc)}
		end
	end
end)

function JGRNewCity(iPlayer, pCity)
	OverT[pCity] = {}
	for specID, gpc in pairs(SpecT) do
		OverT[pCity][specID] = {pCity:GetSpecialistGreatPersonProgress(specID), pCity:GetSpecialistUpgradeThreshold(gpc)}
	end
end

GameEvents.CityCaptureComplete.Add(function(iOldOwner, bIsCapital, iX, iY, iNewOwner, iPop, bConquest)
	local pPlayer = Players[iNewOwner];
	if pPlayer:GetCivilizationType() ~= iJGRCiv then return end
	JGRNewCity(iNewOwner, Map.GetPlot(iX, iY):GetPlotCity())
end)

GameEvents.PlayerCityFounded.Add(function(iPlayer, iCityX, iCityY)
	local pPlayer = Players[iPlayer];
	if pPlayer:GetCivilizationType() ~= iJGRCiv then return end
	JGRNewCity(iPlayer, Map.GetPlot(iCityX, iCityY):GetPlotCity())
end)
