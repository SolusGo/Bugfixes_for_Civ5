# SolusGo's Compatibility Fixes

A separate Community Patch compatibility mod for repairing reproducible faults in older Civilization V mods without coupling those repairs to **The Fleshborn Chorus**.

## Included fixes

### MC's India Civilization Pack — Shivaji / Maratha conscription

Adds the missing `UNITAI_ATTACK` role to `UNIT_MC_CONSCRIPTION`. Without it, the unit is created as `NO_UNITAI`; converting it into infantry triggers the Community Patch DLL's `CvUnit.cpp` enum validator and forcibly ends the game.

### Tar's Arabian Split — Civilopedia

Restores Arabia's missing leader association when the split leaves the disabled base civilization in the database. The stock Civilopedia assumes every major civilization has a leader and otherwise fails while loading its civilization list.

### Byzantium Civilization Pack + Super Civs

Repairs three invalid `BuildingClasses` defaults exposed by Justinian's initialization script:

- `BUILDINGCLASS_BAD_HIDDEN` now points to its existing `BUILDING_BAD_HIDDEN` building.
- Missing hidden `BUILDING_JGR_WRITER` and `BUILDING_JGR_CULTURE` rows are supplied as inert, non-Civilopedia dummy buildings.

These changes prevent `Justinian I Functions.lua` from dereferencing a missing default building during startup.

### Super Civs — Jean Grey / Community Patch tourism crash

Jean Grey's turn script originally iterates through the complete `Players` table and calls `GetInfluenceLevel` for city-states. Community Patch only permits major-civilization IDs in its tourism influence arrays, so the first city-state ID causes the fatal `ePlayer < MAX_MAJOR_CIVS` assertion in `CvCultureClasses.cpp`.

The corrected source restricts the loop to living major civilizations, safely handles a missing capital, and writes explicit zeroes to unused tourism-bit buildings. Because Civ V loads the original script as a private `InGameUIAddin`, this repair cannot be injected by the SQL compatibility mod. Run the source-patch installer once:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\Install-MarvelJeanGreyFix.ps1
```

The installer recognizes the original and Local Optimized v4 folder names, verifies the known unsafe code before changing anything, and keeps `.bak-before-solusgo-jean-grey-fix` backups.

## Installation

Open `SolusGoCompatibilityFixes.civ5sln` in ModBuddy and build the project, or place the built **SolusGo's Compatibility Fixes (v 1)** folder in the Civilization V `MODS` directory. Enable it alongside the Community Patch and your normal mod collection.

The affected third-party packs are optional references, not hard dependencies. A repair is applied only when its matching database content exists.

This mod affects saved games. Keep it enabled for saves started with it.

## Validation

The SQL is conditional and safe to execute repeatedly. To verify it against a
populated Civ V cache without changing that cache, run:

```powershell
python Tools\validate_compatibility.py "C:\path\to\Civ5DebugDatabase.db"
```

The validator works on a temporary copy and checks every currently supported
repair after applying the patch twice.

## Scope and limitations

This project is the central home for additive third-party compatibility repairs discovered while testing the Chorus. It intentionally does not edit the installed source of other mods.

Some Lua faults cannot be repaired additively. Civ V gives a compatibility add-on no safe way to unregister a callback owned by another Lua context. The Jean Grey crash therefore includes an explicit source patch and installer. Tar's Arabian Split has the same architectural limitation for its private `SerialEventUnitCreated` callback; its database and Civilopedia failure is fixed here, but replacing that callback still requires a corrected release of the original pack.
