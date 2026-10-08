# PuppyGraph Supply Chain Demo

Explore how vehicle parts, product designs, material dependencies, and production sites connect using **PuppyGraph**, **DuckDB**, and Eclipse Tractus-X test data.

The demo explores the component and material requirements of three vehicle models, including shared dependencies and the sites recorded for their planned production. A separate example connects an individual vehicle assembly to its planned material dependency.

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
4. Which sites are associated with producing those components?
5. How can an assembly be connected to a planned material dependency?

## How it works

The Python loader converts the two source JSON files into seven DuckDB tables. PuppyGraph reads those tables through the mapping in `schema.json` and exposes them as a graph for Cypher queries. DuckDB runs as an embedded database; PuppyGraph runs in Docker.

| Graph label | Meaning | Count |
| --- | --- | ---: |
| `part` | Individual parts, batches, and placeholders for missing records | 499 |
| `part_type` | Planned products, components, and materials | 42 |
| `contains` | An assembly contains a child part | 765 |
| `planned_contains` | A planned type depends on a component or material type | 70 |
| `matches_type` | A supplied part matches one planned type by partner and part number | 266 |
| `site` | Site IDs from the dedicated planned-site records | 13 |
| `planned_production_at` | A type has a planned production function at a site | 41 |

Both containment relationships point **from parent to child**. A `matches_type` relationship points **from part to planned type**. A `planned_production_at` relationship points **from planned type to site**. The graph has **554 nodes and 1,142 edges**, including one flagged site ID (`BPN`).

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
  13 site IDs (1 suspect), 41 planned production links
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

These queries count each node and relationship label. Compare the results with the table above before exploring the graph. Additional checks return **5 placeholders**, **228 supplied parts without a type match**, and **one suspect site ID** (`BPN`). These reflect the source data rather than an upload failure.

### 2. Inspect parts and assembly relationships

File: [`queries/02-explore-parts.cypher`](queries/02-explore-parts.cypher)

The first query lists 25 supplied parts with their IDs, names, and countries. The second returns 25 direct `contains` relationships, showing one assembly level at a time.

Use this to understand the records and edge direction. Repeated names identify different records, so use IDs to distinguish them. This is a general sample; the later queries select specific paths for a clearer example.

### 3. Explore vehicle requirements and production sites

File: [`queries/03-planned-dependencies.cypher`](queries/03-planned-dependencies.cypher)

**Question:** What components and materials do vehicle models share, and where is their production planned?

```cypher
MATCH dependencies = (vehicle:part_type)
                     -[:planned_contains*0..5]->(component:part_type)
WHERE vehicle.name IN [
  'Vehicle Model A',
  'Vehicle Model B',
  'Vehicle Model C'
]
OPTIONAL MATCH production =
  (component)-[:planned_production_at]->(site:site)
WHERE site.is_suspect = false
RETURN dependencies, production;
```

This query follows every dependency branch for Models A, B, and C up to
five levels deep, then adds the production sites recorded for each type.
The zero-hop starting point includes the vehicles themselves.

Use the graph view to explore batteries, gearboxes, electronics, and tires,
along with their lower-level components and materials. Shared dependencies
connect the models: Models A and B share gearbox and ECU types, while
Models B and C share a tire type.

Site nodes show where production is planned. For example, the battery,
module, and cell share site `BPNS000004711DMY`, while cathode material
links to `BPNS00000003B0Q0`.

`OPTIONAL MATCH` preserves component paths when no usable site is recorded.
The suspect source ID `BPN` is excluded from the site visualization.

These are planned production associations, not evidence of current
production or shipments between factories. Relationship quantities describe
direct requirements; this query does not calculate total material needs.

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

### 6. Explore dependencies on single production sites

File: [`queries/06-single-site-dependencies.cypher`](queries/06-single-site-dependencies.cypher)

**Question:** Which components have only one recorded production site,
and which higher-level assemblies depend on them?

The query finds part types linked to exactly one usable site, then traces
their dependencies upward through as many as five assembly levels.
It returns both the dependency paths and the production-site connections.

Use the graph view to follow a component toward the assemblies that
require it. If an upstream assembly also has only one recorded site,
its production connection appears too: the query checks every part type.

For example, the cell, module, battery, and Vehicle Model A all connect
to site `BPNS000004711DMY`. Their cathode-material dependency connects
to a different site, `BPNS00000003B0Q0`.

This highlights where a site outage could affect several levels of
production. In this dataset, 40 part types have one usable recorded site,
so the result covers much of the planned graph.

“Only one recorded site” does not prove that no alternative producer
exists. These are planned associations; actual disruption also depends
on inventory, available alternatives, and production capacity.

## Understanding the data

Both datasets are synthetic test data from Eclipse Tractus-X. Original filenames, names, IDs, and relationships are preserved, including repeated “Mirror left” names and implausible assembly combinations.

- **Matching:** Both business partner (`bpnl`) and manufacturer part number must match exactly. Empty values and keys identifying multiple planned types are excluded. Every inferred edge records `match_basis = 'business_partner_and_part_number'` and `is_inferred = true`.
- **Missing records:** The instance file supplies 494 records. Five additional nodes represent referenced children whose details are absent; these have `is_placeholder = true`.
- **Time and versions:** Matches do not check revisions or temporal validity. Planned validity dates are retained, but queries explore the historical snapshot without filtering to today's date.
- **Production sites:** Only the dedicated `PartSiteInformationAsPlanned` 1.0.0 model is used, selecting records with `function = 'production'`. Its type-to-site links and validity dates are explicit source data. The conflicting embedded site list in `PartAsPlanned` is not merged. Business ownership is not inferred.
- **Site quality:** The 41 production links cover 41 of the 42 planned types. Twelve distinct site IDs pass a basic `BPNS` plus 12 uppercase-letter/digit shape check; the thirteenth is the literal `BPN`, retained with `is_suspect = true`. This check does not verify registration. The vehicle queries hide suspect site links while keeping the component paths.
- **Scope:** The loader uses serial part, batch, part-as-planned, as-built/as-planned bill-of-materials, and dedicated planned-site models. Metadata, generator helpers, and other aspect models are not mapped.

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

When adding sites to an existing copy, stop its container before replacing the supplied files at their matching repository paths. Then use the commands above. The original JSON files stay unchanged. The loader creates the new site tables, and `start.sh` uploads the expanded mapping; restarting alone will not add the site labels.

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
| `queries/` | Cypher walkthrough, including vehicle dependencies and planned production sites |
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
