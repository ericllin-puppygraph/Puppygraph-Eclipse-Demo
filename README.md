# PuppyGraph supply-chain demo — step 2: prepare the data

This step converts the supplied Eclipse Tractus-X test data into relational tables.
The next step will add Docker services and a PuppyGraph schema that maps those tables
to a graph. This package does not launch PuppyGraph yet.

## What is included

| File | Purpose |
| --- | --- |
| `data/CX_Testdata_v1.7.0_PartInstance-reduced.json` | Byte-for-byte copy of your supplied source file |
| `scripts/load.sql` | Extract parts and as-built parent → child relationships |
| `scripts/validate.sql` | Check this dataset's counts and relationship endpoints |
| `scripts/load.py` | Run both SQL files and close the database cleanly |
| `requirements.txt` | Pin the DuckDB version used for this step |
| `data/README.md` | Record source provenance and transformation choices |

## Add these files to your existing project

Unzip the package. Copy `scripts/`, `requirements.txt`, and the two README files
into your existing `~/Projects/Puppygraph-supply-chain-demo` folder, maintaining
the same subfolders. Your existing `data/CX_Testdata_v1.7.0_PartInstance-reduced.json` can stay where it
is; the package includes the same input for convenience. Keep your existing Git
repository. No Git metadata or sample hooks are needed from the upload.

## Run on your Mac

Requires Python 3.9 or newer. From Terminal:

```bash
cd ~/Projects/Puppygraph-supply-chain-demo
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
python3 scripts/load.py
```

Expected output:

```text
Validation passed: 499 parts (5 placeholders), 765 relationships.
```

The database is written to `data/supply_chain_demo.db`. The included `.gitignore`
keeps generated databases and the Python environment out of Git. You do not
need to install a separate DuckDB application. Docker is not needed for this step.

## What the tables mean

`supply_chain.part` has one row for each of the 494 supplied item IDs and five
placeholder rows for child IDs whose details are absent. Attributes include
the name, country, manufacturing date, source business partner ID, manufacturer
part ID, source record type, and `is_placeholder` flag.

`supply_chain.contains` has 765 rows. Each means **parent contains child**.
The quantity and unit are copied from that specific direct relationship.
`child_business_partner_id` is the relationship's business-partner field;
it is not used to guess the manufacturer of an unknown part.

Only `SingleLevelBomAsBuilt` version 3.0.0 is extracted. Other models, including
planned/specification relationships and reverse usage relationships, are left
in the source JSON. Adding them to the same edge table would change its meaning.

An edge ID is a deterministic hash of its parent, model, source array positions,
and child. Re-running the unchanged input yields identical IDs. Reordering the
source child arrays can change those IDs; this is a snapshot loader, not an
incremental reconciliation service. Repeated relationship rows are preserved.

## Re-running and inspecting

Re-running the loader rebuilds the two demo tables inside a transaction. Stop
PuppyGraph before rebuilding once it is connected in a later step. The runner
checks the known snapshot counts after the loading transaction commits; a
count failure is reported and should be investigated before graph setup.

To see some parts after activating the Python environment:

```bash
python3 - <<'PY'
import duckdb
with duckdb.connect('data/supply_chain_demo.db', read_only=True) as db:
    for row in db.execute('''
        SELECT name, country, record_type
        FROM supply_chain.part
        WHERE NOT is_placeholder
        ORDER BY name, part_id LIMIT 10
    ''').fetchall():
        print(row)
PY
```

## Demo interpretation and next step

The intended story is: a component has a hypothetical defect; which containing
assemblies can be reached upstream? The data provides assembly relationships,
not evidence of actual defects. This is a traversal demonstration, not a speed
benchmark or a deployment of Catena-X access-policy enforcement.

After these tables load successfully, add `docker-compose.yaml`, `schema.json`,
and `scripts/start.sh`, followed by Cypher queries and a recursive SQL comparison.
PuppyGraph will read the relational tables as a graph. Converting this input JSON
into DuckDB is a preparation step for the demo.

Reference: [PuppyGraph's DuckDB tutorial](https://docs.puppygraph.com/getting-started/querying-duckdb-data-as-a-graph/).

## Verification performed for this package

The loader was run directly using DuckDB 1.4.3 against your uploaded file.
Checks covered record counts, every extracted part and relationship against an
independent JSON parse, missing endpoints, and repeat-run consistency. Docker
and PuppyGraph have not been run in this environment.
