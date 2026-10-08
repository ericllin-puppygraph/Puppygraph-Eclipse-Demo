// Run each statement separately in the Cypher editor.
// List a sample of supplied parts.
MATCH (p:part)
WHERE p.is_placeholder = false
RETURN p.part_id, p.name, p.country
ORDER BY p.name, p.part_id
LIMIT 25;

// Display a sample of parent-to-child relationships as a graph.
// LIMIT without ORDER BY does not select a fixed sample.
MATCH path = (parent:part)-[:contains]->(child:part)
RETURN path
LIMIT 25;
