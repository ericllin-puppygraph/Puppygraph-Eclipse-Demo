// Show one supplied vehicle assembly and the inferred bridge to a planned material.
// Expected: two paths in one row; their union has 6 nodes and 5 edges.
// This does not identify a material batch actually used or prove design compliance.
MATCH physical = (vehicle:part)-[:contains*1..5]->(cell:part)
MATCH design = (cell)-[:matches_type]->(type:part_type)
               -[:planned_contains]->(material:part_type)
WHERE vehicle.part_id = 'urn:uuid:ef7d8432-679d-4bda-a277-ca9e9c5d11d1'
  AND cell.part_id = 'urn:uuid:ff827b41-9718-47c2-9786-e4f866889f60'
  AND material.type_id = 'urn:uuid:4f7b1cf2-a598-4027-bc78-63f6d8e55699'
RETURN physical, design;
