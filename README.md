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

Some Lua faults cannot be repaired additively. In particular, Tar's Arabian Split registers a private `SerialEventUnitCreated` callback that dereferences deleted units. Civ V gives a compatibility add-on no safe way to unregister a callback owned by another Lua context. The database and Civilopedia failure from that pack is fixed here; replacing that callback would require a corrected release of the original pack.
