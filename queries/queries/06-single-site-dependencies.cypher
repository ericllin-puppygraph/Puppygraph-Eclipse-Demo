// Find part types with exactly one recorded, usable production site.
MATCH (component:part_type)-[:planned_production_at]->(site:site)
WHERE site.is_suspect = false
WITH component, collect(DISTINCT site) AS production_sites
WHERE size(production_sites) = 1

WITH component, production_sites[0] AS only_site

// Show the component's only recorded production site.
MATCH production = (component)-[:planned_production_at]->(only_site)

// Trace dependencies upward to higher-level assemblies.
MATCH impact = (assembly:part_type)
               -[:planned_contains*0..5]->(component)

RETURN impact, production;