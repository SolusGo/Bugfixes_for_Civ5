-- ============================================================================
-- SolusGo's Compatibility Fixes
-- Conditional repairs for third-party Civilization V mods.
-- Every statement is inert when the affected content is not installed.
-- ============================================================================

-- MC's India Civilization Pack (Maratha / Shivaji)
-- UNIT_MC_CONSCRIPTION has no Unit_AITypes row.  InitUnit therefore creates it
-- as NO_UNITAI, and its conversion into infantry trips the Community Patch DLL
-- enum validator.  Give the placeholder a valid land-combat role.
INSERT OR IGNORE INTO Unit_AITypes (UnitType, UnitAIType)
SELECT 'UNIT_MC_CONSCRIPTION', 'UNITAI_ATTACK'
WHERE EXISTS (
    SELECT 1 FROM Units WHERE Type = 'UNIT_MC_CONSCRIPTION'
)
AND NOT EXISTS (
    SELECT 1 FROM Unit_AITypes
    WHERE UnitType = 'UNIT_MC_CONSCRIPTION'
      AND UnitAIType = 'UNITAI_ATTACK'
);

-- Tar's Arabian Split removes Arabia's Civilization_Leaders row while leaving
-- CIVILIZATION_ARABIA in the database.  The stock Civilopedia assumes every
-- non-minor civilization has a leader and crashes while constructing its list.
INSERT OR IGNORE INTO Civilization_Leaders (CivilizationType, LeaderheadType)
SELECT 'CIVILIZATION_ARABIA', 'LEADER_HARUN_AL_RASHID'
WHERE EXISTS (
    SELECT 1 FROM Civilizations WHERE Type = 'CIVILIZATION_ARABIA'
)
AND EXISTS (
    SELECT 1 FROM Leaders WHERE Type = 'LEADER_HARUN_AL_RASHID'
)
AND NOT EXISTS (
    SELECT 1 FROM Civilization_Leaders
    WHERE CivilizationType = 'CIVILIZATION_ARABIA'
);

-- Super Civs - DC Pack declares the Batman hidden building class with NONE as
-- its default even though BUILDING_BAD_HIDDEN exists.  Justinian's loader
-- dereferences every ordinary BuildingClass default without a nil guard.
UPDATE BuildingClasses
SET DefaultBuilding = 'BUILDING_BAD_HIDDEN'
WHERE Type = 'BUILDINGCLASS_BAD_HIDDEN'
  AND DefaultBuilding = 'NONE'
  AND EXISTS (
      SELECT 1 FROM Buildings WHERE Type = 'BUILDING_BAD_HIDDEN'
  );

-- Super Civs - Marvel Pack declares two Jean Grey School dummy classes but
-- omits their default Buildings rows.  Supply inert hidden rows so generic UI
-- and civilization scripts can safely enumerate BuildingClasses.
INSERT OR IGNORE INTO Buildings
(Type, BuildingClass, Description, Help, Cost, FaithCost, GreatWorkCount,
 PrereqTech, NukeImmune, NeverCapture, HurryCostModifier, MinAreaSize,
 ArtDefineTag, ShowInPedia)
SELECT
 'BUILDING_JGR_WRITER', 'BUILDINGCLASS_JGR_WRITER',
 'TXT_KEY_WR_CP_TOOLTIP_FALLBACK', 'TXT_KEY_WR_CP_TOOLTIP_FALLBACK',
 -1, -1, -1, NULL, 1, 1, -1, -1, 'NONE', 0
WHERE EXISTS (
    SELECT 1 FROM BuildingClasses WHERE Type = 'BUILDINGCLASS_JGR_WRITER'
);

INSERT OR IGNORE INTO Buildings
(Type, BuildingClass, Description, Help, Cost, FaithCost, GreatWorkCount,
 PrereqTech, NukeImmune, NeverCapture, HurryCostModifier, MinAreaSize,
 ArtDefineTag, ShowInPedia)
SELECT
 'BUILDING_JGR_CULTURE', 'BUILDINGCLASS_JGR_CULTURE',
 'TXT_KEY_WR_CP_TOOLTIP_FALLBACK', 'TXT_KEY_WR_CP_TOOLTIP_FALLBACK',
 -1, -1, -1, NULL, 1, 1, -1, -1, 'NONE', 0
WHERE EXISTS (
    SELECT 1 FROM BuildingClasses WHERE Type = 'BUILDINGCLASS_JGR_CULTURE'
);
