# PuppyGraph Supply Chain Demo

Explore how vehicle parts, product designs, and material dependencies connect using **PuppyGraph**, **DuckDB**, and Eclipse Tractus-X test data.

The demo follows a vehicle's battery assembly down to an individual cell, then connects that cell to a planned part type and its cathode material dependency. It demonstrates how graph queries can follow several levels of relationships and connect records from two datasets.

## What this demo shows

The data provides two views of a supply chain:

- **As-built:** records of individual parts and batches, with relationships describing which assemblies contain them.
- **As-planned:** product and component types, with relationships describing their planned components and materials.

For example, a particular battery cell is a `part`, while its planned design is a `part_type`. Many individual cells can match the same type.

The demo connects these views when a part and a planned type share the same business partner and manufacturer part number. This is an **inferred match** created by the loader, not an explicit relationship supplied by the source files.

You can use the included queries to answer:

1. What parts belong to an assembly?
2. Which components connect a planned vehicle model to a material?
3. Which supplied parts match a planned type?
4. How can an assembly be connected to a planned material dependency?

## How it works

The Python loader converts the two source JSON files into five DuckDB tables. PuppyGraph reads those tables through the mapping in `schema.json` and exposes them as a graph for Cypher queries. DuckDB runs as an embedded database; PuppyGraph runs in Docker.

| Graph label | Meaning | Count |
| --- | --- | ---: |
| `part` | Individual parts, batches, and placeholders for missing records | 499 |
| `part_type` | Planned products, components, and materials | 42 |
| `contains` | An assembly contains a child part | 765 |
| `planned_contains` | A planned type depends on a component or material type | 70 |
| `matches_type` | A supplied part matches one planned type by partner and part number | 266 |

Both containment relationships point **from parent to child**. A `matches_type` relationship points **from part to planned type**. The graph has **541 nodes and 1,101 edges**.

## Getting started

### Prerequisites

