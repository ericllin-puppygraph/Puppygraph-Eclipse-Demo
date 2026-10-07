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
