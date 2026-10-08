// Run each statement separately in the Cypher editor.
// Expected: 499 (includes 5 placeholders).
MATCH (p:part)
RETURN count(p) AS parts;

// Expected: 765.
MATCH (:part)-[r:contains]->(:part)
RETURN count(r) AS relationships;

// Expected: 5.
MATCH (p:part)
WHERE p.is_placeholder = true
RETURN count(p) AS placeholders;

// Expected: 42.
MATCH (t:part_type)
RETURN count(t) AS planned_types;

// Expected: 70.
MATCH (:part_type)-[r:planned_contains]->(:part_type)
RETURN count(r) AS planned_relationships;

// Expected: 266.
MATCH (:part)-[r:matches_type]->(:part_type)
RETURN count(r) AS inferred_matches;

// Expected: 228 supplied parts have no inferred match. Placeholders excluded.
MATCH (p:part)
WHERE p.is_placeholder = false
OPTIONAL MATCH (p)-[m:matches_type]->(:part_type)
WITH p, count(m) AS matches
WHERE matches = 0
RETURN count(p) AS unmatched_source_parts;

// Expected: 13 site IDs (12 pass the basic ID shape check, 1 is suspect).
MATCH (s:site)
RETURN count(s) AS sites;

// Expected: 41. Includes the source link to the suspect ID BPN.
MATCH (:part_type)-[r:planned_production_at]->(:site)
RETURN count(r) AS planned_production_links;

// Inspect the questionable source value. Expected: one row, site_id = BPN.
MATCH (t:part_type)-[:planned_production_at]->(s:site)
WHERE s.is_suspect = true
RETURN t.name, s.site_id;
