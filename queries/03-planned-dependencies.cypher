// Run each statement separately in the Cypher editor.

// 1. Explore all planned dependency branches for three vehicle models.
MATCH path = (product:part_type)-[:planned_contains*1..5]->(dependency:part_type)
WHERE product.name IN [
  'Vehicle Model A',
  'Vehicle Model B',
  'Vehicle Model C'
]
RETURN path;

// 2. Add the planned production sites for vehicles and their dependencies.
// Zero hops includes each vehicle's own site. OPTIONAL MATCH keeps dependencies
// without a usable site record. Sites are planned associations, not shipments.
MATCH dependencies = (vehicle:part_type)-[:planned_contains*0..5]->(component:part_type)
WHERE vehicle.name IN [
  'Vehicle Model A',
  'Vehicle Model B',
  'Vehicle Model C'
]
OPTIONAL MATCH production = (component)-[:planned_production_at]->(site:site)
WHERE site.is_suspect = false
RETURN dependencies, production;

// 3. Inspect production assignments and their historical validity dates.
// DISTINCT removes repeats when the same type is reached through multiple paths.
MATCH (vehicle:part_type)-[:planned_contains*0..5]->(component:part_type)
WHERE vehicle.name IN [
  'Vehicle Model A',
  'Vehicle Model B',
  'Vehicle Model C'
]
OPTIONAL MATCH (component)-[production:planned_production_at]->(site:site)
WHERE site.is_suspect = false
RETURN DISTINCT vehicle.name AS vehicle_model,
       component.type_id AS type_id, component.name AS component,
       site.site_id AS production_site,
       production.valid_from AS valid_from,
       production.valid_until AS valid_until
ORDER BY vehicle_model, component, production_site;
