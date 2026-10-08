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
