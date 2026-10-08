#!/usr/bin/env python3
"""Build and validate the bundled snapshots in one transaction."""
import os
from pathlib import Path
import sys

try:
    import duckdb
except ImportError:
    sys.exit('Install the dependency first: python3 -m pip install -r requirements.txt')

ROOT = Path(__file__).resolve().parents[1]


def main():
    os.chdir(ROOT)
    output = ROOT / 'data' / 'supply_chain_demo.db'
    # Stop PuppyGraph before opening this database for writing.
    with duckdb.connect(str(output)) as connection:
        connection.execute('BEGIN TRANSACTION')
        try:
            connection.execute((ROOT / 'scripts' / 'load.sql').read_text())
            connection.execute((ROOT / 'scripts' / 'validate.sql').read_text())
            counts = {
                table: connection.execute(f'SELECT count(*) FROM supply_chain.{table}').fetchone()[0]
                for table in ('part', 'contains', 'part_type', 'planned_contains', 'part_type_match')
            }
            placeholders = connection.execute(
                'SELECT count(*) FROM supply_chain.part WHERE is_placeholder'
            ).fetchone()[0]
            connection.execute('COMMIT')
        except Exception:
            connection.execute('ROLLBACK')
            raise
    print('Validation passed:')
    print(f"  {counts['part']} parts ({placeholders} placeholders), {counts['contains']} as-built relationships")
    print(f"  {counts['part_type']} planned types, {counts['planned_contains']} planned relationships")
    print(f"  {counts['part_type_match']} inferred instance-to-type matches")
    print(f'Database: {output}')


if __name__ == '__main__':
    try:
        main()
    except (duckdb.Error, OSError) as exc:
        sys.exit(f'Loading failed: {exc}')
