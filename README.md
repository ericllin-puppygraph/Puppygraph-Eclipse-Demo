# PuppyGraph Supply Chain Demo

Explore Eclipse Tractus-X assembly data and planned product dependencies using DuckDB and PuppyGraph. Start with a small vehicle–battery–module–cell path, then follow an inferred match from the cell to its planned cathode material dependency.

Both original JSON files are included with their original filenames and contents. One command builds and validates the database; another starts PuppyGraph and uploads the graph mapping.

## What the graph contains

| Graph element | Meaning | Count |
| --- | --- | ---: |
| `part` | Supplied serial parts and batches, plus missing-endpoint placeholders | 499 |
| `contains` | Parent-to-child relationships from the as-built BOM | 765 |
| `part_type` | Planned products, components, and materials | 42 |
| `planned_contains` | Parent-to-child dependencies from the planned BOM | 70 |
| `matches_type` | Inferred instance-to-type matches | 266 |

That is **541 nodes and 1,101 edges**. The two source files have separate IDs. The loader connects them only when a business partner and manufacturer part number match exactly and identify one planned type. These bridges are explicitly marked `is_inferred = true`.

## Requirements

- Python 3.9 or newer with `pip` and `venv`; Conda is not required.
- Docker with Docker Compose. On macOS, install and open [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/).
- Bash and `curl`; the commands below use a macOS/Linux terminal.
- Internet access for dependencies, the Docker image, and the DuckDB JDBC driver.
- Available local ports **8081**, **8182**, and **7687**.

The configuration pins PuppyGraph `1.13.0`, DuckDB Python `1.4.3`, and DuckDB JDBC `1.4.3.0`.

## Fresh setup

Download or clone the repository. Open the folder containing `requirements.txt` and `docker-compose.yaml` in VS Code or a terminal. Run the commands below from that folder.

### Create the Python environment

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
```

In VS Code, install Microsoft's Python extension, open **Python: Select Interpreter** from the Command Palette, and select `.venv/bin/python`.

### Load and validate both datasets

```bash
python3 scripts/load.py
```

Expected output, followed by the database path:

```text
Validation passed:
  499 parts (5 placeholders), 765 as-built relationships
  42 planned types, 70 planned relationships
  266 inferred instance-to-type matches
```

This generates `data/supply_chain_demo.db`. The loader checks counts, IDs, relationship endpoints, and inferred matches before committing. If extraction or validation fails, the transaction rolls back.

### Start PuppyGraph and upload the schema

Open Docker Desktop and wait for its engine to start, then run:

```bash
bash scripts/start.sh
```

The script checks prerequisites, starts the container, waits for the API, and uploads `schema.json`. The first run can take several minutes. **You do not need to upload any JSON manually when this succeeds.**

Open [http://localhost:8081](http://localhost:8081) and sign in:

| Field | Value |
| --- | --- |
| Username | `puppygraph` |
| Password | `puppygraph123` |

These local demo credentials are configured in `docker-compose.yaml`. Ports bind to `127.0.0.1`.

The **Graph** page shows the model. Open **Query**, select **Cypher**, and run the examples below to see actual data.

## Updating an existing copy

If you already ran the earlier version, stop its container **before replacing files or rebuilding the database**:

```bash
docker compose stop
```

Copy the updated repository files into your existing folder, preserving your `.git` directory and `.venv`. Alternatively, extract into a fresh folder and follow Fresh setup after stopping the old container. Both source files must be present in `data/`:

- `CX_Testdata_v1.7.0_PartInstance-reduced.json`
- `CX_Testdata_v.1.7.0_PartType.json`

From the updated repository root, run:

```bash
source .venv/bin/activate
python3 -m pip install -r requirements.txt
python3 scripts/load.py
bash scripts/start.sh
```

The last command uploads the expanded mapping. Restarting the old container alone does not add the new node and edge labels.

## Explore meaningful paths

Run each statement separately in the Cypher editor. Use the graph result view for queries returning paths and the table view for counts and attributes.

### Check the graph

Run the statements in [`queries/01-check-counts.cypher`](queries/01-check-counts.cypher). Expected counts are listed in the file and in the table above. There are five placeholder parts and 228 supplied parts without an inferred type match.

### Follow a planned material dependency

```cypher
MATCH path = (vehicle:part_type)-[:planned_contains*1..5]->(material:part_type)
WHERE vehicle.type_id = 'urn:uuid:0733946c-59c6-41ae-9570-cb43a6e4c79e'
  AND material.type_id = 'urn:uuid:4f7b1cf2-a598-4027-bc78-63f6d8e55699'
