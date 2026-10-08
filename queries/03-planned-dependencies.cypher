// Show vehicle dependencies and their planned production sites.
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