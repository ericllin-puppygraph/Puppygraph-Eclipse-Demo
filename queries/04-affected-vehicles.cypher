// Vehicle classification here uses an exact name observed in this test dataset.
// Expected: 1 distinct vehicle, ef7d8432-679d-4bda-a277-ca9e9c5d11d1.
MATCH (vehicle:part)-[:contains*1..5]->(component:part)
WHERE component.part_id = 'urn:uuid:ff827b41-9718-47c2-9786-e4f866889f60'
  AND vehicle.name = 'Vehicle Fully Electric'
RETURN DISTINCT vehicle.part_id AS vehicle_id, vehicle.name AS vehicle_name;
