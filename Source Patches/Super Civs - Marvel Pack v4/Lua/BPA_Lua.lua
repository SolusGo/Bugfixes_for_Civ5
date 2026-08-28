local iBPACiv = GameInfoTypes.CIVILIZATION_BPA
local iBPABuildingVibranium = GameInfoTypes.BUILDING_BPA_VIBRANIUM
local iBPAResourceVibranium = GameInfoTypes.RESOURCE_BPA_VIBRANIUM
local iBPABuildingLab = GameInfoTypes.BUILDING_BPA_SHADOW_PHYSICS_LAB
local iBPABuildingCulture = GameInfoTypes.BUILDING_BPA_CULTURE
local iBPABuildingScience = GameInfoTypes.BUILDING_BPA_SCIENCE

-- Community Patch audits the resource-from-tiles bucket against the map. Older
-- saves can retain Black Panther's virtual Vibranium in that bucket after a city
-- changes hands, even though Vibranium is never a map resource for another civ.
-- Remove both captured dummy buildings and only the non-building remainder.
local function BPARepairStrayVibranium(iPlayer)
	local pPlayer = Players[iPlayer]
	if not pPlayer or not pPlayer:IsAlive() or pPlayer:GetCivilizationType() == iBPACiv then return end

	for pCity in pPlayer:Cities() do
		if pCity:IsHasBuilding(iBPABuildingVibranium) then
			pCity:SetNumRealBuilding(iBPABuildingVibranium, 0)
		end
	end

	local iFromBuildings = pPlayer:GetNumResourceFromBuildings(iBPAResourceVibranium)
	local iNonImportedTotal = pPlayer:GetNumResourceTotal(iBPAResourceVibranium, false)
	local iStray = iNonImportedTotal - iFromBuildings
	if iStray > 0 then
		-- Explicit false flags are important: this repairs the exact tile bucket
		-- checked by CvPlayer::VerifyAlive and does not touch building resources.
		pPlayer:ChangeNumResourceTotal(iBPAResourceVibranium, -iStray, false, false)
		print(string.format("SolusGo BPA fix: removed %d stray Vibranium from player %d", iStray, iPlayer))
	end
end

local function BPARepairAllStrayVibranium()
	for iPlayer = 0, GameDefines.MAX_CIV_PLAYERS - 1 do
		BPARepairStrayVibranium(iPlayer)
	end
end

function BPABuildingBonus(iPlayer)
	local pPlayer = Players[iPlayer];
	BPARepairStrayVibranium(iPlayer)
	if pPlayer:GetCivilizationType() ~= iBPACiv then return end
	local pCapital = pPlayer:GetCapitalCity()
	if pCapital then
		for pCity in pPlayer:Cities() do
			if pCity ~= pCapital then pCity:SetNumRealBuilding(iBPABuildingVibranium, 0) end
			pCity:SetNumRealBuilding(iBPABuildingCulture, 0)
			pCity:SetNumRealBuilding(iBPABuildingScience, 0)
			if pCity:IsHasBuilding(iBPABuildingLab) then
				local sci = pCity:GetBaseYieldRate(YieldTypes.YIELD_CULTURE) * 0.50
				local cul = pCity:GetBaseYieldRate(YieldTypes.YIELD_SCIENCE) * 0.10
				--print("City: "..pCity:GetName()..", Base Cul: "..pCity:GetBaseYieldRate(YieldTypes.YIELD_CULTURE).."/"..pCity:GetYieldRate(YieldTypes.YIELD_CULTURE)..", Base Sci: "..pCity:GetBaseYieldRate(YieldTypes.YIELD_SCIENCE).."/"..pCity:GetYieldRate(YieldTypes.YIELD_SCIENCE))
				pCity:SetNumRealBuilding(iBPABuildingCulture, cul)
				pCity:SetNumRealBuilding(iBPABuildingScience, sci)
				--print("Cul: "..pCity:GetBaseYieldRate(YieldTypes.YIELD_CULTURE).."/"..pCity:GetYieldRate(YieldTypes.YIELD_CULTURE).."/"..cul..", Sci: "..pCity:GetBaseYieldRate(YieldTypes.YIELD_SCIENCE).."/"..pCity:GetYieldRate(YieldTypes.YIELD_SCIENCE).."/"..sci)
			end
		end
		local iEra = pPlayer:GetCurrentEra()
		local vibraniumNum = 0
		if iEra == GameInfoTypes.ERA_ANCIENT then vibraniumNum = 0
		elseif iEra == GameInfoTypes.ERA_CLASSICAL then vibraniumNum = 1
		elseif iEra == GameInfoTypes.ERA_MEDIEVAL then vibraniumNum = 2
		elseif iEra == GameInfoTypes.ERA_RENAISSANCE then vibraniumNum = 3
		elseif iEra == GameInfoTypes.ERA_INDUSTRIAL then vibraniumNum = 4
		elseif iEra == GameInfoTypes.ERA_MODERN then vibraniumNum = 5
		elseif iEra == GameInfoTypes.ERA_POSTMODERN then vibraniumNum = 6
		elseif iEra == GameInfoTypes.ERA_FUTURE then vibraniumNum = 7 end
		pCapital:SetNumRealBuilding(iBPABuildingVibranium, vibraniumNum)
	end
end
GameEvents.PlayerDoTurn.Add(BPABuildingBonus)

if Events.LoadScreenClose then
	Events.LoadScreenClose.Add(BPARepairAllStrayVibranium)
end

--This function was mostly taken from LeeS and DoktorApplejuice on the forums
local iBuildingGPBonus = GameInfoTypes.BUILDING_BPA_GPBONUS

function BPADoraMilajeGPBonus(iPlayer)
	local pPlayer = Players[iPlayer]
	if pPlayer:IsBarbarian() then return end
	if pPlayer:GetCivilizationType() ~= iBPACiv then return end
	for pCity in pPlayer:Cities() do
		local iCityIsGarrisoned = 0
		local iNumUnits = pCity:Plot():GetNumUnits()
		if iNumUnits > 0 then
			for i = 0, iNumUnits do
				local pUnit = pCity:Plot():GetUnit(i)
				if pUnit then
					if pUnit:IsHasPromotion(GameInfoTypes.PROMOTION_BPA_ADORED_ONES) then
							iCityIsGarrisoned = 1
						break
					end
				end
			end
		end
		pCity:SetNumRealBuilding(iBuildingGPBonus, iCityIsGarrisoned)
	end
end
GameEvents.PlayerDoTurn.Add(BPADoraMilajeGPBonus)
