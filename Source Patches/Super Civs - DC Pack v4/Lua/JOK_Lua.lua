include("PlotIterators")

local iJOKCiv = GameInfoTypes.CIVILIZATION_JOK
local iJOKUnitClown = GameInfoTypes.UNIT_JOK_CLOWN
local iJOKUnitGeneral = GameInfoTypes.UNIT_JOK_CLOWN_GENERAL
local iJOKBuildingPark = GameInfoTypes.BUILDING_JOK_PARK
local iJOKPromotionLaugh = GameInfoTypes.PROMOTION_JOK_LAST_LAUGH
local iJOKPromotionDeath = GameInfoTypes.PROMOTION_JOK_DEATH
local JOKSave = Modding.OpenSaveData()
local JOKConversionKeyPrefix = "SOLUSGO_JOK_GOLDEN_AGE_CONVERTED_"

local function JOKConversionKey(iPlayer)
	return JOKConversionKeyPrefix .. tostring(iPlayer)
end

local function JOKIsConversionActive(iPlayer)
	return tonumber(JOKSave.GetValue(JOKConversionKey(iPlayer))) == 1
end

local function JOKSetConversionActive(iPlayer, active)
	JOKSave.SetValue(JOKConversionKey(iPlayer), active and 1 or 0)
end

local function JOKGetTemporaryClowns(pPlayer)
	local units = {}
	for pUnit in pPlayer:Units() do
		if pUnit:GetUnitType() == iJOKUnitClown
			and pUnit:IsHasPromotion(iJOKPromotionDeath) then
			units[#units + 1] = pUnit
		end
	end
	table.sort(units, function(a, b) return a:GetID() < b:GetID() end)
	return units
end

local function JOKGetCityCount(pPlayer)
	local count = 0
	for pCity in pPlayer:Cities() do count = count + 1 end
	return count
end

local function JOKTrimRunawayClowns(pPlayer, temporaryClowns)
	-- The trait is meant to create one temporary explosive Clown per city.
	-- Older versions ran the Golden Age branch every turn and could leave
	-- hundreds in an existing save. Preserve the oldest intended batch and
	-- silently remove only surplus Clowns carrying the temporary promotion.
	local keep = JOKGetCityCount(pPlayer)
	local removed = 0
	while #temporaryClowns > keep do
		local pUnit = table.remove(temporaryClowns)
		if pUnit then
			pUnit:Kill()
			removed = removed + 1
		end
	end
	if removed > 0 then
		print("JOK_Lua: removed " .. tostring(removed)
			.. " runaway temporary Clowns for " .. pPlayer:GetName())
	end
	return temporaryClowns
end

--clown increasing strength
function JOKClownStrength(iPlayer)
	local pPlayer = Players[iPlayer];
	if not pPlayer or not pPlayer:IsAlive()
		or pPlayer:GetCivilizationType() ~= iJOKCiv then return end
	local str = 1
	local iEra = pPlayer:GetCurrentEra()
	if iEra == GameInfoTypes.ERA_ANCIENT then str = 8
	elseif iEra == GameInfoTypes.ERA_CLASSICAL then str = 12
	elseif iEra == GameInfoTypes.ERA_MEDIEVAL then str = 17
	elseif iEra == GameInfoTypes.ERA_RENAISSANCE then str = 24
	elseif iEra == GameInfoTypes.ERA_INDUSTRIAL then str = 34
	elseif iEra == GameInfoTypes.ERA_MODERN then str = 49
	elseif iEra == GameInfoTypes.ERA_POSTMODERN then str = 67
	elseif iEra == GameInfoTypes.ERA_FUTURE then str = 90
	elseif iEra < GameInfoTypes.ERA_ANCIENT then str = 5
	elseif iEra == GameInfoTypes.ERA_INDUSTRIAL - 1 then str = 29
	elseif iEra > GameInfoTypes.ERA_FUTURE then str = 120 end
	for pUnit in pPlayer:Units() do
		if (pUnit:GetUnitType() == iJOKUnitClown or pUnit:GetUnitType() == iJOKUnitGeneral) and str > 1 then
			pUnit:SetBaseCombatStrength(str)
		end
	end
end
GameEvents.PlayerDoTurn.Add(JOKClownStrength)
Events.SerialEventEraChanged.Add(JOKClownStrength)
Events.SerialEventUnitCreated.Add(JOKClownStrength)

function JOKAnarchy(iPlayer)
	local pPlayer = Players[iPlayer];
	if not pPlayer or not pPlayer:IsAlive()
		or pPlayer:GetCivilizationType() ~= iJOKCiv then return end

	local isAnarchy = pPlayer:IsAnarchy()
	local isGoldenAge = pPlayer:IsGoldenAge()
	local temporaryClowns = JOKTrimRunawayClowns(
		pPlayer,
		JOKGetTemporaryClowns(pPlayer)
	)
	local conversionActive = JOKIsConversionActive(iPlayer)

	-- Recover old saves created before the one-shot conversion marker existed.
	if not conversionActive and isAnarchy and #temporaryClowns > 0 then
		conversionActive = true
		JOKSetConversionActive(iPlayer, true)
	end

	if isAnarchy then
		local pTitle = ("Anarchy!!")
		local pDesc = ("Your nation is in Anarchy for "..pPlayer:GetAnarchyNumTurns().." turns! All of your units have massive combat bonuses! Your extra Clowns will explode when Anarchy ends, so make sure they're not going to blow up your own Units and Cities!")
		pPlayer:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, pDesc, pTitle)
		for pUnit in pPlayer:Units() do
			pUnit:SetHasPromotion(iJOKPromotionLaugh,true)
			pUnit:SetMoves(pUnit:MaxMoves())
		end
	else
		local units = {}
		for pUnit in pPlayer:Units() do units[#units + 1] = pUnit end
		for _, pUnit in ipairs(units) do
			pUnit:SetHasPromotion(iJOKPromotionLaugh,false)
			pUnit:SetMoves(pUnit:MaxMoves())
		end
		for _, pUnit in ipairs(temporaryClowns) do
			if pUnit and pUnit:IsHasPromotion(iJOKPromotionDeath) then
				for adjacentPlot in PlotAreaSweepIterator(Map.GetPlot(pUnit:GetX(), pUnit:GetY()), 1, SECTOR_NORTH, DIRECTION_CLOCKWISE, DIRECTION_OUTWARDS, CENTRE_INCLUDE) do
					if adjacentPlot:IsCity() then
						local pCity = adjacentPlot:GetPlotCity()
						pCity:ChangeDamage(50)
					end
					if adjacentPlot:IsUnit() then
						local adjacentUnit = adjacentPlot:GetUnit()
						adjacentUnit:ChangeDamage(50)
					end
				end
				pUnit:Kill()
			end
		end
	end

	-- Once a Golden Age has been converted, suppress the still-visible Golden
	-- Age state for the duration of that Anarchy instead of spawning another
	-- batch every turn. The marker persists across save/reload.
	if conversionActive then
		if isGoldenAge then
			local turns = pPlayer:GetGoldenAgeTurns()
			if turns > 0 then pPlayer:ChangeGoldenAgeTurns(-turns) end
		elseif not isAnarchy then
			JOKSetConversionActive(iPlayer, false)
		end
		return
	end

	if isGoldenAge and not isAnarchy then
		local turns = pPlayer:GetGoldenAgeTurns()
		if turns <= 0 then return end
		pPlayer:ChangeGoldenAgeTurns(-turns)
		pPlayer:SetAnarchyNumTurns(turns)
		JOKSetConversionActive(iPlayer, true)
		local pTitle = ("Anarchy!!")
		local pDesc = ("Your nation is in Anarchy for "..pPlayer:GetAnarchyNumTurns().." turns! All of your units have massive combat bonuses! Your extra Clowns will explode when Anarchy ends, so make sure they're not going to blow up your own Units and Cities!")
		pPlayer:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, pDesc, pTitle)
		for pCity in pPlayer:Cities() do
			if pCity:IsHasBuilding(iJOKBuildingPark)
				and pCity:GetPopulation() > 1 then
				pCity:ChangePopulation(-1)
			end
			local unit = pPlayer:InitUnit(iJOKUnitClown, pCity:GetX(), pCity:GetY())
			unit:SetHasPromotion(iJOKPromotionDeath,true)
		end
		for pUnit in pPlayer:Units() do
			pUnit:SetHasPromotion(iJOKPromotionLaugh,true)
			pUnit:SetMoves(pUnit:MaxMoves())
		end
	end

end
GameEvents.PlayerDoTurn.Add(JOKAnarchy)
