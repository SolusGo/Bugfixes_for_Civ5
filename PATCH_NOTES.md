# Patch Notes

## Source patch update — 2026-08-28

- Added a guarded source patch and installer for Joker's runaway Golden Age conversion. The conversion now runs once per Golden Age, recovers affected saves by removing only surplus temporary explosive Clowns, safely detonates from a unit snapshot, and cannot reduce an Amusement Park city below 1 Population.

## Version 1 — 2026-08-24

- Fixed the Community Patch `NO_UNITAI` termination caused by Shivaji's Conscript Citizens.
- Fixed the stock Civilopedia failing to load because Tar's Arabian Split leaves Arabia without a leader association.
- Fixed Justinian's Byzantium initialization error caused by invalid hidden-building defaults from the DC and Marvel Super Civ packs.
- Added a standalone ModBuddy project with optional references to the affected mods.
- Added a guarded source patch and installer for Jean Grey's fatal Community Patch tourism assertion. Her trait now queries influence only for living major civilizations and safely handles missing capitals and zero-value tourism bits.
