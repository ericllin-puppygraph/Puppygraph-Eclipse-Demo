#!/usr/bin/env python3
"""Build and verify the demo database; run from any working directory."""
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
    # load.sql is transactional: failed extraction rolls back table changes.
    # Do not run while PuppyGraph is using this database.
    with duckdb.connect(str(output)) as connection:
        connection.execute((ROOT / 'scripts' / 'load.sql').read_text())
        connection.execute((ROOT / 'scripts' / 'validate.sql').read_text())
        parts, placeholders = connection.execute(
            'SELECT count(*), count(*) FILTER (WHERE is_placeholder) '
            'FROM supply_chain.part'
        ).fetchone()
        edges = connection.execute('SELECT count(*) FROM supply_chain.contains').fetchone()[0]
    print(f'Validation passed: {parts} parts ({placeholders} placeholders), {edges} relationships.')
    print(f'Database: {output}')


if __name__ == '__main__':
    try:
        main()
    except (duckdb.Error, OSError) as exc:
        sys.exit(f'Loading failed: {exc}')
