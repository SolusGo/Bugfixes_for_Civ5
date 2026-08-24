"""Validate compatibility SQL against a copy of a populated Civ V database."""

from __future__ import annotations

import argparse
from contextlib import closing
import shutil
import sqlite3
import tempfile
from pathlib import Path


def scalar(connection: sqlite3.Connection, query: str) -> int:
    row = connection.execute(query).fetchone()
    return int(row[0]) if row else 0


def validate_noop(sql: str) -> None:
    """Confirm the patch changes nothing when none of its target mods exist."""
    with closing(sqlite3.connect(":memory:")) as connection:
        connection.executescript(
            """
            CREATE TABLE Units (Type TEXT);
            CREATE TABLE Unit_AITypes (UnitType TEXT, UnitAIType TEXT);
            CREATE TABLE Civilizations (Type TEXT);
            CREATE TABLE Leaders (Type TEXT);
            CREATE TABLE Civilization_Leaders (
                CivilizationType TEXT,
                LeaderheadType TEXT
            );
            CREATE TABLE BuildingClasses (Type TEXT, DefaultBuilding TEXT);
            CREATE TABLE Buildings (
                Type TEXT PRIMARY KEY,
                BuildingClass TEXT,
                Description TEXT,
                Help TEXT,
                Cost INTEGER,
                FaithCost INTEGER,
                GreatWorkCount INTEGER,
                PrereqTech TEXT,
                NukeImmune INTEGER,
                NeverCapture INTEGER,
                HurryCostModifier INTEGER,
                MinAreaSize INTEGER,
                ArtDefineTag TEXT,
                ShowInPedia INTEGER
            );
            """
        )
        connection.executescript(sql)
        connection.executescript(sql)
        changed_rows = sum(
            scalar(connection, f"SELECT COUNT(*) FROM {table}")
            for table in (
                "Unit_AITypes",
                "Civilization_Leaders",
                "Buildings",
            )
        )
        if changed_rows:
            raise SystemExit(
                f"No-op validation failed: inserted {changed_rows} unexpected rows"
            )
        print("PASS  No supported third-party content: patch is inert")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("database", type=Path, help="Path to Civ5DebugDatabase.db")
    args = parser.parse_args()

    sql_path = Path(__file__).parents[1] / "SQL" / "CompatibilityFixes.sql"
    if not args.database.is_file():
        raise SystemExit(f"Database not found: {args.database}")

    sql = sql_path.read_text(encoding="utf-8")
    validate_noop(sql)

    with tempfile.TemporaryDirectory(prefix="solusgo-civ5-compat-") as temp_dir:
        test_database = Path(temp_dir) / "Civ5DebugDatabase.db"
        shutil.copy2(args.database, test_database)

        with closing(sqlite3.connect(test_database)) as connection:
            connection.executescript(sql)
            connection.executescript(sql)  # Every repair must be idempotent.

            checks = {
                "Shivaji conscription has one valid UnitAI": scalar(
                    connection,
                    """
                    SELECT COUNT(*) FROM Unit_AITypes
                    WHERE UnitType = 'UNIT_MC_CONSCRIPTION'
                      AND UnitAIType = 'UNITAI_ATTACK'
                    """,
                ),
                "Arabia has a leader association": scalar(
                    connection,
                    """
                    SELECT COUNT(*) FROM Civilization_Leaders
                    WHERE CivilizationType = 'CIVILIZATION_ARABIA'
                    """,
                ),
                "Batman hidden class has a valid default": scalar(
                    connection,
                    """
                    SELECT COUNT(*)
                    FROM BuildingClasses AS c
                    JOIN Buildings AS b ON b.Type = c.DefaultBuilding
                    WHERE c.Type = 'BUILDINGCLASS_BAD_HIDDEN'
                    """,
                ),
                "Both Jean Grey dummy defaults exist": scalar(
                    connection,
                    """
                    SELECT COUNT(*)
                    FROM BuildingClasses AS c
                    JOIN Buildings AS b ON b.Type = c.DefaultBuilding
                    WHERE c.Type IN (
                        'BUILDINGCLASS_JGR_WRITER',
                        'BUILDINGCLASS_JGR_CULTURE'
                    )
                    """,
                ),
            }

            expected = {
                "Shivaji conscription has one valid UnitAI": 1,
                "Arabia has a leader association": 1,
                "Batman hidden class has a valid default": 1,
                "Both Jean Grey dummy defaults exist": 2,
            }
            failures = [
                f"{name}: expected {expected[name]}, got {value}"
                for name, value in checks.items()
                if value != expected[name]
            ]
            if failures:
                raise SystemExit("Validation failed:\n- " + "\n- ".join(failures))

            for name, value in checks.items():
                print(f"PASS  {name}: {value}")


if __name__ == "__main__":
    main()
