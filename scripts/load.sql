-- Run from the project root. This rebuilds only the supply_chain demo tables.
-- The runner closes DuckDB before a future PuppyGraph process opens this file.
BEGIN TRANSACTION;
CREATE SCHEMA IF NOT EXISTS supply_chain;

-- Keep JSON objects intact rather than relying on inferred nested STRUCT types.
CREATE OR REPLACE TEMP TABLE source_items AS
SELECT item.value AS item
FROM read_json_objects('data/CX_Testdata_v1.7.0_PartInstance-reduced.json') AS document,
     json_each(document.json,
       '$."https://catenax.io/schema/TestDataContainer/1.0.0"') AS item;

SELECT CASE WHEN count(*) > 0 THEN true
       ELSE error('No TestDataContainer records found') END FROM source_items;

CREATE OR REPLACE TEMP TABLE described_items AS
SELECT item,
       item ->> '$.catenaXId' AS part_id,
       coalesce(
         json_extract(item, '$."urn:samm:io.catenax.serial_part:3.0.0#SerialPart"[0]'),
         json_extract(item, '$."urn:samm:io.catenax.batch:3.0.0#Batch"[0]')
       ) AS description,
       CASE WHEN json_exists(item,
         '$."urn:samm:io.catenax.serial_part:3.0.0#SerialPart"[0]')
         THEN 'SerialPart'
         WHEN json_exists(item, '$."urn:samm:io.catenax.batch:3.0.0#Batch"[0]')
         THEN 'Batch' ELSE 'Unknown' END AS record_type
FROM source_items;

CREATE OR REPLACE TEMP TABLE source_boms AS
SELECT s.item ->> '$.catenaXId' AS parent_id,
       b.key AS model_index, b.value AS bom
FROM source_items s,
     json_each(s.item,
       '$."urn:samm:io.catenax.single_level_bom_as_built:3.0.0#SingleLevelBomAsBuilt"') b;

SELECT CASE WHEN count(*) = 0 THEN true
       ELSE error('BOM parent ID disagrees with containing item ID') END
FROM source_boms
WHERE (bom ->> '$.catenaXId') IS DISTINCT FROM parent_id;

DROP TABLE IF EXISTS supply_chain.contains;
DROP TABLE IF EXISTS supply_chain.part;
CREATE TABLE supply_chain.part (
    part_id VARCHAR PRIMARY KEY,
    name VARCHAR NOT NULL,
    country VARCHAR,
    manufacturing_date VARCHAR,
    business_partner_id VARCHAR,
    manufacturer_part_id VARCHAR,
    record_type VARCHAR NOT NULL,
    is_placeholder BOOLEAN NOT NULL
);

INSERT INTO supply_chain.part
SELECT part_id,
       coalesce(nullif(description ->> '$.partTypeInformation.nameAtManufacturer', ''), part_id),
       description ->> '$.manufacturingInformation.country',
       description ->> '$.manufacturingInformation.date',
       item ->> '$.bpnl',
       description ->> '$.partTypeInformation.manufacturerPartId',
       record_type, false
FROM described_items;

CREATE TABLE supply_chain.contains (
    edge_id VARCHAR PRIMARY KEY,
    parent_id VARCHAR NOT NULL,
    child_id VARCHAR NOT NULL,
    quantity DOUBLE,
    unit VARCHAR,
    child_business_partner_id VARCHAR,
    has_alternatives BOOLEAN,
    source_model VARCHAR NOT NULL,
    source_model_index INTEGER NOT NULL,
    source_child_index INTEGER NOT NULL
);

INSERT INTO supply_chain.contains
SELECT md5(concat_ws('|', b.parent_id, 'SingleLevelBomAsBuilt:3.0.0',
                    b.model_index, child.key, child.value ->> '$.catenaXId')),
       b.parent_id,
       child.value ->> '$.catenaXId',
       CAST(child.value ->> '$.quantity.value' AS DOUBLE),
       child.value ->> '$.quantity.unit',
       child.value ->> '$.businessPartner',
       CAST(child.value ->> '$.hasAlternatives' AS BOOLEAN),
       'urn:samm:io.catenax.single_level_bom_as_built:3.0.0#SingleLevelBomAsBuilt',
       CAST(b.model_index AS INTEGER), CAST(child.key AS INTEGER)
FROM source_boms b, json_each(b.bom, '$.childItems') child;

-- Preserve unknown endpoints without inventing a manufacturer or a country.
INSERT INTO supply_chain.part
SELECT DISTINCT c.child_id, 'Unknown referenced part', NULL, NULL, NULL, NULL,
       'Placeholder', true
FROM supply_chain.contains c
WHERE NOT EXISTS (SELECT 1 FROM supply_chain.part p WHERE p.part_id = c.child_id);

SELECT CASE WHEN count(*) = 0 THEN true
       ELSE error('Relationship with missing endpoint') END
FROM supply_chain.contains c
LEFT JOIN supply_chain.part p ON p.part_id = c.parent_id
LEFT JOIN supply_chain.part q ON q.part_id = c.child_id
WHERE p.part_id IS NULL OR q.part_id IS NULL;

COMMIT;
