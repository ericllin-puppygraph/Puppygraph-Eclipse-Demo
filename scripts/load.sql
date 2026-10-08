-- Run through scripts/load.py, which wraps extraction and validation in a transaction.
-- This rebuilds only the supply_chain demo tables.
-- The runner closes DuckDB before a future PuppyGraph process opens this file.
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

-- Only PartAsPlanned records describe types; the PlainObject record is metadata.
CREATE OR REPLACE TEMP TABLE source_type_items AS
SELECT item.value AS item
FROM read_json_objects('data/CX_Testdata_v.1.7.0_PartType.json') AS document,
     json_each(document.json,
       '$."https://catenax.io/schema/TestDataContainer/1.0.0"') AS item
WHERE json_exists(item.value, '$."urn:samm:io.catenax.part_as_planned:2.0.0#PartAsPlanned"');

SELECT CASE WHEN count(*) = 0 THEN true
       ELSE error('Expected exactly one PartAsPlanned description per type') END
FROM source_type_items
WHERE json_array_length(item, '$."urn:samm:io.catenax.part_as_planned:2.0.0#PartAsPlanned"') IS DISTINCT FROM 1;

CREATE OR REPLACE TEMP TABLE described_types AS
SELECT item, item ->> '$.catenaXId' AS type_id,
       json_extract(item, '$."urn:samm:io.catenax.part_as_planned:2.0.0#PartAsPlanned"[0]') AS description
FROM source_type_items;

SELECT CASE WHEN count(*) = 0 THEN true
       ELSE error('PartAsPlanned ID disagrees with containing item ID') END
FROM described_types
WHERE (description ->> '$.catenaXId') IS DISTINCT FROM type_id;

DROP TABLE IF EXISTS supply_chain.part_type_match;
DROP TABLE IF EXISTS supply_chain.planned_contains;
DROP TABLE IF EXISTS supply_chain.part_type;
CREATE TABLE supply_chain.part_type (
    type_id VARCHAR PRIMARY KEY,
    name VARCHAR NOT NULL,
    business_partner_id VARCHAR,
    manufacturer_part_id VARCHAR,
    classification VARCHAR,
    source_model VARCHAR NOT NULL
);
INSERT INTO supply_chain.part_type
SELECT type_id,
       coalesce(nullif(description ->> '$.partTypeInformation.nameAtManufacturer', ''), type_id),
       nullif(item ->> '$.bpnl', 'null'),
       description ->> '$.partTypeInformation.manufacturerPartId',
       description ->> '$.partTypeInformation.classification',
       'urn:samm:io.catenax.part_as_planned:2.0.0#PartAsPlanned'
FROM described_types;

CREATE OR REPLACE TEMP TABLE source_planned_boms AS
SELECT s.item ->> '$.catenaXId' AS parent_id, b.key AS model_index, b.value AS bom
FROM source_type_items s,
     json_each(s.item,
       '$."urn:samm:io.catenax.single_level_bom_as_planned:3.0.0#SingleLevelBomAsPlanned"') b;

SELECT CASE WHEN count(*) = 0 THEN true
       ELSE error('Planned BOM parent ID disagrees with containing item ID') END
FROM source_planned_boms
WHERE (bom ->> '$.catenaXId') IS DISTINCT FROM parent_id;

CREATE TABLE supply_chain.planned_contains (
    edge_id VARCHAR PRIMARY KEY,
    parent_id VARCHAR NOT NULL,
    child_id VARCHAR NOT NULL,
    quantity DOUBLE,
    unit VARCHAR,
    child_business_partner_id VARCHAR,
    valid_from VARCHAR,
    valid_to VARCHAR,
    source_model VARCHAR NOT NULL,
    source_model_index INTEGER NOT NULL,
    source_child_index INTEGER NOT NULL
);
INSERT INTO supply_chain.planned_contains
SELECT md5(concat_ws('|', b.parent_id, 'SingleLevelBomAsPlanned:3.0.0',
                    b.model_index, child.key, child.value ->> '$.catenaXId')),
       b.parent_id, child.value ->> '$.catenaXId',
       CAST(child.value ->> '$.quantity.value' AS DOUBLE),
       child.value ->> '$.quantity.unit',
       child.value ->> '$.businessPartner',
       child.value ->> '$.validityPeriod.validFrom',
       child.value ->> '$.validityPeriod.validTo',
       'urn:samm:io.catenax.single_level_bom_as_planned:3.0.0#SingleLevelBomAsPlanned',
       CAST(b.model_index AS INTEGER), CAST(child.key AS INTEGER)
FROM source_planned_boms b, json_each(b.bom, '$.childItems') child;

-- Only unique nonempty compound keys may create a bridge. Ambiguous keys stay
-- unmatched; names and part numbers alone never resolve an ambiguity.
CREATE OR REPLACE TEMP TABLE unique_type_keys AS
SELECT business_partner_id, manufacturer_part_id
FROM supply_chain.part_type
WHERE nullif(business_partner_id, '') IS NOT NULL
  AND nullif(manufacturer_part_id, '') IS NOT NULL
GROUP BY business_partner_id, manufacturer_part_id
HAVING count(*) = 1;

CREATE TABLE supply_chain.part_type_match (
    edge_id VARCHAR PRIMARY KEY,
    part_id VARCHAR NOT NULL UNIQUE,
    type_id VARCHAR NOT NULL,
    match_basis VARCHAR NOT NULL,
    is_inferred BOOLEAN NOT NULL
);
INSERT INTO supply_chain.part_type_match
SELECT md5(concat_ws('|', 'matches_type', p.part_id, t.type_id)),
       p.part_id, t.type_id, 'business_partner_and_part_number', true
FROM supply_chain.part p
JOIN supply_chain.part_type t
  ON p.business_partner_id = t.business_partner_id
 AND p.manufacturer_part_id = t.manufacturer_part_id
JOIN unique_type_keys k
  ON t.business_partner_id = k.business_partner_id
 AND t.manufacturer_part_id = k.manufacturer_part_id
WHERE NOT p.is_placeholder
  AND nullif(p.business_partner_id, '') IS NOT NULL
  AND nullif(p.manufacturer_part_id, '') IS NOT NULL;
