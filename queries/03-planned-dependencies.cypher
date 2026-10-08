// Run each statement separately. All edges here describe a planned BOM.
// Four edges: Vehicle Model A -> battery -> module -> cell -> cathode material.
MATCH path = (vehicle:part_type)-[:planned_contains*1..5]->(material:part_type)
WHERE vehicle.type_id = 'urn:uuid:0733946c-59c6-41ae-9570-cb43a6e4c79e'
  AND material.type_id = 'urn:uuid:4f7b1cf2-a598-4027-bc78-63f6d8e55699'
RETURN path;

// Explore the cell type's planned material, including quantity and validity.
MATCH (cell:part_type)-[r:planned_contains]->(material:part_type)
WHERE cell.type_id = 'urn:uuid:c7a2b803-f8fe-4b79-b6fc-967ce847c9a9'
RETURN cell.name, material.name, r.quantity, r.unit, r.valid_from, r.valid_to;
