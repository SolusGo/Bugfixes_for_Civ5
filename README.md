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

### Super Civs — Joker runaway temporary Clowns

Joker's Golden Age conversion originally checked `IsGoldenAge()` every turn. With Community Patch, that state can remain visible while the converted Anarchy is active, so the script repeatedly spawned one explosive Clown per city. Long-running saves could accumulate hundreds of temporary Clowns, causing severe turn delays and an unreadable map.

The corrected script records each conversion as a persistent one-shot state, suppresses the residual Golden Age without spawning again, safely iterates unit snapshots during detonation, and prevents Amusement Parks from reducing a city below 1 Population. When an affected save next reaches Joker's turn, it retains at most one temporary explosive Clown per Joker city and silently removes only surplus Clowns carrying `PROMOTION_JOK_DEATH`; ordinary built or converted Clowns are preserved.

This private `InGameUIAddin` must also be repaired at its source. Run the installer once:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\Install-DCJokerFix.ps1
```

The installer recognizes the original and Local Optimized DC v4 folders, refuses unknown source versions, updates the manifest hash, and keeps `.bak-before-solusgo-joker-fix` backups. It is safe to run again.

### Super Civs — stale Vibranium after city transfer

Black Panther's Vibranium is supplied by an invisible building rather than map deposits. In affected saves, transferring a Black Panther city can leave that virtual resource in the Community Patch's map-tile counter for the new owner. The Community Patch then reports a mismatch such as `Stored: 2, counted: 0` during its resource audit.

The corrected Black Panther script removes captured Vibranium dummy buildings from other civilizations and repairs only their non-building Vibranium remainder. It runs once when a save opens and again at the start of each player's turn, so existing affected saves are repaired as well as future city transfers.

This private `InGameUIAddin` must be repaired at its source. With Civilization V closed, run:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\Install-MarvelVibraniumFix.ps1
```

The installer recognizes both Marvel v4 folder names, refuses unknown source versions, updates the manifest hash, and keeps `.bak-before-solusgo-vibranium-fix` backups. It is safe to run again.

### MC's Polynesian Civilisation Pack — Tonga first-contact Science crash

Tonga's first-contact Science bonus passed an invalid technology ID to the Community Patch when no research was selected, causing a fatal research-index check during turn transitions. The repaired source grants the same Science through overflow in that situation and continues to fund selected research normally.

This private Lua callback follows the same source-patch workflow as the Super Civ repairs above. With Civilization V closed, inspect and apply the verified v5 repair:

```powershell
python Tools/hotfix_tonga_research.py
python Tools/hotfix_tonga_research.py --apply
```

The installer checks the mod UUID, source hash and manifest checksum, preserves unrelated bytes, keeps backups, and recognizes an already installed repair. The corrected Lua is also included under `Source Patches/MC's Polynesian Civilisation Pack v5/`. See the [crash evidence, tests and continuation check](docs/TongaResearchCrash.md). Enabling the SQL mod alone does not patch the external Lua file.

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

This project is the central home for third-party compatibility repairs discovered while testing the Chorus. The built SQL mod remains additive and does not edit other mods; explicitly run source-patch installers are provided only where Civ V's isolated Lua contexts make an additive repair impossible.

Some Lua faults cannot be repaired additively. Civ V gives a compatibility add-on no safe way to unregister a callback owned by another Lua context. The Jean Grey and Joker repairs therefore include explicit source patches and installers. Tar's Arabian Split has the same architectural limitation for its private `SerialEventUnitCreated` callback; its database and Civilopedia failure is fixed here, but replacing that callback still requires a corrected release of the original pack.
