// Show this actual vehicle's direct components; expand further in the graph UI.
MATCH path = (vehicle:part)-[:contains]->(component:part)
WHERE vehicle.part_id = 'urn:uuid:ef7d8432-679d-4bda-a277-ca9e9c5d11d1'
RETURN path
LIMIT 100;
