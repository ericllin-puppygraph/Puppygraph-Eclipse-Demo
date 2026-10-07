// Hypothetical defect in one ZB ZELLE battery cell.
// Expected: 3 upstream paths: HV MODUL, Battery, Vehicle Fully Electric.
// Arrows still mean parent contains child; the WHERE clause anchors the child.
MATCH path = (assembly:part)-[:contains*1..5]->(component:part)
WHERE component.part_id = 'urn:uuid:ff827b41-9718-47c2-9786-e4f866889f60'
RETURN path;