- Python 3.9 or newer, including `pip` and `venv`.
- Docker with Docker Compose, such as [Docker Desktop](https://docs.docker.com/desktop/).
- Bash and `curl` for the macOS/Linux commands below.
- Internet access for dependencies and available ports `8081`, `8182`, and `7687`.

The repository pins PuppyGraph `1.13.0`, DuckDB Python `1.4.3`, and DuckDB JDBC `1.4.3.0`. Conda is not required.

### Set up and load the data

Open a terminal in the repository root, where `requirements.txt` and `docker-compose.yaml` are located:

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
python3 scripts/load.py
```

In VS Code, select `.venv/bin/python` through **Python: Select Interpreter**.

The loader creates `data/supply_chain_demo.db` and reports:

```text
Validation passed:
  499 parts (5 placeholders), 765 as-built relationships
  42 planned types, 70 planned relationships
  266 inferred instance-to-type matches
```

### Start PuppyGraph

Open Docker Desktop and wait for it to start, then run:

```bash
bash scripts/start.sh
```

This starts PuppyGraph and uploads `schema.json` automatically. The first run may take several minutes. The uploaded file is the **graph mapping**; the original datasets have already been loaded into DuckDB.

Open [http://localhost:8081](http://localhost:8081) and sign in with username **`puppygraph`** and password **`puppygraph123`**. These are local demo credentials; the configured ports bind to `127.0.0.1`.

Open **Query → Cypher** to begin. Run one statement at a time. Use the **table view** for counts and properties, and the **graph view** for queries returning paths.

## Query walkthrough

The query files are numbered in the order below. The final query brings the two datasets together.

### 1. Check that the graph loaded

File: [`queries/01-check-counts.cypher`](queries/01-check-counts.cypher)

These queries count each node and relationship label. Compare the results with the table above before exploring the graph. Additional checks return **5 placeholders** and **228 supplied parts without a type match**; neither means the upload failed.

### 2. Inspect parts and assembly relationships

File: [`queries/02-explore-parts.cypher`](queries/02-explore-parts.cypher)

The first query lists 25 supplied parts with their IDs, names, and countries. The second returns 25 direct `contains` relationships, showing one assembly level at a time.

Use this to understand the records and edge direction. Repeated names identify different records, so use IDs to distinguish them. This is a general sample; the later queries select specific paths for a clearer example.

### 3. Follow a planned vehicle's material dependency

File: [`queries/03-planned-dependencies.cypher`](queries/03-planned-dependencies.cypher)

**Question:** Which planned components connect Vehicle Model A to cathode material?

```cypher
MATCH path = (vehicle:part_type)-[:planned_contains*1..5]->(material:part_type)
WHERE vehicle.type_id = 'urn:uuid:0733946c-59c6-41ae-9570-cb43a6e4c79e'
  AND material.type_id = 'urn:uuid:4f7b1cf2-a598-4027-bc78-63f6d8e55699'
RETURN path;
```

`MATCH` follows outgoing planned relationships between two selected types. The `*1..5` allows a path of one to five edges, so the query can pass through intermediate components. `RETURN path` includes those components and edges in the graph result.

The result is **Vehicle Model A → OEM A High Voltage Battery → HV Modul → ZB ZELLE → N Tier A CathodeMaterial**. It describes a design dependency, with a module and cell between the battery and material.

The file's second query examines the cell-to-material edge directly and returns its planned quantity, unit, and validity dates.

### 4. See which parts match each planned type

File: [`queries/04-instance-type-matches.cypher`](queries/04-instance-type-matches.cypher)

**Question:** How many supplied parts can be connected to each planned type?

```cypher
MATCH (p:part)-[m:matches_type]->(t:part_type)
RETURN t.type_id, t.name, t.manufacturer_part_id,
       m.match_basis, m.is_inferred, count(p) AS matched_parts
ORDER BY matched_parts DESC;
```

The query follows the matches already created by the loader, groups them by type and match properties, and counts the connected parts. It also returns the matching rule and inferred flag so you can see the basis of the connection.

| Planned type | Matched parts |
| --- | ---: |
| ZB ZELLE | 250 |
| HV Modul | 13 |
| OEM A High Voltage Battery | 3 |

These are many individual records connected to three shared types. The file's second query selects the lowest part ID for each matched type and displays one example connection per type.

### 5. Connect a vehicle assembly to a planned material dependency

File: [`queries/05-assembly-to-material.cypher`](queries/05-assembly-to-material.cypher)

**Question:** Can we follow a vehicle's assembly down to a cell, then use that cell's planned type to find a material dependency?

```cypher
MATCH physical = (vehicle:part)-[:contains*1..5]->(cell:part)
MATCH design = (cell)-[:matches_type]->(type:part_type)
               -[:planned_contains]->(material:part_type)
WHERE vehicle.part_id = 'urn:uuid:ef7d8432-679d-4bda-a277-ca9e9c5d11d1'
  AND cell.part_id = 'urn:uuid:ff827b41-9718-47c2-9786-e4f866889f60'
  AND material.type_id = 'urn:uuid:4f7b1cf2-a598-4027-bc78-63f6d8e55699'
RETURN physical, design;
```

The query builds two connected paths:

1. **`physical`** follows the selected vehicle's `contains` relationships to the selected cell, passing through its battery and module.
2. **`design`** starts at that same cell, follows its inferred type match, then follows the type's planned relationship to cathode material.

The `WHERE` conditions select specific records by ID, keeping the result small despite repeated names. Returning both paths shows **six nodes and five edges** in one connected graph.

This demonstrates how assembly and design data can be explored together. It does **not** identify a material batch actually used in the cell or prove that the assembly complies with the design.

## Understanding the data

Both datasets are synthetic test data from Eclipse Tractus-X. Original filenames, names, IDs, and relationships are preserved, including repeated “Mirror left” names and implausible assembly combinations.

- **Matching:** Both business partner (`bpnl`) and manufacturer part number must match exactly. Empty values and keys identifying multiple planned types are excluded. Every inferred edge records `match_basis = 'business_partner_and_part_number'` and `is_inferred = true`.
- **Missing records:** The instance file supplies 494 records. Five additional nodes represent referenced children whose details are absent; these have `is_placeholder = true`.
- **Time and versions:** Matches do not check revisions or temporal validity. Planned validity dates are retained, but queries explore the historical snapshot without filtering to today's date.
- **Scope:** The loader uses the serial part, batch, part-as-planned, and as-built/as-planned bill-of-materials models. Metadata, generator helpers, and other aspect models are not mapped.

## Stop or reload the demo

Stop PuppyGraph with `docker compose stop`. Restart an unchanged setup with `docker compose start`.

To rebuild the data and reapply the mapping:

```bash
docker compose stop
source .venv/bin/activate
python3 scripts/load.py
bash scripts/start.sh
```

Always stop PuppyGraph before writing to its DuckDB file. Loading and validation run in one transaction; failures roll back table changes. Expected counts are specific to the bundled datasets.

When upgrading an older copy, stop its container before replacing repository files, preserve your `.git` directory and `.venv`, and use the commands above. Running `start.sh` reapplies the mapping so new labels become available.

## Repository structure

| Path | Purpose |
| --- | --- |
| `data/CX_Testdata_v1.7.0_PartInstance-reduced.json` | Original part-instance dataset |
| `data/CX_Testdata_v.1.7.0_PartType.json` | Original planned-type dataset |
| `scripts/load.py`, `load.sql`, `validate.sql` | Build and validate the DuckDB tables |
| `scripts/start.sh` | Start PuppyGraph and upload the mapping |
| `schema.json` | Map tables, IDs, and properties to graph labels |
| `docker-compose.yaml` | Configure the local PuppyGraph container |
| `requirements.txt` | Pin the Python dependency |
| `queries/` | Cypher queries used in the walkthrough |
| `third_party/tractusx/` | Upstream authorship, notices, and license texts |

The generated database and Python environment are excluded from Git. The graph labels map to tables of the same name in the `supply_chain` schema, except `matches_type`, which maps to `part_type_match`.

## Troubleshooting

| Problem | Action |
| --- | --- |
| Python or DuckDB unavailable | Use `python3`, activate `.venv`, and install `requirements.txt`. |
| Docker unavailable or ports occupied | Start Docker Desktop and stop other applications using the configured ports. |
| Missing source file | Check both original filenames in `data/`; the PartType filename includes `v.1.7.0`. |
| Database missing or locked | Run the loader with PuppyGraph stopped and other database connections closed. |
| New labels absent or schema upload fails | Run `bash scripts/start.sh`; inspect the API error and container logs if it fails. |
| JDBC driver download fails | Check container access to `repo.maven.apache.org`. |

Check status and recent logs with:

```bash
docker compose ps
docker compose logs --tail=80 puppygraph
```

If uploading manually through **Graph → Upload Schema**, select `schema.json` and **Do not cache data** if prompted.

## Data source and attribution

The datasets come from the [Eclipse Tractus-X Item Relationship Service](https://github.com/eclipse-tractusx/item-relationship-service), pinned to commit `d787ff133797eaaf0bb8c4990024a08c2c992027`:

- [CX_Testdata_v1.7.0_PartInstance-reduced.json](https://github.com/eclipse-tractusx/item-relationship-service/blob/d787ff133797eaaf0bb8c4990024a08c2c992027/local/testing/testdata/CX_Testdata_v1.7.0_PartInstance-reduced.json)
- [CX_Testdata_v.1.7.0_PartType.json](https://github.com/eclipse-tractusx/item-relationship-service/blob/d787ff133797eaaf0bb8c4990024a08c2c992027/local/testing/testdata/CX_Testdata_v.1.7.0_PartType.json)

The source files are unmodified; the tables and inferred matches are derived by this demo. Upstream [AUTHORS.md](third_party/tractusx/AUTHORS.md), [NOTICE.md](third_party/tractusx/NOTICE.md), [LICENSE](third_party/tractusx/LICENSE), and [LICENSE_non-code](third_party/tractusx/LICENSE_non-code) are included. Those texts cover upstream material; they do not assign a license to the demo's own code.

## Further reading

- [PuppyGraph with DuckDB](https://docs.puppygraph.com/getting-started/querying-duckdb-data-as-a-graph/)
- [Graph modeling](https://docs.puppygraph.com/modeling/building-a-graph/)
- [Schema management](https://docs.puppygraph.com/modeling/managing-the-graph/)