RETURN path;
```

This shows **Vehicle Model A → OEM A High Voltage Battery → HV Modul → ZB ZELLE → N Tier A CathodeMaterial**. It is a planned dependency chain. The source names are preserved; IDs distinguish records with similar names.

[`queries/03-planned-dependencies.cypher`](queries/03-planned-dependencies.cypher) also lists the cell's planned material quantity, unit, and validity dates.

### Inspect the inferred matches

```cypher
MATCH (p:part)-[m:matches_type]->(t:part_type)
RETURN t.name, m.match_basis, m.is_inferred, count(p) AS matched_parts
ORDER BY matched_parts DESC;
```

| Planned type | Matched parts |
| --- | ---: |
| ZB ZELLE | 250 |
| HV Modul | 13 |
| OEM A High Voltage Battery | 3 |

The full queries and three individual examples are in [`queries/04-instance-type-matches.cypher`](queries/04-instance-type-matches.cypher).

### Connect a supplied assembly to its planned material dependency

```cypher
MATCH physical = (vehicle:part)-[:contains*1..5]->(cell:part)
MATCH design = (cell)-[:matches_type]->(type:part_type)
               -[:planned_contains]->(material:part_type)
WHERE vehicle.part_id = 'urn:uuid:ef7d8432-679d-4bda-a277-ca9e9c5d11d1'
  AND cell.part_id = 'urn:uuid:ff827b41-9718-47c2-9786-e4f866889f60'
  AND material.type_id = 'urn:uuid:4f7b1cf2-a598-4027-bc78-63f6d8e55699'
RETURN physical, design;
```

The result contains two paths sharing the cell: a vehicle–battery–module–cell assembly and a cell–planned type–cathode material path. Their combined graph has six nodes and five edges. This focused view avoids displaying hundreds of similarly named parts at once.

This query is saved in [`queries/05-assembly-to-material.cypher`](queries/05-assembly-to-material.cypher). It shows a candidate connection to a planned dependency; it does **not** establish which material batch was physically used or prove design compliance.

For general part browsing, use [`queries/02-explore-parts.cypher`](queries/02-explore-parts.cypher).

## Mapping and data interpretation

| Graph label | DuckDB table | ID and direction |
| --- | --- | --- |
| `part` | `supply_chain.part` | `part_id` |
| `part_type` | `supply_chain.part_type` | `type_id` |
| `contains` | `supply_chain.contains` | `edge_id`; part parent → part child |
| `planned_contains` | `supply_chain.planned_contains` | `edge_id`; type parent → type child |
| `matches_type` | `supply_chain.part_type_match` | `edge_id`; part → type |

The loader extracts `SerialPart` 3.0.0, `Batch` 3.0.0, and `SingleLevelBomAsBuilt` 3.0.0 from the instance file. It extracts `PartAsPlanned` 2.0.0 and `SingleLevelBomAsPlanned` 3.0.0 from the type file. The type file's `PlainObject` metadata record and top-level generator helpers are excluded. Other aspect models remain in the source files but are not mapped.

Matching uses the containing record's `bpnl` and the description's `partTypeInformation.manufacturerPartId`. Both values must be nonempty and equal across files. Compound keys shared by several planned types are excluded from matching. Names are never used to infer identity. Unmatched parts remain in the graph.

Every `matches_type` edge has `match_basis = 'business_partner_and_part_number'` and `is_inferred = true`. Matching does not check temporal validity, revisions, or actual material consumption. Planned BOM validity dates are preserved as strings, and queries show the bundled historical snapshot without filtering to today's date.

Source names, dates, quantities, and units are retained. The reduced instance file contains 494 supplied records and five unresolved child IDs, represented as `is_placeholder = true` with null descriptive attributes. This is test data: repeated “Mirror left” names and implausible assembly combinations are preserved. Adding planned types does not repair those source relationships.

IDs are mapped as queryable attributes as well as graph identifiers. Source BOM edge IDs are stable for unchanged input and include source array positions; reordering those arrays can change IDs. Inferred match edge IDs depend only on the instance and type IDs.

## How the data reaches PuppyGraph

The Python loader converts source JSON into DuckDB tables. PuppyGraph runs in Docker and reads `data/supply_chain_demo.db` at `/home/share/supply_chain_demo.db`. DuckDB needs no separate server. The Docker volume `puppygraph-storage` stores PuppyGraph's own state.

**`schema.json` is the PuppyGraph graph mapping uploaded to the service.** It is not a JSON Schema for validating either dataset, and the original source files are not uploaded to PuppyGraph.

If you start the container manually with `docker compose up -d`, upload the mapping through **Graph → Upload Schema**, selecting `schema.json` and **Do not cache data** if prompted. Alternatively:

```bash
curl --fail-with-body --show-error \
  --user 'puppygraph:puppygraph123' \
  --header 'Content-Type: application/json' \
  --data-binary @schema.json \
  'http://localhost:8081/schema?postUploadBehavior=none'
