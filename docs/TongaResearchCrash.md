# Tonga first-contact Science crash — 2026-10-26

A Boundless campaign crashed during the transition to its next turn, apparently when Fertilizer completed. The Community Patch dialog reported `CvTechClasses.cpp:2408`, expression `eIndex >= 0`, and an invalid technology index. The investigation identified an unguarded Science reward in **MC's Polynesian Civilisation Pack v5**, a separate mod active in that campaign.

## Evidence

- Three native dumps from 12:25, 12:38 and 14:31 on 2026-10-26 stop at the same intentional DLL trap. These are in Civ V's separate `crashlogs` directory; ordinary `Lua.log` and Windows error reporting did not identify the fatal call.
- Reading the x86 fault frame and disassembling the installed DLL shows a Lua `ChangeResearchProgress` call with **30 Science for player 20** and the negative technology sentinel. The caller returns through the same Lua binding in all three dumps.
- The turn 257 save's 64 consecutive, length-prefixed civilization identifiers identify **player 20 as `CIVILIZATION_MC_TONGA`**. Its Boundless snapshot is schema 3, phase `IDLE`, with 13 assignments/withdrawn citizens and a matching six-yield ledger; it has no saved workforce failure.
- The installed `Lua/MC_Tonga_Functions.lua` awards 30 Science on ordinary first contact with a major civilization. Its original line passes `player:GetCurrentResearch()` directly to `ChangeResearchProgress`, including `-1` when research is unselected. Other reward branches award Faith, Culture or Gold.
- Executing that complete original Lua file against an independent negative-index precondition reproduces the fatal call. The repaired file grants the same 30 Science through overflow when research is unselected and continues to grant 30 to a valid selected technology.

The [official Release 5.4.6 source](https://github.com/LoneGazebo/Community-Patch-DLL/blob/dcb33a654cd9e8efb038a0733b4025e19cbcd8ba/CvGameCoreDLL_Expansion2/CvTechClasses.cpp#L2408) has the reported precondition in `SetResearchProgressTimes100`. Its surrounding research functions explain the invalid-index failure. The installed binary identifies itself as `Release-5.4.6-0-gb9ddca9a9`; that exact build hash is not the public tag used for source comparison. The fault offsets and caller arguments above come from the actual installed binary and local dumps.

The evidence ties the repeatable failure to Tonga's first-contact award. Fertilizer's improvement bonuses and Boundless remote yield accounting do not write native research progress. No change to those mechanics is needed for this repair.

## Repair

The optional installer [Tools/hotfix_tonga_research.py](../Tools/hotfix_tonga_research.py) changes only the Science branch:

```lua
local researchID = player:GetCurrentResearch()
if researchID and researchID >= 0 then
    Teams[player:GetTeam()]:GetTeamTechs():ChangeResearchProgress(researchID, reward, playerID)
else
    player:ChangeOverflowResearch(reward)
end
```

This preserves the reward amount, the existing first-contact multiplier, other reward types and notification behavior. It introduces no event, persistent state, new technology choice or recurring update. Overflow belongs to the same player and is available to normal research afterward.

This source repair belongs to **SolusGo's Compatibility Fixes**, alongside its Jean Grey, Joker and Vibranium installers. Civ V isolates the original callback in a private Lua context, so enabling the SQL compatibility mod alone cannot replace it. The installer patches the separately installed **Polynesian pack** once; it adds no override to the compatibility mod's VFS. No SQL, UUID, version or save schema changes are required. The reviewed replacement is also retained under `Source Patches/MC's Polynesian Civilisation Pack v5/Lua/MC_Tonga_Functions.lua`.

## Installation

Use Python 3 from a checkout of this repository. The default target is the standard Documents mod folder; `--mod-dir` can select another installed copy.

1. Fully exit Civilization V.
2. Inspect the proposed target without writing anything:

   ```powershell
   python Tools/hotfix_tonga_research.py
   ```

3. Apply the verified fix:

   ```powershell
   python Tools/hotfix_tonga_research.py --apply
   ```

The installer accepts only the reviewed v5 mod UUID, original source hash and matching manifest checksum. It preserves CRLF and every unrelated byte. It backs up the original Lua and manifest under `dist/tonga-research-backups/`, patches that one Lua file, and updates only its manifest MD5. A verification failure rolls both files back. An already installed repair is recognized without another write; unknown variants are rejected.

Reviewed original SHA-256: `16cc0405489a3ae49ac0109ee629d89e0b210b5a1651892ef70131ae9fdeee1f`.

Repaired SHA-256: `03481951e7384e132f9b865ca50ab70a5994704811cfadd374193eedc27cbba3`.

No saves or cache databases are edited. Restart through **Mods**, enable the same mods, and reload the pre-crash save. A new campaign is not required. Reinstalling the Polynesian pack may overwrite its repair, so rerun the read-only check afterward.

## Validation and remaining check

`Tools/test_tonga_research.py` tests the original negative-index failure, valid research, absent/negative research, 15/30/60-Science amounts, byte preservation, unknown-source/version/UUID rejection, running-game refusal, backups, manifest scope, idempotence and rollback. With `--source` pointing to the original or repaired installed Lua, it also executes the complete external script. Tests require Lupa's Lua 5.1 runtime.

All eleven existing Boundless Lua suites passed. An additional local diagnostic exercised Fertilizer's four affected improvement categories, 13 remote citizens, fresh-water Farm exclusion, a thousand dirty notifications, idle frames and reload. Those are simulations; they do not replace native game acceptance.

**Remaining acceptance:** reload the turn 257 save and complete the turn that previously crashed, then continue another turn. Confirm that Tonga's next contact award no longer produces the invalid-index dialog. Keep the original save for comparison. The native replay after installing this repair has not yet been confirmed.
