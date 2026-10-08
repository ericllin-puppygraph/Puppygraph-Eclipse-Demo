// Expected: ZB ZELLE 250, HV Modul 13, OEM A High Voltage Battery 3.
// Matches are inferred from a unique (business partner, part number) key.
MATCH (p:part)-[m:matches_type]->(t:part_type)
RETURN t.type_id, t.name, t.manufacturer_part_id,
       m.match_basis, m.is_inferred, count(p) AS matched_parts
ORDER BY matched_parts DESC;

// Display three specific examples: one cell, one module, one battery.
MATCH (p:part)-[:matches_type]->(t:part_type)
WITH t, min(p.part_id) AS example_id
MATCH path = (example:part)-[:matches_type]->(t)
WHERE example.part_id = example_id
RETURN path;
