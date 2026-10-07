# Step 3: connect PuppyGraph and run the demo

You have already run the loader successfully. Keep that generated database.
This update adds Docker configuration, a graph schema, startup automation,
four Cypher query files, and a recursive SQL comparison. It contains only new
files. It does not include or rename the source JSON, or replace your loader.

## Put the new files in your existing project

Merge the ZIP contents into the existing project, preserving subfolders:

- `docker-compose.yaml`, `schema.json`, and `STEP3.md` go in the project root.
- `start.sh` goes inside your existing `scripts/` folder alongside `load.py`.
- `queries/` and `sql/` go in the project root.

Copy the files inside `scripts/` into the existing directory; do not replace
the entire existing `scripts/` directory. Your original source remains
`data/CX_Testdata_v1.7.0_PartInstance-reduced.json`.

## Start

Install [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/)
if needed, open it, and wait for the engine to run.

In VS Code's terminal, from your existing project folder:

```bash
docker compose version
bash scripts/start.sh
```

The initial image download can take a few minutes. The script checks that your
database exists, starts PuppyGraph, waits for its API, and uploads `schema.json`.
It applies the supplied mapping to this demo instance when run again.

Open http://localhost:8081 and sign in with:

| Field | Value |
| --- | --- |
| Username | `puppygraph` |
| Password | `puppygraph123` |

These are local demo credentials. Ports are bound to this computer's loopback
interface. Stop another demo using 8081, 8182, or 7687 before starting this one.

## Run the queries

Open **Query**, select **Cypher**, and paste one statement at a time.

1. `queries/01-check-counts.cypher`: verify 499 nodes, 765 edges, 5 placeholders.
2. `queries/02-explore-vehicle.cypher`: visualize one vehicle's direct components.
3. `queries/03-trace-component.cypher`: trace one battery cell to its containing
   module, battery, and vehicle. This returns 3 paths in the supplied snapshot.
4. `queries/04-affected-vehicles.cypher`: return the single containing vehicle.

The battery-cell ID is `urn:uuid:ff827b41-9718-47c2-9786-e4f866889f60`.
Its observed chain is:

| Level above the cell | Name | Part ID |
| --- | --- | --- |
| 0 | ZB ZELLE | urn:uuid:ff827b41-9718-47c2-9786-e4f866889f60 |
| 1 | HV MODUL | urn:uuid:5dcb2c19-472a-4e31-b129-8d09e3646ff6 |
| 2 | Battery | urn:uuid:17771314-f33b-4a8e-8ed5-5cdd87187ae8 |
| 3 | Vehicle Fully Electric | urn:uuid:ef7d8432-679d-4bda-a277-ca9e9c5d11d1 |

The demo scenario is a hypothetical defect. The source has assembly links,
not defect reports. Vehicle identification uses the observed name in this
snapshot, not a general vehicle-classification rule. Five-hop queries are
bounded traversals, not exhaustive impact analysis for arbitrary datasets.

## What Docker and the schema do

DuckDB is embedded and stores these tables in one file; it does not need a
separate running database server. The Python loader already prepared the file.
Docker makes `data/supply_chain_demo.db` available to PuppyGraph at
`/home/share/supply_chain_demo.db`. A separate volume stores PuppyGraph's state.

| Graph element | Table | ID / endpoints |
| --- | --- | --- |
| `part` node | `supply_chain.part` | `part_id` |
| `contains` edge | `supply_chain.contains` | `edge_id`; `parent_id` → `child_id` |

IDs are also mapped as attributes, so `p.part_id` works in Cypher.
The v1 schema selects external data sources, and the upload explicitly uses
`postUploadBehavior=none`. This leaves the graph reading the DuckDB tables.
The mapping does not request replication into PuppyGraph local tables.

PuppyGraph is pinned to image `1.13.0`. The DuckDB JDBC driver is explicitly
set to `1.4.3.0` to match the DuckDB 1.4.3 loader. PuppyGraph downloads that
driver from Maven Central when connecting; the container needs internet access.

## Stop, restart, and rebuild

Stop while retaining the container and its state:

```bash
docker compose stop
```

Restart after the first successful setup:

```bash
docker compose start
```

If you change or reload the input, stop PuppyGraph before using the loader:

```bash
docker compose stop
source .venv/bin/activate
python3 scripts/load.py
docker compose start
```

DuckDB does not allow an independent writer while another process uses the
database. Do not reload it while PuppyGraph is running.

## SQL comparison (optional)

Stop PuppyGraph first, activate `.venv`, and run from the project root:

```bash
python3 - <<'PY'
from pathlib import Path
import duckdb
with duckdb.connect('data/supply_chain_demo.db', read_only=True) as db:
    print(db.execute(Path('sql/sql_comparison.sql').read_text()).fetchall())
PY
```

This returns the same vehicle ID as query 04. The comparison illustrates query
expression, not a performance claim on this small test dataset.

## If startup fails

```bash
docker compose ps
docker compose logs --tail=80 puppygraph
```

- Docker engine unavailable: open Docker Desktop and wait for it to start.
- Port already allocated: stop the other demo using that port.
- Missing database: confirm `data/supply_chain_demo.db` exists in this project.
- Driver download fails: check the container's internet/proxy access to Maven Central.
- Schema upload or query error: retain the full error and recent container logs.

## Verification and references

The mapping's columns and types were checked against the generated DuckDB tables.
The recursive SQL was executed and the selected component's paths were verified
against the dataset. Shell syntax was checked. Docker and PuppyGraph runtime
execution were not possible in the assistant's environment; confirm the three
counts in query 01 on your Mac before presenting the demo.

- [DuckDB setup](https://docs.puppygraph.com/getting-started/querying-duckdb-data-as-a-graph/)
- [Graph fields and identifiers](https://docs.puppygraph.com/modeling/building-a-graph/)
- [Schema upload behavior](https://docs.puppygraph.com/modeling/managing-the-graph/)
- [DuckDB driver compatibility and concurrent access](https://docs.puppygraph.com/connecting/connecting-to-duckdb/)
- [Docker setup](https://docs.puppygraph.com/getting-started/launching-puppygraph-in-docker/)