```

## Stop, restart, and rebuild

Stop the container:

```bash
docker compose stop
```

Restart without changing the database or mapping:

```bash
docker compose start
```

Rebuild the bundled snapshot and reapply the mapping:

```bash
docker compose stop
source .venv/bin/activate
python3 scripts/load.py
bash scripts/start.sh
```

Do not run the loader while PuppyGraph or another process has the DuckDB file open. The loader replaces the five demo tables in one transaction, including validation. Snapshot counts intentionally target the bundled files; review the validation expectations if you substitute different data.

`docker compose down` removes the container and network while retaining the database and storage volume. Run `bash scripts/start.sh` to recreate the container and reapply the mapping.

## Repository layout

| Path | Purpose |
| --- | --- |
| `README.md` | Setup, query examples, and data interpretation |
| `data/*.json` | Both original source snapshots |
| `requirements.txt` | Pinned Python dependency |
| `scripts/load.py` | Transactional load and validation runner |
| `scripts/load.sql` | Create five tables and infer unique matches |
| `scripts/validate.sql` | Verify snapshot counts and relationship integrity |
| `scripts/start.sh` | Start PuppyGraph and upload the mapping |
| `schema.json` | Map tables to two node labels and three edge labels |
| `docker-compose.yaml` | Local PuppyGraph container configuration |
| `queries/*.cypher` | Count checks and focused graph exploration |
| `third_party/tractusx/` | Upstream notice and license texts |

Generated databases, Python environments, and credentials in `.env` are excluded by `.gitignore`. They are not needed in a public GitHub repository.

## Troubleshooting

```bash
docker compose ps
docker compose logs --tail=80 puppygraph
```

| Problem | Action |
| --- | --- |
| Python or pip not found | Use `python3` and `python3 -m pip`. |
| DuckDB module missing | Activate `.venv` and install `requirements.txt`. |
| VS Code uses the wrong Python | Select `.venv/bin/python`. |
| Docker engine unavailable | Open Docker Desktop and wait for it to start. |
| Port already allocated | Stop the other application using the configured ports. |
| Source JSON missing | Check both exact filenames in `data/`, including `v.1.7.0` in the PartType filename. |
| Database missing | Run `python3 scripts/load.py`. |
| Database lock error | Stop PuppyGraph and close other database connections. |
| Validation failure | Check that both bundled snapshots are unchanged; table updates were rolled back. |
| New labels absent | Run `bash scripts/start.sh` to upload the updated mapping. |
| Driver download fails | Check container access to `repo.maven.apache.org`. |
| Schema upload fails | Inspect the API error and container logs; upload `schema.json`. |

## Source and attribution

The data is produced and maintained by the [Eclipse Tractus-X Item Relationship Service](https://github.com/eclipse-tractusx/item-relationship-service) project. Both files match upstream commit `d787ff133797eaaf0bb8c4990024a08c2c992027` byte for byte:

- [CX_Testdata_v1.7.0_PartInstance-reduced.json](https://github.com/eclipse-tractusx/item-relationship-service/blob/d787ff133797eaaf0bb8c4990024a08c2c992027/local/testing/testdata/CX_Testdata_v1.7.0_PartInstance-reduced.json)
- [CX_Testdata_v.1.7.0_PartType.json](https://github.com/eclipse-tractusx/item-relationship-service/blob/d787ff133797eaaf0bb8c4990024a08c2c992027/local/testing/testdata/CX_Testdata_v.1.7.0_PartType.json)

SHA-256, in that order:

```text
3513041264793ae81d8e4a21cb9fd6127d7f484ec4b3b98f2425d0963dbd48af
69f73de2c99f09abfa9a2244ed666faefd718873f2a2f4182e7ae576f67c65ff
```

The original files are unmodified; relational tables and inferred matches are derived by this demo. Upstream [AUTHORS.md](third_party/tractusx/AUTHORS.md), [NOTICE.md](third_party/tractusx/NOTICE.md), [LICENSE](third_party/tractusx/LICENSE), and [LICENSE_non-code](third_party/tractusx/LICENSE_non-code) are retained for attribution and license context. Those texts apply to upstream material; this repository does not assign a new license to that material or choose a license for the demo's own code.

## References

- [PuppyGraph DuckDB setup](https://docs.puppygraph.com/getting-started/querying-duckdb-data-as-a-graph/)
- [Graph modeling](https://docs.puppygraph.com/modeling/building-a-graph/)
- [Schema management](https://docs.puppygraph.com/modeling/managing-the-graph/)
