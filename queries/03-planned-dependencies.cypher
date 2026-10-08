// Show the planned component and material dependencies of three vehicle models.
// Shared components connect the models into one dependency network.
MATCH path = (product:part_type)-[:planned_contains*1..5]->(dependency:part_type)
WHERE product.name IN [
  'Vehicle Model A',
  'Vehicle Model B',
  'Vehicle Model C'
]
RETURN path;